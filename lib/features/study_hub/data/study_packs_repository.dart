import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/study_pack.dart';

/// Read access to /api/study-packs (backend/routes/studyPacks.js).
class StudyPacksRepository {
  StudyPacksRepository(this._dio);

  final Dio _dio;

  Future<List<StudyPack>> list() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/study-packs');
      return (response.data?['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StudyPack.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<StudyPack> getById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/study-packs/$id');
      return StudyPack.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

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
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/study-packs/$id',
        data: data,
      );
      return StudyPack.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> saveAttempt(String id, Map<String, dynamic> body) async {
    try {
      await _dio.post('/study-packs/$id/attempts', data: body);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final studyPacksRepositoryProvider = Provider<StudyPacksRepository>((ref) {
  return StudyPacksRepository(ref.watch(apiClientProvider));
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
