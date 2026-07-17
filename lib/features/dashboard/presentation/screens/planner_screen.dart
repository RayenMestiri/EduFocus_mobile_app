import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../subjects/data/subjects_repository.dart';
import '../../../subjects/domain/subject.dart';
import '../../data/dashboard_repository.dart';
import '../../data/day_plan_repository.dart';
import '../../domain/day_plan.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _isSaving = false;

  final List<DayPlanSubject> _localSubjects = [];
  String? _loadedDateKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    _selectedDay = now;
  }

  String get _selectedDateStr => DateFormat('yyyy-MM-dd').format(_selectedDay);

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (isSameDay(_selectedDay, selectedDay)) return;
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _loadedDateKey = null; // Forces reload from the new date's plan data
    });
  }

  void _initializeLocalStates(DayPlan plan) {
    if (_loadedDateKey == _selectedDateStr) return;
    _loadedDateKey = _selectedDateStr;

    _localSubjects.clear();
    _localSubjects.addAll(plan.subjects);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final payload = {
      'date': _selectedDateStr,
      'subjects': _localSubjects.map((s) => s.toJson()).toList(),
    };

    try {
      await ref.read(dayPlanRepositoryProvider).savePlan(payload);

      ref.invalidate(dayPlanProvider(_selectedDateStr));
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📅 Planning enregistré avec succès !'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'enregistrer le planning : $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAddSessionBottomSheet(List<Subject> allSubjects) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddSessionBottomSheet(
          availableSubjects: allSubjects,
          onAdd: (subjectId, session, priority) {
            setState(() {
              // Find if this subject already exists in the day plan
              final existingSubjectIndex = _localSubjects.indexWhere(
                (s) => s.subjectId == subjectId,
              );

              if (existingSubjectIndex != -1) {
                final existingSubject = _localSubjects[existingSubjectIndex];
                final updatedSessions = List<DayPlanSubjectSession>.from(
                  existingSubject.sessions,
                )..add(session);

                // Sum goal minutes from all sessions
                final newGoalMinutes = updatedSessions.fold(
                  0,
                  (sum, s) => sum + s.duration,
                );

                _localSubjects[existingSubjectIndex] = DayPlanSubject(
                  subjectId: existingSubject.subjectId,
                  subjectName: existingSubject.subjectName,
                  subjectColor: existingSubject.subjectColor,
                  subjectIcon: existingSubject.subjectIcon,
                  goalMinutes: newGoalMinutes,
                  studiedMinutes: existingSubject.studiedMinutes,
                  priority: priority,
                  sessions: updatedSessions,
                );
              } else {
                // Find subject meta
                final subMeta = allSubjects.firstWhere(
                  (sub) => sub.id == subjectId,
                );
                _localSubjects.add(
                  DayPlanSubject(
                    subjectId: subjectId,
                    subjectName: subMeta.name,
                    subjectColor: subMeta.colorHex,
                    subjectIcon: subMeta.icon,
                    goalMinutes: session.duration,
                    studiedMinutes: 0,
                    priority: priority,
                    sessions: [session],
                  ),
                );
              }
            });
            _save();
          },
        );
      },
    );
  }

  void _toggleSessionCompleted(
    DayPlanSubject subject,
    DayPlanSubjectSession session,
  ) {
    setState(() {
      final subIdx = _localSubjects.indexWhere(
        (s) => s.subjectId == subject.subjectId,
      );
      if (subIdx == -1) return;

      final sub = _localSubjects[subIdx];
      final sesIdx = sub.sessions.indexWhere(
        (s) =>
            s.id == session.id ||
            (s.startTime == session.startTime && s.endTime == session.endTime),
      );
      if (sesIdx == -1) return;

      final originalSession = sub.sessions[sesIdx];
      final toggledSession = DayPlanSubjectSession(
        id: originalSession.id,
        startTime: originalSession.startTime,
        endTime: originalSession.endTime,
        duration: originalSession.duration,
        completed: !originalSession.completed,
        note: originalSession.note,
      );

      final updatedSessions = List<DayPlanSubjectSession>.from(sub.sessions)
        ..[sesIdx] = toggledSession;

      // Recalculate studied minutes locally
      final newStudiedMinutes = updatedSessions.fold(
        0,
        (sum, s) => sum + (s.completed ? s.duration : 0),
      );

      _localSubjects[subIdx] = DayPlanSubject(
        subjectId: sub.subjectId,
        subjectName: sub.subjectName,
        subjectColor: sub.subjectColor,
        subjectIcon: sub.subjectIcon,
        goalMinutes: sub.goalMinutes,
        studiedMinutes: newStudiedMinutes,
        priority: sub.priority,
        sessions: updatedSessions,
      );
    });
    _save();
  }

  void _deleteSession(DayPlanSubject subject, DayPlanSubjectSession session) {
    setState(() {
      final subIdx = _localSubjects.indexWhere(
        (s) => s.subjectId == subject.subjectId,
      );
      if (subIdx == -1) return;

      final sub = _localSubjects[subIdx];
      final updatedSessions = List<DayPlanSubjectSession>.from(sub.sessions)
        ..removeWhere(
          (s) =>
              s.id == session.id ||
              (s.startTime == session.startTime &&
                  s.endTime == session.endTime),
        );

      if (updatedSessions.isEmpty) {
        _localSubjects.removeAt(subIdx);
      } else {
        final newGoalMinutes = updatedSessions.fold(
          0,
          (sum, s) => sum + s.duration,
        );
        final newStudiedMinutes = updatedSessions.fold(
          0,
          (sum, s) => sum + (s.completed ? s.duration : 0),
        );

        _localSubjects[subIdx] = DayPlanSubject(
          subjectId: sub.subjectId,
          subjectName: sub.subjectName,
          subjectColor: sub.subjectColor,
          subjectIcon: sub.subjectIcon,
          goalMinutes: newGoalMinutes,
          studiedMinutes: newStudiedMinutes,
          priority: sub.priority,
          sessions: updatedSessions,
        );
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(dayPlanProvider(_selectedDateStr));
    final subjectsAsync = ref.watch(subjectsControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mon Agenda d\'Études',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.6),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Premium Calendar Header ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: TableCalendar(
              locale: 'fr_FR',
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: .25),
                  ),
                ),
                formatButtonTextStyle: TextStyle(
                  color: AppColors.accentText,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
                titleTextStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textSecondary,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                weekendStyle: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: .35),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent, width: 1.5),
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                defaultTextStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                weekendTextStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                outsideDaysVisible: false,
              ),
            ),
          ),

          // Date detail header label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.today_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  DateFormat(
                    'EEEE d MMMM yyyy',
                    'fr_FR',
                  ).format(_selectedDay).toUpperCase(),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Scrollable Timeline / Sessions View ──
          Expanded(
            child: planAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  err.toString(),
                  style: TextStyle(color: AppColors.red),
                ),
              ),
              data: (plan) {
                _initializeLocalStates(plan);

                // Flatten all sessions across subjects and sort by start time
                final List<MapEntry<DayPlanSubject, DayPlanSubjectSession>>
                allSessions = [];
                for (final subject in _localSubjects) {
                  for (final session in subject.sessions) {
                    allSessions.add(MapEntry(subject, session));
                  }
                }
                allSessions.sort(
                  (a, b) => a.value.startTime.compareTo(b.value.startTime),
                );

                return Column(
                  children: [
                    // Statistics header card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ProgressCard(
                        goal: _localSubjects.fold(
                          0,
                          (sum, s) => sum + s.goalMinutes,
                        ),
                        studied: _localSubjects.fold(
                          0,
                          (sum, s) => sum + s.studiedMinutes,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Sessions header list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sessions de la Journée',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Planification heure par heure',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          subjectsAsync.when(
                            data: (allSubs) => TextButton.icon(
                              onPressed: () =>
                                  _showAddSessionBottomSheet(allSubs),
                              icon: Icon(
                                Icons.add_alarm_rounded,
                                size: 16,
                                color: AppColors.accentText,
                              ),
                              label: Text(
                                'Ajouter une heure',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.accentText,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: allSessions.isEmpty
                          ? Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGlass,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.alarm_on_rounded,
                                    color: AppColors.textMuted,
                                    size: 36,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Aucune session planifiée pour aujourd\'hui.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Cliquez sur "Ajouter une heure" pour planifier votre étude.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: allSessions.length,
                              itemBuilder: (context, index) {
                                final entry = allSessions[index];
                                final subject = entry.key;
                                final session = entry.value;

                                return _SessionTimelineTile(
                                  subject: subject,
                                  session: session,
                                  onToggle: () =>
                                      _toggleSessionCompleted(subject, session),
                                  onDelete: () =>
                                      _deleteSession(subject, session),
                                );
                              },
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

// ══════════════════════════════════════════════════════════
//  TIMELINE SESSION TILE
// ══════════════════════════════════════════════════════════

class _SessionTimelineTile extends StatelessWidget {
  const _SessionTimelineTile({
    required this.subject,
    required this.session,
    required this.onToggle,
    required this.onDelete,
  });

  final DayPlanSubject subject;
  final DayPlanSubjectSession session;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  Color get _color {
    final hex = subject.subjectColor.replaceFirst('#', '');
    final value = int.tryParse(
      hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex,
      radix: 16,
    );
    return value == null ? AppColors.accent : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: session.completed
            ? AppColors.green.withValues(alpha: .06)
            : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: session.completed
              ? AppColors.green.withValues(alpha: .3)
              : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Left Time Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.startTime,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 10,
                  color: AppColors.textMuted,
                ),
                Text(
                  session.endTime,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: AppColors.textSecondary,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Middle Timeline vertical divider
            Container(
              width: 3,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 16),

            // Subject detail
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.subjectName,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      decoration: session.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${session.duration} min',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      if (subject.priority == 'high') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'HAUTE',
                            style: TextStyle(
                              color: AppColors.red,
                              fontSize: 6.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Complete button checkbox
            IconButton(
              onPressed: onToggle,
              icon: Icon(
                session.completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: session.completed
                    ? AppColors.green
                    : AppColors.textMuted,
                size: 24,
              ),
            ),

            // Delete button
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.red,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PROGRESS STATS HEADER CARD
// ══════════════════════════════════════════════════════════

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.goal, required this.studied});

  final int goal;
  final int studied;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = goal > 0 ? (studied / goal).clamp(0.0, 1.0) : 0.0;

    final studiedHours = (studied / 60).toStringAsFixed(1);
    final goalHours = (goal / 60).toStringAsFixed(1);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vue d\'ensemble du Planning',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .8),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: .2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeroStatItem(val: '${goalHours}h', label: 'Planifié'),
              _HeroStatItem(val: '${studiedHours}h', label: 'Complété'),
              _HeroStatItem(
                val: '${(progress * 100).round()}%',
                label: 'Progrès',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatItem extends StatelessWidget {
  const _HeroStatItem({required this.val, required this.label});
  final String val;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: .6),
            fontWeight: FontWeight.w900,
            fontSize: 7.5,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ADD SESSION BOTTOM SHEET FORM
// ══════════════════════════════════════════════════════════

class _AddSessionBottomSheet extends StatefulWidget {
  const _AddSessionBottomSheet({
    required this.availableSubjects,
    required this.onAdd,
  });

  final List<Subject> availableSubjects;
  final void Function(
    String subjectId,
    DayPlanSubjectSession session,
    String priority,
  )
  onAdd;

  @override
  State<_AddSessionBottomSheet> createState() => _AddSessionBottomSheetState();
}

class _AddSessionBottomSheetState extends State<_AddSessionBottomSheet> {
  late Subject _selectedSubject;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  String _priority = 'medium';

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.availableSubjects.first;
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int get _calculatedDuration {
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    final diff = endMin - startMin;
    return diff > 0 ? diff : 0;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hex = _selectedSubject.colorHex.replaceFirst('#', '');
    final val = int.tryParse(
      hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex,
      radix: 16,
    );
    final subColor = val == null ? AppColors.accent : Color(0xFF000000 | val);
    final duration = _calculatedDuration;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Planifier une Session',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 18),

          // ── Subject Selector (Horizontal list cards) ──
          Text(
            'Matière',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.availableSubjects.length,
              itemBuilder: (context, index) {
                final sub = widget.availableSubjects[index];
                final active = _selectedSubject.id == sub.id;

                final subHex = sub.colorHex.replaceFirst('#', '');
                final subVal = int.tryParse(
                  subHex.length == 3
                      ? subHex.split('').map((c) => '$c$c').join()
                      : subHex,
                  radix: 16,
                );
                final listColor = subVal == null
                    ? AppColors.accent
                    : Color(0xFF000000 | subVal);

                return GestureDetector(
                  onTap: () => setState(() => _selectedSubject = sub),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: active
                          ? listColor.withValues(alpha: .15)
                          : AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? listColor : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: active ? listColor : AppColors.textMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sub.name,
                          style: TextStyle(
                            color: active ? listColor : AppColors.textSecondary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // ── Start Time & End Time Picker Buttons ──
          Text(
            'Horaires',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimePickerButton(
                  label: 'Début',
                  time: _formatTimeOfDay(_startTime),
                  onTap: () => _selectTime(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePickerButton(
                  label: 'Fin',
                  time: _formatTimeOfDay(_endTime),
                  onTap: () => _selectTime(context, false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          // Live duration preview
          if (duration > 0)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: subColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: subColor.withValues(alpha: .2)),
                ),
                child: Text(
                  'Durée calculée : ${duration ~/ 60 > 0 ? "${duration ~/ 60}h " : ""}${duration % 60} min',
                  style: TextStyle(
                    color: subColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            Center(
              child: Text(
                'L\'heure de fin doit être après l\'heure de début',
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 18),

          // ── Priority Selector ──
          Text(
            'Priorité',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _priorityCard('low', 'Faible', AppColors.blue),
              const SizedBox(width: 8),
              _priorityCard('medium', 'Moyenne', AppColors.yellow),
              const SizedBox(width: 8),
              _priorityCard('high', 'Haute', AppColors.red),
            ],
          ),

          const SizedBox(height: 24),

          // ── Action Buttons ──
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: duration > 0
                      ? () {
                          widget.onAdd(
                            _selectedSubject.id,
                            DayPlanSubjectSession(
                              startTime: _formatTimeOfDay(_startTime),
                              endTime: _formatTimeOfDay(_endTime),
                              duration: duration,
                              completed: false,
                            ),
                            _priority,
                          );
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ajouter à l\'Agenda',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  Widget _priorityCard(String value, String label, Color color) {
    final active = _priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: .15)
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color : AppColors.border,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? color : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ],
            ),
            Icon(
              Icons.access_time_filled_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
