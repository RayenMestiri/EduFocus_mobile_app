import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/offline/offline_badge.dart';
import '../../../subjects/data/subjects_repository.dart';
import '../../../subjects/domain/subject.dart';
import '../timer_controller.dart';
import '../widgets/pomo_ring.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeControllerProvider);
    final timer = ref.watch(pomodoroControllerProvider);
    final subjects = ref.watch(subjectsControllerProvider);
    final isBreak = timer.phase == TimerPhase.shortBreak;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
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
                            'ESPACE ÉTUDE  >  POMODORO',
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
                        'Chronomètre Focus',
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
                // Session Completed Pill
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
                    '${timer.sessionsCompleted} session${timer.sessionsCompleted > 1 ? "s" : ""}',
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

            // ── Phase pill ──
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: (isBreak ? AppColors.green : AppColors.accent)
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: (isBreak ? AppColors.green : AppColors.accent)
                        .withValues(alpha: .3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBreak
                          ? Icons.self_improvement_rounded
                          : Icons.psychology_rounded,
                      size: 15,
                      color: isBreak ? AppColors.green : AppColors.accentText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBreak ? 'Pause — respirez' : 'Durée de focus',
                      style: TextStyle(
                        color: isBreak ? AppColors.green : AppColors.accentText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Ring ──
            Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: PomoRing(
                  progress: timer.progress,
                  isBreak: isBreak,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timer.display,
                        style: text.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (timer.subject != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: timer.subject!.color.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: timer.subject!.color.withValues(
                                alpha: .35,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SubjectIcon(timer.subject!, size: 15),
                              const SizedBox(width: 6),
                              Text(
                                timer.subject!.name,
                                style: TextStyle(
                                  color: timer.subject!.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Controls ──
            if (!timer.hasActiveSession) ...[
              // Duration adjuster
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AdjustButton(
                    label: '−5',
                    onTap: () => ref
                        .read(pomodoroControllerProvider.notifier)
                        .adjustFocusMinutes(-5),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      Text(
                        '${timer.focusMinutes}',
                        style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'MIN',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  _AdjustButton(
                    label: '+5',
                    onTap: () => ref
                        .read(pomodoroControllerProvider.notifier)
                        .adjustFocusMinutes(5),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Sélectionnez une matière pour commencer',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              subjects.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.red),
                ),
                data: (list) => Column(
                  children: [
                    for (final subject in list)
                      _SubjectStartTile(
                        subject: subject,
                        onTap: () => ref
                            .read(pomodoroControllerProvider.notifier)
                            .start(subject),
                      ),
                    if (list.isEmpty)
                      Text(
                        'Ajoutez d\'abord une matière dans l\'onglet Matières.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              if (isBreak &&
                  !timer.isRunning &&
                  timer.remainingSeconds == timer.breakMinutes * 60) ...[
                // Prompt for pause/continue when focus just finished
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.celebration_rounded,
                        color: AppColors.yellow,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Session Focus Terminée ! 🎉',
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Voulez-vous prendre une pause de respiration ou continuer directement ?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => ref
                                  .read(pomodoroControllerProvider.notifier)
                                  .resume(),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.green,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.self_improvement_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Pause',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(pomodoroControllerProvider.notifier)
                                  .skipBreak(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: BorderSide(color: AppColors.border),
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.flash_on_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Continuer',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (isBreak && timer.isRunning) ...[
                // Premium respiration & background audio view during active break
                BreathingRelaxationView(
                  onSkip: () =>
                      ref.read(pomodoroControllerProvider.notifier).skipBreak(),
                ),
              ] else ...[
                // Standard controls when timer is running in focus phase or paused during break
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundControl(
                      icon: timer.isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: isBreak ? AppColors.green : AppColors.accent,
                      size: 76,
                      onTap: () {
                        final notifier = ref.read(
                          pomodoroControllerProvider.notifier,
                        );
                        timer.isRunning ? notifier.pause() : notifier.resume();
                      },
                    ),
                    const SizedBox(width: 18),
                    _RoundControl(
                      icon: isBreak
                          ? Icons.skip_next_rounded
                          : Icons.stop_rounded,
                      color: isBreak ? AppColors.textSecondary : AppColors.red,
                      size: 56,
                      filled: false,
                      onTap: () {
                        if (isBreak) {
                          ref
                              .read(pomodoroControllerProvider.notifier)
                              .skipBreak();
                        } else {
                          ref.read(pomodoroControllerProvider.notifier).stop();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 52,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectStartTile extends StatelessWidget {
  const _SubjectStartTile({required this.subject, required this.onTap});

  final Subject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                SubjectIcon(subject, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subject.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.play_arrow_rounded, color: subject.color, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.size,
    this.filled = true,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color : color.withValues(alpha: .1),
      shape: CircleBorder(
        side: filled ? BorderSide.none : BorderSide(color: color),
      ),
      elevation: filled ? 8 : 0,
      shadowColor: color.withValues(alpha: .5),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: filled ? Colors.white : color,
            size: size * .48,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BREATHING AND AUDIO RELAXATION COMPONENT
// ═══════════════════════════════════════════════════════════════

class BreathingRelaxationView extends StatefulWidget {
  const BreathingRelaxationView({super.key, required this.onSkip});

  final VoidCallback onSkip;

  @override
  State<BreathingRelaxationView> createState() =>
      _BreathingRelaxationViewState();
}

class _BreathingRelaxationViewState extends State<BreathingRelaxationView> {
  late Timer _breathTimer;
  int _seconds = 0;
  String _phaseText = 'Inspirez... 🌬️';
  double _circleScale = 1.0;
  Color _circleColor = AppColors.green;

  // Audio player
  late final AudioPlayer _audioPlayer;
  String _selectedTrack = 'silent';

  final List<Map<String, String>> _tracks = [
    {'id': 'silent', 'name': '🔇 Silencieux', 'url': ''},
    {
      'id': 'rain',
      'name': '🌧️ Pluie',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    },
    {
      'id': 'forest',
      'name': '🌲 Forêt',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    },
    {
      'id': 'lofi',
      'name': '🎹 Study Lofi',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    },
    {
      'id': 'ocean',
      'name': '🌊 Vagues',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    },
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);

    // Start breathing cycle timer: 4s inhale, 4s hold, 4s exhale
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _seconds = (_seconds + 1) % 12;
        if (_seconds < 4) {
          _phaseText = 'Inspirez... 🌬️';
          _circleScale = 1.0 + (_seconds / 4.0) * 0.5; // 1.0 to 1.5
          _circleColor = AppColors.green;
        } else if (_seconds < 8) {
          _phaseText = 'Bloquez... 🧘';
          _circleScale = 1.5;
          _circleColor = AppColors.cyan;
        } else {
          _phaseText = 'Expirez... 💨';
          _circleScale = 1.5 - ((_seconds - 8) / 4.0) * 0.5; // 1.5 to 1.0
          _circleColor = AppColors.accent;
        }
      });
    });
  }

  @override
  void dispose() {
    _breathTimer.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playTrack(String id, String url) async {
    if (!mounted) return;
    setState(() {
      _selectedTrack = id;
    });

    if (id == 'silent') {
      await _audioPlayer.stop();
      return;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.self_improvement_rounded,
                color: _circleColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Guide de Respiration',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Pulsing Circle Visual
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOut,
                  width: 100 * _circleScale,
                  height: 100 * _circleScale,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _circleColor.withValues(alpha: .15),
                    border: Border.all(color: _circleColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _circleColor.withValues(alpha: .3),
                        blurRadius: 28 * _circleScale,
                      ),
                    ],
                  ),
                  child: Text(
                    _phaseText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Background Audio Section
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Ambiance Sonore',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final track in _tracks)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        track['name']!,
                        style: TextStyle(
                          color: _selectedTrack == track['id']
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      selected: _selectedTrack == track['id'],
                      onSelected: (_) =>
                          _playTrack(track['id']!, track['url']!),
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.surfaceSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: _selectedTrack == track['id']
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Skip button
          OutlinedButton.icon(
            onPressed: widget.onSkip,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.skip_next_rounded, size: 20),
            label: const Text(
              'Passer la pause',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
