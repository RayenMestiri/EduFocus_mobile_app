import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../todos/data/todos_repository.dart';
import '../../../todos/domain/todo.dart';
import '../../../todos/presentation/widgets/todo_form_sheet.dart';
import '../../data/subjects_repository.dart';
import '../../domain/subject.dart';
import '../widgets/subject_form_sheet.dart';

/// « Matières & Tâches » — animated segmented workspace.
class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  int _segment = 0; // 0 = Matières · 1 = Tâches

  @override
  Widget build(BuildContext context) {
    ref.watch(themeControllerProvider);
    final subjects = ref.watch(subjectsControllerProvider);
    final todos = ref.watch(todosControllerProvider);

    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 86),
        child: FloatingActionButton.extended(
          heroTag: 'st-fab',
          onPressed: () => _segment == 0
              ? showSubjectFormSheet(context)
              : showTodoFormSheet(context),
          backgroundColor: _segment == 0 ? AppColors.accent : AppColors.green,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: Icon(
            _segment == 0 ? Icons.add_rounded : Icons.add_task_rounded,
            size: 20,
          ),
          label: Text(
            _segment == 0 ? 'Matière' : 'Tâche',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ),
      body: RefreshIndicator(
        edgeOffset: 130,
        onRefresh: () async {
          ref.invalidate(subjectsControllerProvider);
          ref.invalidate(todosControllerProvider);
          await Future.wait([
            ref.read(subjectsControllerProvider.future),
            ref.read(todosControllerProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 20),
                child: Row(
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
                    Text(
                      'Espace d\'étude',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // ══ Segmented control ══
            _SegmentedControl(
              segment: _segment,
              subjectCount: subjects.value?.length,
              todoCount: todos.value?.where((t) => !t.done).length,
              onChanged: (i) => setState(() => _segment = i),
            ),
            const SizedBox(height: 20),

            // ══ Content ══
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .03),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _segment == 0
                  ? _SubjectsPane(key: const ValueKey(0), subjects: subjects)
                  : _TodosPane(key: const ValueKey(1), todos: todos),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SEGMENTED CONTROL
// ═══════════════════════════════════════════════════════════════

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.segment,
    required this.onChanged,
    this.subjectCount,
    this.todoCount,
  });

  final int segment;
  final ValueChanged<int> onChanged;
  final int? subjectCount;
  final int? todoCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: segment * segmentWidth,
                width: segmentWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: segment == 0
                        ? AppColors.heroGradient
                        : LinearGradient(
                            colors: [Color(0xFF059669), AppColors.green],
                          ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (segment == 0 ? AppColors.accent : AppColors.green)
                                .withValues(alpha: .35),
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
                    _SegmentTab(
                      icon: Icons.menu_book_rounded,
                      label: 'Matières',
                      count: subjectCount,
                      active: segment == 0,
                      onTap: () => onChanged(0),
                    ),
                    _SegmentTab(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Tâches',
                      count: todoCount,
                      active: segment == 1,
                      onTap: () => onChanged(1),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: .22)
                      : AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PANES
// ═══════════════════════════════════════════════════════════════

class _SubjectsPane extends ConsumerWidget {
  const _SubjectsPane({super.key, required this.subjects});

  final AsyncValue<List<Subject>> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return subjects.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _InlineError(message: e.toString()),
      data: (list) => list.isEmpty
          ? const _EmptyHint(
              icon: Icons.menu_book_rounded,
              title: 'Aucune matière',
              subtitle:
                  'Créez votre première matière pour structurer vos révisions.',
            )
          : Column(
              children: [
                for (final subject in list) _SubjectCard(subject: subject),
              ],
            ),
    );
  }
}

class _TodosPane extends ConsumerWidget {
  const _TodosPane({super.key, required this.todos});

  final AsyncValue<List<Todo>> todos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return todos.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _InlineError(message: e.toString()),
      data: (list) {
        final activeList = list.where((t) => !t.done).toList();
        final doneList = list.where((t) => t.done).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (list.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: list.isEmpty ? 0 : doneList.length / list.length,
                        minHeight: 6,
                        color: AppColors.green,
                        backgroundColor: AppColors.surfaceHover,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${doneList.length} sur ${list.length} terminées',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (activeList.isEmpty && doneList.isEmpty)
              const _EmptyHint(
                icon: Icons.task_alt_rounded,
                title: 'Gérez vos tâches',
                subtitle:
                    'Ajoutez des tâches avec différents niveaux de priorité pour ne rien oublier.',
              )
            else ...[
              if (activeList.isNotEmpty) ...[
                const _GroupLabel(label: 'En cours'),
                const SizedBox(height: 8),
                for (final todo in activeList) _TodoTile(todo: todo),
                const SizedBox(height: 16),
              ],
              if (doneList.isNotEmpty) ...[
                const _GroupLabel(label: 'Terminées'),
                const SizedBox(height: 8),
                for (final todo in doneList) _TodoTile(todo: todo),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  const _SubjectCard({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Colored accent bar
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: subject.color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: subject.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SubjectIcon(subject),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${subject.totalStudyMinutes} mins · ${subject.totalSessions} sessions',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => showSubjectFormSheet(context, existing: subject),
            icon: Icon(
              Icons.edit_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          IconButton(
            onPressed: () => _confirmDelete(context, ref),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Supprimer la matière ?'),
        content: Text(
          'Toutes les sessions de focus liées à "${subject.name}" seront conservées, mais la matière sera supprimée définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () {
              ref.read(subjectsControllerProvider.notifier).remove(subject.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _TodoTile extends ConsumerWidget {
  const _TodoTile({required this.todo});

  final Todo todo;

  Color get _priorityColor => switch (todo.priority) {
    'urgent' => AppColors.red,
    'high' => AppColors.yellow,
    'medium' => AppColors.cyan,
    _ => AppColors.textMuted,
  };

  String get _priorityLabel => switch (todo.priority) {
    'urgent' => 'Urgente',
    'high' => 'Haute',
    'medium' => 'Moyenne',
    _ => 'Basse',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects =
        ref.watch(subjectsControllerProvider).value ?? const <Subject>[];
    Subject? subject;
    for (final s in subjects) {
      if (s.id == todo.subjectId) {
        subject = s;
        break;
      }
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: todo.done ? .55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: _priorityColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Checkbox(
              value: todo.done,
              onChanged: (_) =>
                  ref.read(todosControllerProvider.notifier).toggle(todo),
              activeColor: AppColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: BorderSide(color: AppColors.textMuted),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: todo.done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _priorityColor.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _priorityLabel,
                          style: TextStyle(
                            color: _priorityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (subject != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: subject.color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            subject.name,
                            style: TextStyle(
                              color: subject.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => showTodoFormSheet(context, existing: todo),
              icon: Icon(
                Icons.edit_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
            IconButton(
              onPressed: () =>
                  ref.read(todosControllerProvider.notifier).remove(todo.id),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: .25)),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.red, fontSize: 13),
      ),
    );
  }
}
