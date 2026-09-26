import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/frames/photo_frames.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../booth/domain/strip_templates.dart';

/// What the camera picked, on its way back.
///
/// ⚠️ A sealed pair rather than two nullable fields: a result is a frame or
/// a strip or nothing, never some combination, and the camera should not
/// have to defend against a state that cannot exist.
sealed class TemplateChoice {
  const TemplateChoice();
}

class FrameChoice extends TemplateChoice {
  const FrameChoice(this.frame);
  final PhotoFrame frame;
}

class StripChoice extends TemplateChoice {
  const StripChoice(this.template);
  final StripTemplate template;
}

/// Everything you can put a photo into, on one page.
///
/// 🔴 **The photo-booth strips live here now.** They used to be the row of
/// circles under the viewfinder, which meant the camera offered eight strip
/// styles and nothing else, and every new frame would have made that row
/// longer until it was the whole screen. The row under the shutter is for
/// the handful you reach for while composing; this is where you go to
/// *look*, and it is the only place that can show a template at a size
/// where you can see what it is.
class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(String text) {
    final q = _search.text.trim().toLowerCase();
    return q.isEmpty || text.toLowerCase().contains(q);
  }

  void _choose(TemplateChoice choice) {
    if (context.canPop()) {
      context.pop(choice);
    } else {
      // Opened straight from a link, with no camera underneath to hand it
      // to. The camera is where it would be used, so go there.
      context.go(Routes.flowers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final singles = [
      for (final f in photoFrames)
        if (f.slots == 1 && _matches(f.name)) f,
    ];
    final pairs = [
      for (final f in photoFrames)
        if (f.slots == 2 && _matches(f.name)) f,
    ];
    // 🔴 No "Paper" section. The torn note has no window, and in build 114
    // picking it here and shooting sent a blank sheet: the photo had
    // nowhere to go and was dropped. This page is reached from the camera,
    // so it offers only what a photo can go into.
    final strips = [
      for (final t in StripTemplate.all)
        if (_matches('${t.name} ${t.tagline}')) t,
    ];
    final nothing = singles.isEmpty && pairs.isEmpty && strips.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: Row(
                children: [
                  IosBackButton(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.flowers)),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text('Templates', style: AppText.display()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenInset,
                  AppSpace.sm, AppSpace.screenInset, AppSpace.xs),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: AppText.body(AppColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  hintText: 'Search templates',
                  hintStyle: AppText.body(AppColors.muted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  prefixIcon: AppIcon(CupertinoIcons.search,
                      size: 18, color: AppColors.muted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 40, minHeight: 20),
                  border: _round,
                  enabledBorder: _round,
                  focusedBorder: _round,
                ),
              ),
            ),
            Expanded(
              child: nothing
                  ? Center(
                      child: Text('Nothing called “${_search.text.trim()}”.',
                          style: AppText.body(AppColors.muted)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpace.screenInset,
                          AppSpace.xs, AppSpace.screenInset, AppSpace.lg),
                      children: [
                        if (singles.isNotEmpty) ...[
                          _Heading('One photo', '${singles.length}'),
                          _FrameGrid(frames: singles, onPick: _choose),
                        ],
                        if (pairs.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.md),
                          _Heading('Two photos', '${pairs.length}'),
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpace.xs),
                            child: Text('Take one, then the other.',
                                style: AppText.caption()),
                          ),
                          _FrameGrid(frames: pairs, onPick: _choose),
                        ],
                        if (strips.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.md),
                          _Heading('Photo booth', '${strips.length}'),
                          const SizedBox(height: AppSpace.xxs),
                          Text(
                            'A strip you both shoot. Duo ones wait for their '
                            'half before they finish.',
                            style: AppText.caption(),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          for (final t in strips) ...[
                            _StripRow(
                                template: t,
                                onTap: () => _choose(StripChoice(t))),
                            const SizedBox(height: AppSpace.xs),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static final _round = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    borderSide: BorderSide.none,
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.count);
  final String title, count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.xs),
        child: Row(
          children: [
            Text(title.toUpperCase(), style: AppText.label()),
            const SizedBox(width: AppSpace.xs),
            Text(count, style: AppText.label(AppColors.muted)),
          ],
        ),
      );
}

/// The frames, big enough to tell apart.
class _FrameGrid extends StatelessWidget {
  const _FrameGrid({required this.frames, required this.onPick});

  final List<PhotoFrame> frames;
  final ValueChanged<TemplateChoice> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpace.xs,
        mainAxisSpacing: AppSpace.xs,
        childAspectRatio: .86,
      ),
      itemCount: frames.length,
      itemBuilder: (context, i) {
        final frame = frames[i];
        return Semantics(
          button: true,
          label: frame.name,
          excludeSemantics: true,
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onPick(FrameChoice(frame)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xs),
                child: Column(
                  children: [
                    Expanded(
                      child: Image.asset(
                        frame.asset,
                        fit: BoxFit.contain,
                        cacheWidth: 480,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(frame.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(AppColors.ink)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One photo-booth strip, in its own paper and ink.
class _StripRow extends StatelessWidget {
  const _StripRow({required this.template, required this.onTap});

  final StripTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: template.name,
      excludeSemantics: true,
      child: Material(
        color: template.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: template.accent.withValues(alpha: .5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.compact),
            child: Row(
              children: [
                Text(template.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: AppSpace.compact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(template.name,
                          style: AppText.subtitle(template.ink)
                              .copyWith(fontSize: 15)),
                      Text(template.tagline,
                          style: AppText.caption(
                              template.ink.withValues(alpha: .7))),
                    ],
                  ),
                ),
                if (template.isDuo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: template.accent.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('Duo',
                        style: AppText.label(template.ink)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
