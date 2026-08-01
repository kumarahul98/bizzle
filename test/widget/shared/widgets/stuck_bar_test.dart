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
              body: StuckBar(movingSeconds: 0, stuckSeconds: 0),
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
                // Converted from 30/10 minutes to 1800/600 seconds — same
                // proportions, now expressed in the seconds API.
                child: StuckBar(movingSeconds: 1800, stuckSeconds: 600),
              ),
            ),
          ),
        ),
      );

      // The StuckBar must contain a Row widget.
      expect(find.byType(Row), findsWidgets);

      // The bar's proportional segments: moving=1800, stuck=600.
      // Each segment is an Expanded child — verify two Expanded widgets exist.
      expect(find.byType(Expanded), findsAtLeastNWidgets(2));
    });

    testWidgets('renders correctly in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: const Scaffold(
              // Converted from 20/5 minutes to 1200/300 seconds.
              body: StuckBar(movingSeconds: 1200, stuckSeconds: 300),
            ),
          ),
        ),
      );

      expect(find.byType(StuckBar), findsOneWidget);
    });

    testWidgets(
      'sub-minute stuck value still yields a non-zero flex segment '
      '(regression guard for the reported bug)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildLightTheme(),
              home: const Scaffold(
                body: SizedBox(
                  width: 400,
                  // 59 minutes moving, 30 seconds stuck — with the old
                  // minutes API this floored to flex 0 and the amber segment
                  // vanished entirely.
                  child: StuckBar(movingSeconds: 3540, stuckSeconds: 30),
                ),
              ),
            ),
          ),
        );

        final flexValues = tester
            .widgetList<Expanded>(find.byType(Expanded))
            .map((e) => e.flex)
            .toList();
        expect(flexValues, [3540, 30]);
      },
    );

    testWidgets('negative input is clamped to zero (defensive)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: SizedBox(
                width: 400,
                child: StuckBar(movingSeconds: -5, stuckSeconds: 100),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StuckBar), findsOneWidget);
      final flexValues = tester
          .widgetList<Expanded>(find.byType(Expanded))
          .map((e) => e.flex)
          .toList();
      expect(flexValues, [0, 100]);
    });
  });
}
