import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import 'app_icon.dart';
import 'app_bottom_nav.dart';

/// Shared chrome for the relationship's content-first destinations.
class StoryScaffold extends StatelessWidget {
  const StoryScaffold(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.children,
      this.actions = const []});
  final String title, subtitle;
  final List<Widget> children, actions;
  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar: const AppBottomNav(),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.all(AppSpace.screenInset),
                children: [
              Row(children: [
                Expanded(child: Text(title, style: AppText.hero())),
                ...actions
              ]),
              const SizedBox(height: AppSpace.xxs),
              Text(subtitle, style: AppText.caption(AppColors.body)),
              const SizedBox(height: AppSpace.md),
              ...children
            ])),
      );
}

class StorySection extends StatelessWidget {
  const StorySection(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.xs),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.subtitle())),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!))
      ]));
}

class UtilityRow extends StatelessWidget {
  const UtilityRow(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.onTap,
      this.trailing});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: ListTile(
          dense: true,
          minTileHeight: 64,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm, vertical: AppSpace.xxs),
          leading: AppIcon(icon, color: AppColors.secondary),
          title: Text(title,
              style: AppText.body(AppColors.ink)
                  .copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: AppText.caption(AppColors.body)),
          trailing: trailing ??
              (onTap == null
                  ? Text('Soon', style: AppText.caption())
                  : AppIcon(CupertinoIcons.chevron_right,
                      size: 16, color: AppColors.muted)),
          onTap: onTap));
}

class StoryEmptyState extends StatelessWidget {
  const StoryEmptyState(
      {super.key, required this.title, required this.body, this.action});
  final String title, body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
      child: Column(children: [
        const AppIcon(CupertinoIcons.heart, size: 32, color: AppColors.brand),
        const SizedBox(height: AppSpace.sm),
        Text(title, textAlign: TextAlign.center, style: AppText.title()),
        const SizedBox(height: AppSpace.xs),
        Text(body, textAlign: TextAlign.center, style: AppText.body()),
        if (action != null) action!
      ]));
}

class CreationTile extends StatelessWidget {
  const CreationTile(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.art,
      required this.onTap});
  final String title, subtitle;
  final Widget art;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Column(children: [
                ExcludeSemantics(child: art),
                const SizedBox(height: AppSpace.sm),
                Text(title,
                    style: AppText.subtitle(), textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.xxs),
                Text(subtitle,
                    style: AppText.caption(AppColors.body),
                    textAlign: TextAlign.center)
              ]))));
}
