import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

/// How a reminder comes back around. Resolved on the device — the row only
/// records the rule, so changing what "monthly" means never needs a
/// migration.
enum ReminderRepeat {
  none('Once'),
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly');

  const ReminderRepeat(this.label);
  final String label;

  static ReminderRepeat fromName(String? name) =>
      ReminderRepeat.values.firstWhere(
        (r) => r.name == name,
        orElse: () => ReminderRepeat.none,
      );

  /// The next time this fires after [from], or null if it doesn't repeat.
  ///
  /// Monthly clamps to the end of a short month: a reminder set for the
  /// 31st lands on the 28th in February rather than rolling into March,
  /// which is what a bare `DateTime(y, 2, 31)` would silently do.
  DateTime? nextAfter(DateTime from) {
    switch (this) {
      case ReminderRepeat.none:
        return null;
      case ReminderRepeat.daily:
        return from.add(const Duration(days: 1));
      case ReminderRepeat.weekly:
        return from.add(const Duration(days: 7));
      case ReminderRepeat.monthly:
        final month = from.month == 12 ? 1 : from.month + 1;
        final year = from.month == 12 ? from.year + 1 : from.year;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(
          year,
          month,
          from.day > lastDay ? lastDay : from.day,
          from.hour,
          from.minute,
        );
    }
  }
}

/// A nudge one partner sets for the other — or for themselves.
///
/// [createdBy] and [forUser] are separate on purpose: "remind Sheena to
/// take her vitamins" is the whole point of the feature, and it needs an
/// author and a recipient that can differ.
class Reminder {
  const Reminder({
    required this.id,
    required this.pairId,
    required this.createdBy,
    required this.forUser,
    required this.title,
    this.note,
    required this.emoji,
    required this.remindAt,
    required this.repeat,
    this.alarm = true,
    this.doneAt,
  });

  final String id;
  final String pairId;
  final String createdBy;
  final String forUser;
  final String title;
  final String? note;
  final String emoji;
  final DateTime remindAt;
  final ReminderRepeat repeat;

  /// Ring like an alarm clock — alarm-stream sound, full screen over the
  /// lock screen, and it keeps going until snoozed or dismissed. False is
  /// an ordinary quiet notification.
  final bool alarm;

  final DateTime? doneAt;

  bool get isDone => doneAt != null;
  bool get repeats => repeat != ReminderRepeat.none;

  /// Past its time and still not ticked off.
  bool get isOverdue => !isDone && remindAt.isBefore(DateTime.now());

  bool isFor(String? userId) => userId != null && forUser == userId;
  bool isFromPartner(String? userId) => userId != null && createdBy != userId;

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        createdBy: map['created_by'] as String,
        forUser: map['for_user'] as String,
        title: map['title'] as String,
        note: map['note'] as String?,
        emoji: map['emoji'] as String? ?? '⏰',
        remindAt: DateTime.parse(map['remind_at'] as String).toLocal(),
        repeat: ReminderRepeat.fromName(map['repeat_rule'] as String?),
        alarm: map['alarm'] as bool? ?? true,
        doneAt: map['done_at'] == null
            ? null
            : DateTime.parse(map['done_at'] as String).toLocal(),
      );
}

class ReminderRepository {
  ReminderRepository(this._client);
  final SupabaseClient _client;

  /// The pair's reminders, **soonest first**, live-updating.
  ///
  /// `ascending: true` is spelled out because `.order()` descends by
  /// default — a bare `.order('remind_at')` would put next year's dentist
  /// appointment above tonight's medication. See the ordering warning in
  /// PROGRESS.md.
  Stream<List<Reminder>> watchPairReminders(String pairId) {
    return _client
        .from('reminders')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('remind_at', ascending: true)
        .map((rows) => rows.map(Reminder.fromMap).toList());
  }

  Future<Reminder> create({
    required String pairId,
    required String createdBy,
    required String forUser,
    required String title,
    String? note,
    required String emoji,
    required DateTime remindAt,
    required ReminderRepeat repeat,
    required bool alarm,
  }) async {
    final row = await _client
        .from('reminders')
        .insert({
          'pair_id': pairId,
          'created_by': createdBy,
          'for_user': forUser,
          'title': title.trim(),
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          'emoji': emoji,
          'remind_at': remindAt.toUtc().toIso8601String(),
          'repeat_rule': repeat.name,
          'alarm': alarm,
        })
        .select()
        .single();
    return Reminder.fromMap(row);
  }

  Future<Reminder> update(
    String id, {
    required String forUser,
    required String title,
    String? note,
    required String emoji,
    required DateTime remindAt,
    required ReminderRepeat repeat,
    required bool alarm,
  }) async {
    final trimmed = note?.trim();
    final row = await _client
        .from('reminders')
        .update({
          'for_user': forUser,
          'title': title.trim(),
          'note': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
          'emoji': emoji,
          'remind_at': remindAt.toUtc().toIso8601String(),
          'repeat_rule': repeat.name,
          'alarm': alarm,
          // Editing a ticked-off reminder puts it back on the list — you
          // changed the time because you want it to happen again.
          'done_at': null,
        })
        .eq('id', id)
        .select()
        .single();
    return Reminder.fromMap(row);
  }

  /// Ticks a reminder off.
  ///
  /// A repeating one is **rolled forward instead of closed**: marking
  /// "vitamins, daily" done should mean done *today*, not done forever.
  /// The next occurrence is computed from the time it was due rather than
  /// from now, so ticking it off late doesn't drag the schedule later.
  Future<void> markDone(Reminder reminder) async {
    if (reminder.repeats) {
      var next = reminder.repeat.nextAfter(reminder.remindAt)!;
      // Catch up if it sat un-ticked for several cycles.
      final now = DateTime.now();
      while (next.isBefore(now)) {
        next = reminder.repeat.nextAfter(next)!;
      }
      await _client.from('reminders').update({
        'remind_at': next.toUtc().toIso8601String(),
        'done_at': null,
      }).eq('id', reminder.id);
      return;
    }
    await _client.from('reminders').update({
      'done_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reminder.id);
  }

  /// Pushes a ringing alarm out by [by] and leaves everything else alone.
  ///
  /// Snooze moves `remind_at` rather than storing a separate
  /// `snoozed_until`: one column is the time this thing is next due, and a
  /// second one would immediately raise the question of which wins.
  ///
  /// The cost is real and worth knowing: snoozing a **repeating** reminder
  /// shifts the series, so snoozing a 7am daily alarm by 9 minutes makes it
  /// a 7:09 daily alarm. Ticking it off with [markDone] is what puts a
  /// repeating one back on its original schedule.
  Future<void> snooze(Reminder reminder, Duration by) async {
    final next = DateTime.now().add(by);
    await _client.from('reminders').update({
      'remind_at': next.toUtc().toIso8601String(),
      'done_at': null,
    }).eq('id', reminder.id);
  }

  Future<void> reopen(String id) async {
    await _client.from('reminders').update({'done_at': null}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('reminders').delete().eq('id', id);
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(supabaseClientProvider));
});

/// Every reminder in the pair, soonest first. Empty until paired.
final remindersProvider = StreamProvider.autoDispose<List<Reminder>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(reminderRepositoryProvider).watchPairReminders(pair.id);
});

/// The ones aimed at me and still open — what the scheduler turns into
/// notifications, and where the hub tile's count comes from.
final myOpenRemindersProvider = Provider.autoDispose<List<Reminder>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final all = ref.watch(remindersProvider).valueOrNull ?? const [];
  return all.where((r) => r.isFor(userId) && !r.isDone).toList();
});

/// Mine, due now or already past — the badge on the Activities hub tile.
final dueReminderCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(myOpenRemindersProvider).where((r) => r.isOverdue).length;
});
