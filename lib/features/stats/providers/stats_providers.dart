import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';

/// Derived stats provider for the Stats screen (STAT-01..05).
///
/// Watches [allTripSummariesProvider] (the existing Drift-backed
/// `StreamProvider<List<TripSummary>>` from Phase 4) and transforms each
/// emission into a [StatsSummary] via [computeStatsSummary].
///
/// Why a derived `Provider` (not a fresh `StreamProvider`)?
///   * Reuses the single Drift subscription owned by
///     [allTripSummariesProvider] — no duplicate `watchAllSummaries()`
///     call (CONTEXT D-06: single source of truth).
///   * Riverpod's `AsyncValue.whenData` preserves loading/error states
///     unchanged and applies the transform only when data arrives, so
///     the screen-level `asyncStats.when(...)` dispatch keeps working
///     identically to `HistoryScreen`.
///
/// Why `DateTime.now()` inside `whenData`?
///   * The week/month/28-day boundaries are anchored to "now" at the
///     instant of computation. Each emission of
///     [allTripSummariesProvider] (driven by Drift writes) recomputes
///     against a fresh `DateTime.now()`, so a midnight or Monday
///     rollover during the user's session is reflected the next time
///     the trips table changes. Tests bypass this by calling
///     [computeStatsSummary] directly with a pinned [DateTime].
final Provider<AsyncValue<StatsSummary>> statsSummaryProvider =
    Provider<AsyncValue<StatsSummary>>(
      (ref) {
        final asyncTrips = ref.watch(allTripSummariesProvider);
        return asyncTrips.whenData(
          (trips) => computeStatsSummary(trips, DateTime.now()),
        );
      },
      name: 'statsSummaryProvider',
    );
