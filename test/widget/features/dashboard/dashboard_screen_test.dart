// Widget tests for DashboardScreen — Phase 8 Plan 04 (GREEN state).
//
// Phase 6 Plan 01 wrote the RED tests with AppBar/FAB assertions that no
// longer apply after the Phase 8 overhaul. This file replaces those with
// layout assertions matching the new design (HeroRecordCard START button,
// HomeHeader, TodaySection, WeekLossCard) while retaining all permission-
// path behavioural tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
import 'package:traevy/features/dashboard/widgets/empty_slot_row.dart';
import 'package:traevy/features/dashboard/widgets/hero_record_card.dart';
import 'package:traevy/features/dashboard/widgets/home_header.dart';
import 'package:traevy/features/dashboard/widgets/in_progress_card.dart';
import 'package:traevy/features/dashboard/widgets/today_section.dart';
import 'package:traevy/features/dashboard/widgets/week_loss_card.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/shared/widgets/trip_row_card.dart';
import 'package:uuid/uuid.dart';

/// Minimal test-only notifier that always returns [TrackingIdle] without
/// wiring any platform channel (avoids MissingPluginException).
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

/// Minimal test-only notifier that returns [TrackingActive] for tests that
/// exercise the active-tracking path.
class _ActiveTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => TrackingActive(
        startedAt: DateTime.now(),
        elapsedSeconds: 600,
        distanceMeters: 3000,
        currentSpeedKmh: 0,
        timeMovingSeconds: 400,
        timeStuckSeconds: 200,
      );
}

typedef _PermissionHarness = ({
  TrackingPermissionService service,
  int Function() openSettingsCalls,
});

/// Build a [TrackingPermissionService] whose `currentStatus` and `preflight`
/// both resolve to the given [trackingStatus]. The returned harness exposes a
/// counter for `openSystemSettings` invocations.
_PermissionHarness _buildFakePermissionService(
  TrackingPermissionStatus trackingStatus,
) {
  var openCount = 0;
  final Map<Permission, PermissionStatus> probeValues;
  final Map<Permission, PermissionStatus> requestValues;
  switch (trackingStatus) {
    case TrackingPermissionStatus.fullyGranted:
      probeValues = <Permission, PermissionStatus>{
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.granted,
        Permission.notification: PermissionStatus.granted,
      };
      requestValues = const <Permission, PermissionStatus>{};
    case TrackingPermissionStatus.foregroundOnly:
      probeValues = <Permission, PermissionStatus>{
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.denied,
        Permission.notification: PermissionStatus.granted,
      };
      requestValues = const <Permission, PermissionStatus>{};
    case TrackingPermissionStatus.denied:
      probeValues = <Permission, PermissionStatus>{
        Permission.locationWhenInUse: PermissionStatus.denied,
      };
      requestValues = <Permission, PermissionStatus>{
        Permission.locationWhenInUse: PermissionStatus.denied,
      };
    case TrackingPermissionStatus.permanentlyDenied:
      probeValues = <Permission, PermissionStatus>{
        Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
      };
      requestValues = const <Permission, PermissionStatus>{};
    case TrackingPermissionStatus.notificationDenied:
      probeValues = <Permission, PermissionStatus>{
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.granted,
        Permission.notification: PermissionStatus.denied,
      };
      // preflight() re-requests when the probe returns denied.
      requestValues = <Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.denied,
      };
  }
  final service = TrackingPermissionService.forTesting(
    probe: (permission) async {
      final result = probeValues[permission];
      if (result == null) {
        throw StateError('Unexpected probe call: $permission');
      }
      return result;
    },
    requester: (permission) async {
      final result = requestValues[permission];
      if (result == null) {
        throw StateError('Unexpected request call: $permission');
      }
      return result;
    },
    opener: () async {
      openCount++;
      return true;
    },
  );
  return (service: service, openSettingsCalls: () => openCount);
}

TripSummary _makeToday() {
  final start = DateTime.now();
  final end = start.add(const Duration(minutes: 30));
  return TripSummary(
    id: const Uuid().v4(),
    startTime: start,
    endTime: end,
    durationSeconds: 1800,
    distanceMeters: 5000,
    direction: kDirectionToOffice,
    timeMovingSeconds: 1200,
    timeStuckSeconds: 600,
    isManualEntry: false,
  );
}

StatsSummary _makeStatsSummary() {
  return const StatsSummary(
    weekTotalSeconds: 7200,
    weekStuckSeconds: 1800,
    monthTotalSeconds: 14400,
    toOfficeAvgSeconds: 1800,
    toHomeAvgSeconds: 1900,
    weekdayAverages: <int?>[1800, 1800, 1800, 1800, 1800, null, null],
    dailyTotalsLast28Days: <int>[
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ],
    hasAnyTrips: true,
  );
}

Future<void> _pumpDashboardScreen(
  WidgetTester tester, {
  required TrackingPermissionService permissionService,
  List<TripSummary> todayTrips = const <TripSummary>[],
  TrackingNotifier Function()? trackingNotifierFactory,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackingPermissionServiceProvider.overrideWithValue(permissionService),
        trackingStateProvider.overrideWith(
          trackingNotifierFactory ?? _IdleTrackingNotifier.new,
        ),
        allTripSummariesProvider.overrideWith(
          (ref) => Stream<List<TripSummary>>.value(todayTrips),
        ),
        statsSummaryProvider.overrideWith(
          (ref) => AsyncValue<StatsSummary>.data(_makeStatsSummary()),
        ),
        // HeroRecordCard reads user prefs to derive direction. Override with
        // a closed stream of defaults so Drift's underlying stream-close
        // timer doesn't leak past widget disposal.
        userPreferenceProvider.overrideWith(
          (ref) => Stream<UserPreferencesValue>.value(
            const UserPreferencesValue.defaults(),
          ),
        ),
      ],
      child: MaterialApp(
        // buildLightTheme() includes TraevyTokensExt — required by
        // HomeHeader, HeroRecordCard, TodaySection, WeekLossCard.
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: const DashboardScreen(),
        routes: kAppRoutes,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('DashboardScreen', () {
    // ------------------------------------------------------------------
    // Layout assertions — Phase 8 Traevy design
    // ------------------------------------------------------------------

    testWidgets('renders DashboardScreen as app root', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('renders HomeHeader', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byType(HomeHeader), findsOneWidget);
    });

    testWidgets('renders HeroRecordCard with START button', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byType(HeroRecordCard), findsOneWidget);
      expect(find.text('START'), findsOneWidget);
    });

    testWidgets('renders TodaySection', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byType(TodaySection), findsOneWidget);
    });

    testWidgets('renders WeekLossCard', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byType(WeekLossCard), findsOneWidget);
    });

    testWidgets('shows InProgressCard when tracking is active', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(
        tester,
        permissionService: harness.service,
        trackingNotifierFactory: _ActiveTrackingNotifier.new,
      );

      expect(find.byType(InProgressCard), findsOneWidget);
    });

    testWidgets('hides InProgressCard when tracking is idle', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byType(InProgressCard), findsNothing);
    });

    testWidgets('shows EmptySlotRow placeholders when no trips today',
        (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(
        tester,
        permissionService: harness.service,
      );

      // TodaySection (08-04) shows EmptySlotRow placeholders for empty
      // state, not the legacy text label.
      expect(find.byType(EmptySlotRow), findsWidgets);
    });

    testWidgets('shows TripRowCard for each trip today', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(
        tester,
        permissionService: harness.service,
        todayTrips: [_makeToday()],
      );

      expect(find.byType(TripRowCard), findsOneWidget);
    });

    // ------------------------------------------------------------------
    // Permission-path tests — preserved from Phase 6 Plan 01.
    // FAB text replaced with 'START' (HeroRecordCard button label).
    // ------------------------------------------------------------------

    testWidgets(
        'tapping START when idle with permanentlyDenied shows settings dialog '
        'instead of navigating', (tester) async {
      final harness = _buildFakePermissionService(
        TrackingPermissionStatus.permanentlyDenied,
      );
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump();

      // Dialog is present; in-place hero remained on the dashboard.
      expect(find.text('Location permission denied'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Open settings'),
        findsOneWidget,
      );
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(harness.openSettingsCalls(), 0);
    });

    testWidgets(
        'tapping START when idle with notificationDenied shows notification '
        'dialog and does NOT navigate to the tracking route', (tester) async {
      final harness = _buildFakePermissionService(
        TrackingPermissionStatus.notificationDenied,
      );
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Notifications required'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Open settings'),
        findsOneWidget,
      );
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(harness.openSettingsCalls(), 0);
    });

    testWidgets(
      'tapping START when idle with fullyGranted invokes notifier.start() '
      '(no navigation — recording transitions in place)',
      (tester) async {
        final harness = _buildFakePermissionService(
          TrackingPermissionStatus.fullyGranted,
        );
        // Capture .start() invocations on the stub notifier.
        final startCalls = <int>[];
        await _pumpDashboardScreen(
          tester,
          permissionService: harness.service,
          trackingNotifierFactory: () =>
              _StartCallNotifier(onStart: () => startCalls.add(1)),
        );

        expect(find.byType(DashboardScreen), findsOneWidget);

        await tester.tap(find.text('START'));
        // Two pumps: one for the async currentStatus() microtask, one for
        // the synchronous TrackingStarting state flip + rebuild.
        await tester.pump();
        await tester.pump();

        expect(startCalls.length, 1);
        // Dashboard stays mounted — no navigation.
        expect(find.byType(DashboardScreen), findsOneWidget);
      },
    );
  });
}

/// Test-only notifier that records .start() invocations without spinning
/// up the foreground service. The hero card transitions through
/// TrackingStarting → TrackingActive on the real path; for this test we
/// only need to confirm the dashboard called notifier.start() exactly once.
class _StartCallNotifier extends TrackingNotifier {
  _StartCallNotifier({required this.onStart});

  final VoidCallback onStart;

  @override
  TrackingState build() => const TrackingIdle();

  @override
  Future<void> start() async {
    onStart();
    state = const TrackingStarting();
  }
}
