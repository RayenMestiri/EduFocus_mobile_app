import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/env.dart';
import '../../../../shared/feedback/delete_confirm_sheet.dart';
import '../../../../shared/feedback/import_overlay.dart';
import '../../../../shared/feedback/overlay_toast.dart';
import '../../../../shared/feedback/publish_success_modal.dart';
import '../../data/study_packs_repository.dart';
import '../../domain/study_pack.dart';

class StudyPackDetailScreen extends ConsumerStatefulWidget {
  const StudyPackDetailScreen({super.key, required this.packId});

  final String packId;

  @override
  ConsumerState<StudyPackDetailScreen> createState() =>
      _StudyPackDetailScreenState();
}

class _StudyPackDetailScreenState extends ConsumerState<StudyPackDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      // Clear selection mode when switching tabs
      if (_selectMode) {
        setState(() {
          _selectMode = false;
          _selectedIds.clear();
        });
      } else {
        setState(() {}); // Synchronize bottom navigation active tab on swipe
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _generateUuid() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Reveals an already-known import result a few items at a time instead
  /// of flashing the final count instantly — the shimmer skeleton in
  /// [showImportProgressOverlay] fills in as each tick arrives.
  Stream<ImportProgressEvent> _staggeredImportProgress(
    ImportCategory category,
    int total,
  ) async* {
    if (total == 0) {
      yield ImportProgressEvent(category: category, done: 0, total: 0);
      return;
    }
    final stepDelay = total <= 10
        ? const Duration(milliseconds: 90)
        : total <= 30
        ? const Duration(milliseconds: 40)
        : const Duration(milliseconds: 15);
    for (var i = 1; i <= total; i++) {
      await Future.delayed(stepDelay);
      yield ImportProgressEvent(category: category, done: i, total: total);
    }
  }

  Future<void> _togglePublic(StudyPack pack) async {
    if (pack.isPublic) {
      if (!mounted) return;
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.borderBright)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Options de partage',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.share_rounded, color: AppColors.accentText),
                title: const Text('Voir le lien et le code de partage'),
                onTap: () => Navigator.of(sheetContext).pop('share'),
              ),
              ListTile(
                leading: Icon(Icons.lock_rounded, color: AppColors.red),
                title: const Text('Rendre le pack privé'),
                onTap: () => Navigator.of(sheetContext).pop('private'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (action == 'share') {
        if (!mounted) return;
        showPublishSuccessModal(
          context,
          itemTitle: pack.title,
          shareLink: '${Env.frontendUrl}/study-hub/shared/${pack.id}',
          shareCode: 'EDU-${pack.id.toUpperCase()}',
        );
      } else if (action == 'private') {
        setState(() => _isSaving = true);
        try {
          await ref.read(studyPacksRepositoryProvider).update(pack.id, {
            'isPublic': false,
          });
          ref.invalidate(studyPackProvider(pack.id));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('🔒 Pack d\'étude rendu privé.'),
                backgroundColor: AppColors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur : $e'),
                backgroundColor: AppColors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
      }
    } else {
      setState(() => _isSaving = true);
      try {
        await ref.read(studyPacksRepositoryProvider).update(pack.id, {
          'isPublic': true,
        });
        ref.invalidate(studyPackProvider(pack.id));
        if (mounted) {
          showPublishSuccessModal(
            context,
            itemTitle: pack.title,
            shareLink: '${Env.frontendUrl}/study-hub/shared/${pack.id}',
            shareCode: 'EDU-${pack.id.toUpperCase()}',
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de publication : $e'),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  StudyItemType _itemTypeForTab(int tab) => switch (tab) {
    0 => StudyItemType.notes,
    1 => StudyItemType.flashcards,
    2 => StudyItemType.qcms,
    3 => StudyItemType.cheatsheets,
    _ => StudyItemType.exercises,
  };

  /// Confirms via a bottom sheet, then exits select mode immediately but
  /// defers the actual mutation: the items stay untouched until the undo
  /// toast's countdown expires, so "Annuler" costs nothing but a tap.
  Future<void> _deleteSelectedItems(StudyPack pack) async {
    final activeTab = _tabController.index;
    final ids = Set<String>.from(_selectedIds);
    final count = ids.length;

    final confirmed = await showDeleteConfirmSheet(
      context,
      type: _itemTypeForTab(activeTab),
      title: 'Supprimer la sélection ?',
      count: count,
      detail: 'Pack concerné : « ${pack.title} ».',
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });

    final type = _itemTypeForTab(activeTab);
    showUndoToast(
      context,
      message: '$count ${type.label(count)} supprimé${count > 1 ? 's' : ''}',
      subtitle: 'Vous pouvez annuler pendant quelques secondes.',
      icon: Icons.delete_outline_rounded,
      accentColor: AppColors.red,
      onExpire: () => _commitDelete(pack, activeTab, ids),
    );
  }

  Future<void> _commitDelete(
    StudyPack pack,
    int activeTab,
    Set<String> ids,
  ) async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      final updatedPayload = <String, dynamic>{};

      if (activeTab == 0) {
        updatedPayload['notes'] = pack.notes
            .where((n) => !ids.contains(n.id))
            .map((n) => n.toJson())
            .toList();
      } else if (activeTab == 1) {
        updatedPayload['flashcards'] = pack.flashcards
            .where((f) => !ids.contains(f.id))
            .map((f) => f.toJson())
            .toList();
      } else if (activeTab == 2) {
        updatedPayload['qcm'] = pack.qcm
            .where((q) => !ids.contains(q.id))
            .map((q) => q.toJson())
            .toList();
      } else if (activeTab == 3) {
        updatedPayload['cheatsheets'] = pack.cheatsheets
            .where((c) => !ids.contains(c.id))
            .map((c) => c.toJson())
            .toList();
      } else if (activeTab == 4) {
        updatedPayload['exercises'] = pack.exercises
            .where((e) => !ids.contains(e.id))
            .map((e) => e.toJson())
            .toList();
      }

      await ref
          .read(studyPacksRepositoryProvider)
          .update(pack.id, updatedPayload);
      ref.invalidate(studyPackProvider(pack.id));
      ref.invalidate(studyPacksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de supprimer les éléments : $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showImportBottomSheet(StudyPack pack) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ImportBottomSheet(
          onImport: (type, jsonString) async {
            try {
              final parsed = jsonDecode(jsonString);
              if (parsed is! List) {
                throw const FormatException('Le JSON doit être un tableau.');
              }

              final updatedPayload = <String, dynamic>{};
              if (type == 'notes') {
                final newNotes = parsed.map((item) {
                  return Note(
                    id: _generateUuid(),
                    title: item['title'] as String? ?? 'Note Importée',
                    content: item['content'] as String? ?? '',
                    tags: List<String>.from(item['tags'] ?? []),
                  );
                }).toList();
                final combined = [
                  ...pack.notes,
                  ...newNotes,
                ].map((n) => n.toJson()).toList();
                updatedPayload['notes'] = combined;
              } else if (type == 'flashcards') {
                final newCards = parsed.map((item) {
                  return Flashcard(
                    id: _generateUuid(),
                    front: item['front'] as String? ?? '',
                    back: item['back'] as String? ?? '',
                    code: item['code'] as String?,
                  );
                }).toList();
                final combined = [
                  ...pack.flashcards,
                  ...newCards,
                ].map((f) => f.toJson()).toList();
                updatedPayload['flashcards'] = combined;
              } else if (type == 'qcm') {
                final newQcms = parsed.map((item) {
                  return QCM(
                    id: _generateUuid(),
                    question: item['question'] as String? ?? '',
                    type: item['type'] as String? ?? 'multiple-choice',
                    options: List<String>.from(item['options'] ?? []),
                    correctAnswer: item['correctAnswer'],
                    explanation: item['explanation'] as String?,
                    topic: item['topic'] as String? ?? 'Importé',
                  );
                }).toList();
                final combined = [
                  ...pack.qcm,
                  ...newQcms,
                ].map((q) => q.toJson()).toList();
                updatedPayload['qcm'] = combined;
              }

              setState(() => _isSaving = true);
              await ref
                  .read(studyPacksRepositoryProvider)
                  .update(pack.id, updatedPayload);
              ref.invalidate(studyPackProvider(pack.id));
              ref.invalidate(studyPacksProvider);

              if (mounted) {
                final category = switch (type) {
                  'flashcards' => ImportCategory.flashcards,
                  'qcm' => ImportCategory.qcms,
                  _ => ImportCategory.notes,
                };
                showImportProgressOverlay(
                  context,
                  events: _staggeredImportProgress(category, parsed.length),
                  onOpenHub: () => context.go('/study-hub'),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Format de fichier invalide : $e'),
                    backgroundColor: AppColors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => _isSaving = false);
            }
          },
        );
      },
    );
  }

  void _showAddItemSheet(StudyPack pack) {
    final activeTab = _tabController.index;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        if (activeTab == 0) {
          return _NoteFormSheet(
            onSave: (title, content, tags, color) => _saveItem(pack, 'notes', {
              'id': _generateUuid(),
              'title': title,
              'content': content,
              'tags': tags,
              'isPinned': false,
              'color': color,
            }),
          );
        } else if (activeTab == 1) {
          return _FlashcardFormSheet(
            onSave: (front, back, code) => _saveItem(pack, 'flashcards', {
              'id': _generateUuid(),
              'front': front,
              'back': back,
              'code': code,
              'state': 'new',
            }),
          );
        } else if (activeTab == 2) {
          return _QcmFormSheet(
            onSave:
                (question, type, options, correctAnswer, explanation, topic) =>
                    _saveItem(pack, 'qcm', {
                      'id': _generateUuid(),
                      'question': question,
                      'type': type,
                      'options': options,
                      'correctAnswer': correctAnswer,
                      'explanation': explanation,
                      'topic': topic,
                    }),
          );
        } else if (activeTab == 3) {
          return _CheatsheetFormSheet(
            onSave: (title, category, items, codeSample) =>
                _saveItem(pack, 'cheatsheets', {
                  'id': _generateUuid(),
                  'title': title,
                  'category': category,
                  'items': items,
                  'codeSample': codeSample,
                }),
          );
        } else {
          return _ExerciseFormSheet(
            onSave: (title, description, task, correctSolution, solutionNote) =>
                _saveItem(pack, 'exercises', {
                  'id': _generateUuid(),
                  'title': title,
                  'description': description,
                  'task': task,
                  'correctSolution': correctSolution,
                  'solutionNote': solutionNote,
                }),
          );
        }
      },
    );
  }

  Future<void> _saveItem(
    StudyPack pack,
    String arrayKey,
    Map<String, dynamic> itemJson, {
    String? editId,
  }) async {
    setState(() => _isSaving = true);
    try {
      final updatedPayload = <String, dynamic>{};

      if (arrayKey == 'notes') {
        final current = pack.notes.map((n) => n.toJson()).toList();
        if (editId != null) {
          final idx = current.indexWhere((n) => n['id'] == editId);
          if (idx != -1) current[idx] = itemJson;
        } else {
          current.add(itemJson);
        }
        updatedPayload['notes'] = current;
      } else if (arrayKey == 'flashcards') {
        final current = pack.flashcards.map((f) => f.toJson()).toList();
        if (editId != null) {
          final idx = current.indexWhere((f) => f['id'] == editId);
          if (idx != -1) current[idx] = itemJson;
        } else {
          current.add(itemJson);
        }
        updatedPayload['flashcards'] = current;
      } else if (arrayKey == 'qcm') {
        final current = pack.qcm.map((q) => q.toJson()).toList();
        if (editId != null) {
          final idx = current.indexWhere((q) => q['id'] == editId);
          if (idx != -1) current[idx] = itemJson;
        } else {
          current.add(itemJson);
        }
        updatedPayload['qcm'] = current;
      } else if (arrayKey == 'cheatsheets') {
        final current = pack.cheatsheets.map((c) => c.toJson()).toList();
        if (editId != null) {
          final idx = current.indexWhere((c) => c['id'] == editId);
          if (idx != -1) current[idx] = itemJson;
        } else {
          current.add(itemJson);
        }
        updatedPayload['cheatsheets'] = current;
      } else if (arrayKey == 'exercises') {
        final current = pack.exercises.map((e) => e.toJson()).toList();
        if (editId != null) {
          final idx = current.indexWhere((e) => e['id'] == editId);
          if (idx != -1) current[idx] = itemJson;
        } else {
          current.add(itemJson);
        }
        updatedPayload['exercises'] = current;
      }

      await ref
          .read(studyPacksRepositoryProvider)
          .update(pack.id, updatedPayload);
      ref.invalidate(studyPackProvider(pack.id));
      ref.invalidate(studyPacksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💾 Modifications enregistrées avec succès !'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'enregistrer : $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showEditItemSheet(StudyPack pack, dynamic item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        if (item is Note) {
          return _NoteFormSheet(
            note: item,
            onSave: (title, content, tags, color) => _saveItem(pack, 'notes', {
              'id': item.id,
              'title': title,
              'content': content,
              'tags': tags,
              'isPinned': item.isPinned,
              'color': color,
            }, editId: item.id),
          );
        } else if (item is Flashcard) {
          return _FlashcardFormSheet(
            card: item,
            onSave: (front, back, code) => _saveItem(pack, 'flashcards', {
              'id': item.id,
              'front': front,
              'back': back,
              'code': code,
              'state': item.state,
              'repetitions': item.repetitions,
              'interval': item.interval,
              'easeFactor': item.easeFactor,
              'dueDate': item.dueDate?.toIso8601String(),
              'lastReviewed': item.lastReviewed?.toIso8601String(),
              'lapses': item.lapses,
            }, editId: item.id),
          );
        } else if (item is QCM) {
          return _QcmFormSheet(
            qcm: item,
            onSave:
                (question, type, options, correctAnswer, explanation, topic) =>
                    _saveItem(pack, 'qcm', {
                      'id': item.id,
                      'question': question,
                      'type': type,
                      'options': options,
                      'correctAnswer': correctAnswer,
                      'explanation': explanation,
                      'topic': topic,
                    }, editId: item.id),
          );
        } else if (item is Cheatsheet) {
          return _CheatsheetFormSheet(
            sheet: item,
            onSave: (title, category, items, codeSample) =>
                _saveItem(pack, 'cheatsheets', {
                  'id': item.id,
                  'title': title,
                  'category': category,
                  'items': items,
                  'codeSample': codeSample,
                }, editId: item.id),
          );
        } else if (item is Exercise) {
          return _ExerciseFormSheet(
            exercise: item,
            onSave: (title, description, task, correctSolution, solutionNote) =>
                _saveItem(pack, 'exercises', {
                  'id': item.id,
                  'title': title,
                  'description': description,
                  'task': task,
                  'correctSolution': correctSolution,
                  'solutionNote': solutionNote,
                }, editId: item.id),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Color _getActiveTabColor(int index) {
    switch (index) {
      case 0:
        return AppColors.accentBright; // Violet
      case 1:
        return AppColors.blue; // Blue
      case 2:
        return AppColors.cyan; // Cyan
      case 3:
        return AppColors.yellow; // Amber
      case 4:
        return AppColors.green; // Green
      default:
        return AppColors.accentBright;
    }
  }

  Color _getSecondaryTabColor(int index) {
    switch (index) {
      case 0:
        return AppColors.indigo; // Violet / Indigo
      case 1:
        return AppColors.accentBright; // Blue / Violet
      case 2:
        return AppColors.blue; // Cyan / Blue
      case 3:
        return AppColors.cyan; // Amber / Cyan
      case 4:
        return AppColors.cyan; // Green / Cyan
      default:
        return AppColors.indigo;
    }
  }

  Widget _buildBottomNavBar(StudyPack pack) {
    final activeColor = _getActiveTabColor(_tabController.index);
    final tabs = [
      (Icons.description_rounded, 'Notes', pack.noteCount),
      (Icons.style_rounded, 'Cards', pack.cardCount),
      (Icons.quiz_rounded, 'QCM', pack.qcmCount),
      (Icons.article_rounded, 'Cheat', pack.cheatsheetCount),
      (Icons.code_rounded, 'Exos', pack.exerciseCount),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(
              alpha: AppColors.isLight ? 0.08 : 0.4,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppColors.isLight
                    ? AppColors.border.withValues(alpha: 0.8)
                    : AppColors.borderBright,
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _BottomNavItem(
                      icon: tabs[i].$1,
                      label: tabs[i].$2,
                      count: tabs[i].$3,
                      selected: _tabController.index == i,
                      activeColor: activeColor,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _tabController.animateTo(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packAsync = ref.watch(studyPackProvider(widget.packId));

    return packAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('…')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(
          child: Text(e.toString(), style: TextStyle(color: AppColors.red)),
        ),
      ),
      data: (pack) {
        final activeColor = _getActiveTabColor(_tabController.index);

        return Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: AppColors.isLight
                  ? Brightness.dark
                  : Brightness.light,
            ),
            leading: IconButton(
              onPressed: () {
                if (_selectMode) {
                  setState(() {
                    _selectMode = false;
                    _selectedIds.clear();
                  });
                } else {
                  context.pop();
                }
              },
              icon: Icon(
                _selectMode
                    ? Icons.close_rounded
                    : Icons.arrow_back_ios_new_rounded,
                size: 18,
              ),
            ),
            title: Text(
              _selectMode ? '${_selectedIds.length} sélectionnés' : pack.title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (!_selectMode) ...[
                // Publish status toggle
                IconButton(
                  onPressed: () => _togglePublic(pack),
                  icon: Icon(
                    pack.isPublic
                        ? Icons.public_rounded
                        : Icons.public_off_rounded,
                    color: pack.isPublic
                        ? AppColors.green
                        : AppColors.textMuted,
                  ),
                  tooltip: pack.isPublic ? 'Rendre privé' : 'Publier le pack',
                ),
                // Import bottom sheet trigger
                IconButton(
                  onPressed: () => _showImportBottomSheet(pack),
                  icon: const Icon(Icons.file_upload_rounded),
                  tooltip: 'Importer du contenu',
                ),
                // Select to delete mode toggle
                IconButton(
                  onPressed: () => setState(() => _selectMode = true),
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Sélectionner des éléments',
                ),
              ] else ...[
                IconButton(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => _deleteSelectedItems(pack),
                  icon: Icon(Icons.delete_rounded, color: AppColors.red),
                  tooltip: 'Supprimer la sélection',
                ),
              ],
            ],
          ),
          body: Stack(
            children: [
              // Ambient light field — the canvas never feels flat/dead
              Positioned(
                top: -110,
                right: -90,
                child: TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 350),
                  tween: ColorTween(end: activeColor),
                  builder: (context, color, child) {
                    return _GlowOrb(
                      size: 300,
                      color: color ?? AppColors.accentBright,
                      alpha: .12,
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 80,
                left: -130,
                child: TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 350),
                  tween: ColorTween(
                    end: _getSecondaryTabColor(_tabController.index),
                  ),
                  builder: (context, color, child) {
                    return _GlowOrb(
                      size: 340,
                      color: color ?? AppColors.indigo,
                      alpha: .08,
                    );
                  },
                ),
              ),
              Positioned(
                top: 240,
                left: -60,
                child: TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 350),
                  tween: ColorTween(end: activeColor),
                  builder: (context, color, child) {
                    return _GlowOrb(
                      size: 200,
                      color: color ?? AppColors.cyan,
                      alpha: .05,
                    );
                  },
                ),
              ),

              SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(studyPackProvider(widget.packId).future),
                  edgeOffset: 10,
                  backgroundColor: AppColors.surfaceSecondary,
                  color: AppColors.accentBright,
                  child: Column(
                    children: [
                      if (_isSaving)
                        LinearProgressIndicator(
                          minHeight: 2,
                          color: AppColors.accent,
                        ),
                      // ── Sleek Compact Header Card ──
                      _CompactHeroCard(pack: pack, activeColor: activeColor),

                      // Tab Content Area
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _NotesTab(
                              pack: pack,
                              selectMode: _selectMode,
                              selectedIds: _selectedIds,
                              onToggleSelect: (id) => setState(() {
                                if (_selectedIds.contains(id)) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              }),
                              onEdit: (note) => _showEditItemSheet(pack, note),
                            ),
                            _FlashcardsTab(
                              pack: pack,
                              activeColor: activeColor,
                              selectMode: _selectMode,
                              selectedIds: _selectedIds,
                              onToggleSelect: (id) => setState(() {
                                if (_selectedIds.contains(id)) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              }),
                              onEdit: (card) => _showEditItemSheet(pack, card),
                            ),
                            _QcmTab(
                              pack: pack,
                              selectMode: _selectMode,
                              selectedIds: _selectedIds,
                              onToggleSelect: (id) => setState(() {
                                if (_selectedIds.contains(id)) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              }),
                              onEdit: (qcm) => _showEditItemSheet(pack, qcm),
                            ),
                            _CheatsheetsTab(
                              pack: pack,
                              activeColor: activeColor,
                              selectMode: _selectMode,
                              selectedIds: _selectedIds,
                              onToggleSelect: (id) => setState(() {
                                if (_selectedIds.contains(id)) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              }),
                              onEdit: (sheet) =>
                                  _showEditItemSheet(pack, sheet),
                            ),
                            _ExercisesTab(
                              pack: pack,
                              selectMode: _selectMode,
                              selectedIds: _selectedIds,
                              onToggleSelect: (id) => setState(() {
                                if (_selectedIds.contains(id)) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              }),
                              onEdit: (ex) => _showEditItemSheet(pack, ex),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _selectMode || _isSaving
              ? null
              : SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _buildBottomNavBar(pack),
                  ),
                ),
          floatingActionButton: _selectMode || _isSaving
              ? null
              : Padding(
                  padding: EdgeInsets.only(
                    bottom: 20 + MediaQuery.of(context).padding.bottom,
                  ), // Shift up to avoid overlap with floating bottom nav
                  child: TweenAnimationBuilder<Color?>(
                    duration: const Duration(milliseconds: 350),
                    tween: ColorTween(end: activeColor),
                    builder: (context, color, child) {
                      return FloatingActionButton(
                        onPressed: () => _showAddItemSheet(pack),
                        backgroundColor: color ?? AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
//  COMPACT SLEEK HERO HEADER CARD
// ══════════════════════════════════════════════════════════

class _CompactHeroCard extends StatelessWidget {
  const _CompactHeroCard({required this.pack, required this.activeColor});

  final StudyPack pack;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final mastered = pack.countByState('mastered');
    final progress = pack.cardCount > 0
        ? (mastered / pack.cardCount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: .22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side: Title, subject, description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pack.subject.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (pack.isPublic) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🌍 ', style: TextStyle(fontSize: 8)),
                            Text(
                              'PUBLIC',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  pack.title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (pack.description != null &&
                    pack.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    pack.description!,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.description_rounded,
                      value: '${pack.noteCount}',
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.style_rounded,
                      value: '${pack.cardCount}',
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.quiz_rounded,
                      value: '${pack.qcmCount}',
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.article_rounded,
                      value: '${pack.cheatsheetCount}',
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.code_rounded,
                      value: '${pack.exerciseCount}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Right side: Mastery progress circular indicator
          if (pack.cardCount > 0)
            Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4.5,
                      backgroundColor: Colors.white.withValues(alpha: .1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 10),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  REUSABLE EMPTY STATE
// ══════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: .15),
                ),
              ),
              child: Icon(icon, color: AppColors.textMuted, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NOTES TAB WITH ACTIONS
// ══════════════════════════════════════════════════════════

Color _parseHexColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

class _NotesTab extends StatefulWidget {
  const _NotesTab({
    required this.pack,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onEdit,
  });

  final StudyPack pack;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<Note> onEdit;

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    if (widget.pack.notes.isEmpty) {
      return const _EmptyState(
        icon: Icons.description_rounded,
        title: 'Aucune note',
        subtitle: 'Ajoutez une note en cliquant sur le bouton +',
      );
    }

    // Extract unique tags for filtering
    final allTags = widget.pack.notes.expand((n) => n.tags).toSet().toList();
    final filters = ['all', 'Important', ...allTags];

    // Filter and sort notes
    var filteredNotes = widget.pack.notes;
    if (_selectedFilter == 'Important') {
      filteredNotes = filteredNotes.where((n) => n.isPinned).toList();
    } else if (_selectedFilter != 'all') {
      filteredNotes = filteredNotes
          .where((n) => n.tags.contains(_selectedFilter))
          .toList();
    }

    final sorted = [...filteredNotes]
      ..sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return 0;
      });

    return Column(
      children: [
        // Outlined ChoiceChips Filter Row
        if (!widget.selectMode)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final active = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      filter == 'all'
                          ? 'Toutes'
                          : (filter == 'Important'
                                ? '📌 Important'
                                : '#$filter'),
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    selected: active,
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.surfaceGlass,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: active ? AppColors.accent : AppColors.border,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = filter);
                      }
                    },
                  ),
                );
              },
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final note = sorted[index];
              final isSelected = widget.selectedIds.contains(note.id);

              return Row(
                children: [
                  if (widget.selectMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => widget.onToggleSelect(note.id),
                    ),
                  Expanded(
                    child: _NoteCard(
                      note: note,
                      selectMode: widget.selectMode,
                      onEdit: () => widget.onEdit(note),
                      onTap: () => context.push(
                        '/study-hub/${widget.pack.id}/notes/${note.id}',
                        extra: note,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.selectMode,
    required this.onEdit,
  });

  final Note note;
  final VoidCallback onTap;
  final bool selectMode;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final preview = note.content.length > 100
        ? '${note.content.substring(0, 100)}…'
        : note.content;
    final accentColor = _parseHexColor(note.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(
              alpha: AppColors.isLight ? 0.05 : 0.15,
            ),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selectMode ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular Doc Icon (accent-colored circular background)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_document,
                    size: 16,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 14),

                // Note Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview.isEmpty ? 'Aucun contenu rédigé' : preview,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Edit Button or Pinned status badge
                if (!selectMode)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: onEdit,
                        icon: Icon(
                          Icons.mode_edit_outline_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (note.isPinned) ...[
                        const SizedBox(height: 8),
                        Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: AppColors.yellow,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FLASHCARDS TAB WITH ACTIONS
// ══════════════════════════════════════════════════════════

class _FlashcardsTab extends StatelessWidget {
  const _FlashcardsTab({
    required this.pack,
    required this.activeColor,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onEdit,
  });

  final StudyPack pack;
  final Color activeColor;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<Flashcard> onEdit;

  @override
  Widget build(BuildContext context) {
    final due = pack.dueCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        // SRS Summary & Study Button
        if (pack.flashcards.isNotEmpty && !selectMode) ...[
          _FlashcardSummaryBlock(pack: pack),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/study-hub/${pack.id}/flashcards'),
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                due > 0
                    ? 'Réviser ($due cartes dues)'
                    : 'Réviser les flashcards',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Toutes les Flashcards',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (pack.flashcards.isEmpty)
          const _EmptyState(
            icon: Icons.style_rounded,
            title: 'Aucune flashcard',
            subtitle: 'Créez une flashcard en cliquant sur le bouton +',
          )
        else
          ...pack.flashcards.map((card) {
            final isSelected = selectedIds.contains(card.id);
            return Row(
              children: [
                if (selectMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelect(card.id),
                  ),
                Expanded(
                  child: _FlashcardTile(
                    card: card,
                    selectMode: selectMode,
                    onEdit: () => onEdit(card),
                  ),
                ),
              ],
            );
          }),
      ],
    );
  }
}

class _FlashcardSummaryBlock extends StatelessWidget {
  const _FlashcardSummaryBlock({required this.pack});
  final StudyPack pack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final newCount = pack.countByState('new');
    final learningCount = pack.countByState('learning');
    final reviewCount = pack.countByState('review');
    final masteredCount = pack.countByState('mastered');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribution SRS',
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 20,
              child: Row(
                children: [
                  if (newCount > 0)
                    Expanded(
                      flex: newCount,
                      child: Container(
                        color: AppColors.blue,
                        alignment: Alignment.center,
                        child: Text(
                          '$newCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (learningCount > 0)
                    Expanded(
                      flex: learningCount,
                      child: Container(
                        color: AppColors.yellow,
                        alignment: Alignment.center,
                        child: Text(
                          '$learningCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (reviewCount > 0)
                    Expanded(
                      flex: reviewCount,
                      child: Container(
                        color: AppColors.accent,
                        alignment: Alignment.center,
                        child: Text(
                          '$reviewCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (masteredCount > 0)
                    Expanded(
                      flex: masteredCount,
                      child: Container(
                        color: AppColors.green,
                        alignment: Alignment.center,
                        child: Text(
                          '$masteredCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashcardTile extends StatelessWidget {
  const _FlashcardTile({
    required this.card,
    required this.selectMode,
    required this.onEdit,
  });
  final Flashcard card;
  final bool selectMode;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    Color stateColor = AppColors.blue;
    if (card.state == 'mastered') stateColor = AppColors.green;
    if (card.state == 'review') stateColor = AppColors.accent;
    if (card.state == 'learning') stateColor = AppColors.yellow;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(
              color: stateColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.front,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  card.back,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!selectMode)
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.mode_edit_outline_rounded,
                size: 16,
                color: AppColors.accentText,
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  QCM TAB WITH ACTIONS
// ══════════════════════════════════════════════════════════

class _QcmTab extends StatelessWidget {
  const _QcmTab({
    required this.pack,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onEdit,
  });

  final StudyPack pack;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<QCM> onEdit;

  @override
  Widget build(BuildContext context) {
    if (pack.qcm.isEmpty) {
      return const _EmptyState(
        icon: Icons.quiz_rounded,
        title: 'Aucun QCM',
        subtitle: 'Ajoutez des QCM en cliquant sur le bouton +',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        if (!selectMode) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/study-hub/${pack.id}/qcm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                'Lancer le Quiz (${pack.qcm.length} questions)',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        ...pack.qcm.map((q) {
          final isSelected = selectedIds.contains(q.id);
          return Row(
            children: [
              if (selectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggleSelect(q.id),
                ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          q.topic ?? 'Général',
                          style: TextStyle(
                            color: AppColors.cyan,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          q.question,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!selectMode)
                        IconButton(
                          onPressed: () => onEdit(q),
                          icon: Icon(
                            Icons.mode_edit_outline_rounded,
                            size: 16,
                            color: AppColors.accentText,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CHEATSHEETS TAB WITH ACTIONS
// ══════════════════════════════════════════════════════════

class _CheatsheetsTab extends StatelessWidget {
  const _CheatsheetsTab({
    required this.pack,
    required this.activeColor,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onEdit,
  });

  final StudyPack pack;
  final Color activeColor;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<Cheatsheet> onEdit;

  @override
  Widget build(BuildContext context) {
    if (pack.cheatsheets.isEmpty) {
      return const _EmptyState(
        icon: Icons.view_list_rounded,
        title: 'Aucune fiche mémo',
        subtitle: 'Ajoutez une fiche en cliquant sur le bouton +',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: pack.cheatsheets.length,
      itemBuilder: (context, index) {
        final sheet = pack.cheatsheets[index];
        final isSelected = selectedIds.contains(sheet.id);

        return Row(
          children: [
            if (selectMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggleSelect(sheet.id),
              ),
            Expanded(
              child: _CheatsheetCard(
                sheet: sheet,
                activeColor: activeColor,
                selectMode: selectMode,
                onEdit: () => onEdit(sheet),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CheatsheetCard extends StatefulWidget {
  const _CheatsheetCard({
    required this.sheet,
    required this.activeColor,
    required this.selectMode,
    required this.onEdit,
  });

  final Cheatsheet sheet;
  final Color activeColor;
  final bool selectMode;
  final VoidCallback onEdit;

  @override
  State<_CheatsheetCard> createState() => _CheatsheetCardState();
}

class _CheatsheetCardState extends State<_CheatsheetCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final catColor = widget.activeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(
              alpha: AppColors.isLight ? 0.04 : 0.12,
            ),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Left side category accent pillar
                  Container(
                    width: 4,
                    height: 38,
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: catColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(1, 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info area
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sheet.title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Category Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: catColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            widget.sheet.category.toUpperCase(),
                            style: TextStyle(
                              color: catColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Action Buttons + Expand icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!widget.selectMode)
                        IconButton(
                          onPressed: widget.onEdit,
                          icon: Icon(
                            Icons.mode_edit_outline_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Detail Section showing concept entries in modern grid rows
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),

                  // Concept Key-Value List styled as glowing cards
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.sheet.items.length,
                    itemBuilder: (context, i) {
                      final item = widget.sheet.items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary.withValues(
                            alpha: .5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Key column with code style or bold styling
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.key,
                                style: TextStyle(
                                  color: catColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  fontFamily: 'JetBrains Mono',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Value column with nice readable font
                            Expanded(
                              flex: 7,
                              child: Text(
                                item.value,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EXERCISES TAB WITH ACTIONS
// ══════════════════════════════════════════════════════════

class _ExercisesTab extends StatelessWidget {
  const _ExercisesTab({
    required this.pack,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onEdit,
  });

  final StudyPack pack;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<Exercise> onEdit;

  @override
  Widget build(BuildContext context) {
    if (pack.exercises.isEmpty) {
      return const _EmptyState(
        icon: Icons.code_rounded,
        title: 'Aucun exercice',
        subtitle: 'Ajoutez un exercice en cliquant sur le bouton +',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        if (!selectMode) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/study-hub/${pack.id}/exercises'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                'Commencer les exercices (${pack.exercises.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        ...pack.exercises.map((ex) {
          final isSelected = selectedIds.contains(ex.id);
          return Row(
            children: [
              if (selectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggleSelect(ex.id),
                ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.code_rounded,
                          color: AppColors.green,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              ex.description,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!selectMode)
                        IconButton(
                          onPressed: () => onEdit(ex),
                          icon: Icon(
                            Icons.mode_edit_outline_rounded,
                            size: 16,
                            color: AppColors.accentText,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CREATION & EDIT SHEETS (FORMS)
// ══════════════════════════════════════════════════════════

class _NoteFormSheet extends StatefulWidget {
  const _NoteFormSheet({this.note, required this.onSave});
  final Note? note;
  final void Function(
    String title,
    String content,
    List<String> tags,
    String color,
  )
  onSave;

  @override
  State<_NoteFormSheet> createState() => _NoteFormSheetState();
}

class _NoteFormSheetState extends State<_NoteFormSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  final List<String> _colors = const [
    '#8B5CF6',
    '#6366F1',
    '#3B82F6',
    '#22D3EE',
    '#34D399',
    '#FBBF24',
    '#F97316',
    '#F87171',
  ];

  String _selectedColor = '#8B5CF6';

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _tagsController.text = widget.note!.tags.join(', ');
      _selectedColor = widget.note!.color;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          const Text(
            '📝 Éditer la Note',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titre de la Note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Contenu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags (séparés par des virgules)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          // Color Selector Strip (matches the bottom selector in the user's screenshot)
          Text(
            'Couleur d\'arrière-plan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _colors.length,
              itemBuilder: (context, index) {
                final hex = _colors[index];
                final color = _parseHexColor(hex);
                final active = _selectedColor == hex;

                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? Colors.black
                            : Colors.black.withValues(alpha: 0.08),
                        width: active ? 2.5 : 1,
                      ),
                      boxShadow: [
                        if (active)
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: active
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                            size: 16,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final tags = _tagsController.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  widget.onSave(
                    _titleController.text.trim(),
                    _contentController.text.trim(),
                    tags,
                    _selectedColor,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlashcardFormSheet extends StatefulWidget {
  const _FlashcardFormSheet({this.card, required this.onSave});
  final Flashcard? card;
  final void Function(String front, String back, String? code) onSave;

  @override
  State<_FlashcardFormSheet> createState() => _FlashcardFormSheetState();
}

class _FlashcardFormSheetState extends State<_FlashcardFormSheet> {
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.card != null) {
      _frontController.text = widget.card!.front;
      _backController.text = widget.card!.back;
      _codeController.text = widget.card!.code ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          const Text(
            '🎴 Éditer la Flashcard',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _frontController,
            decoration: const InputDecoration(
              labelText: 'Question (Recto)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _backController,
            decoration: const InputDecoration(
              labelText: 'Réponse (Verso)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Extrait de code (Optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  widget.onSave(
                    _frontController.text.trim(),
                    _backController.text.trim(),
                    _codeController.text.isEmpty
                        ? null
                        : _codeController.text.trim(),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QcmFormSheet extends StatefulWidget {
  const _QcmFormSheet({this.qcm, required this.onSave});
  final QCM? qcm;
  final void Function(
    String question,
    String type,
    List<String> options,
    dynamic correctAnswer,
    String? explanation,
    String? topic,
  )
  onSave;

  @override
  State<_QcmFormSheet> createState() => _QcmFormSheetState();
}

class _QcmFormSheetState extends State<_QcmFormSheet> {
  final _questionController = TextEditingController();
  final _optControllers = List.generate(4, (_) => TextEditingController());
  final _explanationController = TextEditingController();
  final _topicController = TextEditingController();
  String _type = 'multiple-choice';
  int _correctIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.qcm != null) {
      _questionController.text = widget.qcm!.question;
      _type = widget.qcm!.type;
      _explanationController.text = widget.qcm!.explanation ?? '';
      _topicController.text = widget.qcm!.topic ?? '';
      if (_type == 'multiple-choice') {
        for (var i = 0; i < widget.qcm!.options.length && i < 4; i++) {
          _optControllers[i].text = widget.qcm!.options[i];
        }
        _correctIndex = widget.qcm!.correctAnswer is int
            ? widget.qcm!.correctAnswer
            : 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '❓ Éditer le QCM',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: const [
                DropdownMenuItem(
                  value: 'multiple-choice',
                  child: Text('Choix multiple'),
                ),
                DropdownMenuItem(
                  value: 'true-false',
                  child: Text('Vrai / Faux'),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _type = val ?? 'multiple-choice'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            if (_type == 'multiple-choice') ...[
              for (var i = 0; i < 4; i++) ...[
                TextField(
                  controller: _optControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Option ${i + 1}',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              DropdownButtonFormField<int>(
                initialValue: _correctIndex,
                items: List.generate(
                  4,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text('Option correcte : ${index + 1}'),
                  ),
                ),
                onChanged: (val) => setState(() => _correctIndex = val ?? 0),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ] else ...[
              DropdownButtonFormField<int>(
                initialValue: _correctIndex,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Correct : VRAI')),
                  DropdownMenuItem(value: 1, child: Text('Correct : FAUX')),
                ],
                onChanged: (val) => setState(() => _correctIndex = val ?? 0),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _explanationController,
              decoration: const InputDecoration(
                labelText: 'Explication (Optionnelle)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Sujet / Chapitre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final options = _type == 'multiple-choice'
                        ? _optControllers.map((c) => c.text.trim()).toList()
                        : ['true', 'false'];
                    final dynamic ans = _type == 'multiple-choice'
                        ? _correctIndex
                        : (_correctIndex == 0 ? 'true' : 'false');
                    widget.onSave(
                      _questionController.text.trim(),
                      _type,
                      options,
                      ans,
                      _explanationController.text.trim(),
                      _topicController.text.trim(),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheatsheetFormSheet extends StatefulWidget {
  const _CheatsheetFormSheet({this.sheet, required this.onSave});
  final Cheatsheet? sheet;
  final void Function(
    String title,
    String category,
    List<Map<String, String>> items,
    String? codeSample,
  )
  onSave;

  @override
  State<_CheatsheetFormSheet> createState() => _CheatsheetFormSheetState();
}

class _CheatsheetFormSheetState extends State<_CheatsheetFormSheet> {
  final _titleController = TextEditingController();
  final _catController = TextEditingController();
  final _keyController = TextEditingController();
  final _valController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.sheet != null) {
      _titleController.text = widget.sheet!.title;
      _catController.text = widget.sheet!.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '📜 Ajouter un CheatSheet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _catController,
            decoration: const InputDecoration(
              labelText: 'Catégorie',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyController,
                  decoration: const InputDecoration(
                    labelText: 'Clé (Ex: SELECT)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _valController,
                  decoration: const InputDecoration(
                    labelText: 'Valeur (Ex: Lire)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final items = [
                    {
                      'key': _keyController.text.trim(),
                      'value': _valController.text.trim(),
                    },
                  ];
                  widget.onSave(
                    _titleController.text.trim(),
                    _catController.text.trim(),
                    items,
                    null,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseFormSheet extends StatefulWidget {
  const _ExerciseFormSheet({this.exercise, required this.onSave});
  final Exercise? exercise;
  final void Function(
    String title,
    String description,
    String task,
    String correctSolution,
    String? solutionNote,
  )
  onSave;

  @override
  State<_ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends State<_ExerciseFormSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _taskController = TextEditingController();
  final _solController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.exercise != null) {
      _titleController.text = widget.exercise!.title;
      _descController.text = widget.exercise!.description;
      _taskController.text = widget.exercise!.task;
      _solController.text = widget.exercise!.correctSolution;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '💻 Ajouter un Exercice',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre de l\'Exercice',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taskController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Consigne / Tâche',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _solController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Solution Attendue',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    widget.onSave(
                      _titleController.text.trim(),
                      _descController.text.trim(),
                      _taskController.text.trim(),
                      _solController.text.trim(),
                      null,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  IMPORT BOTTOM SHEET
// ══════════════════════════════════════════════════════════

class _ImportBottomSheet extends StatefulWidget {
  const _ImportBottomSheet({required this.onImport});
  final void Function(String type, String jsonString) onImport;

  @override
  State<_ImportBottomSheet> createState() => _ImportBottomSheetState();
}

class _ImportBottomSheetState extends State<_ImportBottomSheet> {
  String _importType = 'flashcards';
  final _jsonController = TextEditingController();
  String _validationStatus = 'empty'; // empty | valid | invalid
  int _parsedCount = 0;

  @override
  void initState() {
    super.initState();
    _jsonController.addListener(_validateJson);
  }

  @override
  void dispose() {
    _jsonController.removeListener(_validateJson);
    _jsonController.dispose();
    super.dispose();
  }

  void _validateJson() {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _validationStatus = 'empty';
        _parsedCount = 0;
      });
      return;
    }
    try {
      final parsed = jsonDecode(text);
      if (parsed is List) {
        setState(() {
          _validationStatus = 'valid';
          _parsedCount = parsed.length;
        });
      } else {
        setState(() {
          _validationStatus = 'invalid';
          _parsedCount = 0;
        });
      }
    } catch (_) {
      setState(() {
        _validationStatus = 'invalid';
        _parsedCount = 0;
      });
    }
  }

  String get _placeholder {
    if (_importType == 'flashcards') {
      return '[\n  {\n    "front": "Question ou recto de la carte",\n    "back": "Réponse ou verso de la carte",\n    "code": "Extrait de code optionnel"\n  }\n]';
    } else if (_importType == 'notes') {
      return '[\n  {\n    "title": "Titre du chapitre",\n    "content": "Contenu de la note en Markdown",\n    "tags": ["chapitre", "révision"]\n  }\n]';
    } else {
      return '[\n  {\n    "question": "Quelle est la capitale de la France ?",\n    "type": "multiple-choice",\n    "options": ["Marseille", "Paris", "Lyon", "Nice"],\n    "correctAnswer": 1,\n    "explanation": "Explication de la réponse...",\n    "topic": "Géographie"\n  }\n]';
    }
  }

  void _copyAiPrompt() {
    final prompt =
        'Agis en tant qu\'assistant pédagogique d\'élite et expert en apprentissage SRS. Je souhaite générer du contenu pour mon application EduFocus. Voici le format JSON strict à respecter sous forme de tableau :\n\n$_placeholder\n\nGénère 10 éléments pertinents sur le sujet suivant : "[Insérer le titre de votre cours ou sujet spécifique ici]". Retourne UNIQUEMENT le tableau JSON brut valide (sans explications supplémentaires, sans balises markdown de code block, juste le JSON brut).';
    Clipboard.setData(ClipboardData(text: prompt));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🤖 Prompt de génération IA copié avec succès !'),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyTemplateOnly() {
    Clipboard.setData(ClipboardData(text: _placeholder));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Modèle JSON copié !'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.file_upload_rounded,
                    color: AppColors.accentBright,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Importation Intelligente',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // AI Prompts and Guidance Panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🤖', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'MODÈLE DE GÉNÉRATION IA',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Copiez le prompt optimisé et le format attendu pour demander à votre IA de réviser vos cours ou générer des QCM sur-mesure.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copyAiPrompt,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.psychology_rounded, size: 14),
                          label: const Text(
                            'Copier le prompt IA',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyTemplateOnly,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.code_rounded, size: 14),
                          label: const Text(
                            'Modèle JSON',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Segmented Chips Selector
            Text(
              'Type de contenu à importer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSegmentChip(
                  'flashcards',
                  '🎴 Flashcards',
                  AppColors.accentBright,
                ),
                const SizedBox(width: 8),
                _buildSegmentChip('notes', '📝 Notes', AppColors.blue),
                const SizedBox(width: 8),
                _buildSegmentChip('qcm', '❓ QCM', AppColors.cyan),
              ],
            ),
            const SizedBox(height: 16),

            // Text Input Paste Area
            TextField(
              controller: _jsonController,
              maxLines: 5,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
              ),
              decoration: InputDecoration(
                hintText: _placeholder,
                hintStyle: TextStyle(color: AppColors.textMuted),
                labelText: 'Collez le tableau JSON ici',
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // Validation indicator row
            Row(
              children: [
                if (_validationStatus == 'empty') ...[
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textMuted,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'En attente du code JSON généré...',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ] else if (_validationStatus == 'valid') ...[
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.green,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'JSON Valide ! ($_parsedCount éléments détectés)',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  Icon(Icons.cancel_rounded, color: AppColors.red, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Format JSON invalide (vérifiez les virgules)',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 22),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _validationStatus == 'valid'
                      ? () {
                          widget.onImport(
                            _importType,
                            _jsonController.text.trim(),
                          );
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Importer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentChip(String type, String label, Color color) {
    final active = _importType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _importType = type;
          _jsonController.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: .12)
                : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color : AppColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? color : AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ADDITIONAL CUSTOM REDESIGN WIDGETS
// ══════════════════════════════════════════════════════════

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

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : AppColors.textMuted;
    final badgeColor = selected ? activeColor : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(
                          alpha: AppColors.isLight ? .14 : .22,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: .2),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: .2,
                ),
                child: Text(label),
              ),
            ],
          ),
          if (count > 0)
            Positioned(
              top: 8,
              right: 10,
              child: _TabBadge(count: count, color: badgeColor),
            ),
        ],
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          fontFamily: 'JetBrains Mono',
        ),
      ),
    );
  }
}
