// Widget tests for the weekly summary explainer on the dashboard's
// "This week" card (Phase 32, D-03, SC#6).
//
// The card's own numbers are covered by the stats tests; what this file owns
// is the info icon beside the heading and the sheet it opens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/dashboard/widgets/week_loss_card.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/shared/widgets/info_sheet.dart';

/// A summary with a non-zero week so the card renders its data branch.
StatsSummary _weekStats() => StatsSummary(
  weekTotalSeconds: 7200,
  weekStuckSeconds: 1800,
  monthTotalSeconds: 7200,
  toOfficeAvgSeconds: 3600,
  toHomeAvgSeconds: 3600,
  weekdayAverages: const <int?>[null, null, null, null, null, null, null],
  dailyTotalsLast28Days: List<int>.filled(28, 0),
  hasAnyTrips: true,
);

Future<void> _pumpCard(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        statsSummaryProvider.overrideWith(
          (ref) => AsyncValue<StatsSummary>.data(_weekStats()),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: WeekLossCard()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('WeekLossCard explainer (SC#6)', () {
    testWidgets('renders an info icon beside the "This week" heading', (
      tester,
    ) async {
      await _pumpCard(tester);

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.byType(InfoIconButton), findsOneWidget);
      // Closed by default — the explanation is opt-in, not a nag.
      expect(find.text(kWeekLossInfoTitle), findsNothing);
    });

    testWidgets('tapping it opens the shared explainer sheet', (tester) async {
      await _pumpCard(tester);

      await tester.tap(find.byType(InfoIconButton));
      await tester.pumpAndSettle();

      expect(find.text(kWeekLossInfoTitle), findsOneWidget);
      expect(find.text(kWeekLossInfoBody), findsOneWidget);
      expect(find.text(kInfoSheetDismissLabel), findsOneWidget);
    });

    testWidgets('the sheet dismisses back to the card', (tester) async {
      await _pumpCard(tester);

      await tester.tap(find.byType(InfoIconButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kInfoSheetDismissLabel));
      await tester.pumpAndSettle();

      expect(find.text(kWeekLossInfoTitle), findsNothing);
      expect(find.text('THIS WEEK'), findsOneWidget);
    });
  });
}
