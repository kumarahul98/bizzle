import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/saved_locations.dart';

/// Wire-contract tests for the Phase 29 preference endpoints (LOC-03).
///
/// These pin the two things a server change could silently break: the exact
/// request shape we emit, and the exact envelope depth we expect back.
void main() {
  const testBaseUrl = 'https://test.example/api';

  Future<String?> Function({bool forceRefresh}) fixedToken(String token) =>
      ({forceRefresh = false}) async => token;

  ApiClient build(MockClient client) => ApiClient(
    client: client,
    baseUrl: testBaseUrl,
    getToken: fixedToken('tok1'),
  );

  const full = SavedLocations(
    homeLat: 12.9716,
    homeLng: 77.5946,
    officeLat: 12.9352,
    officeLng: 77.6245,
  );

  String envelope(Map<String, Object?> savedLocations) => jsonEncode({
    'statusCode': 200,
    'body': {
      'data': {'savedLocations': savedLocations},
    },
  });

  group('ApiClient.syncPreferences', () {
    test('POSTs to /preferences/sync with Bearer header and wrapped body', () {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"statusCode":200,"body":{"data":{}}}', 200);
      });

      return build(client).syncPreferences(full).then((_) {
        expect(captured.method, 'POST');
        expect(captured.url.toString(), '$testBaseUrl$kSyncPreferencesPath');
        expect(captured.headers['Authorization'], 'Bearer tok1');

        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        final saved = body['savedLocations'] as Map<String, dynamic>;
        expect(saved['homeLat'], 12.9716);
        expect(saved['homeLng'], 77.5946);
        expect(saved['officeLat'], 12.9352);
        expect(saved['officeLng'], 77.6245);
      });
    });

    test('emits all four keys including nulls, not a sparse object', () {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"statusCode":200,"body":{"data":{}}}', 200);
      });

      // The payload is a complete statement of current truth — that is what
      // makes the queue-free re-send in D-02 safe.
      return build(client).syncPreferences(const SavedLocations.empty()).then((
        _,
      ) {
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        final saved = body['savedLocations'] as Map<String, dynamic>;
        expect(
          saved.keys,
          containsAll(<String>[
            'homeLat',
            'homeLng',
            'officeLat',
            'officeLng',
          ]),
        );
        expect(saved['homeLat'], isNull);
      });
    });

    test('throws non-retryable SyncException on 400', () async {
      final client = MockClient(
        (_) async => http.Response('{"statusCode":400}', 400),
      );

      await expectLater(
        build(client).syncPreferences(full),
        throwsA(
          isA<SyncException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.retryable, 'retryable', false),
        ),
      );
    });

    test('throws retryable SyncException on 500', () async {
      final client = MockClient((_) async => http.Response('boom', 500));

      await expectLater(
        build(client).syncPreferences(full),
        throwsA(
          isA<SyncException>().having((e) => e.retryable, 'retryable', true),
        ),
      );
    });
  });

  group('ApiClient.restorePreferences', () {
    test('GETs /preferences/restore and unwraps the double envelope', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          envelope({
            'homeLat': 12.9716,
            'homeLng': 77.5946,
            'officeLat': 12.9352,
            'officeLng': 77.6245,
          }),
          200,
        );
      });

      final result = await build(client).restorePreferences();

      expect(captured.method, 'GET');
      expect(captured.url.toString(), '$testBaseUrl$kRestorePreferencesPath');
      expect(result, full);
    });

    test(
      'parses an all-null response as empty (never-synced user, SC#5)',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            envelope({
              'homeLat': null,
              'homeLng': null,
              'officeLat': null,
              'officeLng': null,
            }),
            200,
          ),
        );

        final result = await build(client).restorePreferences();
        expect(result.isEmpty, isTrue);
      },
    );

    test('parses a partially-set response (Home only)', () async {
      final client = MockClient(
        (_) async => http.Response(
          envelope({
            'homeLat': 12.9716,
            'homeLng': 77.5946,
            'officeLat': null,
            'officeLng': null,
          }),
          200,
        ),
      );

      final result = await build(client).restorePreferences();
      expect(result.homeLat, 12.9716);
      expect(result.officeLat, isNull);
      expect(result.isEmpty, isFalse);
    });

    test('accepts integer-encoded coordinates from JSON', () async {
      // jsonDecode yields int for a whole number, so `as double` would throw.
      final client = MockClient(
        (_) async => http.Response(
          envelope({
            'homeLat': 12,
            'homeLng': 77,
            'officeLat': null,
            'officeLng': null,
          }),
          200,
        ),
      );

      final result = await build(client).restorePreferences();
      expect(result.homeLat, 12.0);
      expect(result.homeLng, 77.0);
    });

    test(
      'throws transport on a malformed envelope, never returns empty',
      () async {
        // "No locations" and "the response was garbage" must not look the same:
        // the first is a normal state, the second should be retried.
        final client = MockClient(
          (_) async =>
              http.Response('{"statusCode":200,"body":{"data":{}}}', 200),
        );

        await expectLater(
          build(client).restorePreferences(),
          throwsA(
            isA<SyncException>().having((e) => e.retryable, 'retryable', true),
          ),
        );
      },
    );

    test('throws transport on a truncated body', () async {
      final client = MockClient((_) async => http.Response('{"body":', 200));

      await expectLater(
        build(client).restorePreferences(),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('SavedLocations', () {
    test(
      'fromJson maps a non-finite value to null rather than propagating it',
      () {
        // A NaN reaching the geofence resolver would not throw — it would
        // silently mislabel the direction of every future trip.
        final parsed = SavedLocations.fromJson(const {
          'homeLat': double.nan,
          'homeLng': double.infinity,
          'officeLat': 12.9352,
          'officeLng': 77.6245,
        });
        expect(parsed.homeLat, isNull);
        expect(parsed.homeLng, isNull);
        expect(parsed.officeLat, 12.9352);
      },
    );

    test('fromJson maps a non-numeric value to null', () {
      final parsed = SavedLocations.fromJson(const {
        'homeLat': 'not-a-number',
        'homeLng': null,
        'officeLat': null,
        'officeLng': null,
      });
      expect(parsed.homeLat, isNull);
    });

    test('0,0 is a set location, not absent', () {
      const nullIsland = SavedLocations(
        homeLat: 0,
        homeLng: 0,
        officeLat: null,
        officeLng: null,
      );
      expect(nullIsland.isEmpty, isFalse);
    });

    test('value equality holds for identical coordinates', () {
      expect(
        const SavedLocations(
          homeLat: 1,
          homeLng: 2,
          officeLat: 3,
          officeLng: 4,
        ),
        const SavedLocations(
          homeLat: 1,
          homeLng: 2,
          officeLat: 3,
          officeLng: 4,
        ),
      );
    });
  });
}
