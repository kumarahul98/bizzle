import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';

void main() {
  group('DirectionLabelService', () {
    const labeler = DirectionLabelService();

    test('hour before morning cutoff returns kDirectionToOffice', () {
      expect(
        labeler.label(DateTime(2026, 1, 1, 7), 12, 18),
        kDirectionToOffice,
      );
    });

    test('hour equal to morning cutoff returns kDirectionToHome', () {
      expect(
        labeler.label(DateTime(2026, 1, 1, 12), 12, 18),
        kDirectionToHome,
      );
    });

    test('hour between morning and evening cutoff returns kDirectionToHome',
        () {
      expect(
        labeler.label(DateTime(2026, 1, 1, 15), 12, 18),
        kDirectionToHome,
      );
    });

    test('hour equal to evening cutoff returns kDirectionToHome', () {
      expect(
        labeler.label(DateTime(2026, 1, 1, 18), 12, 18),
        kDirectionToHome,
      );
    });

    test('hour after evening cutoff returns kDirectionToHome', () {
      expect(
        labeler.label(DateTime(2026, 1, 1, 20), 12, 18),
        kDirectionToHome,
      );
    });

    test('midnight (hour 0) with default cutoffs returns kDirectionToOffice',
        () {
      expect(
        labeler.label(DateTime(2026), 12, 18),
        kDirectionToOffice,
      );
    });

    test('UTC-offset pitfall: 5:30 local time labels as kDirectionToOffice',
        () {
      // Represents 00:00 UTC = 05:30 IST — caller passes toLocal() result.
      // The labeler receives the local DateTime and applies the cutoff rule.
      final localMorning = DateTime(2026, 1, 1, 5, 30); // local
      expect(labeler.label(localMorning, 12, 18), kDirectionToOffice);
    });

    test('custom morning cutoff: hour 6, start at 5 → kDirectionToOffice', () {
      expect(
        labeler.label(DateTime(2026, 1, 1, 5), 6, 18),
        kDirectionToOffice,
      );
    });

    test('custom morning cutoff: hour 6, start at 6 → kDirectionToHome', () {
      expect(
        labeler.label(DateTime(2026, 1, 1, 6), 6, 18),
        kDirectionToHome,
      );
    });

    test('same morning and evening cutoff: hour equal returns kDirectionToHome',
        () {
      // When both cutoffs are 12 (the default), hour >= 12 → to_home.
      expect(
        labeler.label(DateTime(2026, 1, 1, 12), 12, 12),
        kDirectionToHome,
      );
    });
  });
}
