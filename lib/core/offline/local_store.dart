import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Local persistence for the offline-first layer.
///
/// The storage engine is deliberately hidden behind [DocStore] so it can be
/// swapped (sembast today — IndexedDB on web, file on device — Drift/Isar
/// tomorrow) without touching a single repository.
/// ═══════════════════════════════════════════════════════════════════════════

class AppDatabase {
  AppDatabase(this._db);

  final Database _db;

  static Future<AppDatabase> open() async =>
      AppDatabase(await openAppDatabase());

  DocStore store(String name) => DocStore._(_db, name);

  /// Wipes every store — called on logout so no user data leaks between
  /// accounts on a shared device.
  Future<void> clearAll() async {
    await _db.transaction((txn) async {
      for (final name in const [
        'auth',
        'subjects',
        'todos',
        'dashboard',
        'study_packs',
        'settings',
        'sync_queue',
        'id_map',
      ]) {
        await StoreRef<String, Map<String, Object?>>(name).delete(txn);
      }
    });
  }
}

/// A named collection of JSON documents keyed by string id.
class DocStore {
  DocStore._(this._db, String name)
    : _store = StoreRef<String, Map<String, Object?>>(name);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store;

  Future<Map<String, dynamic>?> get(String id) async {
    final rec = await _store.record(id).get(_db);
    return rec == null ? null : Map<String, dynamic>.from(rec);
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final records = await _store.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('_cachedAt')]),
    );
    return [for (final r in records) Map<String, dynamic>.from(r.value)];
  }

  Future<void> put(String id, Map<String, dynamic> doc) {
    return _store.record(id).put(_db, {
      ...doc,
      '_cachedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Replaces the whole collection with a fresh server snapshot in one
  /// transaction — locally-created (unsynced) docs are preserved.
  Future<void> replaceAllSynced(Map<String, Map<String, dynamic>> docs) async {
    await _db.transaction((txn) async {
      final existing = await _store.find(txn);
      var seq = 0;
      for (final r in existing) {
        if (!r.key.startsWith(localIdPrefix)) {
          await _store.record(r.key).delete(txn);
        }
      }
      for (final entry in docs.entries) {
        await _store.record(entry.key).put(txn, {
          ...entry.value,
          // Preserve server ordering on later reads.
          '_cachedAt': DateTime.now().millisecondsSinceEpoch + seq++,
        });
      }
    });
  }

  Future<void> delete(String id) => _store.record(id).delete(_db);

  Future<void> clear() => _store.delete(_db);
}

/// Prefix for ids fabricated offline; the sync engine swaps them for real
/// server ids once the create succeeds.
const localIdPrefix = 'local_';

final _rng = Random();

String newLocalId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _rng.nextInt(1 << 30).toRadixString(36);
  return '$localIdPrefix$now$salt';
}

bool isLocalId(String id) => id.startsWith(localIdPrefix);

/// Opened in `main()` before `runApp` and injected here.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden in main()');
});
