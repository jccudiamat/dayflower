import 'package:dayflower/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The shape the bug needs: a list and a conversation pushed over it, both
/// inside a shell, with a popup opened over the whole app from the
/// conversation, the way the reaction bar and the photo viewers open.
Future<GoRouter> _conversationWithPopup(WidgetTester tester) async {
  final router = GoRouter(initialLocation: '/list', routes: [
    ShellRoute(
      builder: (_, __, child) => Scaffold(body: child),
      routes: [
        GoRoute(path: '/list', builder: (_, __) => const Text('Chats')),
        GoRoute(
          path: '/chat',
          builder: (context, __) => Center(
            child: TextButton(
              onPressed: () => showGeneralDialog<void>(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'Close',
                pageBuilder: (_, __, ___) => const Text('Reactions'),
              ),
              child: const Text('Long-press'),
            ),
          ),
        ),
      ],
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  router.push('/chat');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Long-press'));
  await tester.pumpAndSettle();
  expect(find.text('Reactions'), findsOneWidget);
  return router;
}

void main() {
  testWidgets('go_router alone closes the page under a popup (the bug)',
      (tester) async {
    // Precondition, pinned so the fix below keeps a reason to exist: with a
    // page pushed in the shell, go_router pops the shell and never looks at
    // the popup on the root navigator above it.
    final router = await _conversationWithPopup(tester);
    await router.routerDelegate.popRoute();
    await tester.pumpAndSettle();
    expect(find.text('Long-press'), findsNothing, reason: 'conversation gone');
    expect(find.text('Reactions'), findsOneWidget, reason: 'popup left over');
  });

  testWidgets('back closes the popup first, and only the popup',
      (tester) async {
    final router = await _conversationWithPopup(tester);
    final root = router.routerDelegate.navigatorKey.currentState;
    expect(await popRootOverlay(root), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Reactions'), findsNothing);
    expect(find.text('Long-press'), findsOneWidget, reason: 'still in it');

    // Nothing over the app now: the press is the router's again.
    expect(await popRootOverlay(root), isFalse);
  });
}
