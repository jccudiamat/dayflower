import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'app.dart';
import 'core/dev/dev_login.dart';
import 'core/services/app_notifications.dart';
import 'core/services/partner_alerts.dart';
import 'core/services/pulse_alerts.dart';
import 'features/heartbeat/data/heartbeat_nudge.dart';
import 'features/reminders/data/reminder_scheduler.dart';
import 'features/updates/data/update_alerts.dart';
import 'features/widget/widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IANA timezone database for the dual clocks
  tzdata.initializeTimeZones();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialise Supabase
  await Supabase.initialize(
    url:     dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  // Home-screen widget bridge (no-op off Android/iOS).
  await DayflowerWidgets.init();

  // One initialize() for the whole app, before any feature's channel.
  //
  // The plugin is a singleton, so initialize() is global state and the last
  // caller wins — which is why the tap handlers cannot belong to any one
  // feature. Reminder alarms need them for their Snooze / Done buttons.
  // `reminderActionBackground` must stay a top-level function: it runs in a
  // separate isolate that Android spawns with the app dead.
  await AppNotifications.init(
    onResponse: handleNotificationTap,
    onBackgroundResponse: reminderActionBackground,
  );

  // Notification channel for incoming heartbeats (no-op off Android/iOS).
  await PulseAlerts.init();

  // Reminders get two of their own — one that rings like an alarm clock and
  // one that stays quiet. Android freezes a channel's sound and importance
  // at creation, so neither can share with heartbeats or with each other.
  await ReminderScheduler.init();

  // Its own channel again — a "you haven't tapped yet" nudge is a different
  // kind of interruption from a pulse or a partner-set reminder.
  await HeartbeatNudge.init();

  // Two more: messages and photos want a heads-up banner, shared activity
  // wants to sit quietly in the shade. Android freezes importance at
  // channel creation, so that difference has to be two channels — and it
  // is also what lets either be retuned from Settings without the other.
  await PartnerAlerts.init();

  // And one more for a published build, at low importance. An update is
  // never urgent enough to interrupt anything.
  await UpdateAlerts.init();

  // Debug-only shortcut past the login screen. No-op in release builds.
  await maybeDevAutoLogin();

  runApp(
    // Device frames for checking layout across phone sizes — iPhone SE up to
    // Pixel 8 Pro — without a device for each. `kDebugMode` is what keeps the
    // toolbar out of release builds; DevicePreview with enabled:false is a
    // pass-through, so the release tree is exactly what it was before.
    //
    // ⚠️ It renders whatever engine you're on — Chrome here. iPhone frames
    // give you iOS *dimensions*, never iOS rendering. Still no substitute for
    // a real device before shipping.
    DevicePreview(
      enabled: kDebugMode,
      // Riverpod wraps the entire app
      builder: (_) => const ProviderScope(
        child: DayflowerApp(),
      ),
    ),
  );
}