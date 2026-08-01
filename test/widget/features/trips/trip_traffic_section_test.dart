import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/trips/widgets/estimated_hint.dart';
import 'package:traevy/features/trips/widgets/trip_traffic_section.dart';
import 'package:traevy/shared/widgets/info_sheet.dart';
import 'package:traevy/shared/widgets/stuck_bar.dart';

void main() {
  group('TripTrafficSection', () {
    Widget host(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: child),
    );

    testWidgets(
      'non-zero traffic renders StuckBar, moving/stuck labels, and the '
      'stuck InfoIconButton',
      (tester) async {
        await tester.pumpWidget(
          host(
            const TripTrafficSection(movingSeconds: 2400, stuckSeconds: 300),
          ),
        );

        expect(find.byType(StuckBar), findsOneWidget);
        expect(find.text('40m moving'), findsOneWidget);
        expect(find.text('5m stuck'), findsOneWidget);
        expect(find.byType(InfoIconButton), findsOneWidget);

        await tester.tap(find.byType(InfoIconButton));
        await tester.pumpAndSettle();
        expect(find.text(kStuckInfoTitle), findsOneWidget);
      },
    );

    testWidgets(
      'a sub-minute stuck value renders "<1m stuck", never "0m stuck" '
      '(regression guard)',
      (tester) async {
        await tester.pumpWidget(
          host(
            const TripTrafficSection(movingSeconds: 3540, stuckSeconds: 30),
          ),
        );

        expect(find.text('<1m stuck'), findsOneWidget);
        expect(find.text('0m stuck'), findsNothing);
      },
    );

    testWidgets(
      'a 0/0 trip shows the no-traffic-data notice instead of StuckBar or '
      'a moving/stuck legend, with a working explainer sheet',
      (tester) async {
        await tester.pumpWidget(
          host(const TripTrafficSection(movingSeconds: 0, stuckSeconds: 0)),
        );

        expect(find.text(kNoTrafficDataLabel), findsOneWidget);
        expect(find.byType(StuckBar), findsNothing);
        expect(find.textContaining('moving'), findsNothing);
        expect(find.textContaining('stuck'), findsNothing);

        await tester.tap(find.byType(InfoIconButton));
        await tester.pumpAndSettle();
        expect(find.text(kNoTrafficDataInfoTitle), findsOneWidget);
      },
    );

    testWidgets('isEdited with non-zero traffic shows the EstimatedHint', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const TripTrafficSection(
            movingSeconds: 2400,
            stuckSeconds: 300,
            isEdited: true,
          ),
        ),
      );

      expect(find.byType(EstimatedHint), findsOneWidget);
    });

    testWidgets(
      'isEdited with 0/0 does NOT show the EstimatedHint — nothing was '
      'estimated',
      (tester) async {
        await tester.pumpWidget(
          host(
            const TripTrafficSection(
              movingSeconds: 0,
              stuckSeconds: 0,
              isEdited: true,
            ),
          ),
        );

        expect(find.byType(EstimatedHint), findsNothing);
      },
    );
  });
}
