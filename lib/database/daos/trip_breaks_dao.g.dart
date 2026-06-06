// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_breaks_dao.dart';

// ignore_for_file: type=lint
mixin _$TripBreaksDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $TripBreaksTable get tripBreaks => attachedDatabase.tripBreaks;
  TripBreaksDaoManager get managers => TripBreaksDaoManager(this);
}

class TripBreaksDaoManager {
  final _$TripBreaksDaoMixin _db;
  TripBreaksDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$TripBreaksTableTableManager get tripBreaks =>
      $$TripBreaksTableTableManager(_db.attachedDatabase, _db.tripBreaks);
}
