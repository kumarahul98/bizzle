import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';

/// Reactive break segments for one trip (Phase 31, D-07).
///
/// Backed by `TripBreaksDao.watch`, which already existed and — until this
/// phase — was called from nowhere. The trip timeline reads real breaks from
/// here instead of inventing a marker.
final tripBreaksProvider = StreamProvider.family<List<TripBreakRow>, String>(
  (ref, tripId) => ref.watch(tripBreaksDaoProvider).watch(tripId),
  name: 'tripBreaksProvider',
);

/// Reactive stuck segments for one trip (Phase 31, D-02).
///
/// Emits an empty list for a manual entry, a restored trip, and every trip
/// recorded before Phase 31 — those render exactly as they did before, with
/// one plain polyline and no stuck rows (D-06).
final tripStuckSegmentsProvider =
    StreamProvider.family<List<TripStuckSegmentRow>, String>(
      (ref, tripId) => ref.watch(tripStuckSegmentsDaoProvider).watch(tripId),
      name: 'tripStuckSegmentsProvider',
    );
