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
/// ⚠️ This covers the rule, not the wiring. Reaching the dispatcher itself
/// means pumping the real app, which needs a Supabase instance that nothing
/// in this suite stubs — the same gap that let the Settings dark mode bug
/// ship. The wiring it cannot see is three lines in app.dart: try the router
/// first so pushed screens still pop, then ask this, then give up.
void main() {
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
      expect(backFallbackRoute(route), Routes.home, reason: route);
    }
  });

  test('Home gives up, so the second press closes the app', () {
    // ⚠️ Null is the whole contract: it means "do not handle this", which is
    // what lets the press reach Android. Returning Routes.home here would
    // trap somebody on the first screen with no way out but the task
    // switcher.
    expect(backFallbackRoute(Routes.home), isNull);
  });

  test('the fallback is somewhere the bar can actually show you', () {
    // Home is a real destination in the bar, so backing out of a section
    // lands on a screen whose tab is lit rather than somewhere orphaned.
    expect(sectionForLocation(Routes.home), AppSection.home);
  });
}
