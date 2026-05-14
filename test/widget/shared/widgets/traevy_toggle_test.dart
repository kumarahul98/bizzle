// ignore_for_file: uri_does_not_exist
// Wave-0 RED test for TraevyToggle widget.
//
// This file imports shared/widgets/traevy_toggle.dart which does not exist yet.
// The compile failure is the deliberate RED state.
// Plan 03 creates the production widget that turns this GREEN.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/traevy_toggle.dart';

void main() {
  group('TraevyToggle', () {
    testWidgets(
      'off state: renders borderStr background with knob aligned left',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildLightTheme(),
              home: Scaffold(
                body: TraevyToggle(
                  value: false,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        expect(find.byType(TraevyToggle), findsOneWidget);

        // The toggle pill should exist and the knob must be on the left side.
        // When value=false the knob alignment should be Alignment.centerLeft.
        final alignWidgets = tester.widgetList<Align>(find.byType(Align));
        final leftAligned = alignWidgets.any(
          (a) => a.alignment == Alignment.centerLeft,
        );
        expect(leftAligned, isTrue);
      },
    );

    testWidgets('on state: renders moving background with knob aligned right', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: TraevyToggle(
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TraevyToggle), findsOneWidget);

      // When value=true the knob alignment should be Alignment.centerRight.
      final alignWidgets = tester.widgetList<Align>(find.byType(Align));
      final rightAligned = alignWidgets.any(
        (a) => a.alignment == Alignment.centerRight,
      );
      expect(rightAligned, isTrue);
    });

    testWidgets('tapping invokes onChanged with the inverted value', (
      WidgetTester tester,
    ) async {
      bool? changedTo;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: TraevyToggle(
                value: false,
                onChanged: (v) => changedTo = v,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TraevyToggle));
      await tester.pump();
      expect(changedTo, isTrue);
    });

    testWidgets('tapping on=true invokes onChanged with false', (
      WidgetTester tester,
    ) async {
      bool? changedTo;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: TraevyToggle(
                value: true,
                onChanged: (v) => changedTo = v,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TraevyToggle));
      await tester.pump();
      expect(changedTo, isFalse);
    });
  });
}
