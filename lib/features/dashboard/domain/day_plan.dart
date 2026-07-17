import 'package:flutter/foundation.dart';

@immutable
class DayPlanSubjectSession {
  const DayPlanSubjectSession({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.completed = false,
    this.note,
  });

  final String? id;
  final String startTime;
  final String endTime;
  final int duration;
  final bool completed;
  final String? note;

  factory DayPlanSubjectSession.fromJson(Map<String, dynamic> json) {
    return DayPlanSubjectSession(
      id: json['_id'] as String? ?? json['id'] as String?,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'duration': duration,
      'completed': completed,
      if (note != null) 'note': note,
    };
  }
}

@immutable
class DayPlanSubject {
  const DayPlanSubject({
    required this.subjectId,
    this.subjectName = 'Matière',
    this.subjectColor = '#6366f1',
    this.subjectIcon = 'book',
    this.goalMinutes = 60,
    this.studiedMinutes = 0,
    this.priority = 'medium',
    this.sessions = const [],
  });

  final String subjectId;
  final String subjectName;
  final String subjectColor;
  final String subjectIcon;
  final int goalMinutes;
  final int studiedMinutes;
  final String priority; // 'low' | 'medium' | 'high'
  final List<DayPlanSubjectSession> sessions;

  factory DayPlanSubject.fromJson(Map<String, dynamic> json) {
    // subjectId populated check
    String subId = '';
    String subName = 'Matière';
    String subColor = '#6366f1';
    String subIcon = 'book';

    final subObject = json['subjectId'];
    if (subObject is Map<String, dynamic>) {
      subId = subObject['_id'] as String? ?? subObject['id'] as String? ?? '';
      subName = subObject['name'] as String? ?? 'Matière';
      subColor =
          subObject['colorHex'] as String? ??
          subObject['color'] as String? ??
          '#6366f1';
      subIcon = subObject['icon'] as String? ?? 'book';
    } else if (subObject is String) {
      subId = subObject;
    }

    return DayPlanSubject(
      subjectId: subId,
      subjectName: subName,
      subjectColor: subColor,
      subjectIcon: subIcon,
      goalMinutes: (json['goalMinutes'] as num?)?.toInt() ?? 60,
      studiedMinutes: (json['studiedMinutes'] as num?)?.toInt() ?? 0,
      priority: json['priority'] as String? ?? 'medium',
      sessions: (json['sessions'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DayPlanSubjectSession.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subjectId': subjectId,
      'goalMinutes': goalMinutes,
      'studiedMinutes': studiedMinutes,
      'priority': priority,
      'sessions': sessions.map((s) => s.toJson()).toList(),
    };
  }
}

@immutable
class DayPlan {
  const DayPlan({
    required this.id,
    required this.date,
    this.subjects = const [],
    this.notes,
    this.mood,
    this.productivity,
    this.achievements,
  });

  final String id;
  final String date; // YYYY-MM-DD
  final List<DayPlanSubject> subjects;
  final String? notes;
  final String? mood;
  final int? productivity;
  final String? achievements;

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    final achievementsRaw = json['achievements'];
    String? achievementsStr;
    if (achievementsRaw is List) {
      achievementsStr = achievementsRaw.map((e) => e.toString()).join('\n');
    } else if (achievementsRaw is String) {
      achievementsStr = achievementsRaw;
    }

    return DayPlan(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      subjects: (json['subjects'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DayPlanSubject.fromJson)
          .toList(),
      notes: json['notes'] as String?,
      mood: json['mood'] as String?,
      productivity: (json['productivity'] as num?)?.toInt(),
      achievements: achievementsStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'subjects': subjects.map((s) => s.toJson()).toList(),
      if (notes != null) 'notes': notes,
      if (mood != null) 'mood': mood,
      if (productivity != null) 'productivity': productivity,
      if (achievements != null) 'achievements': achievements,
    };
  }

  int get totalGoalMinutes => subjects.fold(0, (sum, s) => sum + s.goalMinutes);
  int get totalStudiedMinutes =>
      subjects.fold(0, (sum, s) => sum + s.studiedMinutes);
  double get progress => totalGoalMinutes > 0
      ? (totalStudiedMinutes / totalGoalMinutes).clamp(0.0, 1.0)
      : 0.0;
}
