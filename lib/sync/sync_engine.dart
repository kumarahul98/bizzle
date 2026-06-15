import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/sync_status.dart';

/// Background drain of the Drift `sync_queue` to the Phase 10 backend
/// (SYNC-02). One-way, client-authoritative (CLAUDE.md): the engine only
/// PUSHES local changes to the server and never reads back for app operation.
///
/// Core responsibilities:
///   * [processPending] — collapse the pending queue to ONE effective op per
///     `tripId` (HIGH-1), batch the create/update upserts into a single
///     `POST /trips/sync` (chunked at [kMaxSyncBatchTrips]), send deletes
///     individually, and branch failures on [SyncException.retryable]
///     (HIGH-2): retryable → `incrementRetry` + exponential backoff (terminal
///     `markFailed` at [kSyncQueueMaxRetries]); non-retryable (e.g. a 400
///     validation poison-pill) → `markFailed` IMMEDIATELY without consuming
///     the retry budget.
///   * [retryFailed] — the explicit "tap to retry" entry point (bound by
///     Plan 03): clear the backoff window, `resetFailed`, then drain again.
///   * [start]/[dispose] — own the three D-07 triggers (post-save via
///     `watchPending()`, connectivity-restored rising edge, app-resume) and
///     release them. Triggers are fire-and-forget and never block the UI.
///
/// Concurrency: a single [_inFlight] mutex guarantees one drain at a time
/// (T-11-02-02); a backoff WINDOW ([_backoffUntil]) makes triggers coalesce
/// while a retry is scheduled so a flapping connection or repeated resume can
/// never tight-loop the server (MEDIUM-2 / T-11-02-03).
///
/// SECURITY (T-11-02-01): no failure ever surfaces `error.toString()` (which
/// could carry a uid/url/token fragment) — failures are mapped only to the
/// sealed [SyncStatus]. No payloads, tokens, or uids are logged.
class SyncEngine {
  /// Construct with INJECTED seams so unit tests need no real network,
  /// connectivity, or Firebase platform channels.
  SyncEngine({
    required ApiClient apiClient,
    required SyncQueueDao syncQueueDao,
    required TripsDao tripsDao,
    required SyncStatusNotifier status,
    required bool Function() isSignedIn,
    required Future<bool> Function() isOnline,
    DateTime Function() now = DateTime.now,
  }) : _api = apiClient,
       _queueDao = syncQueueDao,
       _tripsDao = tripsDao,
       _status = status,
       _isSignedIn = isSignedIn,
       _isOnline = isOnline,
       _now = now;

  final ApiClient _api;
  final SyncQueueDao _queueDao;
  final TripsDao _tripsDao;
  final SyncStatusNotifier _status;
  final bool Function() _isSignedIn;
  final Future<bool> Function() _isOnline;
  final DateTime Function() _now;

  /// In-flight mutex: only one drain runs at a time (T-11-02-02).
  bool _inFlight = false;

  /// Scheduled retry timer; the ONLY path that re-attempts during a backoff
  /// window. Cancelled on dispose / retryFailed / a successful drain.
  Timer? _backoffTimer;

  /// Open backoff WINDOW (MEDIUM-2). While `now()` is before this, incoming
  /// triggers coalesce (return early) instead of bypassing [_backoffTimer].
  DateTime? _backoffUntil;

  /// Time of the last auto-retry triggered by connectivity or resume.
  /// Enforces [kFailedAutoRetryWindow] so permanently failed rows don't hammer the server.
  DateTime? _lastAutoRetry;

  /// Cached online state for offline→online rising-edge detection. Seeded in
  /// [start] BEFORE the connectivity listener attaches (M3).
  bool _wasOnline = false;

  /// Upload pause flag
  bool _uploadsPaused = false;

  StreamSubscription<List<SyncQueueRow>>? _pendingSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  AppLifecycleListener? _lifecycleListener;

  /// Whether a backoff window is currently active (test/diagnostic predicate).
  bool backoffActive() {
    final until = _backoffUntil;
    return until != null && _now().isBefore(until);
  }

  /// Whether the auto-retry time gate is open (exhausted).
  bool get isAutoRetryExhausted =>
      _lastAutoRetry == null || _now().difference(_lastAutoRetry!) > kFailedAutoRetryWindow;

  /// Pure exponential-backoff delay for [retryCount]: `base × 2^retryCount`
  /// capped at [kSyncRetryMaxDelay]. Guards against shift overflow by capping
  /// the exponent before shifting.
  Duration backoffDelay(int retryCount) {
    // 2^30 × base already vastly exceeds the cap, so clamp the exponent.
    final exponent = retryCount > 30 ? 30 : retryCount;
    final scaled = kSyncRetryBaseDelay * (1 << exponent);
    return scaled > kSyncRetryMaxDelay ? kSyncRetryMaxDelay : scaled;
  }

  /// Drain all pending queue rows. Never rethrows into the caller (UI). See
  /// the class doc for collapse/batch/retry semantics.
  Future<void> processPending() async {
    // (a) In-flight guard — a concurrent trigger returns immediately. Claim
    //     the mutex SYNCHRONOUSLY (before any `await`) so two triggers that
    //     interleave around the offline check cannot both proceed.
    if (_inFlight) return;
    // (b) Backoff-window guard (MEDIUM-2) — the scheduled timer owns the next
    //     attempt; triggers must not bypass it. retryFailed() clears the
    //     window first, so an explicit retry is never blocked here.
    if (backoffActive()) return;
    // (c) Guest no-op — no status change, no DB writes (D-03 / T-11-02-04).
    if (!_isSignedIn()) return;
    // (d) Pause-uploads guard — D-02 during sign-in, prevent uploading until
    //     restore is done.
    if (_uploadsPaused) return;

    _inFlight = true;
    try {
      // (d) Offline no-op.
      if (!await _isOnline()) {
        _status.set(const SyncOffline());
        return;
      }
      await _drain();
    } on Object {
      // (f) Catch-all — never rethrow into the UI (T-11-02-01). Surface a
      //     generic failed status; no error string is leaked.
      _status.set(SyncFailed(await _failedCount()));
    } finally {
      _inFlight = false;
    }
  }

  /// The actual drain body, run under the [_inFlight] mutex. Returns the count
  /// of rows that failed this drain (drives the [SyncFailed] count).
  Future<void> _drain() async {
    final pending = await _queueDao.getPending();
    if (pending.isEmpty) {
      _status.set(const SyncSynced());
      return;
    }

    _status.set(const SyncSyncing());

    // HIGH-1: collapse to ONE effective op per tripId, in queue order.
    final upserts = <String, _Effective>{};
    final deletes = <String, _Effective>{};
    for (final row in pending) {
      final isDelete = row.action == kSyncActionDelete;
      if (isDelete) {
        // A delete supersedes any pending create/update for the same trip.
        final existingUpsert = upserts.remove(row.tripId);
        final eff = deletes.putIfAbsent(
          row.tripId,
          () => _Effective(row.id, row.retryCount),
        );
        if (existingUpsert != null) {
          // The create/update rows are superseded — mark synced w/o sending.
          eff.supersededIds
            ..add(existingUpsert.driverId)
            ..addAll(existingUpsert.supersededIds);
        }
        if (eff.driverId != row.id) eff.supersededIds.add(row.id);
      } else {
        // create / update — collapse into a single upsert. If a delete was
        // already seen for this trip, the row is superseded by that delete.
        final existingDelete = deletes[row.tripId];
        if (existingDelete != null) {
          existingDelete.supersededIds.add(row.id);
          continue;
        }
        final eff = upserts.putIfAbsent(
          row.tripId,
          () => _Effective(row.id, row.retryCount),
        );
        if (eff.driverId != row.id) eff.supersededIds.add(row.id);
      }
    }

    var hadFailure = false;

    // ---- Upserts: load live rows, drop missing, chunk, batch POST ---------
    final liveTrips = <TripRow>[];
    final effForTrip = <String, _Effective>{};
    for (final entry in upserts.entries) {
      final trip = await _tripsDao.findById(entry.key);
      if (trip == null) {
        // Missing-trip skip: mark all of this trip's rows synced, drop it.
        await _markAllSynced(entry.value);
        continue;
      }
      liveTrips.add(trip);
      effForTrip[entry.key] = entry.value;
    }

    for (var i = 0; i < liveTrips.length; i += kMaxSyncBatchTrips) {
      final end = (i + kMaxSyncBatchTrips < liveTrips.length)
          ? i + kMaxSyncBatchTrips
          : liveTrips.length;
      final chunk = liveTrips.sublist(i, end);
      try {
        await _api.syncTrips(chunk);
        for (final trip in chunk) {
          await _markAllSynced(effForTrip[trip.id]!);
        }
      } on SyncException catch (e) {
        for (final trip in chunk) {
          final failed = await _handleFailure(effForTrip[trip.id]!, e);
          hadFailure = hadFailure || failed;
        }
      }
    }

    // ---- Deletes: individual, idempotent (404 → success via ApiClient) ----
    for (final entry in deletes.entries) {
      try {
        await _api.deleteTrip(entry.key);
        await _markAllSynced(entry.value);
      } on SyncException catch (e) {
        final failed = await _handleFailure(entry.value, e);
        hadFailure = hadFailure || failed;
      }
    }

    if (hadFailure) {
      _status.set(SyncFailed(await _queueDao.countFailed()));
    } else {
      // Genuine state change — clear any stale backoff window (MEDIUM-2).
      _clearBackoff();
      _status.set(const SyncSynced());
    }
  }

  /// Mark a driver row and all its superseded rows synced.
  Future<void> _markAllSynced(_Effective eff) async {
    await _queueDao.markSynced(eff.driverId);
    for (final id in eff.supersededIds) {
      await _queueDao.markSynced(id);
    }
  }

  /// Apply HIGH-2 failure branching to the DRIVER row. Superseded rows are
  /// left pending — they collapse again on the next run. Returns whether the
  /// row reached (or already was at) a terminal/retry state worth surfacing.
  Future<bool> _handleFailure(_Effective eff, SyncException e) async {
    final id = eff.driverId;
    // notSignedIn is never a failure (defensive — step (c) already gates).
    if (e.notSignedIn) return false;

    if (!e.retryable) {
      // Non-retryable poison pill (e.g. 400) — terminal immediately, retry
      // budget preserved, no backoff scheduled.
      await _queueDao.markFailed(id);
      return true;
    }

    // Retryable — bump the counter; promote to failed at the cap, else
    // schedule a backoff window.
    final nextRetry = eff.retryCount + 1;
    await _queueDao.incrementRetry(id);
    if (nextRetry >= kSyncQueueMaxRetries) {
      await _queueDao.markFailed(id);
    } else {
      _scheduleBackoff(nextRetry);
    }
    return true;
  }

  /// Open the backoff window and arm the timer (MEDIUM-2). The timer firing is
  /// the ONLY path that re-attempts during the window — triggers coalesce.
  void _scheduleBackoff(int retryCount) {
    _backoffTimer?.cancel();
    final delay = backoffDelay(retryCount);
    _backoffUntil = _now().add(delay);
    _backoffTimer = Timer(delay, () {
      _backoffUntil = null;
      unawaited(processPending());
    });
  }

  /// Cancel the timer and close the backoff window.
  void _clearBackoff() {
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _backoffUntil = null;
  }

  /// Explicit retry entry point (H2) bound by Plan 03's "tap to retry" row.
  /// Clears the backoff window FIRST (a user-initiated state change is never
  /// blocked by the MEDIUM-2 guard), re-enqueues terminally-failed rows, then
  /// drains.
  Future<void> retryFailed() async {
    _lastAutoRetry = _now();
    _clearBackoff();
    await _queueDao.resetFailed();
    await processPending();
  }

  /// Pauses uploads. Used during sign-in to prevent guest trips from uploading before restore completes.
  void pauseUploads() {
    _uploadsPaused = true;
  }

  /// Resumes uploads and triggers a drain if there are pending items.
  void resumeUploads() {
    _uploadsPaused = false;
    unawaited(processPending());
  }

  /// Attach the three D-07 triggers and seed connectivity state. Runs at
  /// provider construction (eager mount in app.dart) so the post-save
  /// `watchPending()` subscription is live before the first trip is saved.
  Future<void> start() async {
    // M3: seed _wasOnline from the v7 List<ConnectivityResult> BEFORE
    // attaching the listener, so the first offline→online edge is not missed.
    final initial = await Connectivity().checkConnectivity();
    _wasOnline = initial.any((r) => r != ConnectivityResult.none);

    // Post-save nudge (M1): a new pending row drains automatically. Gate on a
    // RISING edge of the pending count (MR-03) so a successful drain's own
    // `markSynced` writes — which SHRINK the pending set — do not re-fire a
    // redundant empty `processPending()`. Only a genuine new enqueue (count
    // increases) nudges; failed-row retry still flows through `retryFailed()`
    // and the connectivity/resume triggers remain independent.
    var lastPending = 0;
    _pendingSub = _queueDao.watchPending().listen((rows) {
      if (rows.length > lastPending) unawaited(processPending());
      lastPending = rows.length;
    });

    // Connectivity-restored: only on the offline→online rising edge.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final nowOnline = results.any((r) => r != ConnectivityResult.none);
      if (!_wasOnline && nowOnline) {
        if (_lastAutoRetry == null || _now().difference(_lastAutoRetry!) > kFailedAutoRetryWindow) {
          unawaited(retryFailed());
        } else {
          unawaited(processPending());
        }
      }
      _wasOnline = nowOnline;
    });

    // App-resume.
    _lifecycleListener = AppLifecycleListener(
      onResume: handleResume,
    );
  }

  @visibleForTesting
  void handleResume() {
    if (_lastAutoRetry == null || _now().difference(_lastAutoRetry!) > kFailedAutoRetryWindow) {
      unawaited(retryFailed());
    } else {
      unawaited(processPending());
    }
  }

  /// Release all four resources (T-11-02 disposal).
  void dispose() {
    unawaited(_pendingSub?.cancel());
    unawaited(_connectivitySub?.cancel());
    _lifecycleListener?.dispose();
    _backoffTimer?.cancel();
  }

  Future<int> _failedCount() => _queueDao.countFailed();
}

/// Collapsed effective op for one tripId: the queue row that drives the send
/// plus the superseded rows that get marked synced alongside it. [retryCount]
/// is the driver row's current retry counter, captured from the pending read
/// so failure handling needs no re-query.
class _Effective {
  _Effective(this.driverId, this.retryCount);

  final int driverId;
  final int retryCount;
  final List<int> supersededIds = <int>[];
}

/// keepAlive provider holding the production [SyncEngine]. PLAIN
/// `Provider<SyncEngine>` (NOT a Notifier) — Plan 03 binds to the instance
/// directly (`ref.read(syncEngineProvider).retryFailed()`, no `.notifier`).
///
/// PRODUCTION wiring (M4): `isSignedIn` reads the REAL [authStateProvider]
/// (live FirebaseAuth session); the token attach lives in
/// [apiClientProvider]'s real `getIdToken` seam. `isOnline` uses the real
/// connectivity_plus v7 `List<ConnectivityResult>` check.
///
/// The eager `ref.watch(syncEngineProvider)` in `app.dart` CONSTRUCTS this
/// provider at app root, which runs [SyncEngine.start] — making the
/// post-save subscription live from startup. Construction never blocks the
/// UI build; all trigger handlers are fire-and-forget.
final Provider<SyncEngine> syncEngineProvider = Provider<SyncEngine>(
  (ref) {
    final engine = SyncEngine(
      apiClient: ref.watch(apiClientProvider),
      syncQueueDao: ref.watch(syncQueueDaoProvider),
      tripsDao: ref.watch(tripsDaoProvider),
      status: ref.read(syncStatusProvider.notifier),
      isSignedIn: () => ref.read(authStateProvider) is AuthSignedIn,
      isOnline: () async => (await Connectivity().checkConnectivity()).any(
        (r) => r != ConnectivityResult.none,
      ),
    );
    unawaited(engine.start());
    ref.onDispose(engine.dispose);
    return engine;
  },
  name: 'syncEngineProvider',
);
