import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../study_hub/data/srs_engine.dart';
import '../../../study_hub/data/study_packs_repository.dart';
import '../../../study_hub/domain/study_pack.dart';

/// Spaced Repetition System (SRS) Analytics Screen.
/// Compiles pack flashcard metadata and aggregates stats dynamically.
class SrsAnalyticsScreen extends ConsumerWidget {
  const SrsAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(studyPacksProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: const Text(
          'Analytiques SRS',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(err.toString(), style: TextStyle(color: AppColors.red)),
        ),
        data: (packs) {
          if (packs.isEmpty) {
            return Center(
              child: Text(
                'Aucune donnée de révision disponible.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          // ── Aggregated Calculations ──
          int totalCards = 0;
          int newCount = 0;
          int learningCount = 0;
          int reviewCount = 0;
          int masteredCount = 0;
          int totalReviewed = 0;
          int lapses = 0;
          int reviewsLast7Days = 0;
          int reviewsLast30Days = 0;

          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          final thirtyDaysAgo = now.subtract(const Duration(days: 30));

          final List<Flashcard> dailyQueue = [];

          for (final p in packs) {
            dailyQueue.addAll(SrsEngine.buildReviewQueue(p.flashcards));

            for (final f in p.flashcards) {
              totalCards++;
              final state = f.state;

              if (state == 'new') {
                newCount++;
              } else if (state == 'learning') {
                learningCount++;
              } else if (state == 'review') {
                reviewCount++;
              } else if (state == 'mastered') {
                masteredCount++;
              }

              if (f.lastReviewed != null) {
                totalReviewed++;
                lapses += f.lapses;
                final lr = f.lastReviewed!;
                if (lr.isAfter(sevenDaysAgo)) reviewsLast7Days++;
                if (lr.isAfter(thirtyDaysAgo)) reviewsLast30Days++;
              }
            }
          }

          final dueToday = dailyQueue.length;
          final overdue = dailyQueue.where((c) {
            if (c.state == 'new') return false;
            final due = c.dueDate;
            return due != null && due.isBefore(startOfToday);
          }).length;

          final retentionRate = totalReviewed > 0
              ? (((totalReviewed - lapses) / totalReviewed) * 100)
                    .round()
                    .clamp(0, 100)
              : 100;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studyPacksProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // ── Header Stat Row ──
                Row(
                  children: [
                    _OverviewCell(
                      value: '$totalCards',
                      label: 'Cartes Totales',
                      icon: Icons.style_rounded,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 12),
                    _OverviewCell(
                      value: '${packs.length}',
                      label: 'Packs d\'Étude',
                      icon: Icons.folder_rounded,
                      color: AppColors.accent,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ── Circular Retention Card ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.green.withValues(alpha: .08),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: .25),
                            width: 3,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$retentionRate%',
                              style: TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                            Text(
                              'Retenu',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Taux de Rétention',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mesure la proportion de cartes retenues sans erreur majeure de révision.',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── Cards Distribution ──
                Text(
                  'Distribution des Cartes',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Stacked color bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: SizedBox(
                          height: 12,
                          child: Row(
                            children: [
                              _barSegment(newCount, totalCards, AppColors.blue),
                              _barSegment(
                                learningCount,
                                totalCards,
                                AppColors.yellow,
                              ),
                              _barSegment(
                                reviewCount,
                                totalCards,
                                AppColors.accent,
                              ),
                              _barSegment(
                                masteredCount,
                                totalCards,
                                AppColors.green,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Stats breakdown list
                      _DistributionLegendRow(
                        label: 'Nouveau',
                        count: newCount,
                        total: totalCards,
                        color: AppColors.blue,
                      ),
                      const SizedBox(height: 8),
                      _DistributionLegendRow(
                        label: 'Apprentissage',
                        count: learningCount,
                        total: totalCards,
                        color: AppColors.yellow,
                      ),
                      const SizedBox(height: 8),
                      _DistributionLegendRow(
                        label: 'Révision',
                        count: reviewCount,
                        total: totalCards,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 8),
                      _DistributionLegendRow(
                        label: 'Maîtrisé',
                        count: masteredCount,
                        total: totalCards,
                        color: AppColors.green,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── KPI grid ──
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 90,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  children: [
                    _KpiCell(
                      value: '$dueToday',
                      label: 'À Réviser',
                      color: AppColors.accentBright,
                    ),
                    _KpiCell(
                      value: '$overdue',
                      label: 'En Retard',
                      color: AppColors.red,
                    ),
                    _KpiCell(
                      value: '$reviewsLast7Days',
                      label: 'Rev. (7j)',
                      color: AppColors.cyan,
                    ),
                    _KpiCell(
                      value: '$reviewsLast30Days',
                      label: 'Rev. (30j)',
                      color: AppColors.blue,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Per-pack analysis list ──
                Text(
                  'Analyses par Pack',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                for (final p in packs.where(
                  (pk) => pk.flashcards.isNotEmpty,
                )) ...[_PackStatsTile(pack: p), const SizedBox(height: 8)],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _barSegment(int count, int total, Color color) {
    if (count == 0) return const SizedBox.shrink();
    final weight = total > 0 ? count / total : 0.05;
    return Expanded(
      flex: (weight * 100).round(),
      child: Container(color: color),
    );
  }
}

class _OverviewCell extends StatelessWidget {
  const _OverviewCell({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionLegendRow extends StatelessWidget {
  const _DistributionLegendRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          '$count ($pct%)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ],
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              fontFamily: 'JetBrains Mono',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackStatsTile extends StatelessWidget {
  const _PackStatsTile({required this.pack});

  final StudyPack pack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Local calculations
    int reviewed = 0;
    int lapses = 0;
    for (final f in pack.flashcards) {
      if (f.lastReviewed != null) {
        reviewed++;
        lapses += f.lapses;
      }
    }
    final retention = reviewed > 0
        ? (((reviewed - lapses) / reviewed) * 100).round().clamp(0, 100)
        : 100;

    final mastered = pack.countByState('mastered');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${pack.flashcards.length} cartes · $mastered maîtrisées',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Retention rate badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.green.withValues(alpha: .2)),
            ),
            child: Column(
              children: [
                Text(
                  '$retention%',
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
                Text(
                  'RÉTENTION',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
