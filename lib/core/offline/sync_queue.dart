import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_store.dart';

int _opSeq = 0;

/// Monotonic, lexically-sortable queue key — guarantees strict FIFO replay
/// even for ops enqueued within the same millisecond (web has ms precision).
String newOpId() {
  final ts = DateTime.now().millisecondsSinceEpoch.toString().padLeft(14, '0');
  final seq = (_opSeq++ % 100000).toString().padLeft(5, '0');
  return 'op_${ts}_$seq';
}

/// A mutation captured while offline (or after a failed send), waiting to be
/// replayed against the backend in order.
class PendingOp {
  PendingOp({
    required this.id,
    required this.entity,
    required this.method,
    required this.path,
    this.body,
    this.tempId,
    this.targetId,
    this.attempts = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Queue key (insertion-ordered).
  final String id;

  /// 'subject' | 'todo' | 'session' | 'settings' | 'studyPack'.
  final String entity;

  /// HTTP verb to replay.
  final String method;

  /// API path; may contain a temp id which the engine rewrites once the
  /// matching create has been synced.
  final String path;

  final Map<String, dynamic>? body;

  /// Set on creates performed offline: the fabricated local id whose server
  /// id must be captured from the response.
  final String? tempId;

  /// The entity id this op touches (temp or real) — used for compaction.
  final String? targetId;

  int attempts;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity': entity,
    'method': method,
    'path': path,
    'body': body,
    'tempId': tempId,
    'targetId': targetId,
    'attempts': attempts,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PendingOp.fromJson(Map<String, dynamic> json) => PendingOp(
    id: json['id'] as String,
    entity: json['entity'] as String,
    method: json['method'] as String,
    path: json['path'] as String,
    body: json['body'] == null
        ? null
        : Map<String, dynamic>.from(json['body'] as Map),
    tempId: json['tempId'] as String?,
    targetId: json['targetId'] as String?,
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  PendingOp copyWith({String? path, Map<String, dynamic>? body}) => PendingOp(
    id: id,
    entity: entity,
    method: method,
    path: path ?? this.path,
    body: body ?? this.body,
    tempId: tempId,
    targetId: targetId,
    attempts: attempts,
    createdAt: createdAt,
  );
}

/// Durable FIFO of [PendingOp]s with queue *compaction*: redundant operations
/// on the same entity are merged or cancelled out before they ever hit the
/// network (e.g. create+delete offline → nothing is sent).
class SyncQueue {
  SyncQueue(this._store);

  final DocStore _store;

  Future<List<PendingOp>> all() async {
    final docs = await _store.getAll();
    final ops = [for (final d in docs) PendingOp.fromJson(d)];
    ops.sort((a, b) => a.id.compareTo(b.id));
    return ops;
  }

  Future<int> get length async => (await all()).length;

  Future<void> _save(PendingOp op) => _store.put(op.id, op.toJson());

  Future<void> remove(String opId) => _store.delete(opId);

  Future<void> clear() => _store.clear();

  Future<void> update(PendingOp op) => _save(op);

  /// Enqueues with compaction rules for ops targeting a *local* (unsynced)
  /// entity, keeping the queue minimal and conflict-free:
  ///  · UPDATE on a queued create  → merge fields into the create body.
  ///  · TOGGLE/PATCH on a queued create → merge body the same way.
  ///  · DELETE of a queued create  → drop the create (and its updates); the
  ///    server never hears about the entity at all.
  Future<void> enqueue(PendingOp op) async {
    final targetId = op.targetId;
    if (targetId != null && isLocalId(targetId)) {
      final ops = await all();
      final pendingCreate = ops
          .where((o) => o.tempId == targetId && o.method == 'POST')
          .toList();

      if (pendingCreate.isNotEmpty) {
        final create = pendingCreate.first;

        if (op.method == 'DELETE') {
          for (final o in ops.where((o) => o.targetId == targetId)) {
            await remove(o.id);
          }
          return;
        }

        if (op.body != null) {
          await update(create.copyWith(body: {...?create.body, ...op.body!}));
          return;
        }
      }
    }
    await _save(op);
  }
}

final syncQueueProvider = Provider<SyncQueue>((ref) {
  return SyncQueue(ref.watch(appDatabaseProvider).store('sync_queue'));
});
