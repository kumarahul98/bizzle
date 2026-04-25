// Wave 0 stub — tests will be unskipped in Plan 03-03.
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';

void main() {
  group('DirectionBackfillProvider', () {
    test('updates kDirectionUnknown trips with labeled direction', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');

    test('leaves already-labeled trips unchanged', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');

    test('enqueues kSyncActionUpdate for each backfilled trip', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');

    test('no-op when no kDirectionUnknown trips exist', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-03');
  });
}
