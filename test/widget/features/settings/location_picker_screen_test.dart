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

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/screens/location_picker_screen.dart';
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
  /// [LocationPickerScreen] for the Home slot, wired to the in-memory [db] and
  /// with its device-location seam pinned to the Home coordinate so the map
  /// centre — and therefore the persisted anchor — is deterministic.
  Future<void> pumpAndOpenPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // geofenceBackfillProvider is intentionally NOT overridden: it reads
          // these two DAO providers from the container and constructs the real
          // GeofenceBackfillService, so the confirm path exercises the genuine
          // backfill against the real in-memory DB.
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          userPreferencesDaoProvider.overrideWithValue(db.userPreferencesDao),
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
                        currentLocation: () async =>
                            const LatLng(homeLat, homeLng),
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
    // (postFrameCallback → getOrDefault → setState). Plain pumps only — never
    // pumpAndSettle while FlutterMap is mounted (its tile timers never settle).
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
}
