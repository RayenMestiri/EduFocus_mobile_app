import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/domain/dashboard_stats.dart';
import '../../profile/data/settings_repository.dart';
import '../../study_hub/data/study_packs_repository.dart';
import '../../study_hub/domain/study_pack.dart';
import '../../subjects/data/subjects_repository.dart';
import '../../subjects/domain/subject.dart';
import '../../todos/data/todos_repository.dart';
import '../../todos/domain/todo.dart';
import '../domain/coaching_report.dart';
import 'analysis_engine.dart';
import 'prompt_builder.dart';
import 'recommendation_engine.dart';

/// Result of a full coaching analysis.
class CoachingResult {
  const CoachingResult({
    required this.analysis,
    required this.narrative,
    required this.source,
  });

  final ProductivityAnalysis analysis;
  final String narrative;

  /// 'gemini' when the narrative came from the model, 'local' otherwise.
  final String source;
}

/// Orchestrates the coaching pipeline:
/// data gathering → AnalysisEngine → PromptBuilder → Gemini (via the
/// existing backend endpoint) → narrative, with the RecommendationEngine as
/// a seamless local fallback so the coach never goes silent.
class AiRepository {
  AiRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  /// Pulls every available data source (all offline-cached) and computes the
  /// factual analysis locally.
  Future<ProductivityAnalysis> computeAnalysis() async {
    final results = await Future.wait<Object>([
      _ref.read(dashboardRepositoryProvider).fetch(),
      _ref.read(todosRepositoryProvider).list(),
      _ref.read(subjectsRepositoryProvider).list(),
      _ref.read(studyPacksRepositoryProvider).list(),
      _ref.read(settingsRepositoryProvider).fetch(),
    ]);

    return AnalysisEngine.compute(
      stats: results[0] as DashboardStats,
      todos: (results[1] as List).cast<Todo>(),
      subjects: (results[2] as List).cast<Subject>(),
      packs: (results[3] as List).cast<StudyPack>(),
      settings: results[4] as TimerSettings,
    );
  }

  /// Full « Analyser ma journée » report.
  Future<CoachingResult> analyze() async {
    final stats = await _ref.read(dashboardRepositoryProvider).fetch();
    final analysis = await computeAnalysis();

    if (_ref.read(connectivityProvider)) {
      final prompt = PromptBuilder.buildAnalysisPrompt(
        analysis: analysis,
        stats: stats,
      );
      final narrative = await _askBackend(prompt, stats: statsContext(stats));
      if (narrative != null) {
        return CoachingResult(
          analysis: analysis,
          narrative: narrative.$1,
          source: narrative.$2,
        );
      }
    }

    return CoachingResult(
      analysis: analysis,
      narrative: RecommendationEngine.buildNarrative(analysis),
      source: 'local',
    );
  }

  /// Free-form follow-up question, grounded in the latest analysis.
  Future<CoachingResult> ask(
    String question, {
    ProductivityAnalysis? lastAnalysis,
  }) async {
    final analysis = lastAnalysis ?? await computeAnalysis();

    if (_ref.read(connectivityProvider)) {
      final prompt = PromptBuilder.buildChatPrompt(
        question: question,
        analysis: analysis,
      );
      final narrative = await _askBackend(prompt);
      if (narrative != null) {
        return CoachingResult(
          analysis: analysis,
          narrative: narrative.$1,
          source: narrative.$2,
        );
      }
    }

    return CoachingResult(
      analysis: analysis,
      narrative:
          'Hors ligne pour le moment — voici ce que disent vos données : '
          'score ${analysis.score}/100, ${analysis.dueCards} cartes à '
          'réviser, ${analysis.overdueTodos} tâche(s) en retard. '
          'L\'action la plus utile maintenant : '
          '${analysis.actionPlan.first.label.toLowerCase()}.',
      source: 'local',
    );
  }

  /// The backend endpoint wraps Gemini and returns
  /// `{success, source: 'gemini'|'fallback', advice}`.
  Future<(String, String)?> _askBackend(
    String prompt, {
    Map<String, dynamic>? stats,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/study-advice',
        data: {
          'context': stats ?? const <String, dynamic>{},
          'question': prompt,
          'history': const [],
        },
      );
      final advice = response.data?['advice'] as String?;
      final source = response.data?['source'] as String? ?? 'fallback';
      if (advice == null || advice.trim().isEmpty) return null;
      // The backend's own generic fallback is weaker than our local engine —
      // prefer ours in that case.
      if (source != 'gemini') return null;
      return (advice.trim(), 'gemini');
    } on DioException {
      return null;
    }
  }

  /// Context payload matching what the backend fallback expects.
  Map<String, dynamic> statsContext(DashboardStats stats) => {
    'todayGoalMinutes': stats.today.plannedMinutes,
    'todayStudiedMinutes': stats.today.studiedMinutes,
    'completedTodos': stats.today.completedTasks,
    'totalTodos': stats.today.totalTasks,
  };
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(apiClientProvider), ref);
});
