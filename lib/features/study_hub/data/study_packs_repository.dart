import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_context.dart';
import '../../../core/offline/sync_queue.dart';
import '../domain/study_pack.dart';

/// Offline-first access to /api/study-packs.
///
/// Reads serve the cache when the network is unreachable, so flashcard review
/// keeps working offline. Updates (SRS ratings, notes, QCM edits) are merged
/// into the cached pack immediately and queued — last-write-wins on replay,
/// with the server re-becoming authoritative on the next successful fetch.
class StudyPacksRepository {
  StudyPacksRepository(this._dio, this._offline);

  final Dio _dio;
  final OfflineContext _offline;

  Future<List<StudyPack>> list() async {
    if (_offline.isOnline) {
      try {
        final response = await _dio.get<Map<String, dynamic>>('/study-packs');
        final docs = (response.data?['data'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        await _offline.cache.replaceAllSynced({
          for (final d in docs)
            if (d['_id'] is String) d['_id'] as String: d,
        });
        return [for (final d in docs) StudyPack.fromJson(d)];
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    final docs = await _offline.cache.getAll();
    return [for (final d in docs) StudyPack.fromJson(d)];
  }

  Future<StudyPack> getById(String id) async {
    if (_offline.isOnline) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/study-packs/$id',
        );
        final doc = response.data!['data'] as Map<String, dynamic>;
        await _offline.cache.put(id, doc);
        return StudyPack.fromJson(doc);
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    final cached = await _offline.cache.get(id);
    if (cached != null) return StudyPack.fromJson(cached);
    throw const ApiException('Hors ligne — pack non disponible en cache.');
  }

  /// Clone requires the server (it copies server-side data) — online only.
  Future<StudyPack> clone(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/study-packs/clone/$id',
      );
      return StudyPack.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<StudyPack> update(String id, Map<String, dynamic> data) async {
    if (_offline.isOnline) {
      try {
        final response = await _dio.put<Map<String, dynamic>>(
          '/study-packs/$id',
          data: data,
        );
        final doc = response.data!['data'] as Map<String, dynamic>;
        await _offline.cache.put(id, doc);
        return StudyPack.fromJson(doc);
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    // Offline: merge the partial payload into the cached pack and queue.
    final cached = await _offline.cache.get(id) ?? {'_id': id};
    final merged = {...cached, ...data};
    await _offline.cache.put(id, merged);
    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'studyPack',
        method: 'PUT',
        path: '/study-packs/$id',
        body: data,
        targetId: id,
      ),
    );
    return StudyPack.fromJson(merged);
  }

  Future<void> saveAttempt(String id, Map<String, dynamic> body) async {
    if (_offline.isOnline) {
      try {
        await _dio.post('/study-packs/$id/attempts', data: body);
        return;
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'studyPack',
        method: 'POST',
        path: '/study-packs/$id/attempts',
        body: body,
        targetId: id,
      ),
    );
  }
}

final studyPacksRepositoryProvider = Provider<StudyPacksRepository>((ref) {
  return StudyPacksRepository(
    ref.watch(apiClientProvider),
    offlineContext(ref, 'study_packs'),
  );
});

final studyPacksProvider = FutureProvider.autoDispose<List<StudyPack>>((ref) {
  return ref.watch(studyPacksRepositoryProvider).list();
});

final studyPackProvider = FutureProvider.autoDispose.family<StudyPack, String>((
  ref,
  id,
) {
  return ref.watch(studyPacksRepositoryProvider).getById(id);
});
