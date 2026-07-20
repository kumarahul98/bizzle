import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/preferences_sync_service.dart';

/// Wave 3 trigger semantics for Phase 29 (LOC-03).
///
/// The sign-in seam runs `restore()` then `push()`, and that ORDER is the
/// contract these tests pin. Getting it backwards would silently break the
/// two cases the feature exists for.
void main() {
  const localHome = (lat: 12.9716, lng: 77.5946);
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

  /// Build a service whose transport records the ordered sequence of calls,
  /// and answers GET with [cloud].
  ({PreferencesSyncService service, List<String> calls, List<String> bodies})
  build({Map<String, Object?>? cloud}) {
    final calls = <String>[];
    final bodies = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'GET' &&
          req.url.path.endsWith(kRestorePreferencesPath)) {
        calls.add('restore');
        return http.Response(
          jsonEncode({
            'statusCode': 200,
            'body': {
              'data': {
                'savedLocations':
                    cloud ??
                    const {
                      'homeLat': null,
                      'homeLng': null,
                      'officeLat': null,
                      'officeLng': null,
                    },
              },
            },
          }),
          200,
        );
      }
      calls.add('push');
      bodies.add(req.body);
      return http.Response('{"statusCode":200,"body":{"data":{}}}', 200);
    });

    return (
      service: PreferencesSyncService(
        apiClient: ApiClient(
          client: client,
          baseUrl: 'https://test.example/api',
          getToken: ({forceRefresh = false}) async => 'tok1',
        ),
        userPreferencesDao: db.userPreferencesDao,
      ),
      calls: calls,
      bodies: bodies,
    );
  }

  /// Mirrors `_MainShellState._syncSavedLocations`.
  Future<void> signInSequence(PreferencesSyncService service) async {
    await service.restore();
    await service.push();
  }

  test('sign-in restores BEFORE pushing', () async {
    final h = build();

    await signInSequence(h.service);

    // Push-then-restore would upload the device's empty state first, and on a
    // fresh install that overwrites the user's real cloud locations with null
    // before restore ever reads them.
    expect(h.calls, ['restore', 'push']);
  });

  test('fresh install: cloud pins land locally and are echoed back', () async {
    final h = build(
      cloud: {
        'homeLat': cloudHome.lat,
        'homeLng': cloudHome.lng,
        'officeLat': cloudOffice.lat,
        'officeLng': cloudOffice.lng,
      },
    );

    await signInSequence(h.service);

    final prefs = await db.userPreferencesDao.getOrDefault();
    expect(prefs.homeLat, cloudHome.lat);
    expect(prefs.officeLat, cloudOffice.lat);

    // The follow-up push is a no-op in effect, but must carry the restored
    // values — never nulls that would erase what we just downloaded.
    final pushed =
        (jsonDecode(h.bodies.single) as Map<String, dynamic>)['savedLocations']
            as Map<String, dynamic>;
    expect(pushed['homeLat'], cloudHome.lat);
  });

  test(
    'signed-out user with local pins: sign-in uploads them (the push half)',
    () async {
      await db.userPreferencesDao.setHomeLocation(localHome.lat, localHome.lng);
      // Cloud is empty — this user set pins while signed out.
      final h = build();

      await signInSequence(h.service);

      final pushed =
          (jsonDecode(h.bodies.single)
                  as Map<String, dynamic>)['savedLocations']
              as Map<String, dynamic>;
      // Without the push half of the sequence these coordinates would live
      // only on-device until the user happened to edit a pin again.
      expect(pushed['homeLat'], localHome.lat);
      expect(pushed['homeLng'], localHome.lng);
    },
  );

  test(
    'local pins survive a sign-in that finds different cloud pins',
    () async {
      await db.userPreferencesDao.setHomeLocation(localHome.lat, localHome.lng);
      final h = build(
        cloud: {
          'homeLat': cloudHome.lat,
          'homeLng': cloudHome.lng,
          'officeLat': null,
          'officeLng': null,
        },
      );

      await signInSequence(h.service);

      // D-03: the device wins. The subsequent push then makes the cloud agree
      // with the device, which is the client-authoritative direction.
      final prefs = await db.userPreferencesDao.getOrDefault();
      expect(prefs.homeLat, localHome.lat);

      final pushed =
          (jsonDecode(h.bodies.single)
                  as Map<String, dynamic>)['savedLocations']
              as Map<String, dynamic>;
      expect(pushed['homeLat'], localHome.lat);
    },
  );

  test('a failing restore does not prevent the push', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'GET') {
        calls.add('restore');
        return http.Response('boom', 500);
      }
      calls.add('push');
      return http.Response('{"statusCode":200,"body":{"data":{}}}', 200);
    });
    final service = PreferencesSyncService(
      apiClient: ApiClient(
        client: client,
        baseUrl: 'https://test.example/api',
        getToken: ({forceRefresh = false}) async => 'tok1',
      ),
      userPreferencesDao: db.userPreferencesDao,
    );

    await signInSequence(service);

    // Each half swallows its own failure, so a transient restore error must
    // not strand the upload — otherwise one bad network moment on sign-in
    // would leave the cloud stale until the next manual pin edit.
    expect(calls, ['restore', 'push']);
  });
}
