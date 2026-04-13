import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/screens/home_screen.dart';
import 'package:traevy/features/tracking/screens/tracking_screen.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// Minimal test-only `TrackingNotifier` used exclusively by the
/// HomeScreen navigation test. The real notifier wires fbs stream
/// subscriptions that crash in widget tests with
/// `MissingPluginException`; this subclass short-circuits `build` so
/// navigating into the tracking route does not blow up the test
/// isolate.
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
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
/// The mapping from `TrackingPermissionStatus` back to the
/// `permission_handler` `PermissionStatus` the real service expects
/// from its probe/requester closures is documented next to each case.
_PermissionHarness _buildFakePermissionService(
  TrackingPermissionStatus trackingStatus,
) {
  var openCount = 0;
  final PermissionStatus mapped;
  switch (trackingStatus) {
    case TrackingPermissionStatus.fullyGranted:
      // `currentStatus` probes both fine and background; granting
      // both produces `fullyGranted` without ever touching the
      // requester closure.
      mapped = PermissionStatus.granted;
    case TrackingPermissionStatus.foregroundOnly:
      // A full harness for foregroundOnly would need two different
      // probe results (granted for fine, denied for background).
      // HomeScreen treats foregroundOnly exactly like fullyGranted —
      // it navigates to tracking — so the simpler `granted` probe is
      // sufficient for HomeScreen's code path.
      mapped = PermissionStatus.granted;
    case TrackingPermissionStatus.denied:
      mapped = PermissionStatus.denied;
    case TrackingPermissionStatus.permanentlyDenied:
      mapped = PermissionStatus.permanentlyDenied;
  }
  final service = TrackingPermissionService.forTesting(
    probe: (_) async => mapped,
    requester: (_) async => mapped,
    opener: () async {
      openCount++;
      return true;
    },
  );
  return (service: service, openSettingsCalls: () => openCount);
}

Future<void> _pumpHomeScreen(
  WidgetTester tester, {
  required TrackingPermissionService permissionService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackingPermissionServiceProvider.overrideWithValue(permissionService),
        // HomeScreen itself does not read the tracking state provider,
        // but the navigation test pushes TrackingScreen, which does.
        // Override with a no-op notifier so the test isolate never
        // reaches the real fbs singleton.
        trackingStateProvider.overrideWith(_IdleTrackingNotifier.new),
      ],
      child: MaterialApp(
        home: const HomeScreen(),
        routes: kAppRoutes,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('HomeScreen permission paths', () {
    testWidgets('renders the Start commute button', (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpHomeScreen(tester, permissionService: harness.service);

      expect(
        find.widgetWithText(FilledButton, 'Start commute'),
        findsOneWidget,
      );
    });

    testWidgets(
        'tapping Start with fullyGranted navigates to the tracking route',
        (tester) async {
      final harness =
          _buildFakePermissionService(TrackingPermissionStatus.fullyGranted);
      await _pumpHomeScreen(tester, permissionService: harness.service);

      expect(find.byType(TrackingScreen), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Start commute'));
      // Two pumps: one for the async currentStatus() microtask, one
      // for the Navigator.pushNamed route transition frame.
      await tester.pump();
      await tester.pump();
      // Let the route-push animation settle without triggering the
      // tracking notifier's periodic rebuilds (there are none — our
      // _IdleTrackingNotifier never changes state).
      await tester.pumpAndSettle();

      expect(find.byType(TrackingScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets(
        'tapping Start with permanentlyDenied shows the settings dialog '
        'instead of navigating', (tester) async {
      final harness = _buildFakePermissionService(
        TrackingPermissionStatus.permanentlyDenied,
      );
      await _pumpHomeScreen(tester, permissionService: harness.service);

      await tester.tap(find.widgetWithText(FilledButton, 'Start commute'));
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
        'tapping Open settings in the dialog invokes '
        'TrackingPermissionService.openSystemSettings', (tester) async {
      final harness = _buildFakePermissionService(
        TrackingPermissionStatus.permanentlyDenied,
      );
      await _pumpHomeScreen(tester, permissionService: harness.service);

      await tester.tap(find.widgetWithText(FilledButton, 'Start commute'));
      await tester.pump();
      await tester.pump();

      expect(
        find.widgetWithText(FilledButton, 'Open settings'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Open settings'));
      // Dialog close + async openSystemSettings microtask.
      await tester.pump();
      await tester.pump();

      expect(harness.openSettingsCalls(), 1);
      // Dialog dismissed; still on HomeScreen; still not on the tracking
      // route.
      expect(find.text('Location permission denied'), findsNothing);
      expect(find.byType(TrackingScreen), findsNothing);
    });
  });
}
