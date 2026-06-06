import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/tracking/services/main_isolate_tracking_engine.dart';
import 'package:traevy/features/tracking/services/tracking_event_source.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
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
        tripBreaksDao: ref.watch(tripBreaksDaoProvider),
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
  StreamSubscription<Map<String, dynamic>?>? _autoPausePromptSub;
  PersistResult? _lastPersistResult;
  // Notification refresh throttle (08-10 review HIGH #5). The 1 Hz snapshot
  // rate would call showRecording() ~2700 times on a 45-min trip, all of
  // which round-trip through the platform channel. onlyAlertOnce mutes the
  // sound but not the IPC. Throttle to once per
  // [kTrackingNotificationRefreshInterval] so a 45-min trip drops to ~270
  // calls instead. Reset on stop so the next trip's first snapshot lands
  // immediately.
  DateTime? _lastNotificationUpdateAt;
  // TRACK-12 (D-05/D-06): manual direction override set from the active-trip
  // segmented toggle. When non-null it wins over the time-of-day auto-label
  // both live (resolvedDirection → notification + header) and at finalize
  // (passed as directionOverride into persistFinalizedTrip). Reset to null in
  // stop() so the next trip starts from the heuristic again.
  String? _manualDirectionOverride;

  @override
  TrackingState build() {
    ref.onDispose(() {
      unawaited(_stateSub?.cancel());
      unawaited(_finalizeSub?.cancel());
      unawaited(_errorSub?.cancel());
      unawaited(_readySub?.cancel());
      unawaited(_autoPausePromptSub?.cancel());
    });
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
    // Phase 18 (Plan 04, D-11/D-12, SC#5): the service isolate signals once
    // per stuck streak. The OPT-IN gate lives HERE, on the UI isolate, where
    // Drift (and `user_preferences.auto_pause_enabled`) is reachable — so
    // detection stays service-side while the prompt is only ever posted when
    // the user has opted in. With auto-pause OFF (default) NO prompt is posted.
    _autoPausePromptSub = source.onAutoPausePrompt.listen(
      (data) async {
        final prefs = ref.read(userPreferenceProvider).asData?.value;
        if (prefs == null || !prefs.autoPauseEnabled) return;
        try {
          await ref
              .read(trackingNotificationServiceProvider)
              .showAutoPausePrompt();
        } on Object {
          // POST_NOTIFICATIONS denied or platform channel error — tracking
          // continues; the prompt just isn't shown this streak.
        }
      },
      onError: (Object error, StackTrace stack) {
        // auto-pause prompt channel errored — non-fatal. Tracking and the
        // foreground notification are unaffected; only this prompt is lost.
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
        state = next;
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
            .persistFinalizedTrip(
              trip,
              // D-06: the manual override (if the user picked a direction on
              // the active-trip toggle) wins over the time-of-day heuristic.
              directionOverride: _manualDirectionOverride,
            );
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

  /// Refresh the foreground notification, throttled to once per
  /// [kTrackingNotificationRefreshInterval]. Resolves the trip's direction
  /// from the user's morning/evening cutoff prefs so the notification title
  /// and body match the in-app hero (review HIGH #2/3).
  void _maybeRefreshNotification(TrackingActive active) {
    final now = DateTime.now();
    final last = _lastNotificationUpdateAt;
    if (last != null &&
        now.difference(last) < kTrackingNotificationRefreshInterval) {
      return;
    }
    _lastNotificationUpdateAt = now;
    // D-05: the notification reflects the resolved direction — the manual
    // override when set, else the time-of-day auto-label.
    final direction = resolvedDirection(active.startedAt);
    unawaited(
      ref
          .read(trackingNotificationServiceProvider)
          .showRecording(
            elapsedSeconds: active.elapsedSeconds,
            distanceMeters: active.distanceMeters,
            timeStuckSeconds: active.timeStuckSeconds,
            direction: direction,
          )
          .catchError((Object _) {
            // POST_NOTIFICATIONS denied or platform channel error — tracking
            // continues, notification just doesn't refresh this tick.
          }),
    );
  }

  /// Resolve the direction for a trip that started at [startedAt] (UTC).
  ///
  /// TRACK-12 (D-05): returns the manual override when the user has picked a
  /// direction on the active-trip toggle, else the [DirectionLabelService]
  /// time-of-day auto-label computed from the user's morning/evening cutoff
  /// prefs (falling back to [kDefaultDirectionCutoffHour] until prefs load).
  /// This is the single source consumed by both [_maybeRefreshNotification]
  /// and the hero header label, so the override propagates everywhere live.
  String resolvedDirection(DateTime startedAt) {
    final override = _manualDirectionOverride;
    if (override != null) return override;
    final prefs = ref.read(userPreferenceProvider).asData?.value;
    final morning = prefs?.morningCutoffHour ?? kDefaultDirectionCutoffHour;
    final evening = prefs?.eveningCutoffHour ?? kDefaultDirectionCutoffHour;
    return const DirectionLabelService().label(
      startedAt.toLocal(),
      morning,
      evening,
    );
  }

  /// Set the manual direction override from the active-trip segmented toggle.
  ///
  /// TRACK-12 (D-05): [direction] MUST be [kDirectionToOffice] or
  /// [kDirectionToHome] — the toggle only emits those two constants, and the
  /// assert is a defence-in-depth tamper guard (T-17-02) so no arbitrary
  /// string can reach `trips.direction` via this path. When a trip is active,
  /// resets the notification throttle and refreshes immediately so the header
  /// label and foreground notification flip to the chosen direction on the
  /// same frame.
  void setDirection(String direction) {
    assert(
      direction == kDirectionToOffice || direction == kDirectionToHome,
      'setDirection only accepts kDirectionToOffice or kDirectionToHome',
    );
    _manualDirectionOverride = direction;
    final current = state;
    if (current is TrackingActive) {
      _lastNotificationUpdateAt = null;
      _maybeRefreshNotification(current);
    }
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
    if (!identical(_autoPausePromptSub, except)) {
      unawaited(_autoPausePromptSub?.cancel());
      _autoPausePromptSub = null;
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
    // TRACK-12 (D-05): clear the manual direction override so the next trip
    // starts from the time-of-day heuristic rather than inheriting this
    // trip's choice.
    _manualDirectionOverride = null;
    await ref.read(trackingServiceControllerProvider).stop();
  }

  /// Suspend the active trip (Phase 18, D-08, SC#1). No-op unless the state is
  /// [TrackingActive] — the Pause button only renders while active, so this is
  /// a defensive re-entry guard.
  ///
  /// DUMB TERMINAL CONTRACT (D-08): this method sets NO local paused state. It
  /// forwards the command to the engine and returns; the displayed paused flag
  /// arrives later via the next snapshot's `isPaused` decoded in
  /// [trackingActiveFromSnapshotMap]. Because the UI never runs its own pause
  /// clock, the displayed state can never diverge from the accumulator — after
  /// a backgrounding/kill the UI reconnects and the first snapshot dictates the
  /// paused/running display (T-18-09, automatic recovery).
  Future<void> pause() async {
    if (state is! TrackingActive) return;
    await ref.read(trackingServiceControllerProvider).pause();
  }

  /// Resume a paused trip (Phase 18, D-08, SC#1). No-op unless the state is
  /// [TrackingActive]. Like [pause], sets NO local state — the next snapshot's
  /// `isPaused: false` flips the UI back to the running treatment.
  Future<void> resume() async {
    if (state is! TrackingActive) return;
    await ref.read(trackingServiceControllerProvider).resume();
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
