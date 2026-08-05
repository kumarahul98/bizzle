import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/services/trip_edit_recompute.dart';
import 'package:uuid/uuid.dart';

/// Finite state for trip edit, delete, and manual-entry operations.
///
/// Use exhaustive switch at every call site. Never add a default branch.
@immutable
sealed class TripManagementState {
  const TripManagementState();
}

/// No operation in progress.
final class TripManagementIdle extends TripManagementState {
  const TripManagementIdle();
}

/// A write operation is in progress.
final class TripManagementSaving extends TripManagementState {
  const TripManagementSaving();
}

/// The last operation completed successfully. Call
/// `TripManagementNotifier.reset` after consuming this state.
final class TripManagementSaved extends TripManagementState {
  const TripManagementSaved();
}

/// The last operation failed. [message] is the error description.
/// Call `TripManagementNotifier.reset` after presenting the error.
final class TripManagementError extends TripManagementState {
  const TripManagementError(this.message);

  /// User-facing error description.
  final String message;
}

/// Notifier for trip edit, delete, and manual-entry persistence operations.
///
/// Manual provider — no @riverpod annotation per the project-wide constraint
/// documented in `lib/database/providers.dart`.
class TripManagementNotifier extends Notifier<TripManagementState> {
  @override
  TripManagementState build() => const TripManagementIdle();

  /// Edit an existing trip — the single write path for BOTH the
  /// direction-only edit and the Phase 19 full edit (D-12).
  ///
  /// Wraps every write in one `AppDatabase.transaction` for atomicity
  /// (D-08/D-12). [startTimeUtc] and [endTimeUtc] must be UTC DateTimes.
  ///
  /// Direction-only path (the original callers — edit_trip_sheet,
  /// trip_detail's `_handleDirectionChanged`): pass only the four required
  /// args. `durationSeconds` is recomputed from the window, the
  /// moving/stuck/paused columns are left untouched (`Value.absent()`),
  /// `is_edited` is NOT set, and existing breaks are NOT touched — so the
  /// write is byte-for-byte what it was before Phase 19.
  ///
  /// Full-edit path (Plan 02's edit sheet): in addition to the four args,
  /// pass [breaks] (the validated/clamped segments — non-null even if
  /// empty), the recomputed [totalPausedSeconds]/[timeMovingSeconds]/
  /// [timeStuckSeconds], a [durationSecondsOverride] (the recomputed active
  /// duration), and `markEdited: true`. The notifier does NOT recompute —
  /// the sheet computes via [TripEditRecompute] and passes the numbers, so
  /// the math stays pure and unit-tested while the notifier stays I/O-only.
  /// When [breaks] is non-null the trip's existing breaks are replaced
  /// wholesale (delete-all → insert) inside the same transaction.
  ///
  /// Phase 21 (D-03): every editTrip call stamps `direction_source = manual`
  /// because both call sites are a user explicitly setting the direction (the
  /// Phase 17 quick toggle and the Phase 19 edit sheet). This makes a user's
  /// pick backfill-proof — the Plan 03 geofence backfill re-labels ONLY rows
  /// whose source is NOT manual (SC#4). `insertManualTrip` is NOT tagged: a
  /// manual entry has no GPS to geofence and the user does not pick a direction
  /// at create, so it keeps the DB default `time` (D-11).
  Future<void> editTrip({
    required String tripId,
    required String direction,
    required DateTime startTimeUtc,
    required DateTime endTimeUtc,
    List<EditBreakSegment>? breaks,
    int? totalPausedSeconds,
    int? timeMovingSeconds,
    int? timeStuckSeconds,
    int? durationSecondsOverride,
    bool markEdited = false,
  }) async {
    state = const TripManagementSaving();
    try {
      final db = ref.read(appDatabaseProvider);
      final tripsDao = ref.read(tripsDaoProvider);
      final breaksDao = ref.read(tripBreaksDaoProvider);
      final stuckSegmentsDao = ref.read(tripStuckSegmentsDaoProvider);
      final syncDao = ref.read(syncQueueDaoProvider);
      await db.transaction(() async {
        await tripsDao.updateTrip(
          TripsCompanion(
            id: Value(tripId),
            direction: Value(direction),
            // Phase 21 (D-03): every editTrip call is the user setting the
            // direction (the Phase 17 quick toggle via _handleDirectionChanged
            // AND the Phase 19 edit sheet both route here), so stamp
            // direction_source=manual. This is what guarantees the Plan 03
            // backfill never clobbers a user's choice (SC#4).
            directionSource: const Value(kDirectionSourceManual),
            startTime: Value(startTimeUtc),
            endTime: Value(endTimeUtc),
            durationSeconds: Value(
              durationSecondsOverride ??
                  endTimeUtc.difference(startTimeUtc).inSeconds,
            ),
            // Full-edit-only columns: written only when markEdited is true,
            // otherwise left absent so the direction-only path is unchanged.
            totalPausedSeconds: markEdited
                ? Value(totalPausedSeconds ?? 0)
                : const Value.absent(),
            timeMovingSeconds: markEdited
                ? Value(timeMovingSeconds ?? 0)
                : const Value.absent(),
            timeStuckSeconds: markEdited
                ? Value(timeStuckSeconds ?? 0)
                : const Value.absent(),
            isEdited: markEdited ? const Value(true) : const Value.absent(),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        // Wholesale break replace — only when the caller supplied breaks.
        // Breaks are replaced, not diffed, so each row gets a fresh UUID.
        if (breaks != null) {
          await breaksDao.deleteBreaksForTrip(tripId);
          if (breaks.isNotEmpty) {
            await breaksDao.insertBreaks([
              for (final segment in breaks)
                TripBreaksCompanion.insert(
                  id: const Uuid().v4(),
                  tripId: tripId,
                  startTime: segment.start,
                  endTime: Value<DateTime>(segment.end),
                ),
            ]);
          }
        }
        // A stuck segment records WHERE the user was physically slow. No
        // edit of the trip's times can make that stretch of road untrue, so
        // an edit no longer destroys it (D-2). Only the segments wholly
        // outside the new window — the parts of the recording the user cut
        // away — are removed; everything that overlaps the window survives.
        // A surviving segment is kept entirely UNTOUCHED, not clamped to the
        // new window (D-3): its point indices address an unedited polyline,
        // and clamping the timestamps without clamping the geometry in step
        // would misreport which stretch of road was actually slow.
        //
        // Accepted consequence (D-4): `sum(painted segments) <=
        // timeStuckSeconds` is deliberately ABANDONED for edited trips —
        // `kStuckInfoBody` no longer claims it. The direction-only path
        // leaves timeStuckSeconds untouched, so it never runs this and its
        // segments stay valid.
        if (markEdited) {
          await stuckSegmentsDao.deleteSegmentsOutsideWindow(
            tripId: tripId,
            startTimeUtc: startTimeUtc,
            endTimeUtc: endTimeUtc,
          );
        }
        await syncDao.enqueueUpdate(tripId);
      });
      state = const TripManagementSaved();
    } on Object catch (e) {
      state = TripManagementError(e.toString());
    }
  }

  /// SOFT-delete a trip and enqueue the delete tombstone (Phase 35, D-01/D-03).
  ///
  /// As of Phase 35 this no longer issues a hard `DELETE`: it stamps
  /// `deletedAt` so the trip vanishes from history, the dashboard and stats
  /// (all via the single `watchAllSummaries` filter) yet stays recoverable
  /// from Settings → Deleted trips for [kTrashRetentionDays] days. The wire
  /// contract is UNCHANGED — the existing delete action and its
  /// `{id, userId}` payload are enqueued exactly as before, and the server
  /// still soft-deletes (D-03).
  ///
  /// D-08: both writes run in a single transaction. Pitfall 3: the delete
  /// payload JSON is still built BEFORE the row is modified. With soft delete
  /// the row survives, so the constraint has relaxed — but building the
  /// payload inside the same transaction keeps it consistent with the write.
  Future<void> deleteTrip(String tripId) async {
    state = const TripManagementSaving();
    try {
      final db = ref.read(appDatabaseProvider);
      final tripsDao = ref.read(tripsDaoProvider);
      final syncDao = ref.read(syncQueueDaoProvider);
      await db.transaction(() async {
        // Build payload FIRST — Pitfall 3 mitigation.
        final payload = jsonEncode(<String, String>{
          'id': tripId,
          'userId': kDefaultUserId,
        });
        await tripsDao.softDeleteTrip(tripId, DateTime.now().toUtc());
        await syncDao.enqueueDelete(tripId: tripId, payload: payload);
      });
      state = const TripManagementSaved();
    } on Object catch (e) {
      state = TripManagementError(e.toString());
    }
  }

  /// Restore a soft-deleted trip and enqueue a create (Phase 35, D-03).
  ///
  /// Clears `deletedAt` so the trip returns to every live surface with its
  /// breaks and stuck segments intact (they were never removed), then enqueues
  /// a create. The create carries a NULL payload by the standard contract —
  /// the sync engine re-reads the freshly un-deleted row at flush time — and
  /// the server's upsert clears its own `deleted: true`. This is safe because
  /// sync is one-way and client-authoritative: the client is the only writer,
  /// so no remote state can disagree and no conflict resolution is needed.
  Future<void> restoreTrip(String tripId) async {
    state = const TripManagementSaving();
    try {
      final db = ref.read(appDatabaseProvider);
      final tripsDao = ref.read(tripsDaoProvider);
      final syncDao = ref.read(syncQueueDaoProvider);
      await db.transaction(() async {
        await tripsDao.restoreTrip(tripId);
        await syncDao.enqueueCreate(tripId);
      });
      state = const TripManagementSaved();
    } on Object catch (e) {
      state = TripManagementError(e.toString());
    }
  }

  /// PERMANENTLY (hard) delete a soft-deleted trip from the local database
  /// (Phase 35, D-05). Cascade removes its breaks and stuck segments.
  ///
  /// Enqueues NOTHING: the delete tombstone was already pushed when the trip
  /// was soft-deleted, and the server keeps its own soft-deleted copy per the
  /// project-wide rule that Firestore never hard-deletes. A second delete would
  /// be redundant. This is the irreversible action behind the Trash's "Delete
  /// permanently" confirmation.
  Future<void> deleteTripPermanently(String tripId) async {
    state = const TripManagementSaving();
    try {
      final tripsDao = ref.read(tripsDaoProvider);
      await tripsDao.deleteTrip(tripId);
      state = const TripManagementSaved();
    } on Object catch (e) {
      state = TripManagementError(e.toString());
    }
  }

  /// Insert a manually entered trip (no GPS data).
  ///
  /// D-10: the trip is saved with `isManualEntry`=true and
  /// `routePolyline`='' (empty string). [timeStuckSeconds] and
  /// [distanceMeters] default to 0 when the user left those fields blank.
  ///
  /// [startTimeUtc] MUST be UTC midnight of the chosen local date:
  /// `DateTime(year, month, day).toUtc()` — Pitfall 6 mitigation.
  /// [endTimeUtc] = startTimeUtc + duration.
  /// [direction] is pre-computed by the sheet using
  /// `DirectionLabelService`.
  ///
  /// [timeStuckSeconds] is clamped to the range [0, durationSeconds] to
  /// prevent impossible values. [distanceMeters] is clamped to ≥ 0.
  Future<void> insertManualTrip({
    required DateTime startTimeUtc,
    required DateTime endTimeUtc,
    required String direction,
    int timeStuckSeconds = 0,
    double distanceMeters = 0,
  }) async {
    state = const TripManagementSaving();
    try {
      final db = ref.read(appDatabaseProvider);
      final tripsDao = ref.read(tripsDaoProvider);
      final syncDao = ref.read(syncQueueDaoProvider);
      final tripId = const Uuid().v4();
      final durationSeconds = endTimeUtc.difference(startTimeUtc).inSeconds;
      // Clamp inputs to valid ranges (T-07-04-03 / T-07-04-04 mitigations).
      final clampedStuck = timeStuckSeconds.clamp(0, durationSeconds);
      final clampedDistance = distanceMeters < 0 ? 0.0 : distanceMeters;
      await db.transaction(() async {
        await tripsDao.insertTrip(
          TripsCompanion.insert(
            id: tripId,
            startTime: startTimeUtc,
            endTime: endTimeUtc,
            durationSeconds: durationSeconds,
            distanceMeters: clampedDistance,
            routePolyline: const Value(''),
            direction: direction,
            // The direction on a manual entry is authored by the user in the
            // entry sheet, so its provenance is 'manual' — not the column
            // default 'time'. Leaving it at 'time' made the trip eligible for
            // the restore enrichment at `restore_controller.dart` (local
            // source 'time' + cloud source non-'time' => cloud direction
            // wins), which could overwrite the user's own pick — precisely
            // what T-21-03-01 forbids.
            directionSource: const Value(kDirectionSourceManual),
            timeMovingSeconds: durationSeconds - clampedStuck,
            timeStuckSeconds: clampedStuck,
            isManualEntry: const Value(true),
          ),
        );
        await syncDao.enqueueCreate(tripId);
      });
      state = const TripManagementSaved();
    } on Object catch (e) {
      state = TripManagementError(e.toString());
    }
  }

  /// Reset to `TripManagementIdle` after the caller has consumed
  /// `TripManagementSaved` or `TripManagementError`.
  void reset() => state = const TripManagementIdle();
}

/// Provider for trip management state and operations.
///
/// keepAlive = true by default (bare `NotifierProvider` in Riverpod 3.x).
final NotifierProvider<TripManagementNotifier, TripManagementState>
tripManagementProvider =
    NotifierProvider<TripManagementNotifier, TripManagementState>(
      TripManagementNotifier.new,
      name: 'tripManagementProvider',
    );

/// Parse a `HH:MM` duration string.
///
/// Returns null for any of: malformed input, non-numeric segments,
/// hours outside 0-23, minutes outside 0-59, or a zero duration (0:00).
/// Returns a `Duration` for valid input in the range 0:01 to 23:59.
///
/// Exported from this file so `manual_entry_sheet.dart` can import
/// it alongside the notifier without a separate utility import.
Duration? parseHhMm(String input) {
  final parts = input.trim().split(':');
  if (parts.length != 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
    return null;
  }
  final duration = Duration(hours: hours, minutes: minutes);
  if (duration == Duration.zero) return null;
  return duration;
}
