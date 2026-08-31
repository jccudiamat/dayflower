import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

/// A year is twelve chapters, one per calendar month.
///
/// Every row in this feature is keyed by (year, month) rather than a date
/// range — a chapter *is* a month by definition, so storing bounds would
/// only create the chance for them to disagree with the label.
class ChapterKey {
  const ChapterKey(this.year, this.month);

  ChapterKey.of(DateTime date) : year = date.year, month = date.month;

  static ChapterKey get current => ChapterKey.of(DateTime.now());

  final int year;
  final int month;

  DateTime get firstDay => DateTime(year, month);
  DateTime get lastDay => DateTime(year, month + 1, 0);

  /// The month has ended, so its review is the thing to write.
  bool get isPast {
    final now = DateTime.now();
    return year < now.year || (year == now.year && month < now.month);
  }

  bool get isCurrent {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  bool get isFuture => !isPast && !isCurrent;

  ChapterKey get previous =>
      month == 1 ? ChapterKey(year - 1, 12) : ChapterKey(year, month - 1);

  @override
  bool operator ==(Object other) =>
      other is ChapterKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// One thing you said you'd do this month. `ownerId` null means it's the
/// two of you; a user id means it's that partner's own — same rule as the
/// finance tables.
class MonthlyGoal {
  const MonthlyGoal({
    required this.id,
    required this.pairId,
    this.ownerId,
    required this.year,
    required this.month,
    required this.title,
    this.note,
    required this.emoji,
    this.doneAt,
    required this.createdBy,
  });

  final String id;
  final String pairId;
  final String? ownerId;
  final int year;
  final int month;
  final String title;
  final String? note;
  final String emoji;
  final DateTime? doneAt;
  final String createdBy;

  bool get isDone => doneAt != null;
  bool get isShared => ownerId == null;
  ChapterKey get key => ChapterKey(year, month);

  factory MonthlyGoal.fromMap(Map<String, dynamic> map) => MonthlyGoal(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        ownerId: map['owner_id'] as String?,
        year: map['year'] as int,
        month: map['month'] as int,
        title: map['title'] as String,
        note: map['note'] as String?,
        emoji: map['emoji'] as String? ?? '🎯',
        doneAt: map['done_at'] == null
            ? null
            : DateTime.parse(map['done_at'] as String).toLocal(),
        createdBy: map['created_by'] as String,
      );
}

/// Something that actually happened, logged as it happens so the review
/// isn't written from memory a month later.
class ChapterMoment {
  const ChapterMoment({
    required this.id,
    required this.pairId,
    required this.year,
    required this.month,
    required this.title,
    this.note,
    required this.emoji,
    this.happenedOn,
    required this.createdBy,
  });

  final String id;
  final String pairId;
  final int year;
  final int month;
  final String title;
  final String? note;
  final String emoji;
  final DateTime? happenedOn;
  final String createdBy;

  ChapterKey get key => ChapterKey(year, month);

  factory ChapterMoment.fromMap(Map<String, dynamic> map) => ChapterMoment(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        year: map['year'] as int,
        month: map['month'] as int,
        title: map['title'] as String,
        note: map['note'] as String?,
        emoji: map['emoji'] as String? ?? '✨',
        happenedOn: map['happened_on'] == null
            ? null
            : DateTime.parse(map['happened_on'] as String),
        createdBy: map['created_by'] as String,
      );
}

/// The review written at the end of the month: what to call it, how it
/// went, and whether you've decided it's finished.
class MonthlyChapter {
  const MonthlyChapter({
    required this.id,
    required this.pairId,
    required this.year,
    required this.month,
    this.title,
    this.review,
    this.rating,
    this.closedAt,
  });

  final String id;
  final String pairId;
  final int year;
  final int month;
  final String? title;
  final String? review;
  final int? rating;
  final DateTime? closedAt;

  bool get isClosed => closedAt != null;
  bool get hasReview => review != null && review!.trim().isNotEmpty;
  ChapterKey get key => ChapterKey(year, month);

  factory MonthlyChapter.fromMap(Map<String, dynamic> map) => MonthlyChapter(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        year: map['year'] as int,
        month: map['month'] as int,
        title: map['title'] as String?,
        review: map['review'] as String?,
        rating: map['rating'] as int?,
        closedAt: map['closed_at'] == null
            ? null
            : DateTime.parse(map['closed_at'] as String).toLocal(),
      );
}

class ChapterRepository {
  ChapterRepository(this._client);
  final SupabaseClient _client;

  /// The whole history in one stream rather than one per month. A couple
  /// generates twelve rows a year — paging it would cost more code than
  /// the rows cost bandwidth, and the year grid needs all of them anyway.
  Stream<List<MonthlyGoal>> watchGoals(String pairId) {
    return _client
        .from('monthly_goals')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(MonthlyGoal.fromMap).toList());
  }

  Stream<List<ChapterMoment>> watchMoments(String pairId) {
    return _client
        .from('chapter_moments')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(ChapterMoment.fromMap).toList());
  }

  Stream<List<MonthlyChapter>> watchChapters(String pairId) {
    return _client
        .from('monthly_chapters')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(MonthlyChapter.fromMap).toList());
  }

  Future<void> saveGoal({
    String? id,
    required String pairId,
    required String? ownerId,
    required ChapterKey key,
    required String title,
    String? note,
    required String emoji,
    required String userId,
  }) async {
    final trimmed = note?.trim();
    final values = {
      'owner_id': ownerId,
      'title': title.trim(),
      'note': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'emoji': emoji,
    };
    if (id == null) {
      await _client.from('monthly_goals').insert({
        ...values,
        'pair_id': pairId,
        'year': key.year,
        'month': key.month,
        'created_by': userId,
      });
    } else {
      await _client.from('monthly_goals').update(values).eq('id', id);
    }
  }

  Future<void> toggleGoal(MonthlyGoal goal) async {
    await _client.from('monthly_goals').update({
      'done_at':
          goal.isDone ? null : DateTime.now().toUtc().toIso8601String(),
    }).eq('id', goal.id);
  }

  Future<void> deleteGoal(String id) async {
    await _client.from('monthly_goals').delete().eq('id', id);
  }

  Future<void> saveMoment({
    String? id,
    required String pairId,
    required ChapterKey key,
    required String title,
    String? note,
    required String emoji,
    DateTime? happenedOn,
    required String userId,
  }) async {
    final trimmed = note?.trim();
    final values = {
      'title': title.trim(),
      'note': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'emoji': emoji,
      'happened_on': happenedOn == null ? null : _dateOnly(happenedOn),
    };
    if (id == null) {
      await _client.from('chapter_moments').insert({
        ...values,
        'pair_id': pairId,
        'year': key.year,
        'month': key.month,
        'created_by': userId,
      });
    } else {
      await _client.from('chapter_moments').update(values).eq('id', id);
    }
  }

  Future<void> deleteMoment(String id) async {
    await _client.from('chapter_moments').delete().eq('id', id);
  }

  /// Writes the review.
  ///
  /// An upsert on `(pair_id, year, month)` rather than read-then-branch:
  /// both partners can be editing the same chapter, and the unique index
  /// from 0012 is what makes the second save an update instead of a
  /// duplicate row.
  Future<void> saveReview({
    required String pairId,
    required ChapterKey key,
    String? title,
    String? review,
    int? rating,
    required bool closed,
    required String userId,
  }) async {
    final trimmedTitle = title?.trim();
    final trimmedReview = review?.trim();
    await _client.from('monthly_chapters').upsert({
      'pair_id': pairId,
      'year': key.year,
      'month': key.month,
      'title':
          (trimmedTitle == null || trimmedTitle.isEmpty) ? null : trimmedTitle,
      'review': (trimmedReview == null || trimmedReview.isEmpty)
          ? null
          : trimmedReview,
      'rating': rating,
      // Closing is a milestone, not a lock — reopening simply clears it.
      'closed_at': closed ? DateTime.now().toUtc().toIso8601String() : null,
      'updated_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'pair_id,year,month');
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  return ChapterRepository(ref.watch(supabaseClientProvider));
});

final monthlyGoalsProvider =
    StreamProvider.autoDispose<List<MonthlyGoal>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(chapterRepositoryProvider).watchGoals(pair.id);
});

final chapterMomentsProvider =
    StreamProvider.autoDispose<List<ChapterMoment>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(chapterRepositoryProvider).watchMoments(pair.id);
});

final monthlyChaptersProvider =
    StreamProvider.autoDispose<List<MonthlyChapter>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(chapterRepositoryProvider).watchChapters(pair.id);
});

/// This month's goals — what the hub tile counts and the Chapters screen
/// opens on.
final currentMonthGoalsProvider =
    Provider.autoDispose<List<MonthlyGoal>>((ref) {
  final key = ChapterKey.current;
  final goals = ref.watch(monthlyGoalsProvider).valueOrNull ?? const [];
  return goals.where((g) => g.key == key).toList();
});

/// The nudge on the Activities hub: the month has ended and its review is
/// still unwritten. Null when there's nothing owing.
final unwrittenChapterProvider = Provider.autoDispose<ChapterKey?>((ref) {
  final previous = ChapterKey.current.previous;
  final chapters = ref.watch(monthlyChaptersProvider).valueOrNull;
  // Still loading: say nothing rather than prompting for a review that
  // may already exist.
  if (chapters == null) return null;
  final written = chapters.any((c) => c.key == previous && c.hasReview);
  if (written) return null;

  // Only prompt for a month you actually lived in the app — a couple who
  // joined this month shouldn't be asked to review the month before.
  final goals = ref.watch(monthlyGoalsProvider).valueOrNull ?? const [];
  final moments = ref.watch(chapterMomentsProvider).valueOrNull ?? const [];
  final lived = goals.any((g) => g.key == previous) ||
      moments.any((m) => m.key == previous);
  return lived ? previous : null;
});
