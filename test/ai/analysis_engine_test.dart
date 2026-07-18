import 'package:edufocus_mobile/features/ai/data/analysis_engine.dart';
import 'package:edufocus_mobile/features/ai/data/recommendation_engine.dart';
import 'package:edufocus_mobile/features/dashboard/domain/dashboard_stats.dart';
import 'package:edufocus_mobile/features/profile/data/settings_repository.dart';
import 'package:edufocus_mobile/features/todos/domain/todo.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardStats _stats({
  int planned = 120,
  int studied = 60,
  int totalTasks = 4,
  int completedTasks = 2,
  int sessions = 2,
  int streak = 3,
}) {
  return DashboardStats(
    today: TodayStats(
      plannedMinutes: planned,
      studiedMinutes: studied,
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      sessions: sessions,
    ),
    week: const WeekStats(
      totalMinutes: 300,
      totalSessions: 8,
      averagePerDay: 43,
    ),
    subjects: const [
      SubjectSummary(
        id: 's1',
        name: 'Maths',
        colorHex: '#8b5cf6',
        icon: '📐',
        totalMinutes: 200,
        totalSessions: 6,
      ),
      SubjectSummary(
        id: 's2',
        name: 'Physique',
        colorHex: '#22d3ee',
        icon: '🧪',
        totalMinutes: 40,
        totalSessions: 2,
      ),
    ],
    streak: streak,
    longestStreak: 6,
    dailyGoalMinutes: 60,
  );
}

void main() {
  final fixedNow = DateTime(2026, 7, 15, 14); // afternoon, deterministic

  test('score rewards progress, tasks, sessions and streak transparently', () {
    final analysis = AnalysisEngine.compute(
      stats: _stats(),
      todos: const [],
      subjects: const [],
      packs: const [],
      settings: const TimerSettings(dailySessionsGoal: 4),
      now: fixedNow,
    );

    // 40*(60/120)=20 + 25*(2/4)=12.5 + 20*(2/4)=10 + 15*(3/7)≈6.4 → ≈49.
    expect(analysis.score, inInclusiveRange(45, 53));
    expect(analysis.scoreReasons.length, greaterThanOrEqualTo(3));
    // Every component is explained — transparency requirement.
    expect(
      analysis.scoreReasons.join(),
      allOf(contains('Objectif'), contains('Tâches'), contains('Sessions')),
    );
  });

  test('perfect day scores at the top and flags no problems', () {
    final analysis = AnalysisEngine.compute(
      stats: _stats(
        planned: 120,
        studied: 120,
        totalTasks: 3,
        completedTasks: 3,
        sessions: 4,
        streak: 7,
      ),
      todos: const [],
      subjects: const [],
      packs: const [],
      settings: const TimerSettings(dailySessionsGoal: 4),
      now: fixedNow,
    );

    expect(analysis.score, 100);
    expect(analysis.problems, isEmpty);
    expect(analysis.strengths, isNotEmpty);
  });

  test('overdue todos become a flagged problem with an explanation', () {
    final analysis = AnalysisEngine.compute(
      stats: _stats(),
      todos: const [
        Todo(id: '1', title: 'Vieille tâche', date: '2026-07-10', done: false),
        Todo(id: '2', title: 'Autre', date: '2026-07-12', done: false),
        Todo(id: '3', title: 'Faite', date: '2026-07-10', done: true),
      ],
      subjects: const [],
      packs: const [],
      settings: const TimerSettings(),
      now: fixedNow,
    );

    expect(analysis.overdueTodos, 2);
    final problem = analysis.problems.firstWhere(
      (p) => p.title.contains('en retard'),
    );
    expect(problem.why, isNotEmpty);
    // The action plan picks it up.
    expect(
      analysis.actionPlan.map((a) => a.label).join(),
      contains('en retard'),
    );
  });

  test('narrative varies with the data (no repeated advice)', () {
    final a1 = AnalysisEngine.compute(
      stats: _stats(studied: 0, sessions: 0),
      todos: const [],
      subjects: const [],
      packs: const [],
      settings: const TimerSettings(),
      now: fixedNow,
    );
    final a2 = AnalysisEngine.compute(
      stats: _stats(studied: 120, sessions: 4, completedTasks: 4),
      todos: const [],
      subjects: const [],
      packs: const [],
      settings: const TimerSettings(),
      now: fixedNow,
    );

    final n1 = RecommendationEngine.buildNarrative(a1, now: fixedNow);
    final n2 = RecommendationEngine.buildNarrative(a2, now: fixedNow);
    expect(n1, isNot(equals(n2)));
    expect(n1.split('\n\n').length, greaterThanOrEqualTo(3));
  });

  test('action plan is never empty', () {
    final analysis = AnalysisEngine.compute(
      stats: _stats(
        planned: 0,
        studied: 0,
        totalTasks: 0,
        completedTasks: 0,
        sessions: 0,
        streak: 0,
      ),
      todos: const [],
      subjects: const [],
      packs: const [],
      settings: const TimerSettings(),
      now: fixedNow,
    );
    expect(analysis.actionPlan, isNotEmpty);
    expect(analysis.tomorrowGoals, isNotEmpty);
  });
}
