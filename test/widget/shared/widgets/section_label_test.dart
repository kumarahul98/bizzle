// ignore_for_file: uri_does_not_exist
// Wave-0 RED test for SectionLabel widget.
//
// This file imports shared/widgets/section_label.dart which does not exist yet.
// The compile failure is the deliberate RED state.
// Plan 03 creates the production widget that turns this GREEN.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/section_label.dart';

void main() {
  group('SectionLabel', () {
    testWidgets('renders text in UPPERCASE', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: SectionLabel(text: 'today'),
            ),
          ),
        ),
      );

      // The widget must display the text in uppercase.
      expect(find.text('TODAY'), findsOneWidget);
    });

    testWidgets('has letterSpacing >= 1.0 on the text style', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: SectionLabel(text: 'this week'),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text).first);
      final letterSpacing = textWidget.style?.letterSpacing ?? 0.0;
      expect(letterSpacing, greaterThanOrEqualTo(1.0));
    });

    testWidgets('uses textMuted token color from TraevyTokensExt', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: SectionLabel(text: 'stats'),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text).first);
      final color = textWidget.style?.color;

      // textMuted in light theme is Color(0xFF9A9AAA).
      expect(color, const Color(0xFF9A9AAA));
    });
  });
}
