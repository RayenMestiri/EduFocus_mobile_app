import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../dashboard/domain/dashboard_stats.dart';

/// POST /api/ai/study-advice (backend/routes/ai.js).
///
/// The backend expects `{ context, question, history }` where context uses
/// the keys consumed by both the Gemini prompt and the local fallback:
/// todayGoalMinutes, todayStudiedMinutes, completedTodos, totalTodos,
/// subjectBreakdown[{name, goalMinutes, studiedMinutes}].
class AiRepository {
  AiRepository(this._dio);

  final Dio _dio;

  Future<AiAdvice> requestAdvice({
    required DashboardStats stats,
    String question = '',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/study-advice',
        data: {
          'context': {
            'todayGoalMinutes': stats.today.plannedMinutes,
            'todayStudiedMinutes': stats.today.studiedMinutes,
            'completedTodos': stats.today.completedTasks,
            'totalTodos': stats.today.totalTasks,
            'subjectBreakdown': [
              for (final s in stats.subjects)
                {
                  'name': s.name,
                  'goalMinutes': 0,
                  'studiedMinutes': s.totalMinutes,
                },
            ],
          },
          'question': question,
          'history': const [],
        },
      );
      final data = response.data ?? const {};
      return AiAdvice(
        advice: data['advice'] as String? ?? '',
        source: data['source'] as String? ?? 'fallback',
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class AiAdvice {
  const AiAdvice({required this.advice, required this.source});

  final String advice;

  /// `gemini` or `fallback`.
  final String source;
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(apiClientProvider));
});
