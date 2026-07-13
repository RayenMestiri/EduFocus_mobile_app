import 'package:edufocus_mobile/features/dashboard/domain/dashboard_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardStats.fromJson', () {
    test('parses the /api/stats/dashboard data payload', () {
      final stats = DashboardStats.fromJson(const {
        'user': {'streak': 2, 'longestStreak': 6, 'dailyGoal': 120},
        'today': {
          'date': '2026-07-11',
          'plannedMinutes': 90,
          'studiedMinutes': 45,
          'totalTasks': 4,
          'completedTasks': 1,
          'sessions': 2,
        },
        'week': {'totalMinutes': 300, 'totalSessions': 8, 'averagePerDay': 43},
        'subjects': [
          {
            'id': 's1',
            'name': 'Math',
            'color': '#fbbf24',
            'icon': '📐',
            'totalMinutes': 150,
            'totalSessions': 5,
          },
        ],
      });

      expect(stats.streak, 2);
      expect(stats.dailyGoalMinutes, 120);
      expect(stats.today.progress, closeTo(0.5, 0.001));
      expect(stats.week.totalSessions, 8);
      expect(stats.subjects, hasLength(1));
      expect(stats.subjects.first.colorHex, '#fbbf24');
    });

    test('tolerates empty payload without throwing', () {
      final stats = DashboardStats.fromJson(const {});
      expect(stats.today.plannedMinutes, 0);
      expect(stats.today.progress, 0);
      expect(stats.subjects, isEmpty);
    });
  });

  group('MinutesFormat', () {
    test('formats like the Angular formatTime', () {
      expect(45.asDuration, '45m');
      expect(60.asDuration, '1h');
      expect(85.asDuration, '1h 25m');
      expect(0.asDuration, '0m');
    });
  });
}
