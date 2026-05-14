// ignore_for_file: uri_does_not_exist
// Wave-0 RED test for StatMiniCard widget.
//
// This file imports shared/widgets/stat_mini_card.dart which does not exist yet.
// The compile failure is the deliberate RED state.
// Plan 03 creates the production widget that turns this GREEN.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/stat_mini_card.dart';

void main() {
  group('StatMiniCard', () {
    testWidgets('renders label (Inter) and value (JetBrainsMono)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: StatMiniCard(
                label: 'Distance',
                value: '12.5',
                unit: 'km',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StatMiniCard), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('12.5'), findsOneWidget);
      expect(find.text('km'), findsOneWidget);
    });

    testWidgets('value text uses kFontMono family', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: StatMiniCard(
                label: 'Speed',
                value: '42',
                unit: 'km/h',
              ),
            ),
          ),
        ),
      );

      final valueText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere(
            (t) => t.data == '42',
            orElse: () => throw TestFailure('Value text "42" not found'),
          );
      expect(valueText.style?.fontFamily, kFontMono);
    });

    testWidgets('label text uses kFontUI family', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: StatMiniCard(
                label: 'Duration',
                value: '30',
              ),
            ),
          ),
        ),
      );

      final labelText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere(
            (t) => t.data == 'Duration',
            orElse: () => throw TestFailure('Label text "Duration" not found'),
          );
      expect(labelText.style?.fontFamily, kFontUI);
    });

    testWidgets('renders without unit when unit is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: StatMiniCard(
                label: 'Stuck',
                value: '8',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Stuck'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('tone=stuck tints the value with the stuck token color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: StatMiniCard(
                label: 'Stuck',
                value: '8',
                unit: 'min',
                tone: StatMiniCardTone.stuck,
              ),
            ),
          ),
        ),
      );

      final valueText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere(
            (t) => t.data == '8',
            orElse: () => throw TestFailure('Value text "8" not found'),
          );
      // stuck token in light theme is Color(0xFFC4820A).
      expect(valueText.style?.color, const Color(0xFFC4820A));
    });
  });
}
