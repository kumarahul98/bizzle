import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/app.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/shell/main_shell.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';

/// Minimal stub notifier that skips fbs initialisation.
///
/// The real [TrackingNotifier.build] calls FlutterBackgroundService.on,
/// which throws on non-Android/iOS platforms (the test host). This
/// subclass short-circuits [build] to [TrackingIdle] so widget tests
/// that render DashboardScreen inside [MainShell] never touch the
/// platform channel.
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

void main() {
  testWidgets(
    'TraevyApp builds under ProviderScope and shows MainShell with NavigationBar',
    (tester) async {
      // MainShell mounts DashboardScreen, which watches trackingStateProvider,
      // allTripSummariesProvider, and statsSummaryProvider.
      // Override all providers to avoid file I/O and platform channel calls.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            tripsDaoProvider.overrideWithValue(db.tripsDao),
            syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
            userPreferencesDaoProvider.overrideWithValue(
              db.userPreferencesDao,
            ),
            directionBackfillProvider.overrideWith((_) async {}),
            trackingStateProvider.overrideWith(_IdleTrackingNotifier.new),
            // DashboardScreen watches allTripSummariesProvider via
            // todaysTripSummariesProvider — override to avoid Drift I/O.
            allTripSummariesProvider.overrideWith(
              (ref) => const Stream<List<TripSummary>>.empty(),
            ),
            // TraevyApp now watches userPreferenceProvider (D-04 dynamic
            // themeMode). Override with a completed stream so Drift's
            // stream-close timer does not remain pending after test teardown.
            //
            // Phase 20: the root gate routes a guest with
            // hasSeenOnboarding=false to the LoginScreen. This test asserts
            // the MainShell renders, so emit a returning-user value
            // (hasSeenOnboarding=true) — the first-run gate itself is covered
            // by test/widget/app_gate_test.dart.
            userPreferenceProvider.overrideWith(
              (ref) => Stream.value(
                const UserPreferencesValue(
                  userId: kDefaultUserId,
                  darkMode: kDarkModeSystem,
                  morningCutoffHour: kDefaultDirectionCutoffHour,
                  eveningCutoffHour: kDefaultDirectionCutoffHour,
                  reminderEnabled: false,
                  reminderTime: null,
                  weekendReminder: false,
                  weeklyNotificationEnabled: false,
                  autoPauseEnabled: false,
                  hasSeenOnboarding: true,
                  homeLat: null,
                  homeLng: null,
                  officeLat: null,
                  officeLng: null,
                  backfillMarkerVersion: 0,
                ),
              ),
            ),
          ],
          child: const TraevyApp(),
        ),
      );
      // Two pumps: resolve the stream emission and settle initial frame.
      // pumpAndSettle cannot be used here because statsSummaryProvider
      // is in loading state (stream.empty() never emits) which keeps
      // CircularProgressIndicator animating indefinitely.
      await tester.pump();
      await tester.pump();

      // Root widget tree is a MaterialApp — proves the wiring through
      // ProviderScope reached TraevyApp without throwing.
      expect(find.byType(MaterialApp), findsOneWidget);

      // Phase 8 mounts MainShell as the app root (UX-01).
      expect(find.byType(MainShell), findsOneWidget);

      // NavigationBar with four destinations confirms the shell rendered.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    },
  );
}
