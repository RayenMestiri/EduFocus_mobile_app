import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_stats.dart';

/// Accueil — the screen a student opens first, every day.
///
/// Deliberately NOT a stats-grid dashboard: every section has its own shape,
/// size and rhythm — a hero, a horizontal action shelf, an asymmetric duo,
/// a headline weekly stat, a subject carousel — so nothing reads as an
/// admin panel. All numbers come straight from GET /api/stats/dashboard.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeControllerProvider);
    final user = ref.watch(authControllerProvider).value;
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Ambient light field — the canvas never feels flat/dead ──
          Positioned(
            top: -110,
            right: -90,
            child: _GlowOrb(
              size: 300,
              color: AppColors.accentBright,
              alpha: .14,
            ),
          ),
          Positioned(
            bottom: 60,
            left: -130,
            child: _GlowOrb(size: 340, color: AppColors.indigo, alpha: .10),
          ),
          Positioned(
            top: 280,
            left: -60,
            child: _GlowOrb(size: 200, color: AppColors.cyan, alpha: .06),
          ),

          RefreshIndicator(
            onRefresh: () => ref.refresh(dashboardStatsProvider.future),
            edgeOffset: 100,
            backgroundColor: AppColors.surfaceSecondary,
            color: AppColors.accentBright,
            child: stats.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.accentBright),
              ),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(dashboardStatsProvider),
              ),
              data: (data) => _DashboardBody(
                data: data,
                userName: user?.name ?? 'Étudiant',
                userInitial: user?.initial ?? 'U',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.alpha,
  });

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BODY
// ═══════════════════════════════════════════════════════════════════════════

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.userName,
    required this.userInitial,
  });

  final DashboardStats data;
  final String userName;
  final String userInitial;

  static const _days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Bonne nuit';
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String get _dateLabel {
    final now = DateTime.now();
    return '${_days[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}';
  }

  /// A short line of encouragement that reacts to real progress — never
  /// invented data, just a different tone for a different state.
  String _statusLine(TodayStats today) {
    if (today.plannedMinutes == 0) {
      return 'Aucun objectif planifié pour l\'instant';
    }
    if (today.progress >= 1) return 'Objectif du jour atteint — bravo !';
    if (today.progress >= .6) return 'Vous y êtes presque, continuez';
    if (today.progress > 0) return 'Belle avancée, gardez le rythme';
    return 'Prêt à démarrer votre première session ?';
  }

  @override
  Widget build(BuildContext context) {
    final today = data.today;
    final firstName = userName.split(' ').first;
    var delay = 0;
    Widget reveal(Widget child) {
      final d = delay;
      delay += 60;
      return _Reveal(delayMs: d, child: child);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 128),
      children: [
        // ── Header: greeting first, everything else quiet ──
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateLabel.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_greeting, $firstName',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          letterSpacing: -0.9,
                          height: 1.1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Pressable(
                  onTap: () => context.push(AppRoutes.profile),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: .4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      userInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 1. Hero: today's focus (the one big statement) ──
        reveal(_FocusHero(data: data, statusLine: _statusLine(today))),
        const SizedBox(height: 22),

        // ── 2. Quick actions: a shelf, not a grid ──
        reveal(
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _ActionTile(
                  icon: Icons.bolt_rounded,
                  label: 'Focus',
                  color: AppColors.accentBright,
                  large: true,
                  onTap: () => context.go(AppRoutes.timer),
                ),
                const SizedBox(width: 10),
                _ActionTile(
                  icon: Icons.auto_stories_rounded,
                  label: 'Study Hub',
                  color: AppColors.green,
                  onTap: () => context.push(AppRoutes.studyHub),
                ),
                const SizedBox(width: 10),
                _ActionTile(
                  icon: Icons.psychology_rounded,
                  label: 'Coach IA',
                  color: AppColors.yellow,
                  onTap: () => context.go(AppRoutes.coach),
                ),
                const SizedBox(width: 10),
                _ActionTile(
                  icon: Icons.menu_book_rounded,
                  label: 'Matières',
                  color: AppColors.cyan,
                  onTap: () => context.go(AppRoutes.subjects),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        // ── 3. Asymmetric duo: streak (wide) + tasks (narrow) ──
        reveal(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: _StreakCard(
                    streak: data.streak,
                    best: data.longestStreak,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: _TasksOrb(today: today)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        // ── 4. Weekly rhythm: one headline number, not three equal boxes ──
        reveal(_WeekRhythmCard(week: data.week)),

        // ── 5. Subjects spotlight carousel ──
        if (data.subjects.isNotEmpty) ...[
          const SizedBox(height: 26),
          reveal(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    'Vos matières',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  _Pressable(
                    onTap: () => context.go(AppRoutes.subjects),
                    child: Text(
                      'Tout voir',
                      style: TextStyle(
                        color: AppColors.accentText,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          reveal(_SubjectsCarousel(subjects: data.subjects)),
        ],

        const SizedBox(height: 26),

        // ── 6. Quiet motivational footer ──
        reveal(const _MotivationStrip()),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOCUS HERO
// ═══════════════════════════════════════════════════════════════════════════

class _FocusHero extends StatelessWidget {
  const _FocusHero({required this.data, required this.statusLine});

  final DashboardStats data;
  final String statusLine;

  @override
  Widget build(BuildContext context) {
    final today = data.today;
    final pct = (today.progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.isLight
              ? AppColors.border.withValues(alpha: 0.8)
              : AppColors.borderBright,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.isLight
              ? [
                  AppColors.accent.withValues(alpha: .10),
                  AppColors.surfaceGlass,
                  AppColors.indigo.withValues(alpha: .06),
                ]
              : [
                  AppColors.accentDeep.withValues(alpha: .3),
                  AppColors.surfaceGlass,
                  AppColors.indigo.withValues(alpha: .14),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.isLight
                ? AppColors.shadow.withValues(alpha: .06)
                : AppColors.accentDeep.withValues(alpha: .22),
            blurRadius: AppColors.isLight ? 20 : 36,
            offset: AppColors.isLight ? const Offset(0, 8) : const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FOCUS DU JOUR',
                  style: TextStyle(
                    color: AppColors.accentText.withValues(alpha: .9),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      today.studiedMinutes.asDuration,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 34,
                        letterSpacing: -1.4,
                        height: 1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (today.plannedMinutes > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '/ ${today.plannedMinutes.asDuration}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  statusLine,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                if (data.streak > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 15,
                        color: AppColors.yellow,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${data.streak} jour${data.streak > 1 ? 's' : ''} de suite',
                        style: TextStyle(
                          color: AppColors.yellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 92,
            height: 92,
            child: CustomPaint(
              painter: _RingPainter(progress: today.progress),
              child: Center(
                child: Text(
                  '$pct%',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    letterSpacing: -0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = AppColors.surfaceHover,
    );

    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [
            AppColors.accentBright,
            AppColors.indigo,
            AppColors.accentBright,
          ],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// QUICK ACTION TILE
// ═══════════════════════════════════════════════════════════════════════════

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        width: large ? 104 : 88,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: large
                ? color.withValues(alpha: AppColors.isLight ? .22 : .35)
                : AppColors.border,
          ),
          gradient: large
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: AppColors.isLight ? .12 : .22),
                    color.withValues(alpha: .06),
                  ],
                )
              : null,
          color: large ? null : AppColors.surfaceGlass,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STREAK CARD (wide, illustrative dots)
// ═══════════════════════════════════════════════════════════════════════════

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.best});

  final int streak;
  final int best;

  @override
  Widget build(BuildContext context) {
    final filled = streak.clamp(0, 7);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.yellow.withValues(
            alpha: AppColors.isLight ? .35 : .22,
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.yellow.withValues(
              alpha: AppColors.isLight ? .05 : .1,
            ),
            AppColors.surfaceGlass,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.yellow,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$streak',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  letterSpacing: -1,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'jour${streak > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Série en cours · record $best',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < filled
                          ? AppColors.yellow
                          : AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: i < filled
                          ? [
                              BoxShadow(
                                color: AppColors.yellow.withValues(alpha: .5),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                if (i != 6) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TASKS ORB (narrow, circular)
// ═══════════════════════════════════════════════════════════════════════════

class _TasksOrb extends StatelessWidget {
  const _TasksOrb({required this.today});

  final TodayStats today;

  @override
  Widget build(BuildContext context) {
    final ratio = today.totalTasks == 0
        ? 0.0
        : today.completedTasks / today.totalTasks;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: ratio == 0 ? null : ratio,
                    strokeWidth: 5,
                    backgroundColor: AppColors.surfaceHover,
                    valueColor: AlwaysStoppedAnimation(AppColors.blue),
                  ),
                ),
                Icon(
                  Icons.task_alt_rounded,
                  color: AppColors.blue.withValues(alpha: .8),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${today.completedTasks}/${today.totalTasks}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'tâches',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WEEK RHYTHM CARD (headline stat, not equal columns)
// ═══════════════════════════════════════════════════════════════════════════

class _WeekRhythmCard extends StatelessWidget {
  const _WeekRhythmCard({required this.week});

  final WeekStats week;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.cyan, AppColors.indigo],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CETTE SEMAINE',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  week.totalMinutes.asDuration,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    letterSpacing: -0.7,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${week.totalSessions} sessions',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${week.averagePerDay.asDuration} / jour',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUBJECTS CAROUSEL
// ═══════════════════════════════════════════════════════════════════════════

class _SubjectsCarousel extends StatelessWidget {
  const _SubjectsCarousel({required this.subjects});

  final List<SubjectSummary> subjects;

  @override
  Widget build(BuildContext context) {
    final sorted = [...subjects]
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
    final maxMinutes = sorted.first.totalMinutes.clamp(1, 1 << 30);

    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) =>
            _SubjectSpotlight(subject: sorted[i], maxMinutes: maxMinutes),
      ),
    );
  }
}

class _SubjectSpotlight extends StatelessWidget {
  const _SubjectSpotlight({required this.subject, required this.maxMinutes});

  final SubjectSummary subject;
  final int maxMinutes;

  Color get _color {
    final hex = subject.colorHex.replaceFirst('#', '');
    final value = int.tryParse(
      hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex,
      radix: 16,
    );
    return value == null ? AppColors.accent : Color(0xFF000000 | value);
  }

  bool get _isIconName => RegExp(r'^[a-z_]+$').hasMatch(subject.icon);

  static const _materialIcons = <String, IconData>{
    'menu_book': Icons.menu_book_rounded,
    'auto_stories': Icons.auto_stories_rounded,
    'palette': Icons.palette_rounded,
    'brush': Icons.brush_rounded,
    'calculate': Icons.calculate_rounded,
    'functions': Icons.functions_rounded,
    'science': Icons.science_rounded,
    'biotech': Icons.biotech_rounded,
    'code': Icons.code_rounded,
    'terminal': Icons.terminal_rounded,
    'computer': Icons.computer_rounded,
    'language': Icons.language_rounded,
    'translate': Icons.translate_rounded,
    'public': Icons.public_rounded,
    'history_edu': Icons.history_edu_rounded,
    'psychology': Icons.psychology_rounded,
    'music_note': Icons.music_note_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'school': Icons.school_rounded,
    'book': Icons.book_rounded,
    'edit': Icons.edit_rounded,
    'star': Icons.star_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final ratio = maxMinutes == 0 ? 0.0 : subject.totalMinutes / maxMinutes;

    return _Pressable(
      onTap: () {},
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withValues(
              alpha: AppColors.isLight ? .16 : .28,
            ),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(
                alpha: AppColors.isLight ? .05 : .16,
              ),
              AppColors.surfaceGlass,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(11),
              ),
              child: _isIconName
                  ? Icon(
                      _materialIcons[subject.icon] ?? Icons.menu_book_rounded,
                      color: color,
                      size: 17,
                    )
                  : Text(subject.icon, style: const TextStyle(fontSize: 16)),
            ),
            const Spacer(),
            Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${subject.totalMinutes.asDuration} · ${subject.totalSessions} sess.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                color: color,
                backgroundColor: AppColors.surfaceHover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MOTIVATION STRIP
// ═══════════════════════════════════════════════════════════════════════════

class _MotivationStrip extends StatelessWidget {
  const _MotivationStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.spa_rounded, color: AppColors.green, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'La régularité bat l\'intensité. Une petite session vaut mieux qu\'aucune.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MICRO-INTERACTIONS
// ═══════════════════════════════════════════════════════════════════════════

/// Wraps any tappable widget with a soft scale-down press feedback —
/// the "every tap should animate" premium touch.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades + slides a section in once, staggered by [delayMs] — keeps the
/// first paint from feeling static without any external animation package.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.child, required this.delayMs});

  final Widget child;
  final int delayMs;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, .04),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ERROR STATE
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 100),
        Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réessayer'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
