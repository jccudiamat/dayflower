import 'package:flutter/material.dart';

/// What a build failure looks like instead of Flutter's silent grey box.
///
/// 🔴 **Release builds hide the reason, and that cost a whole evening.** When
/// a widget throws while building, Flutter swaps it for `ErrorWidget`: a red
/// screen with the message in debug, and in release a **flat grey rectangle**
/// — `RenderErrorBox` painting `0xF0C0C0C0`, which over black composites to
/// exactly `#B5B5B5`. No text, no hint, nothing to search for. If the failure
/// is near the top of the tree the whole phone screen goes that grey and the
/// app looks frozen, which is precisely how it was reported: "it shows this
/// screen and gets stuck".
///
/// Hiding internals from strangers is the right default for a public app.
/// This one has two users, and a screenshot that names the exception is worth
/// more than a screenshot that cannot be told apart from a hang.
///
/// ⚠️ This runs when the tree is already broken, so it may sit anywhere and
/// depend on nothing. No `Theme`, no `MediaQuery`, no `Scaffold`, no ancestor
/// of any kind — it brings its own `Directionality` because `Text` demands
/// one and the widget above it may be the thing that just died.
class CrashScreen extends StatelessWidget {
  const CrashScreen(this.details, {super.key});

  final FlutterErrorDetails details;

  /// Installs this in place of the default. Call once, before `runApp`.
  static void install() {
    ErrorWidget.builder = (details) => CrashScreen(details);
  }

  @override
  Widget build(BuildContext context) {
    final summary = details.exception.toString();
    final where = details.library ?? 'widgets library';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        // Deliberately the app's plum rather than Flutter's grey: this should
        // be recognisable as Dayflower failing, not as the phone failing.
        color: const Color(0xFF171027),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Dayflower hit a snag 🥀',
                  style: TextStyle(
                    color: Color(0xFFF5F2F8),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Close and reopen the app. If it keeps happening, send this:',
                  style: TextStyle(
                    color: Color(0xFF9C92AC),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      // Trimmed: a stack trace past this point is unreadable
                      // on a phone and unphotographable anyway.
                      '$where\n\n$summary',
                      style: const TextStyle(
                        color: Color(0xFFE2447C),
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
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
