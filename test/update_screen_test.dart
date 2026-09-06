import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dayflower/features/updates/data/app_release.dart';
import 'package:dayflower/features/updates/data/update_repository.dart';
import 'package:dayflower/features/updates/presentation/widgets/update_screen.dart';

/// The updater flashed up for one frame at launch and vanished. It was a
/// modal sheet on the router's navigator — a *pageless* route bound to the
/// splash page, which the gate redirect replaced a second later, taking the
/// sheet with it. It is a layer above the Router now.
///
/// 🔴 The first version of that layer crashed: it used `BackButtonListener`,
/// which looks for a `Router` ancestor and throws when there is none — and
/// being above the Router is the entire point. Nothing but building the
/// widget catches that, which is what the smoke tests here are for.

const _release = AppRelease(
  buildNumber: 33,
  versionName: '1.0.0',
  fileName: 'dayflower-33.apk',
  sizeBytes: 41871523,
  notes: ['New app icon', 'Voice and video calls'],
  minBuildNumber: 0,
);

const _mandatoryRelease = AppRelease(
  buildNumber: 33,
  versionName: '1.0.0',
  fileName: 'dayflower-33.apk',
  sizeBytes: 41871523,
  notes: [],
  minBuildNumber: 33,
);

Future<void> _pump(WidgetTester tester, UpdateState state) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: UpdateScreen(state: state, onDismiss: () {}),
      ),
    ),
  );
  await tester.pump();
  // google_fonts cannot fetch Quicksand in a test and throws asynchronously.
  // Irrelevant to what these assert, and it must not be mistaken for the
  // widget's own failure.
  tester.takeException();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('it builds in every stage it can be shown in', () {
    // ⚠️ The point is the absence of a thrown exception. `_pump` swallows
    // exactly one — the font — so anything else fails the test.
    for (final (name, state) in <(String, UpdateState)>[
      (
        'available',
        const UpdateState(
            stage: UpdateStage.available, release: _release, installedBuild: 32)
      ),
      (
        'downloading',
        const UpdateState(
            stage: UpdateStage.downloading,
            release: _release,
            installedBuild: 32,
            received: 1800,
            total: 4187)
      ),
      (
        'ready',
        const UpdateState(
            stage: UpdateStage.ready,
            release: _release,
            installedBuild: 32,
            apkPath: '/x.apk')
      ),
      (
        'failed',
        const UpdateState(
            stage: UpdateStage.failed,
            release: _release,
            installedBuild: 32,
            error: 'Download failed')
      ),
      (
        'mandatory',
        const UpdateState(
            stage: UpdateStage.available,
            release: _mandatoryRelease,
            installedBuild: 32)
      ),
    ]) {
      testWidgets(name, (tester) async {
        await _pump(tester, state);
        expect(find.byType(UpdateScreen), findsOneWidget);
      });
    }
  });

  group('what each stage offers', () {
    testWidgets('available offers the update and a way out', (tester) async {
      await _pump(
          tester,
          const UpdateState(
              stage: UpdateStage.available,
              release: _release,
              installedBuild: 32));
      expect(find.text('Update now'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text('A new\nDayflower\nis ready'), findsOneWidget);
    });

    testWidgets('a required update has no way out', (tester) async {
      // The whole meaning of mandatory. If this ever finds a "Not Now",
      // a build nobody may stay on has become dismissible.
      await _pump(
          tester,
          const UpdateState(
              stage: UpdateStage.available,
              release: _mandatoryRelease,
              installedBuild: 32));
      expect(find.text('Not now'), findsNothing);
      expect(find.text('Update\nrequired'), findsOneWidget);
    });

    testWidgets('mid-download there is nothing to dismiss to', (tester) async {
      await _pump(
          tester,
          const UpdateState(
              stage: UpdateStage.downloading,
              release: _release,
              installedBuild: 32,
              received: 2093,
              total: 4187));
      expect(find.text('Not now'), findsNothing);
      expect(find.textContaining('Downloading'), findsOneWidget);
    });

    testWidgets('ready installs, and warns about the Android prompt',
        (tester) async {
      await _pump(
          tester,
          const UpdateState(
              stage: UpdateStage.ready,
              release: _release,
              installedBuild: 32,
              apkPath: '/x.apk'));
      expect(find.text('Install now'), findsOneWidget);
      expect(find.textContaining('allow installs'), findsOneWidget);
    });

    testWidgets('failed retries and says why', (tester) async {
      await _pump(
          tester,
          const UpdateState(
              stage: UpdateStage.failed,
              release: _release,
              installedBuild: 32,
              error: 'Download failed'));
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Download failed'), findsOneWidget);
    });
  });

  group('when it covers the app', () {
    const available = UpdateState(
        stage: UpdateStage.available, release: _release, installedBuild: 32);

    test('not without a release, whatever the stage says', () {
      expect(
          updateIsShowing(
              const UpdateState(stage: UpdateStage.available), null),
          isFalse);
    });

    test('not for stages with nothing to offer', () {
      for (final stage in [
        UpdateStage.idle,
        UpdateStage.checking,
        UpdateStage.upToDate,
      ]) {
        expect(
          updateIsShowing(
              UpdateState(stage: stage, release: _release, installedBuild: 32),
              null),
          isFalse,
          reason: '$stage',
        );
      }
    });

    test('dismissing hides this build and only this build', () {
      expect(updateIsShowing(available, 33), isFalse);
      // A newer build has to be able to interrupt again — a dismissal is
      // about one release, not about updates in general.
      expect(updateIsShowing(available, 32), isTrue);
    });

    test('a required update ignores the dismissal entirely', () {
      const required = UpdateState(
          stage: UpdateStage.available,
          release: _mandatoryRelease,
          installedBuild: 32);
      expect(updateIsShowing(required, 33), isTrue);
    });
  });
}
