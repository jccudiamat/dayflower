import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/features/tulip/domain/day_reactions.dart';
import 'package:dayflower/features/widget/widget_sync.dart';

/// Reacting to somebody's day used to send a real `classic_tulip` flower.
/// These cover the thing that replaced it, and the join between Dart and the
/// Android layout that it has to survive.

void main() {
  group('the vocabulary', () {
    test('every reaction has an id, an emoji and a label', () {
      for (final r in DayReaction.values) {
        expect(r.id, isNotEmpty);
        expect(r.emoji, isNotEmpty);
        expect(r.label, isNotEmpty);
      }
    });

    test('ids are unique and ascii', () {
      final ids = DayReaction.values.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        // ⚠️ The id is what travels in a URI from the widget to the
        // background isolate. Anything outside ascii is at the mercy of
        // whoever percent-encodes it on the way.
        expect(RegExp(r'^[a-z]+$').hasMatch(id), isTrue, reason: id);
      }
    });

    test('an unknown id is nothing, not a fallback', () {
      // A widget left on an older layout after an update sends an id this
      // build has never heard of. The tap does nothing — the alternative is
      // posting a mystery character into the conversation.
      expect(DayReaction.byId('shrug'), isNull);
      expect(DayReaction.byId(''), isNull);
      expect(DayReaction.byId(null), isNull);
    });

    test('every id round-trips', () {
      for (final r in DayReaction.values) {
        expect(DayReaction.byId(r.id), same(r));
      }
    });
  });

  group('the widget URI', () {
    test('parses the shape the Kotlin builds', () {
      // Mirrors Uri.parse("dayflower://react?r=" + reactionId) in
      // TodaysTulipWidget.renderReactions.
      final uri = Uri.parse('${DayflowerWidgets.reactAction}?r=heart');
      expect(uri.host, 'react');
      expect(
        DayReaction.byId(uri.queryParameters[DayflowerWidgets.reactParam]),
        same(DayReaction.heart),
      );
    });

    test('every reaction survives the round trip', () {
      for (final r in DayReaction.values) {
        final uri = Uri.parse(
          '${DayflowerWidgets.reactAction}?${DayflowerWidgets.reactParam}=${r.id}',
        );
        expect(uri.host, 'react');
        expect(DayReaction.byId(uri.queryParameters['r']), same(r));
      }
    });
  });

  group('the native contract', () {
    // 🔴 Hand-maintained lists on two sides of a language boundary drift,
    // and this one drifts silently: a widget button whose id Dart drops is
    // a button that does nothing, with no error anywhere. So read the other
    // side rather than restating it.

    // 🔴 The five-emoji row became one heart: an outline, red once given,
    // tapped again to take it back. DayLikeReceiver flips it in the
    // widget's data before Dart sends anything, so the key they share is
    // the contract now.
    test('the Kotlin and Dart agree on where hearts are kept', () {
      final kotlin = File(
        'android/app/src/main/kotlin/com/dayflower/app/DayLikeReceiver.kt',
      ).readAsStringSync();
      final key = RegExp(r'const val KEY_HEARTED = "(\w+)"').firstMatch(kotlin);
      expect(key, isNotNull, reason: 'KEY_HEARTED not found in Kotlin');
      expect(key!.group(1), DayflowerWidgets.keyHearted);
      // And the tap it forwards is the one Dart handles.
      expect(kotlin, contains('dayflower://like?id='));
      expect(Uri.parse(DayflowerWidgets.likeAction).host, 'like');
    });

    test('every card has its heart, and the emoji row is gone', () {
      final layout =
          File('android/app/src/main/res/layout/todays_tulip_widget.xml')
              .readAsStringSync();
      expect(layout, contains('@+id/widget_heart'));
      // A rotating day carries its own, so it hearts the day on screen.
      final item = File('android/app/src/main/res/layout/widget_photo_item.xml')
          .readAsStringSync();
      expect(item, contains('@+id/widget_item_heart'));
      for (final r in DayReaction.values) {
        expect(layout, isNot(contains('@+id/widget_react_${r.id}')),
            reason: r.id);
      }
    });

    test('nothing still points at the deleted reply pill', () {
      // It launched the app instead of replying, which is what got it
      // removed. A stray reference would resurrect a dead view id.
      final layout =
          File('android/app/src/main/res/layout/todays_tulip_widget.xml')
              .readAsStringSync();
      final kotlin = File(
        'android/app/src/main/kotlin/com/dayflower/app/TodaysTulipWidget.kt',
      ).readAsStringSync();
      expect(layout.contains('widget_reply_pill'), isFalse);
      expect(kotlin.contains('R.id.widget_reply_pill'), isFalse);
      expect(
        File('android/app/src/main/res/drawable/widget_reply_pill.xml')
            .existsSync(),
        isFalse,
      );
    });
  });
}
