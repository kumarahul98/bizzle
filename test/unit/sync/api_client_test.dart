import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/trip_serializer.dart';

void main() {
  const testBaseUrl = 'https://test.example/api';

  TripRow sampleTrip() => TripRow(
        id: '11111111-1111-4111-8111-111111111111',
        userId: kDefaultUserId,
        startTime: DateTime.utc(2026, 5, 31, 8, 30),
        endTime: DateTime.utc(2026, 5, 31, 9),
        durationSeconds: 1800,
        distanceMeters: 12500.5,
        routePolyline: 'abc_polyline',
        direction: kDirectionToOffice,
        timeMovingSeconds: 1500,
        timeStuckSeconds: 300,
        isManualEntry: false,
        createdAt: DateTime.utc(2026, 5, 31, 9, 0, 1),
        updatedAt: DateTime.utc(2026, 5, 31, 9, 0, 2),
      );

  // A token-getter that always returns the same token.
  Future<String?> Function({bool forceRefresh}) fixedToken(String token) =>
      ({forceRefresh = false}) async => token;

  ApiClient build(
    MockClient client, {
    Future<String?> Function({bool forceRefresh})? getToken,
  }) =>
      ApiClient(
        client: client,
        baseUrl: testBaseUrl,
        getToken: getToken ?? fixedToken('tok1'),
      );

  group('ApiClient.syncTrips', () {
    test('POSTs to /trips/sync with Bearer header and {trips:[...]} body', () {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"statusCode":200,"body":{"data":{}}}', 200);
      });

      return build(client).syncTrips([sampleTrip()]).then((_) {
        expect(captured.method, 'POST');
        expect(captured.url.toString(), '$testBaseUrl$kSyncTripsPath');
        expect(captured.headers['Authorization'], 'Bearer tok1');
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['trips'], isA<List<dynamic>>());
        final first = (body['trips'] as List).first as Map<String, dynamic>;
        expect(first['id'], sampleTrip().id);
        expect(first.containsKey('userId'), isFalse);
      });
    });

    test('401 then 200 refreshes token and retries exactly once', () async {
      var calls = 0;
      final tokens = <String>[];
      final client = MockClient((req) async {
        calls++;
        tokens.add(req.headers['Authorization']!);
        return http.Response('{}', calls == 1 ? 401 : 200);
      });
      var refreshed = false;
      Future<String?> getToken({bool forceRefresh = false}) async {
        if (forceRefresh) refreshed = true;
        return forceRefresh ? 'tok2' : 'tok1';
      }

      await build(client, getToken: getToken).syncTrips([sampleTrip()]);

      expect(calls, 2);
      expect(refreshed, isTrue);
      expect(tokens, ['Bearer tok1', 'Bearer tok2']);
    });

    test('persistent 401 throws SyncException(statusCode:401, retryable:true)',
        () async {
      final client = MockClient((req) async => http.Response('{}', 401));

      expect(
        () => build(client).syncTrips([sampleTrip()]),
        throwsA(
          isA<SyncException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.retryable, 'retryable', true),
        ),
      );
    });

    test('503 throws SyncException(statusCode:503, retryable:true)', () {
      final client = MockClient((req) async => http.Response('{}', 503));

      expect(
        () => build(client).syncTrips([sampleTrip()]),
        throwsA(
          isA<SyncException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.retryable, 'retryable', true),
        ),
      );
    });

    test('400 throws SyncException(statusCode:400, retryable:false)', () {
      final client = MockClient((req) async => http.Response('{}', 400));

      expect(
        () => build(client).syncTrips([sampleTrip()]),
        throwsA(
          isA<SyncException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.retryable, 'retryable', false),
        ),
      );
    });

    test('socket/timeout error throws SyncException(null, retryable:true)', () {
      final client = MockClient((req) async {
        throw http.ClientException('connection reset');
      });

      expect(
        () => build(client).syncTrips([sampleTrip()]),
        throwsA(
          isA<SyncException>()
              .having((e) => e.statusCode, 'statusCode', isNull)
              .having((e) => e.retryable, 'retryable', true),
        ),
      );
    });

    test('a refresh-getter that throws surfaces as retryable SyncException',
        () async {
      final client = MockClient((req) async => http.Response('{}', 401));
      Future<String?> getToken({bool forceRefresh = false}) async {
        if (forceRefresh) throw http.ClientException('refresh failed');
        return 'tok1';
      }

      await expectLater(
        () => build(client, getToken: getToken).syncTrips([sampleTrip()]),
        throwsA(
          isA<SyncException>()
              .having((e) => e.retryable, 'retryable', true)
              .having((e) => e.notSignedIn, 'notSignedIn', false),
        ),
      );
    });

    test('not signed in throws notSignedIn and makes no request', () async {
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      });
      Future<String?> nullToken({bool forceRefresh = false}) async => null;

      await expectLater(
        () => build(client, getToken: nullToken).syncTrips([sampleTrip()]),
        throwsA(
          isA<SyncException>()
              .having((e) => e.notSignedIn, 'notSignedIn', true)
              .having((e) => e.retryable, 'retryable', false),
        ),
      );
      expect(called, isFalse);
    });

    test('SyncException.toString never leaks the bearer token', () {
      const ex = SyncException.http(500);
      expect(ex.toString().contains('Bearer'), isFalse);
      expect(ex.toString().contains('tok1'), isFalse);
    });
  });

  group('ApiClient.deleteTrip', () {
    test('DELETEs /trips/{id} with Bearer; 200 ok', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      });

      await build(client).deleteTrip('trip-9');

      expect(captured.method, 'DELETE');
      expect(
        captured.url.toString(),
        '$testBaseUrl${kDeleteTripPathPrefix}trip-9',
      );
      expect(captured.headers['Authorization'], 'Bearer tok1');
    });

    test('404 resolves successfully (idempotent delete, amendment)', () async {
      final client = MockClient((req) async => http.Response('{}', 404));

      // Must NOT throw — already-absent server-side trip is a success.
      await build(client).deleteTrip('already-gone');
    });

    test('other 4xx on delete still throws non-retryable', () {
      final client = MockClient((req) async => http.Response('{}', 400));

      expect(
        () => build(client).deleteTrip('trip-x'),
        throwsA(
          isA<SyncException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.retryable, 'retryable', false),
        ),
      );
    });
  });

  group('ApiClient.restoreTrips', () {
    String envelope(List<Map<String, dynamic>> trips) => jsonEncode({
          'statusCode': 200,
          'body': {
            'data': {'trips': trips},
          },
        });

    test('unwraps the FULL envelope body.data.trips into companions', () async {
      final t1 = TripSerializer.toJson(sampleTrip());
      final t2 = TripSerializer.toJson(sampleTrip())
        ..['id'] = '22222222-2222-4222-8222-222222222222';
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(envelope([t1, t2]), 200);
      });

      final companions = await build(client).restoreTrips();

      expect(captured.method, 'GET');
      expect(captured.url.toString(), '$testBaseUrl$kRestoreTripsPath');
      expect(companions, hasLength(2));
      expect(companions.first.id.value, t1['id']);
    });

    test('a body missing the outer wrapper throws (not silent [])', () {
      // Note: data.trips present but NOT under body — wrong envelope shape.
      final malformed = jsonEncode({
        'data': {'trips': <Map<String, dynamic>>[]},
      });
      final client = MockClient((req) async => http.Response(malformed, 200));

      expect(
        () => build(client).restoreTrips(),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('ApiClient injectable base URL', () {
    test('routes all three calls to the injected host', () async {
      final hosts = <String>{};
      final client = MockClient((req) async {
        hosts.add(req.url.host);
        if (req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'statusCode': 200,
              'body': {
                'data': {'trips': <Map<String, dynamic>>[]},
              },
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });
      final api = ApiClient(
        client: client,
        baseUrl: 'https://emulator.local:5001/api',
        getToken: fixedToken('tok1'),
      );

      await api.syncTrips([sampleTrip()]);
      await api.deleteTrip('trip-1');
      await api.restoreTrips();

      expect(hosts, {'emulator.local'});
    });
  });
}
