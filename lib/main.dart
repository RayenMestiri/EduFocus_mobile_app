import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved theme preference before the first frame so the app never
  // flashes the wrong mode at startup.
  ThemeController.initialMode = await loadInitialThemeMode();
  runApp(const ProviderScope(child: EduFocusApp()));
}
