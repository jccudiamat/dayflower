import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/app_router.dart';

/// The gate decides, on every single redirect, whether to move the user.
/// It runs far more often than it looks like it does — every auth event,
/// every profile refresh, every pairing change — and anything it returns is
/// a navigation nobody asked for. The bug these exist to prevent: saving a
/// nickname bounced the app to the splash screen and back to Home, because
/// a *refreshing* profile provider was read as an *unknown* one.

/// A fully signed-in, onboarded, paired user sitting on some screen.
String? _settled(String location) => gateRedirect(
      location: location,
      authKnown: true,
      signedIn: true,
      profileKnown: true,
      hasProfile: true,
      pairKnown: true,
      isLinked: true,
    );

void main() {
  group('a settled user is left alone', () {
    test('stays put on an ordinary screen', () {
      expect(_settled(Routes.settings), isNull);
      expect(_settled(Routes.chat), isNull);
      expect(_settled(Routes.finance), isNull);
      expect(_settled(Routes.activityFeed), isNull);
    });

    test('a profile refresh does not move them', () {
      // The regression, stated directly. `profileKnown` stays true while
      // the provider reloads, because it is still holding the old value —
      // so editing a nickname from Settings must return null, not splash.
      expect(
        gateRedirect(
          location: Routes.settings,
          authKnown: true,
          signedIn: true,
          profileKnown: true,
          hasProfile: true,
          pairKnown: true,
          isLinked: true,
        ),
        isNull,
      );
    });

    test('is pulled off the gate screens', () {
      for (final gate in [
        Routes.splash,
        Routes.welcome,
        Routes.login,
        Routes.onboarding,
        Routes.pair,
      ]) {
        expect(_settled(gate), Routes.home, reason: '$gate should hand over');
      }
    });
  });

  group('the gates themselves', () {
    test('nothing known yet waits on the splash', () {
      expect(
        gateRedirect(
          location: Routes.home,
          authKnown: false,
          signedIn: false,
          profileKnown: false,
          hasProfile: false,
          pairKnown: false,
          isLinked: false,
        ),
        Routes.splash,
      );
    });

    test('signed out goes to welcome, but login stays reachable', () {
      String? out(String at) => gateRedirect(
            location: at,
            authKnown: true,
            signedIn: false,
            profileKnown: false,
            hasProfile: false,
            pairKnown: false,
            isLinked: false,
          );
      expect(out(Routes.home), Routes.welcome);
      expect(out(Routes.welcome), isNull);
      // Otherwise the login screen would bounce back to welcome the moment
      // it opened, and there would be no way to sign in at all.
      expect(out(Routes.login), isNull);
    });

    test('signed in with no profile goes to onboarding', () {
      expect(
        gateRedirect(
          location: Routes.home,
          authKnown: true,
          signedIn: true,
          profileKnown: true,
          hasProfile: false,
          pairKnown: false,
          isLinked: false,
        ),
        Routes.onboarding,
      );
    });

    test('onboarded but unpaired goes to pairing', () {
      expect(
        gateRedirect(
          location: Routes.home,
          authKnown: true,
          signedIn: true,
          profileKnown: true,
          hasProfile: true,
          pairKnown: true,
          isLinked: false,
        ),
        Routes.pair,
      );
    });

    test('a gate never redirects to the screen already showing', () {
      // Returning your own location is a redirect loop, and go_router
      // treats it as one.
      expect(
        gateRedirect(
          location: Routes.pair,
          authKnown: true,
          signedIn: true,
          profileKnown: true,
          hasProfile: true,
          pairKnown: true,
          isLinked: false,
        ),
        isNull,
      );
    });
  });

  group('order of the gates', () {
    test('auth outranks everything', () {
      // A stale profile from a previous session must not let someone who is
      // signed out past the welcome screen.
      expect(
        gateRedirect(
          location: Routes.home,
          authKnown: true,
          signedIn: false,
          profileKnown: true,
          hasProfile: true,
          pairKnown: true,
          isLinked: true,
        ),
        Routes.welcome,
      );
    });

    test('a pair still loading waits rather than showing the pair screen', () {
      // Otherwise every cold start would flash "invite your partner" at
      // somebody who has had one for a year.
      expect(
        gateRedirect(
          location: Routes.home,
          authKnown: true,
          signedIn: true,
          profileKnown: true,
          hasProfile: true,
          pairKnown: false,
          isLinked: false,
        ),
        Routes.splash,
      );
    });
  });

  group('which async values the gate may act on', () {
    // The distinction that decides whether signing in flashes the
    // onboarding wizard at somebody who onboarded a year ago.

    test('a settled value is usable, either way', () {
      expect(isGateValueUsable(const AsyncData<String?>('profile')), isTrue);
      expect(isGateValueUsable(const AsyncData<String?>(null)), isTrue);
    });

    test('nothing loaded yet is not usable', () {
      expect(isGateValueUsable(const AsyncLoading<String?>()), isFalse);
    });

    test('a refresh holding a real value stays usable', () {
      // This is what a nickname edit looks like. Losing it here is the
      // splash-screen flash.
      final refreshing = const AsyncLoading<String?>()
          .copyWithPrevious(const AsyncData<String?>('profile'));
      expect(refreshing.hasValue, isTrue, reason: 'precondition');
      expect(refreshing.isLoading, isTrue, reason: 'precondition');
      expect(isGateValueUsable(refreshing), isTrue);
    });

    test('a refresh holding a stale null is NOT usable', () {
      // And this is what signing in looks like: the null belongs to the
      // signed-out moment before it, and believing it routes to onboarding.
      final afterSignIn = const AsyncLoading<String?>()
          .copyWithPrevious(const AsyncData<String?>(null));
      expect(afterSignIn.hasValue, isTrue,
          reason: 'precondition — this is why plain hasValue was wrong');
      expect(isGateValueUsable(afterSignIn), isFalse);
    });

    test('the stale null waits on the splash rather than onboarding', () {
      final afterSignIn = const AsyncLoading<String?>()
          .copyWithPrevious(const AsyncData<String?>(null));
      expect(
        gateRedirect(
          location: Routes.home,
          authKnown: true,
          signedIn: true,
          profileKnown: isGateValueUsable(afterSignIn),
          hasProfile: afterSignIn.valueOrNull != null,
          pairKnown: false,
          isLinked: false,
        ),
        Routes.splash,
      );
    });
  });
}
