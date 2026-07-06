// UX-06 overflow regression tests for ElapsedDisplay — Phase 17 Plan 01.
//
// These tests pump ElapsedDisplay into a deliberately narrow 320dp box so the
// 76sp mono timer has a real width constraint to fit into. Before the Task 1
// fix (FittedBox(scaleDown) + maxLines:1 + softWrap:false + full-width box),
// the 76sp timer at 2-digit hours — or under a 2.0 system text-scale —
// overflowed/clipped, surfacing a paint exception via tester.takeException().
// After the fix the glyphs shrink to fit, so each test asserts BOTH the exact
// formatted string AND that no exception was thrown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/tracking/widgets/elapsed_display.dart';

Widget _harness(Widget child) => MaterialApp(
  theme: buildLightTheme(),
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

void main() {
  group('ElapsedDisplay UX-06 overflow', () {
    testWidgets('renders full 99:59:59 without overflow at a narrow width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const ElapsedDisplay(durationSeconds: 359999)),
      );

      expect(find.text('99:59:59'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at textScaler 2.0', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ElapsedDisplay(durationSeconds: 35),
          ),
        ),
      );

      expect(find.text('00:00:35'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('format unchanged regression guard', (tester) async {
      await tester.pumpWidget(
        _harness(const ElapsedDisplay(durationSeconds: 3661)),
      );

      expect(find.text('01:01:01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
