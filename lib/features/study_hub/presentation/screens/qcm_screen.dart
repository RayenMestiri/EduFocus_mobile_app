import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/study_packs_repository.dart';
import '../../domain/study_pack.dart';

/// QCM Quiz Mode — Interactive quiz with topic filtering, error filters,
/// question navigator dots, timer count-up, bookmarking, and backend synchronization.
class QcmScreen extends ConsumerWidget {
  const QcmScreen({super.key, required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packAsync = ref.watch(studyPackProvider(packId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
        title: packAsync.when(
          data: (p) => Text(
            'Quiz — ${p.title}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: -0.4,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          loading: () => const Text('…'),
          error: (err, stack) => const Text('Quiz'),
        ),
      ),
      body: packAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(), style: const TextStyle(color: AppColors.red)),
        ),
        data: (p) => p.qcm.isEmpty
            ? const Center(
                child: Text(
                  'Aucune question QCM dans ce pack.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : _QuizBody(pack: p),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  QUIZ BODY — stateful dashboard & flow
// ══════════════════════════════════════════════════════════

class _QuizBody extends ConsumerStatefulWidget {
  const _QuizBody({required this.pack});

  final StudyPack pack;

  @override
  ConsumerState<_QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends ConsumerState<_QuizBody> {
  late final PageController _pageController;

  // Active question list (holds filtered/shuffled state)
  List<QCM> _activeQuestions = [];

  // Filter conditions
  String _selectedTopic = 'all';
  String _selectedMode = 'all'; // 'all' | 'wrong' | 'bookmarks'

  // User answer state
  // key: question ID, value: selected answer
  final Map<String, dynamic> _selectedAnswers = {};
  final Map<String, bool> _revealedAnswers = {};
  final Map<String, bool> _isCorrectAnswers = {};

  // Bookmark registry
  final Set<String> _bookmarkedIds = {};

  // Timing
  late Timer _timer;
  int _elapsedSeconds = 0;
  bool _quizFinished = false;
  int _currentIndex = 0;
  bool _isSavingAttempt = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _activeQuestions = List.from(widget.pack.qcm);
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_quizFinished && mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  String get _formattedTime {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Filter updates
  void _applyFilters() {
    List<QCM> list = List.from(widget.pack.qcm);

    // Topic filter
    if (_selectedTopic != 'all') {
      list = list.where((q) => (q.topic ?? 'Général') == _selectedTopic).toList();
    }

    // Mode filter
    if (_selectedMode == 'wrong') {
      list = list.where((q) {
        final revealed = _revealedAnswers[q.id] ?? false;
        final correct = _isCorrectAnswers[q.id] ?? false;
        return revealed && !correct;
      }).toList();
    } else if (_selectedMode == 'bookmarks') {
      list = list.where((q) => _bookmarkedIds.contains(q.id)).toList();
    }

    setState(() {
      _activeQuestions = list;
      _currentIndex = 0;
      _quizFinished = list.isEmpty;
    });

    if (list.isNotEmpty) {
      _pageController.jumpToPage(0);
    }
  }

  void _setTopic(String topic) {
    setState(() {
      _selectedTopic = topic;
    });
    _applyFilters();
  }

  void _setModeFilter(String mode) {
    setState(() {
      _selectedMode = mode;
    });
    _applyFilters();
  }

  void _shuffle() {
    setState(() {
      _activeQuestions.shuffle();
      _currentIndex = 0;
    });
    if (_activeQuestions.isNotEmpty) {
      _pageController.jumpToPage(0);
    }
  }

  void _reset() {
    setState(() {
      _selectedAnswers.clear();
      _revealedAnswers.clear();
      _isCorrectAnswers.clear();
      _currentIndex = 0;
      _quizFinished = false;
      _elapsedSeconds = 0;
    });
    _applyFilters();
  }

  void _toggleBookmark(String questionId) {
    setState(() {
      if (_bookmarkedIds.contains(questionId)) {
        _bookmarkedIds.remove(questionId);
      } else {
        _bookmarkedIds.add(questionId);
      }
    });
  }

  void _selectAnswer(String questionId, dynamic answer, QCM question) {
    if (_revealedAnswers[questionId] == true) return;

    final correct = question.isCorrect(answer);

    setState(() {
      _selectedAnswers[questionId] = answer;
      _revealedAnswers[questionId] = true;
      _isCorrectAnswers[questionId] = correct;
    });
  }

  void _jumpToQuestion(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _goNext() {
    if (_currentIndex < _activeQuestions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() {
        _quizFinished = true;
      });
      _saveAttemptToBackend();
    }
  }

  Future<void> _saveAttemptToBackend() async {
    setState(() => _isSavingAttempt = true);

    final answeredQuestions = _activeQuestions.where((q) => _revealedAnswers[q.id] == true).toList();
    final score = _activeQuestions.where((q) => _isCorrectAnswers[q.id] == true).length;
    final total = _activeQuestions.length;
    
    final divisor = _quizFinished ? total : answeredQuestions.length;
    final pct = divisor > 0 ? (score / divisor * 100).round() : 0;

    final answersJson = answeredQuestions.map((q) {
      return {
        'questionId': q.id,
        'selectedAnswer': _selectedAnswers[q.id]?.toString() ?? '',
        'isCorrect': _isCorrectAnswers[q.id] ?? false,
        'topic': q.topic ?? 'Général',
      };
    }).toList();

    try {
      await ref.read(studyPacksRepositoryProvider).saveAttempt(widget.pack.id, {
        'score': score,
        'totalQuestions': total,
        'percentage': pct,
        'answers': answersJson,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'enregistrer l\'essai : $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isSavingAttempt = false);
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    final answeredCount = _selectedAnswers.length;
    final totalCount = _activeQuestions.length;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceGlass,
          title: const Text(
            '💾 Sauvegarder avant de partir ?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Vous avez répondu à $answeredCount/$totalCount questions.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Sauvegarder maintenant pour conserver votre progression dans votre historique.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowButtonSpacing: 8,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Sauvegarder et quitter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('leave'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Quitter sans sauver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('stay'),
              child: const Text('Rester sur le quiz', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (result == 'save') {
      await _saveAttemptToBackend();
      return true;
    } else if (result == 'leave') {
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_quizFinished) {
      final correctCount = _activeQuestions.where((q) => _isCorrectAnswers[q.id] == true).length;
      return _ScoreScreen(
        correct: correctCount,
        total: _activeQuestions.length,
        timeStr: _formattedTime,
        isSaving: _isSavingAttempt,
        onRestart: _reset,
        onClose: () => context.pop(),
      );
    }

    final total = _activeQuestions.length;
    final textTheme = Theme.of(context).textTheme;

    // Get list of topics
    final topics = widget.pack.qcm.map((q) => q.topic ?? 'Général').toSet().toList();

    final correctCount = _activeQuestions.where((q) => _isCorrectAnswers[q.id] == true).length;
    final wrongCount = _activeQuestions.where((q) => _revealedAnswers[q.id] == true && _isCorrectAnswers[q.id] != true).length;
    final remainingCount = total - _activeQuestions.where((q) => _revealedAnswers[q.id] == true).length;
    final pct = total > 0 ? (correctCount / total * 100).round() : 0;

    final answeredCount = _selectedAnswers.length;
    final canPopFreely = _quizFinished || answeredCount == 0;

    return PopScope(
      canPop: canPopFreely,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool shouldLeave = await _showExitConfirmationDialog();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Column(
        children: [
        // ── Timer & Stats ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progression',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: AppColors.green),
                    const SizedBox(width: 6),
                    Text(
                      _formattedTime,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Live stats cells
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              _StatCell(value: '$total', label: 'Total', color: AppColors.indigo),
              const SizedBox(width: 8),
              _StatCell(value: '$correctCount', label: 'Juste', color: AppColors.green),
              const SizedBox(width: 8),
              _StatCell(value: '$wrongCount', label: 'Faux', color: AppColors.red),
              const SizedBox(width: 8),
              _StatCell(value: '$remainingCount', label: 'Reste', color: AppColors.yellow),
              const SizedBox(width: 8),
              _StatCell(value: '$pct%', label: 'Score', color: AppColors.cyan),
            ],
          ),
        ),

        // ── Topic Filter Pills & Controls ──
        Container(
          height: 38,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _FilterPill(
                label: 'Tout',
                isActive: _selectedTopic == 'all',
                onTap: () => _setTopic('all'),
              ),
              for (final topic in topics) ...[
                const SizedBox(width: 8),
                _FilterPill(
                  label: topic,
                  isActive: _selectedTopic == topic,
                  onTap: () => _setTopic(topic),
                ),
              ],
            ],
          ),
        ),

        // Mode filters row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _ModeFilterButton(
                label: 'Tout',
                isActive: _selectedMode == 'all',
                onTap: () => _setModeFilter('all'),
              ),
              const SizedBox(width: 8),
              _ModeFilterButton(
                label: 'Erreurs',
                isActive: _selectedMode == 'wrong',
                onTap: () => _setModeFilter('wrong'),
              ),
              const SizedBox(width: 8),
              _ModeFilterButton(
                label: 'Signets',
                isActive: _selectedMode == 'bookmarks',
                onTap: () => _setModeFilter('bookmarks'),
              ),
              const Spacer(),
              IconButton(
                onPressed: _shuffle,
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceGlass,
                  side: BorderSide(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceGlass,
                  side: BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
        ),

        // ── Dot Navigator Grid ──
        if (total > 0)
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: total,
              itemBuilder: (context, index) {
                final q = _activeQuestions[index];
                final isCurrent = _currentIndex == index;
                final revealed = _revealedAnswers[q.id] ?? false;
                final isCorrect = _isCorrectAnswers[q.id] ?? false;

                Color bgColor = AppColors.surfaceGlass;
                Color borderColor = AppColors.border;
                Color textColor = AppColors.textSecondary;

                if (isCurrent) {
                  bgColor = AppColors.accent;
                  borderColor = AppColors.accent;
                  textColor = Colors.white;
                } else if (revealed) {
                  if (isCorrect) {
                    bgColor = AppColors.green.withValues(alpha: .15);
                    borderColor = AppColors.green;
                    textColor = AppColors.green;
                  } else {
                    bgColor = AppColors.red.withValues(alpha: .15);
                    borderColor = AppColors.red;
                    textColor = AppColors.red;
                  }
                }

                return GestureDetector(
                  onTap: () => _jumpToQuestion(index),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_bookmarkedIds.contains(q.id))
                          const Positioned(
                            top: -12,
                            right: -12,
                            child: Icon(Icons.bookmark_rounded,
                                color: AppColors.yellow, size: 10),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // ── Main PageView ──
        Expanded(
          child: total == 0
              ? const _EmptyStateView()
              : PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemCount: total,
                  itemBuilder: (context, index) {
                    final q = _activeQuestions[index];
                    final selected = _selectedAnswers[q.id];
                    final revealed = _revealedAnswers[q.id] == true;

                    return _QuestionCard(
                      question: q,
                      index: index,
                      selected: selected,
                      revealed: revealed,
                      isBookmarked: _bookmarkedIds.contains(q.id),
                      onBookmark: () => _toggleBookmark(q.id),
                      onSelect: (ans) => _selectAnswer(q.id, ans, q),
                      onNext: _goNext,
                      isLast: index == total - 1,
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.border,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: .2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ModeFilterButton extends StatelessWidget {
  const _ModeFilterButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.indigo.withValues(alpha: .15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.indigo.withValues(alpha: .35) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.indigo : AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withValues(alpha: .15)),
              ),
              child: const Icon(Icons.inbox_rounded, color: AppColors.textMuted, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune question trouvée',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Veuillez modifier vos filtres ou signets.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  QUESTION CARD
// ══════════════════════════════════════════════════════════

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.selected,
    required this.revealed,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onSelect,
    required this.onNext,
    required this.isLast,
  });

  final QCM question;
  final int index;
  final dynamic selected;
  final bool revealed;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final ValueChanged<dynamic> onSelect;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        // Topic Pill + Bookmark
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                question.topic ?? 'Général',
                style: const TextStyle(
                  color: AppColors.accentBright,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: onBookmark,
              icon: Icon(
                isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isBookmarked ? AppColors.yellow : AppColors.textMuted,
                size: 20,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Question Statement
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            question.question,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Answers
        if (question.type == 'multiple-choice')
          ..._buildMultipleChoice(),

        if (question.type == 'true-false') ..._buildTrueFalse(),

        if (question.type == 'fill-blanks')
          _FillBlanksBox(
            onSubmit: onSelect,
            revealed: revealed,
            isCorrect: revealed ? question.isCorrect(selected) : false,
          ),

        // Explanation / Trap Note
        if (revealed) ...[
          const SizedBox(height: 16),
          _ExplanationBox(
            question: question,
            isCorrect: question.isCorrect(selected),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isLast ? 'Terminer et Enregistrer' : 'Suivant',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildMultipleChoice() {
    const alphabet = ['A', 'B', 'C', 'D', 'E', 'F'];
    return [
      for (var i = 0; i < question.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AnswerCell(
            letter: i < alphabet.length ? alphabet[i] : '${i + 1}',
            text: question.options[i],
            isSelected: selected == i,
            isCorrect: revealed && question.isCorrect(i),
            isWrong: revealed && selected == i && !question.isCorrect(i),
            revealed: revealed,
            onTap: () => onSelect(i),
          ),
        ),
    ];
  }

  List<Widget> _buildTrueFalse() {
    return [
      Row(
        children: [
          Expanded(
            child: _AnswerCell(
              letter: '✓',
              text: 'Vrai',
              isSelected: selected == 'true',
              isCorrect: revealed && question.isCorrect('true'),
              isWrong: revealed && selected == 'true' && !question.isCorrect('true'),
              revealed: revealed,
              onTap: () => onSelect('true'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AnswerCell(
              letter: '✗',
              text: 'Faux',
              isSelected: selected == 'false',
              isCorrect: revealed && question.isCorrect('false'),
              isWrong: revealed && selected == 'false' && !question.isCorrect('false'),
              revealed: revealed,
              onTap: () => onSelect('false'),
            ),
          ),
        ],
      ),
    ];
  }
}

// ══════════════════════════════════════════════════════════
//  ANSWER CELL
// ══════════════════════════════════════════════════════════

class _AnswerCell extends StatelessWidget {
  const _AnswerCell({
    required this.letter,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrong,
    required this.revealed,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.surfaceGlass;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textPrimary;
    Color badgeBg = AppColors.accent.withValues(alpha: .1);
    Color badgeColor = AppColors.accentBright;

    if (revealed) {
      if (isCorrect) {
        bgColor = AppColors.green.withValues(alpha: .1);
        borderColor = AppColors.green.withValues(alpha: .35);
        badgeBg = AppColors.green.withValues(alpha: .15);
        badgeColor = AppColors.green;
      } else if (isWrong) {
        bgColor = AppColors.red.withValues(alpha: .1);
        borderColor = AppColors.red.withValues(alpha: .35);
        badgeBg = AppColors.red.withValues(alpha: .15);
        badgeColor = AppColors.red;
      } else {
        bgColor = AppColors.surfaceSecondary;
        textColor = AppColors.textMuted;
      }
    } else if (isSelected) {
      borderColor = AppColors.accent;
      bgColor = AppColors.accent.withValues(alpha: .08);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: revealed ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              if (revealed && isCorrect)
                const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20),
              if (revealed && isWrong)
                const Icon(Icons.cancel_rounded, color: AppColors.red, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FILL BLANKS BOX
// ══════════════════════════════════════════════════════════

class _FillBlanksBox extends StatefulWidget {
  const _FillBlanksBox({
    required this.onSubmit,
    required this.revealed,
    required this.isCorrect,
  });

  final ValueChanged<String> onSubmit;
  final bool revealed;
  final bool isCorrect;

  @override
  State<_FillBlanksBox> createState() => _FillBlanksBoxState();
}

class _FillBlanksBoxState extends State<_FillBlanksBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          enabled: !widget.revealed,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Votre réponse…',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceGlass,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
          ),
        ),
        if (!widget.revealed) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onSubmit(_controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Valider',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EXPLANATION BOX
// ══════════════════════════════════════════════════════════

class _ExplanationBox extends StatelessWidget {
  const _ExplanationBox({
    required this.question,
    required this.isCorrect,
  });

  final QCM question;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.green.withValues(alpha: .08)
            : AppColors.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? AppColors.green.withValues(alpha: .25)
              : AppColors.red.withValues(alpha: .25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isCorrect ? AppColors.green : AppColors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct !' : 'Incorrect',
                style: TextStyle(
                  color: isCorrect ? AppColors.green : AppColors.red,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (question.explanation != null && question.explanation!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              question.explanation!,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (question.trapNote != null && question.trapNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.yellow.withValues(alpha: .2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_rounded, color: AppColors.yellow, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Piège : ${question.trapNote!}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.yellow,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SCORE SCREEN
// ══════════════════════════════════════════════════════════

class _ScoreScreen extends StatelessWidget {
  const _ScoreScreen({
    required this.correct,
    required this.total,
    required this.timeStr,
    required this.isSaving,
    required this.onRestart,
    required this.onClose,
  });

  final int correct;
  final int total;
  final String timeStr;
  final bool isSaving;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = total > 0 ? (correct / total * 100).round() : 0;
    final isExcellent = pct >= 80;
    final isGood = pct >= 50;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ListView(
          shrinkWrap: true,
          children: [
            // Score circle
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isExcellent
                        ? [AppColors.green, const Color(0xFF059669)]
                        : isGood
                            ? [AppColors.accent, AppColors.indigo]
                            : [AppColors.red, const Color(0xFFDC2626)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isExcellent
                              ? AppColors.green
                              : isGood
                                  ? AppColors.accent
                                  : AppColors.red)
                          .withValues(alpha: .35),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 34,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        '$correct / $total',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .7),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              isExcellent
                  ? 'Excellent !'
                  : isGood
                      ? 'Bien joué !'
                      : 'Continuez à réviser',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isExcellent
                  ? 'Vous maîtrisez ce sujet parfaitement.'
                  : isGood
                      ? 'Encore un effort pour tout maîtriser.'
                      : 'Révisez le contenu et réessayez.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Attempts saving notification
            if (isSaving)
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentText),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Enregistrement de l\'essai...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              )
            else
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_done_rounded, color: AppColors.green, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Essai enregistré sur le cloud',
                      style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Performance Cards
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'TEMPS TOTAL',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 8, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: AppColors.border),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'QUESTIONS',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 8, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$total',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                      ],
                    ),
                  ),
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
