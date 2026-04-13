import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';
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
/// No persistence is wired here — D-06 says Phase 2 keeps samples in
/// memory, and the plan 02-05 persistence path will land in that plan.
/// The `trip_finalized` listener below drops back to [TrackingIdle]
/// without calling Drift. Plan 02-05 will insert its call to
/// `TrackingServiceController.persistFinalizedTrip(...)` between
/// `TrackingStopping` and `TrackingIdle`.

/// Stateless [TrackingPermissionService] — safe to share. Const
/// constructor (plan 02-01) means this provider reads a compile-time
/// constant, so the `ref` allocation is the only per-app cost.
final Provider<TrackingPermissionService> trackingPermissionServiceProvider =
    Provider<TrackingPermissionService>(
  (ref) => const TrackingPermissionService(),
  name: 'trackingPermissionServiceProvider',
);

/// Thin UI-isolate wrapper around [FlutterBackgroundService]. The
/// wrapped instance is the fbs singleton (`FlutterBackgroundService()`
/// is a factory that always returns the same instance), so this
/// provider is effectively a holder for the controller object itself.
final Provider<TrackingServiceController> trackingServiceControllerProvider =
    Provider<TrackingServiceController>(
  (ref) => TrackingServiceController(service: FlutterBackgroundService()),
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
///     `trip_finalized`, plan 02-05 will persist the trip here, then
///     the state returns to idle.
///   * `TrackingStarting → TrackingError` — if the controller's start
///     pre-flight fails (e.g. Location Services disabled).
///
/// **Plan 02-05 hook:** inside the `trip_finalized` listener below,
/// plan 02-05 will call
/// `ref.read(trackingServiceControllerProvider).persistFinalizedTrip(...)`
/// between the `TrackingStopping` and `TrackingIdle` transitions. Left
/// as a documented handoff (NOT a `TODO`) so the code compiles and the
/// feature can be manually smoke-tested without persistence.
class TrackingNotifier extends Notifier<TrackingState> {
  StreamSubscription<Map<String, dynamic>?>? _stateSub;
  StreamSubscription<Map<String, dynamic>?>? _finalizeSub;

  @override
  TrackingState build() {
    ref.onDispose(() {
      unawaited(_stateSub?.cancel());
      unawaited(_finalizeSub?.cancel());
    });
    _attach();
    return const TrackingIdle();
  }

  void _attach() {
    final service = FlutterBackgroundService();
    _stateSub = service.on(kTrackingStateEvent).listen((data) {
      if (data == null) return;
      // strict-casts-safe: `trackingActiveFromSnapshotMap` does the
      // `Map<String, dynamic>` → `Map<String, Object?>` cast through
      // the audited `_req<T>` helper in `tracking_state.dart`.
      state = trackingActiveFromSnapshotMap(
        data.cast<String, Object?>(),
      );
    });
    _finalizeSub = service.on(kTripFinalizedEvent).listen((data) {
      if (data == null) return;
      state = const TrackingStopping();
      // Plan 02-05 hook — persistence goes here. See class doc.
      // For now we drop straight back to idle so the feature can be
      // smoke-tested on an emulator before persistence is wired:
      state = const TrackingIdle();
    });
  }

  /// Ask the background service to start tracking. Transitions the
  /// state from [TrackingIdle] to [TrackingStarting]; the service
  /// isolate's first `tracking_state` event flips it to
  /// [TrackingActive]. If the controller's pre-flight fails (e.g.
  /// Location Services disabled system-wide), transitions to
  /// [TrackingError] instead.
  ///
  /// No-op if the state is already [TrackingActive] or
  /// [TrackingStarting].
  Future<void> start() async {
    if (state is TrackingActive || state is TrackingStarting) return;
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
  /// The actual [TrackingStopping] → [TrackingIdle] transition happens
  /// inside the `trip_finalized` listener attached in [_attach], not
  /// here, because the service isolate responds asynchronously.
  Future<void> stop() async {
    if (state is! TrackingActive) return;
    await ref.read(trackingServiceControllerProvider).stop();
  }
}
