import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../data/ai_repository.dart';
import '../../domain/coaching_report.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Coach IA — premium conversational coaching.
///
/// Facts come from the local AnalysisEngine (score, distribution, plan);
/// the narrative streams in progressively like a real assistant. Loading is
/// a staged "thinking" sequence, never a bare spinner.
/// ═══════════════════════════════════════════════════════════════════════════
class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final List<CoachMessage> _messages = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;
  ProductivityAnalysis? _lastAnalysis;

  static const _suggestions = [
    ('auto_graph_rounded', 'Analyser ma journée'),
    ('style_rounded', 'Que réviser en priorité ?'),
    ('event_rounded', 'Un plan pour demain'),
    ('local_fire_department_rounded', 'Comment va ma régularité ?'),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final maxScroll = _scroll.position.maxScrollExtent;
      final currentScroll = _scroll.position.pixels;

      // If force is true (e.g. user just sent a message), always scroll to the end.
      // Otherwise, only auto-scroll if the user is already near the bottom (within 140 pixels).
      if (force || (maxScroll - currentScroll < 140)) {
        _scroll.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _analyze() async {
    if (_thinking) return;
    setState(() {
      _messages.add(const CoachMessage.user('Analyse ma journée'));
      _thinking = true;
    });
    _scrollToEnd(force: true);

    try {
      final result = await ref.read(aiRepositoryProvider).analyze();
      if (!mounted) return;
      setState(() {
        _lastAnalysis = result.analysis;
        _messages.add(
          CoachMessage.coach(
            narrative: result.narrative,
            analysis: result.analysis,
            source: result.source,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          CoachMessage.coach(
            narrative:
                'Je n\'arrive pas à récupérer vos données pour le moment. '
                'Réessayez dans un instant.',
            source: 'local',
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollToEnd();
    }
  }

  Future<void> _ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _thinking) return;
    _input.clear();

    if (trimmed == 'Analyser ma journée') {
      return _analyze();
    }

    setState(() {
      _messages.add(CoachMessage.user(trimmed));
      _thinking = true;
    });
    _scrollToEnd(force: true);

    try {
      final result = await ref
          .read(aiRepositoryProvider)
          .ask(trimmed, lastAnalysis: _lastAnalysis);
      if (!mounted) return;
      _lastAnalysis = result.analysis;
      setState(() {
        _messages.add(
          CoachMessage.coach(
            narrative: result.narrative,
            source: result.source,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const CoachMessage.coach(
            narrative:
                'Petit souci de mon côté — reposez-moi la question dans un '
                'instant.',
            source: 'local',
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            Expanded(
              child: _messages.isEmpty && !_thinking
                  ? _EmptyState(onSuggestion: _ask, suggestions: _suggestions)
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                      children: [
                        for (var i = 0; i < _messages.length; i++)
                          _messages[i].isUser
                              ? _UserBubble(text: _messages[i].text)
                              : _CoachBubble(
                                  message: _messages[i],
                                  onStream: _scrollToEnd,
                                  isLast: i == _messages.length - 1,
                                ),
                        if (_thinking) const _ThinkingCard(),
                      ],
                    ),
            ),
            _InputBar(
              controller: _input,
              enabled: !_thinking,
              onSend: _ask,
              suggestions: _messages.isEmpty
                  ? const []
                  : const ['Analyser ma journée', 'Un plan pour demain'],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER — floating pulsing avatar
// ═══════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
          const _PulsingAvatar(size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach IA',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Analyse fondée sur vos vraies données',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
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

class _PulsingAvatar extends StatefulWidget {
  const _PulsingAvatar({required this.size});

  final double size;

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: .3 + .25 * t),
                blurRadius: 14 + 10 * t,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 20,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestion, required this.suggestions});

  final void Function(String) onSuggestion;
  final List<(String, String)> suggestions;

  static const _icons = {
    'auto_graph_rounded': Icons.auto_graph_rounded,
    'style_rounded': Icons.style_rounded,
    'event_rounded': Icons.event_rounded,
    'local_fire_department_rounded': Icons.local_fire_department_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      children: [
        const Center(child: _PulsingAvatar(size: 76)),
        const SizedBox(height: 22),
        Text(
          'Votre coach personnel',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 21,
            letterSpacing: -0.6,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'J\'analyse vos sessions, tâches, révisions et habitudes pour vous '
          'donner un diagnostic honnête et un plan concret — jamais de '
          'conseils génériques.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        for (final (icon, label) in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => onSuggestion(label),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(_icons[icon], size: 18, color: AppColors.accentText),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// THINKING — staged analysis loader
// ═══════════════════════════════════════════════════════════════════════════

class _ThinkingCard extends StatefulWidget {
  const _ThinkingCard();

  @override
  State<_ThinkingCard> createState() => _ThinkingCardState();
}

class _ThinkingCardState extends State<_ThinkingCard> {
  static const _stages = [
    'L\'IA analyse votre productivité…',
    'Passage en revue des sessions du jour…',
    'Comparaison avec les jours précédents…',
    'Détection de patterns…',
    'Construction de votre plan personnalisé…',
  ];

  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) {
        setState(() => _stage = math.min(_stage + 1, _stages.length - 1));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 40),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const _TypingDots(),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, .3),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  _stages[_stage],
                  key: ValueKey(_stage),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_controller.value * 3) - i).clamp(0.0, 1.0);
            final bump = math.sin(phase * math.pi);
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .35 + .65 * bump),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MESSAGES
// ═══════════════════════════════════════════════════════════════════════════

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 60),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: .25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachBubble extends StatefulWidget {
  const _CoachBubble({
    required this.message,
    required this.onStream,
    required this.isLast,
  });

  final CoachMessage message;
  final VoidCallback onStream;
  final bool isLast;

  @override
  State<_CoachBubble> createState() => _CoachBubbleState();
}

class _CoachBubbleState extends State<_CoachBubble> {
  late bool _showReport;

  @override
  void initState() {
    super.initState();
    _showReport =
        !widget.isLast ||
        widget.message.narrative == null ||
        widget.message.narrative!.isEmpty;
  }

  @override
  void didUpdateWidget(covariant _CoachBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLast) {
      _showReport = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Provenance ──
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: AppColors.accentText,
                ),
                const SizedBox(width: 5),
                Text(
                  'COACH',
                  style: TextStyle(
                    color: AppColors.accentText,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.message.source != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (widget.message.source == 'gemini'
                                  ? AppColors.green
                                  : AppColors.cyan)
                              .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.message.source == 'gemini'
                          ? 'Gemini'
                          : 'Analyse locale',
                      style: TextStyle(
                        color: widget.message.source == 'gemini'
                            ? AppColors.green
                            : AppColors.cyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Narrative (streams in) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: _StreamingText(
              text: widget.message.narrative ?? '',
              onAdvance: widget.onStream,
              isLast: widget.isLast,
              onDone: () {
                if (mounted && !_showReport) {
                  setState(() => _showReport = true);
                  widget
                      .onStream(); // Scroll to end to reveal the new report card!
                }
              },
            ),
          ),

          // ── Structured report ──
          if (widget.message.analysis != null && _showReport) ...[
            const SizedBox(height: 12),
            _ReportCard(analysis: widget.message.analysis!),
          ],
        ],
      ),
    );
  }
}

/// Progressive character reveal with a blinking cursor and natural pauses
/// after sentence breaks — the "assistant is writing" feel.
class _StreamingText extends StatefulWidget {
  const _StreamingText({
    required this.text,
    required this.onAdvance,
    this.onDone,
    this.isLast = true,
  });

  final String text;
  final VoidCallback onAdvance;
  final VoidCallback? onDone;
  final bool isLast;

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText> {
  late int _visible;
  Timer? _timer;

  bool get _done => _visible >= widget.text.length;

  @override
  void initState() {
    super.initState();
    _visible = widget.isLast ? 0 : widget.text.length;
    if (widget.isLast) {
      _tick();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDone?.call();
      });
    }
  }

  void _tick() {
    if (_done) {
      widget.onDone?.call();
      return;
    }
    final ch = widget.text[_visible.clamp(0, widget.text.length - 1)];
    // Natural pauses on punctuation & paragraph breaks.
    final delay = switch (ch) {
      '.' || '!' || '?' => 160,
      ',' || ';' => 70,
      '\n' => 120,
      _ => 14,
    };
    _timer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _visible = math.min(_visible + 2, widget.text.length));
      if (_visible % 60 == 0) widget.onAdvance();
      _tick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.text.substring(0, _visible);
    return Text.rich(
      TextSpan(
        text: shown,
        children: [
          if (!_done)
            TextSpan(
              text: ' ▍',
              style: TextStyle(color: AppColors.accentBright),
            ),
        ],
      ),
      style: TextStyle(
        color: AppColors.textPrimary.withValues(alpha: .92),
        fontSize: 14,
        height: 1.65,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STRUCTURED REPORT
// ═══════════════════════════════════════════════════════════════════════════

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.analysis});

  final ProductivityAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderBright),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Score + trend ──
          Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: a.score / 100),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CustomPaint(
                    painter: _ScoreRingPainter(progress: value),
                    child: Center(
                      child: Text(
                        '${(value * 100).round()}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCORE DE PRODUCTIVITÉ',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      a.scoreLabel,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      a.weeklyTrendLabel,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Why this score ──
          const SizedBox(height: 12),
          _Expandable(
            title: 'Pourquoi ce score ?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in a.scoreReasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accentBright,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Time distribution ──
          if (a.timeDistribution.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionLabel(
              icon: Icons.donut_small_rounded,
              label: 'Répartition du temps',
            ),
            const SizedBox(height: 10),
            for (final slice in a.timeDistribution)
              _DistributionBar(slice: slice),
          ],

          // ── Signals ──
          if (a.problems.isNotEmpty || a.strengths.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionLabel(icon: Icons.insights_rounded, label: 'Signaux'),
            const SizedBox(height: 10),
            for (final s in a.strengths.take(2)) _InsightTile(insight: s),
            for (final p in a.problems.take(2)) _InsightTile(insight: p),
            for (final w in a.weaknesses.take(a.problems.isEmpty ? 2 : 1))
              _InsightTile(insight: w),
          ],

          // ── Action plan ──
          const SizedBox(height: 14),
          _SectionLabel(icon: Icons.checklist_rounded, label: 'Plan d\'action'),
          const SizedBox(height: 10),
          for (var i = 0; i < a.actionPlan.length; i++)
            _ActionRow(index: i + 1, item: a.actionPlan[i]),

          // ── Tomorrow ──
          if (a.tomorrowGoals.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionLabel(
              icon: Icons.wb_twilight_rounded,
              label: 'Objectifs de demain',
            ),
            const SizedBox(height: 10),
            for (final g in a.tomorrowGoals)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flag_rounded, size: 14, color: AppColors.cyan),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        g.label,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
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

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.surfaceHover,
    );
    if (progress <= 0) return;

    final color = progress >= .65
        ? AppColors.green
        : progress >= .4
        ? AppColors.yellow
        : AppColors.red;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.accentText),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ],
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({required this.slice});

  final TimeSlice slice;

  Color get _color {
    final hex = slice.colorHex.replaceFirst('#', '');
    final value = int.tryParse(
      hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex,
      radix: 16,
    );
    return value == null ? AppColors.accent : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: slice.share),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  color: _color,
                  backgroundColor: AppColors.surfaceHover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              '${(slice.share * 100).round()} %',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (insight.severity) {
      InsightSeverity.positive => (AppColors.green, Icons.trending_up_rounded),
      InsightSeverity.warning => (
        AppColors.yellow,
        Icons.warning_amber_rounded,
      ),
      InsightSeverity.critical => (AppColors.red, Icons.error_outline_rounded),
      InsightSeverity.info => (AppColors.blue, Icons.info_outline_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.why,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.45,
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.index, required this.item});

  final int index;
  final ActionItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (item.detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.detail!,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
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

class _Expandable extends StatefulWidget {
  const _Expandable({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_Expandable> createState() => _ExpandableState();
}

class _ExpandableState extends State<_Expandable> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: AppColors.accentText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _open ? .5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.accentText,
                ),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: widget.child,
          ),
          crossFadeState: _open
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INPUT BAR
// ═══════════════════════════════════════════════════════════════════════════

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.suggestions,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSend;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        // Clear the floating nav bar.
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (suggestions.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: enabled ? () => onSend(suggestions[i]) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: .25),
                      ),
                    ),
                    child: Text(
                      suggestions[i],
                      style: TextStyle(
                        color: AppColors.accentText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (suggestions.isNotEmpty) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: onSend,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Posez une question à votre coach…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: enabled ? () => onSend(controller.text) : null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: enabled ? 1 : .5,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: .35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
