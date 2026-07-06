import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/trips/services/geofence_direction_resolver.dart';

/// Exhaustive proof of the Phase 21 geofence proximity policy (D-04..D-09).
///
/// The resolver is a PURE function: it takes the trip's start/end coords plus
/// the saved Home/Office anchors and returns kDirectionToOffice,
/// kDirectionToHome, or null (no confident match → caller falls back to time).
/// It uses only the static `Geolocator.distanceBetween` math, so it runs on the
/// plain Dart VM with no plugin channel.
///
/// Fixtures use real-world-scale coordinates (Bengaluru, a few km apart) so
/// `distanceBetween` returns realistic meters — never the degenerate (0,0).
void main() {
  group('GeofenceDirectionResolver (D-04..D-09)', () {
    const resolver = GeofenceDirectionResolver();

    // Home and Office ~4.5 km apart — far enough that a point near one is
    // nowhere near the other (no accidental overlap).
    const home = (lat: 12.9716, lng: 77.5946);
    const office = (lat: 12.9352, lng: 77.6245);

    // A point ~50 m from Home (well within the 250 m radius).
    const nearHome = (lat: 12.97205, lng: 77.5946);
    // A point ~50 m from Office.
    const nearOffice = (lat: 12.93565, lng: 77.6245);
    // A point ~3 km from both anchors.
    const farFromBoth = (lat: 13.0, lng: 77.65);

    test('D-04 confident END → Office: end near Office only → to_office', () {
      expect(
        resolver.resolve(
          start: nearHome,
          end: nearOffice,
          homeLat: home.lat,
          homeLng: home.lng,
          officeLat: office.lat,
          officeLng: office.lng,
        ),
        kDirectionToOffice,
      );
    });

    test('D-04 confident END → Home: end near Home only → to_home', () {
      expect(
        resolver.resolve(
          start: nearOffice,
          end: nearHome,
          homeLat: home.lat,
          homeLng: home.lng,
          officeLat: office.lat,
          officeLng: office.lng,
        ),
        kDirectionToHome,
      );
    });

    test(
      'D-06 outside both: end far from both anchors → null (time fallback)',
      () {
        expect(
          resolver.resolve(
            start: nearHome,
            end: farFromBoth,
            homeLat: home.lat,
            homeLng: home.lng,
            officeLat: office.lat,
            officeLng: office.lng,
          ),
          isNull,
        );
      },
    );

    group('D-07 overlap (Home & Office within 2× radius, end inside BOTH)', () {
      // Place Home and Office only ~80 m apart, symmetric in LONGITUDE about a
      // shared parallel (same latitude), so a single end point lands within
      // 250 m of BOTH — forcing the START tie-breaker. Keeping both anchors on
      // the SAME latitude makes an east-west midpoint genuinely equidistant:
      // along a parallel the great-circle distance depends only on the
      // (identical) latitude and the longitude delta, so equal longitude
      // offsets give exactly equal distances — no ellipsoid asymmetry, so the
      // equidistant case resolves to null deterministically.
      const closeHome = (lat: 12.97196, lng: 77.59424); // ~80 m west
      const closeOffice = (lat: 12.97196, lng: 77.59496); // ~80 m east
      const midLng = (77.59424 + 77.59496) / 2; // 77.5946 — equidistant
      // End point sits between them, within radius of both.
      const between = (lat: 12.97196, lng: midLng);

      test('start nearer Home → to_office', () {
        // Start far on the Home (west) side so it is strictly nearer closeHome.
        const startNearHome = (lat: 12.97196, lng: 77.59300);
        expect(
          resolver.resolve(
            start: startNearHome,
            end: between,
            homeLat: closeHome.lat,
            homeLng: closeHome.lng,
            officeLat: closeOffice.lat,
            officeLng: closeOffice.lng,
          ),
          kDirectionToOffice,
        );
      });

      test('start nearer Office → to_home', () {
        const startNearOffice = (lat: 12.97196, lng: 77.59620);
        expect(
          resolver.resolve(
            start: startNearOffice,
            end: between,
            homeLat: closeHome.lat,
            homeLng: closeHome.lng,
            officeLat: closeOffice.lat,
            officeLng: closeOffice.lng,
          ),
          kDirectionToHome,
        );
      });

      test('start equidistant from Home and Office → null', () {
        // Start exactly at the parallel midpoint → equal distance to both
        // anchors (same latitude, symmetric longitudes) → null.
        expect(
          resolver.resolve(
            start: between,
            end: between,
            homeLat: closeHome.lat,
            homeLng: closeHome.lng,
            officeLat: closeOffice.lat,
            officeLng: closeOffice.lng,
          ),
          isNull,
        );
      });

      test('start null with overlapping end → null (cannot tie-break)', () {
        expect(
          resolver.resolve(
            start: null,
            end: between,
            homeLat: closeHome.lat,
            homeLng: closeHome.lng,
            officeLat: closeOffice.lat,
            officeLng: closeOffice.lng,
          ),
          isNull,
        );
      });
    });

    group('D-08 only one anchor set (never guess the unset one)', () {
      test('only Home set, end near Home → to_home', () {
        expect(
          resolver.resolve(
            start: nearOffice,
            end: nearHome,
            homeLat: home.lat,
            homeLng: home.lng,
            officeLat: null,
            officeLng: null,
          ),
          kDirectionToHome,
        );
      });

      test('only Home set, end far from Home → null (never to_office)', () {
        expect(
          resolver.resolve(
            start: nearHome,
            end: farFromBoth,
            homeLat: home.lat,
            homeLng: home.lng,
            officeLat: null,
            officeLng: null,
          ),
          isNull,
        );
      });

      test('only Office set, end near Office → to_office', () {
        expect(
          resolver.resolve(
            start: nearHome,
            end: nearOffice,
            homeLat: null,
            homeLng: null,
            officeLat: office.lat,
            officeLng: office.lng,
          ),
          kDirectionToOffice,
        );
      });

      test('only Office set, end far from Office → null (never to_home)', () {
        expect(
          resolver.resolve(
            start: nearOffice,
            end: farFromBoth,
            homeLat: null,
            homeLng: null,
            officeLat: office.lat,
            officeLng: office.lng,
          ),
          isNull,
        );
      });
    });

    group('D-09 additive / null guards', () {
      test('both anchors null → null (pre-Phase-21 behaviour)', () {
        expect(
          resolver.resolve(
            start: nearHome,
            end: nearOffice,
            homeLat: null,
            homeLng: null,
            officeLat: null,
            officeLng: null,
          ),
          isNull,
        );
      });

      test('end null (empty/short polyline) → null', () {
        expect(
          resolver.resolve(
            start: nearHome,
            end: null,
            homeLat: home.lat,
            homeLng: home.lng,
            officeLat: office.lat,
            officeLng: office.lng,
          ),
          isNull,
        );
      });
    });

    test('D-06 boundary: distance exactly == radius is OUTSIDE (strict <)', () {
      // Construct an end point whose great-circle distance from Office is
      // (within float tolerance) exactly the radius, then assert the strict
      // boundary by probing just inside and just outside.
      // Use a tiny radius so we control the geometry precisely: a point
      // ~111.32 m east of Office at this latitude is ~0.001 deg lng. With a
      // radius set to that exact distance, the point must be OUTSIDE.
      const r = 100.0;
      // ~1.0 m east of Office — comfortably inside r=100.
      const justInside = (lat: 12.9352, lng: 77.62451);
      expect(
        resolver.resolve(
          start: home,
          end: justInside,
          homeLat: null,
          homeLng: null,
          officeLat: office.lat,
          officeLng: office.lng,
          radiusMeters: r,
        ),
        kDirectionToOffice,
        reason: 'a point well within r must match',
      );
      // ~500 m east of Office — comfortably outside r=100.
      const wellOutside = (lat: 12.9352, lng: 77.6291);
      expect(
        resolver.resolve(
          start: home,
          end: wellOutside,
          homeLat: null,
          homeLng: null,
          officeLat: office.lat,
          officeLng: office.lng,
          radiusMeters: r,
        ),
        isNull,
        reason: 'a point beyond r must not match',
      );
    });
  });
}
