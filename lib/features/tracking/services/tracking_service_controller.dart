import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/daos/trip_breaks_dao.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/tracking/services/location_accuracy_gate.dart';
import 'package:traevy/features/tracking/services/tracking_event_source.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';
import 'package:uuid/uuid.dart';

/// UI-isolate wrapper around the platform-selected [TrackingEventSource].
/// Thin by design — all tracking logic (GPS stream, accumulator, 1 Hz
/// snapshots, stop race guard) lives either in `tracking_service.dart`
/// (Android fbs isolate) or in `MainIsolateTrackingEngine` (iOS). This
/// class owns only:
///
///   * the start/stop lifecycle, including the Location-Services
///     pre-flight that the home screen cannot easily guard on its own;
///   * the stop command, forwarded to the shared [TrackingEventSource];
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
  /// Construct a controller bound to the platform-selected [source],
  /// [database], its DAOs, and the [notifications] wrapper. Production
  /// wiring is done in `tracking_providers.dart` via
  /// `trackingEventSourceProvider`.
  ///
  /// [accuracyGate] is the IOS-08 reduced-accuracy preflight gate. Defaults
  /// to a real [LocationAccuracyGate] backed by Geolocator; inject a fake
  /// in tests.
  TrackingServiceController({
    required TrackingEventSource source,
    required AppDatabase database,
    required TripsDao tripsDao,
    required SyncQueueDao syncQueueDao,
    required TrackingNotificationService notifications,
    required UserPreferencesDao userPreferencesDao,
    required TripBreaksDao tripBreaksDao,
    LocationAccuracyGate? accuracyGate,
  }) : _source = source,
       _database = database,
       _tripsDao = tripsDao,
       _syncQueueDao = syncQueueDao,
       _notifications = notifications,
       _userPreferencesDao = userPreferencesDao,
       _tripBreaksDao = tripBreaksDao,
       _accuracyGate = accuracyGate ?? LocationAccuracyGate();

  final TrackingEventSource _source;
  final AppDatabase _database;
  final TripsDao _tripsDao;
  final SyncQueueDao _syncQueueDao;
  final TrackingNotificationService _notifications;
  final UserPreferencesDao _userPreferencesDao;
  final TripBreaksDao _tripBreaksDao;
  final LocationAccuracyGate _accuracyGate;

  /// Start tracking. Returns `true` if the engine started successfully,
  /// `false` if the Location-Services pre-flight failed or the platform
  /// refused.
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
  ///     are toggled off system-wide, return `false` without starting
  ///     (the engine call would otherwise succeed, then Geolocator would
  ///     fail with an unhelpful error on the first sample).
  ///   * IOS-08 accuracy gate — on iOS, ensures full (precise) location
  ///     accuracy before opening the GPS stream.
  ///
  /// On a successful Android start the UX-03 foreground notification is
  /// shown via [TrackingNotificationService.showRecording] BEFORE the
  /// engine starts (D-14 race resolution). On iOS, CoreLocation shows
  /// its own system indicator (D-07); no flutter_local_notifications call
  /// is made.
  Future<bool> start() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // IOS-08 reduced-accuracy gate (D-05): on iOS, ensure full (precise)
    // location accuracy is available before opening the GPS stream.
    // If accuracy is still reduced after the prompt (user declined), block
    // recording — never compute speed stats from coarse 500-metre fixes.
    // Uses defaultTargetPlatform (not dart:io Platform.isIOS) so the branch
    // is exercisable in unit tests via debugDefaultTargetPlatformOverride.
    // Android branch is UNCHANGED — the gate is iOS-only.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final precise = await _accuracyGate.ensurePrecise();
      if (!precise) {
        return false;
      }
    }

    // Post the UX-03 notification BEFORE starting the engine on Android so
    // the action-bearing notification exists at kTrackingNotificationId when
    // fbs's setAsForegroundService promotes the service. This is the D-14
    // unification contract. On iOS, CoreLocation shows its own indicator
    // (D-07) so no notification is posted here.
    //
    // POST_NOTIFICATIONS denied on Android 13+ → tracking still works.
    // Do NOT rethrow (Deviation Rule 4).
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      try {
        await _notifications.showRecording();
      } on Object {
        // intentionally swallowed — see comment above
      }
    }

    return _source.start();
  }

  /// Tell the engine to stop. The engine responds asynchronously by
  /// emitting via [TrackingEventSource.onFinalized], which
  /// `TrackingNotifier` listens for and uses to transition the UI state
  /// through `TrackingStopping` back to `TrackingIdle`.
  Future<void> stop() async {
    await _source.stop();
  }

  /// Suspend the active trip (Phase 18, D-08). Thin passthrough to the
  /// platform-selected [TrackingEventSource]; the engine opens a break span on
  /// its accumulator and reflects `isPaused: true` on the next snapshot. The
  /// trip is NEVER ended — it resumes as one continuous record.
  Future<void> pause() async {
    await _source.pause();
  }

  /// Resume a paused trip (Phase 18, D-08). Thin passthrough — closes the open
  /// break span; the next snapshot carries `isPaused: false`.
  Future<void> resume() async {
    await _source.resume();
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
  ///
  /// TRACK-12 (D-06): if [directionOverride] is non-null (the user picked a
  /// direction on the active-tracking toggle), it is written to
  /// `trips.direction` instead of the time-of-day auto-label — the manual
  /// choice wins over the heuristic. When [directionOverride] is null the
  /// behaviour is byte-for-byte identical to the pre-Phase-17 auto-label
  /// path. No Drift schema change accompanies this — the value still lands in
  /// the existing `direction` column.
  Future<PersistResult> persistFinalizedTrip(
    FinalizedTrip trip, {
    String? directionOverride,
  }) async {
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
      final autoLabel = labeler.label(
        trip.startTime.toLocal(),
        prefs.morningCutoffHour,
        prefs.eveningCutoffHour,
      );
      // D-06: the manual override (if any) wins over the heuristic.
      final direction = directionOverride ?? autoLabel;
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
            // Phase 18 (D-07): the ACTIVE-duration aggregate. Unset would keep
            // the DB default 0, but writing it explicitly keeps the trip row
            // and its break rows internally consistent.
            totalPausedSeconds: Value<int>(trip.totalPausedSeconds),
          ),
        );
        // Phase 18 (D-07, T-18-06): break rows land in the SAME transaction as
        // the trip + sync row — atomic, all-or-nothing. The FK to trips.id is
        // satisfied because the trip insert above runs first.
        final breakRows = _breakRowsFor(trip);
        if (breakRows.isNotEmpty) {
          await _tripBreaksDao.insertBreaks(breakRows);
        }
        await _syncQueueDao.enqueueCreate(trip.id);
      });
      await _notifications.dismiss();
      return PersistSaved(trip.id);
    } on Object catch (error) {
      await _notifications.dismiss();
      return PersistFailed(error);
    }
  }

  /// Build the `trip_breaks` companions for [trip]'s primitive break list
  /// (Phase 18, D-07). Each break map carries UTC-microsecond `startUs` /
  /// `endUs` ints; we decode them back to UTC `DateTime`s and stamp a fresh
  /// UUID per row. The list is empty for a trip that never paused.
  List<TripBreaksCompanion> _breakRowsFor(FinalizedTrip trip) {
    const uuid = Uuid();
    return trip.breaks
        .map(
          (b) => TripBreaksCompanion.insert(
            id: uuid.v4(),
            tripId: trip.id,
            startTime: DateTime.fromMicrosecondsSinceEpoch(
              b['startUs']! as int,
              isUtc: true,
            ),
            endTime: Value<DateTime>(
              DateTime.fromMicrosecondsSinceEpoch(
                b['endUs']! as int,
                isUtc: true,
              ),
            ),
          ),
        )
        .toList(growable: false);
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
