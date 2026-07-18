import '../domain/coaching_report.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Recommendation Engine — local narrative generation.
///
/// Used whenever Gemini is unavailable (offline, quota, no key) so the coach
/// still speaks like a coach, not an error message.
/// ═══════════════════════════════════════════════════════════════════════════
abstract final class RecommendationEngine {
  static String buildNarrative(ProductivityAnalysis a, {DateTime? now}) {
    final opening = switch (a.score) {
      >= 85 => 'Franchement, belle journée de travail.',
      >= 65 => 'Bonne dynamique aujourd\'hui, il reste une marge exploitable.',
      >= 40 => 'Journée correcte, mais votre potentiel est au-dessus.',
      _ => 'Peu d\'activité pour l\'instant ; une seule session peut tout changer.',
    };

    final diagnosis = StringBuffer();
    if (a.problems.isNotEmpty) {
      final p = a.problems.first;
      diagnosis.write(
        'Le signal à traiter en priorité : ${p.title}. ${p.why}',
      );
    } else if (a.weaknesses.isNotEmpty) {
      final w = a.weaknesses.first;
      diagnosis.write(
        'À surveiller : ${w.title}. ${w.why}',
      );
    } else {
      diagnosis.write(
        'Aucun signal d\'alerte dans vos données — le système tourne.',
      );
    }

    final strengthLine = a.strengths.isNotEmpty
        ? 'Ce qui joue pour vous : ${a.strengths.first.title} - ${a.strengths.first.why}'
        : null;

    final closing = 'La matinée est votre meilleure fenêtre : un bloc maintenant vaut deux ce soir.';

    return [
      opening,
      diagnosis.toString(),
      if (strengthLine != null) strengthLine,
      closing,
    ].join('\n\n');
  }
}
