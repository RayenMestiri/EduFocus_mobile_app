import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/offline/offline_badge.dart';
import '../../data/study_packs_repository.dart';
import '../../domain/study_pack.dart';

class StudyHubScreen extends ConsumerStatefulWidget {
  const StudyHubScreen({super.key});

  @override
  ConsumerState<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends ConsumerState<StudyHubScreen> {
  String _selectedSubjectFilter = 'Tous';

  void _showImportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return _ImportPackSheet(
          onImport: (code) async {
            final cleanId = code.trim().replaceFirst('EDU-', '').toLowerCase();
            final messenger = ScaffoldMessenger.of(context);
            await ref.read(studyPacksRepositoryProvider).clone(cleanId);
            ref.invalidate(studyPacksProvider);
            messenger.showSnackBar(
              SnackBar(
                content: Text('📥 Pack d\'étude importé avec succès !'),
                backgroundColor: AppColors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeControllerProvider);
    final packsAsync = ref.watch(studyPacksProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(studyPacksProvider.future),
          child: packsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32),
              children: [
                const SizedBox(height: 60),
                Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Impossible de charger les packs d\'étude : $e',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            data: (list) {
              // Get all unique subjects for the filter strip
              final subjects = ['Tous', ...list.map((p) => p.subject).toSet()];

              // Filter packs list based on selection
              final filteredList = _selectedSubjectFilter == 'Tous'
                  ? list
                  : list
                        .where((p) => p.subject == _selectedSubjectFilter)
                        .toList();

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // ── Premium Handcrafted Breadcrumb Header ──
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'ESPACE ÉTUDE  >  STUDY HUB',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textMuted,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const OfflineBadge(),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Centre d\'Apprentissage',
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Packs completed pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          "${list.length} pack${list.length > 1 ? 's' : ''}",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ── Sleek SRS Telemetry Overview Panel ──
                  _SrsOverview(packs: list),
                  const SizedBox(height: 20),

                  // ── Adorable Memory Tip Banner ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: .15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text('🧠', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Astuce SRS : Révisez vos flashcards dès qu\'elles sont dues pour ancrer les connaissances durablement.',
                            style: TextStyle(
                              color: AppColors.accentText,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Premium Handcrafted Import Code Button ──
                  GestureDetector(
                    onTap: () => _showImportBottomSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: .3),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: .06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: .14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.download_rounded,
                              color: AppColors.accentBright,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Importer un pack d\'étude',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Saisissez un code de partage mobile pour cloner un pack public.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Dynamic Subject Filter Strip ──
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final sub = subjects[index];
                        final active = _selectedSubjectFilter == sub;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              sub,
                              style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                            selected: active,
                            selectedColor: AppColors.accent,
                            backgroundColor: AppColors.surfaceGlass,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: active
                                    ? AppColors.accent
                                    : AppColors.border,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedSubjectFilter = sub);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Header Title & Count ──
                  Row(
                    children: [
                      Text(
                        'Mes Packs d\'Étude',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${filteredList.length}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (filteredList.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 48,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 40,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun pack d\'étude trouvé',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedSubjectFilter == 'Tous'
                                ? 'Créez vos packs depuis l\'application web pour les retrouver ici.'
                                : 'Aucun pack correspondant à la matière sélectionnée.',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredList.map((pack) => _PackCard(pack: pack)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TELEMETRY OVERVIEW HEADER PANEL
// ══════════════════════════════════════════════════════════

class _SrsOverview extends StatelessWidget {
  const _SrsOverview({required this.packs});

  final List<StudyPack> packs;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final totalCards = packs.fold(0, (sum, p) => sum + p.cardCount);
    final due = packs.fold(0, (sum, p) => sum + p.dueCount);
    final mastered = packs.fold(
      0,
      (sum, p) => sum + p.countByState('mastered'),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDeep.withValues(alpha: .28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'SYSTÈME DE RÉTENTION SRS',
                style: text.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: .8),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _OverviewStat(
                value: '$totalCards',
                label: 'Flashcards',
                icon: '📚',
              ),
              _verticalDivider(),
              _OverviewStat(
                value: '$due',
                label: 'À réviser',
                icon: '🔥',
                highlightColor: due > 0
                    ? const Color(0xFFFDE68A)
                    : Colors.white,
              ),
              _verticalDivider(),
              _OverviewStat(
                value: '$mastered',
                label: 'Maîtrisées',
                icon: '🏆',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: Colors.white.withValues(alpha: .18),
  );
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.value,
    required this.label,
    required this.icon,
    this.highlightColor,
  });

  final String value;
  final String label;
  final String icon;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                value,
                style: text.titleMedium?.copyWith(
                  color: highlightColor ?? Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: text.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: .6),
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PREMIUM DETAILED STUDY PACK CARD
// ══════════════════════════════════════════════════════════

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack});

  final StudyPack pack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final due = pack.dueCount;
    final mastered = pack.countByState('mastered');

    final progress = pack.cardCount > 0
        ? (mastered / pack.cardCount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/study-hub/${pack.id}'),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upper row: Icon, title, subject and due count
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: .15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        pack.title.isEmpty ? '?' : pack.title[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pack.title,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pack.subject.toUpperCase(),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Due cards status bubble
                    if (due > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.red.withValues(alpha: .25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.red.withValues(alpha: .1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Text(
                              '$due dues',
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Content summary badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _CountChip(
                      icon: Icons.style_rounded,
                      label: '${pack.cardCount} flashcards',
                      color: AppColors.accentBright,
                    ),
                    if (pack.noteCount > 0)
                      _CountChip(
                        icon: Icons.description_rounded,
                        label: '${pack.noteCount} notes',
                        color: AppColors.blue,
                      ),
                    if (pack.qcmCount > 0)
                      _CountChip(
                        icon: Icons.quiz_rounded,
                        label: '${pack.qcmCount} QCM',
                        color: AppColors.cyan,
                      ),
                    if (pack.exerciseCount > 0)
                      _CountChip(
                        icon: Icons.fitness_center_rounded,
                        label: '${pack.exerciseCount} exos',
                        color: AppColors.green,
                      ),
                  ],
                ),

                // Mastery progress bar (if flashcards exist)
                if (pack.cardCount > 0) ...[
                  const SizedBox(height: 16),
                  Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progression de maîtrise',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: TextStyle(
                                    color: AppColors.green,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'JetBrains Mono',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                color: AppColors.green,
                                backgroundColor: AppColors.surfaceHover,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHover,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  COUNT CHIP WIDGET
// ══════════════════════════════════════════════════════════

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  IMPORT PACK SHEET
// ══════════════════════════════════════════════════════════

class _ImportPackSheet extends StatefulWidget {
  const _ImportPackSheet({required this.onImport});

  final Future<void> Function(String code) onImport;

  @override
  State<_ImportPackSheet> createState() => _ImportPackSheetState();
}

class _ImportPackSheetState extends State<_ImportPackSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Le code ne peut pas être vide');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.onImport(code);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().contains('404')
              ? 'Pack non trouvé. Vérifiez le code.'
              : 'Erreur lors de l\'importation. Réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: .15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    color: AppColors.accentBright,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Importer un Pack',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Entrez le code de partage mobile (ex: EDU-60F8BA5A...) pour cloner ce pack d\'étude public dans votre espace personnel.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              style: GoogleFonts.jetBrainsMono(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'EDU-60F8BA5A...',
                hintStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                ),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Importer',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
