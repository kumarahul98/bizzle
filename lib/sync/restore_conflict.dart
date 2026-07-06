import 'package:flutter/foundation.dart';
import 'package:traevy/database/database.dart';

/// Represents a conflict between a local trip and a cloud trip during restore.
@immutable
sealed class RestoreConflict {
  const RestoreConflict();
  TripRow get localTrip;
  TripsCompanion get cloudTrip;
}

class SameUuidConflict extends RestoreConflict {
  const SameUuidConflict({required this.localTrip, required this.cloudTrip});
  
  @override
  final TripRow localTrip;
  
  @override
  final TripsCompanion cloudTrip;
}

class OverlapConflict extends RestoreConflict {
  const OverlapConflict({required this.localTrip, required this.cloudTrip});
  
  @override
  final TripRow localTrip;
  
  @override
  final TripsCompanion cloudTrip;
}
