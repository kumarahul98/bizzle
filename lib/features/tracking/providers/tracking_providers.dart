import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// Riverpod 3.x wiring for the tracking feature.
///
/// Manual provider declarations (no `@riverpod` annotation) per Phase 1
/// D-12: `riverpod_generator` / `custom_lint` / `riverpod_lint` pin
/// `analyzer ^9` while `drift_dev 2.32.1` pins `analyzer ^10`, so the
/// combination is not installable today. See the Phase 1 comment in
/// `lib/database/providers.dart` for the canonical statement of this
/// constraint. When the ecosystem catches up, a later plan will migrate
/// this file to the `@Riverpod` annotation form.
///
/// Lifecycle notes:
///   * Every provider below uses bare `Provider(...)` /
///     `NotifierProvider(...)`, which in Riverpod 3.x defaults to
///     `isAutoDispose = false` — the manual equivalent of the codegen
///     annotation `@Riverpod(keepAlive: true)`. Do NOT switch any of
///     these to `.autoDispose`; the notifier's service subscription
///     must outlive per-widget disposal, otherwise the first Stop event
///     can arrive while nothing is listening and the UI is stuck in
///     `TrackingActive` forever.
///   * `TrackingNotifier` cancels its two `StreamSubscription`s in
///     `ref.onDispose` so test containers (`container.dispose()`)
///     release the fbs stream cleanly.
///
/// Plan 02-05 wires persistence through
/// `TrackingServiceController.persistFinalizedTrip(...)`. The
/// `trip_finalized` listener on [TrackingNotifier] now transitions
/// `TrackingStopping` → (await persist) → `TrackingIdle`, records the
/// [PersistResult] in the notifier's last-result slot so the tracking
/// screen can surface the D-10 / T-02-22 snackbars via
/// `TrackingNotifier.consumeLastPersistResult`.

/// Stateless [TrackingPermissionService] — safe to share. Const
/// constructor (plan 02-01) means this provider reads a compile-time
/// constant, so the `ref` allocation is the only per-app cost.
final Provider<TrackingPermissionService> trackingPermissionServiceProvider =
    Provider<TrackingPermissionService>(
      (ref) => const TrackingPermissionService(),
      name: 'trackingPermissionServiceProvider',
    );

/// [TrackingNotificationService] for the UX-03 foreground notification.
///
/// The service creates its own `FlutterLocalNotificationsPlugin`
/// instance internally, but the plugin class is a singleton — so this
/// provider and the `main()` bootstrap share the same underlying plugin
/// state. Channel registration from `main()` therefore survives into
/// every `showRecording()` / `dismiss()` call routed through this
/// provider.
final Provider<TrackingNotificationService>
trackingNotificationServiceProvider = Provider<TrackingNotificationService>(
  (ref) => TrackingNotificationService(),
  name: 'trackingNotificationServiceProvider',
);

/// Thin UI-isolate wrapper around [FlutterBackgroundService]. The
/// wrapped instance is the fbs singleton (`FlutterBackgroundService()`
/// is a factory that always returns the same instance), so this
/// provider is effectively a holder for the controller object itself.
/// Dependencies (`AppDatabase`, the two DAOs, the notification service)
/// are injected via `ref.watch` so Drift tests can override the
/// database provider in isolation.
final Provider<TrackingServiceController> trackingServiceControllerProvider =
    Provider<TrackingServiceController>(
      (ref) => TrackingServiceController(
        service: FlutterBackgroundService(),
        database: ref.watch(appDatabaseProvider),
        tripsDao: ref.watch(tripsDaoProvider),
        syncQueueDao: ref.watch(syncQueueDaoProvider),
        notifications: ref.watch(trackingNotificationServiceProvider),
        userPreferencesDao: ref.watch(userPreferencesDaoProvider),
      ),
      name: 'trackingServiceControllerProvider',
    );

/// Live tracking state driven by `service.invoke` events from the
/// background isolate. Plan 02-04 binds the tracking screen tiles to
/// this provider.
final NotifierProvider<TrackingNotifier, TrackingState> trackingStateProvider =
    NotifierProvider<TrackingNotifier, TrackingState>(
      TrackingNotifier.new,
      name: 'trackingStateProvider',
    );

/// Notifier that owns the UI-side [TrackingState]. Subscribes to
/// `tracking_state` (1 Hz accumulator snapshots) and `trip_finalized`
/// (Stop event outcome) on the fbs instance.
///
/// State machine:
///
///   * `TrackingIdle` — initial and post-stop state.
///   * `TrackingIdle → TrackingStarting` — [start] calls the
///     controller; the service isolate is spinning up.
///   * `TrackingStarting → TrackingActive` — first `tracking_state`
///     event arrives from the service isolate.
///   * `TrackingActive → TrackingActive` — every subsequent snapshot
///     updates the live tiles.
///   * `TrackingActive → TrackingStopping → TrackingIdle` — [stop]
///     sends the stop command, the service responds with
///     `trip_finalized`, `persistFinalizedTrip` runs inside
///     `TrackingStopping`, and the state returns to idle. The
///     resulting [PersistResult] is stashed in a private
///     last-result slot for the tracking screen to consume via
///     [consumeLastPersistResult].
///   * `TrackingStarting → TrackingError` — if the controller's start
///     pre-flight fails (e.g. Location Services disabled).
class TrackingNotifier extends Notifier<TrackingState> {
  StreamSubscription<Map<String, dynamic>?>? _stateSub;
  StreamSubscription<Map<String, dynamic>?>? _finalizeSub;
  StreamSubscription<Map<String, dynamic>?>? _errorSub;
  StreamSubscription<Map<String, dynamic>?>? _readySub;
  PersistResult? _lastPersistResult;

  @override
  TrackingState build() {
    ref.onDispose(() {
      unawaited(_stateSub?.cancel());
      unawaited(_finalizeSub?.cancel());
      unawaited(_errorSub?.cancel());
      unawaited(_readySub?.cancel());
    });
    _attach();
    return const TrackingIdle();
  }

  void _attach() {
    final service = FlutterBackgroundService();
    // D-14 race resolution: fbs's setAsForegroundService() calls Android's
    // startForeground(id, notification) internally, replacing our
    // action-bearing Stop notification with an action-less placeholder.
    // The service isolate emits kServiceReadyEvent immediately after
    // setAsForegroundService() completes. We respond by re-posting the
    // UX-03 notification, which overwrites fbs's placeholder and restores
    // the Stop button. See tracking_service_events.dart for the full
    // contract.
    _readySub = service
        .on(kServiceReadyEvent)
        .listen(
          (data) async {
            try {
              await ref
                  .read(trackingNotificationServiceProvider)
                  .showRecording();
            } on Object {
              // POST_NOTIFICATIONS denied — tracking continues, button absent.
            }
          },
          onError: (Object error, StackTrace stack) {
            // kServiceReadyEvent channel errored — non-fatal. The notification
            // may lack the Stop button but tracking is otherwise unaffected.
          },
        );
    _stateSub = service
        .on(kTrackingStateEvent)
        .listen(
          (data) {
            if (data == null) return;
            // strict-casts-safe: `trackingActiveFromSnapshotMap` does the
            // `Map<String, dynamic>` → `Map<String, Object?>` cast through
            // the audited `_req<T>` helper in `tracking_state.dart`.
            state = trackingActiveFromSnapshotMap(
              data.cast<String, Object?>(),
            );
          },
          onError: (Object error, StackTrace stack) {
            // WR-03: the fbs channel emitted an error (e.g. the background
            // isolate died abruptly or the platform channel dropped a
            // message). Without this handler the error would propagate to
            // the notifier's build zone and be invisible to the UI — the
            // notifier would stay attached to a dead stream and the
            // tracking screen would be frozen in TrackingActive forever.
            //
            // PII guard (T-02-07): do NOT forward `error.toString()` — it
            // may contain raw platform diagnostics. Use a stable short
            // user-facing message instead.
            _cancelSiblingSubs(except: _stateSub);
            _lastPersistResult = null;
            state = TrackingError('Tracking stream failed');
          },
        );
    _finalizeSub = service
        .on(kTripFinalizedEvent)
        .listen(
          (data) async {
            if (data == null) return;
            state = const TrackingStopping();
            final trip = FinalizedTripCodec.fromEventMap(data);
            final result = await ref
                .read(trackingServiceControllerProvider)
                .persistFinalizedTrip(trip);
            _lastPersistResult = result;
            // Defense-in-depth (WR-02): only transition back to idle if the
            // state is still TrackingStopping. If a concurrent caller (e.g.
            // a `kTrackingErrorEvent` handler or a programmatic retry) has
            // already moved the state elsewhere (TrackingError /
            // TrackingStarting / TrackingActive) we must not clobber it.
            if (state is TrackingStopping) {
              state = const TrackingIdle();
            }
          },
          onError: (Object error, StackTrace stack) {
            // WR-03: the trip_finalized channel errored mid-persist window.
            // Cancel siblings so we don't accept further (potentially
            // inconsistent) snapshots from the dead service, clear any
            // in-flight persist result, and surface a recoverable error
            // state so the user can retry.
            _cancelSiblingSubs(except: _finalizeSub);
            _lastPersistResult = null;
            state = TrackingError('Unable to finalize trip');
          },
        );
    // WR-01: map the service isolate's `tracking_error` channel to a
    // user-facing TrackingError. The service isolate emits a stable
    // short `reason` tag (PII guard — raw error text may contain
    // lat/lng coordinates per T-02-07). The notifier owns the reason →
    // user-facing message mapping so every supported reason is a
    // deliberate UX choice.
    _errorSub = service
        .on(kTrackingErrorEvent)
        .listen(
          (data) {
            if (data == null) return;
            final reason = data['reason'];
            final message = switch (reason) {
              'position_stream_error' =>
                'Location unavailable. Tracking stopped.',
              _ => 'Tracking stopped unexpectedly',
            };
            state = TrackingError(message);
          },
          onError: (Object error, StackTrace stack) {
            _cancelSiblingSubs(except: _errorSub);
            _lastPersistResult = null;
            state = TrackingError('Tracking stream failed');
          },
        );
  }

  /// Cancel every fbs subscription except [except]. Used by the
  /// `onError` handlers (WR-03) to prevent a zombie subscription from
  /// emitting further events after the notifier has transitioned to
  /// [TrackingError] — once one channel has errored we cannot trust
  /// the others to reflect reality.
  void _cancelSiblingSubs({required StreamSubscription<Object?>? except}) {
    if (!identical(_stateSub, except)) {
      unawaited(_stateSub?.cancel());
      _stateSub = null;
    }
    if (!identical(_finalizeSub, except)) {
      unawaited(_finalizeSub?.cancel());
      _finalizeSub = null;
    }
    if (!identical(_errorSub, except)) {
      unawaited(_errorSub?.cancel());
      _errorSub = null;
    }
    if (!identical(_readySub, except)) {
      unawaited(_readySub?.cancel());
      _readySub = null;
    }
  }

  /// Ask the background service to start tracking. Transitions the
  /// state from [TrackingIdle] (or [TrackingError] — retry path) to
  /// [TrackingStarting]; the service isolate's first `tracking_state`
  /// event flips it to [TrackingActive]. If the controller's pre-flight
  /// fails (e.g. Location Services disabled system-wide), transitions to
  /// [TrackingError] instead.
  ///
  /// Exhaustive guard over the sealed [TrackingState] variants (WR-02):
  /// only [TrackingIdle] and [TrackingError] allow a fresh start.
  /// [TrackingStarting], [TrackingActive], and [TrackingStopping] all
  /// short-circuit — crucially including [TrackingStopping], which is
  /// the window while the `trip_finalized` listener's
  /// [TrackingServiceController.persistFinalizedTrip] is awaiting the
  /// Drift transaction. A Start re-entry during that window would spawn
  /// a second tracking session over the first and the outer `_attach`
  /// listener would later clobber its `TrackingStarting` / [TrackingActive]
  /// state when it writes [TrackingIdle] on resolution.
  Future<void> start() async {
    switch (state) {
      case TrackingIdle():
      case TrackingError():
        // Fall through to the start sequence below.
        break;
      case TrackingStarting():
      case TrackingActive():
      case TrackingStopping():
        return;
    }
    state = const TrackingStarting();
    final ok = await ref.read(trackingServiceControllerProvider).start();
    if (!ok) {
      state = TrackingError('Unable to start tracking');
    }
  }

  /// Ask the background service to stop tracking. No-op unless the
  /// state is [TrackingActive] — the Stop button is hidden in every
  /// other state, so this is a defensive guard against re-entry.
  ///
  /// WR-04 contract: the transition to [TrackingStopping] happens
  /// SYNCHRONOUSLY at the top of this method, BEFORE any `await`. A
  /// double-tap on the Stop button lands both taps in the same frame;
  /// the first tap passes the guard and flips state to
  /// [TrackingStopping]; the second tap hits the guard and
  /// short-circuits because state is no longer [TrackingActive]. This
  /// guarantees `kStopTrackingEvent` is invoked exactly once per Stop
  /// click even though the service isolate responds asynchronously
  /// with `kTripFinalizedEvent`.
  ///
  /// The final [TrackingStopping] → [TrackingIdle] transition happens
  /// inside the `trip_finalized` listener attached in [_attach], not
  /// here, because the service isolate responds asynchronously.
  Future<void> stop() async {
    if (state is! TrackingActive) return;
    state = const TrackingStopping();
    await ref.read(trackingServiceControllerProvider).stop();
  }

  /// Return the [PersistResult] produced by the most recent
  /// `trip_finalized` cycle, and clear the slot. The tracking screen
  /// calls this from a `ref.listen(trackingStateProvider, ...)` when
  /// the state transitions back to [TrackingIdle] after a save, so it
  /// can show the D-10 / save / failure snackbar exactly once.
  ///
  /// Returns `null` if no persist cycle has completed yet, or if the
  /// previous result has already been consumed.
  PersistResult? consumeLastPersistResult() {
    final result = _lastPersistResult;
    _lastPersistResult = null;
    return result;
  }

  /// Test-only seam used by plan 02-06 widget tests to simulate the
  /// "trip just finalized with result X" state without driving a real
  /// service-isolate round trip. MUST NOT be called from production
  /// code — `very_good_analysis` warns when a non-test file touches a
  /// `@visibleForTesting` member.
  ///
  /// Intentionally named `setLastPersistResultForTesting` (not a
  /// Dart setter) so grep audits catch every test site and production
  /// code cannot accidentally write to `_lastPersistResult` via an
  /// innocuous-looking assignment.
  @visibleForTesting
  // A named method (not a Dart setter) is deliberate so audits can
  // grep for every call site; production code MUST NOT reach into
  // _lastPersistResult through an innocuous-looking assignment.
  // ignore: use_setters_to_change_properties
  void setLastPersistResultForTesting(PersistResult result) {
    _lastPersistResult = result;
  }
}

/// Isolate-boundary codec for [FinalizedTrip] payloads crossing the
/// `flutter_background_service.invoke(kTripFinalizedEvent, ...)`
/// channel. The service isolate emits `Map<String, dynamic>` and the
/// notifier needs `Map<String, Object?>` — this helper is the single
/// audited cast site, matching the pattern used by
/// `trackingActiveFromSnapshotMap` for the `kTrackingStateEvent`
/// payload.
class FinalizedTripCodec {
  const FinalizedTripCodec._();

  /// Decode a trip_finalized payload. Delegates to
  /// [FinalizedTrip.fromMap] after widening the map element type.
  static FinalizedTrip fromEventMap(Map<String, dynamic> data) {
    return FinalizedTrip.fromMap(data.cast<String, Object?>());
  }
}
