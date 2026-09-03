import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/providers/supabase_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/design_tokens.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/welcome_screen.dart';
import 'features/activities/presentation/screens/activities_screen.dart';
import 'features/activity/presentation/screens/activity_feed_screen.dart';
import 'features/booth/presentation/screens/booth_screen.dart';
import 'features/chapters/presentation/screens/chapter_detail_screen.dart';
import 'features/chapters/presentation/screens/chapters_screen.dart';
import 'features/dates/presentation/screens/events_screen.dart';
import 'features/finance/presentation/screens/finance_screen.dart';
import 'features/finance/presentation/screens/insights_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/onboarding/data/user_repository.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/pairing/data/pair_repository.dart';
import 'features/pairing/presentation/screens/pairing_screen.dart';
import 'features/reminders/presentation/screens/alarm_screen.dart';
import 'features/reminders/presentation/screens/reminders_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/tulip/presentation/screens/flowers_screen.dart';
import 'features/tulip/presentation/screens/messages_screen.dart';
import 'features/us/presentation/screens/us_screen.dart';

// ── Route names ──────────────────────────────
// Tab labels: Home · Flowers · Events · Activities.
// Feature folders keep their original names (tulip/dates/booth).
class Routes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const pair = '/pair';
  static const shell = '/app';
  static const home = '/app/home';

  /// The Camera tab, despite the name — see messages_screen.dart. The path
  /// predates the camera getting a tab of its own and is kept so existing
  /// deep links keep resolving.
  static const flowers = '/app/flowers';

  /// The Flowers tab — the conversation itself.
  ///
  /// Still a path under `flowers` for deep-link compatibility, but no longer
  /// a sub-route of anything: `flowers` is the Camera tab now and these two
  /// are siblings. Nothing may navigate to `flowers` meaning "the chat".
  static const chat = '/app/flowers/chat';

  /// The couple's own page — both of you, the numbers, and the date
  /// everything else is derived from. A sub-route of Home, like the
  /// activity feed: it is reached from the pair pill on Home's top bar, so
  /// the Home tab should stay lit inside it.
  static const us = '/app/home/us';

  /// Everything that has happened, in one list. A sub-route of Home, not
  /// of the Activities hub: it is reached from the Home section, and the
  /// hub is a menu of features rather than a log of them.
  static const activityFeed = '/app/home/activity';
  static const events = '/app/events';
  static const activities = '/app/activities';

  /// Sub-route of the Activities hub — the tab itself is a menu, not the
  /// booth. Nested under `activities` so AppBottomNav keeps the tab lit.
  static const booth = '/app/activities/booth';

  /// The rest of the Activities hub. All nested under `activities` for the
  /// same reason as the booth — move one to a top-level path and the tab
  /// silently goes dark inside it.
  static const reminders = '/app/activities/reminders';
  static const finance = '/app/activities/finance';

  /// The month, read back to you, and exportable as one image. Nested under
  /// finance so the Activities tab stays lit inside it.
  static const insights = '/app/activities/finance/insights';
  static const chapters = '/app/activities/chapters';

  /// One month of the year. Path params rather than a query string so the
  /// route reads as what it is: `/chapters/2026/8`.
  static const chapter = '/app/activities/chapters/:year/:month';
  static String chapterFor(int year, int month) =>
      '/app/activities/chapters/$year/$month';

  static const settings = '/app/settings';

  /// The ringing screen for a reminder alarm. **Top-level, outside the app
  /// shell on purpose** — an alarm is not a place you navigated to, it is an
  /// interruption with exactly two ways out (Snooze, Done), and rendering
  /// the bottom nav under it would offer a third.
  static const alarm = '/alarm/:id';
  static String alarmFor(String reminderId) => '/alarm/$reminderId';
}

/// Whether an async gate input is safe to act on.
///
/// ⚠️ **A present value and a *trustworthy* value are not the same thing,
/// and the difference is a null.**
///
/// Riverpod keeps the previous value while a provider refreshes, which is
/// what lets a nickname edit leave the router alone — a profile that is
/// merely reloading is still that person. But `userProfileProvider` also
/// legitimately resolves to **null** when nobody is signed in yet, and that
/// null survives into the refresh that follows signing in. For a moment the
/// gate then holds "we have an answer, and the answer is: no profile" — and
/// routes to the onboarding wizard, for somebody who onboarded a year ago.
///
/// Observed: after dev auto-login the router settled on `/onboarding` while
/// Home was on screen. So a non-null value is believed even mid-refresh; a
/// null is only believed once it has stopped moving.
bool isGateValueUsable(AsyncValue<Object?> value) =>
    value.hasValue && (value.valueOrNull != null || !value.isLoading);

/// Where the gates say you belong, or null to stay put.
///
/// Extracted from the router and taking plain booleans rather than
/// `AsyncValue`s, because the distinction the whole thing turns on — *known*
/// versus *loading* — is invisible when it is buried in `isLoading`, and
/// that is exactly where this went wrong.
///
/// ⚠️ **"Loading" is not the same as "unknown".** Riverpod reports
/// `isLoading == true` while a provider *refreshes*, even though it is
/// holding a perfectly good previous value. Reading that as "we don't know
/// who this is yet" is what sent the app to the splash screen every time
/// somebody changed their nickname. Only [authKnown] / [profileKnown] /
/// [pairKnown] — which mean "has a value at all" — may gate on loading.
String? gateRedirect({
  required String location,
  required bool authKnown,
  required bool signedIn,
  required bool profileKnown,
  required bool hasProfile,
  required bool pairKnown,
  required bool isLinked,
}) {
  // Gate order: auth → onboarding (profile) → pairing → app.
  String gateTarget;
  if (!authKnown) {
    gateTarget = Routes.splash;
  } else if (!signedIn) {
    // Signed out: welcome is home base, login is reachable from it.
    return (location == Routes.welcome || location == Routes.login)
        ? null
        : Routes.welcome;
  } else if (!profileKnown) {
    gateTarget = Routes.splash;
  } else if (!hasProfile) {
    gateTarget = Routes.onboarding;
  } else if (!pairKnown) {
    gateTarget = Routes.splash;
  } else if (!isLinked) {
    gateTarget = Routes.pair;
  } else {
    gateTarget = Routes.home;
  }

  if (gateTarget != Routes.home) {
    return location == gateTarget ? null : gateTarget;
  }

  // Fully onboarded and paired — keep out of the gate routes only, and
  // otherwise leave the user exactly where they are. This is the branch
  // that has to stay quiet: it runs again on every profile refresh, and
  // anything it returns here is a navigation the user did not ask for.
  const gateRoutes = {
    Routes.splash,
    Routes.welcome,
    Routes.login,
    Routes.onboarding,
    Routes.pair,
  };
  if (gateRoutes.contains(location)) return Routes.home;
  return null;
}

/// 🔴 **Do not replace these `ref.watch` calls with `ref.listen`.**
///
/// Build 19 did exactly that — the router was built once and refreshed
/// through a `ChangeNotifier` fed by `ref.listen`, which is the pattern the
/// go_router/Riverpod docs describe — and it **bricked the app on the
/// splash screen**. `userProfileProvider` sat in `AsyncLoading` forever, so
/// the gate correctly waited for an answer that never came. Nothing errored
/// and nothing timed out; the phone just never got past "two lips, one
/// garden".
///
/// The `ref.listen` subscription observes the provider but does not drive
/// it the way a watch does, so the chain
/// `authState → currentUserIdProvider → userProfileProvider` went dirty on
/// sign-in and was never recomputed. Watching is what makes it resolve.
///
/// ⚠️ **The cost, knowingly accepted:** every change to auth, profile or
/// pair rebuilds this provider and therefore builds a **new `GoRouter`** —
/// a new `routerConfig` for `MaterialApp.router`, so the Navigator and its
/// history are rebuilt from `initialLocation`. That is why saving a
/// nickname flashes the splash screen. A cosmetic flash on an app that
/// starts beats no flash on an app that doesn't.
///
/// If you fix that flash, keep the watches and hoist only the `GoRouter`
/// instance so it is built once — and **verify the app still boots from
/// cold** before shipping it. That is the check build 19 skipped.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileAsync = ref.watch(userProfileProvider);
  final pairAsync = ref.watch(currentPairProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) => gateRedirect(
      location: state.matchedLocation,
      // Not `!isLoading`: a refreshing provider still knows the answer, and
      // treating it as unknown is what sent this to the splash on every
      // profile edit. Not plain `hasValue` either — see isGateValueUsable
      // for the null that hides in there.
      authKnown: authState.hasValue,
      signedIn: authState.valueOrNull?.session != null,
      profileKnown: isGateValueUsable(profileAsync),
      hasProfile: profileAsync.valueOrNull != null,
      pairKnown: isGateValueUsable(pairAsync),
      isLinked: pairAsync.valueOrNull?.isLinked == true,
    ),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.pair,
        builder: (_, __) => const PairingScreen(),
      ),
      GoRoute(
        path: Routes.alarm,
        builder: (_, state) =>
            AlarmScreen(reminderId: state.pathParameters['id'] ?? ''),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(path: Routes.us, builder: (_, __) => const UsScreen()),
          GoRoute(
              path: Routes.activityFeed,
              builder: (_, __) => const ActivityFeedScreen()),
          GoRoute(
              path: Routes.flowers,
              builder: (_, __) => const MessagesScreen()),
          GoRoute(path: Routes.chat, builder: (_, __) => const FlowersScreen()),
          GoRoute(
              path: Routes.events, builder: (_, __) => const EventsScreen()),
          GoRoute(
              path: Routes.activities,
              builder: (_, __) => const ActivitiesScreen()),
          GoRoute(path: Routes.booth, builder: (_, __) => const BoothScreen()),
          GoRoute(
              path: Routes.reminders,
              builder: (_, __) => const RemindersScreen()),
          GoRoute(
              path: Routes.finance, builder: (_, __) => const FinanceScreen()),
          GoRoute(
              path: Routes.insights,
              builder: (_, __) => const InsightsScreen()),
          GoRoute(
              path: Routes.chapters,
              builder: (_, __) => const ChaptersScreen()),
          GoRoute(
            path: Routes.chapter,
            builder: (_, state) {
              // A hand-typed or stale URL falls back to this month rather
              // than crashing on a null parse.
              final now = DateTime.now();
              final year =
                  int.tryParse(state.pathParameters['year'] ?? '') ?? now.year;
              final month =
                  int.tryParse(state.pathParameters['month'] ?? '') ?? now.month;
              return ChapterDetailScreen(
                year: year,
                month: month.clamp(1, 12),
              );
            },
          ),
          GoRoute(
              path: Routes.settings,
              builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

// ── Splash — waits for auth to resolve ───────
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching this is enough — router redirect fires automatically
    ref.watch(authStateProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.splash),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Dayflower', style: AppText.display(Colors.white)),
              const SizedBox(height: AppSpace.xs),
              Text(
                'two lips, one garden',
                style: AppText.note(Colors.white.withValues(alpha: .85)),
              ),
              const SizedBox(height: AppSpace.lg),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white.withValues(alpha: .8),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shell ──────────────────────────────────────
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext ctx) => Scaffold(body: child);
}

