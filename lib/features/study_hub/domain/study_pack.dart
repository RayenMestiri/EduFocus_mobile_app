import 'package:flutter/foundation.dart';

/// Immutable read models for /api/study-packs
/// (backend/models/StudyPack.js — envelope `{ success, data }`).

// ══════════════════════════════════════════════════════════
//  STUDY PACK — root aggregate
// ══════════════════════════════════════════════════════════

@immutable
class StudyPack {
  const StudyPack({
    required this.id,
    required this.title,
    required this.subject,
    this.description,
    this.progress = 0,
    this.streak = 0,
    this.isPublic = false,
    this.lastStudied,
    this.flashcards = const [],
    this.notes = const [],
    this.qcm = const [],
    this.cheatsheets = const [],
    this.exercises = const [],
  });

  final String id;
  final String title;
  final String subject;
  final String? description;
  final int progress;
  final int streak;
  final bool isPublic;
  final DateTime? lastStudied;
  final List<Flashcard> flashcards;
  final List<Note> notes;
  final List<QCM> qcm;
  final List<Cheatsheet> cheatsheets;
  final List<Exercise> exercises;

  factory StudyPack.fromJson(Map<String, dynamic> json) {
    return StudyPack(
      id: json['_id'] as String? ?? json['id'] as String,
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String?,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      isPublic: json['isPublic'] as bool? ?? false,
      lastStudied: json['lastStudied'] != null
          ? DateTime.tryParse(json['lastStudied'] as String)
          : null,
      flashcards: (json['flashcards'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Flashcard.fromJson)
          .toList(growable: false),
      notes: (json['notes'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Note.fromJson)
          .toList(growable: false),
      qcm: (json['qcm'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(QCM.fromJson)
          .toList(growable: false),
      cheatsheets: (json['cheatsheets'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Cheatsheet.fromJson)
          .toList(growable: false),
      exercises: (json['exercises'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Exercise.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'progress': progress,
      'streak': streak,
      'isPublic': isPublic,
      'lastStudied': lastStudied?.toIso8601String(),
      'flashcards': flashcards.map((f) => f.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'qcm': qcm.map((q) => q.toJson()).toList(),
      'cheatsheets': cheatsheets.map((c) => c.toJson()).toList(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  int get cardCount => flashcards.length;
  int get noteCount => notes.length;
  int get qcmCount => qcm.length;
  int get cheatsheetCount => cheatsheets.length;
  int get exerciseCount => exercises.length;

  /// Total content items across all types.
  int get totalContent =>
      cardCount + noteCount + qcmCount + cheatsheetCount + exerciseCount;

  /// Cards whose SRS due date has passed (or never reviewed) — mirrors the
  /// Angular SRS engine's "due" definition for read-only display.
  int get dueCount {
    final now = DateTime.now();
    return flashcards.where((c) {
      if (c.state == 'new') return true;
      final due = c.dueDate;
      return due != null && !due.isAfter(now);
    }).length;
  }

  int countByState(String state) =>
      flashcards.where((c) => c.state == state).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is StudyPack && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════
//  FLASHCARD — SRS-managed card
// ══════════════════════════════════════════════════════════

@immutable
class Flashcard {
  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.code,
    this.difficulty,
    this.state = 'new',
    this.repetitions = 0,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.dueDate,
    this.lastReviewed,
    this.lapses = 0,
  });

  final String id;
  final String front;
  final String back;
  final String? code;
  final String? difficulty;

  /// new | learning | review | mastered (SM-2 state).
  final String state;
  final int repetitions;
  final int interval;
  final double easeFactor;
  final DateTime? dueDate;
  final DateTime? lastReviewed;
  final int lapses;

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String? ?? '',
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      code: json['code'] as String?,
      difficulty: json['difficulty'] as String?,
      state: json['state'] as String? ?? 'new',
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      interval: (json['interval'] as num?)?.toInt() ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      lastReviewed: json['lastReviewed'] != null
          ? DateTime.tryParse(json['lastReviewed'] as String)
          : null,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'front': front,
      'back': back,
      'code': code,
      'difficulty': difficulty,
      'state': state,
      'repetitions': repetitions,
      'interval': interval,
      'easeFactor': easeFactor,
      'dueDate': dueDate?.toIso8601String(),
      'lastReviewed': lastReviewed?.toIso8601String(),
      'lapses': lapses,
    };
  }
}

// ══════════════════════════════════════════════════════════
//  NOTE — rich text note inside a pack
// ══════════════════════════════════════════════════════════

@immutable
class Note {
  const Note({
    required this.id,
    required this.title,
    this.content = '',
    this.tags = const [],
    this.isPinned = false,
    this.color = '#E0F2FE',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final bool isPinned;
  final String color;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Sans titre',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List? ?? const []).whereType<String>().toList(
        growable: false,
      ),
      isPinned: json['isPinned'] as bool? ?? false,
      color: json['color'] as String? ?? '#E0F2FE',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'isPinned': isPinned,
      'color': color,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

// ══════════════════════════════════════════════════════════
//  QCM — quiz question (multiple-choice / true-false / fill-blanks)
// ══════════════════════════════════════════════════════════

@immutable
class QCM {
  const QCM({
    required this.id,
    required this.question,
    this.type = 'multiple-choice',
    this.options = const [],
    required this.correctAnswer,
    this.explanation,
    this.trapNote,
    this.topic,
  });

  final String id;
  final String question;

  /// `multiple-choice` | `true-false` | `fill-blanks`
  final String type;
  final List<String> options;

  /// Can be int (index) for multiple-choice, bool for true-false,
  /// or String for fill-blanks. Stored as dynamic from the backend.
  final dynamic correctAnswer;
  final String? explanation;
  final String? trapNote;
  final String? topic;

  factory QCM.fromJson(Map<String, dynamic> json) {
    return QCM(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      type: json['type'] as String? ?? 'multiple-choice',
      options: (json['options'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      correctAnswer: json['correctAnswer'],
      explanation: json['explanation'] as String?,
      trapNote: json['trapNote'] as String?,
      topic: json['topic'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'type': type,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'trapNote': trapNote,
      'topic': topic,
    };
  }

  /// Check if a given answer is correct (handles int index and string match).
  bool isCorrect(dynamic answer) {
    if (type == 'true-false') {
      return answer.toString().toLowerCase() ==
          correctAnswer.toString().toLowerCase();
    }
    if (type == 'fill-blanks') {
      return answer.toString().trim().toLowerCase() ==
          correctAnswer.toString().trim().toLowerCase();
    }
    // multiple-choice: correctAnswer is typically the index (int)
    if (correctAnswer is int) return answer == correctAnswer;
    return answer.toString() == correctAnswer.toString();
  }
}

// ══════════════════════════════════════════════════════════
//  CHEATSHEET — reference card with key/value items
// ══════════════════════════════════════════════════════════

@immutable
class CheatsheetItem {
  const CheatsheetItem({required this.key, required this.value});

  final String key;
  final String value;

  factory CheatsheetItem.fromJson(Map<String, dynamic> json) {
    return CheatsheetItem(
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'key': key, 'value': value};
  }
}

@immutable
class Cheatsheet {
  const Cheatsheet({
    required this.id,
    required this.title,
    this.category = 'Général',
    this.items = const [],
    this.codeSample,
  });

  final String id;
  final String title;
  final String category;
  final List<CheatsheetItem> items;
  final String? codeSample;

  factory Cheatsheet.fromJson(Map<String, dynamic> json) {
    return Cheatsheet(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'Général',
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CheatsheetItem.fromJson)
          .toList(growable: false),
      codeSample: json['codeSample'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'items': items.map((i) => i.toJson()).toList(),
      'codeSample': codeSample,
    };
  }
}

// ══════════════════════════════════════════════════════════
//  EXERCISE — practice problem with solution
// ══════════════════════════════════════════════════════════

@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    required this.description,
    this.schemaContext,
    required this.task,
    required this.correctSolution,
    this.solutionNote,
  });

  final String id;
  final String title;
  final String description;
  final String? schemaContext;
  final String task;
  final String correctSolution;
  final String? solutionNote;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      schemaContext: json['schemaContext'] as String?,
      task: json['task'] as String? ?? '',
      correctSolution: json['correctSolution'] as String? ?? '',
      solutionNote: json['solutionNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'schemaContext': schemaContext,
      'task': task,
      'correctSolution': correctSolution,
      'solutionNote': solutionNote,
    };
  }
}
