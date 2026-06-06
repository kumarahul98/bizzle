// Unit tests for dynamic themeMode wiring in TraevyApp.
//
// These tests verify the _toThemeMode mapping by rendering TraevyApp with
// a mocked userPreferenceProvider that emits specific darkMode string values,
// then asserting the resolved MaterialApp.themeMode.
//
// RED phase: fails until lib/app.dart is updated with dynamic themeMode
// and lib/features/settings/providers/settings_providers.dart is created.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/app.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';

/// Stub notifier that skips flutter_background_service init on test host.
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

/// Pump [TraevyApp] with [darkMode] overridden via [userPreferenceProvider]
/// and return the resolved [MaterialApp.themeMode].
Future<ThemeMode?> _resolvedThemeMode(
  WidgetTester tester,
  String darkMode,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tripsDaoProvider.overrideWithValue(db.tripsDao),
        syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        userPreferencesDaoProvider.overrideWithValue(db.userPreferencesDao),
        directionBackfillProvider.overrideWith((_) async {}),
        trackingStateProvider.overrideWith(_IdleTrackingNotifier.new),
        allTripSummariesProvider.overrideWith(
          (ref) => const Stream<List<TripSummary>>.empty(),
        ),
        // Override the preference stream to emit the desired darkMode value.
        userPreferenceProvider.overrideWith(
          (ref) => Stream.value(
            UserPreferencesValue(
              userId: kDefaultUserId,
              darkMode: darkMode,
              morningCutoffHour: kDefaultDirectionCutoffHour,
              eveningCutoffHour: kDefaultDirectionCutoffHour,
              reminderEnabled: false,
              reminderTime: null,
              weekendReminder: false,
              weeklyNotificationEnabled: false,
              autoPauseEnabled: false,
              // Phase 20: emit a returning-user value so the root gate routes
              // AuthGuest → MainShell (not the first-run LoginScreen). This
              // test asserts only the resolved themeMode; the gate itself is
              // covered by test/widget/app_gate_test.dart.
              hasSeenOnboarding: true,
              homeLat: null,
              homeLng: null,
              officeLat: null,
              officeLng: null,
            ),
          ),
        ),
      ],
      child: const TraevyApp(),
    ),
  );
  await tester.pump();
  await tester.pump();

  return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;
}

void main() {
  group('TraevyApp._toThemeMode via dynamic themeMode wiring', () {
    testWidgets(
      "_toThemeMode('light') resolves MaterialApp.themeMode to ThemeMode.light",
      (tester) async {
        final mode = await _resolvedThemeMode(tester, kDarkModeLight);
        expect(mode, ThemeMode.light);
      },
    );

    testWidgets(
      "_toThemeMode('dark') resolves MaterialApp.themeMode to ThemeMode.dark",
      (tester) async {
        final mode = await _resolvedThemeMode(tester, kDarkModeDark);
        expect(mode, ThemeMode.dark);
      },
    );

    testWidgets(
      "_toThemeMode('system') resolves MaterialApp.themeMode to ThemeMode.system",
      (tester) async {
        final mode = await _resolvedThemeMode(tester, kDarkModeSystem);
        expect(mode, ThemeMode.system);
      },
    );

    testWidgets(
      '_toThemeMode(unknown) resolves MaterialApp.themeMode to ThemeMode.system',
      (tester) async {
        final mode = await _resolvedThemeMode(tester, 'unknown_value');
        expect(mode, ThemeMode.system);
      },
    );
  });
}
