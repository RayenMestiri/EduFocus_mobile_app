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

/// Curated library of subject icons — crisp Material vectors that render
/// instantly on every platform (unlike emoji, which flicker while their
/// colour font loads on Flutter web). Grouped loosely by theme; the map
/// order is the order shown in the picker. Unknown names fall back to a book.
const kSubjectMaterialIcons = <String, IconData>{
  // ── General & study ──
  'menu_book': Icons.menu_book_rounded,
  'auto_stories': Icons.auto_stories_rounded,
  'book': Icons.book_rounded,
  'import_contacts': Icons.import_contacts_rounded,
  'local_library': Icons.local_library_rounded,
  'school': Icons.school_rounded,
  'edit': Icons.edit_rounded,
  'edit_note': Icons.edit_note_rounded,
  'article': Icons.article_rounded,
  'description': Icons.description_rounded,
  'sticky_note_2': Icons.sticky_note_2_rounded,
  'bookmark': Icons.bookmark_rounded,
  'label': Icons.label_rounded,
  'lightbulb': Icons.lightbulb_rounded,
  'emoji_objects': Icons.emoji_objects_rounded,
  'quiz': Icons.quiz_rounded,
  'extension': Icons.extension_rounded,
  'star': Icons.star_rounded,
  'grade': Icons.grade_rounded,
  'workspace_premium': Icons.workspace_premium_rounded,
  'emoji_events': Icons.emoji_events_rounded,

  // ── Maths & logic ──
  'calculate': Icons.calculate_rounded,
  'functions': Icons.functions_rounded,
  'percent': Icons.percent_rounded,
  'tag': Icons.tag_rounded,
  'square_foot': Icons.square_foot_rounded,
  'straighten': Icons.straighten_rounded,

  // ── Sciences ──
  'science': Icons.science_rounded,
  'biotech': Icons.biotech_rounded,
  'psychology': Icons.psychology_rounded,
  'memory': Icons.memory_rounded,
  'bolt': Icons.bolt_rounded,
  'thermostat': Icons.thermostat_rounded,
  'water_drop': Icons.water_drop_rounded,
  'eco': Icons.eco_rounded,
  'spa': Icons.spa_rounded,
  'pets': Icons.pets_rounded,
  'agriculture': Icons.agriculture_rounded,

  // ── Technology ──
  'code': Icons.code_rounded,
  'terminal': Icons.terminal_rounded,
  'computer': Icons.computer_rounded,
  'laptop': Icons.laptop_rounded,
  'dns': Icons.dns_rounded,
  'storage': Icons.storage_rounded,
  'data_object': Icons.data_object_rounded,
  'smart_toy': Icons.smart_toy_rounded,
  'rocket_launch': Icons.rocket_launch_rounded,
  'developer_board': Icons.developer_board_rounded,

  // ── Languages & humanities ──
  'language': Icons.language_rounded,
  'translate': Icons.translate_rounded,
  'public': Icons.public_rounded,
  'history_edu': Icons.history_edu_rounded,
  'account_balance': Icons.account_balance_rounded,
  'gavel': Icons.gavel_rounded,
  'record_voice_over': Icons.record_voice_over_rounded,
  'forum': Icons.forum_rounded,
  'groups': Icons.groups_rounded,
  'travel_explore': Icons.travel_explore_rounded,
  'map': Icons.map_rounded,
  'flight': Icons.flight_rounded,

  // ── Arts & media ──
  'palette': Icons.palette_rounded,
  'brush': Icons.brush_rounded,
  'draw': Icons.draw_rounded,
  'design_services': Icons.design_services_rounded,
  'architecture': Icons.architecture_rounded,
  'music_note': Icons.music_note_rounded,
  'piano': Icons.piano_rounded,
  'theater_comedy': Icons.theater_comedy_rounded,
  'movie': Icons.movie_rounded,
  'photo_camera': Icons.photo_camera_rounded,

  // ── Health & sport ──
  'fitness_center': Icons.fitness_center_rounded,
  'sports_esports': Icons.sports_esports_rounded,
  'sports_soccer': Icons.sports_soccer_rounded,
  'sports_basketball': Icons.sports_basketball_rounded,
  'directions_run': Icons.directions_run_rounded,
  'self_improvement': Icons.self_improvement_rounded,
  'favorite': Icons.favorite_rounded,
  'medical_services': Icons.medical_services_rounded,
  'restaurant': Icons.restaurant_rounded,

  // ── Misc ──
  'work': Icons.work_rounded,
  'business_center': Icons.business_center_rounded,
  'savings': Icons.savings_rounded,
  'attach_money': Icons.attach_money_rounded,
  'coffee': Icons.coffee_rounded,
  'wb_sunny': Icons.wb_sunny_rounded,
  'nightlight': Icons.nightlight_rounded,
  'cleaning_services': Icons.cleaning_services_rounded,
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
