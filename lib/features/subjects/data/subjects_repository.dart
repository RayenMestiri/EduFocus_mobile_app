import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/subject.dart';

/// CRUD against /api/subjects (backend/routes/subjects.js — `{success, data}`).
class SubjectsRepository {
  SubjectsRepository(this._dio);

  final Dio _dio;

  Future<List<Subject>> list() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/subjects');
      return (response.data?['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Subject.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Subject> create({
    required String name,
    required String colorHex,
    required String icon,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/subjects',
        data: {'name': name, 'color': colorHex, 'icon': icon},
      );
      return Subject.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Subject> update(
    String id, {
    required String name,
    required String colorHex,
    required String icon,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/subjects/$id',
        data: {'name': name, 'color': colorHex, 'icon': icon},
      );
      return Subject.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<Map<String, dynamic>>('/subjects/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  return SubjectsRepository(ref.watch(apiClientProvider));
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
      await ref
          .read(subjectsRepositoryProvider)
          .create(name: name, colorHex: colorHex, icon: icon);
      ref.invalidateSelf();
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
      await ref
          .read(subjectsRepositoryProvider)
          .update(id, name: name, colorHex: colorHex, icon: icon);
      ref.invalidateSelf();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> remove(String id) async {
    try {
      await ref.read(subjectsRepositoryProvider).delete(id);
      ref.invalidateSelf();
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
