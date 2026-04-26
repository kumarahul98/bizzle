import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/providers.dart';

/// Reactive stream of all trips as summaries, newest-first.
///
/// Consumed by HistoryScreen (Phase 4) and StatsScreen (Phase 5).
/// Manual provider — no @riverpod annotation per lib/database/providers.dart
/// constraint (analyzer version conflict documented there).
final StreamProvider<List<TripSummary>> allTripSummariesProvider =
    StreamProvider<List<TripSummary>>(
      (ref) => ref.watch(tripsDaoProvider).watchAllSummaries(),
      name: 'allTripSummariesProvider',
    );

/// Group a list of [TripSummary] (ordered newest-first) into a map keyed
/// by date-only [DateTime] values in local time.
///
/// Pitfall 3 mitigation: converts startTime to local time before stripping
/// the time component to ensure same-day trips group together regardless
/// of UTC offset.
///
/// Returns entries in insertion order (newest date first).
Map<DateTime, List<TripSummary>> groupTripsByDate(
  List<TripSummary> trips,
) {
  final result = <DateTime, List<TripSummary>>{};
  for (final trip in trips) {
    final local = trip.startTime.toLocal();
    final dateOnly = DateTime(local.year, local.month, local.day);
    (result[dateOnly] ??= <TripSummary>[]).add(trip);
  }
  return result;
}

/// Format a date-only [DateTime] as a history section header label.
///
/// Returns [kHistoryDateToday] for today, [kHistoryDateYesterday] for
/// yesterday, and 'EEE d MMM' (e.g. 'Mon 21 Apr') for older dates.
String formatDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (date == today) return kHistoryDateToday;
  if (date == yesterday) return kHistoryDateYesterday;
  return DateFormat('EEE d MMM').format(date);
}
