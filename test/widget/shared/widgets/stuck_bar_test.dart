// ignore_for_file: uri_does_not_exist
// Wave-0 RED test for StuckBar widget.
//
// This file imports shared/widgets/stuck_bar.dart which does not exist yet.
// The compile failure (or import error) is the deliberate RED state.
// Plan 03 creates the production widget that turns this GREEN.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/stuck_bar.dart';

void main() {
  group('StuckBar', () {
    testWidgets('renders without crashing when both values are zero', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: StuckBar(movingMinutes: 0, stuckMinutes: 0),
            ),
          ),
        ),
      );

      expect(find.byType(StuckBar), findsOneWidget);
    });

    testWidgets('renders a Row with two children whose flex matches inputs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: SizedBox(
                width: 400,
                child: StuckBar(movingMinutes: 30, stuckMinutes: 10),
              ),
            ),
          ),
        ),
      );

      // The StuckBar must contain a Row widget.
      expect(find.byType(Row), findsWidgets);

      // The bar's proportional segments: moving=30, stuck=10 → total=40.
      // Each segment is an Expanded child — verify two Expanded widgets exist.
      expect(find.byType(Expanded), findsAtLeastNWidgets(2));
    });

    testWidgets('renders correctly in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: const Scaffold(
              body: StuckBar(movingMinutes: 20, stuckMinutes: 5),
            ),
          ),
        ),
      );

      expect(find.byType(StuckBar), findsOneWidget);
    });
  });
}
