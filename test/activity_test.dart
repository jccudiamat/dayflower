import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/app_router.dart';
import 'package:dayflower/features/activity/data/activity_models.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';

/// The activity feed's two jobs are saying what happened and going where it
/// happened. Both are pure functions of a row, and both fail quietly when
/// they fail — a card that reads "Someone did something" and a tap that
/// lands on the wrong screen look exactly like working software until
/// somebody notices. So they are tested.

const _me = 'user-me';
const _them = 'user-them';

Activity _activity({
  String kind = 'reminder_set',
  String title = 'Take your vitamins',
  String? actor = _them,
  Map<String, dynamic> meta = const {},
}) =>
    Activity.fromMap({
      'id': 'a1',
      'pair_id': 'pair-1',
      'actor_id': actor,
      'kind': kind,
      'title': title,
      'emoji': '⏰',
      'subject_id': 'subject-1',
      'meta': meta,
      'created_at': '2026-09-03T08:00:00.000Z',
    });

void main() {
  group('kinds', () {
    test('every kind the triggers emit is recognised', () {
      // Guards the one contract that spans the language boundary: these
      // strings are written by migration 0019 and read here, and nothing
      // else will notice if the two drift apart.
      const emittedByTriggers = [
        'reminder_set',
        'goal_set',
        'goal_done',
        'moment_added',
        'chapter_written',
        'chapter_closed',
        'reunion_set',
        'strip_waiting',
        'strip_done',
        'account_added',
        'budget_set',
      ];
      for (final id in emittedByTriggers) {
        expect(ActivityKind.fromId(id), isNot(ActivityKind.unknown),
            reason: '$id is emitted by 0019 but has no ActivityKind');
      }
      // And nothing in the enum is unreachable from the database.
      for (final kind in ActivityKind.values) {
        if (kind == ActivityKind.unknown) continue;
        expect(emittedByTriggers, contains(kind.id));
      }
    });

    test('a kind from a newer build degrades instead of throwing', () {
      // `activities.kind` carries no CHECK constraint precisely so a new
      // kind can ship ahead of the app. This is the other half of that.
      final a = _activity(kind: 'somebody_did_a_new_thing');
      expect(a.kind, ActivityKind.unknown);
      expect(a.route, isNull, reason: 'nowhere honest to send anyone');
    });
  });

  group('where a tap lands', () {
    test('a reminder opens reminders', () {
      expect(_activity().route, Routes.reminders);
    });

    test('a chapter activity opens its own month', () {
      final a = _activity(
        kind: 'goal_set',
        meta: const {'year': 2026, 'month': 9},
      );
      expect(a.route, Routes.chapterFor(2026, 9));
    });

    test('a chapter activity with no month falls back to the index', () {
      // The failure this prevents: `/chapters/null/null`, which resolves to
      // *this* month and silently shows the wrong one.
      expect(_activity(kind: 'goal_set').route, Routes.chapters);
    });

    test('year and month survive arriving as strings', () {
      // jsonb round-trips through PostgREST as untyped JSON, and a number
      // that comes back quoted would otherwise fail the int cast and drop
      // the user on the index.
      final a = _activity(
        kind: 'moment_added',
        meta: const {'year': '2026', 'month': '9'},
      );
      expect(a.route, Routes.chapterFor(2026, 9));
    });

    test('a waiting strip opens the camera, a finished one the thread', () {
      // Not the same place, on purpose: one is a thing to do and only the
      // shutter can do it; the other is a photo that already exists.
      expect(_activity(kind: 'strip_waiting').route, Routes.flowers);
      expect(_activity(kind: 'strip_done').route, Routes.chat);
    });
  });

  group('how it reads', () {
    test('the same row says "You" or their name depending on who looks', () {
      final a = _activity(actor: _them);
      expect(a.sentence(myUserId: _me, partnerName: 'Sheena'),
          'Sheena set a reminder');
      expect(a.sentence(myUserId: _them, partnerName: 'Sheena'),
          'You set a reminder');
    });

    test('a lost account is "Someone", never "You"', () {
      final a = _activity(actor: null);
      expect(a.sentence(myUserId: _me, partnerName: 'Sheena'),
          startsWith('Someone'));
      expect(a.isMine(_me), isFalse);
      expect(a.isMine(null), isFalse,
          reason: 'a signed-out reader owns nothing');
    });

    test('a waiting strip inverts rather than reading as nonsense', () {
      // "You are waiting on your half" is the sentence the generic path
      // would produce for the person who started it.
      final a = _activity(kind: 'strip_waiting', actor: _them);
      expect(a.sentence(myUserId: _me, partnerName: 'Sheena'),
          'Sheena is waiting on your half');
      expect(a.sentence(myUserId: _them, partnerName: 'Sheena'),
          contains('waiting on them'));
    });
  });

  group('rows off the wire', () {
    test('a row with nothing optional set still parses', () {
      final a = Activity.fromMap({
        'id': 'a1',
        'pair_id': 'p1',
        'actor_id': null,
        'kind': 'reunion_set',
        'title': 'Manila',
        'emoji': null,
        'subject_id': null,
        'meta': null,
        'created_at': '2026-09-03T08:00:00.000Z',
      });
      expect(a.emoji, '✨');
      expect(a.meta, isEmpty);
      expect(a.route, Routes.events);
    });

    test('created_at comes back local, not UTC', () {
      // The feed prints "2h ago" against DateTime.now(), which is local.
      // A UTC timestamp compared to a local now is off by the offset —
      // in Dubai that is a card claiming to be four hours in the future.
      expect(_activity().createdAt.isUtc, isFalse);
    });
  });

  group('the message line', () {
    test('a photo leads with its caption when it has one', () {
      expect(_message(imagePath: 'p/x.jpg').alertLine, 'Shared their day 📷');
      expect(_message(imagePath: 'p/x.jpg', note: 'at the beach').alertLine,
          contains('at the beach'));
    });

    test('a text message is just the text', () {
      expect(_message(note: 'miss you').alertLine, 'miss you');
    });

    test('a whitespace-only note is treated as no note', () {
      // Otherwise the notification body is a blank line, which on Android
      // renders as a title with nothing under it.
      expect(_message(imagePath: 'p/x.jpg', note: '   ').alertLine,
          'Shared their day 📷');
    });

    test('a flower id the catalog has never heard of still reads', () {
      // Retired flowers, or one written by a newer build. FlowerCatalog
      // answers an unknown id with the classic tulip rather than null, so
      // the line names a flower instead of crashing the notification for
      // what is otherwise a perfectly good message.
      final line = _message(flowerType: 'not-a-real-flower').alertLine;
      expect(line, startsWith('Sent you a'));
      expect(line, isNot(contains('null')));
    });

    test('a captioned flower keeps both halves', () {
      final line = _message(flowerType: 'tulip', note: 'for you').alertLine;
      expect(line, contains('for you'));
      expect(line, startsWith('Sent you a'));
    });
  });
}

FlowerMessage _message({
  String? flowerType,
  String? imagePath,
  String? note,
}) =>
    FlowerMessage(
      id: 'm1',
      pairId: 'pair-1',
      senderId: _them,
      flowerType: flowerType,
      imagePath: imagePath,
      note: note,
      sentAt: DateTime(2026, 9, 3),
    );

