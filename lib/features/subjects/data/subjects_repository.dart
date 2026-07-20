import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/offline_context.dart';
import '../../../core/offline/sync_queue.dart';
import '../domain/subject.dart';

/// Offline-first CRUD against /api/subjects.
///
/// Online behaviour is unchanged (network is the source of truth and the
/// cache is refreshed after every call). When the network is unreachable the
/// repository serves the cache and records mutations optimistically in the
/// sync queue for later replay.
class SubjectsRepository {
  SubjectsRepository(this._dio, this._offline);

  final Dio _dio;
  final OfflineContext _offline;

  Future<List<Subject>> list() async {
    if (_offline.isOnline) {
      try {
        final response = await _dio.get<Map<String, dynamic>>('/subjects');
        final docs = (response.data?['data'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

        final ops = await _offline.queue.all();
        final pendingPuts = {
          for (final op in ops)
            if (op.entity == 'subject' &&
                op.method == 'PUT' &&
                op.targetId != null)
              op.targetId!: op.body
        };

        final updatedDocs = <String, Map<String, dynamic>>{};
        for (final d in docs) {
          final id = d['_id'] as String;
          if (pendingPuts.containsKey(id)) {
            updatedDocs[id] = {...d, ...pendingPuts[id]!};
          } else {
            updatedDocs[id] = d;
          }
        }

        await _offline.cache.replaceAllSynced(updatedDocs);
        return _fromCache();
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
        // Network lied — fall through to cache.
      }
    }
    return _fromCache();
  }

  Future<List<Subject>> _fromCache() async {
    final docs = await _offline.cache.getAll();
    return [for (final d in docs) Subject.fromJson(d)];
  }

  Future<Subject> create({
    required String name,
    required String colorHex,
    required String icon,
  }) async {
    final body = {'name': name, 'color': colorHex, 'icon': icon};
    if (_offline.isOnline) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/subjects',
          data: body,
        );
        final doc = response.data!['data'] as Map<String, dynamic>;
        await _offline.cache.put(doc['_id'] as String, doc);
        return Subject.fromJson(doc);
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    // Offline: fabricate the subject locally and queue the create.
    final tempId = newLocalId();
    final doc = {...body, '_id': tempId};
    await _offline.cache.put(tempId, doc);
    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'subject',
        method: 'POST',
        path: '/subjects',
        body: body,
        tempId: tempId,
        targetId: tempId,
      ),
    );
    return Subject.fromJson(doc);
  }

  Future<Subject> update(
    String id, {
    required String name,
    required String colorHex,
    required String icon,
  }) async {
    final body = {'name': name, 'color': colorHex, 'icon': icon};
    if (_offline.isOnline && !isLocalId(id)) {
      try {
        final response = await _dio.put<Map<String, dynamic>>(
          '/subjects/$id',
          data: body,
        );
        final doc = response.data!['data'] as Map<String, dynamic>;
        await _offline.cache.put(id, doc);
        return Subject.fromJson(doc);
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    // Offline (or still-local entity): merge into cache and queue.
    final cached = await _offline.cache.get(id) ?? {'_id': id};
    final merged = {...cached, ...body};
    await _offline.cache.put(id, merged);
    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'subject',
        method: 'PUT',
        path: '/subjects/$id',
        body: body,
        targetId: id,
      ),
    );
    return Subject.fromJson(merged);
  }

  Future<void> delete(String id) async {
    if (_offline.isOnline && !isLocalId(id)) {
      try {
        await _dio.delete<Map<String, dynamic>>('/subjects/$id');
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
        entity: 'subject',
        method: 'DELETE',
        path: '/subjects/$id',
        targetId: id,
      ),
    );
  }
}

final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  return SubjectsRepository(
    ref.watch(apiClientProvider),
    offlineContext(ref, 'subjects'),
  );
});

/// Live list of the user's subjects, shared by Timer, Todos and Matières.
class SubjectsController extends AsyncNotifier<List<Subject>> {
  @override
  Future<List<Subject>> build() {
    return ref.read(subjectsRepositoryProvider).list();
  }

  Future<String?> create({
    required String name,
    required String colorHex,
    required String icon,
  }) async {
    try {
      final created = await ref
          .read(subjectsRepositoryProvider)
          .create(name: name, colorHex: colorHex, icon: icon);
      // Optimistic: append the new subject instantly — no network re-fetch.
      final current = state.value ?? [];
      state = AsyncData([...current, created]);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> updateSubject(
    String id, {
    required String name,
    required String colorHex,
    required String icon,
  }) async {
    try {
      final updated = await ref
          .read(subjectsRepositoryProvider)
          .update(id, name: name, colorHex: colorHex, icon: icon);
      // Optimistic: patch the single item in-place — no network re-fetch.
      final current = state.value ?? [];
      state = AsyncData([
        for (final s in current)
          if (s.id == id) updated else s,
      ]);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> remove(String id) async {
    try {
      await ref.read(subjectsRepositoryProvider).delete(id);
      // Optimistic: filter out the deleted subject instantly — no network re-fetch.
      final current = state.value ?? [];
      state = AsyncData([for (final s in current) if (s.id != id) s]);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}


final subjectsControllerProvider =
    AsyncNotifierProvider<SubjectsController, List<Subject>>(
      SubjectsController.new,
    );
