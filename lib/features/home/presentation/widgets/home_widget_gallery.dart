import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../heartbeat/data/heartbeat_repository.dart';
import '../../../reunion/data/reunion_repository.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../tulip/domain/day_reactions.dart';
import '../../domain/home_moments.dart';
import '../screens/home_screen.dart' show HomeDayPhoto;

enum HomeWidgetKind { myDay, heartbeat, reunion }

class HomeWidgetGallery extends ConsumerWidget {
  const HomeWidgetGallery({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
          key: const ValueKey('home-widget-gallery'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Keep each other close', style: AppText.title()),
            const SizedBox(height: AppSpace.xs),
            Text('Dayflower on your phone’s home screen',
                style: AppText.body()),
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border)),
              child: Column(children: [
                for (final kind in HomeWidgetKind.values) ...[
                  if (kind != HomeWidgetKind.myDay)
                    Divider(height: 1, color: AppColors.border),
                  _WidgetFeature(kind: kind),
                ],
              ]),
            ),
          ]);
}

class _WidgetFeature extends StatelessWidget {
  const _WidgetFeature({required this.kind});
  final HomeWidgetKind kind;
  String get title => switch (kind) {
        HomeWidgetKind.myDay => 'My Day',
        HomeWidgetKind.heartbeat => 'Heartbeat',
        HomeWidgetKind.reunion => 'Reunion'
      };
  String get description => switch (kind) {
        HomeWidgetKind.myDay => 'Their photos, right on your home screen.',
        HomeWidgetKind.heartbeat => 'Send love in a tap.',
        HomeWidgetKind.reunion => 'Until your next hug.',
      };
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Set up $title widget',
        button: true,
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () => _setup(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: LayoutBuilder(builder: (context, box) {
                  final content = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.subtitle()),
                        const SizedBox(height: 6),
                        Text(description, style: AppText.body()),
                        const SizedBox(height: 12),
                        Text('Set up ›',
                            style: AppText.subtitle(AppColors.brandDark)),
                      ]);
                  final preview = ExcludeSemantics(
                      child: SizedBox(
                          width: 104,
                          height: 118,
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.ink
                                            .withValues(alpha: .08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4))
                                  ]),
                              child: MediaQuery.withNoTextScaling(
                                  child: _WidgetPreview(kind: kind)))));
                  if (box.maxWidth < 240 ||
                      MediaQuery.textScalerOf(context).scale(14) > 21) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: preview),
                          const SizedBox(height: 16),
                          content,
                        ]);
                  }
                  return Row(children: [
                    preview,
                    const SizedBox(width: 20),
                    Expanded(child: content)
                  ]);
                }),
              ),
            )),
      );
  void _setup(BuildContext context) {
    // ⚠️ Was overridden to "Today's Flower" here while the card above it
    // said "My Day" — the same widget under two names, in one sheet.
    final widgetName = title;
    final android = defaultTargetPlatform == TargetPlatform.android;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                              tooltip: 'Close widget setup',
                              onPressed: () => Navigator.pop(sheet),
                              icon: const AppIcon(CupertinoIcons.xmark))),
                      Text('Set up $title', style: AppText.hero()),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                          kIsWeb
                              ? 'Add widgets from the Dayflower app installed on your phone.'
                              : android
                                  ? '1. Touch and hold an empty space on your phone’s home screen.\n\n2. Tap Widgets, then Dayflower.\n\n3. Drag “$widgetName” onto your home screen.'
                                  : 'Touch and hold your phone’s home screen, then choose Edit and Add Widget. Search for Dayflower and choose an available widget.',
                          style: AppText.body()),
                      if (kind == HomeWidgetKind.myDay) ...[
                        const SizedBox(height: AppSpace.sm),
                        Text(
                            'My Day photos appear in the “Today’s Flower” widget.',
                            style: AppText.caption())
                      ],
                      if (kind == HomeWidgetKind.reunion) ...[
                        const SizedBox(height: AppSpace.sm),
                        Text(
                            'Choose your reunion date in Events. You can change the background in widget settings.',
                            style: AppText.body()),
                        TextButton(
                            onPressed: () {
                              Navigator.pop(sheet);
                              context.push(Routes.events);
                            },
                            child: const Text('Choose reunion date'))
                      ],
                      const SizedBox(height: AppSpace.md),
                      OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheet);
                            context.push(Routes.settings);
                          },
                          child: const Text('Widget settings')),
                    ]))));
  }
}

/// Illustrative, noninteractive previews: no accidental sends or photo reactions.
class _WidgetPreview extends ConsumerWidget {
  const _WidgetPreview({required this.kind});
  final HomeWidgetKind kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(partnerDayPhotoProvider);
    final counts = ref.watch(todayHeartbeatCountsProvider);
    final reunion = ref.watch(reunionProvider).valueOrNull;
    final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
    final days = reunion == null
        ? null
        : DateTime.utc(reunion.happensAt.year, reunion.happensAt.month,
                reunion.happensAt.day)
            .difference(DateTime.utc(now.year, now.month, now.day))
            .inDays;
    return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
            color: kind == HomeWidgetKind.heartbeat
                ? AppColors.onDark
                : AppColors.surfaceSubtle,
            child: switch (kind) {
              HomeWidgetKind.myDay => photo == null
                  ? _label(CupertinoIcons.camera, 'Photo preview')
                  : Stack(fit: StackFit.expand, children: [
                      HomeDayPhoto(message: photo),
                      Positioned(
                          left: 4,
                          right: 4,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 3),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill)),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  for (final reaction in DayReaction.values)
                                    Text(reaction.emoji,
                                        style: AppText.caption(Colors.white)),
                                ]),
                          )),
                    ]),
              HomeWidgetKind.heartbeat => Container(
                  color: const Color(0xFF1D1430),
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AppIcon(CupertinoIcons.heart_fill,
                                color: AppColors.brand, size: 40),
                            const SizedBox(height: 8),
                            Text('Tap to send',
                                style: AppText.caption(Colors.white)),
                            if (counts.partner > 0)
                              Text('${counts.partner} today',
                                  style: AppText.caption(Colors.white70)),
                          ]))),
              HomeWidgetKind.reunion => days == null || days < 0
                  ? _label(CupertinoIcons.calendar, 'Choose a date')
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$days',
                                style: AppText.stat(AppColors.secondary)),
                            Text(
                                days == 0
                                    ? 'Together today'
                                    : 'days until our next hug',
                                textAlign: TextAlign.center,
                                style: AppText.caption()),
                          ])),
            }));
  }

  Widget _label(IconData icon, String label) => Padding(
      padding: const EdgeInsets.all(8),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AppIcon(icon, size: 32, color: AppColors.secondary),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: AppText.caption()),
      ]));
}
