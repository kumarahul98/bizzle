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
      final lowered = kStuckInfoBody.toLowerCase();
      for (final jargon in <String>[
        'm/s',
        'sample',
        'threshold',
        'polyline',
        'gps',
        'interval',
        'segment',
      ]) {
        expect(
          lowered.contains(jargon),
          isFalse,
          reason: 'stuck explainer must not say "$jargon"',
        );
      }
    });

    test('states the 10 km/h rule and the map floor honestly (D-03)', () {
      expect(kStuckInfoBody, contains('10 km/h'));
      // T-31-03: the sheet must SAY the highlighted stretches add up to less
      // than the printed figure rather than hiding the discrepancy.
      expect(kStuckInfoBody, contains('less than the total'));
      // And it must say breaks are excluded.
      expect(kStuckInfoBody.toLowerCase(), contains('paused'));
    });
  });
}
