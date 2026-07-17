import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../dashboard/domain/dashboard_stats.dart';
import '../../data/settings_repository.dart';

/// Profil & réglages — identity card, lifetime stats, timer settings synced
/// with the backend, logout.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  TimerSettings? _draft;
  bool _saving = false;

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(settingsRepositoryProvider).save(draft);
      if (!mounted) return;
      setState(() {
        _draft = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Réglages enregistrés ✓')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final settings = ref.watch(timerSettingsProvider);
    final text = Theme.of(context).textTheme;
    final stats = user?.stats;

    // Seed the editable draft once the settings arrive.
    if (_draft == null && settings.value != null) {
      _draft = settings.value;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Identity card ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentDeep.withValues(alpha: .35),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .3),
                    ),
                  ),
                  child: Text(
                    user?.initial ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '',
                        style: text.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: text.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (stats != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFFFDE68A),
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${stats.points}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Lifetime stats ──
          if (stats != null) ...[
            Row(
              children: [
                _StatPill(
                  icon: Icons.schedule_rounded,
                  value: stats.totalStudyMinutes.asDuration,
                  label: 'Temps total',
                  color: AppColors.green,
                ),
                const SizedBox(width: 12),
                _StatPill(
                  icon: Icons.play_circle_rounded,
                  value: '${stats.totalSessions}',
                  label: 'Sessions',
                  color: AppColors.blue,
                ),
                const SizedBox(width: 12),
                _StatPill(
                  icon: Icons.local_fire_department_rounded,
                  value: '${stats.streak}',
                  label: 'Série',
                  color: AppColors.yellow,
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],

          // ── Appearance ──
          Text(
            'Apparence',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          const _ThemeModeSelector(),
          const SizedBox(height: 28),

          // ── Timer settings ──
          Text(
            'Réglages du timer',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          settings.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                Text(e.toString(), style: TextStyle(color: AppColors.red)),
            data: (_) {
              final draft = _draft;
              if (draft == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                // ListTiles paint ink on the nearest Material ancestor; a
                // transparent one keeps splashes visible above the glass box.
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      _SettingSlider(
                        icon: Icons.psychology_rounded,
                        label: 'Durée de focus',
                        value: draft.pomodoroLength,
                        min: 5,
                        max: 60,
                        unit: 'min',
                        color: AppColors.accentBright,
                        onChanged: (v) => setState(
                          () => _draft = draft.copyWith(pomodoroLength: v),
                        ),
                      ),
                      _SettingSlider(
                        icon: Icons.coffee_rounded,
                        label: 'Pause courte',
                        value: draft.shortBreak,
                        min: 1,
                        max: 15,
                        unit: 'min',
                        color: AppColors.green,
                        onChanged: (v) => setState(
                          () => _draft = draft.copyWith(shortBreak: v),
                        ),
                      ),
                      _SettingSlider(
                        icon: Icons.self_improvement_rounded,
                        label: 'Pause longue',
                        value: draft.longBreak,
                        min: 5,
                        max: 30,
                        unit: 'min',
                        color: AppColors.cyan,
                        onChanged: (v) => setState(
                          () => _draft = draft.copyWith(longBreak: v),
                        ),
                      ),
                      _SettingSlider(
                        icon: Icons.flag_rounded,
                        label: 'Objectif sessions / jour',
                        value: draft.dailySessionsGoal,
                        min: 1,
                        max: 30,
                        unit: '',
                        color: AppColors.yellow,
                        onChanged: (v) => setState(
                          () => _draft = draft.copyWith(dailySessionsGoal: v),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Démarrer les pauses automatiquement',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: draft.autoStartBreaks,
                        onChanged: (v) => setState(
                          () => _draft = draft.copyWith(autoStartBreaks: v),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Reprendre le focus automatiquement',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: draft.autoStartFocus,
                        onChanged: (v) => setState(
                          () => _draft = draft.copyWith(autoStartFocus: v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: .24),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Enregistrer les réglages',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Logout ──
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              backgroundColor: AppColors.red.withValues(alpha: .06),
              side: BorderSide(
                color: AppColors.red.withValues(
                  alpha: AppColors.isLight ? .22 : .4,
                ),
              ),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text(
              'Déconnexion',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: text.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.color,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              unit.isEmpty ? '$value' : '$value $unit',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: AppColors.surfaceHover,
            overlayColor: color.withValues(alpha: .15),
            trackHeight: 4,
            tickMarkShape: const _InactiveOnlyTickMarkShape(tickMarkRadius: 1.2),
            inactiveTickMarkColor: color.withValues(alpha: .24),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

class _InactiveOnlyTickMarkShape extends SliderTickMarkShape {
  const _InactiveOnlyTickMarkShape({this.tickMarkRadius});

  final double? tickMarkRadius;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) {
    return Size.fromRadius(tickMarkRadius ?? 1.5);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required bool isEnabled,
    required TextDirection textDirection,
  }) {
    // Determine active zone based on TextDirection
    final bool isLeftToRight = textDirection == TextDirection.ltr;
    final bool isActive = isLeftToRight
        ? center.dx <= thumbCenter.dx
        : center.dx >= thumbCenter.dx;

    // Do not paint tick marks in the active/filled zone
    if (isActive) {
      return;
    }

    final Canvas canvas = context.canvas;
    final double radius = tickMarkRadius ?? 1.5;
    final Paint paint = Paint()
      ..color = sliderTheme.inactiveTickMarkColor ?? Colors.grey.withValues(alpha: 0.5);

    canvas.drawCircle(center, radius, paint);
  }
}

// ═══════════════════════════════════════════════════════════════
// THEME MODE SELECTOR — animated 3-way segmented control
// ═══════════════════════════════════════════════════════════════

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  static const _options = [
    (ThemeMode.light, Icons.light_mode_rounded, 'Clair'),
    (ThemeMode.dark, Icons.dark_mode_rounded, 'Sombre'),
    (ThemeMode.system, Icons.brightness_auto_rounded, 'Système'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    final index = _options.indexWhere((o) => o.$1 == mode).clamp(0, 2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thème de l\'interface',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode == ThemeMode.system
                          ? 'Suit le réglage de votre appareil'
                          : mode == ThemeMode.light
                          ? 'Toujours lumineux'
                          : 'Toujours sombre',
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
          const SizedBox(height: 16),
          Container(
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth / _options.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      left: index * w,
                      width: w,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: .38),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: [
                          for (final (m, icon, label) in _options)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => ref
                                    .read(themeControllerProvider.notifier)
                                    .setMode(m),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 15,
                                      color: mode == m
                                          ? Colors.white
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: mode == m
                                              ? Colors.white
                                              : AppColors.textMuted,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
