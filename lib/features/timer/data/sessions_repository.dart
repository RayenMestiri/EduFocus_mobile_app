import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/dates.dart';

/// Persists completed focus sessions to POST /api/sessions.
///
/// The backend derives `duration` and `completed` from start/end times
/// (StudySession pre-save hook) and then updates subject + user stats —
/// identical to what happens when the Angular timer finishes.
class SessionsRepository {
  SessionsRepository(this._dio);

  final Dio _dio;

  Future<void> saveCompletedSession({
    required String subjectId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/sessions',
        data: {
          'subjectId': subjectId,
          'date': todayYmd(startTime),
          'startTime': startTime.toUtc().toIso8601String(),
          'endTime': endTime.toUtc().toIso8601String(),
          'type': 'pomodoro',
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SessionsRepository(ref.watch(apiClientProvider));
});
