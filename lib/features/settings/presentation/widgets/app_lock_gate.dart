import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../data/app_lock.dart';

/// Closes the app's screen when it has been away long enough.
///
/// Wraps the whole app, above the router, so there is no route that can be
/// reached around it — including the ones a notification or a widget deep
/// link opens, which is exactly where a gate placed inside the shell would
/// leak.
///
/// ⚠️ **It covers the UI; it does not end the session.** Supabase stays
/// signed in, so the heartbeat widget's background isolate, reminder alarms
/// and push all keep working while the screen is locked. That is the whole
/// reason this is a lock and not a logout — see [AppLockDelay].
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  /// When the app was last backgrounded. Null while it is in front.
  DateTime? _leftAt;

  /// True while the system prompt is up.
  ///
  /// 🔴 The biometric prompt is itself a window, so showing it sends the app
  /// `inactive`/`paused` — and without this the return from a *successful*
  /// unlock would be read as another trip to the background and lock it
  /// straight again. An unlock loop with no way out.
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authenticating) return;
    final settings = ref.read(appLockPrefsProvider);
    if (!settings.enabled) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Stamped on the way out, not counted on the way in: the app is not
        // running to keep a timer while it is away.
        _leftAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final away = _leftAt;
        _leftAt = null;
        if (away == null) return;
        if (DateTime.now().difference(away) >= settings.delay.after) {
          ref.read(appLockedProvider.notifier).state = true;
        }
      case AppLifecycleState.inactive:
        // Deliberately ignored. A notification shade pull or the app
        // switcher raises `inactive` without the app going anywhere, and
        // treating that as leaving would lock it in your hand.
        break;
    }
  }

  Future<void> _unlock() async {
    setState(() => _authenticating = true);
    try {
      if (await AppLockAuth.unlock()) {
        ref.read(appLockedProvider.notifier).state = false;
        // Cleared so the lifecycle events the prompt itself caused cannot
        // be mistaken for a fresh trip to the background.
        _leftAt = null;
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockedProvider);

    return Stack(
      children: [
        widget.child,
        if (locked)
          // Opaque and on top rather than replacing the child: the app keeps
          // its state, its scroll positions and any live call, so unlocking
          // puts you back exactly where you were.
          Positioned.fill(
            child: _LockScreen(
              busy: _authenticating,
              onUnlock: _unlock,
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.busy, required this.onUnlock});

  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkCanvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text('🌷', style: TextStyle(fontSize: 52)),
              const SizedBox(height: AppSpace.md),
              Text('Dayflower is locked',
                  style: AppText.hero(AppColors.onDark)),
              const SizedBox(height: AppSpace.xs),
              Text(
                // Says nothing about what is inside. A lock screen that
                // previewed the last message would defeat itself.
                'Unlock to pick up where you left off.',
                textAlign: TextAlign.center,
                style: AppText.body(AppColors.onDarkMuted),
              ),
              const Spacer(),
              GradientButton(
                label: busy ? 'Waiting…' : 'Unlock',
                onPressed: busy ? null : onUnlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
