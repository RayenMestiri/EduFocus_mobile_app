import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Content categories an import can produce — fixed order drives both the
/// live progress rows and the final summary breakdown.
enum ImportCategory { flashcards, notes, qcms, cheatsheets, exercises }

String _categoryLabel(ImportCategory c) => switch (c) {
  ImportCategory.flashcards => 'Flashcards',
  ImportCategory.notes => 'Notes',
  ImportCategory.qcms => 'Questions QCM',
  ImportCategory.cheatsheets => 'Fiches',
  ImportCategory.exercises => 'Exercices',
};

IconData _categoryIcon(ImportCategory c) => switch (c) {
  ImportCategory.flashcards => Icons.style_rounded,
  ImportCategory.notes => Icons.description_rounded,
  ImportCategory.qcms => Icons.quiz_rounded,
  ImportCategory.cheatsheets => Icons.fact_check_rounded,
  ImportCategory.exercises => Icons.assignment_rounded,
};

/// One progress tick for a given category — e.g. "12/20 Questions QCM".
class ImportProgressEvent {
  const ImportProgressEvent({
    required this.category,
    required this.done,
    required this.total,
  });

  final ImportCategory category;
  final int done;
  final int total;
}

/// Full-screen import overlay: shimmering skeleton rows update live from
/// [events]; once the stream closes, a summary breakdown fades in
/// automatically (e.g. "+12 Flashcards", "+3 Notes"). Feed [events] from the
/// import parser as it processes each category — see study_pack_detail_screen
/// for the reference producer. `onOpenHub` fires if the user taps the CTA on
/// the summary (the caller should pop back to the Study Hub root there).
Future<void> showImportProgressOverlay(
  BuildContext context, {
  required Stream<ImportProgressEvent> events,
  VoidCallback? onOpenHub,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: .6),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, _) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(
          begin: .95,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: _ImportOverlayCard(events: events, onOpenHub: onOpenHub),
      ),
    ),
  );
}

class _ImportOverlayCard extends StatefulWidget {
  const _ImportOverlayCard({required this.events, this.onOpenHub});

  final Stream<ImportProgressEvent> events;
  final VoidCallback? onOpenHub;

  @override
  State<_ImportOverlayCard> createState() => _ImportOverlayCardState();
}

class _ImportOverlayCardState extends State<_ImportOverlayCard> {
  final Map<ImportCategory, ImportProgressEvent> _latest = {};
  late final StreamSubscription<ImportProgressEvent> _sub;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.events.listen(
      (e) {
        if (!mounted) return;
        setState(() => _latest[e.category] = e);
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _finished = true);
      },
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.borderBright),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: .18),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutCubic,
                child: _finished
                    ? _SummaryView(
                        key: const ValueKey('summary'),
                        totals: _latest,
                        onOpenHub: widget.onOpenHub,
                      )
                    : _ProgressView(
                        key: const ValueKey('progress'),
                        latest: _latest,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({super.key, required this.latest});

  final Map<ImportCategory, ImportProgressEvent> latest;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.cloud_sync_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Importation en cours…',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                    ),
                  ),
                  Text(
                    'Analyse du contenu, un instant.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final category in ImportCategory.values) ...[
          _ImportRow(category: category, event: latest[category]),
          if (category != ImportCategory.values.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({required this.category, required this.event});

  final ImportCategory category;
  final ImportProgressEvent? event;

  @override
  Widget build(BuildContext context) {
    final pending = event == null;
    final ratio = pending || event!.total == 0
        ? 0.0
        : event!.done / event!.total;
    final complete = !pending && event!.done >= event!.total;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pending
                ? AppColors.surfaceSecondary
                : AppColors.accent.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(11),
          ),
          child: complete
              ? Icon(Icons.check_rounded, color: AppColors.green, size: 18)
              : Icon(
                  _categoryIcon(category),
                  size: 17,
                  color: pending ? AppColors.textMuted : AppColors.accentText,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: pending
              ? const _ShimmerLine()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_categoryLabel(category)} · ${event!.done}/${event!.total}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 4,
                        backgroundColor: AppColors.accent.withValues(alpha: .12),
                        valueColor: AlwaysStoppedAnimation(
                          complete ? AppColors.green : AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Dependency-free shimmer sweep for a pending/unknown-progress row.
class _ShimmerLine extends StatefulWidget {
  const _ShimmerLine();

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.surfaceSecondary;
    final highlight = AppColors.textMuted.withValues(alpha: .35);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final dx = _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1 + dx * 3, 0),
            end: Alignment(dx * 3, 0),
            colors: [base, highlight, base],
          ).createShader(rect),
          child: Container(
            height: 13,
            width: double.infinity,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({super.key, required this.totals, this.onOpenHub});

  final Map<ImportCategory, ImportProgressEvent> totals;
  final VoidCallback? onOpenHub;

  int get _grandTotal =>
      totals.values.fold(0, (sum, e) => sum + e.done);

  @override
  Widget build(BuildContext context) {
    final rows = ImportCategory.values
        .where((c) => (totals[c]?.done ?? 0) > 0)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: .4),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.celebration_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$_grandTotal éléments importés !',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Répartition du contenu ajouté à votre pack.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (final c in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(_categoryIcon(c), size: 16, color: AppColors.accentText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _categoryLabel(c),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '+${totals[c]!.done}',
                        style: TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onOpenHub?.call();
            },
            icon: const Icon(Icons.auto_stories_rounded, size: 18),
            label: const Text('Ouvrir le Study Hub'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Fermer',
            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
