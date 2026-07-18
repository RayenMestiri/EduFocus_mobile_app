import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';
import 'local_store.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

/// Everything a repository needs to be offline-first, bundled so repository
/// constructors stay small and the wiring lives in one place.
class OfflineContext {
  OfflineContext({
    required this.cache,
    required this.queue,
    required this._isOnline,
    required this._poke,
  });

  /// Entity cache store (one per repository).
  final DocStore cache;

  /// Durable mutation queue shared by the whole app.
  final SyncQueue queue;

  final bool Function() _isOnline;
  final void Function() _poke;

  /// Whether it's worth attempting a network call right now.
  bool get isOnline => _isOnline();

  /// Ask the sync engine to try draining (fire-and-forget).
  void requestSync() => _poke();

  /// Enqueue a mutation and immediately request a drain attempt.
  Future<void> enqueue(PendingOp op) async {
    await queue.enqueue(op);
    requestSync();
  }
}

/// True when the failure is a transport problem (no HTTP response) — the
/// trigger for falling back to the offline path.
bool isTransportError(DioException e) => e.response == null;

OfflineContext offlineContext(Ref ref, String storeName) {
  return OfflineContext(
    cache: ref.watch(appDatabaseProvider).store(storeName),
    queue: ref.watch(syncQueueProvider),
    isOnline: () => ref.read(connectivityProvider),
    poke: () => ref.read(syncEngineProvider.notifier).drain(),
  );
}
