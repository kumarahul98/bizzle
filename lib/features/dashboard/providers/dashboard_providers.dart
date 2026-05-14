import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';

/// Trips whose [TripSummary.startTime] (converted to local time) falls
/// on today's calendar date. Derived from [allTripSummariesProvider]
/// so no duplicate Drift subscription is opened.
///
/// Returns the same [AsyncValue] states (loading/error/data) as the
/// upstream provider.
final Provider<AsyncValue<List<TripSummary>>> todaysTripSummariesProvider =
    Provider<AsyncValue<List<TripSummary>>>(
      (ref) {
        final asyncTrips = ref.watch(allTripSummariesProvider);
        return asyncTrips.whenData((trips) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          return trips.where((trip) {
            final local = trip.startTime.toLocal();
            final date = DateTime(local.year, local.month, local.day);
            return date == today;
          }).toList();
        });
      },
      name: 'todaysTripSummariesProvider',
    );
