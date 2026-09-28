import 'dart:convert';

import 'package:dayflower/core/services/background_supabase.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A background tap (the heartbeat widget, a heart, a notification's
/// button) acts as whoever is signed in when it is tapped.
///
/// 🔴 Those isolates live as long as the app's process. Supabase set up
/// in one used to keep the session of the first tap: after switching from
/// Wifey to Hubby on a phone, the heartbeat widget went on sending as Wifey.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String key;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    final host = Uri.parse(dotenv.env['SUPABASE_URL']!).host.split('.').first;
    key = 'sb-$host-auth-token';
  });

  /// A stored session for [userId], good for an hour. Nothing checks the
  /// signature on this side, and nothing here reaches the network.
  String session(String userId) {
    String b64(Map<String, Object> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final jwt = '${b64({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${b64({'sub': userId, 'exp': exp, 'role': 'authenticated'})}.sig';
    return jsonEncode({
      'access_token': jwt,
      'expires_in': 3600,
      'expires_at': exp,
      'refresh_token': 'refresh-$userId',
      'token_type': 'bearer',
      'user': {
        'id': userId,
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
        'aud': 'authenticated',
        'created_at': '2026-09-01T00:00:00Z',
      },
    });
  }

  /// What the app's own isolate does on a sign-in: writes the stored
  /// session underneath this isolate's cached copy of it.
  Future<void> appSignsInAs(String? userId) async {
    final store = SharedPreferencesStorePlatform.instance;
    if (userId == null) {
      await store.remove('flutter.$key');
    } else {
      await store.setValue('String', 'flutter.$key', session(userId));
    }
  }

  Future<String?> whoSends() =>
      withBackgroundSupabase<String>((client, userId) async => userId);

  test('each tap is sent as whoever is signed in at the time', () async {
    SharedPreferences.setMockInitialValues({key: session('wifey')});
    // This isolate reads the stored session once, and keeps it cached.
    expect(await whoSends(), 'wifey');

    // Signed out of Wifey and in as Hubby, in the app, on the same phone.
    await appSignsInAs('hubby');
    expect(await whoSends(), 'hubby',
        reason: 'the first tap\'s session must not outlive the switch');

    // Signed out: nothing is sent as anybody.
    await appSignsInAs(null);
    expect(await whoSends(), isNull);
  });

  test('two taps together are run one after the other', () async {
    SharedPreferences.setMockInitialValues({key: session('hubby')});
    final order = <String>[];
    Future<void> tap(String name) => withBackgroundSupabase<void>((_, __) async {
          order.add('$name start');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          order.add('$name end');
        });
    await Future.wait([tap('a'), tap('b')]);
    expect(order, ['a start', 'a end', 'b start', 'b end']);
  });
}
