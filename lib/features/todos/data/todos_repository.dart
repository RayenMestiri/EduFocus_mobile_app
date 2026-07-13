import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/todo.dart';

/// CRUD against /api/todos (backend/routes/todos.js — `{success, data}`).
class TodosRepository {
  TodosRepository(this._dio);

  final Dio _dio;

  Future<List<Todo>> list() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/todos');
      return (response.data?['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Todo.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Todo> create({
    required String title,
    required String date,
    required String priority,
    String? subjectId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/todos',
        data: {
          'title': title,
          'date': date,
          'priority': priority,
          if (subjectId != null && subjectId.isNotEmpty) 'subjectId': subjectId,
        },
      );
      return Todo.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Todo> update(
    String id, {
    required String title,
    required String priority,
    String? subjectId,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/todos/$id',
        data: {
          'title': title,
          'priority': priority,
          // Backend unsets the subject when null/empty is sent.
          'subjectId': subjectId ?? '',
        },
      );
      return Todo.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> toggle(String id) async {
    try {
      await _dio.patch<Map<String, dynamic>>('/todos/$id/toggle');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<Map<String, dynamic>>('/todos/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final todosRepositoryProvider = Provider<TodosRepository>((ref) {
  return TodosRepository(ref.watch(apiClientProvider));
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
