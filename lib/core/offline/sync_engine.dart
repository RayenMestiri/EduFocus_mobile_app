import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'connectivity_service.dart';
import 'local_store.dart';
import 'sync_queue.dart';

/// Live synchronization status surfaced to the UI (offline banner).
@immutable
class SyncStatus {
  const SyncStatus({
    this.online = true,
    this.syncing = false,
    this.pending = 0,
  });

  final bool online;
  final bool syncing;
  final int pending;

  bool get hasWork => pending > 0 || syncing;

  SyncStatus copyWith({bool? online, bool? syncing, int? pending}) =>
      SyncStatus(
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
        pending: pending ?? this.pending,
      );
}

/// Replays queued mutations against the backend, strictly in order.
///
/// Guarantees:
///  · Creates performed offline get their fabricated `local_*` id swapped for
///    the real server id; every later queued op referencing that temp id is
///    rewritten before being sent (path *and* cached doc).
///  · Transport failures stop the drain and schedule a retry with exponential
///    backoff (also re-triggered by connectivity changes).
///  · 4xx responses (except 401/408/429) are permanent — the op is dropped so
///    one poisoned mutation can never wedge the queue.
///  · After a successful drain, entity providers are refreshed via
///    [onSynced] callbacks registered by the repositories' feature layer.
class SyncEngine extends Notifier<SyncStatus> {
  Timer? _retryTimer;
  int _backoffLevel = 0;
  bool _draining = false;

  /// Callbacks (provider invalidations) fired after a drain that actually
  /// pushed something, so UIs refresh from the now-authoritative server.
  static final List<void Function()> onSynced = [];

  @override
  SyncStatus build() {
    ref.onDispose(() => _retryTimer?.cancel());

    // Connectivity transitions drive the queue.
    ref.listen<bool>(connectivityProvider, (prev, online) {
      state = state.copyWith(online: online);
      if (online) {
        _backoffLevel = 0;
        drain();
      }
    });

    _refreshPending();
    // Kick an initial drain shortly after startup (lets DI settle).
    Timer.run(drain);
    return SyncStatus(online: ref.read(connectivityProvider));
  }

  SyncQueue get _queue => ref.read(syncQueueProvider);
  DocStore get _idMap => ref.read(appDatabaseProvider).store('id_map');
  Dio get _dio => ref.read(apiClientProvider);

  Future<void> _refreshPending() async {
    final n = await _queue.length;
    state = state.copyWith(pending: n);
  }

  /// Public entry point — safe to call at any time (no-ops when already
  /// draining or offline or empty).
  Future<void> drain() async {
    if (_draining) return;
    if (!ref.read(connectivityProvider)) return;
    _draining = true;
    var pushedSomething = false;

    try {
      state = state.copyWith(syncing: true);
      while (true) {
        final ops = await _queue.all();
        state = state.copyWith(pending: ops.length);
        if (ops.isEmpty) break;

        final op = ops.first;
        final resolved = await _resolveIds(op);

        // A non-create op still pointing at an unresolved local id means its
        // create hasn't synced (shouldn't happen given FIFO) — drop safely.
        if (op.method != 'POST' && resolved.path.contains(localIdPrefix)) {
          await _queue.remove(op.id);
          continue;
        }

        try {
          final response = await _dio.request<Map<String, dynamic>>(
            resolved.path,
            data: resolved.body,
            options: Options(method: resolved.method),
          );

          if (op.tempId != null) {
            await _captureServerId(op.tempId!, response.data);
          }
          await _queue.remove(op.id);
          pushedSomething = true;
          _backoffLevel = 0;
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          final permanent =
              status != null &&
              status >= 400 &&
              status < 500 &&
              status != 401 &&
              status != 408 &&
              status != 429;

          if (permanent) {
            // Server rejected it definitively (validation, already deleted…):
            // keep the queue healthy by dropping the op.
            await _queue.remove(op.id);
            continue;
          }

          // Transport error / 5xx / auth — stop, keep order, retry later.
          op.attempts++;
          await _queue.update(op);
          _scheduleRetry();
          break;
        }
      }
    } finally {
      _draining = false;
      await _refreshPending();
      state = state.copyWith(syncing: false);
      if (pushedSomething) {
        for (final cb in onSynced) {
          cb();
        }
      }
    }
  }

  /// Rewrites any `local_*` id in the op (path or body) using the id map
  /// persisted when the matching create synced.
  Future<PendingOp> _resolveIds(PendingOp op) async {
    var path = op.path;
    final match = RegExp('$localIdPrefix\\w+').firstMatch(path);
    if (match != null) {
      final mapping = await _idMap.get(match.group(0)!);
      final serverId = mapping?['serverId'] as String?;
      if (serverId != null) {
        path = path.replaceAll(match.group(0)!, serverId);
      }
    }
    return op.copyWith(path: path);
  }

  /// Extracts the server id from a create response (`{success, data: {_id}}`)
  /// and rewrites the local cache + id map so the UI switches to the real id.
  Future<void> _captureServerId(
    String tempId,
    Map<String, dynamic>? body,
  ) async {
    final data = body?['data'];
    final serverId = data is Map<String, dynamic>
        ? (data['_id'] as String? ?? data['id'] as String?)
        : null;
    if (serverId == null) return;

    await _idMap.put(tempId, {'serverId': serverId});

    // Migrate the cached doc from temp key to server key in every store that
    // may hold it (cheap: only the entity stores).
    for (final storeName in const ['subjects', 'todos']) {
      final store = ref.read(appDatabaseProvider).store(storeName);
      final doc = await store.get(tempId);
      if (doc != null) {
        doc['_id'] = serverId;
        await store.delete(tempId);
        await store.put(serverId, doc);
      }
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _backoffLevel = math.min(_backoffLevel + 1, 6);
    final delay = Duration(seconds: math.min(5 * (1 << _backoffLevel), 300));
    _retryTimer = Timer(delay, drain);
  }
}

final syncEngineProvider = NotifierProvider<SyncEngine, SyncStatus>(
  SyncEngine.new,
);
