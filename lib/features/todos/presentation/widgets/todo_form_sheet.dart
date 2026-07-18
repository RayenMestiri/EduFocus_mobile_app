import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/dates.dart';
import '../../../subjects/data/subjects_repository.dart';
import '../../../subjects/domain/subject.dart';
import '../../data/todos_repository.dart';
import '../../domain/todo.dart';

List<(String, String, Color)> get kPriorities => [
  ('low', 'Basse', AppColors.blue),
  ('medium', 'Moyenne', AppColors.yellow),
  ('high', 'Haute', const Color(0xFFF97316)),
  ('urgent', 'Urgente', AppColors.red),
];

/// Bottom sheet to create or edit a task. Returns true when saved.
Future<bool?> showTodoFormSheet(BuildContext context, {Todo? existing}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TodoFormSheet(existing: existing),
  );
}

class _TodoFormSheet extends ConsumerStatefulWidget {
  const _TodoFormSheet({this.existing});

  final Todo? existing;

  @override
  ConsumerState<_TodoFormSheet> createState() => _TodoFormSheetState();
}

class _TodoFormSheetState extends ConsumerState<_TodoFormSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late String _priority = widget.existing?.priority ?? 'medium';
  late String? _subjectId = widget.existing?.subjectId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Le titre de la tâche est requis');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final controller = ref.read(todosControllerProvider.notifier);
    final error = widget.existing == null
        ? await controller.create(
            title: title,
            date: todayYmd(),
            priority: _priority,
            subjectId: _subjectId,
          )
        : await controller.updateTodo(
            widget.existing!.id,
            title: title,
            priority: _priority,
            subjectId: _subjectId,
          );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subjects =
        ref.watch(subjectsControllerProvider).value ?? const <Subject>[];
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;

    final double bottomPadding = keyboardHeight > 0 ? 24.0 : 108.0;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: screenHeight * 0.85 - keyboardHeight,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.borderBright)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              widget.existing == null
                  ? 'Nouvelle tâche'
                  : 'Modifier la tâche',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: AppColors.red, fontSize: 13),
                        ),
                      ),
                    TextField(
                      controller: _title,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Titre',
                        hintText: 'Ex : Réviser le chapitre 4',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'PRIORITÉ',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final (value, label, color) in kPriorities)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _priority = value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _priority == value
                                      ? color.withValues(alpha: .16)
                                      : AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _priority == value
                                        ? color
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: _priority == value
                                        ? color
                                        : AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'MATIÈRE (OPTIONNEL)',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _subjectId = null),
                          child: _SubjectChip(
                            label: 'Aucune',
                            color: AppColors.textMuted,
                            selected: _subjectId == null,
                          ),
                        ),
                        for (final subject in subjects)
                          GestureDetector(
                            onTap: () => setState(() => _subjectId = subject.id),
                            child: _SubjectChip(
                              label: subject.name,
                              color: subject.color,
                              selected: _subjectId == subject.id,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.existing == null ? 'Ajouter' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.color,
    required this.selected,
  });

  final String label;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: .16)
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: selected ? color : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? color : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
