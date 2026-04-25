import 'package:drift/drift.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';

/// UI-isolate wrapper around [FlutterBackgroundService]. Thin by design —
/// all tracking logic (GPS stream, accumulator, 1 Hz snapshots, stop
/// race guard) lives in `tracking_service.dart`. This class owns only:
///
///   * the start/stop lifecycle, including the Location-Services
///     pre-flight that the home screen cannot easily guard on its own;
///   * the stop command, which is sent as an [kStopTrackingEvent]
///     `service.invoke` call (the service isolate listens for it and
///     responds with [kTripFinalizedEvent]);
///   * the [persistFinalizedTrip] transaction — the atomic Drift write
///     that inserts the trip and enqueues the sync-queue entry in a
///     single transaction, with the D-10 short-trip discard guarding
///     the threshold and the UX-03 notification dismissed on every
///     exit path.
///
/// **Not** responsible for permission pre-flight — callers must invoke
/// `TrackingPermissionService.preflight` first (plan 02-04's tracking
/// screen does so). This keeps the UI in charge of denial/banner UX.
class TrackingServiceController {
  /// Construct a controller bound to [service], [database], its DAOs,
  /// and the [notifications] wrapper. Production wiring is done in
  /// `tracking_providers.dart` with `FlutterBackgroundService()`,
  /// `appDatabaseProvider`, and the two DAO providers.
  TrackingServiceController({
    required FlutterBackgroundService service,
    required AppDatabase database,
    required TripsDao tripsDao,
    required SyncQueueDao syncQueueDao,
    required TrackingNotificationService notifications,
    required UserPreferencesDao userPreferencesDao,
  }) : _service = service,
       _database = database,
       _tripsDao = tripsDao,
       _syncQueueDao = syncQueueDao,
       _notifications = notifications,
       _userPreferencesDao = userPreferencesDao;

  final FlutterBackgroundService _service;
  final AppDatabase _database;
  final TripsDao _tripsDao;
  final SyncQueueDao _syncQueueDao;
  final TrackingNotificationService _notifications;
  final UserPreferencesDao _userPreferencesDao;

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
  ///
  /// On a successful start the UX-03 foreground notification is shown
  /// via [TrackingNotificationService.showRecording]. The notification
  /// call is wrapped in a defensive try/catch (Deviation Rule 4): on
  /// Android 13+ `POST_NOTIFICATIONS` may not yet be granted on the
  /// first run, and we prefer silent tracking over a failed start.
  Future<bool> start() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    // Post the UX-03 notification BEFORE starting the service so the
    // action-bearing notification exists at kTrackingNotificationId when
    // fbs's setAsForegroundService promotes the service. This is the
    // D-14 unification contract — fbs reuses the existing notification
    // at the same id+channel instead of creating its own action-less
    // stock notification. Reversing this order would let fbs win the
    // race and the Stop action button would never appear.
    //
    // POST_NOTIFICATIONS denied on Android 13+ → tracking still works,
    // the UX-03 notification is just absent until the user grants it.
    // Do NOT rethrow (Deviation Rule 4).
    try {
      await _notifications.showRecording();
    } on Object {
      // intentionally swallowed — see comment above
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

  /// Atomically persist a finalized trip.
  ///
  /// Three outcomes, each a final variant of [PersistResult]:
  ///
  ///   * [PersistDiscardedTooShort] — the trip is below either the
  ///     30 s duration threshold OR the 100 m distance threshold (D-10).
  ///     No rows are written. The UX-03 notification is dismissed.
  ///   * [PersistSaved] — the trip was written to the `trips` table and
  ///     a matching `create` row was enqueued in the `sync_queue` table.
  ///     BOTH writes happen inside a single [AppDatabase.transaction]
  ///     call so either both succeed or both roll back. The UX-03
  ///     notification is dismissed.
  ///   * [PersistFailed] — the transaction threw. No rows survive
  ///     (atomic rollback). The UX-03 notification is dismissed even on
  ///     failure (T-02-20 — the notification must never outlive the
  ///     tracking session).
  ///
  /// Direction is labeled at save time using [DirectionLabelService] and the
  /// morning cutoff from user preferences (D-06). The `userId` column
  /// defaults to [kDefaultUserId] at the DB level (D-02), so we do not set
  /// it here. The `sync_queue` row has `payload = null` (D-13) — the sync
  /// engine re-reads the fresh trip row at sync time.
  Future<PersistResult> persistFinalizedTrip(FinalizedTrip trip) async {
    if (trip.durationSeconds < kMinTripDurationSeconds ||
        trip.distanceMeters < kMinTripDistanceMeters) {
      await _notifications.dismiss();
      return const PersistDiscardedTooShort();
    }
    try {
      // Phase 3 D-06: label at save time using the cutoff from user prefs.
      // startTime is UTC from the accumulator; convert to local for the rule
      // (Pitfall 2).
      final prefs = await _userPreferencesDao.getOrDefault();
      const labeler = DirectionLabelService();
      final direction = labeler.label(
        trip.startTime.toLocal(),
        prefs.morningCutoffHour,
      );
      await _database.transaction(() async {
        await _tripsDao.insertTrip(
          TripsCompanion.insert(
            id: trip.id,
            startTime: trip.startTime,
            endTime: trip.endTime,
            durationSeconds: trip.durationSeconds,
            distanceMeters: trip.distanceMeters,
            direction: direction,
            timeMovingSeconds: trip.timeMovingSeconds,
            timeStuckSeconds: trip.timeStuckSeconds,
            routePolyline: Value<String?>(trip.encodedPolyline),
          ),
        );
        await _syncQueueDao.enqueueCreate(trip.id);
      });
      await _notifications.dismiss();
      return PersistSaved(trip.id);
    } on Object catch (error) {
      await _notifications.dismiss();
      return PersistFailed(error);
    }
  }
}

/// Result of a [TrackingServiceController.persistFinalizedTrip] call.
///
/// Sealed so the UI layer can switch exhaustively on the three
/// outcomes without a default branch — matches the Phase 2 convention
/// established by `TrackingState` (plan 02-03).
sealed class PersistResult {
  const PersistResult();
}

/// The trip was persisted and enqueued for sync.
final class PersistSaved extends PersistResult {
  /// Construct a success result for [tripId].
  const PersistSaved(this.tripId);

  /// UUID of the persisted trip. Matches the Drift primary key.
  final String tripId;
}

/// The trip was below the D-10 threshold (either duration or distance).
/// Nothing was written.
final class PersistDiscardedTooShort extends PersistResult {
  /// Const singleton — the discard outcome carries no payload.
  const PersistDiscardedTooShort();
}

/// The transaction threw. No rows survive (atomic rollback). [error]
/// carries the root cause so the UI can surface a diagnostic without
/// leaking the stack trace (T-02-22).
final class PersistFailed extends PersistResult {
  /// Construct a failure result wrapping [error].
  const PersistFailed(this.error);

  /// Underlying error object. UI code should call `.toString()` on this
  /// when formatting a user-facing snackbar.
  final Object error;
}
