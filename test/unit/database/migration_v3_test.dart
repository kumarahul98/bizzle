import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v2.dart' as v2;

/// Proves the Phase 18 v2 → v3 migration is additive-only and preserves
/// every existing trip row (T-18-01, D-03/D-04/D-10).
void main() {
  group('Drift v2 → v3 migration (Phase 18, D-04)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v2 schema opens cleanly at version 2', () async {
      final connection = await verifier.startAt(2);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      // Trivial sanity query — proves the v2 connection is live.
      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'v2 → v3 migration applies and preserves existing trip rows',
      () async {
        // 1. Open the database at the v2 schema and insert a trip row plus a
        //    user_preferences row through the generated v2 schema classes
        //    (no break columns exist yet at v2).
        final schema = await verifier.schemaAt(2);
        final oldDb = v2.DatabaseAtV2(schema.newConnection());

        const tripId = 'trip-v2-survivor';
        final start = DateTime.utc(2026, 1, 1, 8);
        final end = DateTime.utc(2026, 1, 1, 9);

        await oldDb
            .into(oldDb.trips)
            .insert(
              RawValuesInsertable<dynamic>({
                'id': const Variable<String>(tripId),
                'start_time': Variable<DateTime>(start),
                'end_time': Variable<DateTime>(end),
                'duration_seconds': const Variable<int>(3600),
                'distance_meters': const Variable<double>(12345.6),
                'direction': const Variable<String>('to_office'),
                'time_moving_seconds': const Variable<int>(3000),
                'time_stuck_seconds': const Variable<int>(600),
              }),
            );
        await oldDb
            .into(oldDb.userPreferences)
            .insert(
              const RawValuesInsertable<dynamic>({'id': Variable<int>(1)}),
            );
        await oldDb.close();

        // 2. Run the real migration up to the current terminal version (v8)
        //    and validate the resulting schema against the generated v8
        //    snapshot. A real v2 install upgrades straight through v3..v8,
        //    so this exercises the full stepwise chain (D-04). The v3
        //    columns added by Phase 18 (total_paused_seconds,
        //    auto_pause_enabled) are asserted below to prove the v2 → v3 step
        //    still preserves data. Migrating to the terminal version is also
        //    required so the real DAO's getOrDefault() can read every column
        //    (has_seen_onboarding was added at v5; the Phase 21 coords +
        //    direction_source at v6; the Phase 26 backfill_marker_version at
        //    v7; the Phase 27 seen_tours at v8).
        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 8);

        // 3a. The previously-inserted trip still exists after migration.
        final tripRow = await migratedDb.tripsDao.findById(tripId);
        expect(tripRow, isNotNull, reason: 'existing trip must survive v3');
        expect(tripRow!.id, tripId);
        expect(tripRow.durationSeconds, 3600);

        // 3b. The new total_paused_seconds column defaults to 0 for the
        //     pre-existing row (D-02/D-03 — active duration == wall-clock).
        expect(tripRow.totalPausedSeconds, 0);

        // 3c. At v3 the pre-existing user_preferences row got
        //     auto_pause_enabled = false (D-10 — opt-in default, which held
        //     at v3). But this install upgrades all the way to the current
        //     terminal version, and the Phase 27 v7 → v8 migration
        //     explicitly backfills EVERY existing row's auto_pause_enabled
        //     to true (UX-08 supersedes D-10) — so by the time the DAO
        //     reads it here, it is true, not false. This assertion is
        //     scoped to what the FULL migration chain guarantees for this
        //     row today, not to the v3 step in isolation.
        final prefs = await migratedDb.userPreferencesDao.getOrDefault();
        expect(prefs.autoPauseEnabled, isTrue);
      },
    );
  });
}
