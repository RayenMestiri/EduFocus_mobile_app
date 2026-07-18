import 'package:edufocus_mobile/core/offline/local_store.dart';
import 'package:edufocus_mobile/core/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<SyncQueue> _freshQueue() async {
  final db = await databaseFactoryMemory.openDatabase(
    'test_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return SyncQueue(AppDatabase(db).store('sync_queue'));
}

void main() {
  group('PendingOp', () {
    test('round-trips through JSON', () {
      final op = PendingOp(
        id: newOpId(),
        entity: 'todo',
        method: 'POST',
        path: '/todos',
        body: {'title': 'Réviser', 'priority': 'high'},
        tempId: 'local_abc',
        targetId: 'local_abc',
      );
      final restored = PendingOp.fromJson(op.toJson());
      expect(restored.id, op.id);
      expect(restored.entity, 'todo');
      expect(restored.method, 'POST');
      expect(restored.path, '/todos');
      expect(restored.body?['title'], 'Réviser');
      expect(restored.tempId, 'local_abc');
    });
  });

  group('SyncQueue', () {
    test('preserves strict FIFO order', () async {
      final queue = await _freshQueue();
      for (var i = 0; i < 5; i++) {
        await queue.enqueue(
          PendingOp(
            id: newOpId(),
            entity: 'todo',
            method: 'POST',
            path: '/todos',
            body: {'title': 'T$i'},
          ),
        );
      }
      final ops = await queue.all();
      expect(ops.map((o) => o.body?['title']).toList(), [
        'T0',
        'T1',
        'T2',
        'T3',
        'T4',
      ]);
    });

    test('merges an update into a pending offline create', () async {
      final queue = await _freshQueue();
      const tempId = '${localIdPrefix}abc';
      await queue.enqueue(
        PendingOp(
          id: newOpId(),
          entity: 'subject',
          method: 'POST',
          path: '/subjects',
          body: {'name': 'Maths', 'color': '#111111'},
          tempId: tempId,
          targetId: tempId,
        ),
      );
      await queue.enqueue(
        PendingOp(
          id: newOpId(),
          entity: 'subject',
          method: 'PUT',
          path: '/subjects/$tempId',
          body: {'name': 'Maths avancées'},
          targetId: tempId,
        ),
      );

      final ops = await queue.all();
      expect(ops, hasLength(1), reason: 'update folded into the create');
      expect(ops.single.method, 'POST');
      expect(ops.single.body?['name'], 'Maths avancées');
      expect(ops.single.body?['color'], '#111111');
    });

    test('create + delete offline cancel out entirely', () async {
      final queue = await _freshQueue();
      const tempId = '${localIdPrefix}xyz';
      await queue.enqueue(
        PendingOp(
          id: newOpId(),
          entity: 'todo',
          method: 'POST',
          path: '/todos',
          body: {'title': 'Éphémère'},
          tempId: tempId,
          targetId: tempId,
        ),
      );
      await queue.enqueue(
        PendingOp(
          id: newOpId(),
          entity: 'todo',
          method: 'DELETE',
          path: '/todos/$tempId',
          targetId: tempId,
        ),
      );

      expect(
        await queue.all(),
        isEmpty,
        reason:
            'the server never hears about an entity created then '
            'deleted while offline',
      );
    });

    test('toggle on a pending create stays queued after it (FIFO)', () async {
      final queue = await _freshQueue();
      const tempId = '${localIdPrefix}tgl';
      await queue.enqueue(
        PendingOp(
          id: newOpId(),
          entity: 'todo',
          method: 'POST',
          path: '/todos',
          body: {'title': 'À cocher'},
          tempId: tempId,
          targetId: tempId,
        ),
      );
      await queue.enqueue(
        PendingOp(
          id: newOpId(),
          entity: 'todo',
          method: 'PATCH',
          path: '/todos/$tempId/toggle',
          targetId: tempId,
        ),
      );

      final ops = await queue.all();
      expect(ops, hasLength(2));
      expect(ops.first.method, 'POST');
      expect(ops.last.method, 'PATCH');
    });
  });
}
