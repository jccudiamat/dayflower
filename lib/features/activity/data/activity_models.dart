import 'package:flutter/material.dart';

import '../../../app_router.dart';
import '../../../core/theme/app_colors.dart';

/// One thing that happened in the couple's shared world.
///
/// Deliberately not a notification. A heart or a message wants to interrupt
/// you once and then be gone; an activity is worth reading hours later, it
/// points somewhere, and it reads the same to both of you. See the header of
/// migration 0019 for why that distinction earns its own table.
class Activity {
  const Activity({
    required this.id,
    required this.pairId,
    required this.actorId,
    required this.kind,
    required this.title,
    required this.emoji,
    required this.subjectId,
    required this.meta,
    required this.createdAt,
  });

  final String id;
  final String pairId;

  /// Null when the account is gone, or when the row came from something
  /// other than one of the two people — a SQL-editor write, say.
  final String? actorId;

  final ActivityKind kind;

  /// Rendered at write time by the trigger, so renaming a reminder later
  /// does not rewrite what the feed says happened.
  final String title;
  final String emoji;

  /// The row this points at. Not a foreign key — it means a different table
  /// per [kind].
  final String? subjectId;

  /// Whatever the destination needs beyond the id: the year and month for a
  /// chapter, who a reminder is for. Never rendered directly.
  final Map<String, dynamic> meta;

  final DateTime createdAt;

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        actorId: map['actor_id'] as String?,
        kind: ActivityKind.fromId(map['kind'] as String?),
        title: map['title'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '✨',
        subjectId: map['subject_id'] as String?,
        meta: (map['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );

  bool isMine(String? userId) => actorId != null && actorId == userId;

  /// Where tapping this card should land.
  ///
  /// Resolved here rather than stored on the row. A route in the database
  /// would be frozen at write time: rename a path and every activity ever
  /// logged deep-links somewhere that no longer exists, with nothing to
  /// notice it by. The row keeps the *subject*; the app keeps the map.
  ///
  /// Null means "not tappable" — only for a kind this build has never heard
  /// of, which is what an older app reading a newer database looks like.
  String? get route {
    switch (kind) {
      case ActivityKind.reminderSet:
        return Routes.reminders;

      case ActivityKind.goalSet:
      case ActivityKind.goalDone:
      case ActivityKind.momentAdded:
      case ActivityKind.chapterWritten:
      case ActivityKind.chapterClosed:
        final year = _int('year');
        final month = _int('month');
        // A chapter row missing its month is not worth a dead card — the
        // index is one tap further away and always resolves.
        return (year == null || month == null)
            ? Routes.chapters
            : Routes.chapterFor(year, month);

      case ActivityKind.reunionSet:
        return Routes.events;

      // The camera, not the thread: a strip waiting on you is a thing to
      // *do*, and the shutter is the only place you can do it.
      case ActivityKind.stripWaiting:
        return Routes.flowers;

      // The finished strip was posted as an ordinary photo message, so the
      // thread is where it actually is.
      case ActivityKind.stripDone:
        return Routes.chat;

      case ActivityKind.accountAdded:
      case ActivityKind.budgetSet:
      case ActivityKind.savingGoalSet:
        return Routes.finance;

      case ActivityKind.unknown:
        return null;
    }
  }

  int? _int(String key) {
    final value = meta[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  /// The line under the title: who did it, phrased for whoever is reading.
  ///
  /// [me] is the reader, not the actor — "You set a reminder" and "Sheena
  /// set a reminder" are the same row seen from two sides.
  String sentence({required String? myUserId, required String partnerName}) {
    final mine = isMine(myUserId);
    final who = actorId == null ? 'Someone' : (mine ? 'You' : partnerName);

    // The one kind whose whole point is direction. "Sheena is waiting on
    // your half" is the news; "You are waiting on your half" is nonsense,
    // so the actor's own copy says what they actually did.
    if (kind == ActivityKind.stripWaiting) {
      return mine
          ? 'You started a strip — waiting on them'
          : '$who is waiting on your half';
    }

    return '$who ${kind.verb}';
  }
}

/// What happened, and how the card reads.
///
/// The string ids are the contract with migration 0019's triggers — change
/// one here and the matching `log_activity` call has to move with it.
enum ActivityKind {
  reminderSet('reminder_set', 'Reminder', 'set a reminder', AppColors.amber),
  goalSet('goal_set', 'New goal', 'added a goal', AppColors.sage),
  goalDone('goal_done', 'Goal done', 'ticked off a goal', AppColors.success),
  momentAdded('moment_added', 'Moment', 'saved a moment', AppColors.brand),
  chapterWritten(
      'chapter_written', 'Chapter', 'wrote the review', AppColors.secondary),
  chapterClosed(
      'chapter_closed', 'Chapter closed', 'closed the chapter',
      AppColors.secondary),
  reunionSet('reunion_set', 'Countdown', 'moved the countdown', AppColors.brand),
  stripWaiting('strip_waiting', 'Your turn', 'started a photo strip',
      AppColors.gradientPink),
  stripDone(
      'strip_done', 'Photo strip', 'finished the strip', AppColors.lavender),
  accountAdded('account_added', 'Money', 'added an account', AppColors.sage),
  budgetSet('budget_set', 'Budget', 'set a shared budget', AppColors.sage),
  savingGoalSet(
      'saving_goal_set', 'Goal', 'started saving for something',
      AppColors.amber),

  /// A kind this build has never heard of — a newer app wrote it. Renders
  /// as a plain, untappable card rather than throwing, which is the whole
  /// reason `activities.kind` carries no CHECK constraint.
  unknown('', 'Activity', 'did something', AppColors.muted);

  const ActivityKind(this.id, this.label, this.verb, this.tint);

  /// Matches `activities.kind` in Postgres.
  final String id;

  /// The pill at the top of the card.
  final String label;

  /// Completes "You …" / "Sheena …".
  final String verb;

  /// Drives the card's wash and its pill. Used at low alpha — these are
  /// full-strength palette colours, not fills.
  final Color tint;

  static ActivityKind fromId(String? id) => ActivityKind.values.firstWhere(
        (k) => k.id == id && k != ActivityKind.unknown,
        orElse: () => ActivityKind.unknown,
      );
}
