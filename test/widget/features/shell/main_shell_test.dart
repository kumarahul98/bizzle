// Wave-0 RED test for MainShell widget — turned GREEN by Plan 04.
//
// Plan 04 created lib/features/shell/main_shell.dart with the MainShell
// ConsumerWidget and lib/features/shell/providers/main_shell_provider.dart
// with mainShellIndexProvider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/shell/main_shell.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';

/// Minimal stub notifier that skips fbs initialisation.
///
/// The real [TrackingNotifier.build] calls FlutterBackgroundService.on,
/// which throws on non-Android/iOS platforms (the test host). This
/// subclass short-circuits [build] to [TrackingIdle] so widget tests
/// that render [MainShell] never touch the platform channel.
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

/// Minimal [StatsSummary] with no trips for a clean test baseline.
StatsSummary _emptyStats() => const StatsSummary(
  weekTotalSeconds: 0,
  weekStuckSeconds: 0,
  monthTotalSeconds: 0,
  toOfficeAvgSeconds: 0,
  toHomeAvgSeconds: 0,
  weekdayAverages: <int?>[null, null, null, null, null, null, null],
  dailyTotalsLast28Days: <int>[
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ],
  hasAnyTrips: false,
);

/// Pump [MainShell] with all required provider overrides so platform channels
/// and Drift I/O are never reached in the test host.
///
/// IndexedStack mounts all four tabs simultaneously, so overrides must cover
/// providers from every tab screen: Dashboard (tracking + trips + stats),
/// History (trips), Stats (stats), and Settings (userPreferenceProvider).
Future<void> _pumpShell(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackingStateProvider.overrideWith(_IdleTrackingNotifier.new),
        allTripSummariesProvider.overrideWith(
          (ref) => Stream<List<TripSummary>>.value(const <TripSummary>[]),
        ),
        statsSummaryProvider.overrideWith(
          (ref) => AsyncValue<StatsSummary>.data(_emptyStats()),
        ),
        // SettingsScreen (mounted by IndexedStack) watches userPreferenceProvider
        // which opens a Drift stream. Override with a completed stream so no
        // pending timers remain after the test tears down.
        userPreferenceProvider.overrideWith(
          (ref) => Stream.value(const UserPreferencesValue.defaults()),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const MainShell(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('MainShell', () {
    testWidgets('mounts under ProviderScope and shows NavigationBar', (
      tester,
    ) async {
      await _pumpShell(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('NavigationBar has exactly four NavigationDestinations', (
      tester,
    ) async {
      await _pumpShell(tester);

      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });

    testWidgets(
      'NavigationBar destination labels are Today, Trips, Stats, Settings',
      (tester) async {
        await _pumpShell(tester);

        // Scope the search to the NavigationBar to avoid collisions with
        // body text that shares the same label string (e.g. the "Today"
        // section header in DashboardScreen).
        final navBar = find.byType(NavigationBar);
        expect(
          find.descendant(of: navBar, matching: find.text('Today')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: navBar, matching: find.text('Trips')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: navBar, matching: find.text('Stats')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: navBar, matching: find.text('Settings')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the Trips destination switches IndexedStack child to HistoryScreen',
      (tester) async {
        await _pumpShell(tester);

        // Initially on Today (index 0) — HistoryScreen should not be visible.
        expect(find.byType(HistoryScreen), findsNothing);

        // Tap the Trips destination.
        await tester.tap(find.text('Trips'));
        await tester.pumpAndSettle();

        // After tapping, HistoryScreen should appear in the IndexedStack.
        expect(find.byType(HistoryScreen), findsOneWidget);
      },
    );

    // Review MEDIUM #4: back button from a non-default tab must NOT pop to
    // Dashboard. Tab switches are state updates on mainShellIndexProvider,
    // not route pushes — so the navigator stack only contains the root
    // MainShell route. handlePopRoute() returns false when nothing was popped.
    testWidgets(
      'back button from non-default tab does NOT pop to dashboard (Review MEDIUM #4)',
      (tester) async {
        await _pumpShell(tester);

        // Switch to the Stats tab (index 2).
        await tester.tap(find.text('Stats'));
        // Use pump with a duration instead of pumpAndSettle — the IndexedStack
        // and NavigationBar animations run for 300ms; pumpAndSettle would time
        // out if any AnimatedOpacity/NavigationBar transition is still active.
        await tester.pump(const Duration(milliseconds: 500));

        // Stats tab is now visible.
        expect(find.byType(StatsScreen), findsOneWidget);

        // Simulate system back button. Returns false when no route was popped
        // — correct for a bottom-nav app where tabs are not pushed routes.
        final popped = await tester.binding.handlePopRoute();
        await tester.pump();

        // handlePopRoute returned false — navigator did not pop any route.
        expect(popped, isFalse);

        // Stats tab is still visible — back did NOT switch back to Dashboard.
        expect(find.byType(StatsScreen), findsOneWidget);

        // DashboardScreen is NOT in the foreground after back press.
        // (It is still mounted by IndexedStack but not the active index.)
        expect(find.byType(DashboardScreen), findsNothing);
      },
    );
  });
}
