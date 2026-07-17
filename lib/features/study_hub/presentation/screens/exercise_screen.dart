import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/study_packs_repository.dart';
import '../../domain/study_pack.dart';

/// Exercise Viewer — step-by-step walkthrough of exercises with solution reveal.
class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({super.key, required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(studyPackProvider(packId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
        title: pack.when(
          data: (p) => Text(
            'Exercices — ${p.title}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: -0.4,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          loading: () => const Text('…'),
          error: (_, _) => const Text('Exercices'),
        ),
      ),
      body: pack.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(), style: TextStyle(color: AppColors.red)),
        ),
        data: (p) => p.exercises.isEmpty
            ? Center(
                child: Text(
                  'Aucun exercice dans ce pack.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : _ExerciseBody(exercises: p.exercises),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EXERCISE BODY — PageView of exercises
// ══════════════════════════════════════════════════════════

class _ExerciseBody extends StatefulWidget {
  const _ExerciseBody({required this.exercises});

  final List<Exercise> exercises;

  @override
  State<_ExerciseBody> createState() => _ExerciseBodyState();
}

class _ExerciseBodyState extends State<_ExerciseBody> {
  late final PageController _pageController;
  int _currentIndex = 0;
  final Set<int> _revealedSolutions = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.exercises.length;

    return Column(
      children: [
        // Progress
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / total,
                    minHeight: 5,
                    color: AppColors.green,
                    backgroundColor: AppColors.surfaceHover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentIndex + 1}/$total',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Exercise pages
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: total,
            itemBuilder: (context, index) {
              final ex = widget.exercises[index];
              final revealed = _revealedSolutions.contains(index);

              return _ExercisePage(
                exercise: ex,
                index: index,
                total: total,
                revealed: revealed,
                onReveal: () => setState(() => _revealedSolutions.add(index)),
                onPrevious: index > 0 ? () => _goTo(index - 1) : null,
                onNext: index < total - 1 ? () => _goTo(index + 1) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EXERCISE PAGE — single exercise card
// ══════════════════════════════════════════════════════════

class _ExercisePage extends StatelessWidget {
  const _ExercisePage({
    required this.exercise,
    required this.index,
    required this.total,
    required this.revealed,
    required this.onReveal,
    this.onPrevious,
    this.onNext,
  });

  final Exercise exercise;
  final int index;
  final int total;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        // Exercise number & title
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                exercise.title,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Description
        _SectionCard(
          icon: Icons.info_outline_rounded,
          label: 'DESCRIPTION',
          color: AppColors.blue,
          child: Text(
            exercise.description,
            style: text.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),

        // Schema context
        if (exercise.schemaContext != null &&
            exercise.schemaContext!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.schema_rounded,
            label: 'CONTEXTE / SCHÉMA',
            color: AppColors.cyan,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                exercise.schemaContext!,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: AppColors.cyan,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Task
        _SectionCard(
          icon: Icons.assignment_rounded,
          label: 'TÂCHE',
          color: AppColors.accent,
          child: Text(
            exercise.task,
            style: text.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Solution toggle
        if (!revealed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onReveal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: AppColors.green.withValues(alpha: .35),
              ),
              icon: const Icon(Icons.visibility_rounded, size: 20),
              label: const Text(
                'Voir la solution',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          )
        else ...[
          // Correct solution
          _SectionCard(
            icon: Icons.check_circle_rounded,
            label: 'SOLUTION',
            color: AppColors.green,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: .2),
                ),
              ),
              child: Text(
                exercise.correctSolution,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: AppColors.green,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (exercise.solutionNote != null &&
              exercise.solutionNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.yellow.withValues(alpha: .2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_rounded,
                    color: AppColors.yellow,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      exercise.solutionNote!,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.yellow,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 24),

        // Navigation buttons
        Row(
          children: [
            if (onPrevious != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrevious,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'Précédent',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            if (onPrevious != null && onNext != null) const SizedBox(width: 12),
            if (onNext != null)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Suivant',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SECTION CARD — reusable labeled card
// ══════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
