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

  /// Auto-pause prompt signal (Phase 18 Plan 04, D-11/D-12). Emitted ONCE per
  /// uninterrupted stationary streak when the trip looks stuck beyond the
  /// threshold and is not already paused. Carries NO payload — only the signal.
  /// The UI isolate (`TrackingNotifier`) posts the actual notification, and
  /// ONLY when the user has opted into auto-pause (so OFF → no prompt, SC#5).
  Stream<Map<String, dynamic>?> get onAutoPausePrompt;

  /// Fires when the user taps Pause on the auto-pause prompt notification
  /// (2026-07-21, D-02). The UI shows a confirmation dialog; NOTHING is paused
  /// until the user confirms.
  Stream<Map<String, dynamic>?> get onAutoPauseConfirmRequest;

  /// Fires when the user taps Stop on the recording notification (Phase 36,
  /// D-04). The UI shows a confirmation dialog; NOTHING is stopped until the
  /// user confirms.
  Stream<Map<String, dynamic>?> get onStopConfirmRequest;

  /// Tell the service that a live UI isolate received [onStopConfirmRequest]
  /// (Phase 36, T-36-06).
  ///
  /// Must be called on RECEIPT, not on the user's answer. Its only claim is
  /// that the relay landed somewhere capable of asking them — an unacked relay
  /// means the Stop button has silently become a no-op, and the service stops
  /// the trip itself rather than stranding the user with one they cannot end.
  void acknowledgeStopConfirm();

  /// Start tracking. Returns `true` if the underlying service/engine started
  /// successfully, `false` if a pre-flight check blocked the start.
  Future<bool> start({Map<String, dynamic>? initialAccumulatorState});

  /// Stop tracking. Fire-and-forget; the engine responds asynchronously via
  /// [onFinalized].
  Future<void> stop();

  /// Suspend the current trip without ending it (Phase 18, D-08). The trip
  /// keeps recording as ONE continuous record; the accumulator opens a break
  /// span. Fire-and-forget: the engine reflects the paused state on the next
  /// `onState` snapshot (`isPaused: true`), never synchronously.
  Future<void> pause();

  /// Resume a paused trip (Phase 18, D-08). Closes the open break span; the
  /// next `onState` snapshot carries `isPaused: false`.
  Future<void> resume();
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
  Stream<Map<String, dynamic>?> get onState => _service.on(kTrackingStateEvent);

  @override
  Stream<Map<String, dynamic>?> get onFinalized =>
      _service.on(kTripFinalizedEvent);

  @override
  Stream<Map<String, dynamic>?> get onError => _service.on(kTrackingErrorEvent);

  @override
  Stream<Map<String, dynamic>?> get onReady => _service.on(kServiceReadyEvent);

  @override
  Stream<Map<String, dynamic>?> get onAutoPauseConfirmRequest =>
      _service.on(kAutoPauseConfirmEvent);

  // The duplicated `@override` that used to sit above this getter (and left
  // this one without any) was a copy-paste slip in 318b005. Harmless — it
  // analyzed clean either way — but corrected here rather than left to be
  // pattern-matched by the next person adding a member.
  @override
  Stream<Map<String, dynamic>?> get onAutoPausePrompt =>
      _service.on(kAutoPausePromptEvent);

  @override
  Stream<Map<String, dynamic>?> get onStopConfirmRequest =>
      _service.on(kStopConfirmEvent);

  @override
  void acknowledgeStopConfirm() => _service.invoke(kStopConfirmAckCommand);

  @override
  Future<bool> start({Map<String, dynamic>? initialAccumulatorState}) async {
    final started = await _service.startService();
    if (started && initialAccumulatorState != null) {
      _service.invoke(kSetInitialStateCommand, {
        'initialState': initialAccumulatorState,
      });
    }
    return started;
  }

  @override
  Future<void> stop() async {
    _service.invoke(kStopTrackingEvent);
  }

  @override
  Future<void> pause() async {
    // ONLY the command name (a primitive String) crosses the isolate
    // boundary — no payload (T-18-08). The service-isolate handler routes on
    // the channel name alone.
    _service.invoke(kTrackingPauseCommand);
  }

  @override
  Future<void> resume() async {
    _service.invoke(kTrackingResumeCommand);
  }
}
