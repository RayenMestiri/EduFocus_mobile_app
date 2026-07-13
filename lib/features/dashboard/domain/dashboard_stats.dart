import 'package:flutter/foundation.dart';

/// Immutable read models for GET /api/stats/dashboard
/// (backend/routes/stats.js — envelope `{ success, data: {...} }`).
@immutable
class DashboardStats {
  const DashboardStats({
    required this.today,
    required this.week,
    required this.subjects,
    required this.streak,
    required this.longestStreak,
    required this.dailyGoalMinutes,
  });

  final TodayStats today;
  final WeekStats week;
  final List<SubjectSummary> subjects;
  final int streak;
  final int longestStreak;
  final int dailyGoalMinutes;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return DashboardStats(
      today: TodayStats.fromJson(
        json['today'] as Map<String, dynamic>? ?? const {},
      ),
      week: WeekStats.fromJson(
        json['week'] as Map<String, dynamic>? ?? const {},
      ),
      subjects: (json['subjects'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubjectSummary.fromJson)
          .toList(growable: false),
      streak: (user['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (user['longestStreak'] as num?)?.toInt() ?? 0,
      dailyGoalMinutes: (user['dailyGoal'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class TodayStats {
  const TodayStats({
    this.plannedMinutes = 0,
    this.studiedMinutes = 0,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.sessions = 0,
  });

  final int plannedMinutes;
  final int studiedMinutes;
  final int totalTasks;
  final int completedTasks;
  final int sessions;

  factory TodayStats.fromJson(Map<String, dynamic> json) {
    return TodayStats(
      plannedMinutes: (json['plannedMinutes'] as num?)?.toInt() ?? 0,
      studiedMinutes: (json['studiedMinutes'] as num?)?.toInt() ?? 0,
      totalTasks: (json['totalTasks'] as num?)?.toInt() ?? 0,
      completedTasks: (json['completedTasks'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }

  /// 0..1 progress toward today's planned minutes (0 when nothing planned).
  double get progress =>
      plannedMinutes <= 0 ? 0 : (studiedMinutes / plannedMinutes).clamp(0, 1);
}

@immutable
class WeekStats {
  const WeekStats({
    this.totalMinutes = 0,
    this.totalSessions = 0,
    this.averagePerDay = 0,
  });

  final int totalMinutes;
  final int totalSessions;
  final int averagePerDay;

  factory WeekStats.fromJson(Map<String, dynamic> json) {
    return WeekStats(
      totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      averagePerDay: (json['averagePerDay'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class SubjectSummary {
  const SubjectSummary({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.icon,
    this.totalMinutes = 0,
    this.totalSessions = 0,
  });

  final String id;
  final String name;

  /// Hex string as stored by the backend (e.g. `#8b5cf6`).
  final String colorHex;

  /// Subject icon — the backend stores either an emoji or a Material icon
  /// name string; rendered as text on mobile.
  final String icon;
  final int totalMinutes;
  final int totalSessions;

  factory SubjectSummary.fromJson(Map<String, dynamic> json) {
    return SubjectSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      colorHex: json['color'] as String? ?? '#8b5cf6',
      icon: json['icon'] as String? ?? '📚',
      totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Formats minutes as `1h 25m` / `45m`, mirroring the Angular formatTime.
extension MinutesFormat on int {
  String get asDuration {
    final h = this ~/ 60;
    final m = this % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
