import 'dart:io';

import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/widgets/app_snack_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Snackbars sat on top of the tab bar and the chat's text box, and some
/// could not be closed. These build the app's own shape, a page Scaffold
/// inside the shell's Scaffold, and check where a snackbar lands.

const _navHeight = 80.0;

/// The page's Scaffold inside the shell's, as AppShell has it.
Widget _app({
  required Widget page,
  bool withAppSnackBars = true,
}) =>
    MaterialApp(
      theme: AppTheme.current,
      builder: withAppSnackBars
          ? (context, child) => AppSnackBars(child: child!)
          : null,
      home: Scaffold(body: page),
    );

Widget _tabPage() => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Saved'))),
            child: const Text('show'),
          ),
        ),
      ),
      bottomNavigationBar: const SnackBarObstacle(
        child: SizedBox(
            key: ValueKey('nav'),
            height: _navHeight,
            child: ColoredBox(color: Colors.black12)),
      ),
    );

Rect _snackBar(WidgetTester tester) => tester.getRect(find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
    .first);

Future<void> _show(WidgetTester tester) async {
  await tester.tap(find.text('show'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without it, the shell draws a snackbar over the tab bar',
      (tester) async {
    // The bug, kept as a test so the reason for AppSnackBars stays visible:
    // the outermost Scaffold draws it, and that one has no tab bar.
    await tester.pumpWidget(_app(page: _tabPage(), withAppSnackBars: false));
    await _show(tester);
    final nav = tester.getRect(find.byKey(const ValueKey('nav')));
    expect(_snackBar(tester).bottom, greaterThan(nav.top));
  });

  testWidgets('a snackbar sits above the tab bar, not on it', (tester) async {
    await tester.pumpWidget(_app(page: _tabPage()));
    await _show(tester);
    final nav = tester.getRect(find.byKey(const ValueKey('nav')));
    final bar = _snackBar(tester);
    expect(bar.bottom, lessThanOrEqualTo(nav.top - snackBarGap + .5));
    // Right above it, not flung up the screen.
    expect(bar.bottom, greaterThan(nav.top - snackBarGap - 12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('and above a composer at the foot of the page', (tester) async {
    await tester.pumpWidget(_app(
      page: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Sent'))),
                    child: const Text('show'),
                  ),
                ),
              ),
              const SnackBarObstacle(
                child: SizedBox(
                  key: ValueKey('composer'),
                  height: 64,
                  child: TextField(),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await _show(tester);
    final composer = tester.getRect(find.byKey(const ValueKey('composer')));
    expect(_snackBar(tester).bottom,
        lessThanOrEqualTo(composer.top - snackBarGap + .5));
  });

  testWidgets('a text field being typed in is not covered either',
      (tester) async {
    // No obstacle anywhere: a form whose field sits above the keyboard.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    late BuildContext page;
    await tester.pumpWidget(_app(
      page: Scaffold(
        body: Builder(builder: (context) {
          page = context;
          return const Column(
            children: [
              Expanded(child: SizedBox()),
              Padding(
                padding: EdgeInsets.all(16),
                child: TextField(key: ValueKey('field')),
              ),
            ],
          );
        }),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    ScaffoldMessenger.of(page)
        .showSnackBar(const SnackBar(content: Text('Could not save that')));
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byKey(const ValueKey('field')));
    expect(_snackBar(tester).bottom, lessThanOrEqualTo(field.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a field at the top of the screen leaves it where it was',
      (tester) async {
    late BuildContext page;
    await tester.pumpWidget(_app(
      page: Scaffold(
        body: Builder(builder: (context) {
          page = context;
          return const Column(
            children: [
              TextField(key: ValueKey('search')),
              Expanded(child: SizedBox()),
            ],
          );
        }),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('search')));
    await tester.pump();
    ScaffoldMessenger.of(page)
        .showSnackBar(const SnackBar(content: Text('Nothing found')));
    await tester.pumpAndSettle();
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    // 🔴 Lifting it over a search box would put it off the top of the
    // screen, which the Scaffold asserts on.
    expect(_snackBar(tester).bottom, greaterThan(screen.height - 80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tab bar on a page underneath does not count',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.current,
      navigatorKey: navigator,
      builder: (context, child) => AppSnackBars(child: child!),
      home: _tabPage(),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Copied'))),
            child: const Text('show'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await _show(tester);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    // Lifted over a tab bar that is not on screen, it would float in the
    // middle of the page for no reason.
    expect(_snackBar(tester).bottom, greaterThan(screen.height - _navHeight));
  });

  testWidgets('every snackbar has an X, even one that asks for none',
      (tester) async {
    late BuildContext page;
    await tester.pumpWidget(_app(
      page: Builder(builder: (context) {
        page = context;
        return const SizedBox.expand();
      }),
    ));
    ScaffoldMessenger.of(page).showSnackBar(const SnackBar(
      content: Text('Link copied'),
      showCloseIcon: false,
      duration: Duration(minutes: 5),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Link copied'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Link copied'), findsNothing, reason: 'the X closes it');
  });

  test('the app shows its snackbars through AppSnackBars', () {
    // ⚠️ Read from the source: the app's root needs Supabase, which a test
    // does not have. Without this line every rule above is off.
    expect(File('lib/app.dart').readAsStringSync(), contains('AppSnackBars('));
  });
}
