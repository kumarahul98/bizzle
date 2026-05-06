import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
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

  /// Edit an existing trip's direction and times.
  ///
  /// Wraps `TripsDao.updateTrip` and `SyncQueueDao.enqueueUpdate` in a
  /// single `AppDatabase.transaction` for atomicity (D-08).
  /// [startTimeUtc] and [endTimeUtc] must be UTC DateTimes.
  Future<void> editTrip({
    required String tripId,
    required String direction,
    required DateTime startTimeUtc,
    required DateTime endTimeUtc,
  }) async {
    state = const TripManagementSaving();
    try {
      final db = ref.read(appDatabaseProvider);
      final tripsDao = ref.read(tripsDaoProvider);
      final syncDao = ref.read(syncQueueDaoProvider);
      await db.transaction(() async {
        await tripsDao.updateTrip(
          TripsCompanion(
            id: Value(tripId),
            direction: Value(direction),
            startTime: Value(startTimeUtc),
            endTime: Value(endTimeUtc),
            durationSeconds: Value(
              endTimeUtc.difference(startTimeUtc).inSeconds,
            ),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
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
