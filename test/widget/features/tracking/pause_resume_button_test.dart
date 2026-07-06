// Widget tests for PauseResumeButton — Phase 18 Plan 03.
//
// The button is a pure stateless toggle: its label/icon are driven entirely
// by the `isPaused` flag (D-08 dumb terminal — no local state), and a tap
// fires `onPressed`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/tracking/widgets/pause_resume_button.dart';

Widget _harness(Widget child) => MaterialApp(
  theme: buildLightTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('PauseResumeButton', () {
    testWidgets('shows the Pause label + pause icon when not paused', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(PauseResumeButton(isPaused: false, onPressed: () {})),
      );

      expect(find.text(kTrackingPauseLabel), findsOneWidget);
      expect(find.text(kTrackingResumeLabel), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('shows the Resume label + play icon when paused', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(PauseResumeButton(isPaused: true, onPressed: () {})),
      );

      expect(find.text(kTrackingResumeLabel), findsOneWidget);
      expect(find.text(kTrackingPauseLabel), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(PauseResumeButton(isPaused: false, onPressed: () => taps++)),
      );

      await tester.tap(find.byType(PauseResumeButton));
      await tester.pump();

      expect(taps, 1);
    });
  });
}
