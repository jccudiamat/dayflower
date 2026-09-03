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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileAsync = ref.watch(userProfileProvider);
  final pairAsync = ref.watch(currentPairProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Gate order: auth → onboarding (profile) → pairing → app.
      // Each stage stays on splash while its data is still loading.
      String gateTarget;
      if (authState.isLoading) {
        gateTarget = Routes.splash;
      } else if (authState.whenOrNull(data: (s) => s.session != null) != true) {
        // Signed out: welcome is home base, login is reachable from it.
        return (loc == Routes.welcome || loc == Routes.login)
            ? null
            : Routes.welcome;
      } else if (profileAsync.isLoading) {
        gateTarget = Routes.splash;
      } else if (profileAsync.valueOrNull == null) {
        gateTarget = Routes.onboarding;
      } else if (pairAsync.isLoading) {
        gateTarget = Routes.splash;
      } else if (pairAsync.valueOrNull?.isLinked != true) {
        gateTarget = Routes.pair;
      } else {
        gateTarget = Routes.home;
      }

      if (gateTarget != Routes.home) {
        return loc == gateTarget ? null : gateTarget;
      }

      // Fully onboarded and paired — keep out of the gate routes only.
      const gateRoutes = {
        Routes.splash,
        Routes.welcome,
        Routes.login,
        Routes.onboarding,
        Routes.pair,
      };
      if (gateRoutes.contains(loc)) return Routes.home;
      return null;
    },
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

