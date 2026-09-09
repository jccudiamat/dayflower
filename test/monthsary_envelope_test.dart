import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/features/greetings/presentation/monthsary_envelope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Both partners get their own unopened envelope and can reopen it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> showFor(String user) async {
      await tester.pumpWidget(ProviderScope(key: ValueKey(user), overrides: [
        currentUserIdProvider.overrideWithValue(user),
        pairGreetingProvider.overrideWith((ref) async => {
          'id': 'monthsary-53', 'title': 'Happy 53rd Monthsary to us!',
          'message': '53 months of choosing each other.', 'artwork': 'monthsary_53',
        }),
      ], child: const MaterialApp(home: Scaffold(body: SafeArea(child: MonthsaryEnvelope())))));
      await tester.pumpAndSettle();
    }
    await showFor('partner-a');
    expect(find.text('A little surprise for us'), findsOneWidget);
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('Happy 53rd Monthsary to us!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close greeting'));
    await tester.pumpAndSettle();
    expect(find.text('Open our greeting again'), findsOneWidget);
    await showFor('partner-b');
    expect(find.text('A little surprise for us'), findsOneWidget);
    await showFor('partner-a');
    expect(find.text('Open our greeting again'), findsOneWidget);
  });
  testWidgets('No greeting means no envelope', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue('other-user'),
      pairGreetingProvider.overrideWith((ref) async => null),
    ], child: const MaterialApp(home: Scaffold(body: MonthsaryEnvelope()))));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
  });
}
