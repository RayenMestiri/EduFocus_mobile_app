import 'dart:io';
import 'package:flutter/foundation.dart';

/// Compile-time environment configuration.
///
/// The API base URL points at the existing EduFocus Node.js backend and can be
/// overridden per target without touching code:
///
/// ```sh
/// # Desktop / web / iOS simulator (backend on the same machine)
/// flutter run --dart-define=API_BASE_URL=http://localhost:5002
///
/// # Android emulator (host loopback is 10.0.2.2)
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5002
///
/// # Production (Render)
/// flutter build apk --dart-define=API_BASE_URL=https://edufocus-cpbo.onrender.com
/// ```
abstract final class Env {
  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5002',
  );

  static String get apiBaseUrl {
    if (!kIsWeb &&
        Platform.isAndroid &&
        _rawBaseUrl == 'http://localhost:5002') {
      return 'http://10.0.2.2:5002';
    }
    return _rawBaseUrl;
  }
}
