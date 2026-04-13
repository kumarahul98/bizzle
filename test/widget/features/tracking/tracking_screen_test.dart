import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/screens/tracking_screen.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// Test-only `TrackingNotifier` subclass.
///
/// The production notifier's `build` method attaches to
/// `FlutterBackgroundService().on(...)` streams; calling into the
/// plugin from a widget test raises `MissingPluginException`. This
/// subclass overrides `build` to return the initial state directly so
/// tests can drive state transitions deterministically. `start` is
/// also overridden so the Start-tap test does not reach the real
/// `trackingServiceControllerProvider` (which needs a real Drift
/// database, DAOs, and an fbs singleton).
///
/// The D-10 short-trip snackbar test uses `simulateDiscard`, which
/// consumes the `@visibleForTesting` `setLastPersistResultForTesting`
/// seam added to `TrackingNotifier` by plan 02-05. This plan (02-06)
/// is the first consumer — it does NOT add the seam, it only uses it.
class _TestTrackingNotifier extends TrackingNotifier {
  TrackingState initialState = const TrackingIdle();
  int startCallCount = 0;

  @override
  TrackingState build() {
    // Deliberately skip the super.build() call — that would wire the
    // fbs stream subscriptions, which crash in a widget test with a
    // MissingPluginException.
    return initialState;
  }

  @override
  Future<void> start() async {
    startCallCount++;
    state = const TrackingStarting();
  }

  @override
  Future<void> stop() async {
    // Test notifier never reaches the service isolate — the
    // TrackingStopping transition is driven manually via [setState] or
    // [simulateDiscard].
  }

  /// Deterministically drive the state machine into the post-finalize
  /// state a real `trip_finalized` listener would produce. Used by the
  /// D-10 short-trip snackbar test.
  void simulateDiscard() {
    state = const TrackingStopping();
    setLastPersistResultForTesting(const PersistDiscardedTooShort());
    state = const TrackingIdle();
  }
}

TrackingPermissionService _grantedPermissionService() {
  return TrackingPermissionService.forTesting(
    probe: (_) async => PermissionStatus.granted,
    requester: (_) async => PermissionStatus.granted,
    opener: () async => true,
  );
}

Future<_TestTrackingNotifier> _pumpTrackingScreen(
  WidgetTester tester, {
  TrackingState initialState = const TrackingIdle(),
}) async {
  final notifier = _TestTrackingNotifier()..initialState = initialState;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackingPermissionServiceProvider.overrideWithValue(
          _grantedPermissionService(),
        ),
        trackingStateProvider.overrideWith(() => notifier),
      ],
      child: const MaterialApp(home: TrackingScreen()),
    ),
  );
  // One pump to flush the post-frame preflight callback and its
  // setState; after this the screen is rendering [initialState] with
  // the permission status resolved to fullyGranted.
  await tester.pump();
  return notifier;
}

void main() {
  group('TrackingScreen sealed-state rendering', () {
    testWidgets('TrackingIdle renders zeroed tiles and a Start button',
        (tester) async {
      await _pumpTrackingScreen(tester);

      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Speed'), findsOneWidget);
      // Idle tiles are zero-valued.
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('0 m'), findsOneWidget);
      expect(find.text('0 km/h'), findsOneWidget);
      // Start CTA present; Stop button absent.
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Stop'), findsNothing);
    });

    testWidgets('TrackingStarting renders a spinner and no Stop button',
        (tester) async {
      await _pumpTrackingScreen(
        tester,
        initialState: const TrackingStarting(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Starting GPS...'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Stop'), findsNothing);
    });

    testWidgets('TrackingActive renders live tiles and the Stop button',
        (tester) async {
      await _pumpTrackingScreen(
        tester,
        initialState: TrackingActive(
          startedAt: DateTime.utc(2026, 4, 12, 8),
          elapsedSeconds: 125,
          distanceMeters: 2340,
          currentSpeedKmh: 27,
          timeMovingSeconds: 100,
          timeStuckSeconds: 25,
        ),
      );

      expect(find.text('02:05'), findsOneWidget);
      expect(find.text('2.34 km'), findsOneWidget);
      expect(find.text('27 km/h'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Stop'), findsOneWidget);
    });

    testWidgets('Elapsed >= 3600 seconds formats as HH:MM:SS', (tester) async {
      await _pumpTrackingScreen(
        tester,
        initialState: TrackingActive(
          startedAt: DateTime.utc(2026, 4, 12, 8),
          elapsedSeconds: 3725,
          distanceMeters: 5000,
          currentSpeedKmh: 40,
          timeMovingSeconds: 3700,
          timeStuckSeconds: 25,
        ),
      );

      expect(find.text('01:02:05'), findsOneWidget);
    });

    testWidgets('Distance < 1000 m formats as integer meters', (tester) async {
      await _pumpTrackingScreen(
        tester,
        initialState: TrackingActive(
          startedAt: DateTime.utc(2026, 4, 12, 8),
          elapsedSeconds: 60,
          distanceMeters: 450,
          currentSpeedKmh: 18,
          timeMovingSeconds: 60,
          timeStuckSeconds: 0,
        ),
      );

      expect(find.text('450 m'), findsOneWidget);
      // No distance-in-km formatting should appear — only the speed
      // tile legitimately contains "km" (as "km/h"). Assert the
      // distance tile's alternate "X.XX km" formatting is absent.
      expect(find.textContaining(RegExp(r'\d \.\d+ km$')), findsNothing);
      expect(find.text('0.45 km'), findsNothing);
    });

    testWidgets('Speed rounds correctly at the boundary', (tester) async {
      // 9.4 rounds DOWN to 9.
      await _pumpTrackingScreen(
        tester,
        initialState: TrackingActive(
          startedAt: DateTime.utc(2026, 4, 12, 8),
          elapsedSeconds: 60,
          distanceMeters: 500,
          currentSpeedKmh: 9.4,
          timeMovingSeconds: 0,
          timeStuckSeconds: 60,
        ),
      );
      expect(find.text('9 km/h'), findsOneWidget);
    });

    testWidgets('Speed rounds up at 9.6 and clamps to 0 below 0.5',
        (tester) async {
      // 9.6 rounds UP to 10.
      final notifier = await _pumpTrackingScreen(
        tester,
        initialState: TrackingActive(
          startedAt: DateTime.utc(2026, 4, 12, 8),
          elapsedSeconds: 60,
          distanceMeters: 500,
          currentSpeedKmh: 9.6,
          timeMovingSeconds: 60,
          timeStuckSeconds: 0,
        ),
      );
      expect(find.text('10 km/h'), findsOneWidget);

      // 0.3 falls under the 0.5 clamp and renders as "0 km/h".
      notifier.state = TrackingActive(
        startedAt: DateTime.utc(2026, 4, 12, 8),
        elapsedSeconds: 61,
        distanceMeters: 500,
        currentSpeedKmh: 0.3,
        timeMovingSeconds: 60,
        timeStuckSeconds: 1,
      );
      await tester.pump();
      expect(find.text('0 km/h'), findsOneWidget);
    });

    testWidgets('TrackingStopping shows a Saving trip status with a spinner',
        (tester) async {
      await _pumpTrackingScreen(
        tester,
        initialState: const TrackingStopping(),
      );

      expect(find.text('Saving trip...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Stop'), findsNothing);
    });

    testWidgets('TrackingError shows the message and a Retry button',
        (tester) async {
      await _pumpTrackingScreen(
        tester,
        initialState: TrackingError('GPS unavailable'),
      );

      expect(find.text('GPS unavailable'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });
  });

  group('TrackingScreen interactions', () {
    testWidgets('Tapping Start in TrackingIdle transitions to TrackingStarting',
        (tester) async {
      final notifier = await _pumpTrackingScreen(tester);

      expect(notifier.startCallCount, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pump();

      expect(notifier.startCallCount, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Starting GPS...'), findsOneWidget);
    });

    testWidgets(
        'Short-trip snackbar surfaces after the TrackingStopping -> '
        'TrackingIdle edge with a PersistDiscardedTooShort result',
        (tester) async {
      final notifier = await _pumpTrackingScreen(
        tester,
        initialState: TrackingActive(
          startedAt: DateTime.utc(2026, 4, 12, 8),
          elapsedSeconds: 10,
          distanceMeters: 40,
          currentSpeedKmh: 8,
          timeMovingSeconds: 0,
          timeStuckSeconds: 10,
        ),
      );

      // Drive the exact state sequence the real trip_finalized listener
      // produces on a short trip: Active -> Stopping -> (persist
      // returns PersistDiscardedTooShort) -> Idle. The ref.listen inside
      // TrackingScreen.build fires on the Stopping -> Idle edge and
      // consumes the stashed persist result.
      notifier.simulateDiscard();
      await tester.pump(); // flush the state changes + listen callback
      await tester.pump(); // flush the scheduled SnackBar entry

      expect(find.text('Trip too short to save'), findsOneWidget);
    });
  });
}
