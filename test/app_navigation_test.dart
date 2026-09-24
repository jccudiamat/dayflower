import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/widgets/app_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Historic deep links keep their destinations and new tab ownership', () {
    // These literals are used outside the app by widgets and notifications.
    expect(Routes.flowers, '/app/flowers');
    expect(Routes.chat, '/app/flowers/chat');
    expect(Routes.events, '/app/events');
    // 🔴 Looking back is Memories. The saved prints live here even though
    // their path hangs off the booth's.
    for (final route in [
      Routes.photos,
      Routes.myDays,
      Routes.boothCollection,
    ]) {
      expect(sectionForLocation(route), AppSection.memories, reason: route);
    }
    // Making things is Dayflower, whatever path they answer on. The booth and
    // the journal kept their original /app/activities/... literals because
    // widgets and notifications point at them.
    for (final route in [
      Routes.booth,
      Routes.boothPending,
      Routes.chapters,
      Routes.chapterFor(2026, 9),
      Routes.blooms,
      Routes.dayflower,
    ]) {
      expect(sectionForLocation(route), AppSection.dayflower, reason: route);
    }
    for (final route in [
      Routes.events,
      Routes.reminders,
      Routes.finance,
      Routes.insights,
      Routes.gifts,
      Routes.travel,
      Routes.activities
    ]) {
      expect(sectionForLocation(route), AppSection.together);
    }
    // The list is the tab; the conversation and its settings stay in it.
    expect(Routes.chats, '/app/chats');
    expect(sectionForLocation(Routes.chats), AppSection.chat);
    expect(sectionForLocation(Routes.chat), AppSection.chat);
    expect(
        sectionForLocation('${Routes.chat}?compose=flowers'), AppSection.chat);
    expect(sectionForLocation(Routes.chatSettings), AppSection.chat);
    expect(sectionForLocation(Routes.blooms), AppSection.dayflower);
    expect(sectionForLocation(Routes.us), AppSection.home);
    expect(sectionForLocation(Routes.notifications), AppSection.home);
    expect(sectionForLocation(Routes.settings), AppSection.home);
  });
}
