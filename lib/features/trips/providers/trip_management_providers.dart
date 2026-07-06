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
        await syncDao.enqueueUpdate(tripId);
      });
      state = const TripManagementSaved();
    } on Object catch (e) {
      state = TripManagementError(e.toString());
    }
  }

  /// Delete a trip and enqueue the tombstone.
  ///
  /// D-08: both DAO calls are in a single transaction. Pitfall 3:
  /// the delete payload JSON is built BEFORE `TripsDao.deleteTrip` is
  /// called, because the row must still exist at payload-build time.
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
        await tripsDao.deleteTrip(tripId);
        await syncDao.enqueueDelete(tripId: tripId, payload: payload);
      });
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
