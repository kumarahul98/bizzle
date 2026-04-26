// Wave 0 stub tests for HistoryScreen (HIST-01, HIST-02).
//
// These stubs compile and pass immediately (via markTestSkipped) so the test
// runner stays green before HistoryScreen exists. Wave 2 implements the
// screen in lib/features/trips/screens/history_screen.dart and uncomments
// the import below, then fills these stubs in with real assertions.
//
// Do NOT import HistoryScreen — it does not exist yet and importing it
// would fail compilation. The setUp/tearDown DB scaffold matches
// edit_trip_sheet_test.dart so Wave 2 can drop assertions in directly.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('HistoryScreen', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() async => db.close());

    // Helper kept for Wave 2 use; stubs do not yet invoke it.
    // ignore: unused_element
    TripSummary makeSummary({String direction = kDirectionToOffice}) {
      final start = DateTime.utc(2026, 1, 1, 8);
      final end = DateTime.utc(2026, 1, 1, 9);
      return TripSummary(
        id: const Uuid().v4(),
        startTime: start,
        endTime: end,
        durationSeconds: 3600,
        distanceMeters: 0,
        direction: direction,
        timeMovingSeconds: 0,
        timeStuckSeconds: 0,
        isManualEntry: false,
      );
    }

    testWidgets('renders trip cards grouped under date headers', (
      tester,
    ) async {
      markTestSkipped('Wave 2: implement HistoryScreen first');
    });

    testWidgets('shows empty state when no trips', (tester) async {
      markTestSkipped('Wave 2: implement HistoryScreen first');
    });

    testWidgets('calendar view shows event marker on days with trips', (
      tester,
    ) async {
      markTestSkipped('Wave 3: implement calendar mode first');
    });

    testWidgets('tapping a calendar date filters the sub-list', (tester) async {
      markTestSkipped('Wave 3: implement calendar filter first');
    });

    testWidgets('tapping a trip card navigates to detail screen', (
      tester,
    ) async {
      markTestSkipped('Wave 2: implement HistoryScreen navigation first');
    });
  });
}
