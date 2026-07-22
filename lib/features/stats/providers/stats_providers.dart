import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/stats/services/stats_period.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';

/// Selected calendar period for the Stats screen (Phase 34).
///
/// Provider state (not widget state) so that switching period moves every
/// period-aware card together: all cards watch [statsSummaryProvider], which
/// watches this. Defaults to [WeekPeriod]. Kept-alive so the selection
/// persists across tab switches for the lifetime of the app.
final NotifierProvider<SelectedStatsPeriodNotifier, StatsPeriod>
selectedStatsPeriodProvider =
    NotifierProvider<SelectedStatsPeriodNotifier, StatsPeriod>(
      SelectedStatsPeriodNotifier.new,
      name: 'selectedStatsPeriodProvider',
    );

/// Notifier for [selectedStatsPeriodProvider].
class SelectedStatsPeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => const WeekPeriod();

  /// Switch the stats screen to [period].
  // ignore: use_setters_to_change_properties — a named action reads better at
  // the call site than assigning a `period` setter on a notifier.
  void select(StatsPeriod period) {
    state = period;
  }
}

/// Derived stats provider for the Stats screen.
///
/// Watches [allTripSummariesProvider] (the shared Drift-backed stream) and
/// [selectedStatsPeriodProvider], transforming each emission into a
/// [StatsSummary] via [computeStatsSummary].
///
/// The dashboard week-loss card also watches this provider but reads only the
/// period-independent `week…` fields, so a period change on the stats screen
/// recomputes an identical week figure for the dashboard (D-03).
///
/// `DateTime.now()` is read inside the transform so week/month/year boundaries
/// are anchored to the instant of computation. Tests bypass this by calling
/// [computeStatsSummary] directly with a pinned [DateTime].
final Provider<AsyncValue<StatsSummary>> statsSummaryProvider =
    Provider<AsyncValue<StatsSummary>>(
      (ref) {
        final period = ref.watch(selectedStatsPeriodProvider);
        final asyncTrips = ref.watch(allTripSummariesProvider);
        return asyncTrips.whenData(
          (trips) => computeStatsSummary(trips, DateTime.now(), period: period),
        );
      },
      name: 'statsSummaryProvider',
    );
