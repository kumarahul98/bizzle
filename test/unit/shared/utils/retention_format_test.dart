import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/shared/utils/retention_format.dart';

void main() {
  group('formatRetentionCountdown (Phase 35, D-05)', () {
    final now = DateTime.utc(2026, 6, 1, 12);

    String at(int daysAgo) => formatRetentionCountdown(
      deletedAtUtc: now.subtract(Duration(days: daysAgo)),
      nowUtc: now,
    );

    test('deleted today shows the full window remaining', () {
      expect(at(0), 'Deleted today · auto-removes in 30 days');
    });

    test('singular day noun on both halves', () {
      expect(at(1), 'Deleted 1 day ago · auto-removes in 29 days');
      expect(at(29), 'Deleted 29 days ago · auto-removes in 1 day');
    });

    test('the canonical example from the plan', () {
      expect(at(3), 'Deleted 3 days ago · auto-removes in 27 days');
    });

    test('at the retention boundary the remaining half reads "soon"', () {
      expect(at(30), 'Deleted 30 days ago · auto-removes soon');
      // Past the window (not yet purged) still clamps to "soon", not negative.
      expect(at(45), 'Deleted 45 days ago · auto-removes soon');
    });

    test(
      'a future-dated tombstone (clock moved backward) clamps the age to zero',
      () {
        final result = formatRetentionCountdown(
          deletedAtUtc: now.add(const Duration(days: 5)),
          nowUtc: now,
        );
        expect(result, 'Deleted today · auto-removes in 30 days');
      },
    );

    test('respects a custom retentionDays', () {
      final result = formatRetentionCountdown(
        deletedAtUtc: now.subtract(const Duration(days: 2)),
        nowUtc: now,
        retentionDays: 7,
      );
      expect(result, 'Deleted 2 days ago · auto-removes in 5 days');
    });

    test('is assembled only from the copy constants', () {
      expect(kTrashRetentionDays, 30);
      expect(kTrashDeletedTodayLabel, 'Deleted today');
      expect(kTrashAutoRemovesSoonLabel, 'auto-removes soon');
    });
  });
}
