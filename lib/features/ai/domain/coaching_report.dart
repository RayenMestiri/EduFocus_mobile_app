import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AI Coach — domain models
///
/// The report separates *facts* from *narrative*:
///  · [ProductivityAnalysis] is computed locally by the AnalysisEngine from
///    the user's real data — always accurate, works offline, never invented.
///  · The narrative (diagnosis, motivation) comes from Gemini when available,
///    or from the local RecommendationEngine otherwise.
/// ═══════════════════════════════════════════════════════════════════════════

/// One labelled share of today's/weekly study time.
@immutable
class TimeSlice {
  const TimeSlice({
    required this.label,
    required this.minutes,
    required this.colorHex,
    required this.share,
  });

  final String label;
  final int minutes;
  final String colorHex;

  /// 0..1 of total tracked time.
  final double share;
}

/// A detected issue with an explanation of *why* it was flagged.
@immutable
class Insight {
  const Insight({
    required this.title,
    required this.why,
    this.severity = InsightSeverity.info,
  });

  final String title;
  final String why;
  final InsightSeverity severity;
}

enum InsightSeverity { positive, info, warning, critical }

/// A concrete, actionable next step.
@immutable
class ActionItem {
  const ActionItem({required this.label, this.detail});

  final String label;
  final String? detail;
}

/// Deterministic, data-derived analysis — the factual half of the report.
@immutable
class ProductivityAnalysis {
  const ProductivityAnalysis({
    required this.score,
    required this.scoreReasons,
    required this.strengths,
    required this.weaknesses,
    required this.timeDistribution,
    required this.problems,
    required this.actionPlan,
    required this.tomorrowGoals,
    required this.weeklyTrendLabel,
    this.mostProductiveSubject,
    this.leastActiveSubject,
    this.overdueTodos = 0,
    this.dueCards = 0,
    this.streak = 0,
  });

  /// 0–100 productivity score for today.
  final int score;

  /// Human-readable explanation of each score component (transparency).
  final List<String> scoreReasons;

  final List<Insight> strengths;
  final List<Insight> weaknesses;
  final List<TimeSlice> timeDistribution;
  final List<Insight> problems;
  final List<ActionItem> actionPlan;
  final List<ActionItem> tomorrowGoals;

  /// e.g. « ↑ 22 % vs votre moyenne » — weekly trend in one line.
  final String weeklyTrendLabel;

  final String? mostProductiveSubject;
  final String? leastActiveSubject;
  final int overdueTodos;
  final int dueCards;
  final int streak;

  String get scoreLabel => switch (score) {
    >= 85 => 'Excellente journée',
    >= 65 => 'Bonne dynamique',
    >= 40 => 'Journée correcte',
    >= 15 => 'Départ timide',
    _ => 'Journée à lancer',
  };
}

/// A full coaching exchange rendered in the conversation.
@immutable
class CoachMessage {
  const CoachMessage.user(this.text)
    : isUser = true,
      analysis = null,
      narrative = null,
      source = null;

  const CoachMessage.coach({
    required String this.narrative,
    this.analysis,
    this.source,
  }) : isUser = false,
       text = '';

  final bool isUser;
  final String text;

  /// Present only on full « Analyser ma journée » reports.
  final ProductivityAnalysis? analysis;
  final String? narrative;

  /// 'gemini' | 'local' — shown as a small provenance badge.
  final String? source;
}
