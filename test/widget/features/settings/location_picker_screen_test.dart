// Regression test for GEO-BACKFILL-FIX / LOC-02 (historical backfill half).
//
// Bug: LocationPickerScreen._confirm() triggered the historical geofence
// re-label ONLY via `ref.invalidate(geofenceBackfillProvider)`. That provider
// is a keepAlive FutureProvider that is never watched/listened anywhere, so
// invalidating it is a no-op — its body never ran and pre-existing trips were
// never re-labelled after saving a Home/Office anchor.
//
// Fix: after invalidating, `_confirm()` now awaits
// `ref.read(geofenceBackfillProvider.future)`, which forces the keepAlive
// provider's body (and thus GeofenceBackfillService.run()) to actually run.
//
// This test pumps the real LocationPickerScreen backed by a real in-memory
// Drift DB, seeds a historical GPS trip mislabelled `to_office` whose route
// ends exactly at the Home anchor, taps the confirm button, and asserts the
// trip row was re-labelled to `to_home` with `direction_source = geofence`.
//
// Fail-old / pass-new: against the old `invalidate`-only code the backfill
// never runs, so the row stays `to_office` / `time` and the final assertions
// fail. With the fix the awaited provider read runs the service and the row
// flips, so the test passes.
//
// --- 260802-dgp: prompt-on-open + Locate-me feedback ---------------------
//
// Bug: the picker never asked for GPS permission — it opened on a hardcoded
// Bengaluru default and read the device position only if permission was
// ALREADY granted. Its "Locate me" FAB called that same silent resolver and
// simply did nothing when the fix was unavailable (no permission, no fix).
//
// Fix: `_resolveInitialCenter` now requests `locationWhenInUse` (and only
// that) when the slot has no saved coord, falling back silently through the
// existing chain on decline. `_locateMe` is an exhaustive switch over
// `LocationWhenInUseStatus` — every branch either moves the map or shows a
// SnackBar. The tests below drive both paths through a fake
// `TrackingPermissionService` (never the real permission_handler platform
// channel) and pin the six behaviours from the plan's `must_haves`.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/screens/location_picker_screen.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

void main() {
  // The Home anchor the user "drops the pin" on. The picker's initial camera
  // centre is driven to this exact coordinate via the [currentLocation] seam,
  // so confirm persists it as the Home location.
  const homeLat = kMapDefaultCenterLat; // 12.9716
  const homeLng = kMapDefaultCenterLng; // 77.5946

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

  /// Pump a host route with a button that pushes the real
  /// [LocationPickerScreen] for the Home slot, wired to the in-memory [db].
  ///
  /// [permissionService] overrides `trackingPermissionServiceProvider` —
  /// defaults to an always-granted fake (via [_fakePermissionService]) so
  /// tests that don't care about the permission outcome (like the LOC-02
  /// backfill regression below) never reach the real permission_handler
  /// platform channel.
  ///
  /// [currentLocation] overrides the device-position seam — defaults to the
  /// fixed Home coordinate, matching the original LOC-02 test's determinism.
  ///
  /// [seedSavedCoord] seeds `db.userPreferencesDao.setHomeLocation(...)`
  /// BEFORE pumping, so the picker's no-saved-coord permission prompt is
  /// skipped — used by the "does not prompt" test.
  Future<void> pumpAndOpenPicker(
    WidgetTester tester, {
    TrackingPermissionService? permissionService,
    CurrentLocationResolver? currentLocation,
    bool seedSavedCoord = false,
  }) async {
    if (seedSavedCoord) {
      await db.userPreferencesDao.setHomeLocation(homeLat, homeLng);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // geofenceBackfillProvider is intentionally NOT overridden: it reads
          // these two DAO providers from the container and constructs the real
          // GeofenceBackfillService, so the confirm path exercises the genuine
          // backfill against the real in-memory DB.
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          userPreferencesDaoProvider.overrideWithValue(db.userPreferencesDao),
          trackingPermissionServiceProvider.overrideWithValue(
            permissionService ??
                _fakePermissionService(
                  probeStatus: PermissionStatus.granted,
                  log: _PermissionLog(),
                ),
          ),
        ],
        child: MaterialApp(
          // LocationPickerCrosshair reads Theme.of(context)
          // .extension<TraevyTokensExt>()! — install the real app theme so the
          // extension is present (a bare MaterialApp omits it and the pin's
          // null-check throws during build).
          theme: buildLightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LocationPickerScreen(
                        isHome: true,
                        currentLocation:
                            currentLocation ??
                            () async => const LatLng(homeLat, homeLng),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    // Push the route, then drain the async initial-centre resolution
    // (postFrameCallback → getOrDefault → [requestWhenInUse] →
    // getCurrentPosition → setState). Plain pumps only — never
    // pumpAndSettle while FlutterMap is mounted (its tile timers never
    // settle).
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets(
    'LOC-02: saving a Home location re-labels a historical trip via the '
    'geofence backfill (dead-trigger regression closed)',
    (tester) async {
      // Historical GPS trip currently mislabelled `to_office` by the time
      // heuristic, whose route ENDS exactly at the Home anchor. After the
      // anchor is saved, the backfill must flip it to `to_home` / `geofence`.
      final polyline = encodePolyline(<({double lat, double lng})>[
        (lat: 12.0, lng: 77.0),
        (lat: homeLat, lng: homeLng),
      ]);
      await db.tripsDao
          .into(db.tripsDao.trips)
          .insert(
            TripsCompanion.insert(
              id: 'hist',
              userId: const Value(kDefaultUserId),
              startTime: DateTime.utc(2026, 5, 1, 8),
              endTime: DateTime.utc(2026, 5, 1, 8, 30),
              durationSeconds: 1800,
              distanceMeters: 12000,
              direction: kDirectionToOffice,
              timeMovingSeconds: 1200,
              timeStuckSeconds: 600,
              routePolyline: Value(polyline),
              directionSource: const Value(kDirectionSourceTime),
            ),
          );

      await pumpAndOpenPicker(tester);

      // The picker has finished resolving its centre: the map and confirm bar
      // are on screen.
      expect(find.byType(FlutterMap), findsOneWidget);
      final confirmButton = find.widgetWithText(
        FilledButton,
        kLocationPickerSetHomeButton,
      );
      expect(confirmButton, findsOneWidget);

      // Sanity: the anchor is not yet saved and the trip is still mislabelled.
      final prefsBefore = await db.userPreferencesDao.getOrDefault();
      expect(prefsBefore.homeLat, isNull);
      final tripBefore = await db.tripsDao.findById('hist');
      expect(tripBefore?.direction, kDirectionToOffice);

      // Tap confirm: persists the Home anchor, then (with the fix) awaits the
      // backfill provider so the historical relabel actually runs.
      await tester.tap(confirmButton);
      // Drain the confirm-path futures (setHomeLocation → invalidate → awaited
      // provider read → service.run() → updateDirectionAndSource → pop).
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // The Home anchor was persisted at the pinned coordinate.
      final prefsAfter = await db.userPreferencesDao.getOrDefault();
      expect(prefsAfter.homeLat, closeTo(homeLat, 0.001));
      expect(prefsAfter.homeLng, closeTo(homeLng, 0.001));

      // The historical trip was re-labelled by the geofence backfill — this is
      // the behaviour the dead `ref.invalidate`-only trigger failed to produce.
      final tripAfter = await db.tripsDao.findById('hist');
      expect(tripAfter?.direction, kDirectionToHome);
      expect(tripAfter?.directionSource, kDirectionSourceGeofence);
    },
  );

  testWidgets(
    '260802-dgp: opening the picker with no saved coord prompts for '
    'locationWhenInUse exactly once and centres the map on the resolved fix',
    (tester) async {
      final log = _PermissionLog();
      final service = _fakePermissionService(
        probeStatus: PermissionStatus.denied,
        requestStatus: PermissionStatus.granted,
        log: log,
      );
      const resolvedLat = 10.0;
      const resolvedLng = 20.0;

      await pumpAndOpenPicker(
        tester,
        permissionService: service,
        currentLocation: () async => const LatLng(resolvedLat, resolvedLng),
      );

      expect(log.requestCalls, <Permission>[Permission.locationWhenInUse]);

      final confirmButton = find.widgetWithText(
        FilledButton,
        kLocationPickerSetHomeButton,
      );
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final prefsAfter = await db.userPreferencesDao.getOrDefault();
      expect(prefsAfter.homeLat, closeTo(resolvedLat, 0.001));
      expect(prefsAfter.homeLng, closeTo(resolvedLng, 0.001));
    },
  );

  testWidgets(
    '260802-dgp: opening the picker for a slot with a saved coord does not '
    'prompt for permission',
    (tester) async {
      final log = _PermissionLog();
      final service = _fakePermissionService(
        probeStatus: PermissionStatus.granted,
        log: log,
      );

      await pumpAndOpenPicker(
        tester,
        permissionService: service,
        seedSavedCoord: true,
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      // Nothing to locate — a saved coord already exists, so prompting would
      // be gratuitous.
      expect(log.probeCalls, isEmpty);
      expect(log.requestCalls, isEmpty);
    },
  );

  testWidgets(
    '260802-dgp: declining the permission prompt on open falls back '
    'silently with no SnackBar and never reads a position',
    (tester) async {
      final log = _PermissionLog();
      final service = _fakePermissionService(
        probeStatus: PermissionStatus.denied,
        requestStatus: PermissionStatus.denied,
        log: log,
      );
      var resolverCalled = false;

      await pumpAndOpenPicker(
        tester,
        permissionService: service,
        currentLocation: () async {
          resolverCalled = true;
          return const LatLng(homeLat, homeLng);
        },
      );

      // D-3: reading a position without permission would be a bug.
      expect(resolverCalled, isFalse);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    '260802-dgp: Locate me shows a SnackBar when permission is denied',
    (tester) async {
      final log = _PermissionLog();
      final service = _fakePermissionService(
        probeStatus: PermissionStatus.denied,
        requestStatus: PermissionStatus.denied,
        log: log,
      );

      await pumpAndOpenPicker(tester, permissionService: service);

      await tester.tap(find.byIcon(Icons.my_location_rounded));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(
        find.text(kLocationPickerPermissionDeniedMessage),
        findsOneWidget,
      );
      expect(find.byType(SnackBarAction), findsNothing);
    },
  );

  testWidgets(
    '260802-dgp: Locate me shows the Open-settings action when permission '
    'is permanently denied',
    (tester) async {
      final log = _PermissionLog();
      final service = _fakePermissionService(
        probeStatus: PermissionStatus.permanentlyDenied,
        log: log,
      );

      await pumpAndOpenPicker(tester, permissionService: service);

      await tester.tap(find.byIcon(Icons.my_location_rounded));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(
        find.text(kLocationPickerPermissionBlockedMessage),
        findsOneWidget,
      );

      await tester.tap(find.text(kOpenPermissionSettingsLabel));
      await tester.pump();

      expect(log.openedCount, 1);
    },
  );

  testWidgets(
    '260802-dgp: Locate me shows the location-unavailable SnackBar when '
    'permission is granted but the position read fails',
    (tester) async {
      final log = _PermissionLog();
      final service = _fakePermissionService(
        probeStatus: PermissionStatus.granted,
        log: log,
      );

      await pumpAndOpenPicker(
        tester,
        permissionService: service,
        currentLocation: () async => null,
      );

      await tester.tap(find.byIcon(Icons.my_location_rounded));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(
        find.text(kLocationPickerLocationUnavailableMessage),
        findsOneWidget,
      );
    },
  );
}

/// Records which [Permission] values were probed/requested and how many
/// times `openSystemSettings` fired, mirroring `_CallLog` from
/// `tracking_permission_service_test.dart`'s own unit tests.
class _PermissionLog {
  final List<Permission> probeCalls = <Permission>[];
  final List<Permission> requestCalls = <Permission>[];
  int openedCount = 0;
}

/// Builds a [TrackingPermissionService.forTesting] fake whose probe of
/// `Permission.locationWhenInUse` always resolves to [probeStatus], and
/// whose request (only reached when the probe is not already granted or
/// permanently denied) resolves to [requestStatus].
///
/// Any OTHER [Permission] throws — mirroring the seeded-narrowly technique
/// in the service's own unit tests, so a stray locationAlways/notification
/// call fails the test loudly instead of silently returning a default.
TrackingPermissionService _fakePermissionService({
  required PermissionStatus probeStatus,
  required _PermissionLog log,
  PermissionStatus? requestStatus,
}) {
  return TrackingPermissionService.forTesting(
    probe: (permission) async {
      log.probeCalls.add(permission);
      if (permission != Permission.locationWhenInUse) {
        throw StateError('Unexpected probe call: $permission');
      }
      return probeStatus;
    },
    requester: (permission) async {
      log.requestCalls.add(permission);
      if (permission != Permission.locationWhenInUse) {
        throw StateError('Unexpected request call: $permission');
      }
      return requestStatus ?? probeStatus;
    },
    opener: () async {
      log.openedCount++;
      return true;
    },
  );
}
