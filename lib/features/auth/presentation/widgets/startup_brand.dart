import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';

/// Shared chrome for the welcome and loading screens. No timers or routing:
/// the existing authentication gate remains responsible for startup.
class StartupSurface extends StatelessWidget {
  const StartupSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: (AppColors.isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(
          statusBarColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarDividerColor: AppColors.background,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Container(
            constraints: const BoxConstraints.expand(),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(.6, -.55),
                radius: 1.1,
                colors: [AppColors.blush, AppColors.background],
              ),
            ),
            child: SafeArea(child: child),
          ),
        ),
      );
}

class DayflowerWordmark extends StatelessWidget {
  const DayflowerWordmark({super.key});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/mark.png',
              width: 30, height: 30, excludeFromSemantics: true),
          const SizedBox(width: 9),
          Text('Dayflower',
              style: AppText.title().copyWith(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              )),
        ],
      );
}

/// An illustration of the real photo and heartbeat widgets. These are
/// onboarding artwork, never fake incoming photos or tappable sample data.
class WelcomeWidgetPreview extends StatelessWidget {
  const WelcomeWidgetPreview({super.key, this.height = 280});
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
            height: height,
            child: Center(
                child: AspectRatio(
              aspectRatio: 1.14,
              child: LayoutBuilder(builder: (context, box) {
                final width = box.maxWidth;
                return Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: width * .05,
                    top: 10,
                    width: width * .73,
                    height: box.maxHeight * .88,
                    child: Transform.rotate(
                        angle: -.065,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.ink.withValues(alpha: .09),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10))
                            ],
                          ),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Stack(fit: StackFit.expand, children: [
                                Image.asset(
                                    'assets/images/flowers/sunset_shore.webp',
                                    fit: BoxFit.cover),
                                const DecoratedBox(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0x99170F23)
                                  ],
                                  stops: [.45, 1],
                                ))),
                                Positioned(
                                    left: 14,
                                    right: 14,
                                    bottom: 15,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('My Day',
                                              style: AppText.subtitle(
                                                  Colors.white)),
                                          const SizedBox(height: 2),
                                          Text('A little of your world',
                                              style: AppText.caption(
                                                  Colors.white)),
                                        ])),
                              ])),
                        )),
                  ),
                  Positioned(
                    right: width * .01,
                    bottom: 5,
                    width: width * .43,
                    child: Transform.rotate(
                        angle: .07,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.darkSurface,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                                color: AppColors.onDark.withValues(alpha: .15)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: .13),
                                  blurRadius: 20,
                                  offset: const Offset(0, 9))
                            ],
                          ),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const AppIcon(Icons.favorite,
                                color: AppColors.gradientPink, size: 42),
                            const SizedBox(height: 10),
                            Text('Thinking of you',
                                textAlign: TextAlign.center,
                                style: AppText.caption(AppColors.onDark)
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ]),
                        )),
                  ),
                ]);
              }),
            ))),
      );
}

class StartupLoadingView extends StatelessWidget {
  const StartupLoadingView({super.key});

  @override
  Widget build(BuildContext context) => StartupSurface(
        child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 176,
                              height: 176,
                              padding: const EdgeInsets.all(38),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [
                                    AppColors.blushMid,
                                    AppColors.blush.withValues(alpha: .2)
                                  ])),
                              child: Image.asset('assets/images/mark.png',
                                  excludeFromSemantics: true),
                            ),
                            const SizedBox(height: 22),
                            Text('Dayflower',
                                style: AppText.display().copyWith(
                                    fontSize: 36, letterSpacing: -1.2)),
                            const SizedBox(height: 8),
                            Text('Your person, a little closer.',
                                textAlign: TextAlign.center,
                                style: AppText.body(AppColors.body)),
                            const SizedBox(height: 38),
                            SizedBox(
                                width: 104,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    value:
                                        MediaQuery.disableAnimationsOf(context)
                                            ? 1
                                            : null,
                                    color: AppColors.isDark
                                        ? AppColors.gradientPink
                                        : AppColors.petalDeep,
                                    backgroundColor: AppColors.border,
                                    semanticsLabel: 'Opening Dayflower',
                                  ),
                                )),
                            const SizedBox(height: 12),
                            Text('Opening your space',
                                style: AppText.caption(AppColors.body)),
                          ],
                        )),
                  ),
                )),
      );
}
