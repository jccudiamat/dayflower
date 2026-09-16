import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One controller per section, shared by its content and navbar reselect.
/// Nested routes can return to their parent and reset that parent's position.
final sectionScrollControllerProvider =
    Provider.autoDispose.family<ScrollController, String>((ref, route) {
  final controller = ScrollController(keepScrollOffset: false);
  ref.onDispose(controller.dispose);
  return controller;
});

class SectionScrollScope extends ConsumerWidget {
  const SectionScrollScope({
    super.key,
    required this.route,
    required this.child,
  });

  final String route;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PrimaryScrollController(
        controller: ref.watch(sectionScrollControllerProvider(route)),
        automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
        child: child,
      );
}
