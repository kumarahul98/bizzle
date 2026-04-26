// Wave 0 stub tests for trip history date grouping (HIST-01).
//
// These stubs compile and pass immediately (via markTestSkipped) so the test
// runner stays green before the production code exists. Wave 1 implements
// `groupTripsByDate` in lib/features/trips/providers/history_providers.dart
// and `formatDateHeader` in lib/shared/utils/formatters.dart, then Wave 2
// fills these stubs in with real assertions and uncommented imports.
//
// Do NOT import the production modules from this stub — they do not exist
// yet and importing them would fail compilation. The imports are added in
// Wave 1/Wave 2 alongside the real assertions.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupTripsByDate', () {
    test('returns empty map for empty input', () {
      markTestSkipped('Wave 1: implement groupTripsByDate first');
    });

    test('groups trips by local date (same UTC day, same local date)', () {
      markTestSkipped('Wave 1: implement groupTripsByDate first');
    });

    test('strips time from key (keys are date-only DateTime objects)', () {
      markTestSkipped('Wave 1: implement groupTripsByDate first');
    });

    test('preserves newest-first order within each group', () {
      markTestSkipped('Wave 1: implement groupTripsByDate first');
    });
  });

  group('formatDateHeader', () {
    test('returns kHistoryDateToday for today', () {
      markTestSkipped('Wave 1: implement formatDateHeader first');
    });

    test('returns kHistoryDateYesterday for yesterday', () {
      markTestSkipped('Wave 1: implement formatDateHeader first');
    });

    test("returns 'Mon 21 Apr' format for older dates", () {
      markTestSkipped('Wave 1: implement formatDateHeader first');
    });
  });
}
