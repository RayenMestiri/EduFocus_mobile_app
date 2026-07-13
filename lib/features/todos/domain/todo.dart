import 'package:flutter/foundation.dart';

/// Immutable domain model for a task
/// (backend/models/Todo.js — envelope `{ success, data }`).
///
/// `subjectId` is populated server-side, so it arrives either as a plain id
/// string or as a full subject object — both are handled.
@immutable
class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.date,
    this.done = false,
    this.priority = 'medium',
    this.subjectId,
  });

  final String id;
  final String title;

  /// `YYYY-MM-DD`.
  final String date;
  final bool done;

  /// low | medium | high | urgent.
  final String priority;
  final String? subjectId;

  factory Todo.fromJson(Map<String, dynamic> json) {
    final rawSubject = json['subjectId'];
    return Todo(
      id: json['_id'] as String? ?? json['id'] as String,
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      priority: json['priority'] as String? ?? 'medium',
      subjectId: switch (rawSubject) {
        final String id => id,
        final Map<String, dynamic> populated => populated['_id'] as String?,
        _ => null,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Todo && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
