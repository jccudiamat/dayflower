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
/// ⚠️ Null means "not handled", and it is the whole contract. The press then
/// falls through to the Activity, which is both how the app closes and — via
/// the dispatcher asking for it — how a live call becomes the floating
/// window. Answering a press here keeps it inside Dart and costs both.
///
/// ⚠️ These cover the rule, not the wiring around it. Reaching the
/// dispatcher means pumping the real app, which needs a Supabase instance
/// nothing in this suite stubs. What the rule cannot see: that a live call
/// asks for picture-in-picture only *after* this returns null, and that
/// MainActivity hands every back press to Flutter before deciding anything.
void main() {
  test('every section falls back to Home', () {
    for (final route in [
      Routes.chats,
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

  test('the conversation falls back to the Chats list, not Home', () {
    // Opened from a notification there is nothing under it. WhatsApp's
    // back goes to the list of chats, and so does this; the list's own
    // back then goes Home.
    expect(backFallbackRoute(Routes.chat), Routes.chats);
    expect(backFallbackRoute('${Routes.chat}?compose=flowers'), Routes.chats);
    expect(backFallbackRoute(Routes.chatSettings), Routes.chats);
  });

  test('Home gives up, so the press can leave the app', () {
    // 🔴 Returning Routes.home here would trap somebody on the first screen
    // with no way out but the task switcher — and, during a call, would stop
    // the floating window ever appearing.
    expect(backFallbackRoute(Routes.home), isNull);
  });

  test('the call screen is not special-cased, because it pops', () {
    // ⚠️ The call screen is reached with push(), so the router pops it long
    // before the fallback is consulted — that is what makes the phone's back
    // behave like the call screen's own back, floating the call inside the
    // app and returning to the conversation. If this ever starts being
    // reached, something has made the call screen a go() destination and the
    // in-app float will have quietly stopped working.
    expect(backFallbackRoute(Routes.call), Routes.home);
  });

  test('the fallback is somewhere the bar can actually show you', () {
    expect(sectionForLocation(Routes.home), AppSection.home);
  });
}
