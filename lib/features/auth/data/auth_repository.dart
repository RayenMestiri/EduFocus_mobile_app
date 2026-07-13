import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

/// Talks to the existing EduFocus auth endpoints (backend/routes/auth.js).
/// Response envelope: `{ success, message, token, user }`.
class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStorage _tokens;

  /// POST /api/auth/login → stores the JWT and returns the user.
  Future<User> login({required String email, required String password}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return _persistAuth(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /api/auth/register → stores the JWT and returns the user.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
      );
      return _persistAuth(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /api/auth/forgot-password — always succeeds server-side
  /// (anti-enumeration), so no return payload beyond the generic message.
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /api/auth/me using the stored token. Returns null when no token is
  /// stored; clears an invalid/expired token instead of leaving the app in a
  /// broken half-authenticated state.
  Future<User?> restoreSession() async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final user = response.data?['user'];
      if (user is Map<String, dynamic>) return User.fromJson(user);
      return null;
    } on DioException catch (e) {
      final failure = ApiException.fromDio(e);
      if (failure.isUnauthorized) {
        await _tokens.clear();
        return null;
      }
      throw failure;
    }
  }

  Future<void> logout() => _tokens.clear();

  Future<User> _persistAuth(Map<String, dynamic> body) async {
    final token = body['token'] as String?;
    final user = body['user'];
    if (token == null || user is! Map<String, dynamic>) {
      throw const ApiException('Réponse du serveur invalide.');
    }
    await _tokens.write(token);
    return User.fromJson(user);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});
