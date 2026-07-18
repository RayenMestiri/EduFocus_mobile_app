import '../../dashboard/domain/dashboard_stats.dart';
import '../../profile/data/settings_repository.dart';
import '../../study_hub/domain/study_pack.dart';
import '../../subjects/domain/subject.dart';
import '../../todos/domain/todo.dart';
import '../domain/coaching_report.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Analysis Engine — pure Dart, fully deterministic, unit-testable.
///
/// Turns every data source the app owns (sessions, tasks, subjects, SRS
/// decks, streaks, weekly history, timer settings) into a transparent
/// [ProductivityAnalysis]: each number comes with the *why* behind it, so
/// the coach never asserts something it cannot justify.
/// ═══════════════════════════════════════════════════════════════════════════
abstract final class AnalysisEngine {
  static ProductivityAnalysis compute({
    required DashboardStats stats,
    required List<Todo> todos,
    required List<Subject> subjects,
    required List<StudyPack> packs,
    required TimerSettings settings,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final t = stats.today;

    // ── Task hygiene ──
    final todayYmd = _ymd(today);
    final overdue = todos
        .where(
          (td) =>
              !td.done && td.date.isNotEmpty && td.date.compareTo(todayYmd) < 0,
        )
        .length;
    final pendingToday = todos
        .where((td) => !td.done && td.date == todayYmd)
        .length;

    // ── SRS pressure ──
    var dueCards = 0;
    var masteredCards = 0;
    var totalCards = 0;
    for (final p in packs) {
      dueCards += p.dueCount;
      masteredCards += p.countByState('mastered');
      totalCards += p.cardCount;
    }

    // ── Score (0–100) with explainable components ──
    final reasons = <String>[];
    var score = 0.0;

    // 1. Progress toward today's planned minutes — 40 pts.
    if (t.plannedMinutes > 0) {
      final part = 40 * t.progress;
      score += part;
      reasons.add(
        'Objectif du jour : ${t.studiedMinutes.asDuration} sur '
        '${t.plannedMinutes.asDuration} (+${part.round()} pts)',
      );
    } else if (t.studiedMinutes > 0) {
      // No plan but real work still counts (capped).
      final part = (t.studiedMinutes / 60 * 20).clamp(0, 30).toDouble();
      score += part;
      reasons.add(
        '${t.studiedMinutes.asDuration} étudiées sans planning '
        '(+${part.round()} pts)',
      );
    } else {
      reasons.add('Aucune minute d\'étude enregistrée aujourd\'hui (+0 pt)');
    }

    // 2. Tasks completed — 25 pts.
    if (t.totalTasks > 0) {
      final part = 25 * (t.completedTasks / t.totalTasks);
      score += part;
      reasons.add(
        'Tâches : ${t.completedTasks}/${t.totalTasks} terminées '
        '(+${part.round()} pts)',
      );
    }

    // 3. Focus sessions vs personal goal — 20 pts.
    final sessionGoal = settings.dailySessionsGoal.clamp(1, 30);
    final sessPart = 20 * (t.sessions / sessionGoal).clamp(0, 1);
    score += sessPart;
    reasons.add(
      'Sessions focus : ${t.sessions}/$sessionGoal '
      '(+${sessPart.round()} pts)',
    );

    // 4. Streak bonus — 15 pts (caps at 7 days).
    final streakPart = 15 * (stats.streak / 7).clamp(0, 1);
    score += streakPart;
    if (stats.streak > 0) {
      reasons.add(
        'Série de ${stats.streak} jour${stats.streak > 1 ? 's' : ''} '
        '(+${streakPart.round()} pts)',
      );
    }

    final finalScore = score.round().clamp(0, 100);

    // ── Time distribution across subjects (lifetime minutes as weights) ──
    final activeSubjects =
        stats.subjects.where((s) => s.totalMinutes > 0).toList()
          ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
    final totalMinutes = activeSubjects.fold<int>(
      0,
      (sum, s) => sum + s.totalMinutes,
    );
    final distribution = [
      for (final s in activeSubjects.take(5))
        TimeSlice(
          label: s.name,
          minutes: s.totalMinutes,
          colorHex: s.colorHex,
          share: totalMinutes == 0 ? 0 : s.totalMinutes / totalMinutes,
        ),
    ];

    final mostProductive = activeSubjects.isNotEmpty
        ? activeSubjects.first.name
        : null;
    String? leastActive;
    if (stats.subjects.length > 1) {
      final sorted = [...stats.subjects]
        ..sort((a, b) => a.totalMinutes.compareTo(b.totalMinutes));
      leastActive = sorted.first.name;
    }

    // ── Strengths ──
    final strengths = <Insight>[];
    if (stats.streak >= 3) {
      strengths.add(
        Insight(
          title: 'Régularité solide',
          why:
              '${stats.streak} jours d\'étude consécutifs — la constance est le '
              'meilleur prédicteur de rétention.',
          severity: InsightSeverity.positive,
        ),
      );
    }
    if (t.plannedMinutes > 0 && t.progress >= 1) {
      strengths.add(
        const Insight(
          title: 'Objectif du jour atteint',
          why: '100 % du temps planifié a été réalisé.',
          severity: InsightSeverity.positive,
        ),
      );
    }
    if (t.totalTasks > 0 && t.completedTasks == t.totalTasks) {
      strengths.add(
        const Insight(
          title: 'Toutes les tâches du jour terminées',
          why: 'Liste du jour entièrement cochée.',
          severity: InsightSeverity.positive,
        ),
      );
    }
    if (masteredCards > 0 && totalCards > 0) {
      final pct = (masteredCards / totalCards * 100).round();
      strengths.add(
        Insight(
          title: '$pct % de cartes maîtrisées',
          why:
              '$masteredCards cartes sur $totalCards ont atteint le stade '
              '« maîtrisée » dans vos paquets SRS.',
          severity: InsightSeverity.positive,
        ),
      );
    }
    if (stats.week.totalMinutes > 0 &&
        stats.week.averagePerDay >= stats.dailyGoalMinutes &&
        stats.dailyGoalMinutes > 0) {
      strengths.add(
        const Insight(
          title: 'Semaine au-dessus de l\'objectif',
          why: 'Votre moyenne quotidienne dépasse votre objectif personnel.',
          severity: InsightSeverity.positive,
        ),
      );
    }

    // ── Weaknesses & problems ──
    final weaknesses = <Insight>[];
    final problems = <Insight>[];

    if (overdue > 0) {
      problems.add(
        Insight(
          title: '$overdue tâche${overdue > 1 ? 's' : ''} en retard',
          why:
              'Des tâches datées d\'avant aujourd\'hui ne sont pas terminées — '
              'elles s\'accumulent et pèsent sur la motivation.',
          severity: overdue >= 3
              ? InsightSeverity.critical
              : InsightSeverity.warning,
        ),
      );
    }
    if (dueCards > 20) {
      problems.add(
        Insight(
          title: '$dueCards cartes à réviser',
          why:
              'La file SRS dépasse 20 cartes : chaque jour d\'attente augmente '
              'le taux d\'oubli et la charge de rattrapage.',
          severity: InsightSeverity.warning,
        ),
      );
    } else if (dueCards > 0) {
      weaknesses.add(
        Insight(
          title: '$dueCards cartes dues',
          why: 'Une courte session de révision suffirait à vider la file.',
          severity: InsightSeverity.info,
        ),
      );
    }
    if (t.sessions == 0 && today.hour >= 12) {
      weaknesses.add(
        const Insight(
          title: 'Aucune session focus aujourd\'hui',
          why:
              'La journée est entamée sans session Pomodoro — un bloc de 25 min '
              'suffit à enclencher la dynamique.',
          severity: InsightSeverity.warning,
        ),
      );
    }
    if (distribution.isNotEmpty &&
        distribution.first.share > .6 &&
        stats.subjects.length > 1) {
      weaknesses.add(
        Insight(
          title: 'Temps concentré sur ${distribution.first.label}',
          why:
              '${(distribution.first.share * 100).round()} % de votre temps va '
              'à une seule matière — ${leastActive ?? 'les autres'} reste(nt) '
              'en retrait.',
          severity: InsightSeverity.info,
        ),
      );
    }
    if (stats.streak == 0 && stats.longestStreak >= 3) {
      weaknesses.add(
        Insight(
          title: 'Série interrompue',
          why:
              'Votre record est de ${stats.longestStreak} jours — une session '
              'aujourd\'hui relance le compteur.',
          severity: InsightSeverity.info,
        ),
      );
    }

    // ── Action plan (today) ──
    final plan = <ActionItem>[];
    if (t.plannedMinutes > 0 && t.progress < 1) {
      final remaining = t.plannedMinutes - t.studiedMinutes;
      plan.add(
        ActionItem(
          label: 'Terminer les ${remaining.asDuration} restantes',
          detail: mostProductive != null
              ? 'Commencez par $mostProductive pour rester en terrain connu.'
              : null,
        ),
      );
    }
    if (overdue > 0) {
      plan.add(
        ActionItem(
          label: 'Rattraper $overdue tâche${overdue > 1 ? 's' : ''} en retard',
          detail: 'Traitez d\'abord la plus courte pour créer de l\'élan.',
        ),
      );
    }
    if (pendingToday > 0) {
      plan.add(
        ActionItem(
          label:
              'Cocher $pendingToday tâche${pendingToday > 1 ? 's' : ''} du jour',
        ),
      );
    }
    if (dueCards > 0) {
      final batch = dueCards.clamp(1, 20);
      plan.add(
        ActionItem(
          label: 'Réviser $batch cartes SRS',
          detail:
              'Mode examen dans le Study Hub — ${(batch * 0.5).ceil()} min '
              'environ.',
        ),
      );
    }
    if (plan.isEmpty) {
      plan.add(
        const ActionItem(
          label: 'Journée au propre — préparez demain',
          detail: 'Planifiez vos blocs de demain pendant que tout est frais.',
        ),
      );
    }

    // ── Tomorrow ──
    final tomorrow = <ActionItem>[
      ActionItem(
        label: t.plannedMinutes > 0
            ? 'Planifier ${t.plannedMinutes.asDuration} (même volume)'
            : 'Planifier au moins 2 blocs de ${settings.pomodoroLength} min',
      ),
      if (leastActive != null)
        ActionItem(label: 'Donner un bloc à $leastActive (matière délaissée)'),
      if (stats.streak > 0)
        ActionItem(
          label:
              'Protéger la série (jour ${stats.streak + 1}) avec une session '
              'avant midi',
        ),
    ];

    // ── Weekly trend ──
    final String trend;
    if (stats.dailyGoalMinutes > 0 && stats.week.averagePerDay > 0) {
      final delta =
          ((stats.week.averagePerDay / stats.dailyGoalMinutes) - 1) * 100;
      trend = delta >= 0
          ? '↑ ${delta.round()} % au-dessus de votre objectif quotidien'
          : '↓ ${delta.abs().round()} % sous votre objectif quotidien';
    } else if (stats.week.totalMinutes > 0) {
      trend =
          '${stats.week.totalMinutes.asDuration} cette semaine · moyenne '
          '${stats.week.averagePerDay.asDuration}/jour';
    } else {
      trend = 'Pas encore de données cette semaine';
    }

    return ProductivityAnalysis(
      score: finalScore,
      scoreReasons: reasons,
      strengths: strengths,
      weaknesses: weaknesses,
      timeDistribution: distribution,
      problems: problems,
      actionPlan: plan,
      tomorrowGoals: tomorrow,
      weeklyTrendLabel: trend,
      mostProductiveSubject: mostProductive,
      leastActiveSubject: leastActive,
      overdueTodos: overdue,
      dueCards: dueCards,
      streak: stats.streak,
    );
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
