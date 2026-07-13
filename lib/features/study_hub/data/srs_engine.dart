import '../domain/study_pack.dart';

/// Spaced Repetition System (SRS) Engine based on the SM-2 algorithm.
/// Matches the Angular srs-engine.service.ts implementation exactly.
class SrsEngine {
  static const double minEase = 1.3;
  static const double defaultEase = 2.5;
  static const int masteryInterval = 21; // Days

  static DateTime addMinutes(DateTime dt, int minutes) {
    return dt.add(Duration(minutes: minutes));
  }

  static DateTime addDays(DateTime dt, int days) {
    return dt.add(Duration(days: days));
  }

  static bool checkMastery(int interval, double easeFactor) {
    return interval >= masteryInterval;
  }

  /// Rate a card using Anki/SM-2 scale:
  /// - 0 = Again (À revoir)
  /// - 1 = Hard (Difficile)
  /// - 2 = Good (Bien)
  /// - 3 = Easy (Facile)
  static Flashcard rateCard(Flashcard card, int rating) {
    final now = DateTime.now();
    
    String state = card.state;
    int repetitions = card.repetitions;
    int interval = card.interval;
    double easeFactor = card.easeFactor;
    int lapses = card.lapses;

    // ── AGAIN (0) ──
    if (rating == 0) {
      if (state == 'review' || state == 'mastered') {
        lapses++;
      }
      repetitions = 0;
      interval = 0;
      easeFactor = (easeFactor - 0.2).clamp(minEase, double.infinity);
      state = 'learning';

      return Flashcard(
        id: card.id,
        front: card.front,
        back: card.back,
        code: card.code,
        state: state,
        repetitions: repetitions,
        interval: interval,
        easeFactor: easeFactor,
        lapses: lapses,
        lastReviewed: now,
        dueDate: addMinutes(now, 1),
        difficulty: 'hard',
      );
    }

    // ── HARD (1) ──
    if (rating == 1) {
      easeFactor = (easeFactor - 0.15).clamp(minEase, double.infinity);

      if (state == 'new' || state == 'learning') {
        return Flashcard(
          id: card.id,
          front: card.front,
          back: card.back,
          code: card.code,
          state: 'learning',
          repetitions: repetitions,
          interval: 0,
          easeFactor: easeFactor,
          lapses: lapses,
          lastReviewed: now,
          dueDate: addMinutes(now, 1),
          difficulty: 'hard',
        );
      }

      interval = (interval * 1.2).round().clamp(1, double.maxFinite.toInt());
      repetitions++;
      state = 'review';

      return Flashcard(
        id: card.id,
        front: card.front,
        back: card.back,
        code: card.code,
        state: state,
        repetitions: repetitions,
        interval: interval,
        easeFactor: easeFactor,
        lapses: lapses,
        lastReviewed: now,
        dueDate: addDays(now, interval),
        difficulty: 'medium',
      );
    }

    // ── GOOD (2) ──
    if (rating == 2) {
      if (state == 'new' || state == 'learning') {
        repetitions = 1;
        interval = 1;
        state = 'review';

        return Flashcard(
          id: card.id,
          front: card.front,
          back: card.back,
          code: card.code,
          state: state,
          repetitions: repetitions,
          interval: interval,
          easeFactor: easeFactor,
          lapses: lapses,
          lastReviewed: now,
          dueDate: addDays(now, 1),
          difficulty: 'medium',
        );
      }

      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor).round();
      }
      repetitions++;
      state = checkMastery(interval, easeFactor) ? 'mastered' : 'review';

      return Flashcard(
        id: card.id,
        front: card.front,
        back: card.back,
        code: card.code,
        state: state,
        repetitions: repetitions,
        interval: interval,
        easeFactor: easeFactor,
        lapses: lapses,
        lastReviewed: now,
        dueDate: addDays(now, interval),
        difficulty: state == 'mastered' ? 'easy' : 'medium',
      );
    }

    // ── EASY (3) ──
    easeFactor = easeFactor + 0.15;

    if (state == 'new' || state == 'learning') {
      repetitions = 1;
      interval = 4;
      state = 'review';

      return Flashcard(
        id: card.id,
        front: card.front,
        back: card.back,
        code: card.code,
        state: state,
        repetitions: repetitions,
        interval: interval,
        easeFactor: easeFactor,
        lapses: lapses,
        lastReviewed: now,
        dueDate: addDays(now, 4),
        difficulty: 'easy',
      );
    }

    if (repetitions == 0) {
      interval = 1;
    } else if (repetitions == 1) {
      interval = 6;
    } else {
      interval = (interval * easeFactor * 1.3).round();
    }
    repetitions++;
    state = checkMastery(interval, easeFactor) ? 'mastered' : 'review';

    return Flashcard(
      id: card.id,
      front: card.front,
      back: card.back,
      code: card.code,
      state: state,
      repetitions: repetitions,
      interval: interval,
      easeFactor: easeFactor,
      lapses: lapses,
      lastReviewed: now,
      dueDate: addDays(now, interval),
      difficulty: 'easy',
    );
  }

  /// Format next interval as human readable label (e.g. "1m", "1j", "6j", "24j")
  static String getIntervalLabel(Flashcard card, int rating) {
    final updated = rateCard(card, rating);
    if (updated.state == 'learning' || updated.interval == 0) {
      return '1m';
    }
    return '${updated.interval}j';
  }

  /// Build review queue matching Angular logic (due/overdue + limited new cards)
  static List<Flashcard> buildReviewQueue(List<Flashcard> cards, {int newCardsPerDay = 20}) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final List<Flashcard> overdue = [];
    final List<Flashcard> dueToday = [];
    final List<Flashcard> newCards = [];
    final List<Flashcard> learning = [];

    for (final card in cards) {
      if (card.state == 'new') {
        newCards.push(card);
      } else if (card.state == 'learning') {
        learning.push(card);
      } else if (card.dueDate != null) {
        final due = card.dueDate!;
        if (due.isBefore(startOfDay)) {
          overdue.add(card);
        } else if (!due.isAfter(now)) {
          dueToday.add(card);
        }
      }
    }

    // Sort overdue by oldest lastReviewed / dueDate
    overdue.sort((a, b) {
      final da = a.dueDate ?? DateTime.now();
      final db = b.dueDate ?? DateTime.now();
      return da.compareTo(db);
    });

    // Limit new cards to preserve session sanity
    final limitedNew = newCards.take(newCardsPerDay).toList();

    // Combined queue: Overdue first, then Due Today, then Learning, then New
    return [
      ...overdue,
      ...dueToday,
      ...learning,
      ...limitedNew,
    ];
  }
}

extension _ListPush<T> on List<T> {
  void push(T element) => add(element);
}
