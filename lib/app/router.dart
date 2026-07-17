import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/presentation/screens/ai_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/chrono/presentation/screens/chrono_screen.dart';
import '../features/dashboard/presentation/screens/planner_screen.dart';
import '../features/dashboard/presentation/screens/srs_analytics_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/study_hub/domain/study_pack.dart';
import '../features/study_hub/presentation/screens/exercise_screen.dart';
import '../features/study_hub/presentation/screens/flashcards_screen.dart';
import '../features/study_hub/presentation/screens/note_detail_screen.dart';
import '../features/study_hub/presentation/screens/qcm_screen.dart';
import '../features/study_hub/presentation/screens/study_hub_screen.dart';
import '../features/study_hub/presentation/screens/study_pack_detail_screen.dart';
import '../features/subjects/presentation/screens/subjects_screen.dart';
import '../features/timer/presentation/screens/timer_screen.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const timer = '/timer';
  static const chrono = '/chrono';
  static const coach = '/coach';
  static const subjects = '/subjects';
  static const studyHub = '/study-hub';
  static const profile = '/profile';
  static const planner = '/planner';
  static const srsAnalytics = '/study-hub/analytics';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Bump a ValueNotifier whenever auth state changes so GoRouter re-evaluates
  // its redirect — the canonical Riverpod × go_router integration.
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final onAuthPage =
          location == AppRoutes.login || location == AppRoutes.register;

      // Session restore in flight → hold on splash.
      if (auth.isLoading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final signedIn = auth.value != null;
      if (!signedIn && !onAuthPage) return AppRoutes.login;
      if (signedIn && (onAuthPage || location == AppRoutes.splash)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      // ── Full-screen pages pushed above the shell ──
      GoRoute(
        path: AppRoutes.studyHub,
        builder: (context, state) => const StudyHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.srsAnalytics,
        builder: (context, state) => const SrsAnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.planner,
        builder: (context, state) => const PlannerScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.studyHub}/:id',
        builder: (context, state) =>
            StudyPackDetailScreen(packId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.studyHub}/:id/flashcards',
        builder: (context, state) =>
            FlashcardsScreen(packId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.studyHub}/:id/qcm',
        builder: (context, state) =>
            QcmScreen(packId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.studyHub}/:id/notes/:noteId',
        builder: (context, state) {
          final note = state.extra as Note;
          return NoteDetailScreen(
            note: note,
            packId: state.pathParameters['id']!,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.studyHub}/:id/exercises',
        builder: (context, state) =>
            ExerciseScreen(packId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      // ── Main app: 5 tab branches behind the glass nav bar ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.timer,
                builder: (context, state) => const TimerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chrono,
                builder: (context, state) => const ChronoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.coach,
                builder: (context, state) => const AiScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.subjects,
                builder: (context, state) => const SubjectsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
