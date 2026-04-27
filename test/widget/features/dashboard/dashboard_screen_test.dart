// Widget tests for DashboardScreen (Phase 6, Plan 01 — RED state).
//
// This file imports dashboard_screen.dart and in_progress_card.dart which
// do not exist yet. The compile failure is the intentional RED state;
// Plans 03–04 create the production widgets that turn it GREEN.
//
// Permission-path tests migrated verbatim from
// test/widget/features/tracking/home_screen_test.dart; class/helper names
// updated to reflect DashboardScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
import 'package:traevy/features/dashboard/widgets/in_progress_card.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/screens/tracking_screen.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/features/trips/widgets/trip_card.dart';
import 'package:uuid/uuid.dart';

/// Minimal test-only `TrackingNotifier` used exclusively by the
/// DashboardScreen navigation test. The real notifier wires fbs stream
/// subscriptions that crash in widget tests with
/// `MissingPluginException`; this subclass short-circuits `build` so
/// navigating into the tracking route does not blow up the test isolate.
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

/// Minimal test-only `TrackingNotifier` that returns [TrackingActive]
/// state for tests that exercise the active-tracking path.
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

/// Build a `TrackingPermissionService` whose `currentStatus` and
/// `preflight` both resolve to the given [trackingStatus]. `opener`
/// returns a callback-recording spy so tests can assert whether
/// `openSystemSettings` was invoked.
///
/// The harness wires a per-permission probe/requester map so that the
/// four-step dance (locationWhenInUse → locationAlways → notification)
/// resolves to the intended tracking status with the minimum number of
/// probe/request calls. The mapping is documented next to each case.
_PermissionHarness _buildFakePermissionService(
  TrackingPermissionStatus trackingStatus,
) {
  var openCount = 0;
  final Map<Permission, PermissionStatus> probeValues;
  final Map<Permission, PermissionStatus> requestValues;
  switch (trackingStatus) {
    case TrackingPermissionStatus.fullyGranted:
      // All three permissions granted on probe — no requests fire.
      probeValues = <Permission, PermissionStatus>{
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.granted,
        Permission.notification: PermissionStatus.granted,
      };
      requestValues = const <Permission, PermissionStatus>{};
    case TrackingPermissionStatus.foregroundOnly:
      // Fine granted, background denied, notification granted. Test
      // paths that care about foregroundOnly go through the tracking
      // screen, not the dashboard screen — DashboardScreen treats
      // foregroundOnly identically to fullyGranted (navigates).
      probeValues = <Permission, PermissionStatus>{
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.denied,
        Permission.notification: PermissionStatus.granted,
      };
      requestValues = const <Permission, PermissionStatus>{};
    case TrackingPermissionStatus.denied:
      // Fine denied on probe — currentStatus short-circuits before
      // touching locationAlways or notification. preflight will call
      // the requester for locationWhenInUse (still denied).
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
      // Location dance resolves (fine + background granted) but the
      // notification probe comes back denied. DashboardScreen uses
      // `currentStatus` which does NOT call the requester, so no
      // notification request value is needed here.
      probeValues = <Permission, PermissionStatus>{
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.granted,
        Permission.notification: PermissionStatus.denied,
      };
      requestValues = const <Permission, PermissionStatus>{};
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
    dailyTotalsLast28Days: <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
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
        // DashboardScreen watches trackingStateProvider — override with a
        // no-op notifier so the test isolate never reaches the real fbs
        // singleton.
        trackingStateProvider.overrideWith(
          trackingNotifierFactory ?? _IdleTrackingNotifier.new,
        ),
        // DashboardScreen watches allTripSummariesProvider (via
        // todaysTripSummariesProvider) — override to avoid real Drift I/O.
        allTripSummariesProvider.overrideWith(
          (ref) => Stream<List<TripSummary>>.value(todayTrips),
        ),
        // DashboardScreen watches statsSummaryProvider — override to avoid
        // real Drift I/O and stats computation.
        statsSummaryProvider.overrideWith(
          (ref) => AsyncValue<StatsSummary>.data(_makeStatsSummary()),
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

void main() {
  group('DashboardScreen', () {
    testWidgets('renders DashboardScreen as app root', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('FAB shows Start commute label when tracking is idle',
        (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.text(kDashboardFabIdleLabel), findsOneWidget);
    });

    testWidgets('FAB shows Go to tracking label when tracking is active',
        (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(
        tester,
        permissionService: harness.service,
        trackingNotifierFactory: _ActiveTrackingNotifier.new,
      );

      expect(find.text(kDashboardFabActiveLabel), findsOneWidget);
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

    testWidgets('shows empty state text when no trips today', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(
        tester,
        permissionService: harness.service,
      );

      expect(find.text(kDashboardEmptyStateLabel), findsOneWidget);
    });

    testWidgets('shows TripCard for each trip today', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(
        tester,
        permissionService: harness.service,
        todayTrips: [_makeToday()],
      );

      expect(find.byType(TripCard), findsOneWidget);
    });

    testWidgets('AppBar has history icon button', (tester) async {
      // Icon must match implementation in dashboard_screen.dart AppBar actions
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('AppBar has stats icon button', (tester) async {
      // Icon must match implementation in dashboard_screen.dart AppBar actions
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });

    // --------------------------------------------------------------------------
    // Permission-path tests — migrated verbatim from home_screen_test.dart.
    // HomeScreen → DashboardScreen, _pumpHomeScreen → _pumpDashboardScreen.
    // --------------------------------------------------------------------------

    testWidgets(
        'tapping FAB when idle with permanentlyDenied shows settings dialog '
        'instead of navigating', (tester) async {
      final harness = _buildFakePermissionService(
        TrackingPermissionStatus.permanentlyDenied,
      );
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      await tester.tap(find.text(kDashboardFabIdleLabel));
      await tester.pump();
      await tester.pump();

      // Dialog is present, tracking route is NOT.
      expect(find.text('Location permission denied'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Open settings'),
        findsOneWidget,
      );
      expect(find.byType(TrackingScreen), findsNothing);
      expect(harness.openSettingsCalls(), 0);
    });

    testWidgets(
        'tapping FAB when idle with notificationDenied shows notification '
        'dialog and does NOT navigate to the tracking route', (tester) async {
      // UX-03 gap-closure: POST_NOTIFICATIONS denial is a hard block
      // because the foreground notification cannot be shown on Android
      // 13+ without it. DashboardScreen must short-circuit Start the same
      // way it does for permanentlyDenied.
      final harness = _buildFakePermissionService(
        TrackingPermissionStatus.notificationDenied,
      );
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      await tester.tap(find.text(kDashboardFabIdleLabel));
      await tester.pump();
      await tester.pump();

      expect(find.text('Notifications required'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Open settings'),
        findsOneWidget,
      );
      expect(find.byType(TrackingScreen), findsNothing);
      expect(harness.openSettingsCalls(), 0);
    });

    testWidgets(
        'tapping FAB when idle with fullyGranted navigates to tracking screen',
        (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpDashboardScreen(tester, permissionService: harness.service);

      expect(find.byType(TrackingScreen), findsNothing);

      await tester.tap(find.text(kDashboardFabIdleLabel));
      // Two pumps: one for the async currentStatus() microtask, one
      // for the Navigator.pushNamed route transition frame.
      await tester.pump();
      await tester.pump();
      // Let the route-push animation settle without triggering the
      // tracking notifier's periodic rebuilds (there are none — our
      // _IdleTrackingNotifier never changes state).
      await tester.pumpAndSettle();

      expect(find.byType(TrackingScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    });
  });
}
