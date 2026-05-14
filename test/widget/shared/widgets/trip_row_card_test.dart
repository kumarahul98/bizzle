// ignore_for_file: uri_does_not_exist
// Wave-0 RED test for TripRowCard widget.
//
// This file imports shared/widgets/trip_row_card.dart which does not exist yet.
// The compile failure is the deliberate RED state.
// Plan 03 creates the production widget that turns this GREEN.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/trip_row_card.dart';

void main() {
  group('TripRowCard', () {
    testWidgets('renders to_office direction with accentBg avatar', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: TripRowCard(
                direction: kDirectionToOffice,
                durationSeconds: 1800,
                startTime: DateTime(2026, 5, 14, 8, 30),
                endTime: DateTime(2026, 5, 14, 9, 0),
                distanceMeters: 12500,
                stuckSeconds: 300,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TripRowCard), findsOneWidget);
      // Avatar for to_office uses accentBg — verify it exists as a CircleAvatar
      // or Container with specific decoration. At minimum, the widget renders.
      expect(find.byType(CircleAvatar), findsAtLeastNWidgets(1));

      await tester.tap(find.byType(TripRowCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('renders to_home direction with movingBg avatar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: TripRowCard(
                direction: kDirectionToHome,
                durationSeconds: 2100,
                startTime: DateTime(2026, 5, 14, 17, 45),
                endTime: DateTime(2026, 5, 14, 18, 20),
                distanceMeters: 13200,
                stuckSeconds: 600,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TripRowCard), findsOneWidget);
      expect(find.byType(CircleAvatar), findsAtLeastNWidgets(1));
    });

    testWidgets('duration text uses kFontMono family', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: TripRowCard(
                direction: kDirectionToOffice,
                durationSeconds: 1800,
                startTime: DateTime(2026, 5, 14, 8, 30),
                endTime: DateTime(2026, 5, 14, 9, 0),
                distanceMeters: 12500,
                stuckSeconds: 0,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Find a Text widget whose style uses kFontMono (JetBrainsMono).
      final monoTexts = tester.widgetList<Text>(find.byType(Text)).where((t) {
        final style = t.style;
        return style != null && style.fontFamily == kFontMono;
      });
      expect(monoTexts, isNotEmpty);
    });

    testWidgets('tap callback fires on tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: TripRowCard(
                direction: kDirectionToHome,
                durationSeconds: 900,
                startTime: DateTime(2026, 5, 14, 18, 0),
                endTime: DateTime(2026, 5, 14, 18, 15),
                distanceMeters: 5000,
                stuckSeconds: 120,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TripRowCard));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
