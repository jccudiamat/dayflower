import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:dayflower/core/services/app_notifications.dart';
import 'package:dayflower/core/services/pulse_alerts.dart';
import 'package:dayflower/features/heartbeat/data/heartbeat_nudge.dart';
import 'package:dayflower/features/heartbeat/data/heartbeat_repository.dart';
import 'package:dayflower/features/heartbeat/data/incoming_heartbeats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 9, 14, 12);
  Heartbeat beat(String id, {String sender = 'partner', int age = 0}) =>
      Heartbeat(
          id: id,
          senderId: sender,
          sentAt: now.subtract(Duration(minutes: age)));
  late IncomingHeartbeats tracker;
  int take(List<Heartbeat> beats, {String pair = 'pair', String user = 'me'}) =>
      tracker
          .take(
              pairId: pair,
              userId: user,
              partnerId: 'partner',
              beats: beats,
              now: now)
          .count;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tracker = IncomingHeartbeats();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Initial history is silent, including recent taps', () {
    expect(take([beat('recent'), beat('old', age: 60)]), 0);
    expect(take([beat('new'), beat('recent')]), 1);
  });

  test('Own taps, duplicates and reconnect history do not notify', () {
    take([]);
    expect(take([beat('a')]), 1);
    expect(take([]), 0);
    expect(
        take([beat('a'), beat('old', age: 10), beat('mine', sender: 'me')]), 0);
  });

  test('New batch uses exact count even when window length stays the same', () {
    take([beat('a'), beat('b')]);
    expect(take([beat('c'), beat('d')]), 2);
    expect(take([beat('c'), beat('d')]), 0);
  });

  test('Changing pair or account establishes a silent baseline', () {
    take([]);
    expect(take([beat('a')], pair: 'other'), 0);
    expect(take([beat('b')], pair: 'other', user: 'other-user'), 0);
    tracker.reset();
    expect(take([beat('c')]), 0);
  });

  test('Copy reports the action without making up a partner message', () {
    expect(PulseAlerts.copy(from: 'Wifey', pulses: 1), (
      title: 'Wifey sent you a heartbeat 💗',
      body: 'Open Dayflower to send one back.',
    ));
    expect(PulseAlerts.copy(from: 'Wifey', pulses: 3).title,
        'Wifey sent you 3 heartbeats 💗');
    expect(PulseAlerts.copy(from: ' ', pulses: 1).title,
        'Your partner sent you a heartbeat 💗');
  });

  /// What actually reaches the phone, and when it stays quiet.
  ///
  /// 🔴 All four of these were wrong at once, and together they made the
  /// heartbeat the least sensible notification in the app: it announced
  /// itself to people already watching it happen, the count went *down* as
  /// more arrived, a burst was ten rounds of lub-dub, and what you had
  /// already seen stayed in the shade.
  group('What lands on the phone', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    final at = DateTime(2026, 9, 14, 12);

    List<MethodCall> shows() =>
        calls.where((c) => c.method == 'show').toList();
    Map<Object?, Object?> android(MethodCall call) =>
        (call.arguments as Map)['platformSpecifics'] as Map<Object?, Object?>;

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      // ⚠️ The count and the mark live in storage so a background isolate
      // can see them, which also means they outlive a test. Clearing the
      // store is the only reliable reset — seen() deliberately leaves the
      // mark alone.
      SharedPreferences.setMockInitialValues({});
      calls.clear();
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('The app being open posts nothing at all', () async {
      // The home screen is already rippling and the phone is in their hand.
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at,
          foreground: true,
          now: at);
      expect(shows(), isEmpty);
      // And nothing is banked, because there is nothing left to tell them.
      expect(await PulseAlerts.waiting(), 0);
    });

    test('The count is everything since you last looked, not the last batch',
        () async {
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 5,
          newestAt: at,
          foreground: false,
          now: at);
      expect(shows().last.arguments['title'], 'Wifey sent you 5 heartbeats 💗');

      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 3,
          newestAt: at.add(const Duration(minutes: 1)),
          foreground: false,
          now: at.add(const Duration(minutes: 1)));
      // 🔴 This said "3" before — the same notification, rewritten to a
      // smaller number while more hearts were arriving.
      expect(shows().last.arguments['title'], 'Wifey sent you 8 heartbeats 💗');
    });

    test('A burst updates the count without sounding again', () async {
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at,
          foreground: false,
          now: at);
      expect(android(shows().last)['onlyAlertOnce'], isFalse,
          reason: 'the first one announces itself');

      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at.add(const Duration(seconds: 2)),
          foreground: false,
          now: at.add(const Duration(seconds: 2)));
      // ⚠️ onlyAlertOnce is the load-bearing flag on Android 8+, where the
      // channel owns the sound and playSound is ignored on an update.
      expect(android(shows().last)['onlyAlertOnce'], isTrue);
      expect(android(shows().last)['playSound'], isFalse);
      expect(shows().last.arguments['title'], 'Wifey sent you 2 heartbeats 💗');
    });

    test('A heart after a long gap is allowed to be heard again', () async {
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at,
          foreground: false,
          now: at);
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at.add(PulseAlerts.reAlertAfter),
          foreground: false,
          now: at.add(PulseAlerts.reAlertAfter));
      expect(android(shows().last)['onlyAlertOnce'], isFalse);
      expect(android(shows().last)['playSound'], isTrue);
    });

    test('Opening the app clears what was waiting', () async {
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 4,
          newestAt: at,
          foreground: false,
          now: at);
      expect(await PulseAlerts.waiting(), 4);

      await PulseAlerts.seen();
      expect(await PulseAlerts.waiting(), 0);
      expect(calls.map((c) => c.method), contains('cancel'));

      // And the next one starts from one, not from five on top of a
      // notification that has already been read.
      calls.clear();
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at.add(const Duration(hours: 1)),
          foreground: false,
          now: at.add(const Duration(hours: 1)));
      expect(shows().last.arguments['title'], 'Wifey sent you a heartbeat 💗');
    });

    test('The same tap down both paths is counted once', () async {
      // 🔴 A backgrounded-but-alive app gets every tap twice: realtime
      // delivers it, and migration 0046 pushes it. Without the mark, one
      // heart read as two and the shade said so.
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at,
          foreground: false,
          now: at);
      expect(await PulseAlerts.waiting(), 1);

      // The push for the same tap, arriving a moment later.
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at,
          foreground: false,
          now: at.add(const Duration(seconds: 3)));
      expect(await PulseAlerts.waiting(), 1);
      expect(shows().last.arguments['title'], 'Wifey sent you a heartbeat 💗');
    });

    test('A genuinely newer tap still gets through', () async {
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at,
          foreground: false,
          now: at);
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at.add(const Duration(seconds: 5)),
          foreground: false,
          now: at.add(const Duration(seconds: 5)));
      expect(await PulseAlerts.waiting(), 2);
    });

    test('Opening the app does not let old taps announce themselves again',
        () async {
      // ⚠️ seen() clears the count, never the mark. If it cleared both, the
      // push for a tap realtime had just handled would arrive after the app
      // was opened and announce it a second time.
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at,
          foreground: false,
          now: at);
      await PulseAlerts.seen();
      calls.clear();

      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 1,
          newestAt: at,
          foreground: false,
          now: at.add(const Duration(minutes: 5)));
      expect(shows(), isEmpty);
      expect(await PulseAlerts.waiting(), 0);
    });

    test('Nothing to report stays silent', () async {
      await PulseAlerts.handleIncoming(
          from: 'Wifey',
          pulses: 0,
          newestAt: at,
          foreground: false,
          now: at);
      expect(shows(), isEmpty);
    });
  });

  group('Device reminder', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      SharedPreferences.setMockInitialValues({});
      tz.initializeTimeZones();
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Successful send cancels without scheduling another reminder',
        () async {
      await HeartbeatNudge.sync(sentToday: true);
      expect(calls.map((c) => c.method), ['cancel']);
    });

    test('Unpaired, signed out or loading data cannot schedule', () async {
      await HeartbeatNudge.sync(sentToday: false, eligible: false);
      expect(calls.map((c) => c.method), ['cancel']);
    });

    test('Reminder uses neutral copy and opens Home', () async {
      await HeartbeatNudge.sync(sentToday: false);
      final scheduled = calls.singleWhere((c) => c.method == 'zonedSchedule');
      expect(scheduled.arguments['title'], HeartbeatNudge.title);
      expect(scheduled.arguments['body'], HeartbeatNudge.body);
      expect(AppNotifications.routeOf(scheduled.arguments['payload']),
          '/app/home');
    });

    test('A cancellation after a schedule wins even if calls overlap',
        () async {
      await Future.wait([
        HeartbeatNudge.sync(sentToday: false),
        HeartbeatNudge.sync(sentToday: true),
      ]);
      expect(calls.last.method, 'cancel');
      expect(calls.where((c) => c.method == 'zonedSchedule').length, 1);
    });

    test('Disabled reminders stay cancelled', () async {
      SharedPreferences.setMockInitialValues(
          {'heartbeat_nudge_enabled': false});
      await HeartbeatNudge.sync(sentToday: false);
      expect(calls.map((c) => c.method), ['cancel']);
    });
  });
}
