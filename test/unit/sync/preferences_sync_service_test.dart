import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/preferences_sync_service.dart';

/// Tests for the Phase 29 preferences sync service (LOC-03).
///
/// The centrepiece is the D-03 merge matrix in
/// [PreferencesSyncService.restore]:
/// cloud values fill ONLY local gaps. CLAUDE.md makes the client authoritative,
/// so a user who already set Home on this device must never have it moved by a
/// stale cloud copy. Every cell of that matrix is pinned below.
void main() {
  const home = (lat: 12.9716, lng: 77.5946);
  const office = (lat: 12.9352, lng: 77.6245);
  const cloudHome = (lat: 51.5074, lng: -0.1278);
  const cloudOffice = (lat: 48.8566, lng: 2.3522);

  late AppDatabase db;

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

  String restoreEnvelope({
    double? homeLat,
    double? homeLng,
    double? officeLat,
    double? officeLng,
  }) => jsonEncode({
    'statusCode': 200,
    'body': {
      'data': {
        'savedLocations': {
          'homeLat': homeLat,
          'homeLng': homeLng,
          'officeLat': officeLat,
          'officeLng': officeLng,
        },
      },
    },
  });

  PreferencesSyncService service(MockClient client) => PreferencesSyncService(
    apiClient: ApiClient(
      client: client,
      baseUrl: 'https://test.example/api',
      getToken: ({forceRefresh = false}) async => 'tok1',
    ),
    userPreferencesDao: db.userPreferencesDao,
  );

  group('push', () {
    test('sends the locally saved coordinates', () async {
      await db.userPreferencesDao.setHomeLocation(home.lat, home.lng);
      await db.userPreferencesDao.setOfficeLocation(office.lat, office.lng);

      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"statusCode":200,"body":{"data":{}}}', 200);
      });

      final ok = await service(client).push();

      expect(ok, isTrue);
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      final saved = body['savedLocations'] as Map<String, dynamic>;
      expect(saved['homeLat'], home.lat);
      expect(saved['officeLng'], office.lng);
    });

    test(
      'pushes even when nothing is set — clearing must reach the cloud',
      () async {
        late http.Request captured;
        final client = MockClient((req) async {
          captured = req;
          return http.Response('{"statusCode":200,"body":{"data":{}}}', 200);
        });

        final ok = await service(client).push();

        expect(ok, isTrue);
        // Skipping the all-null push would strand a cleared location as a stale
        // coordinate in Firestore forever.
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(
          (body['savedLocations'] as Map<String, dynamic>)['homeLat'],
          isNull,
        );
      },
    );

    test('returns false instead of throwing when the request fails', () async {
      final client = MockClient((_) async => http.Response('boom', 500));

      // Runs on a UI seam; CLAUDE.md forbids blocking or crashing the UI on
      // network failure. The next change or sign-in re-sends.
      await expectLater(service(client).push(), completion(isFalse));
    });

    test('returns false when not signed in', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final svc = PreferencesSyncService(
        apiClient: ApiClient(
          client: client,
          baseUrl: 'https://test.example/api',
          getToken: ({forceRefresh = false}) async => null,
        ),
        userPreferencesDao: db.userPreferencesDao,
      );

      await expectLater(svc.push(), completion(isFalse));
    });
  });

  group('restore — D-03 null-only merge', () {
    test('fills both when local has neither', () async {
      final client = MockClient(
        (_) async => http.Response(
          restoreEnvelope(
            homeLat: cloudHome.lat,
            homeLng: cloudHome.lng,
            officeLat: cloudOffice.lat,
            officeLng: cloudOffice.lng,
          ),
          200,
        ),
      );

      final written = await service(client).restore();

      expect(written, 2);
      final prefs = await db.userPreferencesDao.getOrDefault();
      expect(prefs.homeLat, cloudHome.lat);
      expect(prefs.officeLat, cloudOffice.lat);
    });

    test('does NOT overwrite a Home the user already set', () async {
      await db.userPreferencesDao.setHomeLocation(home.lat, home.lng);

      final client = MockClient(
        (_) async => http.Response(
          restoreEnvelope(
            homeLat: cloudHome.lat,
            homeLng: cloudHome.lng,
            officeLat: cloudOffice.lat,
            officeLng: cloudOffice.lng,
          ),
          200,
        ),
      );

      final written = await service(client).restore();

      // Office was a gap and gets filled; Home is untouched.
      expect(written, 1);
      final prefs = await db.userPreferencesDao.getOrDefault();
      expect(prefs.homeLat, home.lat, reason: 'local Home must win (D-03)');
      expect(prefs.homeLng, home.lng);
      expect(prefs.officeLat, cloudOffice.lat);
    });

    test('does NOT overwrite when local has both', () async {
      await db.userPreferencesDao.setHomeLocation(home.lat, home.lng);
      await db.userPreferencesDao.setOfficeLocation(office.lat, office.lng);

      final client = MockClient(
        (_) async => http.Response(
          restoreEnvelope(
            homeLat: cloudHome.lat,
            homeLng: cloudHome.lng,
            officeLat: cloudOffice.lat,
            officeLng: cloudOffice.lng,
          ),
          200,
        ),
      );

      final written = await service(client).restore();

      expect(written, 0);
      final prefs = await db.userPreferencesDao.getOrDefault();
      expect(prefs.homeLat, home.lat);
      expect(prefs.officeLat, office.lat);
    });

    test('writes nothing when the cloud is empty', () async {
      await db.userPreferencesDao.setHomeLocation(home.lat, home.lng);

      final client = MockClient(
        (_) async => http.Response(restoreEnvelope(), 200),
      );

      final written = await service(client).restore();

      expect(written, 0);
      final prefs = await db.userPreferencesDao.getOrDefault();
      expect(prefs.homeLat, home.lat);
    });

    test('fills Home only when the cloud has Home only', () async {
      final client = MockClient(
        (_) async => http.Response(
          restoreEnvelope(homeLat: cloudHome.lat, homeLng: cloudHome.lng),
          200,
        ),
      );

      final written = await service(client).restore();

      expect(written, 1);
      final prefs = await db.userPreferencesDao.getOrDefault();
      expect(prefs.homeLat, cloudHome.lat);
      expect(prefs.officeLat, isNull);
    });

    test(
      'ignores a half-set cloud pair rather than writing half a location',
      () async {
        // The server rejects half-set pairs, so this is defence in depth
        // against a hand-edited document. A lone latitude reads as "set"
        // downstream while being unusable — worse than leaving the gap.
        final client = MockClient(
          (_) async =>
              http.Response(restoreEnvelope(homeLat: cloudHome.lat), 200),
        );

        final written = await service(client).restore();

        expect(written, 0);
        final prefs = await db.userPreferencesDao.getOrDefault();
        expect(prefs.homeLat, isNull);
        expect(prefs.homeLng, isNull);
      },
    );

    test('returns 0 instead of throwing when the request fails', () async {
      final client = MockClient((_) async => http.Response('boom', 500));

      await expectLater(service(client).restore(), completion(0));
    });

    test(
      'returns 0 on a malformed envelope and leaves Drift untouched',
      () async {
        await db.userPreferencesDao.setHomeLocation(home.lat, home.lng);
        final client = MockClient(
          (_) async => http.Response('{"statusCode":200,"body":{}}', 200),
        );

        final written = await service(client).restore();

        expect(written, 0);
        final prefs = await db.userPreferencesDao.getOrDefault();
        expect(prefs.homeLat, home.lat);
      },
    );

    test('is idempotent — a second restore writes nothing more', () async {
      final client = MockClient(
        (_) async => http.Response(
          restoreEnvelope(
            homeLat: cloudHome.lat,
            homeLng: cloudHome.lng,
            officeLat: cloudOffice.lat,
            officeLng: cloudOffice.lng,
          ),
          200,
        ),
      );

      expect(await service(client).restore(), 2);
      // Second run: everything is now locally set, so D-03 blocks every write.
      expect(await service(client).restore(), 0);
    });
  });
}
