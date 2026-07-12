import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/restore_conflict.dart';

/// Finite state of the manual restore-from-cloud flow (SYNC-03, D-08). A
/// sealed model — never a raw string — per the CLAUDE.md "sealed classes for
/// finite state" rule. The Settings restore row switches on these variants
/// exhaustively (never a `default`).
@immutable
sealed class RestoreState {
  const RestoreState();
}

/// Resting state — no restore has run, or the last result was acknowledged.
class RestoreIdle extends RestoreState {
  const RestoreIdle();
}

/// A restore download + insert is currently in flight.
class RestoreRestoring extends RestoreState {
  const RestoreRestoring();
}

/// The restore completed. [count] is the number of NEW trips inserted into
/// Drift (existing UUIDs were skipped, so `0` means "already up to date").
class RestoreSuccess extends RestoreState {
  const RestoreSuccess(this.count);

  /// Number of NEW trips written by this restore (dedupe-by-UUID delta).
  final int count;
}

/// The restore detected conflicts (SYNC-04).
class RestoreConflictState extends RestoreState {
  const RestoreConflictState(this.conflicts);

  /// The list of conflicts that need user resolution.
  final List<RestoreConflict> conflicts;
}

/// The restore failed (transport error, malformed envelope, etc.). The
/// concrete error is intentionally NOT carried — the UI shows a fixed copy
/// constant, never `error.toString()` (T-11-03-03 PII guard).
class RestoreError extends RestoreState {
  const RestoreError();
}

/// Drives the manual restore-from-cloud flow (SYNC-03, D-08).
///
/// `restore()` downloads all of the authenticated user's trips via Plan 01's
/// [ApiClient.restoreTrips] (which already maps the response envelope to
/// `List<TripsCompanion>` via `TripSerializer.fromJson` internally — HIGH-3),
/// then writes them into Drift in a SINGLE batch with dedupe-by-UUID
/// (`TripsDao.insertOrIgnoreTrips` — MEDIUM-3). It reports the count of NEW
/// trips inserted.
///
/// Restore is a DOWNLOAD: it NEVER enqueues sync_queue rows (it is the inverse
/// of the upload engine). It is client-authoritative — existing local rows are
/// never overwritten.
///
/// SECURITY / UX (T-11-03-02): all work is async and errors are caught
/// internally — `restore()` NEVER rethrows, so a tap can never crash or freeze
/// the UI. The Settings row reads [restoreControllerProvider] for live state
/// and guards against a double-tap while [RestoreRestoring].
///
/// Manual Riverpod 3.x `Notifier` (no `@riverpod` codegen — the project-wide
/// drift_dev/analyzer pin, see `lib/database/providers.dart`).
class RestoreController extends Notifier<RestoreState> {
  @override
  RestoreState build() => const RestoreIdle();

  /// Download all cloud trips and insert them (dedupe-by-UUID) into Drift.
  ///
  /// Transitions: idle → [RestoreRestoring] → [RestoreSuccess] (with the
  /// NEW-row count) on success, or [RestoreError] on any failure. Never
  /// rethrows.
  Future<void> restore() async {
    state = const RestoreRestoring();
    try {
      // Phase 26: ApiClient.restoreTrips() now returns ParsedTrip (trip +
      // breaks). This plan (26-03) only wires the trip half through
      // unchanged so restore keeps compiling/passing; persisting the
      // restored break companions is Plan 05's job (RESEARCH.md scope).
      final parsed = await ref.read(apiClientProvider).restoreTrips();
      final companions = parsed.map((p) => p.trip).toList();
      final tripsDao = ref.read(tripsDaoProvider);

      final localTrips = await tripsDao.getAllTrips();
      // Lookup structures built once so the per-cloud-trip work below stays
      // cheap for multi-year histories: O(1) UUID lookup, and an
      // ascending-start ordering that lets the overlap scan stop at the
      // first local trip starting at/after the cloud trip's end.
      final localById = <String, TripRow>{
        for (final t in localTrips) t.id: t,
      };
      final localsByStart = [...localTrips]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      final conflicts = <RestoreConflict>[];
      final nonConflicts = <TripsCompanion>[];

      for (final cloud in companions) {
        bool isConflict = false;

        final sameUuidLocal = localById[cloud.id.value];
        if (sameUuidLocal != null) {
          if (_isDifferent(sameUuidLocal, cloud)) {
            conflicts.add(
              SameUuidConflict(localTrip: sameUuidLocal, cloudTrip: cloud),
            );
            isConflict = true;
          }
        } else if (cloud.startTime.present && cloud.endTime.present) {
          for (final local in localsByStart) {
            // Sorted by startTime: once a local trip starts at/after the
            // cloud trip's end, neither it nor any later one can overlap.
            if (!local.startTime.isBefore(cloud.endTime.value)) break;
            if (_isOverlap(local, cloud)) {
              conflicts.add(
                OverlapConflict(localTrip: local, cloudTrip: cloud),
              );
              isConflict = true;
              break;
            }
          }
        }

        if (!isConflict && sameUuidLocal == null) {
          nonConflicts.add(cloud);
        }
      }

      final inserted = await tripsDao.insertOrIgnoreTrips(nonConflicts);

      if (conflicts.isNotEmpty) {
        state = RestoreConflictState(conflicts);
      } else {
        state = RestoreSuccess(inserted);
      }
    } on Object {
      state = const RestoreError();
    }
  }

  bool _isDifferent(TripRow local, TripsCompanion cloud) {
    if (cloud.startTime.present &&
        !local.startTime.isAtSameMomentAs(cloud.startTime.value))
      return true;
    if (cloud.endTime.present &&
        !local.endTime.isAtSameMomentAs(cloud.endTime.value))
      return true;
    if (cloud.durationSeconds.present &&
        local.durationSeconds != cloud.durationSeconds.value)
      return true;
    if (cloud.totalPausedSeconds.present &&
        local.totalPausedSeconds != cloud.totalPausedSeconds.value)
      return true;
    if (cloud.distanceMeters.present &&
        local.distanceMeters != cloud.distanceMeters.value)
      return true;
    if (cloud.direction.present && local.direction != cloud.direction.value)
      return true;
    if (cloud.directionSource.present &&
        local.directionSource != cloud.directionSource.value)
      return true;
    if (cloud.timeMovingSeconds.present &&
        local.timeMovingSeconds != cloud.timeMovingSeconds.value)
      return true;
    if (cloud.timeStuckSeconds.present &&
        local.timeStuckSeconds != cloud.timeStuckSeconds.value)
      return true;
    if (cloud.isManualEntry.present &&
        local.isManualEntry != cloud.isManualEntry.value)
      return true;
    if (cloud.isEdited.present && local.isEdited != cloud.isEdited.value)
      return true;
    if (cloud.routePolyline.present &&
        local.routePolyline != cloud.routePolyline.value)
      return true;
    return false;
  }

  bool _isOverlap(TripRow local, TripsCompanion cloud) {
    if (!cloud.startTime.present || !cloud.endTime.present) return false;
    final maxStart = local.startTime.isAfter(cloud.startTime.value)
        ? local.startTime
        : cloud.startTime.value;
    final minEnd = local.endTime.isBefore(cloud.endTime.value)
        ? local.endTime
        : cloud.endTime.value;
    if (maxStart.isBefore(minEnd)) {
      return minEnd.difference(maxStart).inSeconds > 60;
    }
    return false;
  }

  /// Transition to success after resolving conflicts.
  void resolveConflicts(int insertedCount) {
    state = RestoreSuccess(insertedCount);
  }
}

/// keepAlive `NotifierProvider` (bare, not `.autoDispose`) exposing the restore
/// flow state. Matches the manual-provider convention in
/// `lib/database/providers.dart`. Plan 03's Settings restore row binds to this.
final NotifierProvider<RestoreController, RestoreState>
restoreControllerProvider = NotifierProvider<RestoreController, RestoreState>(
  RestoreController.new,
  name: 'restoreControllerProvider',
);
