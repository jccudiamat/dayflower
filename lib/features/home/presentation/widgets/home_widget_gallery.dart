import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../reunion/data/reunion_repository.dart';
import '../../../tulip/data/chat_shortcut.dart';
import '../../../tulip/presentation/widgets/chat_shortcut_action.dart';
import '../../../widget/heartbeat_themes.dart';
import '../../../widget/heartbeat_widget_preview.dart';
import '../../../widget/widget_pinner.dart';
import '../../domain/home_moments.dart';

/// [chat] is not a widget but their chat's icon (ChatShortcut), which
/// people look for in the same place. Android only.
enum HomeWidgetKind { myDay, heartbeat, reunion, chat }

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
                for (final kind in HomeWidgetKind.values)
                  if (kind != HomeWidgetKind.chat ||
                      ChatShortcut.supported) ...[
                    if (kind != HomeWidgetKind.myDay)
                      Divider(height: 1, color: AppColors.border),
                    _WidgetFeature(kind: kind),
                  ],
              ]),
            ),
          ]);
}

class _WidgetFeature extends ConsumerWidget {
  const _WidgetFeature({required this.kind});
  final HomeWidgetKind kind;
  String get title => switch (kind) {
        HomeWidgetKind.myDay => 'My Day',
        HomeWidgetKind.heartbeat => 'Heartbeat',
        HomeWidgetKind.reunion => 'Reunion',
        HomeWidgetKind.chat => 'Chat',
      };
  String get description => switch (kind) {
        HomeWidgetKind.myDay => 'Their photos, right on your home screen.',
        HomeWidgetKind.heartbeat => 'Send love in a tap.',
        HomeWidgetKind.reunion => 'Until your next hug.',
        HomeWidgetKind.chat => 'Their chat, one tap from your home screen.',
      };
  bool get _isChat => kind == HomeWidgetKind.chat;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
        label: _isChat
            ? 'Add their chat to your home screen'
            : 'Add the $title widget to your home screen',
        button: true,
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              // Nothing to set up first: the launcher is asked straight
              // away, the way WhatsApp's Add shortcut does.
              onTap: () => _isChat
                  ? addChatShortcut(context, ref)
                  : _add(context, ref),
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
                        Text('Add ›',
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
  /// The launcher's own "Add to home screen" dialog (WidgetPinner), as the
  /// chat's shortcut is added. It used to be steps through the widget tray
  /// every time; they are only what shows now where the launcher cannot be
  /// asked (iOS, the web, a launcher that takes no requests).
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    // A countdown with nothing to count to says so on the widget ("Tap to
    // set a date"), but the date is quicker to choose from here.
    final noDate = kind == HomeWidgetKind.reunion &&
        ref.read(reunionProvider).valueOrNull == null;
    if (!await WidgetPinner.pin(kind.name)) {
      if (context.mounted) _setup(context);
      return;
    }
    if (noDate) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Choose your reunion date to start the countdown.'),
        action: SnackBarAction(
            label: 'Choose', onPressed: () => router.push(Routes.events)),
      ));
    }
  }

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
                      if (kind == HomeWidgetKind.heartbeat) ...[
                        const SizedBox(height: AppSpace.sm),
                        Text(
                            'Tap it to send a heartbeat. You can change its picture in widget settings.',
                            style: AppText.body()),
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
    final beatTheme = ref.watch(heartbeatThemeProvider);
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
              HomeWidgetKind.myDay => const _SampleDay(),
              // The scene they picked, as the widget draws it. No counts: the
              // widget does not keep them any more.
              HomeWidgetKind.heartbeat =>
                HeartbeatWidgetPreview(theme: beatTheme),
              HomeWidgetKind.chat => const ChatShortcutPreview(),
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

/// A made-up day on the My Day widget, so its preview shows what the widget
/// does rather than whatever they shared today, or an empty box when they
/// have shared nothing. The picture is one the app already carries
/// (Together's couple at sunset), so it costs the APK nothing.
class _SampleDay extends StatelessWidget {
  const _SampleDay();

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/together/couple_sunset.webp',
            fit: BoxFit.cover, excludeFromSemantics: true),
        // Dark enough at the foot for the caption, as on the widget.
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xA6000000)]))),
        // The caption, then the heart and the reply bubble, bottom right,
        // as on the phone.
        const Positioned(
            left: 8,
            right: 6,
            bottom: 7,
            child: Row(children: [
              Expanded(
                  child: Text('Sunset walk',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600))),
              SizedBox(width: 4),
              AppIcon(CupertinoIcons.heart, color: Colors.white, size: 14),
              SizedBox(width: 4),
              AppIcon(CupertinoIcons.chat_bubble,
                  color: Colors.white, size: 14),
            ])),
      ]);
}
