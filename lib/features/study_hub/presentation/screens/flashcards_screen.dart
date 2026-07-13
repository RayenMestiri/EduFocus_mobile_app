import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/study_packs_repository.dart';
import '../../data/srs_engine.dart';
import '../../domain/study_pack.dart';

/// Flashcard review screen with 3D flip card, Normal vs. Exam SRS modes,
/// Anki-style 4-button rating panel, and a detailed session summary.
class FlashcardsScreen extends ConsumerStatefulWidget {
  const FlashcardsScreen({super.key, required this.packId});

  final String packId;

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  String _studyMode = 'exam'; // 'normal' | 'exam'
  List<Flashcard> _reviewQueue = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isFinished = false;
  late DateTime _sessionStartTime;
  bool _initialized = false;
  bool _isSaving = false;

  // Session stats tracking
  final List<int> _sessionRatings = [];
  int _countAgain = 0;
  int _countHard = 0;
  int _countGood = 0;
  int _countEasy = 0;

  // Controller for page view transition
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _sessionStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Initialize queue once the pack data is loaded
  void _initializeQueue(List<Flashcard> allCards) {
    if (_initialized) return;
    _reviewQueue = _studyMode == 'exam'
        ? SrsEngine.buildReviewQueue(allCards)
        : List.from(allCards);
    _initialized = true;
  }

  /// Switch mode and rebuild the queue
  void _setMode(String mode, List<Flashcard> allCards) {
    if (_studyMode == mode) return;
    setState(() {
      _studyMode = mode;
      _reviewQueue = mode == 'exam'
          ? SrsEngine.buildReviewQueue(allCards)
          : List.from(allCards);
      _currentIndex = 0;
      _isFlipped = false;
      _isFinished = _reviewQueue.isEmpty;
      _sessionRatings.clear();
      _countAgain = 0;
      _countHard = 0;
      _countGood = 0;
      _countEasy = 0;
      _sessionStartTime = DateTime.now();
    });
    if (_reviewQueue.isNotEmpty) {
      _pageController.jumpToPage(0);
    }
  }

  /// Toggle flip state
  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  /// Rate card in Exam SRS mode
  Future<void> _rateCard(int rating, StudyPack pack) async {
    if (_isSaving) return;

    final card = _reviewQueue[_currentIndex];
    final updatedCard = SrsEngine.rateCard(card, rating);

    // Track session stats
    setState(() {
      _sessionRatings.add(rating);
      if (rating == 0) _countAgain++;
      if (rating == 1) _countHard++;
      if (rating == 2) _countGood++;
      if (rating == 3) _countEasy++;
      _isSaving = true;
    });

    // Update locally and in DB
    final updatedCards = pack.flashcards.map((c) {
      return c.id == card.id ? updatedCard : c;
    }).toList();

    try {
      await ref.read(studyPacksRepositoryProvider).update(pack.id, {
        'flashcards': updatedCards.map((c) => c.toJson()).toList(),
      });
      // Force reload pack provider
      ref.invalidate(studyPackProvider(pack.id));
    } catch (e) {
      // Quiet fail or show Snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de synchronisation : $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _isFlipped = false;
    });

    _advance();
  }

  /// Skip card in Exam SRS mode
  void _skipCard() {
    setState(() {
      _isFlipped = false;
    });
    _advance();
  }

  /// Next card in Normal mode
  void _nextNormal() {
    setState(() {
      _isFlipped = false;
    });
    _advance();
  }

  /// Previous card
  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _isFlipped = false;
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Advance to next card or finish session
  void _advance() {
    if (_currentIndex < _reviewQueue.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() {
        _isFinished = true;
      });
    }
  }

  /// Restart current session queue
  void _restart(List<Flashcard> allCards) {
    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
      _isFinished = false;
      _initialized = false;
      _sessionRatings.clear();
      _countAgain = 0;
      _countHard = 0;
      _countGood = 0;
      _countEasy = 0;
      _sessionStartTime = DateTime.now();
    });
    _initializeQueue(allCards);
    _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final packAsync = ref.watch(studyPackProvider(widget.packId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: packAsync.when(
          data: (p) => Text(
            p.title,
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            overflow: TextOverflow.ellipsis,
          ),
          loading: () => const Text('…'),
          error: (err, stack) => const Text('Flashcards'),
        ),
      ),
      body: packAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(), style: const TextStyle(color: AppColors.red)),
        ),
        data: (pack) {
          if (pack.flashcards.isEmpty) {
            return const Center(
              child: Text(
                'Aucune flashcard dans ce pack.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          _initializeQueue(pack.flashcards);

          if (_isFinished || _reviewQueue.isEmpty) {
            return _SessionSummaryScreen(
              studyMode: _studyMode,
              total: _reviewQueue.length,
              againCount: _countAgain,
              hardCount: _countHard,
              goodCount: _countGood,
              easyCount: _countEasy,
              duration: DateTime.now().difference(_sessionStartTime),
              onRestart: () => _restart(pack.flashcards),
              onClose: () => context.pop(),
            );
          }

          final card = _reviewQueue[_currentIndex];

          return Column(
            children: [
              // ── Mode Switcher & Banner ──
              _ModeSwitcher(
                currentMode: _studyMode,
                onModeChanged: (m) => _setMode(m, pack.flashcards),
              ),

              _ModeBanner(studyMode: _studyMode, dueCount: pack.dueCount),

              // ── Stats Header (Cards due, learning etc.) ──
              if (_studyMode == 'exam')
                _SrsScoreboard(
                  newCount: pack.countByState('new'),
                  learningCount: pack.countByState('learning'),
                  reviewCount: pack.countByState('review'),
                  masteredCount: pack.countByState('mastered'),
                ),

              // ── Progress Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / _reviewQueue.length,
                          minHeight: 5,
                          color: _studyMode == 'exam' ? AppColors.accent : AppColors.cyan,
                          backgroundColor: AppColors.surfaceHover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currentIndex + 1} / ${_reviewQueue.length}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // ── 3D Card PageView ──
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _reviewQueue.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: _FlipCard(
                        key: ValueKey(card.id),
                        card: card,
                        isFlipped: _isFlipped,
                        onTap: _flipCard,
                      ),
                    );
                  },
                ),
              ),

              // ── Navigation & Skip row ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavButton(
                      icon: Icons.chevron_left_rounded,
                      label: 'Précédent',
                      enabled: _currentIndex > 0,
                      onTap: _prevCard,
                    ),
                    _FlipIndicator(isFlipped: _isFlipped),
                    if (_studyMode == 'exam')
                      _NavButton(
                        icon: Icons.chevron_right_rounded,
                        label: 'Passer',
                        enabled: true,
                        onTap: _skipCard,
                      )
                    else
                      _NavButton(
                        icon: Icons.chevron_right_rounded,
                        label: 'Suivant',
                        enabled: _currentIndex < _reviewQueue.length - 1,
                        onTap: _nextNormal,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Rating & Next Panels ──
              AnimatedCrossFade(
                firstChild: _SrsRatingPanel(
                  card: card,
                  isFlipped: _isFlipped,
                  onSelect: (rating) => _rateCard(rating, pack),
                ),
                secondChild: _NormalNextPanel(
                  isFlipped: _isFlipped,
                  onTap: _nextNormal,
                ),
                crossFadeState: _studyMode == 'exam'
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MODE SWITCHER
// ══════════════════════════════════════════════════════════

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.currentMode,
    required this.onModeChanged,
  });

  final String currentMode;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTab(
              label: 'Parcours Libre',
              icon: Icons.menu_book_rounded,
              isActive: currentMode == 'normal',
              color: AppColors.cyan,
              onTap: () => onModeChanged('normal'),
            ),
          ),
          Expanded(
            child: _ModeTab(
              label: 'Examen SRS',
              icon: Icons.auto_awesome_rounded,
              isActive: currentMode == 'exam',
              color: AppColors.accent,
              onTap: () => onModeChanged('exam'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: .15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color.withValues(alpha: .3) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? color : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MODE BANNER
// ══════════════════════════════════════════════════════════

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.studyMode, required this.dueCount});

  final String studyMode;
  final int dueCount;

  @override
  Widget build(BuildContext context) {
    final isExam = studyMode == 'exam';
    final label = isExam
        ? (dueCount > 0
            ? '$dueCount cartes à réviser aujourd\'hui 📚'
            : 'Pas de cartes à réviser pour le moment ✨')
        : 'Navigation libre — sans évaluation SRS';

    final color = isExam ? AppColors.accent : AppColors.cyan;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Icon(isExam ? Icons.psychology_rounded : Icons.menu_book_rounded,
              size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SRS SCOREBOARD
// ══════════════════════════════════════════════════════════

class _SrsScoreboard extends StatelessWidget {
  const _SrsScoreboard({
    required this.newCount,
    required this.learningCount,
    required this.reviewCount,
    required this.masteredCount,
  });

  final int newCount;
  final int learningCount;
  final int reviewCount;
  final int masteredCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          _SrsScoreCell(
              count: newCount, label: 'Nouveau', color: AppColors.blue),
          const SizedBox(width: 8),
          _SrsScoreCell(
              count: learningCount, label: 'Apprent.', color: AppColors.yellow),
          const SizedBox(width: 8),
          _SrsScoreCell(
              count: reviewCount, label: 'Révision', color: AppColors.accent),
          const SizedBox(width: 8),
          _SrsScoreCell(
              count: masteredCount, label: 'Maîtrisé', color: AppColors.green),
        ],
      ),
    );
  }
}

class _SrsScoreCell extends StatelessWidget {
  const _SrsScoreCell({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 8,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  3D FLIP CARD
// ══════════════════════════════════════════════════════════

class _FlipCard extends StatefulWidget {
  const _FlipCard({
    super.key,
    required this.card,
    required this.isFlipped,
    required this.onTap,
  });

  final Flashcard card;
  final bool isFlipped;
  final VoidCallback onTap;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isFlipped) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final angle = _animation.value * math.pi;
          final showBack = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardFace(
                      label: 'RÉPONSE',
                      content: widget.card.back,
                      code: widget.card.code,
                      accent: AppColors.green,
                      isBack: true,
                      dueDate: widget.card.dueDate,
                      state: widget.card.state,
                    ),
                  )
                : _CardFace(
                    label: 'QUESTION',
                    content: widget.card.front,
                    accent: AppColors.accentBright,
                    isBack: false,
                    state: widget.card.state,
                  ),
          );
        },
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.label,
    required this.content,
    required this.accent,
    this.code,
    required this.isBack,
    this.dueDate,
    required this.state,
  });

  final String label;
  final String content;
  final Color accent;
  final String? code;
  final bool isBack;
  final DateTime? dueDate;
  final String state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: .25)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .1),
            blurRadius: 36,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              _StateBadge(state: state),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      content,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isBack && code != null && code!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          code!,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: AppColors.cyan,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 13, color: AppColors.textMuted.withValues(alpha: .5)),
                const SizedBox(width: 4),
                Text(
                  'Retourner la carte',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.blue;
    String label = 'Nouveau';

    if (state == 'learning') {
      color = AppColors.yellow;
      label = 'Apprentissage';
    } else if (state == 'review') {
      color = AppColors.accent;
      label = 'Révision';
    } else if (state == 'mastered') {
      color = AppColors.green;
      label = 'Maîtrisé';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NAV BUTTONS
// ══════════════════════════════════════════════════════════

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FlipIndicator extends StatelessWidget {
  const _FlipIndicator({required this.isFlipped});

  final bool isFlipped;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFlipped ? Icons.lightbulb_outline_rounded : Icons.help_outline_rounded,
            size: 13,
            color: isFlipped ? AppColors.green : AppColors.accentBright,
          ),
          const SizedBox(width: 6),
          Text(
            isFlipped ? 'Afficher la question' : 'Afficher la réponse',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SRS 4-BUTTON RATING PANEL
// ══════════════════════════════════════════════════════════

class _SrsRatingPanel extends StatelessWidget {
  const _SrsRatingPanel({
    required this.card,
    required this.isFlipped,
    required this.onSelect,
  });

  final Flashcard card;
  final bool isFlipped;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!isFlipped) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: const Text(
          'Retournez la carte pour l\'évaluer',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      children: [
        const Text(
          'PROCHAIN INTERVALLE DE RÉVISION',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _RateButton(
                label: 'Revoir',
                interval: SrsEngine.getIntervalLabel(card, 0),
                color: AppColors.red,
                onTap: () => onSelect(0),
              ),
              const SizedBox(width: 8),
              _RateButton(
                label: 'Difficile',
                interval: SrsEngine.getIntervalLabel(card, 1),
                color: AppColors.yellow,
                onTap: () => onSelect(1),
              ),
              const SizedBox(width: 8),
              _RateButton(
                label: 'Bien',
                interval: SrsEngine.getIntervalLabel(card, 2),
                color: AppColors.blue,
                onTap: () => onSelect(2),
              ),
              const SizedBox(width: 8),
              _RateButton(
                label: 'Facile',
                interval: SrsEngine.getIntervalLabel(card, 3),
                color: AppColors.green,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String interval;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .25), width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                interval,
                style: TextStyle(
                  color: color.withValues(alpha: .7),
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NORMAL MODE NEXT PANEL
// ══════════════════════════════════════════════════════════

class _NormalNextPanel extends StatelessWidget {
  const _NormalNextPanel({required this.isFlipped, required this.onTap});

  final bool isFlipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!isFlipped) return const SizedBox(height: 60);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          label: const Text(
            'Carte suivante',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SESSION SUMMARY SCREEN
// ══════════════════════════════════════════════════════════

class _SessionSummaryScreen extends StatelessWidget {
  const _SessionSummaryScreen({
    required this.studyMode,
    required this.total,
    required this.againCount,
    required this.hardCount,
    required this.goodCount,
    required this.easyCount,
    required this.duration,
    required this.onRestart,
    required this.onClose,
  });

  final String studyMode;
  final int total;
  final int againCount;
  final int hardCount;
  final int goodCount;
  final int easyCount;
  final Duration duration;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final timeStr = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ListView(
          shrinkWrap: true,
          children: [
            // Checked Icon Ring
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.green.withValues(alpha: .3)),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.green,
                  size: 36,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Session Terminée !',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 6),

            Text(
              studyMode == 'exam'
                  ? 'Félicitations pour vos révisions espacées.'
                  : 'Parcours libre complété.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Scoreboard Summary Cards
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Temps écoulé',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            fontFamily: 'JetBrains Mono'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cartes parcourues',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                      Text(
                        '$total',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            fontFamily: 'JetBrains Mono'),
                      ),
                    ],
                  ),
                  if (studyMode == 'exam') ...[
                    const SizedBox(height: 12),
                    Container(height: 1, color: AppColors.border),
                    const SizedBox(height: 12),
                    _StatRow(
                        label: 'À revoir (Again)',
                        count: againCount,
                        color: AppColors.red),
                    const SizedBox(height: 8),
                    _StatRow(
                        label: 'Difficile (Hard)',
                        count: hardCount,
                        color: AppColors.yellow),
                    const SizedBox(height: 8),
                    _StatRow(
                        label: 'Bien (Good)',
                        count: goodCount,
                        color: AppColors.blue),
                    const SizedBox(height: 8),
                    _StatRow(
                        label: 'Facile (Easy)',
                        count: easyCount,
                        color: AppColors.green),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRestart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Recommencer',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onClose,
              child: const Text(
                'Retour au pack',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ],
    );
  }
}
