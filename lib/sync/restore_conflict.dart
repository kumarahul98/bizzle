import 'package:flutter/foundation.dart';
import 'package:traevy/database/database.dart';

/// Represents a conflict between a local trip and a cloud trip during restore.
///
/// Phase 26 (Plan 05): both variants also carry the two sides' break
/// segments — [cloudBreaks] (parsed wire companions, fresh UUIDs) and
/// [localBreaks] (existing `trip_breaks` rows) — so Plan 06's merge sheet
/// and breaks-differ indicator never need a second DB read. Both default to
/// `const []` so pre-Phase-26 construction sites compile unchanged.
///
/// The two stuck-segment lists ride along for the same reason: resolving a
/// conflict rewrites the trip's `routePolyline`, and a stuck segment's point
/// indices are only meaningful against the polyline they were computed from,
/// so the resolver needs both sides in hand to decide which segments remain
/// index-coherent.
@immutable
sealed class RestoreConflict {
  const RestoreConflict();
  TripRow get localTrip;
  TripsCompanion get cloudTrip;

  /// The cloud copy's break segments as parsed insert companions
  /// (`TripSerializer.fromJson` output — fresh UUIDs, tripId already set).
  List<TripBreaksCompanion> get cloudBreaks;

  /// The local trip's existing `trip_breaks` rows, `startTime` ascending.
  List<TripBreakRow> get localBreaks;

  /// The cloud copy's stuck segments as parsed insert companions.
  List<TripStuckSegmentsCompanion> get cloudStuckSegments;

  /// The local trip's existing `trip_stuck_segments` rows,
  /// `startPointIndex` ascending.
  List<TripStuckSegmentRow> get localStuckSegments;
}

class SameUuidConflict extends RestoreConflict {
  const SameUuidConflict({
    required this.localTrip,
    required this.cloudTrip,
    this.cloudBreaks = const [],
    this.localBreaks = const [],
    this.cloudStuckSegments = const [],
    this.localStuckSegments = const [],
  });

  @override
  final TripRow localTrip;

  @override
  final TripsCompanion cloudTrip;

  @override
  final List<TripBreaksCompanion> cloudBreaks;

  @override
  final List<TripBreakRow> localBreaks;

  @override
  final List<TripStuckSegmentsCompanion> cloudStuckSegments;

  @override
  final List<TripStuckSegmentRow> localStuckSegments;
}

class OverlapConflict extends RestoreConflict {
  const OverlapConflict({
    required this.localTrip,
    required this.cloudTrip,
    this.cloudBreaks = const [],
    this.localBreaks = const [],
    this.cloudStuckSegments = const [],
    this.localStuckSegments = const [],
  });

  @override
  final TripRow localTrip;

  @override
  final TripsCompanion cloudTrip;

  @override
  final List<TripBreaksCompanion> cloudBreaks;

  @override
  final List<TripBreakRow> localBreaks;

  @override
  final List<TripStuckSegmentsCompanion> cloudStuckSegments;

  @override
  final List<TripStuckSegmentRow> localStuckSegments;
}
