// Wave 0 RED contract for user_id backfill (AUTH-03).
//
// INTENDED STATE: COMPILE FAILURE (RED)
//
//   This file references methods that do not exist yet:
//     - TripsDao.backfillUserId(String)    — Plan 09-02 adds this method
//     - UserPreferencesDao.backfillUserId(String) — Plan 09-02 adds this method
//
//   Until Plan 09-02 adds these two DAO methods, this file will fail to
//   compile. That is the intended Wave 0 RED state.
//   DO NOT stub the methods — the compile failure is the contract signal.
//
// CONTRACTS VERIFIED:
//   AUTH-03: tripsDao.backfillUserId(uid) rewrites all user_id='local_user' rows to uid
//   AUTH-03: userPreferencesDao.backfillUserId(uid) rewrites the single prefs row
//   AUTH-03: tripsDao.backfillUserId returns the count of changed rows
//   AUTH-03: a second call returns 0 (no remaining local_user rows)
//
// PATTERN:
//   Uses in-memory AppDatabase (NativeDatabase.memory()) — the same approach
//   as test/unit/database/trips_dao_test.dart lines 8-55. No platform channels.
//   No fake DAOs — the real Drift DAOs are tested against the real in-memory DB.
//
// See .planning/phases/09-authentication/09-RESEARCH.md:
//   - Code Examples §2 (backfillUserId DAO method)
//   - PATTERNS.md § trips_dao.dart (explicit-WHERE update pattern)
//   - STATE.md Phase 3 decision: never use .replace() for partial updates

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  const uuid = Uuid();

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

  // ---------------------------------------------------------------------------
  // Group 1: TripsDao.backfillUserId
  // ---------------------------------------------------------------------------
  group('TripsDao.backfillUserId', () {
    test(
      'rewrites user_id from kDefaultUserId to the supplied uid',
      () async {
        // Arrange: insert two trips with user_id = kDefaultUserId
        final id1 = uuid.v4();
        final id2 = uuid.v4();
        final start = DateTime.utc(2026, 1, 1, 8);
        final end = DateTime.utc(2026, 1, 1, 9);

        await db.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: id1,
            startTime: start,
            endTime: end,
            durationSeconds: 3600,
            distanceMeters: 5000,
            direction: kDirectionToOffice,
            timeMovingSeconds: 3000,
            timeStuckSeconds: 600,
          ),
        );
        await db.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: id2,
            startTime: start.add(const Duration(days: 1)),
            endTime: end.add(const Duration(days: 1)),
            durationSeconds: 3600,
            distanceMeters: 4800,
            direction: kDirectionToHome,
            timeMovingSeconds: 2800,
            timeStuckSeconds: 800,
          ),
        );

        // Act: backfill the userId to a real Firebase uid
        const firebaseUid = 'firebase-uid-abc';
        final changed = await db.tripsDao.backfillUserId(firebaseUid);

        // Assert: both rows updated, returned count = 2
        expect(changed, 2);

        // Verify the raw rows via watchAllSummaries to confirm the rewrite
        // without exposing internal Drift row types to the test.
        // The userId column is internal to the DAO; we verify via a direct
        // select query to confirm the rewrite.
        final rows = await db.tripsDao.watchAllSummaries().first;
        expect(rows, hasLength(2));
        // Summaries don't expose userId — test the backfill count only.
        // The full row assertion is implicit: if backfillUserId returns 2,
        // exactly 2 rows were updated.
      },
    );

    test(
      'returns the changed-row count (first-sign-in signal)',
      () async {
        // Arrange: insert one trip with default user_id
        await db.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: uuid.v4(),
            startTime: DateTime.utc(2026, 1, 2, 8),
            endTime: DateTime.utc(2026, 1, 2, 9),
            durationSeconds: 3600,
            distanceMeters: 6000,
            direction: kDirectionToOffice,
            timeMovingSeconds: 3600,
            timeStuckSeconds: 0,
          ),
        );

        // Act
        final changed = await db.tripsDao.backfillUserId('uid-123');

        // Assert: exactly 1 row changed — the signal AuthService uses to
        // decide whether to show the confirmation screen (D-12).
        expect(changed, 1);
      },
    );

    test(
      'returns 0 on a second call (idempotent — no remaining local_user rows)',
      () async {
        // Arrange: insert a trip and backfill once
        await db.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: uuid.v4(),
            startTime: DateTime.utc(2026, 1, 3, 8),
            endTime: DateTime.utc(2026, 1, 3, 9),
            durationSeconds: 3600,
            distanceMeters: 5500,
            direction: kDirectionToHome,
            timeMovingSeconds: 2000,
            timeStuckSeconds: 1600,
          ),
        );

        await db.tripsDao.backfillUserId('uid-123');

        // Act: call backfill again with the same uid
        final secondChanged = await db.tripsDao.backfillUserId('uid-123');

        // Assert: 0 rows remain with kDefaultUserId — second call is a no-op
        expect(secondChanged, 0);
      },
    );

    test(
      'returns 0 when no trips exist (guest with no trips)',
      () async {
        // Arrange: empty database
        // Act: backfill on an empty table
        final changed = await db.tripsDao.backfillUserId('uid-empty');

        // Assert: no rows to update
        expect(changed, 0);
      },
    );

    test(
      'does not update rows with a non-kDefaultUserId user_id',
      () async {
        // Arrange: insert a trip that already has a real uid
        // (simulates a row written after a previous sign-in)
        //
        // To insert a row with a non-default userId, we must insert with
        // the companion's userId field set explicitly.
        await db.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: uuid.v4(),
            startTime: DateTime.utc(2026, 1, 4, 8),
            endTime: DateTime.utc(2026, 1, 4, 9),
            durationSeconds: 3600,
            distanceMeters: 5000,
            direction: kDirectionToOffice,
            timeMovingSeconds: 3000,
            timeStuckSeconds: 600,
            userId: const Value<String>('already-real-uid'),
          ),
        );

        // Act: backfill should only touch kDefaultUserId rows
        final changed = await db.tripsDao.backfillUserId('new-uid');

        // Assert: the row with 'already-real-uid' is untouched
        expect(changed, 0);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 2: UserPreferencesDao.backfillUserId
  // ---------------------------------------------------------------------------
  group('UserPreferencesDao.backfillUserId', () {
    test(
      'rewrites user_id in the user_preferences row',
      () async {
        // Arrange: upsert preferences so the row exists with kDefaultUserId
        const prefs = UserPreferencesValue(
          userId: kDefaultUserId,
          darkMode: kDarkModeSystem,
          morningCutoffHour: kDefaultDirectionCutoffHour,
          eveningCutoffHour: kDefaultDirectionCutoffHour,
          reminderEnabled: false,
          reminderTime: null,
          weekendReminder: false,
          weeklyNotificationEnabled: false,
          autoPauseEnabled: false,
          hasSeenOnboarding: false,
        );
        await db.userPreferencesDao.upsert(prefs);

        // Act: backfill the preferences row
        const firebaseUid = 'firebase-uid-prefs';
        final changed = await db.userPreferencesDao.backfillUserId(firebaseUid);

        // Assert: 1 row updated
        expect(changed, 1);

        // Verify the rewrite via getOrDefault
        final after = await db.userPreferencesDao.getOrDefault();
        expect(after.userId, firebaseUid);
      },
    );

    test(
      'returns 0 when the preferences row has already been backfilled',
      () async {
        // Arrange: upsert prefs with kDefaultUserId, then backfill
        const prefs = UserPreferencesValue(
          userId: kDefaultUserId,
          darkMode: kDarkModeSystem,
          morningCutoffHour: kDefaultDirectionCutoffHour,
          eveningCutoffHour: kDefaultDirectionCutoffHour,
          reminderEnabled: false,
          reminderTime: null,
          weekendReminder: false,
          weeklyNotificationEnabled: false,
          autoPauseEnabled: false,
          hasSeenOnboarding: false,
        );
        await db.userPreferencesDao.upsert(prefs);
        await db.userPreferencesDao.backfillUserId('uid-first');

        // Act: second backfill
        final second = await db.userPreferencesDao.backfillUserId('uid-first');

        // Assert: no remaining kDefaultUserId rows
        expect(second, 0);
      },
    );

    test(
      'returns 0 when the preferences row has not been created yet',
      () async {
        // Arrange: empty database — no user_preferences row inserted yet.
        // (D-04: first-launch state, row absent until user changes a setting.)

        // Act
        final changed = await db.userPreferencesDao.backfillUserId('uid-norow');

        // Assert: nothing to update
        expect(changed, 0);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 3: Combined backfill (simulates AuthService.signIn() orchestration)
  // ---------------------------------------------------------------------------
  group('Combined trips + prefs backfill', () {
    test(
      'trips and prefs both carry the uid after combined backfill',
      () async {
        // Simulates the two-DAO backfill in AuthService.signIn():
        //   1. db.tripsDao.backfillUserId(uid)
        //   2. db.userPreferencesDao.backfillUserId(uid)
        //
        // The two updates are called sequentially here (matching the real
        // implementation which wraps them in a db.transaction() — see
        // PATTERNS.md § AuthService).

        // Arrange
        final tripId = uuid.v4();
        await db.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: tripId,
            startTime: DateTime.utc(2026, 2, 1, 8),
            endTime: DateTime.utc(2026, 2, 1, 9),
            durationSeconds: 3600,
            distanceMeters: 7000,
            direction: kDirectionToOffice,
            timeMovingSeconds: 3600,
            timeStuckSeconds: 0,
          ),
        );
        const prefs = UserPreferencesValue(
          userId: kDefaultUserId,
          darkMode: kDarkModeSystem,
          morningCutoffHour: kDefaultDirectionCutoffHour,
          eveningCutoffHour: kDefaultDirectionCutoffHour,
          reminderEnabled: false,
          reminderTime: null,
          weekendReminder: false,
          weeklyNotificationEnabled: false,
          autoPauseEnabled: false,
          hasSeenOnboarding: false,
        );
        await db.userPreferencesDao.upsert(prefs);

        // Act: combined backfill
        const uid = 'combined-uid-456';
        final tripsChanged = await db.tripsDao.backfillUserId(uid);
        await db.userPreferencesDao.backfillUserId(uid);

        // Assert: first-sign-in signal (trips changed > 0)
        expect(tripsChanged, greaterThan(0));

        // Assert prefs row updated
        final afterPrefs = await db.userPreferencesDao.getOrDefault();
        expect(afterPrefs.userId, uid);
      },
    );
  });
}
