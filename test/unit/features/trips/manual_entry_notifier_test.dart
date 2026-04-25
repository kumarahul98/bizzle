// Wave 0 stub — tests will be unskipped in Plan 03-03.
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';

void main() {
  group('parseHhMm', () {
    test('0:00 returns zero duration', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03 (parseHhMm in manual_entry_sheet.dart)');

    test('23:59 returns max valid duration', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');

    test('24:00 returns null (out of range)', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');

    test('empty string returns null', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');

    test('no colon returns null', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');

    test('non-numeric returns null', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');
  });

  group('ManualEntryNotifier.insertManualTrip', () {
    test('saved trip has isManualEntry=true and distanceMeters=0.0', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');

    test('startTime is UTC midnight of chosen local date (Pitfall 6)', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');
  });
}
