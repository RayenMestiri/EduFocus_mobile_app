import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/study_packs_repository.dart';
import '../../domain/study_pack.dart';

/// Parses a note color hex (may be `#RGB`, `#RRGGBB` or `#AARRGGBB`).
Color _parseHexColor(String hexString) {
  final hex = hexString.replaceFirst('#', '');
  final buffer = StringBuffer();
  if (hex.length <= 6) buffer.write('ff');
  if (hex.length == 3) {
    for (final c in hex.split('')) {
      buffer.write('$c$c');
    }
  } else {
    buffer.write(hex);
  }
  return Color(int.tryParse(buffer.toString(), radix: 16) ?? 0xFF8B5CF6);
}

/// Premium note reader/editor — Craft/Notion-grade.
///
/// The note's stored pastel color is used only as an *accent* (header glow,
/// tag tint, heading rules) over the app's cohesive dark canvas, rather than
/// flooding the whole screen — this keeps it consistent with the rest of the
/// premium dark UI while still feeling personal.
class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({super.key, required this.note, required this.packId});

  final Note note;
  final String packId;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late Note _currentNote;
  bool _editMode = false;
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _contentFocusNode = FocusNode();
  bool _isPinned = false;

  // Accent palette offered in the editor (vivid, tuned for the dark canvas).
  static const _colors = [
    '#8B5CF6', '#6366F1', '#3B82F6', '#22D3EE',
    '#34D399', '#FBBF24', '#F97316', '#F87171',
  ];
  String _selectedColor = '#8B5CF6';

  Color get _accent => _parseHexColor(_editMode ? _selectedColor : _currentNote.color);

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _isPinned = _currentNote.isPinned;
    _selectedColor = _currentNote.color;
    _initForm();
  }

  void _initForm() {
    _titleController.text = _currentNote.title;
    _contentController.text = _currentNote.content;
    _tagsController.text = _currentNote.tags.join(', ');
    _selectedColor = _currentNote.color;
    _isPinned = _currentNote.isPinned;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  // ── Editing helpers ────────────────────────────────────────────────────────

  void _insertMarkdown(String snippet, {int caretBack = 0}) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final newText = text.replaceRange(start, end, snippet);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + snippet.length - caretBack,
      ),
    );
    _contentFocusNode.requestFocus();
  }

  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? AppColors.surfaceHover,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _togglePin() async {
    setState(() => _isSaving = true);
    try {
      final pack = await ref.read(studyPacksRepositoryProvider).getById(widget.packId);
      final updatedNotes = pack.notes.map((n) {
        return n.id == _currentNote.id
            ? Note(
                id: n.id,
                title: n.title,
                content: n.content,
                tags: n.tags,
                isPinned: !n.isPinned,
                color: n.color,
                createdAt: n.createdAt,
                updatedAt: DateTime.now(),
              )
            : n;
      }).map((n) => n.toJson()).toList();

      final updatedPack = await ref
          .read(studyPacksRepositoryProvider)
          .update(widget.packId, {'notes': updatedNotes});
      ref.invalidate(studyPackProvider(widget.packId));
      ref.invalidate(studyPacksProvider);

      final newNote = updatedPack.notes.firstWhere((n) => n.id == _currentNote.id);
      setState(() {
        _currentNote = newNote;
        _isPinned = newNote.isPinned;
      });
      _snack(_isPinned ? 'Note épinglée' : 'Épingle retirée', color: AppColors.accent);
    } catch (e) {
      _snack('Impossible de modifier l\'épingle', color: AppColors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveEdits() async {
    if (_titleController.text.trim().isEmpty) {
      _snack('Le titre ne peut pas être vide.', color: AppColors.red);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final pack = await ref.read(studyPacksRepositoryProvider).getById(widget.packId);
      final tags = _tagsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final updatedNotes = pack.notes.map((n) {
        return n.id == _currentNote.id
            ? Note(
                id: n.id,
                title: _titleController.text.trim(),
                content: _contentController.text.trim(),
                tags: tags,
                isPinned: _isPinned,
                color: _selectedColor,
                createdAt: n.createdAt,
                updatedAt: DateTime.now(),
              )
            : n;
      }).map((n) => n.toJson()).toList();

      final updatedPack = await ref
          .read(studyPacksRepositoryProvider)
          .update(widget.packId, {'notes': updatedNotes});
      ref.invalidate(studyPackProvider(widget.packId));
      ref.invalidate(studyPacksProvider);

      final newNote = updatedPack.notes.firstWhere((n) => n.id == _currentNote.id);
      setState(() {
        _currentNote = newNote;
        _selectedColor = newNote.color;
        _editMode = false;
      });
      _snack('Note enregistrée', color: AppColors.green);
    } catch (e) {
      _snack('Erreur d\'enregistrement', color: AppColors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Ambient accent glow behind the header.
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            child: IgnorePointer(
              child: Container(
                height: 320,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 0.9,
                    colors: [_accent.withValues(alpha: .16), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          _editMode ? _buildEditor() : _buildReader(),
        ],
      ),
      floatingActionButton: _editMode
          ? null
          : FloatingActionButton.extended(
              heroTag: 'note-edit',
              onPressed: () {
                _initForm();
                setState(() => _editMode = true);
              },
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              icon: const Icon(Icons.edit_rounded, size: 19),
              label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AppBar(
            backgroundColor: AppColors.bg.withValues(alpha: .55),
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: () =>
                  _editMode ? setState(() => _editMode = false) : context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            title: Text(
              _editMode ? 'Édition' : 'Note',
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
            ),
            actions: _editMode
                ? [
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.only(right: 20),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: FilledButton(
                          onPressed: _saveEdits,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Enregistrer',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                  ]
                : [
                    _GhostIconButton(
                      icon: _isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: _isPinned ? AppColors.yellow : null,
                      onTap: _isSaving ? null : _togglePin,
                    ),
                    _GhostIconButton(
                      icon: Icons.copy_all_rounded,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _currentNote.content));
                        _snack('Contenu copié', color: AppColors.accent);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  READER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildReader() {
    final note = _currentNote;
    final words = note.content.trim().isEmpty
        ? 0
        : note.content.trim().split(RegExp(r'\s+')).length;
    final readMins = (words / 200).ceil().clamp(1, 999);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 120),
      children: [
        // ── Meta row ──
        Row(
          children: [
            if (_isPinned) ...[
              _MetaPill(
                icon: Icons.push_pin_rounded,
                label: 'Épinglée',
                color: AppColors.yellow,
              ),
              const SizedBox(width: 8),
            ],
            if (note.createdAt != null)
              Text(
                _formatDate(note.updatedAt ?? note.createdAt!),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Spacer(),
            if (words > 0)
              Text(
                '$words mots · $readMins min',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),

        // ── Title with accent spine ──
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                margin: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_accent, _accent.withValues(alpha: .35)],
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: Text(
                  note.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 27,
                    letterSpacing: -0.9,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Tags ──
        if (note.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in note.tags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accent.withValues(alpha: .25)),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],

        const SizedBox(height: 22),
        Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 22),

        // ── Content ──
        if (note.content.trim().isEmpty)
          _EmptyNote(accent: _accent)
        else
          _MarkdownView(content: note.content, accent: _accent, onCopy: _snack),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EDITOR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEditor() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 76, 20, 20),
              children: [
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.7,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Titre de la note',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.local_offer_rounded, size: 14, color: _accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _tagsController,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'tags séparés par des virgules',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 14),
                TextField(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.7,
                    color: AppColors.textPrimary.withValues(alpha: .92),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Écrivez en Markdown…',
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),

          // ── Accent color strip ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Accent',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final hex = _colors[i];
                        final color = _parseHexColor(hex);
                        final active = _selectedColor.toUpperCase() == hex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: active ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: active
                                  ? [BoxShadow(color: color.withValues(alpha: .5), blurRadius: 10)]
                                  : null,
                            ),
                            child: active
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Markdown toolbar ──
          Container(
            padding: EdgeInsets.fromLTRB(
              8,
              8,
              8,
              8 + MediaQuery.of(context).viewInsets.bottom * 0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ToolBtn(icon: Icons.title_rounded, label: 'H1', onTap: () => _insertMarkdown('\n# ')),
                  _ToolBtn(icon: Icons.text_fields_rounded, label: 'H2', onTap: () => _insertMarkdown('\n## ')),
                  _ToolBtn(icon: Icons.format_bold_rounded, onTap: () => _insertMarkdown('****', caretBack: 2)),
                  _ToolBtn(icon: Icons.format_italic_rounded, onTap: () => _insertMarkdown('**', caretBack: 1)),
                  _ToolBtn(icon: Icons.format_list_bulleted_rounded, onTap: () => _insertMarkdown('\n- ')),
                  _ToolBtn(icon: Icons.checklist_rounded, onTap: () => _insertMarkdown('\n- [ ] ')),
                  _ToolBtn(icon: Icons.code_rounded, onTap: () => _insertMarkdown('\n```\n\n```', caretBack: 4)),
                  _ToolBtn(icon: Icons.data_object_rounded, onTap: () => _insertMarkdown('``', caretBack: 1)),
                  _ToolBtn(icon: Icons.format_quote_rounded, onTap: () => _insertMarkdown('\n> ')),
                  _ToolBtn(icon: Icons.lightbulb_outline_rounded, onTap: () => _insertMarkdown('\n> [!tip] ')),
                  _ToolBtn(icon: Icons.highlight_rounded, onTap: () => _insertMarkdown('====', caretBack: 2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SMALL SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({required this.icon, this.color, this.onTap});

  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({required this.icon, this.label, required this.onTap});

  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            height: 40,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                if (label != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    label!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.article_outlined, size: 40, color: accent.withValues(alpha: .5)),
          const SizedBox(height: 14),
          const Text(
            'Cette note est vide',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Touchez « Modifier » pour commencer à écrire.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MARKDOWN RENDERER
// ═══════════════════════════════════════════════════════════════════════════

class _MarkdownView extends StatelessWidget {
  const _MarkdownView({
    required this.content,
    required this.accent,
    required this.onCopy,
  });

  final String content;
  final Color accent;
  final void Function(String, {Color? color}) onCopy;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final blocks = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // ── Fenced code block ──
      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          code.add(lines[i]);
          i++;
        }
        blocks.add(_CodeBlock(
          code: code.join('\n'),
          language: lang.isEmpty ? 'code' : lang,
          onCopy: onCopy,
        ));
        continue;
      }

      // ── Table (contiguous pipe lines) ──
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final rows = <String>[];
        while (i < lines.length &&
            lines[i].trim().startsWith('|') &&
            lines[i].trim().endsWith('|')) {
          rows.add(lines[i].trim());
          i++;
        }
        i--; // step back; outer loop will ++.
        blocks.add(_MdTable(rows: rows, accent: accent));
        continue;
      }

      // ── Callout: > [!tip] / [!note] / [!warning] ──
      final calloutMatch =
          RegExp(r'^>\s*\[!(\w+)\]\s*(.*)$').firstMatch(trimmed);
      if (calloutMatch != null) {
        blocks.add(_Callout(
          kind: calloutMatch.group(1)!.toLowerCase(),
          text: calloutMatch.group(2) ?? '',
          accent: accent,
        ));
        continue;
      }

      blocks.add(_mdLine(line, accent));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  static Widget _mdLine(String line, Color accent) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return const SizedBox(height: 10);

    // Headings
    if (trimmed.startsWith('### ')) {
      return _heading(trimmed.substring(4), 16.5, FontWeight.w800, accent, rule: false);
    }
    if (trimmed.startsWith('## ')) {
      return _heading(trimmed.substring(3), 19, FontWeight.w800, accent, rule: true);
    }
    if (trimmed.startsWith('# ')) {
      return _heading(trimmed.substring(2), 23, FontWeight.w800, accent, rule: true, full: true);
    }

    // Checkboxes
    final checkbox = RegExp(r'^[-*]\s*\[( |x|X)\]\s*(.*)$').firstMatch(trimmed);
    if (checkbox != null) {
      final checked = checkbox.group(1)!.toLowerCase() == 'x';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 19,
              height: 19,
              margin: const EdgeInsets.only(top: 2, right: 11),
              decoration: BoxDecoration(
                color: checked ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? accent : AppColors.textMuted,
                  width: 1.8,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
            Expanded(
              child: _RichLine(
                text: checkbox.group(2) ?? '',
                accent: accent,
                strike: checked,
                muted: checked,
              ),
            ),
          ],
        ),
      );
    }

    // Numbered list
    final numbered = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
    if (numbered != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 10, top: 1),
              child: Text(
                '${numbered.group(1)}.',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ),
            Expanded(child: _RichLine(text: numbered.group(2) ?? '', accent: accent)),
          ],
        ),
      );
    }

    // Bullet list
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 8, right: 12),
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            Expanded(child: _RichLine(text: trimmed.substring(2), accent: accent)),
          ],
        ),
      );
    }

    // Quote
    if (trimmed.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: _RichLine(
          text: trimmed.substring(2),
          accent: accent,
          italic: true,
          muted: true,
        ),
      );
    }

    // Divider
    if (trimmed == '---' || trimmed == '***') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Divider(color: AppColors.border, height: 1),
      );
    }

    // Paragraph
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _RichLine(text: line, accent: accent),
    );
  }

  static Widget _heading(
    String text,
    double size,
    FontWeight weight,
    Color accent, {
    required bool rule,
    bool full = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: size > 18 ? 20 : 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.inter(
              fontWeight: weight,
              fontSize: size,
              letterSpacing: -0.5,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
          ),
          if (rule) ...[
            const SizedBox(height: 7),
            Container(
              width: full ? double.infinity : 30,
              height: full ? 1 : 2.5,
              decoration: BoxDecoration(
                color: full ? AppColors.border : accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline-formatted line: **bold**, *italic*, `code`, ==highlight==, [text](url).
class _RichLine extends StatelessWidget {
  const _RichLine({
    required this.text,
    required this.accent,
    this.italic = false,
    this.strike = false,
    this.muted = false,
  });

  final String text;
  final Color accent;
  final bool italic;
  final bool strike;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(
      fontSize: 15,
      height: 1.65,
      color: (muted ? AppColors.textSecondary : AppColors.textPrimary)
          .withValues(alpha: muted ? .85 : .92),
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: strike ? TextDecoration.lineThrough : null,
      decorationColor: AppColors.textMuted,
    );

    return Text.rich(TextSpan(style: base, children: _parseInline(text, base, accent)));
  }

  static List<InlineSpan> _parseInline(String text, TextStyle base, Color accent) {
    final pattern = RegExp(
      r'(\*\*(.+?)\*\*)'      // bold
      r'|(`(.+?)`)'            // inline code
      r'|(==(.+?)==)'          // highlight
      r'|(\*(.+?)\*)'          // italic
      r'|(\[(.+?)\]\((.+?)\))', // link
    );

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(2),
          style: base.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ));
      } else if (m.group(4) != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              m.group(4)!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ));
      } else if (m.group(6) != null) {
        spans.add(TextSpan(
          text: ' ${m.group(6)} ',
          style: base.copyWith(
            color: const Color(0xFF1A1024),
            fontWeight: FontWeight.w700,
            background: Paint()
              ..color = accent.withValues(alpha: .85)
              ..strokeCap = StrokeCap.round,
          ),
        ));
      } else if (m.group(8) != null) {
        spans.add(TextSpan(
          text: m.group(8),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(10) != null) {
        spans.add(TextSpan(
          text: m.group(10),
          style: base.copyWith(
            color: accent,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: accent.withValues(alpha: .4),
          ),
        ));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CALLOUT
// ═══════════════════════════════════════════════════════════════════════════

class _Callout extends StatelessWidget {
  const _Callout({required this.kind, required this.text, required this.accent});

  final String kind;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (kind) {
      'tip' || 'success' => (AppColors.green, Icons.lightbulb_rounded, 'Astuce'),
      'warning' || 'caution' => (AppColors.yellow, Icons.warning_amber_rounded, 'Attention'),
      'danger' || 'error' => (AppColors.red, Icons.error_rounded, 'Important'),
      'info' => (AppColors.blue, Icons.info_rounded, 'Info'),
      _ => (accent, Icons.sticky_note_2_rounded, 'Note'),
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                _RichLine(text: text, accent: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TABLE
// ═══════════════════════════════════════════════════════════════════════════

class _MdTable extends StatelessWidget {
  const _MdTable({required this.rows, required this.accent});

  final List<String> rows;
  final Color accent;

  List<String> _cells(String row) {
    var r = row.trim();
    if (r.startsWith('|')) r = r.substring(1);
    if (r.endsWith('|')) r = r.substring(0, r.length - 1);
    return r.split('|').map((c) => c.trim()).toList();
  }

  bool _isSeparator(String row) =>
      RegExp(r'^[\s|:-]+$').hasMatch(row) && row.contains('-');

  @override
  Widget build(BuildContext context) {
    final dataRows = rows.where((r) => !_isSeparator(r)).toList();
    if (dataRows.isEmpty) return const SizedBox.shrink();
    final header = _cells(dataRows.first);
    final body = dataRows.skip(1).map(_cells).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              decoration: BoxDecoration(color: accent.withValues(alpha: .12)),
              children: [
                for (final h in header)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Text(
                      h,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
            for (var r = 0; r < body.length; r++)
              TableRow(
                decoration: BoxDecoration(
                  color: r.isOdd ? AppColors.surfaceHover.withValues(alpha: .4) : null,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                children: [
                  for (var c = 0; c < header.length; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(
                        c < body[r].length ? body[r][c] : '',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CODE BLOCK — VS Code / GitHub style with line numbers + syntax highlight
// ═══════════════════════════════════════════════════════════════════════════

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.code,
    required this.language,
    required this.onCopy,
  });

  final String code;
  final String language;
  final void Function(String, {Color? color}) onCopy;

  static const _bg = Color(0xFF0D1117); // GitHub dark canvas
  static const _headerBg = Color(0xFF161B22);
  static const _gutter = Color(0xFF484F58);

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header bar: traffic lights + language + copy ──
          Container(
            color: _headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _dot(const Color(0xFFFF5F56)),
                const SizedBox(width: 7),
                _dot(const Color(0xFFFFBD2E)),
                const SizedBox(width: 7),
                _dot(const Color(0xFF27C93F)),
                const SizedBox(width: 14),
                Text(
                  language,
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF8B949E),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    onCopy('Code copié', color: AppColors.accent);
                  },
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white.withValues(alpha: .08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.content_copy_rounded, size: 12, color: Color(0xFF8B949E)),
                        const SizedBox(width: 5),
                        Text(
                          'Copier',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8B949E),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Code body with gutter ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line number gutter
                        Container(
                          width: 44,
                          padding: const EdgeInsets.only(right: 14, top: 2, bottom: 2),
                          alignment: Alignment.topRight,
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.jetBrainsMono(
                              color: _gutter,
                              fontSize: 12.5,
                              height: 1.6,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 18, top: 2, bottom: 2),
                          child: Text.rich(
                            TextSpan(children: _highlight(lines[i])),
                            style: GoogleFonts.jetBrainsMono(fontSize: 12.5, height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) =>
      Container(width: 11, height: 11, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  // ── Lightweight, language-agnostic syntax highlighter ──
  static const _base = Color(0xFFE6EDF3);
  static const _keyword = Color(0xFFFF7B72);
  static const _string = Color(0xFFA5D6FF);
  static const _comment = Color(0xFF8B949E);
  static const _number = Color(0xFF79C0FF);
  static const _func = Color(0xFFD2A8FF);

  static final _keywords = {
    'const', 'final', 'var', 'let', 'function', 'func', 'def', 'class',
    'return', 'if', 'else', 'elif', 'for', 'while', 'do', 'import', 'export',
    'from', 'async', 'await', 'void', 'int', 'double', 'float', 'string',
    'bool', 'true', 'false', 'null', 'none', 'new', 'this', 'self', 'super',
    'public', 'private', 'protected', 'static', 'extends', 'implements',
    'interface', 'enum', 'struct', 'try', 'catch', 'except', 'finally',
    'throw', 'throws', 'switch', 'case', 'break', 'continue', 'in', 'is',
    'as', 'not', 'and', 'or', 'lambda', 'yield', 'with', 'print', 'type',
    'abstract', 'override', 'required', 'late', 'get', 'set', 'widget',
  };

  static List<TextSpan> _highlight(String line) {
    if (line.trim().isEmpty) return const [TextSpan(text: ' ')];

    // Whole-line comment.
    final t = line.trimLeft();
    if (t.startsWith('//') || t.startsWith('#') || t.startsWith('*') || t.startsWith('/*')) {
      return [TextSpan(text: line, style: const TextStyle(color: _comment, fontStyle: FontStyle.italic))];
    }

    final spans = <TextSpan>[];
    final token = RegExp(
      r'''("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)''' // strings
      r'|(//.*$|#.*$)'                                              // trailing comment
      r'|(\b\d+(?:\.\d+)?\b)'                                       // numbers
      r'|(\b[A-Za-z_]\w*\b)'                                        // identifiers
      r'|(\s+)'                                                     // whitespace
      r'|(.)',                                                      // any other char
      multiLine: true,
    );

    for (final m in token.allMatches(line)) {
      final s = m.group(0)!;
      if (m.group(1) != null) {
        spans.add(TextSpan(text: s, style: const TextStyle(color: _string)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: s, style: const TextStyle(color: _comment, fontStyle: FontStyle.italic)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: s, style: const TextStyle(color: _number)));
      } else if (m.group(4) != null) {
        if (_keywords.contains(s.toLowerCase())) {
          spans.add(TextSpan(text: s, style: const TextStyle(color: _keyword, fontWeight: FontWeight.w600)));
        } else {
          // Function call if followed by '(' — cheap lookahead.
          final after = line.substring(m.end).trimLeft();
          final isCall = after.startsWith('(');
          spans.add(TextSpan(text: s, style: TextStyle(color: isCall ? _func : _base)));
        }
      } else {
        spans.add(TextSpan(text: s, style: const TextStyle(color: _base)));
      }
    }
    return spans;
  }
}
