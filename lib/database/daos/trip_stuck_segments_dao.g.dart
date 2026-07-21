// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_stuck_segments_dao.dart';

// ignore_for_file: type=lint
mixin _$TripStuckSegmentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $TripStuckSegmentsTable get tripStuckSegments =>
      attachedDatabase.tripStuckSegments;
  TripStuckSegmentsDaoManager get managers => TripStuckSegmentsDaoManager(this);
}

class TripStuckSegmentsDaoManager {
  final _$TripStuckSegmentsDaoMixin _db;
  TripStuckSegmentsDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$TripStuckSegmentsTableTableManager get tripStuckSegments =>
      $$TripStuckSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.tripStuckSegments,
      );
}
