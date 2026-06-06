// iOS main-isolate GPS tracking engine.
//
// IMPORTANT — PII guard (T-02-07):
// * This engine runs in the SAME process as the UI isolate. Raw Position
//   lat/lng fields are PII. This file MUST NEVER log a Position or forward
//   raw exception text. Only the encoded polyline egresses via
//   FinalizedTrip.toMap(). Grep acceptance criterion enforces this.
// * Error forwarding: forward ONLY the stable tag 'position_stream_error' —
//   never the raw exception message.
//
// iOS does not use flutter_background_service (D-01): BGTaskScheduler is
// periodic, not continuous, and would risk OS termination mid-commute.
// Instead, the Geolocator position stream runs here on the main isolate
// under CoreLocation's `location` background mode (UIBackgroundModes:location
// already in Info.plist + AppleSettings.allowBackgroundLocationUpdates:true).
// CoreLocation shows its own system blue pill indicator (D-07) — no
// flutter_local_notifications foreground notification needed on iOS.
//
// onReady is const Stream.empty() (D-07): no fbs service-ready signal on iOS.
//
// Stop-race ordering mirrors tracking_service.dart lines 139-168:
//   stopping = true  FIRST
//   await positionSub.cancel()
//   timer.cancel()
//   accumulator.finalize(now)
//   emit on onFinalized controller
// A Position arriving after stopping=true sets the flag MUST NOT reach the
// accumulator (the listener early-returns).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/location_settings_builder.dart';
import 'package:traevy/features/tracking/services/tracking_event_source.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';

/// iOS main-isolate implementation of [TrackingEventSource].
///
/// On [start]:
///   1. Constructs a [TripAccumulator] with `DateTime.now().toUtc()`.
///   2. Opens `Geolocator.getPositionStream(locationSettings:
///      buildLocationSettings())` on the main isolate.
///   3. Starts a `Timer.periodic(kTrackingUiUpdateInterval)` that pushes
///      `accumulator.snapshot(now).toMap()` on [onState].
///
/// On [stop]:
///   1. Sets `stopping = true` FIRST (stop-race guard).
///   2. Awaits `positionSub.cancel()`.
///   3. Cancels the UI timer.
///   4. Finalizes the accumulator and pushes `trip.toMap()` on [onFinalized].
///
/// [onReady] is `const Stream.empty()` — no fbs service-ready signal on iOS.
///
/// Injectable seams (for unit tests):
///   - `positionStreamFactory` overrides `Geolocator.getPositionStream(...)`.
///   - `locationSettingsBuilder` overrides `buildLocationSettings()`.
/// Both default to their production implementations when not provided.
final class MainIsolateTrackingEngine implements TrackingEventSource {
  /// Create an iOS main-isolate engine.
  ///
  /// [positionStreamFactory] and [locationSettingsBuilder] are injectable
  /// for unit tests. Production code omits them to use the real Geolocator
  /// stream.
  MainIsolateTrackingEngine({
    Stream<Position> Function(LocationSettings)? positionStreamFactory,
    LocationSettings Function()? locationSettingsBuilder,
  }) : _positionStreamFactory =
           positionStreamFactory ??
           ((settings) => Geolocator.getPositionStream(
             locationSettings: settings,
           )),
       _locationSettingsBuilder =
           locationSettingsBuilder ?? buildLocationSettings;

  final Stream<Position> Function(LocationSettings) _positionStreamFactory;
  final LocationSettings Function() _locationSettingsBuilder;

  final StreamController<Map<String, dynamic>?> _stateController =
      StreamController<Map<String, dynamic>?>.broadcast();
  final StreamController<Map<String, dynamic>?> _finalizedController =
      StreamController<Map<String, dynamic>?>.broadcast();
  final StreamController<Map<String, dynamic>?> _errorController =
      StreamController<Map<String, dynamic>?>.broadcast();

  @override
  Stream<Map<String, dynamic>?> get onState => _stateController.stream;

  @override
  Stream<Map<String, dynamic>?> get onFinalized => _finalizedController.stream;

  @override
  Stream<Map<String, dynamic>?> get onError => _errorController.stream;

  /// iOS has no fbs service-ready signal — CoreLocation shows its own
  /// system background indicator. onReady is always empty (D-07).
  @override
  Stream<Map<String, dynamic>?> get onReady =>
      const Stream<Map<String, dynamic>?>.empty();

  // Internal state — accessed only on the main isolate.
  bool _stopping = false;
  StreamSubscription<Position>? _positionSub;
  Timer? _uiTimer;
  TripAccumulator? _accumulator;

  @override
  Future<bool> start() async {
    _stopping = false;
    _accumulator = TripAccumulator(startedAt: DateTime.now().toUtc());
    final accumulator = _accumulator!;

    final settings = _locationSettingsBuilder();

    _positionSub = _positionStreamFactory(settings).listen(
      (position) {
        // Race guard: a Position can arrive after stop() sets the flag but
        // before cancel() returns. The flag short-circuits those late samples.
        if (_stopping) return;
        accumulator.addSample(position);
      },
      onError: (Object error, StackTrace stack) async {
        // Mid-trip position stream failure.
        // PII guard (T-02-07): DO NOT forward raw platform error text — it
        // can include GPS coordinates. Forward only the stable reason tag.
        if (_stopping) return;
        _stopping = true;
        _uiTimer?.cancel();
        await _positionSub?.cancel();
        _errorController.add(
          const <String, Object?>{'reason': 'position_stream_error'},
        );
      },
      cancelOnError: true,
    );

    _uiTimer = Timer.periodic(kTrackingUiUpdateInterval, (_) {
      if (_stopping) return;
      _stateController.add(
        accumulator.snapshot(DateTime.now().toUtc()).toMap(),
      );
    });

    return true;
  }

  @override
  Future<void> stop() async {
    // Stop-race ordering: set the flag FIRST so any in-flight position
    // listener callback early-returns before the subscription is cancelled.
    // This mirrors the Android isolate's stop-race guard (tracking_service.dart
    // lines 143-168).
    _stopping = true;
    await _positionSub?.cancel();
    _uiTimer?.cancel();
    final accumulator = _accumulator;
    if (accumulator != null) {
      final trip = accumulator.finalize(DateTime.now().toUtc());
      _finalizedController.add(trip.toMap());
    }
  }

  @override
  Future<void> pause() async {
    // Phase 18 (D-08): pause/resume toggle this engine's own accumulator
    // directly — there is no second isolate to invoke. The next uiTimer tick
    // emits a snapshot whose `isPaused` reflects the new state, so the
    // dumb-terminal UI updates from that, not from this call. Guarded by the
    // stop-race flag so a late pause cannot touch a finalized accumulator.
    if (_stopping) return;
    _accumulator?.pause(DateTime.now().toUtc());
  }

  @override
  Future<void> resume() async {
    if (_stopping) return;
    _accumulator?.resume(DateTime.now().toUtc());
  }

  /// Test-only accessor — exposes the accumulator so stop-race tests can
  /// inspect counters without reading raw coordinates (PII guard).
  @visibleForTesting
  TripAccumulator? get accumulatorForTest => _accumulator;
}
