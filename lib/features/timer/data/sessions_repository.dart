import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_context.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/utils/dates.dart';

/// Persists completed focus sessions to POST /api/sessions.
///
/// A finished pomodoro is study time the user earned — it must never be
/// lost. If the network is unreachable the session is queued and replayed
/// by the sync engine; the backend then updates subject/user stats exactly
/// as if it had been sent live.
class SessionsRepository {
  SessionsRepository(this._dio, this._offline);

  final Dio _dio;
  final OfflineContext _offline;

  Future<void> saveCompletedSession({
    required String subjectId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final body = {
      'subjectId': subjectId,
      'date': todayYmd(startTime),
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'type': 'pomodoro',
    };

    if (_offline.isOnline) {
      try {
        await _dio.post<Map<String, dynamic>>('/sessions', data: body);
        return;
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }

    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'session',
        method: 'POST',
        path: '/sessions',
        body: body,
        // Sessions created offline never need id remapping — nothing else
        // references them.
      ),
    );
  }
}

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SessionsRepository(
    ref.watch(apiClientProvider),
    offlineContext(ref, 'sessions'),
  );
});
