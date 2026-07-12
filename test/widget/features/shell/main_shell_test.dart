// Wave-0 RED test for MainShell widget — turned GREEN by Plan 04.
//
// Plan 04 created lib/features/shell/main_shell.dart with the MainShell
// ConsumerWidget and lib/features/shell/providers/main_shell_provider.dart
// with mainShellIndexProvider.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
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
import 'package:traevy/sync/restore_controller.dart';
import 'package:traevy/sync/sync_engine.dart';
import 'package:uuid/uuid.dart';

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

/// Minimal fake [AuthStateNotifier] that returns a fixed [AuthState].
///
/// Extends [AuthStateNotifier] so the `authStateProvider.overrideWith`
/// factory type-check passes (Riverpod 3.x requires the factory to return
/// the exact Notifier subtype declared in the provider). Returns a
/// configurable fixed state without subscribing to Firebase streams.
/// Mirrors `settings_screen_test.dart`'s `_FakeAuthNotifier`.
class _FakeAuthNotifier extends AuthStateNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

/// Fake [RestoreController] whose `restore()` completes instantly with
/// [RestoreSuccess] — keeps `_runAutoRestore()` deterministic (no network,
/// no ApiClient construction) so the backfill sequencing after it can be
/// asserted.
class _FakeRestoreController extends RestoreController {
  @override
  RestoreState build() => const RestoreIdle();

  @override
  Future<void> restore() async {
    state = const RestoreSuccess(0);
  }
}

/// Fake [SyncEngine] exposing only the two members `_runAutoRestore()`
/// touches. Any other access fails fast via noSuchMethod, mirroring the
/// fake style in `settings_screen_test.dart`.
class _FakeSyncEngine implements SyncEngine {
  @override
  void pauseUploads() {}

  @override
  void resumeUploads() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pump [MainShell] with all required provider overrides so platform channels
/// and Drift I/O are never reached in the test host.
///
/// IndexedStack mounts all four tabs simultaneously, so overrides must cover
/// providers from every tab screen: Dashboard (tracking + trips + stats),
/// History (trips), Stats (stats), and Settings (userPreferenceProvider).
///
/// When [db] is provided (Phase 26 backfill tests), the real in-memory
/// [AppDatabase] backs `appDatabaseProvider` (and therefore the trips /
/// sync-queue / user-preferences DAO providers), auth starts at [authState]
/// (default [AuthGuest]), and restore/sync-engine are faked so the sign-in
/// transition sequencing is deterministic.
Future<void> _pumpShell(
  WidgetTester tester, {
  AppDatabase? db,
  AuthState authState = const AuthGuest(),
}) async {
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
        if (db != null) ...[
          appDatabaseProvider.overrideWithValue(db),
          authStateProvider.overrideWith(() => _FakeAuthNotifier(authState)),
          restoreControllerProvider.overrideWith(_FakeRestoreController.new),
          syncEngineProvider.overrideWithValue(_FakeSyncEngine()),
        ],
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

  group('MainShell one-time backfill (Phase 26, D-01/D-02/D-03)', () {
    late AppDatabase db;
    const uuid = Uuid();

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    /// Seed one backfill-candidate trip (isEdited=true) and return its id.
    Future<String> seedEditedTrip() async {
      final id = uuid.v4();
      final start = DateTime.utc(2026, 6, 1, 8);
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: start,
          endTime: start.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          distanceMeters: 5000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 1500,
          timeStuckSeconds: 300,
          isEdited: const Value(true),
        ),
      );
      return id;
    }

    /// Fire the AuthGuest -> AuthSignedIn transition the `ref.listen`
    /// callback in MainShell reacts to, then settle the async
    /// restore-then-backfill sequence (extra pump expires snackbar timers).
    Future<void> signInAndSettle(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainShell)),
      );
      container.read(authStateProvider.notifier).state = const AuthSignedIn(
        uid: 'u',
        name: 'n',
        email: 'e',
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
    }

    testWidgets(
      'sign-in transition enqueues candidate trips once and stamps the marker',
      (tester) async {
        final tripId = await seedEditedTrip();
        expect(await db.userPreferencesDao.getBackfillMarkerVersion(), 0);

        await _pumpShell(tester, db: db);
        await signInAndSettle(tester);

        final pending = await db.syncQueueDao.getPending();
        expect(pending, hasLength(1));
        expect(pending.single.tripId, tripId);
        expect(pending.single.action, kSyncActionUpdate);
        expect(
          await db.userPreferencesDao.getBackfillMarkerVersion(),
          kBackfillMarkerVersion,
        );
      },
    );

    testWidgets(
      'sign-in with marker already stamped enqueues nothing (exactly-once)',
      (tester) async {
        await seedEditedTrip();
        await db.userPreferencesDao.setBackfillMarkerVersion(
          kBackfillMarkerVersion,
        );

        await _pumpShell(tester, db: db);
        await signInAndSettle(tester);

        expect(await db.syncQueueDao.getPending(), isEmpty);
        expect(
          await db.userPreferencesDao.getBackfillMarkerVersion(),
          kBackfillMarkerVersion,
        );
      },
    );
  });
}
