import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Immutable domain model for a study subject
/// (backend/models/Subject.js — envelope `{ success, data }`).
@immutable
class Subject {
  const Subject({
    required this.id,
    required this.name,
    this.description,
    this.colorHex = '#8b5cf6',
    this.icon = '📚',
    this.category = 'other',
    this.totalStudyMinutes = 0,
    this.totalSessions = 0,
  });

  final String id;
  final String name;
  final String? description;
  final String colorHex;

  /// Either an emoji (`📚`) or a Material icon name (`palette`) — subjects
  /// created in the Angular client use icon names.
  final String icon;
  final String category;
  final int totalStudyMinutes;
  final int totalSessions;

  factory Subject.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    return Subject(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      colorHex: json['color'] as String? ?? '#8b5cf6',
      icon: json['icon'] as String? ?? '📚',
      category: json['category'] as String? ?? 'other',
      totalStudyMinutes: (stats['totalStudyMinutes'] as num?)?.toInt() ?? 0,
      totalSessions: (stats['totalSessions'] as num?)?.toInt() ?? 0,
    );
  }

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    final value = int.tryParse(
      hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex,
      radix: 16,
    );
    return value == null ? AppColors.accent : Color(0xFF000000 | value);
  }

  bool get hasIconName => RegExp(r'^[a-z_]+$').hasMatch(icon);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Subject && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Maps the Material icon names used by the Angular icon picker to Flutter
/// icons; unknown names fall back to a book so nothing ever renders as raw
/// text.
const kSubjectMaterialIcons = <String, IconData>{
  'menu_book': Icons.menu_book_rounded,
  'auto_stories': Icons.auto_stories_rounded,
  'palette': Icons.palette_rounded,
  'brush': Icons.brush_rounded,
  'calculate': Icons.calculate_rounded,
  'functions': Icons.functions_rounded,
  'science': Icons.science_rounded,
  'biotech': Icons.biotech_rounded,
  'code': Icons.code_rounded,
  'terminal': Icons.terminal_rounded,
  'computer': Icons.computer_rounded,
  'language': Icons.language_rounded,
  'translate': Icons.translate_rounded,
  'public': Icons.public_rounded,
  'history_edu': Icons.history_edu_rounded,
  'psychology': Icons.psychology_rounded,
  'music_note': Icons.music_note_rounded,
  'sports_esports': Icons.sports_esports_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'school': Icons.school_rounded,
  'book': Icons.book_rounded,
  'edit': Icons.edit_rounded,
  'star': Icons.star_rounded,
  'mop': Icons.cleaning_services_rounded,
};

/// Renders a subject icon consistently: mapped Material icon for icon names,
/// text for emoji.
class SubjectIcon extends StatelessWidget {
  const SubjectIcon(this.subject, {super.key, this.size = 20});

  final Subject subject;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (subject.hasIconName) {
      return Icon(
        kSubjectMaterialIcons[subject.icon] ?? Icons.menu_book_rounded,
        color: subject.color,
        size: size,
      );
    }
    return Text(subject.icon, style: TextStyle(fontSize: size - 2));
  }
}
