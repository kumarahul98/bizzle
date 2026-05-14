// ignore_for_file: uri_does_not_exist
// Wave-0 RED test for MainShell widget.
//
// This file imports features/shell/main_shell.dart and
// features/trips/screens/history_screen.dart which do not yet exist as part
// of the Phase 8 shell. The compile failure is the deliberate RED state.
// Plan 04 creates the production MainShell that turns this GREEN.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/shell/main_shell.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';

void main() {
  group('MainShell', () {
    testWidgets('mounts under ProviderScope and shows NavigationBar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MainShell(),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('NavigationBar has exactly four NavigationDestinations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MainShell(),
          ),
        ),
      );

      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });

    testWidgets(
      'NavigationBar destination labels are Today, Trips, Stats, Settings',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildLightTheme(),
              home: const MainShell(),
            ),
          ),
        );

        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Trips'), findsOneWidget);
        expect(find.text('Stats'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the Trips destination switches IndexedStack child to HistoryScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildLightTheme(),
              home: const MainShell(),
            ),
          ),
        );

        // Initially on Today (index 0) — HistoryScreen should not be visible.
        expect(find.byType(HistoryScreen), findsNothing);

        // Tap the Trips destination.
        await tester.tap(find.text('Trips'));
        await tester.pumpAndSettle();

        // After tapping, HistoryScreen should appear in the IndexedStack.
        expect(find.byType(HistoryScreen), findsOneWidget);
      },
    );
  });
}
