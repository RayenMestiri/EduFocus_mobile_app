import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_colors.dart';

const _storageKey = 'edufocus_theme_mode';
const _storage = FlutterSecureStorage();

/// Resolves what palette a [ThemeMode] means right now (System follows the
/// OS brightness) and pushes it into the [AppColors] static bridge so every
/// widget reads the correct colors on the next frame.
AppPaletteData _resolvePalette(ThemeMode mode) {
  final platformBrightness = ui.PlatformDispatcher.instance.platformBrightness;
  final effectiveDark = switch (mode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system => platformBrightness == Brightness.dark,
  };
  return effectiveDark ? AppPaletteData.dark : AppPaletteData.light;
}

/// Reads the saved preference and primes [AppColors] — awaited in `main()`
/// before `runApp` so the first frame is already in the right theme
/// (no flash of the wrong mode).
Future<ThemeMode> loadInitialThemeMode() async {
  String? saved;
  try {
    saved = await _storage.read(key: _storageKey);
  } catch (_) {
    saved = null; // storage unavailable → fall back to system
  }
  final mode = switch (saved) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  AppColors.setPalette(_resolvePalette(mode));
  return mode;
}

class ThemeController extends Notifier<ThemeMode> {
  /// Seeded by `main()` via [loadInitialThemeMode].
  static ThemeMode initialMode = ThemeMode.system;

  @override
  ThemeMode build() {
    AppColors.setPalette(_resolvePalette(initialMode));
    return initialMode;
  }

  Future<void> setMode(ThemeMode mode) async {
    AppColors.setPalette(_resolvePalette(mode));
    state = mode;
    try {
      await _storage.write(
        key: _storageKey,
        value: switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
    } catch (_) {
      // Persistence failure is non-fatal; the in-session choice still applies.
    }
  }

  /// Called when the OS toggles its appearance while we're in System mode.
  void onPlatformBrightnessChanged() {
    if (state != ThemeMode.system) return;
    AppColors.setPalette(_resolvePalette(state));
    // Same enum value, but dependents must re-read the resolved palette.
    ref.notifyListeners();
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
