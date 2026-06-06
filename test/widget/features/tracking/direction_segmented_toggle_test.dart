import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/tracking/widgets/direction_segmented_toggle.dart';

/// Widget tests for [DirectionSegmentedToggle] (TRACK-12, D-04).
///
/// The toggle is a controlled `SegmentedButton<String>` over the
/// kDirectionToOffice / kDirectionToHome constants: both options visible,
/// one tap selects, parent owns the selected value.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: buildLightTheme(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets(
    'tapping the To home segment invokes onSelected with kDirectionToHome',
    (tester) async {
      final selections = <String>[];
      await tester.pumpWidget(
        wrap(
          DirectionSegmentedToggle(
            selected: kDirectionToOffice,
            onSelected: selections.add,
          ),
        ),
      );

      // Both options are visible.
      expect(find.text(kDirectionToOfficeLabel), findsOneWidget);
      expect(find.text(kDirectionToHomeLabel), findsOneWidget);

      await tester.tap(find.text(kDirectionToHomeLabel));
      await tester.pumpAndSettle();

      expect(selections, <String>[kDirectionToHome]);
    },
  );

  testWidgets(
    'tapping the To office segment invokes onSelected with kDirectionToOffice',
    (tester) async {
      final selections = <String>[];
      await tester.pumpWidget(
        wrap(
          DirectionSegmentedToggle(
            selected: kDirectionToHome,
            onSelected: selections.add,
          ),
        ),
      );

      await tester.tap(find.text(kDirectionToOfficeLabel));
      await tester.pumpAndSettle();

      expect(selections, <String>[kDirectionToOffice]);
    },
  );

  testWidgets('selected value reflects the passed direction', (tester) async {
    await tester.pumpWidget(
      wrap(
        DirectionSegmentedToggle(
          selected: kDirectionToHome,
          onSelected: (_) {},
        ),
      ),
    );

    final button = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(button.selected, <String>{kDirectionToHome});

    // Re-pump with the opposite value and assert the selection follows.
    await tester.pumpWidget(
      wrap(
        DirectionSegmentedToggle(
          selected: kDirectionToOffice,
          onSelected: (_) {},
        ),
      ),
    );
    final button2 = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(button2.selected, <String>{kDirectionToOffice});
  });

  testWidgets('disabled toggle does not fire onSelected', (tester) async {
    final selections = <String>[];
    await tester.pumpWidget(
      wrap(
        DirectionSegmentedToggle(
          selected: kDirectionToOffice,
          onSelected: selections.add,
          enabled: false,
        ),
      ),
    );

    await tester.tap(find.text(kDirectionToHomeLabel));
    await tester.pumpAndSettle();

    expect(selections, isEmpty);
  });
}
