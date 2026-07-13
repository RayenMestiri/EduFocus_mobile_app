import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/subjects_repository.dart';
import '../../domain/subject.dart';

const _emojiChoices = [
  '📚',
  '📐',
  '🧪',
  '💻',
  '🌍',
  '🎨',
  '🎵',
  '⚽',
  '🧠',
  '✍️',
  '🔬',
  '📖',
  '🗣️',
  '💡',
  '🏛️',
  '🧮',
];

const _colorChoices = [
  '#8b5cf6',
  '#6366f1',
  '#3b82f6',
  '#22d3ee',
  '#34d399',
  '#fbbf24',
  '#f97316',
  '#f87171',
  '#ec4899',
  '#a78bfa',
  '#10b981',
  '#eab308',
];

/// Bottom sheet to create or edit a subject. Returns true when saved.
Future<bool?> showSubjectFormSheet(BuildContext context, {Subject? existing}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SubjectFormSheet(existing: existing),
  );
}

class _SubjectFormSheet extends ConsumerStatefulWidget {
  const _SubjectFormSheet({this.existing});

  final Subject? existing;

  @override
  ConsumerState<_SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends ConsumerState<_SubjectFormSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late String _icon = widget.existing?.icon ?? '📚';
  late String _color = widget.existing?.colorHex ?? '#8b5cf6';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom de la matière est requis');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final controller = ref.read(subjectsControllerProvider.notifier);
    final error = widget.existing == null
        ? await controller.create(name: name, colorHex: _color, icon: _icon)
        : await controller.updateSubject(
            widget.existing!.id,
            name: name,
            colorHex: _color,
            icon: _icon,
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.borderBright)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: SingleChildScrollView(
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
                    ? 'Nouvelle matière'
                    : 'Modifier la matière',
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                  ),
                ),
              TextField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Nom de la matière',
                  hintText: 'Ex : Mathématiques',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ICÔNE',
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
                  for (final emoji in _emojiChoices)
                    GestureDetector(
                      onTap: () => setState(() => _icon = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _icon == emoji
                              ? AppColors.accent.withValues(alpha: .18)
                              : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _icon == emoji
                                ? AppColors.accent
                                : AppColors.border,
                            width: _icon == emoji ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'COULEUR',
                style: text.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final hex in _colorChoices)
                    GestureDetector(
                      onTap: () => setState(() => _color = hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color(
                            0xFF000000 | int.parse(hex.substring(1), radix: 16),
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == hex
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: _color == hex
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                ],
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
      ),
    );
  }
}
