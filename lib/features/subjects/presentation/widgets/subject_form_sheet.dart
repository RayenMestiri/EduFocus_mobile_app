import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/subjects_repository.dart';
import '../../domain/subject.dart';

/// Full professional colour palette — 30 hues spanning the spectrum, tuned to
/// stay readable on both the porcelain (light) and deep-space (dark) canvas.
const _colorChoices = [
  '#8b5cf6', '#7c3aed', '#6366f1', '#4f46e5', '#3b82f6', '#2563eb',
  '#0ea5e9', '#06b6d4', '#22d3ee', '#14b8a6', '#10b981', '#22c55e',
  '#34d399', '#84cc16', '#eab308', '#fbbf24', '#f59e0b', '#f97316',
  '#ef4444', '#f87171', '#ec4899', '#f472b6', '#d946ef', '#a855f7',
  '#0891b2', '#0f766e', '#be123c', '#9333ea', '#64748b', '#475569',
];

/// First N shown before the picker offers to expand.
const _iconPreviewCount = 21;
const _colorPreviewCount = 14;

Color _hexColor(String hex) =>
    Color(0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16));

/// Bottom sheet to create or edit a subject. Returns true when saved.
Future<bool?> showSubjectFormSheet(BuildContext context, {Subject? existing}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
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

  // Icons are stored as Material icon *names* (vector, no emoji-font flicker).
  // A legacy emoji subject being edited is upgraded to a sensible default.
  late String _icon = _resolveInitialIcon(widget.existing?.icon);
  late String _color = widget.existing?.colorHex ?? '#8b5cf6';

  bool _saving = false;
  bool _showAllIcons = false;
  bool _showAllColors = false;
  String? _error;

  static String _resolveInitialIcon(String? stored) {
    if (stored != null && kSubjectMaterialIcons.containsKey(stored)) {
      return stored;
    }
    return 'menu_book';
  }

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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = keyboardHeight > 0
        ? 24.0
        : (28.0 + MediaQuery.of(context).padding.bottom);
    final accent = _hexColor(_color);

    final iconKeys = kSubjectMaterialIcons.keys.toList();
    final visibleIcons = _showAllIcons
        ? iconKeys
        : iconKeys.take(_iconPreviewCount).toList();
    final visibleColors = _showAllColors
        ? _colorChoices
        : _colorChoices.take(_colorPreviewCount).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: screenHeight * 0.88 - keyboardHeight,
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
            // ── Grabber ──
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

            // ── Live preview: the chosen icon + colour together ──
            Row(
              children: [
                _LivePreview(color: accent, iconName: _icon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existing == null
                            ? 'Nouvelle matière'
                            : 'Modifier la matière',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choisissez une icône et une couleur',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

                    // ── Name ──
                    TextField(
                      controller: _name,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la matière',
                        hintText: 'Ex : Mathématiques',
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Icons ──
                    _SectionHeader(
                      label: 'ICÔNE',
                      trailing: iconKeys.length > _iconPreviewCount
                          ? _MoreButton(
                              expanded: _showAllIcons,
                              extra: iconKeys.length - _iconPreviewCount,
                              onTap: () => setState(
                                () => _showAllIcons = !_showAllIcons,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (final key in visibleIcons)
                          _IconTile(
                            iconName: key,
                            selected: _icon == key,
                            accent: accent,
                            onTap: () => setState(() => _icon = key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // ── Colours ──
                    _SectionHeader(
                      label: 'COULEUR',
                      trailing: _colorChoices.length > _colorPreviewCount
                          ? _MoreButton(
                              expanded: _showAllColors,
                              extra:
                                  _colorChoices.length - _colorPreviewCount,
                              onTap: () => setState(
                                () => _showAllColors = !_showAllColors,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final hex in visibleColors)
                          _ColorDot(
                            hex: hex,
                            selected: _color == hex,
                            onTap: () => setState(() => _color = hex),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: accent),
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

// ═══════════════════════════════════════════════════════════════
// LIVE PREVIEW
// ═══════════════════════════════════════════════════════════════

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.color, required this.iconName});

  final Color color;
  final String iconName;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .28), color.withValues(alpha: .14)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .4)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        kSubjectMaterialIcons[iconName] ?? Icons.menu_book_rounded,
        color: color,
        size: 27,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION HEADER + MORE BUTTON
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 10,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.expanded,
    required this.extra,
    required this.onTap,
  });

  final bool expanded;
  final int extra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.accent.withValues(alpha: .25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              expanded ? 'Voir moins' : 'Voir plus',
              style: TextStyle(
                color: AppColors.accentText,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 3),
            if (!expanded)
              Text(
                '+$extra',
                style: TextStyle(
                  color: AppColors.accentText.withValues(alpha: .7),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            AnimatedRotation(
              turns: expanded ? .5 : 0,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ICON TILE
// ═══════════════════════════════════════════════════════════════

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.iconName,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String iconName;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: .18)
              : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: .3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(
          kSubjectMaterialIcons[iconName] ?? Icons.menu_book_rounded,
          size: 22,
          color: selected ? accent : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COLOR DOT
// ═══════════════════════════════════════════════════════════════

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(hex);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? .55 : .3),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
