// Platform seam for the tracking event bus.
//
// This file is the ONLY place that abstracts the tracking event channels. It
// defines the platform-agnostic [TrackingEventSource] interface that both the
// Android fbs path and the iOS main-isolate engine implement.
//
// Android path ([FbsTrackingEventSource]) is a thin 1:1 passthrough to the
// `FlutterBackgroundService` singleton — it adds NO behaviour of its own.
// `tracking_service.dart` (the fbs background-isolate entrypoint) is NOT
// modified; its behaviour is byte-for-byte identical after this refactor
// (D-08 regression guard from 14-CONTEXT.md).
//
// iOS path ([MainIsolateTrackingEngine]) is defined in its own file
// `main_isolate_tracking_engine.dart` and runs the geolocator stream on the
// main isolate without touching flutter_background_service at all (D-01).
//
// TrackingNotifier (tracking_providers.dart — Plan 03) subscribes to the
// [TrackingEventSource] interface rather than to FlutterBackgroundService
// directly. Platform selection happens at provider construction time.

import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';

/// Platform-agnostic event bus for the tracking feature.
///
/// Both the Android fbs path and the iOS main-isolate engine implement this
/// interface so `TrackingNotifier` can subscribe to identical
/// `Map<String, dynamic>?` stream shapes regardless of platform.
///
/// Stream shapes mirror what `tracking_service.dart` has always emitted:
///   - [onState]     — `accumulator.snapshot(now).toMap()` at 1 Hz
///   - [onFinalized] — `FinalizedTrip.toMap()` on Stop
///   - [onError]     — `{'reason': <stableTag>}` on stream failure
///   - [onReady]     — Android only (D-14 race resolution); iOS = empty stream
abstract interface class TrackingEventSource {
  /// 1 Hz accumulator snapshots while a trip is active.
  Stream<Map<String, dynamic>?> get onState;

  /// FinalizedTrip payload emitted once when Stop completes.
  Stream<Map<String, dynamic>?> get onFinalized;

  /// Error payload `{'reason': <stableTag>}` on mid-trip stream failure.
  /// The reason is always a stable short string — never `error.toString()`.
  Stream<Map<String, dynamic>?> get onError;

  /// Service-ready signal. Android emits this after `setAsForegroundService`
  /// so the D-14 race (fbs placeholder overwriting the Stop-action
  /// notification) can be resolved. iOS returns `const Stream.empty()` — no
  /// fbs, no ready signal (D-07: CoreLocation shows its own indicator).
  Stream<Map<String, dynamic>?> get onReady;

  /// Start tracking. Returns `true` if the underlying service/engine started
  /// successfully, `false` if a pre-flight check blocked the start.
  Future<bool> start();

  /// Stop tracking. Fire-and-forget; the engine responds asynchronously via
  /// [onFinalized].
  Future<void> stop();
}

/// Android implementation of [TrackingEventSource]. Thin passthrough to the
/// [FlutterBackgroundService] singleton — every method and getter delegates
/// directly with no added logic (D-08: Android path unchanged).
///
/// Channels map 1:1 to the event-name constants in
/// `tracking_service_events.dart`:
///   - [onState]     → `service.on(kTrackingStateEvent)`
///   - [onFinalized] → `service.on(kTripFinalizedEvent)`
///   - [onError]     → `service.on(kTrackingErrorEvent)`
///   - [onReady]     → `service.on(kServiceReadyEvent)`
///   - [start]       → `service.startService()`
///   - [stop]        → `service.invoke(kStopTrackingEvent)`
final class FbsTrackingEventSource implements TrackingEventSource {
  /// Construct the Android wrapper around the given `service`.
  ///
  /// Production code passes `FlutterBackgroundService()` (the factory
  /// singleton). Tests can inject a fake implementation.
  const FbsTrackingEventSource(this._service);

  final FlutterBackgroundService _service;

  @override
  Stream<Map<String, dynamic>?> get onState =>
      _service.on(kTrackingStateEvent);

  @override
  Stream<Map<String, dynamic>?> get onFinalized =>
      _service.on(kTripFinalizedEvent);

  @override
  Stream<Map<String, dynamic>?> get onError =>
      _service.on(kTrackingErrorEvent);

  @override
  Stream<Map<String, dynamic>?> get onReady =>
      _service.on(kServiceReadyEvent);

  @override
  Future<bool> start() => _service.startService();

  @override
  Future<void> stop() async {
    _service.invoke(kStopTrackingEvent);
  }
}
