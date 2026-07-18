import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/offline_context.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

/// Talks to the existing EduFocus auth endpoints (backend/routes/auth.js).
/// Response envelope: `{ success, message, token, user }`.
///
/// Offline-first: the authenticated profile is cached so a stored JWT keeps
/// the whole app usable with no network — the token is only *invalidated* by
/// an explicit 401 from the server, never by a transport failure.
class AuthRepository {
  AuthRepository(this._dio, this._tokens, this._db);

  final Dio _dio;
  final TokenStorage _tokens;
  final AppDatabase _db;

  DocStore get _authCache => _db.store('auth');
  static const _meKey = 'me';

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

  /// GET /api/auth/me using the stored token.
  ///
  /// Returns null when no token is stored. A 401 clears the token (session
  /// truly expired). A *transport* failure falls back to the cached profile
  /// so the app opens fully offline.
  Future<User?> restoreSession() async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final user = response.data?['user'];
      if (user is Map<String, dynamic>) {
        await _authCache.put(_meKey, user);
        return User.fromJson(user);
      }
      return null;
    } on DioException catch (e) {
      if (isTransportError(e)) {
        final cached = await _authCache.get(_meKey);
        if (cached != null) return User.fromJson(cached);
        // Token exists but we've never cached a profile — treat as signed
        // out for this launch rather than blocking on an error screen.
        return null;
      }
      final failure = ApiException.fromDio(e);
      if (failure.isUnauthorized) {
        await _tokens.clear();
        await _authCache.delete(_meKey);
        return null;
      }
      throw failure;
    }
  }

  /// Clears the token *and* every cached collection + pending mutation —
  /// no user data may survive on a shared device.
  Future<void> logout() async {
    await _tokens.clear();
    await _db.clearAll();
  }

  Future<User> _persistAuth(Map<String, dynamic> body) async {
    final token = body['token'] as String?;
    final user = body['user'];
    if (token == null || user is! Map<String, dynamic>) {
      throw const ApiException('Réponse du serveur invalide.');
    }
    await _tokens.write(token);
    await _authCache.put(_meKey, user);
    return User.fromJson(user);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
    ref.watch(appDatabaseProvider),
  );
});
