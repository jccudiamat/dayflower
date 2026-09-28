import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase for code Android runs in a background isolate: a widget's tap
/// (a heartbeat, a heart), a notification's button (snooze, done, decline).
/// [run] gets the client and who it is signed in as, or is never called
/// when nobody is signed in.
///
/// 🔴 **Signed in as whoever is signed in now, every time.** Those isolates
/// are not one-offs: home_widget and flutter_local_notifications each keep
/// their background engine for as long as the app's process lives, and
/// every later tap runs in the same one. Supabase.initialize there used to
/// run once, on the first tap, with the session of whoever was signed in
/// then, and every call after it was "already initialized, skipping". So
/// after switching accounts on a phone, the heartbeat widget went on
/// sending as the account signed in before: Hubby tapped it and Wifey's
/// heartbeat arrived. And that client kept refreshing its tokens and
/// writing them back to the same stored session, which could have put the
/// old account back into the app on its next start.
///
/// So each run reads the stored session fresh (SharedPreferences caches it
/// per isolate, so it is reloaded first), signs in with that, and closes the
/// client again when it is done: nothing is left behind to go stale or to
/// refresh on its own. Runs one at a time, because two taps close together
/// would otherwise close each other's client.
Future<T?> withBackgroundSupabase<T>(
  Future<T?> Function(SupabaseClient client, String userId) run,
) {
  final next = _queue.then((_) => _once(run));
  _queue = next.then((_) {}, onError: (_) {});
  return next;
}

Future<void> _queue = Future.value();

Future<T?> _once<T>(
  Future<T?> Function(SupabaseClient client, String userId) run,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ Already initialized means it is not ours (ours is always closed
  // before a run returns): this is the app's own isolate, whose client is
  // the signed-in one and must not be closed from here.
  if (_alreadyInitialized()) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;
    return run(client, user.id);
  }

  await dotenv.load(fileName: '.env');
  // The session the app has now, not the one this isolate first read.
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null; // signed out
    return await run(client, user.id);
  } finally {
    await Supabase.instance.dispose();
  }
}

/// Supabase.instance asserts that it is initialized, in debug builds.
bool _alreadyInitialized() {
  try {
    return Supabase.instance.isInitialized;
  } catch (_) {
    return false;
  }
}
