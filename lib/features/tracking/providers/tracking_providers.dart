import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/tracking/services/live_activity_service.dart';
import 'package:traevy/features/tracking/services/main_isolate_tracking_engine.dart';
import 'package:traevy/features/tracking/services/tracking_event_source.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';

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
///   * `TrackingNotifier` cancels its four `StreamSubscription`s in
///     `ref.onDispose` so test containers (`container.dispose()`)
///     release the event-source streams cleanly.
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

/// [LiveActivityService] for the iOS 17+ Live Activity (IOS-13, D-08).
///
/// Keep-alive (no autoDispose) for the same reason as
/// [trackingNotificationServiceProvider] — the url-scheme Stop-button listener
/// and the _activityId state must survive widget disposal.
///
/// Initialisation (calling [LiveActivityService.init] with the controller) is
/// done inside [TrackingNotifier.build] where the controller is available.
final Provider<LiveActivityService> liveActivityServiceProvider =
    Provider<LiveActivityService>(
      (ref) => LiveActivityService(),
      name: 'liveActivityServiceProvider',
    );

/// Platform-selected [TrackingEventSource].
///
/// D-04 platform selection: on iOS the main-isolate engine is used so
/// CoreLocation keeps the GPS stream alive across background/lock-screen
/// (IOS-06, D-01). On every other platform the fbs background-isolate
/// wrapper is used (the existing Android path, unchanged).
///
/// The **same instance** is injected into both [TrackingNotifier] (which
/// subscribes to its streams) and [trackingServiceControllerProvider]
/// (which drives its start/stop). This is the D-04 contract — there is
/// exactly ONE engine per app lifetime; a second construction would open a
/// second GPS stream on iOS.
///
/// Uses `defaultTargetPlatform` (not `dart:io Platform.isIOS`) so the
/// branch is exercisable under `debugDefaultTargetPlatformOverride` in
/// unit tests (14-CONTEXT D-04, 14-VALIDATION).
final Provider<TrackingEventSource> trackingEventSourceProvider =
    Provider<TrackingEventSource>(
      (ref) {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return MainIsolateTrackingEngine();
        }
        return FbsTrackingEventSource(FlutterBackgroundService());
      },
      name: 'trackingEventSourceProvider',
    );

/// Thin UI-isolate wrapper around the platform-selected
/// [TrackingEventSource]. The wrapped source is shared via
/// [trackingEventSourceProvider] so the notifier's subscriptions and the
/// controller's start/stop calls act on the same engine instance.
/// Dependencies (`AppDatabase`, the two DAOs, the notification service)
/// are injected via `ref.watch` so Drift tests can override the
/// database provider in isolation.
final Provider<TrackingServiceController> trackingServiceControllerProvider =
    Provider<TrackingServiceController>(
      (ref) => TrackingServiceController(
        source: ref.watch(trackingEventSourceProvider),
        database: ref.watch(appDatabaseProvider),
        tripsDao: ref.watch(tripsDaoProvider),
        syncQueueDao: ref.watch(syncQueueDaoProvider),
        notifications: ref.watch(trackingNotificationServiceProvider),
        userPreferencesDao: ref.watch(userPreferencesDaoProvider),
      ),
      name: 'trackingServiceControllerProvider',
    );

/// Live tracking state driven by events from the platform-selected
/// [TrackingEventSource]. Plan 02-04 binds the tracking screen tiles to
/// this provider.
final NotifierProvider<TrackingNotifier, TrackingState> trackingStateProvider =
    NotifierProvider<TrackingNotifier, TrackingState>(
      TrackingNotifier.new,
      name: 'trackingStateProvider',
    );

/// Notifier that owns the UI-side [TrackingState]. Subscribes to the
/// platform-selected [TrackingEventSource] (1 Hz accumulator snapshots,
/// trip-finalized payload, error events, and the Android service-ready
/// signal).
///
/// State machine:
///
///   * `TrackingIdle` — initial and post-stop state.
///   * `TrackingIdle → TrackingStarting` — [start] calls the
///     controller; the engine is spinning up.
///   * `TrackingStarting → TrackingActive` — first `onState`
///     event arrives from the engine.
///   * `TrackingActive → TrackingActive` — every subsequent snapshot
///     updates the live tiles.
///   * `TrackingActive → TrackingStopping → TrackingIdle` — [stop]
///     sends the stop command, the engine responds with an `onFinalized`
///     event, `persistFinalizedTrip` runs inside `TrackingStopping`, and
///     the state returns to idle. The resulting [PersistResult] is stashed
///     in a private last-result slot for the tracking screen to consume via
///     [consumeLastPersistResult].
///   * `TrackingStarting → TrackingError` — if the controller's start
///     pre-flight fails (e.g. Location Services disabled, or IOS-08
///     accuracy gate blocked).
class TrackingNotifier extends Notifier<TrackingState> {
  StreamSubscription<Map<String, dynamic>?>? _stateSub;
  StreamSubscription<Map<String, dynamic>?>? _finalizeSub;
  StreamSubscription<Map<String, dynamic>?>? _errorSub;
  StreamSubscription<Map<String, dynamic>?>? _readySub;
  PersistResult? _lastPersistResult;
  // Notification refresh throttle (08-10 review HIGH #5). The 1 Hz snapshot
  // rate would call showRecording() ~2700 times on a 45-min trip, all of
  // which round-trip through the platform channel. onlyAlertOnce mutes the
  // sound but not the IPC. Throttle to once per
  // [kTrackingNotificationRefreshInterval] so a 45-min trip drops to ~270
  // calls instead. Reset on stop so the next trip's first snapshot lands
  // immediately.
  DateTime? _lastNotificationUpdateAt;

  @override
  TrackingState build() {
    ref.onDispose(() {
      unawaited(_stateSub?.cancel());
      unawaited(_finalizeSub?.cancel());
      unawaited(_errorSub?.cancel());
      unawaited(_readySub?.cancel());
    });
    // IOS-13: wire the Live Activity url-scheme Stop-button listener once the
    // controller is available. No-op on Android (service self-gates in init).
    unawaited(
      ref
          .read(liveActivityServiceProvider)
          .init(ref.read(trackingServiceControllerProvider))
          .catchError((Object _) {
            // init failure is non-fatal — Live Activity is additive (T-15-13).
          }),
    );
    _attach();
    return const TrackingIdle();
  }

  void _attach() {
    final source = ref.read(trackingEventSourceProvider);
    // D-14 race resolution (Android only): fbs's setAsForegroundService()
    // calls Android's startForeground(id, notification) internally,
    // replacing our action-bearing Stop notification with an action-less
    // placeholder. The service isolate emits kServiceReadyEvent immediately
    // after setAsForegroundService() completes. We respond by re-posting
    // the UX-03 notification, which overwrites fbs's placeholder and
    // restores the Stop button.
    //
    // On iOS, source.onReady is const Stream.empty() (D-07) — no fbs
    // service-ready signal; this subscription is a harmless no-op.
    _readySub = source.onReady.listen(
      (data) async {
        try {
          await ref.read(trackingNotificationServiceProvider).showRecording();
        } on Object {
          // POST_NOTIFICATIONS denied — tracking continues, button absent.
        }
      },
      onError: (Object error, StackTrace stack) {
        // onReady channel errored — non-fatal. The notification
        // may lack the Stop button but tracking is otherwise unaffected.
      },
    );
    _stateSub = source.onState.listen(
      (data) {
        if (data == null) return;
        // strict-casts-safe: `trackingActiveFromSnapshotMap` does the
        // `Map<String, dynamic>` → `Map<String, Object?>` cast through
        // the audited `_req<T>` helper in `tracking_state.dart`.
        final next = trackingActiveFromSnapshotMap(
          data.cast<String, Object?>(),
        );
        // IOS-13: start the Live Activity on the first TrackingActive event
        // (i.e. the TrackingStarting → TrackingActive transition). The service
        // self-gates on iOS 17+ via _isLiveActivitySupported(); on all other
        // platforms start() is a no-op. Subsequent snapshots go to update().
        final wasStarting = state is TrackingStarting;
        state = next;
        if (wasStarting) {
          _startLiveActivity(next);
        }
        _maybeRefreshNotification(next);
      },
      onError: (Object error, StackTrace stack) {
        // WR-03: the event source emitted an error (e.g. the background
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
    _finalizeSub = source.onFinalized.listen(
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
          // IOS-13 Pitfall 4: on idle, sweep up any Live Activity orphaned by
          // an app-kill mid-commute. endAll() is a no-op when there is no
          // running Activity — calling it here is always safe.
          unawaited(
            ref.read(liveActivityServiceProvider).endAll().catchError((
              Object _,
            ) {
              // endAll() failure is non-fatal (T-15-13).
            }),
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        // WR-03: the trip_finalized channel errored mid-persist window.
        // Cancel siblings so we don't accept further (potentially
        // inconsistent) snapshots from the dead engine, clear any
        // in-flight persist result, and surface a recoverable error
        // state so the user can retry.
        _cancelSiblingSubs(except: _finalizeSub);
        _lastPersistResult = null;
        state = TrackingError('Unable to finalize trip');
      },
    );
    // WR-01: map the engine's `onError` channel to a user-facing
    // TrackingError. The engine emits a stable short `reason` tag
    // (PII guard — raw error text may contain lat/lng coordinates per
    // T-02-07). The notifier owns the reason → user-facing message
    // mapping so every supported reason is a deliberate UX choice.
    _errorSub = source.onError.listen(
      (data) {
        if (data == null) return;
        final reason = data['reason'];
        final message = switch (reason) {
          'position_stream_error' => 'Location unavailable. Tracking stopped.',
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

  /// Start the iOS 17+ Live Activity when the first [TrackingActive] event
  /// arrives (the [TrackingStarting] → [TrackingActive] transition).
  ///
  /// The [LiveActivityService] self-gates on iOS 17+ via
  /// [LiveActivityService._isLiveActivitySupported]; on Android and iOS < 17
  /// this call is a no-op. Fire-and-forget to avoid blocking the synchronous
  /// state-update path.
  void _startLiveActivity(TrackingActive active) {
    final prefs = ref.read(userPreferenceProvider).asData?.value;
    final morning = prefs?.morningCutoffHour ?? kDefaultDirectionCutoffHour;
    final evening = prefs?.eveningCutoffHour ?? kDefaultDirectionCutoffHour;
    final direction = const DirectionLabelService().label(
      active.startedAt.toLocal(),
      morning,
      evening,
    );
    // TrackingActive.currentSpeedKmh is the km/h value after the isolate-
    // boundary conversion in trackingActiveFromSnapshotMap. Convert back to
    // m/s for the TripSnapshot so LiveActivityService can compare against
    // kStuckSpeedThresholdMs (which is m/s).
    final snapshot = TripSnapshot(
      startedAt: active.startedAt,
      elapsedSeconds: active.elapsedSeconds,
      distanceMeters: active.distanceMeters,
      timeMovingSeconds: active.timeMovingSeconds,
      timeStuckSeconds: active.timeStuckSeconds,
      currentSpeedMs: active.currentSpeedKmh / 3.6,
    );
    debugPrint( // TEMP la-diag
      '[la-diag] wiring: trackingStarting->Active transition, invoking liveActivityService.start()', // TEMP la-diag
    ); // TEMP la-diag
    liveActivityDiag.value = // TEMP la-diag UI
        'LA wiring: transition fired, calling start()'; // TEMP la-diag UI
    unawaited(
      ref
          .read(liveActivityServiceProvider)
          .start(snapshot, direction)
          .catchError((Object _) {
            // Live Activity start failure is non-fatal (T-15-13).
          }),
    );
  }

  /// Refresh the foreground notification, throttled to once per
  /// [kTrackingNotificationRefreshInterval]. Resolves the trip's direction
  /// from the user's morning/evening cutoff prefs so the notification title
  /// and body match the in-app hero (review HIGH #2/3).
  ///
  /// Also updates the iOS 17+ Live Activity on the same 5s cadence (A2) so
  /// both surfaces stay in sync without a separate throttle constant (IOS-13).
  void _maybeRefreshNotification(TrackingActive active) {
    final now = DateTime.now();
    final last = _lastNotificationUpdateAt;
    if (last != null &&
        now.difference(last) < kTrackingNotificationRefreshInterval) {
      return;
    }
    _lastNotificationUpdateAt = now;
    final prefs = ref.read(userPreferenceProvider).asData?.value;
    final morning = prefs?.morningCutoffHour ?? kDefaultDirectionCutoffHour;
    final evening = prefs?.eveningCutoffHour ?? kDefaultDirectionCutoffHour;
    final direction = const DirectionLabelService().label(
      active.startedAt.toLocal(),
      morning,
      evening,
    );
    unawaited(
      ref
          .read(trackingNotificationServiceProvider)
          .showRecording(
            elapsedSeconds: active.elapsedSeconds,
            distanceMeters: active.distanceMeters,
            timeMovingSeconds: active.timeMovingSeconds,
            timeStuckSeconds: active.timeStuckSeconds,
            direction: direction,
          )
          .catchError((Object _) {
            // POST_NOTIFICATIONS denied or platform channel error — tracking
            // continues, notification just doesn't refresh this tick.
          }),
    );
    // IOS-13: update the Live Activity on the SAME 5s throttle (Assumption A2).
    // The service no-ops if there is no active Activity (_activityId == null).
    // Convert currentSpeedKmh → m/s for LiveActivityService (kStuckSpeedThresholdMs
    // comparison requires m/s — same conversion as in _startLiveActivity).
    final snapshot = TripSnapshot(
      startedAt: active.startedAt,
      elapsedSeconds: active.elapsedSeconds,
      distanceMeters: active.distanceMeters,
      timeMovingSeconds: active.timeMovingSeconds,
      timeStuckSeconds: active.timeStuckSeconds,
      currentSpeedMs: active.currentSpeedKmh / 3.6,
    );
    unawaited(
      ref
          .read(liveActivityServiceProvider)
          .update(snapshot, direction)
          .catchError((Object _) {
            // Live Activity update failure is non-fatal (T-15-13).
          }),
    );
  }

  /// Cancel every event-source subscription except [except]. Used by the
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

  /// Ask the engine to start tracking. Transitions the state from
  /// [TrackingIdle] (or [TrackingError] — retry path) to
  /// [TrackingStarting]; the engine's first `onState` event flips it to
  /// [TrackingActive]. If the controller's pre-flight fails (e.g. Location
  /// Services disabled, or IOS-08 accuracy gate blocked), transitions to
  /// [TrackingError] instead.
  ///
  /// IOS-08: if the accuracy gate blocks, a distinct
  /// [kTrackingReducedAccuracyBlockedMessage] is surfaced (not the generic
  /// "Unable to start tracking") so the user understands the cause is
  /// reduced location accuracy, not a general failure.
  ///
  /// Exhaustive guard over the sealed [TrackingState] variants (WR-02):
  /// only [TrackingIdle] and [TrackingError] allow a fresh start.
  /// [TrackingStarting], [TrackingActive], and [TrackingStopping] all
  /// short-circuit — crucially including [TrackingStopping], which is
  /// the window while the `onFinalized` listener's
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
      // IOS-08: if the accuracy gate blocked the start, surface a distinct
      // message so the user understands precision is required. On Android,
      // the generic message is shown (location services disabled or similar).
      final message = defaultTargetPlatform == TargetPlatform.iOS
          ? kTrackingReducedAccuracyBlockedMessage
          : 'Unable to start tracking';
      state = TrackingError(message);
    }
  }

  /// Ask the engine to stop tracking. No-op unless the state is
  /// [TrackingActive] — the Stop button is hidden in every other state,
  /// so this is a defensive guard against re-entry.
  ///
  /// WR-04 contract: the transition to [TrackingStopping] happens
  /// SYNCHRONOUSLY at the top of this method, BEFORE any `await`. A
  /// double-tap on the Stop button lands both taps in the same frame;
  /// the first tap passes the guard and flips state to
  /// [TrackingStopping]; the second tap hits the guard and
  /// short-circuits because state is no longer [TrackingActive]. This
  /// guarantees the stop command is issued exactly once per Stop click
  /// even though the engine responds asynchronously via `onFinalized`.
  ///
  /// The final [TrackingStopping] → [TrackingIdle] transition happens
  /// inside the `onFinalized` listener attached in [_attach], not here,
  /// because the engine responds asynchronously.
  Future<void> stop() async {
    if (state is! TrackingActive) return;
    state = const TrackingStopping();
    // Reset notification throttle so the first snapshot of the next trip
    // refreshes the notification immediately rather than waiting up to
    // kTrackingNotificationRefreshInterval.
    _lastNotificationUpdateAt = null;
    await ref.read(trackingServiceControllerProvider).stop();
    // IOS-13: dismiss the Live Activity immediately when the trip stops.
    // Fire-and-forget — the Activity ending must never block the stop path.
    unawaited(
      ref.read(liveActivityServiceProvider).end().catchError((Object _) {
        // end() failure is non-fatal (T-15-13).
      }),
    );
  }

  /// Return the [PersistResult] produced by the most recent
  /// `onFinalized` cycle, and clear the slot. The tracking screen
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
  /// engine round trip. MUST NOT be called from production code —
  /// `very_good_analysis` warns when a non-test file touches a
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
/// event-source channel. Both the Android fbs isolate and the iOS
/// main-isolate engine emit `Map<String, dynamic>` and the notifier
/// needs `Map<String, Object?>` — this helper is the single audited
/// cast site, matching the pattern used by
/// `trackingActiveFromSnapshotMap` for the `onState` payload.
class FinalizedTripCodec {
  const FinalizedTripCodec._();

  /// Decode a trip_finalized payload. Delegates to
  /// [FinalizedTrip.fromMap] after widening the map element type.
  static FinalizedTrip fromEventMap(Map<String, dynamic> data) {
    return FinalizedTrip.fromMap(data.cast<String, Object?>());
  }
}
