import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Master switch for the dev convenience login. Set false to always see
/// the real Welcome → Sign in flow.
const kDevAutoLogin = true;

/// Signs in with DEV_EMAIL / DEV_PASSWORD from `.env` so the app opens
/// straight on the Nest with real data, skipping the login screen.
///
/// Three independent guards keep this out of anything shipped:
/// [kDebugMode] (never runs in a release build), [kDevAutoLogin], and the
/// presence of the two `.env` keys. It also no-ops when a session already
/// exists, so signing out from Settings still lands you on Welcome for the
/// rest of that run.
Future<void> maybeDevAutoLogin() async {
  if (!kDebugMode || !kDevAutoLogin) return;

  final client = Supabase.instance.client;
  if (client.auth.currentSession != null) return;

  final email = dotenv.env['DEV_EMAIL'];
  final password = dotenv.env['DEV_PASSWORD'];
  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    return;
  }

  try {
    await client.auth.signInWithPassword(email: email, password: password);
    debugPrint('dev auto-login: signed in as $email');
  } catch (e) {
    debugPrint('dev auto-login failed ($email): $e');
  }
}
