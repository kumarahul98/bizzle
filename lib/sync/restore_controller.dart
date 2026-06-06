import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/api_client.dart';

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
      // Plan 01: returns List<TripsCompanion>, already mapped via
      // TripSerializer.fromJson internally (HIGH-3). No forked mapper.
      final companions = await ref.read(apiClientProvider).restoreTrips();
      // Plan 03 / MEDIUM-3: one Drift batch, dedupe-by-UUID, NEW-row count.
      final inserted = await ref
          .read(tripsDaoProvider)
          .insertOrIgnoreTrips(companions);
      state = RestoreSuccess(inserted);
    } on Object {
      // Caught internally (T-11-03-02): a failed restore becomes RestoreError,
      // never a rethrow / crash / corrupt DB. No error string is surfaced.
      state = const RestoreError();
    }
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
