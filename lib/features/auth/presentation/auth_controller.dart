import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Global authentication state.
///
/// - `AsyncLoading` only during the initial session restore at startup.
/// - `AsyncData(null)` when signed out.
/// - `AsyncData(User)` when signed in.
///
/// The router redirects based on this state. Login/register deliberately do
/// NOT flip the global state to loading: doing so would bounce the router to
/// the splash screen mid-submission, unmounting the form and losing its
/// local error/loading state. Instead they return an error message (null on
/// success) and screens manage their own submitting flag.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() {
    return ref.read(authRepositoryProvider).restoreSession();
  }

  /// Returns null on success, or a user-displayable error message.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      state = AsyncData(user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Returns null on success, or a user-displayable error message.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .register(name: name, email: email, password: password);
      state = AsyncData(user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);
