// Widget tests for the shared InfoSheet (Phase 31, D-08) — the single
// explanation surface consumed by this phase and by Phases 32 and 33.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/info_sheet.dart';

Widget host(Widget child) => MaterialApp(
  theme: buildLightTheme(),
  home: Scaffold(body: Center(child: child)),
);

/// Words that mean something to whoever wrote the tracking code and nothing
/// to the person reading the sheet. Every explainer body is held to this.
const List<String> _jargon = <String>[
  'm/s',
  'sample',
  'threshold',
  'polyline',
  'gps',
  'interval',
  'segment',
];

void _expectNoJargon(String body, String label) {
  final lowered = body.toLowerCase();
  for (final jargon in _jargon) {
    expect(
      lowered.contains(jargon),
      isFalse,
      reason: '$label must not say "$jargon"',
    );
  }
}

void main() {
  group('InfoIconButton', () {
    testWidgets('renders an info icon and nothing else', (tester) async {
      await tester.pumpWidget(
        host(
          const InfoIconButton(title: kStuckInfoTitle, body: kStuckInfoBody),
        ),
      );
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.text(kStuckInfoTitle), findsNothing);
    });

    testWidgets('tapping opens the explainer sheet with title and body', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const InfoIconButton(title: kStuckInfoTitle, body: kStuckInfoBody),
        ),
      );
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text(kStuckInfoTitle), findsOneWidget);
      expect(find.text(kStuckInfoBody), findsOneWidget);
      expect(find.text(kInfoSheetDismissLabel), findsOneWidget);
    });

    testWidgets('the dismiss button closes the sheet', (tester) async {
      await tester.pumpWidget(
        host(
          const InfoIconButton(title: kStuckInfoTitle, body: kStuckInfoBody),
        ),
      );
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kInfoSheetDismissLabel));
      await tester.pumpAndSettle();

      expect(find.text(kStuckInfoTitle), findsNothing);
    });
  });

  group('stuck-time explainer copy (SC#7)', () {
    test('contains no technical jargon', () {
      _expectNoJargon(kStuckInfoBody, 'stuck explainer');
    });

    test('states the 10 km/h rule and the map floor honestly (D-03, D-4)', () {
      expect(kStuckInfoBody, contains('10 km/h'));
      // D-4 (this quick task): a full edit now RETAINS overlapping stuck
      // segments instead of wiping them, so the sheet no longer claims the
      // painted stretches sum to LESS than the printed total — that
      // invariant is deliberately abandoned for edited trips. It must still
      // say brief halts are left out, and that an edited trip may not add up
      // to the total above.
      expect(kStuckInfoBody.toLowerCase(), contains('brief halts'));
      expect(kStuckInfoBody.toLowerCase(), contains('may not add up'));
      // And it must say breaks are excluded.
      expect(kStuckInfoBody.toLowerCase(), contains('paused'));
    });
  });

  group('weekly summary explainer copy (Phase 32, D-03, SC#6)', () {
    test('contains no technical jargon', () {
      _expectNoJargon(kWeekLossInfoBody, 'weekly summary explainer');
    });

    test('states the Mon-Sun window and that it is not a rolling 7 days', () {
      expect(kWeekLossInfoBody, contains('Monday'));
      expect(kWeekLossInfoBody, contains('Sunday'));
      // The card shows the CURRENT, part-finished week — the distinction the
      // stats service actually implements, and the one a reader assumes wrong.
      expect(kWeekLossInfoBody.toLowerCase(), contains('includes today'));
      expect(kWeekLossInfoBody.toLowerCase(), contains('last seven days'));
    });

    test('states what "lost to traffic" measures', () {
      expect(kWeekLossInfoBody, contains('10 km/h'));
    });

    test('states that break time counts towards neither figure', () {
      expect(kWeekLossInfoBody.toLowerCase(), contains('paused'));
      expect(kWeekLossInfoBody.toLowerCase(), contains('neither'));
    });
  });
}
