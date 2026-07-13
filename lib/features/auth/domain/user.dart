import 'package:flutter/foundation.dart';

/// Immutable domain model for the authenticated user.
///
/// Shape matches the `user` object returned by POST /api/auth/login,
/// POST /api/auth/register and GET /api/auth/me.
@immutable
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.role = 'user',
    this.stats,
  });

  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String role;
  final UserStats? stats;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? json['_id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String?,
      role: json['role'] as String? ?? 'user',
      stats: json['stats'] is Map<String, dynamic>
          ? UserStats.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
    );
  }

  String get initial => name.isEmpty ? 'U' : name[0].toUpperCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is User && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Matches `User.stats` in backend/models/User.js.
@immutable
class UserStats {
  const UserStats({
    this.totalStudyMinutes = 0,
    this.totalSessions = 0,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.points = 0,
    this.streak = 0,
    this.longestStreak = 0,
    this.lastStudyDate,
  });

  final int totalStudyMinutes;
  final int totalSessions;
  final int totalTasks;
  final int completedTasks;
  final int points;
  final int streak;
  final int longestStreak;
  final DateTime? lastStudyDate;

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalStudyMinutes: (json['totalStudyMinutes'] as num?)?.toInt() ?? 0,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      totalTasks: (json['totalTasks'] as num?)?.toInt() ?? 0,
      completedTasks: (json['completedTasks'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastStudyDate: json['lastStudyDate'] != null
          ? DateTime.tryParse(json['lastStudyDate'] as String)
          : null,
    );
  }
}
