import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('input hit area does not enlarge the search artwork', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TextField(
          decoration: InputDecoration(
            prefixIcon: AppIcon(CupertinoIcons.search, semanticLabel: 'Search'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(AppIcon)).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byType(SvgPicture)), const Size(24, 24));
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
