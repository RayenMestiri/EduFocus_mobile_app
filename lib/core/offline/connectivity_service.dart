import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the device currently has a network path.
///
/// `true` means "worth attempting a request" (wifi/cellular/ethernet present);
/// repositories still handle request failures gracefully, so a lying network
/// (captive portal etc.) degrades to the offline path automatically.
class ConnectivityController extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  bool build() {
    _sub?.cancel();
    try {
      _sub = Connectivity().onConnectivityChanged.listen((results) {
        final online = _isOnline(results);
        if (online != state) state = online;
      });
    } catch (e) {
      debugPrint('Connectivity listener error: $e');
    }
    ref.onDispose(() => _sub?.cancel());

    // Optimistic default until the first platform callback lands.
    try {
      Connectivity()
          .checkConnectivity()
          .then((results) {
            final online = _isOnline(results);
            if (online != state) state = online;
          })
          .catchError((e) {
            debugPrint('Connectivity check error: $e');
          });
    } catch (e) {
      debugPrint('Connectivity check error: $e');
    }
    return true;
  }

  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
  }
}

final connectivityProvider = NotifierProvider<ConnectivityController, bool>(
  ConnectivityController.new,
);
