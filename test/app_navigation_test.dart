import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/widgets/app_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Historic deep links keep their destinations and new tab ownership', () {
    // These literals are used outside the app by widgets and notifications.
    expect(Routes.flowers, '/app/flowers');
    expect(Routes.chat, '/app/flowers/chat');
    expect(Routes.events, '/app/events');
    for (final route in [
      Routes.photos,
      Routes.myDays,
      Routes.booth,
      Routes.chapters,
      Routes.chapterFor(2026, 9)
    ]) {
      expect(sectionForLocation(route), AppSection.memories);
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
    expect(
        sectionForLocation('${Routes.chat}?compose=flowers'), AppSection.chat);
    expect(sectionForLocation(Routes.chatSettings), AppSection.chat);
    expect(sectionForLocation(Routes.blooms), AppSection.dayflower);
    expect(sectionForLocation(Routes.us), AppSection.home);
    expect(sectionForLocation(Routes.notifications), AppSection.home);
    expect(sectionForLocation(Routes.settings), AppSection.home);
  });
}
