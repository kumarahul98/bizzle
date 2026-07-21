import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/trips/providers/trip_detail_providers.dart';

const double _kMapHeight = 210;
const double _kMapBorderRadius = 16;
const double _kMapCameraPadding = 32;
const double _kPolylineStrokeWidth = 4;

/// Route map for the trip detail screen, with the trip's stuck stretches
/// painted over the base route (Phase 31, D-05).
///
/// Extracted from `trip_detail_screen.dart`, which was already at 682 lines
/// against CLAUDE.md's ~100-line widget cap.
///
/// Wrapped in a `RepaintBoundary` (Review LOW #5) so tile rasterization is
/// isolated from adjacent state changes in `StuckBar` / `TripTimeline`.
class TripMapSection extends ConsumerWidget {
  /// Create the map section for [tripId] over the already-decoded
  /// [latLngPoints].
  const TripMapSection({
    required this.tripId,
    required this.latLngPoints,
    required this.tokens,
    super.key,
  });

  /// Trip whose stuck segments should be painted.
  final String tripId;

  /// Decoded route points, in polyline point-index order.
  final List<LatLng> latLngPoints;

  /// Resolved Traevy design tokens from the ambient theme.
  final TraevyTokensExt tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pitfall 2 guard: CameraFit.coordinates asserts on an empty list.
    // Render a placeholder when no decoded points exist (corrupt polyline).
    if (latLngPoints.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kMapBorderRadius),
        child: Container(height: _kMapHeight, color: tokens.mapBg),
      );
    }

    // D-06: a pre-Phase-31 trip, a manual entry, or a restored trip has no
    // segments and simply renders the single base polyline — no empty state,
    // no error. An error or still-loading stream degrades the same way.
    final segments = ref
        .watch(tripStuckSegmentsProvider(tripId))
        .maybeWhen(
          data: (rows) => rows,
          orElse: () => const <TripStuckSegmentRow>[],
        );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kMapBorderRadius),
        child: SizedBox(
          height: _kMapHeight,
          child: IgnorePointer(
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: latLngPoints,
                  padding: const EdgeInsets.all(_kMapCameraPadding),
                ),
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: Theme.of(context).brightness == Brightness.dark
                      ? kMapTileUrlDark
                      : kMapTileUrlLight,
                  subdomains: kMapTileSubdomains,
                  userAgentPackageName: kMapUserAgentPackageName,
                ),
                PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: latLngPoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: _kPolylineStrokeWidth,
                    ),
                    // Draw order matters: the stuck overlays MUST come after
                    // the base route or the primary-coloured line hides them.
                    ...stuckPolylines(
                      points: latLngPoints,
                      segments: segments,
                      color: tokens.stuck,
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: <SourceAttribution>[
                    TextSourceAttribution(
                      '© CARTO, © OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Build one [Polyline] per stuck [segments] entry over its sub-range of
/// [points] (Phase 31, D-05).
///
/// T-31-02 (clamp on read): a segment whose index range does not fully address
/// [points] — negative, inverted, or reaching past the end — is SKIPPED
/// entirely rather than drawn partially. A truncated polyline after a failed
/// write must never paint a stretch of road the user did not sit on.
///
/// The sub-range is inclusive of `endPointIndex`, so consecutive segments
/// share their boundary point with the base route and join visually instead of
/// leaving a hairline gap.
///
/// Exported (not private) so widget tests can assert the clamp without going
/// through a full `FlutterMap` render.
List<Polyline<Object>> stuckPolylines({
  required List<LatLng> points,
  required List<TripStuckSegmentRow> segments,
  required Color color,
}) {
  final result = <Polyline<Object>>[];
  for (final segment in segments) {
    final start = segment.startPointIndex;
    final end = segment.endPointIndex;
    if (start < 0 || end <= start || end >= points.length) continue;
    result.add(
      Polyline<Object>(
        points: points.sublist(start, end + 1),
        color: color,
        strokeWidth: kStuckPolylineStrokeWidth,
      ),
    );
  }
  return result;
}
