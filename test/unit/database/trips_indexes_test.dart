import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';

void main() {
  group('Trips table indexes (D-03)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('idx_trips_start_time and idx_trips_direction_start exist', () async {
      final rows = await db
          .customSelect(
            'SELECT name FROM sqlite_master '
            "WHERE type = 'index' AND tbl_name = 'trips'",
          )
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();

      expect(
        names,
        containsAll(<String>[
          'idx_trips_start_time',
          'idx_trips_direction_start',
        ]),
      );
    });
  });
}
