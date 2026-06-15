import 'package:traevy/sync/restore_controller.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/trip_serializer.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _tripJson(String id) => <String, dynamic>{
  'id': id,
  'startTime': '2026-05-01T08:00:00.000Z',
  'endTime': '2026-05-01T08:30:00.000Z',
  'durationSeconds': 1800,
  'distanceMeters': 12000.0,
  'routePolyline': null,
  'direction': 'to_office',
  'timeMovingSeconds': 1200,
  'timeStuckSeconds': 600,
  'isManualEntry': false,
  'createdAt': '2026-05-01T08:30:00.000Z',
  'updatedAt': '2026-05-01T08:30:00.000Z',
};

void main() {
  test('debug mismatch', () async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  final cloud = TripSerializer.fromJson(_tripJson('t1'));
  
  await db.tripsDao.insertOrIgnoreTrips([cloud]);
  final local = await db.tripsDao.findById('t1');
  
  print('local.startTime: ${local!.startTime} (UTC: ${local.startTime.isUtc})');
  print('cloud.startTime: ${cloud.startTime.value} (UTC: ${cloud.startTime.value.isUtc})');
  print('isAtSameMomentAs: ${local.startTime.isAtSameMomentAs(cloud.startTime.value)}');
  print('local.durationSeconds: ${local.durationSeconds}, cloud: ${cloud.durationSeconds.value}');

  if (cloud.startTime.present && !local.startTime.isAtSameMomentAs(cloud.startTime.value)) print('startTime DIFFERS');
  if (cloud.endTime.present && !local.endTime.isAtSameMomentAs(cloud.endTime.value)) print('endTime DIFFERS');
  if (cloud.durationSeconds.present && local.durationSeconds != cloud.durationSeconds.value) print('durationSeconds DIFFERS');
  if (cloud.totalPausedSeconds.present && local.totalPausedSeconds != cloud.totalPausedSeconds.value) print('totalPausedSeconds DIFFERS');
  if (cloud.distanceMeters.present && local.distanceMeters != cloud.distanceMeters.value) print('distanceMeters DIFFERS');
  if (cloud.direction.present && local.direction != cloud.direction.value) print('direction DIFFERS');
  if (cloud.directionSource.present && local.directionSource != cloud.directionSource.value) print('directionSource DIFFERS');
  if (cloud.timeMovingSeconds.present && local.timeMovingSeconds != cloud.timeMovingSeconds.value) print('timeMovingSeconds DIFFERS');
  if (cloud.timeStuckSeconds.present && local.timeStuckSeconds != cloud.timeStuckSeconds.value) print('timeStuckSeconds DIFFERS');
  if (cloud.isManualEntry.present && local.isManualEntry != cloud.isManualEntry.value) print('isManualEntry DIFFERS');
  if (cloud.isEdited.present && local.isEdited != cloud.isEdited.value) print('isEdited DIFFERS');
  if (cloud.routePolyline.present && local.routePolyline != cloud.routePolyline.value) print('routePolyline DIFFERS');
  
  });
}
