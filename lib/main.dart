import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/theme/theme_controller.dart';
import 'core/offline/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for French locale
  await initializeDateFormatting('fr_FR', null);

  // Boot-critical async work in parallel: saved theme (avoids a wrong-mode
  // flash) and the offline database (repositories need it from frame one).
  final results = await Future.wait([
    loadInitialThemeMode(),
    AppDatabase.open(),
  ]);
  ThemeController.initialMode = results[0] as ThemeMode;
  final db = results[1] as AppDatabase;

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const EduFocusApp(),
    ),
  );
}
