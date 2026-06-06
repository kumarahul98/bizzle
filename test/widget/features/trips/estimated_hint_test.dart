import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/trips/widgets/estimated_hint.dart';
import 'package:traevy/shared/widgets/trip_row_info.dart';

void main() {
  group('EstimatedHint', () {
    Widget host(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: child),
    );

    testWidgets('renders the label and carries the tooltip message', (
      tester,
    ) async {
      await tester.pumpWidget(host(const EstimatedHint()));
      expect(find.text(kEditEstimatedHintLabel), findsOneWidget);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, kEditEstimatedHintTooltip);
    });

    testWidgets('TripRowInfo shows the hint only when isEdited is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const TripRowInfo(
            displayName: 'To office',
            durationLabel: '30m',
            timeRange: '08:00 → 08:30 · 5 km',
            stuckMins: 5,
          ),
        ),
      );
      expect(find.text(kEditEstimatedHintLabel), findsNothing);

      await tester.pumpWidget(
        host(
          const TripRowInfo(
            displayName: 'To office',
            durationLabel: '30m',
            timeRange: '08:00 → 08:30 · 5 km',
            stuckMins: 5,
            isEdited: true,
          ),
        ),
      );
      expect(find.text(kEditEstimatedHintLabel), findsOneWidget);
    });
  });
}
