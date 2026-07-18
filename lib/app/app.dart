import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/offline/sync_engine.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/profile/data/settings_repository.dart';
import '../features/study_hub/data/study_packs_repository.dart';
import '../features/subjects/data/subjects_repository.dart';
import '../features/todos/data/todos_repository.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class EduFocusApp extends ConsumerStatefulWidget {
  const EduFocusApp({super.key});

  @override
  ConsumerState<EduFocusApp> createState() => _EduFocusAppState();
}

class _EduFocusAppState extends ConsumerState<EduFocusApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // After the sync engine pushes queued work, the server is authoritative
    // again — refresh every entity provider so UIs converge.
    SyncEngine.onSynced
      ..clear()
      ..add(() {
        ref.invalidate(subjectsControllerProvider);
        ref.invalidate(todosControllerProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(studyPacksProvider);
        ref.invalidate(timerSettingsProvider);
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Keep "Système" mode in sync when the OS switches appearance.
    ref.read(themeControllerProvider.notifier).onPlatformBrightnessChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the foreground is a natural moment to push pending work.
    if (state == AppLifecycleState.resumed) {
      ref.read(syncEngineProvider.notifier).drain();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);

    // Instantiate the engine so it starts listening to connectivity.
    ref.watch(syncEngineProvider);

    return MaterialApp.router(
      title: 'EduFocus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 320),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: router,
    );
  }
}
