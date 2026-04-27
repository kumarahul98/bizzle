// Unit tests for todaysTripSummariesProvider (Phase 6, Plan 01 — RED state).
//
// This file imports dashboard_providers.dart which does not exist yet.
// The compile failure is the intentional RED state; Plans 02–04 create
// the production code that turns it GREEN.
//
// Test structure mirrors test/unit/features/trips/history_grouping_test.dart
// — same TripSummary factory pattern and ProviderContainer usage.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/dashboard/providers/dashboard_providers.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:uuid/uuid.dart';

TripSummary _makeTrip(DateTime startTime) {
  final endTime = startTime.add(const Duration(hours: 1));
  return TripSummary(
    id: const Uuid().v4(),
    startTime: startTime,
    endTime: endTime,
    durationSeconds: endTime.difference(startTime).inSeconds,
    distanceMeters: 0,
    direction: kDirectionToOffice,
    timeMovingSeconds: 3600,
    timeStuckSeconds: 0,
    isManualEntry: false,
  );
}

void main() {
  group('todaysTripSummariesProvider', () {
    test('includes trips starting today in local time', () async {
      final container = ProviderContainer(
        overrides: [
          allTripSummariesProvider.overrideWith(
            (ref) =>
                Stream<List<TripSummary>>.value([_makeTrip(DateTime.now())]),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(todaysTripSummariesProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      final result = container.read(todaysTripSummariesProvider);
      expect(result.value, hasLength(1));
    });

    test('excludes trips starting yesterday', () async {
      final container = ProviderContainer(
        overrides: [
          allTripSummariesProvider.overrideWith(
            (ref) => Stream<List<TripSummary>>.value(
              [_makeTrip(DateTime.now().subtract(const Duration(days: 1)))],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(todaysTripSummariesProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      final result = container.read(todaysTripSummariesProvider);
      expect(result.value, hasLength(0));
    });

    test('excludes trips starting tomorrow', () async {
      final container = ProviderContainer(
        overrides: [
          allTripSummariesProvider.overrideWith(
            (ref) => Stream<List<TripSummary>>.value(
              [_makeTrip(DateTime.now().add(const Duration(days: 1)))],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(todaysTripSummariesProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      final result = container.read(todaysTripSummariesProvider);
      expect(result.value, hasLength(0));
    });

    test('returns empty list when input is empty', () async {
      final container = ProviderContainer(
        overrides: [
          allTripSummariesProvider.overrideWith(
            (ref) => Stream<List<TripSummary>>.value(const <TripSummary>[]),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(todaysTripSummariesProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      final result = container.read(todaysTripSummariesProvider);
      expect(result.value, hasLength(0));
    });
  });
}
