import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/features/presence/data/device_presence.dart';
import 'package:dayflower/features/presence/data/presence_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gate, wired up.
///
/// presence_test.dart pins the *rule*; this pins that the heartbeat
/// actually asks it before writing. They are worth separating: the rule was
/// easy to get right and the wiring is where it would quietly stop being
/// consulted — a refactor that drops one `await` here puts the old
/// behaviour back with every rule test still green.

/// Stands in for the table, so a refused beat is visibly a write that never
/// happened rather than one that failed.
class Recorder implements PresenceRepository {
  final pings = <String>[];

  @override
  Future<void> markActive(String userId) async => pings.add(userId);

  @override
  Future<DateTime?> lastActive(String userId) async => null;
}

ProviderContainer containerWith(
  Recorder repo, {
  String? userId = 'u1',
  bool awake = true,
}) =>
    ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      presenceRepositoryProvider.overrideWithValue(repo),
      deviceAwakeProvider.overrideWithValue(() async => awake),
    ]);

void main() {
  test('an awake phone with a session writes a ping', () async {
    final repo = Recorder();
    final container = containerWith(repo);
    addTearDown(container.dispose);

    await container.read(presencePingerProvider).pingNow();
    expect(repo.pings, ['u1']);
  });

  test('a phone that only lit up for a notification writes nothing', () async {
    // 🔴 The bug. The Activity is showWhenLocked, so a full-screen intent
    // put the app in front of a locked phone and the beat went out before
    // anyone had touched it.
    final repo = Recorder();
    final container = containerWith(repo, awake: false);
    addTearDown(container.dispose);

    await container.read(presencePingerProvider).pingNow();
    expect(repo.pings, isEmpty);
  });

  test('no session, no ping', () async {
    final repo = Recorder();
    final container = containerWith(repo, userId: null);
    addTearDown(container.dispose);

    await container.read(presencePingerProvider).pingNow();
    expect(repo.pings, isEmpty);
  });

  test('the timer keeps going after a refused ping', () async {
    // ⚠️ Unlocking a phone raises no lifecycle event, so nothing calls
    // start() again. If a refusal stopped the timer, a phone that rang at
    // 3am would stay silent until the app was next reopened by hand.
    final repo = Recorder();
    final container = containerWith(repo, awake: false);
    addTearDown(container.dispose);
    final heart = container.read(presencePingerProvider);

    heart.start();
    await heart.pingNow();
    expect(repo.pings, isEmpty);

    heart.stop();
    // Restarting is the same object, and it beats again once the answer
    // changes — the gate is asked per beat, not once at start.
    final awake = containerWith(repo);
    addTearDown(awake.dispose);
    await awake.read(presencePingerProvider).pingNow();
    expect(repo.pings, ['u1']);
  });
}
