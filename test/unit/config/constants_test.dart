import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';

void main() {
  group('Phase 1 constants', () {
    test('kStuckSpeedThresholdKmh is 10 (double)', () {
      expect(kStuckSpeedThresholdKmh, 10);
      expect(kStuckSpeedThresholdKmh, isA<double>());
    });

    test('kDefaultDirectionCutoffHour is 12 (int)', () {
      expect(kDefaultDirectionCutoffHour, 12);
      expect(kDefaultDirectionCutoffHour, isA<int>());
    });

    test("kDefaultUserId is 'local_user'", () {
      expect(kDefaultUserId, 'local_user');
    });

    test("kDatabaseName is 'traevy'", () {
      expect(kDatabaseName, 'traevy');
    });

    test('kSyncQueueMaxRetries is 3', () {
      expect(kSyncQueueMaxRetries, 3);
    });

    test('direction constants are lowercase literals', () {
      expect(kDirectionToOffice, 'to_office');
      expect(kDirectionToHome, 'to_home');
    });

    test('sync action constants are lowercase literals', () {
      expect(kSyncActionCreate, 'create');
      expect(kSyncActionUpdate, 'update');
      expect(kSyncActionDelete, 'delete');
    });

    test('sync status constants are lowercase literals', () {
      expect(kSyncStatusPending, 'pending');
      expect(kSyncStatusSynced, 'synced');
      expect(kSyncStatusFailed, 'failed');
    });
  });

  group('delete-trip dialog copy describes the SOFT delete it performs', () {
    // Per-trip delete moves the trip to Trash — the row survives with a
    // `deleted_at` stamp and is restorable. The copy said "permanently
    // removed", which described the wrong operation and contradicted both the
    // published privacy policy and CLAUDE.md's deletion model.
    const body =
        '$kTripDeleteDialogBodyPrefix'
        '$kTrashRetentionDays'
        '$kTripDeleteDialogBodySuffix';

    test('does not claim the trip is permanently removed', () {
      expect(body.toLowerCase(), isNot(contains('permanent')));
      expect(body.toLowerCase(), isNot(contains('cannot be recovered')));
    });

    test('names the Trash destination and says it is restorable', () {
      expect(body, contains(kTrashScreenTitle));
      expect(body.toLowerCase(), contains('restore'));
    });

    test('states the retention window from kTrashRetentionDays', () {
      expect(body, contains('$kTrashRetentionDays days'));
    });

    test('stays distinct from the permanent-delete copy', () {
      expect(body, isNot(kTrashPermanentDeleteDialogBody));
      // The Trash action's own copy must still be the blunt one.
      expect(
        kTrashPermanentDeleteDialogBody.toLowerCase(),
        contains('cannot be recovered'),
      );
    });
  });
}
