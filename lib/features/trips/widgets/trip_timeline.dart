import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/trips/providers/trip_detail_providers.dart';
import 'package:traevy/features/trips/widgets/trip_timeline_row.dart';
import 'package:traevy/shared/widgets/section_label.dart';

/// One chronologically-placed entry in the trip timeline.
@immutable
class TimelineEntry {
  /// Create an entry anchored at [time] (local).
  const TimelineEntry({
    required this.time,
    required this.label,
    required this.kind,
    this.durationMinutes,
  });

  /// Local time the entry is anchored at; drives both display and ordering.
  final DateTime time;

  /// Row copy, always sourced from `constants.dart`.
  final String label;

  /// Which of the four row types this is — drives icon and colour.
  final TimelineEntryKind kind;

  /// Whole minutes shown right-aligned, or null for the anchors.
  final int? durationMinutes;
}

/// The finite set of trip timeline row types (CLAUDE.md: enums for finite
/// state, never raw strings).
enum TimelineEntryKind {
  /// The trip's real start anchor.
  started,

  /// One real break segment from `trip_breaks`.
  breakSegment,

  /// One real stuck stretch from `trip_stuck_segments`.
  stuckSegment,

  /// The trip's real end anchor.
  arrived,
}

/// Chronological timeline of what actually happened on a trip (Phase 31,
/// D-07).
///
/// Before this phase the widget invented a "Stuck in traffic" row and placed
/// it at a hardcoded 40% of trip duration — a fiction that could not agree
/// with the map. Every row here is now derived from a stored row: the real
/// breaks the user took (`trip_breaks`) and the real stuck stretches
/// (`trip_stuck_segments`), between the trip's real Started / Arrived anchors.
///
/// A trip with no breaks and no segments — a manual entry, a restored trip, or
/// anything recorded before Phase 31 — renders just the two anchors. That is
/// the intended degradation, not an empty state (D-06).
class TripTimeline extends ConsumerWidget {
  /// Creates a [TripTimeline] for [tripId].
  const TripTimeline({
    required this.tripId,
    required this.startTime,
    required this.endTime,
    required this.direction,
    super.key,
  });

  /// Trip whose breaks and stuck segments are shown.
  final String tripId;

  /// Trip start time (UTC); converted to local for display.
  final DateTime startTime;

  /// Trip end time (UTC); converted to local for display.
  final DateTime endTime;

  /// Trip direction string (kDirectionToOffice or kDirectionToHome).
  final String direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final breaks = ref
        .watch(tripBreaksProvider(tripId))
        .maybeWhen(
          data: (rows) => rows,
          orElse: () => const <TripBreakRow>[],
        );
    final segments = ref
        .watch(tripStuckSegmentsProvider(tripId))
        .maybeWhen(
          data: (rows) => rows,
          orElse: () => const <TripStuckSegmentRow>[],
        );

    final entries = buildTimelineEntries(
      startTime: startTime,
      endTime: endTime,
      direction: direction,
      breaks: breaks,
      segments: segments,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionLabel(text: kTimelineSectionLabel),
        const SizedBox(height: 12),
        for (var i = 0; i < entries.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          _TimelineEntryRow(entry: entries[i], tokens: tokens),
        ],
      ],
    );
  }
}

/// One [TimelineEntry] rendered as a [TripTimelineRow].
class _TimelineEntryRow extends StatelessWidget {
  const _TimelineEntryRow({required this.entry, required this.tokens});

  final TimelineEntry entry;
  final TraevyTokensExt tokens;

  @override
  Widget build(BuildContext context) {
    final (icon, iconBg, iconColor) = switch (entry.kind) {
      TimelineEntryKind.started => (
        Icons.location_on_rounded,
        tokens.accentBg,
        tokens.accent,
      ),
      TimelineEntryKind.breakSegment => (
        Icons.pause_rounded,
        tokens.surface2,
        tokens.textDim,
      ),
      TimelineEntryKind.stuckSegment => (
        Icons.access_time_rounded,
        tokens.stuckBg,
        tokens.stuck,
      ),
      TimelineEntryKind.arrived => (
        Icons.flag_rounded,
        tokens.movingBg,
        tokens.moving,
      ),
    };
    final minutes = entry.durationMinutes;
    return TripTimelineRow(
      time: entry.time,
      icon: icon,
      iconBg: iconBg,
      iconColor: iconColor,
      label: entry.label,
      duration: minutes == null ? null : '$minutes $kTimelineMinutesSuffix',
      durationColor: iconColor,
    );
  }
}

/// Assemble the timeline's rows in chronological order (Phase 31, D-07).
///
/// Pure and exported so ordering with interleaved breaks and stuck stretches
/// is directly testable without a widget pump. Timestamps are converted from
/// stored UTC to local exactly once, here.
///
/// The Started and Arrived anchors always bracket the list: a stored row whose
/// timestamp falls outside the trip (possible after a Phase 19 time edit) is
/// still ordered by its own time, but the anchors are pinned first and last so
/// the timeline never reads as if the trip ended before it began.
///
/// A break or stretch shorter than a minute rounds UP to `1` rather than
/// showing `0 min`, which would read as "nothing happened" beside a row
/// asserting something did.
List<TimelineEntry> buildTimelineEntries({
  required DateTime startTime,
  required DateTime endTime,
  required String direction,
  required List<TripBreakRow> breaks,
  required List<TripStuckSegmentRow> segments,
}) {
  final middle = <TimelineEntry>[
    for (final b in breaks)
      // An open break (null end) never exists on a finalized trip; skip it
      // defensively rather than rendering a row with no duration.
      if (b.endTime != null)
        TimelineEntry(
          time: b.startTime.toLocal(),
          label: kTimelineBreakLabel,
          kind: TimelineEntryKind.breakSegment,
          durationMinutes: _wholeMinutes(b.startTime, b.endTime!),
        ),
    for (final s in segments)
      TimelineEntry(
        time: s.startTime.toLocal(),
        label: kTimelineStuckLabel,
        kind: TimelineEntryKind.stuckSegment,
        durationMinutes: _wholeMinutes(s.startTime, s.endTime),
      ),
  ]..sort((a, b) => a.time.compareTo(b.time));

  return <TimelineEntry>[
    TimelineEntry(
      time: startTime.toLocal(),
      label: kTimelineStartedLabel,
      kind: TimelineEntryKind.started,
    ),
    ...middle,
    TimelineEntry(
      time: endTime.toLocal(),
      label: direction == kDirectionToHome
          ? kTimelineArrivedHomeLabel
          : kTimelineArrivedOfficeLabel,
      kind: TimelineEntryKind.arrived,
    ),
  ];
}

/// Whole minutes between [from] and [to], never below 1 for a real span.
int _wholeMinutes(DateTime from, DateTime to) {
  final seconds = to.difference(from).inSeconds;
  if (seconds <= 0) return 0;
  final minutes = seconds ~/ 60;
  return minutes < 1 ? 1 : minutes;
}
