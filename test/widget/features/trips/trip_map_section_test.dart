// Widget tests for TripMapSection (Phase 31, D-05): the base route plus one
// stuck-coloured polyline per stored segment, drawn AFTER the base route so it
// is not hidden underneath, with out-of-range segments skipped (T-31-02).

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
import 'package:traevy/features/trips/widgets/trip_map_section.dart';

const String _tripId = 'trip-map-1';

/// Six evenly-spaced points so segments have room to address sub-ranges.
final List<LatLng> _points = <LatLng>[
  for (var i = 0; i < 6; i++) LatLng(37.7749 + i * 0.01, -122.4194),
];

TripStuckSegmentRow _segment({
  required String id,
  required int start,
  required int end,
}) => TripStuckSegmentRow(
  id: id,
  tripId: _tripId,
  startPointIndex: start,
  endPointIndex: end,
  startTime: DateTime.utc(2026, 4, 1, 8),
  endTime: DateTime.utc(2026, 4, 1, 8, 2),
);

void main() {
  group('stuckPolylines — T-31-02 clamp on read', () {
    test('an in-range segment becomes one polyline over its sub-range', () {
      final lines = stuckPolylines(
        points: _points,
        segments: [_segment(id: 'a', start: 1, end: 3)],
        color: const Color(0xFF000000),
      );
      expect(lines, hasLength(1));
      // Inclusive of endPointIndex, so 1..3 is three points and the boundary
      // point is shared with the base route rather than leaving a gap.
      expect(lines.single.points, hasLength(3));
      expect(lines.single.points.first, _points[1]);
      expect(lines.single.points.last, _points[3]);
      expect(lines.single.strokeWidth, kStuckPolylineStrokeWidth);
    });

    test(
      'a segment reaching past the decoded points is SKIPPED, not clipped',
      () {
        final lines = stuckPolylines(
          points: _points,
          segments: [_segment(id: 'a', start: 3, end: 99)],
          color: const Color(0xFF000000),
        );
        expect(lines, isEmpty);
      },
    );

    test('negative and inverted ranges are skipped', () {
      final lines = stuckPolylines(
        points: _points,
        segments: [
          _segment(id: 'a', start: -2, end: 3),
          _segment(id: 'b', start: 4, end: 4),
          _segment(id: 'c', start: 4, end: 2),
        ],
        color: const Color(0xFF000000),
      );
      expect(lines, isEmpty);
    });

    test('N valid segments produce N polylines', () {
      final lines = stuckPolylines(
        points: _points,
        segments: [
          _segment(id: 'a', start: 0, end: 1),
          _segment(id: 'b', start: 2, end: 3),
          _segment(id: 'c', start: 3, end: 5),
        ],
        color: const Color(0xFF000000),
      );
      expect(lines, hasLength(3));
    });
  });

  group('TripMapSection', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() async => db.close());

    Future<void> seedTrip() async {
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: _tripId,
          startTime: DateTime.utc(2026, 4, 1, 8),
          endTime: DateTime.utc(2026, 4, 1, 8, 45),
          durationSeconds: 2700,
          distanceMeters: 5000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 2100,
          timeStuckSeconds: 600,
        ),
      );
    }

    Widget host() => ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TripMapSection(
              tripId: _tripId,
              latLngPoints: _points,
              tokens: Theme.of(context).extension<TraevyTokensExt>()!,
            ),
          ),
        ),
      ),
    );

    int polylineCount(WidgetTester tester) => tester
        .widget<PolylineLayer<Object>>(find.byType(PolylineLayer<Object>))
        .polylines
        .length;

    testWidgets('a trip with no stuck segments renders ONE polyline', (
      tester,
    ) async {
      await seedTrip();
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(polylineCount(tester), 1);
    });

    testWidgets('a trip with N stuck segments renders 1 + N polylines', (
      tester,
    ) async {
      await seedTrip();
      await db.tripStuckSegmentsDao.insertSegments([
        TripStuckSegmentsCompanion.insert(
          id: 'seg-a',
          tripId: _tripId,
          startPointIndex: 0,
          endPointIndex: 2,
          startTime: DateTime.utc(2026, 4, 1, 8, 2),
          endTime: DateTime.utc(2026, 4, 1, 8, 5),
        ),
        TripStuckSegmentsCompanion.insert(
          id: 'seg-b',
          tripId: _tripId,
          startPointIndex: 3,
          endPointIndex: 5,
          startTime: DateTime.utc(2026, 4, 1, 8, 20),
          endTime: DateTime.utc(2026, 4, 1, 8, 22),
        ),
      ]);
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();
      expect(polylineCount(tester), 3);
    });

    testWidgets('the stuck overlays are drawn AFTER the base route', (
      tester,
    ) async {
      await seedTrip();
      await db.tripStuckSegmentsDao.insertSegments([
        TripStuckSegmentsCompanion.insert(
          id: 'seg-a',
          tripId: _tripId,
          startPointIndex: 1,
          endPointIndex: 4,
          startTime: DateTime.utc(2026, 4, 1, 8, 2),
          endTime: DateTime.utc(2026, 4, 1, 8, 5),
        ),
      ]);
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();

      final polylines = tester
          .widget<PolylineLayer<Object>>(find.byType(PolylineLayer<Object>))
          .polylines;
      // The base route is first (underneath) and spans every point; the
      // overlay is last (on top) and spans only its sub-range.
      expect(polylines.first.points, hasLength(_points.length));
      expect(polylines.last.points, hasLength(4));
    });
  });
}
