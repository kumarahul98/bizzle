import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/screens/tracking_screen.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/tracking/widgets/elapsed_display.dart';
import 'package:traevy/features/tracking/widgets/recording_header.dart';
import 'package:traevy/features/tracking/widgets/stop_button.dart';

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
  int persistFinalizedTripCallCount = 0;

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
    // Mirror production: the state transition to TrackingStopping
    // happens SYNCHRONOUSLY before any await so a double-tap second
    // invocation short-circuits on the guard (WR-04).
    // `persistFinalizedTripCallCount` counts how many times the stop
    // command would have reached the controller-backed persist path.
    if (state is! TrackingActive) return;
    state = const TrackingStopping();
    persistFinalizedTripCallCount++;
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
      child: MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: const TrackingScreen(),
      ),
    ),
  );
  // One pump to flush the post-frame preflight callback and its
  // setState; after this the screen is rendering [initialState] with
  // the permission status resolved to fullyGranted.
  await tester.pump();
  return notifier;
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('TrackingScreen sealed-state rendering', () {
    testWidgets('TrackingIdle renders zeroed tiles and a Start button',
        (tester) async {
      await _pumpTrackingScreen(tester);

      // Tile labels are now uppercase StatMiniCard labels (value and unit
      // rendered as separate Text widgets inside StatMiniCard).
      expect(find.text('STUCK'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('SPEED'), findsOneWidget);
      // Idle distance value '0' and unit 'm' rendered separately.
      expect(find.text('0'), findsWidgets);
      expect(find.text('m'), findsWidgets);
      // Speed unit renders 'km/h'.
      expect(find.text('km/h'), findsWidgets);
      // Start CTA present; Stop button absent.
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
      expect(find.byType(StopButton), findsNothing);
    });

    testWidgets('TrackingStarting renders a spinner and no Stop button',
        (tester) async {
      await _pumpTrackingScreen(
        tester,
        initialState: const TrackingStarting(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Starting GPS...'), findsOneWidget);
      expect(find.byType(StopButton), findsNothing);
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

      // Active layout renders ElapsedDisplay.
      expect(find.byType(ElapsedDisplay), findsOneWidget);
      // 2340 m = 2.34 km; value and unit are separate Text widgets.
      expect(find.text('2.34'), findsOneWidget);
      expect(find.text('km'), findsWidgets);
      // Speed: value '27', unit 'km/h'.
      expect(find.text('27'), findsOneWidget);
      expect(find.text('km/h'), findsWidgets);
      // Variant A active layout uses StopButton (not FilledButton).
      expect(find.byType(StopButton), findsOneWidget);
      // RecordingHeader must be present in active state.
      expect(find.byType(RecordingHeader), findsOneWidget);
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

      // DistanceTile renders value='450', unit='m' as separate Text widgets.
      expect(find.text('450'), findsOneWidget);
      expect(find.text('m'), findsWidgets);
      // No combined '0.45 km' text — value and unit are split.
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
      // Speed value '9', unit 'km/h' rendered separately.
      expect(find.text('9'), findsWidgets);
      expect(find.text('km/h'), findsWidgets);
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
      expect(find.text('10'), findsOneWidget);

      // 0.3 falls under the 0.5 clamp and renders speed as '0'.
      notifier.state = TrackingActive(
        startedAt: DateTime.utc(2026, 4, 12, 8),
        elapsedSeconds: 61,
        distanceMeters: 500,
        currentSpeedKmh: 0.3,
        timeMovingSeconds: 60,
        timeStuckSeconds: 1,
      );
      await tester.pump();
      // '0' appears in speed tile (and possibly elapsed/stuck tiles).
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('TrackingStopping shows a Saving trip status with a spinner',
        (tester) async {
      await _pumpTrackingScreen(
        tester,
        initialState: const TrackingStopping(),
      );

      expect(find.text('Saving trip...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(StopButton), findsNothing);
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
        'Double-tapping Stop only fires a single persist cycle '
        '(WR-04 guard)',
        (tester) async {
      final notifier = await _pumpTrackingScreen(
        tester,
        initialState: TrackingActive(
          startedAt: DateTime.utc(2026, 4, 12, 8),
          elapsedSeconds: 60,
          distanceMeters: 500,
          currentSpeedKmh: 20,
          timeMovingSeconds: 60,
          timeStuckSeconds: 0,
        ),
      );

      expect(notifier.persistFinalizedTripCallCount, 0);

      // Two rapid Stop taps with no pump between the button handlers —
      // simulates the double-tap race where the user's second tap lands
      // in the same frame, before the service isolate has responded
      // with trip_finalized. The WR-04 fix makes the Active ->
      // Stopping transition synchronous inside TrackingNotifier.stop,
      // so the second tap must short-circuit on the
      // `state is! TrackingActive` guard.
      await tester.tap(find.byType(StopButton));
      await tester.tap(find.byType(StopButton));
      await tester.pump();

      expect(notifier.persistFinalizedTripCallCount, 1);
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
