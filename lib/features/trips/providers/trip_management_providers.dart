import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';

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
