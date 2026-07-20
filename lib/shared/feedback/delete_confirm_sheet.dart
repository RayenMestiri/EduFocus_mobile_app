import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Content categories a study pack can hold — drives the icon and label used
/// in [showDeleteConfirmSheet]'s contextual warning.
enum StudyItemType { flashcards, notes, qcms, cheatsheets, exercises, mixed }

extension StudyItemTypeMeta on StudyItemType {
  String label(int count) => switch (this) {
    StudyItemType.flashcards => count > 1 ? 'flashcards' : 'flashcard',
    StudyItemType.notes => count > 1 ? 'notes' : 'note',
    StudyItemType.qcms => count > 1 ? 'questions QCM' : 'question QCM',
    StudyItemType.cheatsheets => count > 1 ? 'fiches' : 'fiche',
    StudyItemType.exercises => count > 1 ? 'exercices' : 'exercice',
    StudyItemType.mixed => count > 1 ? 'éléments' : 'élément',
  };

  IconData get icon => switch (this) {
    StudyItemType.flashcards => Icons.style_rounded,
    StudyItemType.notes => Icons.description_rounded,
    StudyItemType.qcms => Icons.quiz_rounded,
    StudyItemType.cheatsheets => Icons.fact_check_rounded,
    StudyItemType.exercises => Icons.assignment_rounded,
    StudyItemType.mixed => Icons.layers_rounded,
  };
}

/// Floating bottom sheet confirming a deletion inside the Study Hub (a
/// flashcard deck, note set, QCM batch, or a whole pack). Resolves `true`
/// only if the destructive button was tapped.
Future<bool?> showDeleteConfirmSheet(
  BuildContext context, {
  required StudyItemType type,
  required String title,
  required int count,
  String? detail,
  String confirmLabel = 'Supprimer définitivement',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DeleteSheet(
      type: type,
      title: title,
      count: count,
      detail: detail,
      confirmLabel: confirmLabel,
    ),
  );
}

class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({
    required this.type,
    required this.title,
    required this.count,
    required this.confirmLabel,
    this.detail,
  });

  final StudyItemType type;
  final String title;
  final int count;
  final String? detail;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: AppColors.red.withValues(alpha: .25)),
                ),
              ),
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
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(type.icon, color: AppColors.red, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            letterSpacing: -.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.red.withValues(alpha: .2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$count ${type.label(count)} seront supprimé${count > 1 ? 's' : ''} définitivement.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        if (detail != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            detail!,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
