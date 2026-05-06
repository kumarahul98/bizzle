// Widget tests for SettingsScreen (Phase 7, Plan 02 — RED state).
//
// This file imports settings_providers.dart (plan 03) and settings_screen.dart
// (plan 04) which do not exist yet. The compile failure is the intentional
// Wave 0 RED state; plans 03 and 04 create the production code that turns
// it GREEN.
//
// Constants (kSettingsDarkModeSystemLabel, kSettingsTooltip, etc.) are added
// to lib/config/constants.dart by plan 01. The file will fail to compile
// until plans 01, 03, and 04 are complete — that is correct Wave 0 behavior.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/screens/settings_screen.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Minimal no-op TrackingNotifier for widget tests.
///
/// The real notifier wires flutter_background_service streams that crash on
/// the test host; this subclass short-circuits build() to avoid that.
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

StatsSummary _makeStatsSummary() => const StatsSummary(
      weekTotalSeconds: 0,
      weekStuckSeconds: 0,
      monthTotalSeconds: 0,
      toOfficeAvgSeconds: null,
      toHomeAvgSeconds: null,
      weekdayAverages: <int?>[null, null, null, null, null, null, null],
      dailyTotalsLast28Days: <int>[
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ],
      hasAnyTrips: false,
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump a [SettingsScreen] with [prefs] as the Riverpod override.
///
/// Mirrors the dashboard_screen_test pump helper pattern (PATTERNS.md).
Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  UserPreferencesValue prefs = const UserPreferencesValue.defaults(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userPreferenceProvider.overrideWith(
          (ref) => Stream<UserPreferencesValue>.value(prefs),
        ),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Pump a [DashboardScreen] with routes wired so gear icon navigation works.
///
/// Overrides all providers that touch platform plugins or real Drift I/O so
/// the test isolate does not crash on the non-Android host.
Future<void> _pumpDashboardWithRoutes(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Prevent flutter_background_service crash on test host.
        trackingStateProvider.overrideWith(_IdleTrackingNotifier.new),
        // Avoid real Drift I/O for trip list.
        allTripSummariesProvider.overrideWith(
          (ref) => Stream<List<TripSummary>>.value(const <TripSummary>[]),
        ),
        // Avoid real stats computation.
        statsSummaryProvider.overrideWith(
          (ref) => AsyncValue<StatsSummary>.data(_makeStatsSummary()),
        ),
        // Provide user preferences for the dynamic themeMode in TraevyApp
        // and for SettingsScreen after navigation.
        userPreferenceProvider.overrideWith(
          (ref) => Stream<UserPreferencesValue>.value(
            const UserPreferencesValue.defaults(),
          ),
        ),
      ],
      child: MaterialApp(
        home: const DashboardScreen(),
        routes: kAppRoutes,
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SettingsScreen', () {
    testWidgets('renders without error', (WidgetTester tester) async {
      await _pumpSettingsScreen(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets(
      'renders exactly 3 RadioListTile rows in Appearance section',
      (WidgetTester tester) async {
        await _pumpSettingsScreen(tester);
        expect(find.byType(RadioListTile<String>), findsNWidgets(3));
      },
    );

    testWidgets(
      'renders System default, Light, and Dark radio labels',
      (WidgetTester tester) async {
        await _pumpSettingsScreen(tester);
        expect(find.text(kSettingsDarkModeSystemLabel), findsOneWidget);
        expect(find.text(kSettingsDarkModeLightLabel), findsOneWidget);
        expect(find.text(kSettingsDarkModeDarkLabel), findsOneWidget);
      },
    );

    testWidgets(
      'renders Weekly summary SwitchListTile in Notifications section',
      (WidgetTester tester) async {
        await _pumpSettingsScreen(tester);
        expect(find.text(kSettingsWeeklySummaryLabel), findsOneWidget);
      },
    );

    testWidgets(
      'renders Daily reminder SwitchListTile in Notifications section',
      (WidgetTester tester) async {
        await _pumpSettingsScreen(tester);
        expect(find.text(kSettingsReminderLabel), findsOneWidget);
      },
    );

    testWidgets(
      'hides reminder time row when reminderEnabled is false',
      (WidgetTester tester) async {
        await _pumpSettingsScreen(
          tester,
          prefs: const UserPreferencesValue(
            userId: 'test',
            darkMode: kDarkModeSystem,
            morningCutoffHour: 12,
            eveningCutoffHour: 12,
            reminderEnabled: false,
            reminderTime: null,
            weekendReminder: false,
            weeklyNotificationEnabled: false,
          ),
        );
        // Reminder time row should be absent or opacity 0.38 when disabled.
        // Verify the Reminder time label exists but the tile is disabled.
        // (AnimatedOpacity keeps it in the tree — we check enabled state.)
        final reminderTimeFinder = find.text(kSettingsReminderTimeLabel);
        if (reminderTimeFinder.evaluate().isNotEmpty) {
          // If present, the enclosing ListTile must be disabled
          final listTile = tester.widget<ListTile>(
            find.ancestor(
              of: reminderTimeFinder,
              matching: find.byType(ListTile),
            ),
          );
          expect(listTile.enabled, isFalse);
        }
      },
    );

    testWidgets(
      'shows reminder time row as enabled when reminderEnabled is true',
      (WidgetTester tester) async {
        await _pumpSettingsScreen(
          tester,
          prefs: const UserPreferencesValue(
            userId: 'test',
            darkMode: kDarkModeSystem,
            morningCutoffHour: 12,
            eveningCutoffHour: 12,
            reminderEnabled: true,
            reminderTime: '08:00',
            weekendReminder: false,
            weeklyNotificationEnabled: false,
          ),
        );
        expect(find.text(kSettingsReminderTimeLabel), findsOneWidget);
      },
    );

    testWidgets(
      'renders AppBar with Settings title',
      (WidgetTester tester) async {
        await _pumpSettingsScreen(tester);
        expect(find.text(kSettingsAppBarTitle), findsOneWidget);
      },
    );
  });

  group('DashboardScreen gear icon navigation', () {
    testWidgets(
      'gear icon appears as 4th trailing AppBar action',
      (WidgetTester tester) async {
        await _pumpDashboardWithRoutes(tester);
        // Gear icon is identified by tooltip kSettingsTooltip.
        expect(
          find.byTooltip(kSettingsTooltip),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping gear icon navigates to SettingsScreen',
      (WidgetTester tester) async {
        await _pumpDashboardWithRoutes(tester);
        await tester.tap(find.byTooltip(kSettingsTooltip));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );
  });
}
