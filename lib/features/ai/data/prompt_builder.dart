import '../../dashboard/domain/dashboard_stats.dart';
import '../domain/coaching_report.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Prompt Builder — turns the local analysis into a rich Gemini prompt.
///
/// The metrics are computed locally (they're facts); Gemini's job is the
/// *narrative*: diagnosis, prioritisation and motivation. A rotating
/// coaching angle keyed to the weekday keeps consecutive analyses from
/// converging on the same advice.
/// ═══════════════════════════════════════════════════════════════════════════
abstract final class PromptBuilder {
  static const _angles = [
    'la gestion de l\'énergie et des pauses',
    'la priorisation impitoyable (une seule chose à la fois)',
    'la régularité plutôt que l\'intensité',
    'la méthode de révision active (SRS, rappel libre)',
    'l\'équilibre entre les matières',
    'la préparation de la journée de demain',
    'la réduction des frictions au démarrage',
  ];

  static String coachingAngle(DateTime now) =>
      _angles[(now.weekday + now.day) % _angles.length];

  static String buildAnalysisPrompt({
    required ProductivityAnalysis analysis,
    required DashboardStats stats,
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final angle = coachingAngle(date);

    final buffer = StringBuffer()
      ..writeln(
        'Tu es le coach d\'étude personnel de l\'utilisateur dans EduFocus. '
        'Tu reçois une analyse factuelle déjà calculée à partir de ses '
        'vraies données. Ne recalcule rien, n\'invente aucun chiffre.',
      )
      ..writeln()
      ..writeln('RÈGLES DE STYLE :')
      ..writeln('- Français naturel, tutoiement chaleureux mais pro.')
      ..writeln('- 4 paragraphes courts maximum, pas de listes à puces.')
      ..writeln(
        '- Explique toujours POURQUOI (appuie-toi sur les chiffres fournis).',
      )
      ..writeln(
        '- Zéro conseil générique (« reste motivé », « travaille dur »).',
      )
      ..writeln('- Angle de coaching du jour à privilégier : $angle.')
      ..writeln('- Termine par une question de coaching courte.')
      ..writeln()
      ..writeln('ANALYSE FACTUELLE :')
      ..writeln(
        'Score du jour : ${analysis.score}/100 (${analysis.scoreLabel})',
      )
      ..writeln('Composantes : ${analysis.scoreReasons.join(' · ')}')
      ..writeln('Tendance semaine : ${analysis.weeklyTrendLabel}')
      ..writeln('Série actuelle : ${analysis.streak} jours');

    if (analysis.mostProductiveSubject != null) {
      buffer.writeln(
        'Matière dominante : ${analysis.mostProductiveSubject} · '
        'Matière délaissée : ${analysis.leastActiveSubject ?? 'aucune'}',
      );
    }
    if (analysis.problems.isNotEmpty) {
      buffer.writeln(
        'Problèmes détectés : '
        '${analysis.problems.map((p) => '${p.title} (${p.why})').join(' | ')}',
      );
    }
    if (analysis.strengths.isNotEmpty) {
      buffer.writeln(
        'Forces : ${analysis.strengths.map((s) => s.title).join(', ')}',
      );
    }
    buffer
      ..writeln(
        'Plan d\'action local déjà proposé : '
        '${analysis.actionPlan.map((a) => a.label).join(' → ')}',
      )
      ..writeln()
      ..writeln(
        'Rédige le diagnostic personnalisé (pas le plan, il est déjà affiché '
        'à côté) : ce qui se passe vraiment, le levier n°1 selon l\'angle du '
        'jour, et une phrase de motivation ancrée dans SES chiffres.',
      );

    return buffer.toString();
  }

  /// Free-form question in the ongoing conversation.
  static String buildChatPrompt({
    required String question,
    required ProductivityAnalysis analysis,
  }) {
    return 'Tu es le coach d\'étude EduFocus. Contexte factuel du jour : '
        'score ${analysis.score}/100, ${analysis.overdueTodos} tâches en '
        'retard, ${analysis.dueCards} cartes SRS dues, série de '
        '${analysis.streak} jours, tendance « ${analysis.weeklyTrendLabel} ». '
        'Réponds en français, tutoiement, 120 mots max, concret et ancré '
        'dans ces chiffres. Question : $question';
  }
}
