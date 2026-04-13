import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';

/// UI-isolate wrapper around [FlutterBackgroundService]. Thin by design —
/// all tracking logic (GPS stream, accumulator, 1 Hz snapshots, stop
/// race guard) lives in `tracking_service.dart`. This class owns only:
///
///   * the start/stop lifecycle, including the Location-Services
///     pre-flight that the home screen cannot easily guard on its own;
///   * the stop command, which is sent as an [kStopTrackingEvent]
///     `service.invoke` call (the service isolate listens for it and
///     responds with [kTripFinalizedEvent]).
///
/// Plan 02-05 will add a `persistFinalizedTrip(FinalizedTrip)` method
/// that wraps the Drift transaction (insert trip + enqueue sync queue
/// entry) and dismisses the UX-03 notification. That method belongs to
/// this class because it is the single place the UI isolate already
/// touches the background-service machinery.
///
/// **Not** responsible for permission pre-flight — callers must invoke
/// `TrackingPermissionService.preflight` first (plan 02-04's tracking
/// screen does so). This keeps the UI in charge of denial/banner UX.
class TrackingServiceController {
  /// Construct a controller bound to [service]. Production wiring is
  /// done in `tracking_providers.dart` with `FlutterBackgroundService()`.
  TrackingServiceController({required FlutterBackgroundService service})
      : _service = service;

  final FlutterBackgroundService _service;

  /// Start the background tracking service. Returns `true` if the
  /// service was asked to start (`FlutterBackgroundService.startService`
  /// returned `true`), `false` if the Location-Services pre-flight
  /// failed or the platform refused.
  ///
  /// Pre-conditions the caller MUST have already handled:
  ///
  ///   * `locationWhenInUse` granted (via the permission service's
  ///     `preflight` method);
  ///   * ideally `locationAlways` granted too — if it is not, tracking
  ///     still works while the app is foregrounded (D-08 banner).
  ///
  /// Pre-conditions this method handles:
  ///
  ///   * `Geolocator.isLocationServiceEnabled()` — if Location Services
  ///     are toggled off system-wide, return `false` without invoking
  ///     `startService` (the fbs call would otherwise succeed, the
  ///     service would spin up, and Geolocator would then fail with an
  ///     unhelpful error on the first sample).
  Future<bool> start() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    return _service.startService();
  }

  /// Tell the background isolate to stop. The service responds
  /// asynchronously by emitting [kTripFinalizedEvent], which
  /// `TrackingNotifier` listens for and uses to transition the UI state
  /// through `TrackingStopping` back to `TrackingIdle`.
  ///
  /// The `invoke` call itself is fire-and-forget — fbs does not expose
  /// an awaitable acknowledgement.
  Future<void> stop() async {
    _service.invoke(kStopTrackingEvent);
  }
}
