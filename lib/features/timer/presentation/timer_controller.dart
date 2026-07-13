import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/data/dashboard_repository.dart';
import '../../subjects/domain/subject.dart';
import '../data/sessions_repository.dart';

enum TimerPhase { focus, shortBreak }

@immutable
class PomodoroState {
  const PomodoroState({
    this.phase = TimerPhase.focus,
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.remainingSeconds = 25 * 60,
    this.isRunning = false,
    this.subject,
    this.sessionsCompleted = 0,
    this.startedAt,
  });

  final TimerPhase phase;
  final int focusMinutes;
  final int breakMinutes;
  final int remainingSeconds;
  final bool isRunning;
  final Subject? subject;
  final int sessionsCompleted;
  final DateTime? startedAt;

  int get phaseTotalSeconds =>
      (phase == TimerPhase.focus ? focusMinutes : breakMinutes) * 60;

  /// 1 → full ring, 0 → empty.
  double get progress =>
      phaseTotalSeconds == 0 ? 0 : remainingSeconds / phaseTotalSeconds;

  bool get hasActiveSession => subject != null;

  String get display {
    final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PomodoroState copyWith({
    TimerPhase? phase,
    int? focusMinutes,
    int? breakMinutes,
    int? remainingSeconds,
    bool? isRunning,
    Subject? subject,
    bool clearSubject = false,
    int? sessionsCompleted,
    DateTime? startedAt,
    bool clearStartedAt = false,
  }) {
    return PomodoroState(
      phase: phase ?? this.phase,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      subject: clearSubject ? null : (subject ?? this.subject),
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    );
  }
}

/// Pomodoro state machine.
///
/// Focus phase completion posts the session to the backend (which updates
/// subject/user stats and the streak), then rolls into a short break.
class PomodoroController extends Notifier<PomodoroState> {
  Timer? _ticker;

  @override
  PomodoroState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const PomodoroState();
  }

  void adjustFocusMinutes(int delta) {
    if (state.isRunning || state.hasActiveSession) return;
    final minutes = (state.focusMinutes + delta).clamp(5, 60);
    state = state.copyWith(
      focusMinutes: minutes,
      remainingSeconds: minutes * 60,
    );
  }

  void start(Subject subject) {
    _ticker?.cancel();
    state = state.copyWith(
      subject: subject,
      isRunning: true,
      phase: TimerPhase.focus,
      remainingSeconds: state.hasActiveSession && state.remainingSeconds > 0
          ? state.remainingSeconds
          : state.focusMinutes * 60,
      startedAt: state.startedAt ?? DateTime.now(),
    );
    _startTicker();
  }

  void resume() {
    if (state.subject == null || state.remainingSeconds <= 0) return;
    state = state.copyWith(isRunning: true);
    _startTicker();
  }

  void pause() {
    _ticker?.cancel();
    state = state.copyWith(isRunning: false);
  }

  /// Stops and discards the current phase without saving.
  void stop() {
    _ticker?.cancel();
    state = state.copyWith(
      isRunning: false,
      clearSubject: true,
      clearStartedAt: true,
      phase: TimerPhase.focus,
      remainingSeconds: state.focusMinutes * 60,
    );
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (state.remainingSeconds > 1) {
      state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      return;
    }

    _ticker?.cancel();

    if (state.phase == TimerPhase.focus) {
      await _completeFocusSession();
      // Set to break phase, but do not auto-start so the user can choose to pause/continue.
      state = state.copyWith(
        phase: TimerPhase.shortBreak,
        remainingSeconds: state.breakMinutes * 60,
        isRunning: false,
        clearStartedAt: true,
      );
    } else {
      // Break finished → back to idle focus, keep the subject selected.
      state = state.copyWith(
        phase: TimerPhase.focus,
        remainingSeconds: state.focusMinutes * 60,
        isRunning: false,
      );
    }
  }

  void skipBreak() {
    _ticker?.cancel();
    state = state.copyWith(
      phase: TimerPhase.focus,
      remainingSeconds: state.focusMinutes * 60,
      isRunning: false,
    );
  }

  Future<void> _completeFocusSession() async {
    final subject = state.subject;
    final startedAt = state.startedAt;
    state = state.copyWith(
      sessionsCompleted: state.sessionsCompleted + 1,
      isRunning: false,
    );
    if (subject == null) return;

    try {
      await ref
          .read(sessionsRepositoryProvider)
          .saveCompletedSession(
            subjectId: subject.id,
            startTime:
                startedAt ??
                DateTime.now().subtract(Duration(minutes: state.focusMinutes)),
            endTime: DateTime.now(),
          );
      // Stats changed server-side — refresh the dashboard.
      ref.invalidate(dashboardStatsProvider);
    } catch (_) {
      // Session save failure must never crash the timer; the dashboard
      // simply won't reflect this session until connectivity returns.
    }
  }
}

final pomodoroControllerProvider =
    NotifierProvider<PomodoroController, PomodoroState>(PomodoroController.new);
