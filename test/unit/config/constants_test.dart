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
}
