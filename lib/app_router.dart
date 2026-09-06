import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/providers/supabase_provider.dart';
import 'core/theme/app_colors.dart';
import 'features/calls/data/call_pip.dart';
import 'core/util/clamp_offset.dart';
import 'core/theme/design_tokens.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/welcome_screen.dart';
import 'features/activities/presentation/screens/activities_screen.dart';
import 'features/activity/presentation/screens/activity_feed_screen.dart';
import 'features/booth/presentation/screens/booth_screen.dart';
import 'features/calls/data/call_repository.dart';
import 'features/calls/domain/call.dart';
import 'features/calls/domain/call_notifier.dart';
import 'features/calls/presentation/screens/call_screen.dart';
import 'features/calls/presentation/widgets/call_video.dart';
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
import 'features/tulip/data/flower_repository.dart';
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

  /// A call in progress. **Top-level, outside the app shell**, for the same
  /// reason as the alarm: a call is not a tab you can wander away from, and
  /// drawing the bottom nav under it would offer four ways out of a screen
  /// that has exactly one — End.
  ///
  /// Carries no id. The call lives in `callNotifierProvider`, so the route
  /// is a door onto whatever call this phone is in; a path parameter would
  /// let a stale deep link open a screen for a call that ended yesterday.
  static const call = '/call';
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
      GoRoute(
        path: Routes.call,
        builder: (_, __) => const CallScreen(),
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
              path: Routes.flowers, builder: (_, __) => const MessagesScreen()),
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
              final month = int.tryParse(state.pathParameters['month'] ?? '') ??
                  now.month;
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
/// Everything inside the app, plus the one thing that can interrupt it.
///
/// The shell watches for a call your partner has started and puts the
/// ringing screen on top of wherever you are. It lives here rather than in
/// the chat because a call does not only arrive while you are looking at the
/// conversation — that is the whole reason it is worth interrupting for.
///
/// ⚠️ **This is not a ringtone, and it only reaches an app that is open.**
/// Local notifications cannot wake a backgrounded process (PROGRESS.md §
/// Notifications), so a swiped-away app hears nothing until it is next
/// opened — at which point the Join bubble in the thread is what delivers
/// the call. Push is what would close that gap; until then this is the
/// in-app half of it.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// The call we have already shown a screen for. Without it, every rebuild
  /// while the call is live would push another ringing screen onto the
  /// stack — the notifier's own guard stops a second *session*, but not a
  /// second route.
  String? _ringingFor;

  @override
  Widget build(BuildContext context) {
    ref.listen<FlowerMessage?>(incomingCallProvider, (previous, next) {
      if (next == null) {
        _ringingFor = null;
        return;
      }
      if (_ringingFor == next.id) return;
      _ringingFor = next.id;

      ref.read(callNotifierProvider.notifier).ring(next);
      // Guarded because the stream can deliver while the app is settling a
      // route change of its own.
      if (mounted) context.push(Routes.call);
    });

    // ⚠️ In the shell, not above the router. The call screen is a top-level
    // route *outside* this shell, so a bar here is on every tab and never on
    // the call itself — which is the whole condition, expressed by where it
    // lives rather than by asking what route is on top.
    final call = ref.watch(callNotifierProvider);
    final live = call != null && !call.status.isTerminal;

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          // ⚠️ Not inside the floating window. In picture-in-picture the
          // window *is* the call, and a second little call window drawn
          // inside it is a mirror facing a mirror.
          if (live && !ref.watch(pipModeProvider)) _CallMiniBar(session: call),
        ],
      ),
    );
  }
}

/// The call, still playing, while you are somewhere else in the app.
///
/// 🔴 **It shows the call — it does not describe it.** The first version was
/// a pill reading "On a call · 0:42", which is a notification about something
/// that is happening rather than the thing itself. Pressing back during a
/// video call and getting a sentence about it is not minimising the call, it
/// is closing it and leaving a receipt.
///
/// The same window the launcher gets from picture-in-picture, drawn inside
/// the app: their face, still moving, in the corner. Tap to go back to it.
class _CallMiniBar extends ConsumerStatefulWidget {
  const _CallMiniBar({required this.session});

  final CallSession session;

  @override
  ConsumerState<_CallMiniBar> createState() => _CallMiniBarState();
}

class _CallMiniBarState extends ConsumerState<_CallMiniBar> {
  static const _size = Size(116, 164);
  static const _margin = 12.0;

  /// ⚠️ Bottom **right**, and low enough to clear the tab bar. The left is
  /// where the app's own back affordances live, and a window sitting over
  /// the nav would cover the tab you were trying to reach.
  Offset? _position;

  Offset _clamp(Offset value, Size bounds) => clampToBox(
        value: value,
        box: bounds,
        tile: _size,
        margin: _margin,
        // Clear of the tab bar.
        bottomInset: 96,
      );

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final bounds = MediaQuery.sizeOf(context);
    final position = _clamp(
      _position ??
          Offset(bounds.width - _size.width - _margin,
              bounds.height - _size.height - 96),
      bounds,
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(Routes.call),
        // Movable, for the same reason the self-view is: a window parked
        // over the thing you are reading is a window in the way.
        onPanUpdate: (details) => setState(() {
          _position = _clamp((_position ?? position) + details.delta, bounds);
        }),
        child: Container(
          width: _size.width,
          height: _size.height,
          decoration: BoxDecoration(
            color: AppColors.darkCanvas,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.onDark.withValues(alpha: .14)),
            boxShadow: AppElevation.glow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (session.isVideo)
                  RemoteVideo(session: session)
                else
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.hero),
                    child: Center(
                      child: Icon(CupertinoIcons.phone_fill,
                          color: AppColors.onDark, size: 28),
                    ),
                  ),
                // The clock, on a scrim so it survives a bright frame.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    color: AppColors.darkCanvas.withValues(alpha: .55),
                    alignment: Alignment.center,
                    child: Text(
                      session.elapsed == null
                          ? 'Connecting…'
                          : formatCallDuration(session.elapsed!),
                      style: AppText.caption(AppColors.onDark).copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
