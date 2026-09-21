import 'package:dayflower/app.dart';
import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/widgets/app_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';

/// 🔴 **The back button used to close the app from anywhere in it.**
///
/// The bottom bar navigates with `go()`, which replaces the stack instead of
/// growing it, so a tab has no history behind it: the router had nothing to
/// pop and the press went past the app and out to the launcher. One tap on
/// Memories and one on back, and Dayflower was gone.
///
/// 🔴 **And the fix nearly took the floating call window with it.** A back
/// press only reaches `MainActivity.onBackPressed` when Dart declines it,
/// and that is the one place a live call turns into a picture-in-picture
/// window over the launcher. Answering every press here would have left that
/// native path unreachable — with nothing in Dart failing to say so.
///
/// ⚠️ These cover the rule, not the wiring. Reaching the dispatcher means
/// pumping the real app, which needs a Supabase instance nothing in this
/// suite stubs.
void main() {
  group('with no call up', () {
    test('every section falls back to Home', () {
      for (final route in [
        Routes.chat,
        Routes.dayflower,
        Routes.memories,
        Routes.together,
        Routes.blooms,
        Routes.booth,
        Routes.settings,
        Routes.notifications,
      ]) {
        expect(backFallbackRoute(route, callActive: false), Routes.home,
            reason: route);
      }
    });

    test('Home gives up, so the press closes the app', () {
      // ⚠️ Null is the contract: it means "not handled", which is what lets
      // the press reach Android. Returning Routes.home here would trap
      // somebody on the first screen with no way out but the task switcher.
      expect(backFallbackRoute(Routes.home, callActive: false), isNull);
    });
  });

  group('with a call up', () {
    test('nothing is intercepted, from any screen', () {
      // 🔴 Every one of these must be null. Handling any of them keeps the
      // press inside Dart, and the call can no longer become the floating
      // window — which is a native behaviour, so no Dart test but this one
      // would notice.
      for (final route in [
        Routes.home,
        Routes.chat,
        Routes.call,
        Routes.memories,
        Routes.together,
        Routes.dayflower,
      ]) {
        expect(backFallbackRoute(route, callActive: true), isNull,
            reason: route);
      }
    });

    test('a call changes the answer for the same screen', () {
      // The two rules genuinely disagree, which is the point of the flag.
      expect(backFallbackRoute(Routes.memories, callActive: false),
          Routes.home);
      expect(backFallbackRoute(Routes.memories, callActive: true), isNull);
    });
  });

  test('the fallback is somewhere the bar can actually show you', () {
    expect(sectionForLocation(Routes.home), AppSection.home);
  });
}
