import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/offline_context.dart';
import '../../../core/offline/sync_queue.dart';
import '../domain/todo.dart';

/// Offline-first CRUD against /api/todos.
///
/// Same contract as before; when the network is unreachable, reads come from
/// the cache and writes are applied optimistically then queued for replay.
class TodosRepository {
  TodosRepository(this._dio, this._offline);

  final Dio _dio;
  final OfflineContext _offline;

  Future<List<Todo>> list() async {
    if (_offline.isOnline) {
      try {
        final response = await _dio.get<Map<String, dynamic>>('/todos');
        final docs = (response.data?['data'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

        final ops = await _offline.queue.all();
        final todoOps = ops.where((op) => op.entity == 'todo').toList();

        final updatedDocs = <String, Map<String, dynamic>>{};
        for (final d in docs) {
          final id = d['_id'] as String;
          var doc = Map<String, dynamic>.from(d);

          for (final op in todoOps) {
            if (op.targetId == id) {
              if (op.method == 'PUT' && op.body != null) {
                doc = {...doc, ...op.body!};
              } else if (op.method == 'PATCH' && op.path.endsWith('/toggle')) {
                doc['done'] = !(doc['done'] as bool? ?? false);
              }
            }
          }
          updatedDocs[id] = doc;
        }

        await _offline.cache.replaceAllSynced(updatedDocs);
        return _fromCache();
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    return _fromCache();
  }

  Future<List<Todo>> _fromCache() async {
    final docs = await _offline.cache.getAll();
    return [for (final d in docs) Todo.fromJson(d)];
  }

  Future<Todo> create({
    required String title,
    required String date,
    required String priority,
    String? subjectId,
  }) async {
    final body = {
      'title': title,
      'date': date,
      'priority': priority,
      if (subjectId != null && subjectId.isNotEmpty) 'subjectId': subjectId,
    };
    if (_offline.isOnline) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/todos',
          data: body,
        );
        final doc = response.data!['data'] as Map<String, dynamic>;
        await _offline.cache.put(doc['_id'] as String, doc);
        return Todo.fromJson(doc);
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    final tempId = newLocalId();
    final doc = {...body, '_id': tempId, 'done': false};
    await _offline.cache.put(tempId, doc);
    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'todo',
        method: 'POST',
        path: '/todos',
        body: body,
        tempId: tempId,
        targetId: tempId,
      ),
    );
    return Todo.fromJson(doc);
  }

  Future<Todo> update(
    String id, {
    required String title,
    required String priority,
    String? subjectId,
  }) async {
    final body = {
      'title': title,
      'priority': priority,
      // Backend unsets the subject when null/empty is sent.
      'subjectId': subjectId ?? '',
    };
    if (_offline.isOnline && !isLocalId(id)) {
      try {
        final response = await _dio.put<Map<String, dynamic>>(
          '/todos/$id',
          data: body,
        );
        final doc = response.data!['data'] as Map<String, dynamic>;
        await _offline.cache.put(id, doc);
        return Todo.fromJson(doc);
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    final cached = await _offline.cache.get(id) ?? {'_id': id};
    final merged = {...cached, ...body};
    await _offline.cache.put(id, merged);
    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'todo',
        method: 'PUT',
        path: '/todos/$id',
        body: body,
        targetId: id,
      ),
    );
    return Todo.fromJson(merged);
  }

  Future<void> toggle(String id) async {
    if (_offline.isOnline && !isLocalId(id)) {
      try {
        await _dio.patch<Map<String, dynamic>>('/todos/$id/toggle');
        final cached = await _offline.cache.get(id);
        if (cached != null) {
          cached['done'] = !(cached['done'] as bool? ?? false);
          await _offline.cache.put(id, cached);
        }
        return;
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    final cached = await _offline.cache.get(id);
    if (cached != null) {
      cached['done'] = !(cached['done'] as bool? ?? false);
      await _offline.cache.put(id, cached);
    }
    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'todo',
        method: 'PATCH',
        path: '/todos/$id/toggle',
        targetId: id,
      ),
    );
  }

  Future<void> delete(String id) async {
    if (_offline.isOnline && !isLocalId(id)) {
      try {
        await _dio.delete<Map<String, dynamic>>('/todos/$id');
        await _offline.cache.delete(id);
        return;
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    await _offline.cache.delete(id);
    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'todo',
        method: 'DELETE',
        path: '/todos/$id',
        targetId: id,
      ),
    );
  }
}

final todosRepositoryProvider = Provider<TodosRepository>((ref) {
  return TodosRepository(
    ref.watch(apiClientProvider),
    offlineContext(ref, 'todos'),
  );
});

class TodosController extends AsyncNotifier<List<Todo>> {
  @override
  Future<List<Todo>> build() {
    return ref.read(todosRepositoryProvider).list();
  }

  Future<String?> create({
    required String title,
    required String date,
    required String priority,
    String? subjectId,
  }) async {
    try {
      await ref
          .read(todosRepositoryProvider)
          .create(
            title: title,
            date: date,
            priority: priority,
            subjectId: subjectId,
          );
      ref.invalidateSelf();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> updateTodo(
    String id, {
    required String title,
    required String priority,
    String? subjectId,
  }) async {
    try {
      await ref
          .read(todosRepositoryProvider)
          .update(id, title: title, priority: priority, subjectId: subjectId);
      ref.invalidateSelf();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Optimistic toggle: flip locally first so the checkbox answers
  /// instantly, then sync; reload on failure.
  Future<void> toggle(Todo todo) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final t in current)
          if (t.id == todo.id)
            Todo(
              id: t.id,
              title: t.title,
              date: t.date,
              done: !t.done,
              priority: t.priority,
              subjectId: t.subjectId,
            )
          else
            t,
      ]);
    }
    try {
      await ref.read(todosRepositoryProvider).toggle(todo.id);
    } on ApiException {
      ref.invalidateSelf();
    }
  }

  Future<String?> remove(String id) async {
    try {
      await ref.read(todosRepositoryProvider).delete(id);
      ref.invalidateSelf();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}

final todosControllerProvider =
    AsyncNotifierProvider<TodosController, List<Todo>>(TodosController.new);
