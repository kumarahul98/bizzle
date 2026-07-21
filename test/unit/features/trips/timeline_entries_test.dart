// Unit coverage for the Phase 31 (D-07) trip timeline: the rows are now
// derived from real `trip_breaks` and `trip_stuck_segments` data, ordered by
// time, instead of the hardcoded 40%-of-duration "Stuck in traffic" marker
// that used to be invented at render time.

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/trips/widgets/trip_timeline.dart';

final DateTime _start = DateTime.utc(2026, 4, 1, 8);
final DateTime _end = DateTime.utc(2026, 4, 1, 8, 45);

TripBreakRow _break(int fromMinute, int toMinute) => TripBreakRow(
  id: 'break-$fromMinute',
  tripId: 'trip-1',
  startTime: _start.add(Duration(minutes: fromMinute)),
  endTime: _start.add(Duration(minutes: toMinute)),
);

TripStuckSegmentRow _segment(int fromMinute, int toMinute) =>
    TripStuckSegmentRow(
      id: 'seg-$fromMinute',
      tripId: 'trip-1',
      startPointIndex: fromMinute,
      endPointIndex: toMinute,
      startTime: _start.add(Duration(minutes: fromMinute)),
      endTime: _start.add(Duration(minutes: toMinute)),
    );

List<TimelineEntry> build({
  List<TripBreakRow> breaks = const [],
  List<TripStuckSegmentRow> segments = const [],
  String direction = kDirectionToOffice,
}) => buildTimelineEntries(
  startTime: _start,
  endTime: _end,
  direction: direction,
  breaks: breaks,
  segments: segments,
);

void main() {
  group('buildTimelineEntries', () {
    test('a trip with no breaks and no segments renders only the anchors', () {
      final entries = build();
      expect(entries, hasLength(2));
      expect(entries.first.kind, TimelineEntryKind.started);
      expect(entries.first.label, kTimelineStartedLabel);
      expect(entries.last.kind, TimelineEntryKind.arrived);
    });

    test('the arrival label follows the trip direction', () {
      expect(build().last.label, kTimelineArrivedOfficeLabel);
      expect(
        build(direction: kDirectionToHome).last.label,
        kTimelineArrivedHomeLabel,
      );
    });

    test('no row is ever placed at a fabricated 40% of the duration', () {
      // The old widget synthesised a stuck row at start + 0.4 * duration.
      final fabricated = _start.add(const Duration(minutes: 18)).toLocal();
      final entries = build(segments: [_segment(5, 9)]);
      expect(
        entries.where((e) => e.time == fabricated),
        isEmpty,
        reason: 'timeline rows must come from stored rows, never a ratio',
      );
      // The one stuck row sits where the stored segment actually starts.
      final stuck = entries.singleWhere(
        (e) => e.kind == TimelineEntryKind.stuckSegment,
      );
      expect(stuck.time, _start.add(const Duration(minutes: 5)).toLocal());
    });

    test('breaks and stuck stretches interleave in chronological order', () {
      final entries = build(
        breaks: [_break(20, 25), _break(4, 6)],
        segments: [_segment(10, 13), _segment(30, 32)],
      );
      expect(
        entries.map((e) => e.kind).toList(),
        <TimelineEntryKind>[
          TimelineEntryKind.started,
          TimelineEntryKind.breakSegment, // 4
          TimelineEntryKind.stuckSegment, // 10
          TimelineEntryKind.breakSegment, // 20
          TimelineEntryKind.stuckSegment, // 30
          TimelineEntryKind.arrived,
        ],
      );
      // Strictly non-decreasing in time.
      for (var i = 1; i < entries.length; i++) {
        expect(
          entries[i].time.isBefore(entries[i - 1].time),
          isFalse,
          reason: 'entry $i is out of chronological order',
        );
      }
    });

    test('anchors always bracket the list, first and last', () {
      final entries = build(
        breaks: [_break(0, 2)],
        segments: [_segment(44, 45)],
      );
      expect(entries.first.kind, TimelineEntryKind.started);
      expect(entries.last.kind, TimelineEntryKind.arrived);
    });

    test('durations are whole minutes; anchors carry none', () {
      final entries = build(
        breaks: [_break(10, 17)],
        segments: [_segment(20, 23)],
      );
      expect(entries.first.durationMinutes, isNull);
      expect(entries.last.durationMinutes, isNull);
      expect(
        entries
            .firstWhere((e) => e.kind == TimelineEntryKind.breakSegment)
            .durationMinutes,
        7,
      );
      expect(
        entries
            .firstWhere((e) => e.kind == TimelineEntryKind.stuckSegment)
            .durationMinutes,
        3,
      );
    });

    test('a sub-minute span rounds up to 1 rather than showing 0', () {
      final entries = build(
        segments: [
          TripStuckSegmentRow(
            id: 'seg-short',
            tripId: 'trip-1',
            startPointIndex: 1,
            endPointIndex: 4,
            startTime: _start,
            endTime: _start.add(const Duration(seconds: 40)),
          ),
        ],
      );
      expect(
        entries
            .firstWhere((e) => e.kind == TimelineEntryKind.stuckSegment)
            .durationMinutes,
        1,
      );
    });

    test('an open break (null end) is skipped defensively', () {
      final entries = build(
        breaks: [
          TripBreakRow(
            id: 'break-open',
            tripId: 'trip-1',
            startTime: _start.add(const Duration(minutes: 5)),
          ),
        ],
      );
      expect(entries, hasLength(2));
    });
  });
}
