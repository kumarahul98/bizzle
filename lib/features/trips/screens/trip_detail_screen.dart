import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/tracking/widgets/direction_segmented_toggle.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';
import 'package:traevy/features/trips/services/trip_actions.dart'
    as trip_actions;
import 'package:traevy/features/trips/widgets/edit_trip_sheet.dart';
import 'package:traevy/features/trips/widgets/traffic_insight_card.dart';
import 'package:traevy/features/trips/widgets/trip_timeline.dart';
import 'package:traevy/shared/utils/formatters.dart';
import 'package:traevy/shared/widgets/section_label.dart';
import 'package:traevy/shared/widgets/stuck_bar.dart';

const double _kHorizontalPadding = 20;
const double _kMapHeight = 210;
const double _kMapBorderRadius = 16;
const double _kCardBorderRadius = 16;
const double _kMapCameraPadding = 32;
const double _kPolylineStrokeWidth = 4;
const double _kHeaderIconSize = 36;
const double _kLegendDotSize = 8;

/// Trip detail screen (HIST-03) — Phase 8 Traevy restyle.
///
/// Layout: custom header row (back arrow · date+time · more-options),
/// 210dp flutter_map TileLayer wrapped in RepaintBoundary (Review LOW #5),
/// commute-part-of-day SectionLabel, direction title, Duration+Distance
/// card, StuckBar + legend, TrafficInsightCard callout (GPS trips only),
/// TripTimeline, and Edit/Delete border buttons.
///
/// Manual trips: map is hidden; TrafficInsightCard hidden (no traffic data).
class TripDetailScreen extends ConsumerStatefulWidget {
  /// Create the trip detail screen for [tripId].
  const TripDetailScreen({required this.tripId, super.key});

  /// UUID of the trip to display.
  final String tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  TripRow? _trip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTrip());
  }

  Future<void> _loadTrip() async {
    final dao = ref.read(tripsDaoProvider);
    final trip = await dao.findById(widget.tripId);
    if (!mounted) return;
    setState(() {
      _trip = trip;
      _loading = false;
    });
  }

  TripSummary _summaryFromRow(TripRow row) => TripSummary(
    id: row.id,
    startTime: row.startTime,
    endTime: row.endTime,
    durationSeconds: row.durationSeconds,
    distanceMeters: row.distanceMeters,
    direction: row.direction,
    timeMovingSeconds: row.timeMovingSeconds,
    timeStuckSeconds: row.timeStuckSeconds,
    isManualEntry: row.isManualEntry,
  );

  Future<void> _handleEdit(TripRow trip) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => EditTripSheet(summary: _summaryFromRow(trip)),
    );
    if (!context.mounted) return;
    await _loadTrip();
  }

  /// Quick direction change from the trip detail toggle (TRACK-12, D-07).
  ///
  /// Reuses the existing `tripManagementProvider.editTrip` DAO path — the
  /// same atomic updateTrip + enqueueUpdate the edit sheet uses — passing the
  /// trip's existing UTC start/end and the newly-selected direction, then
  /// reloads so the title + toggle reflect the change. No new persistence
  /// path is introduced.
  Future<void> _handleDirectionChanged(
    TripRow trip,
    String newDirection,
  ) async {
    if (newDirection == trip.direction) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(tripManagementProvider.notifier)
        .editTrip(
          tripId: trip.id,
          direction: newDirection,
          startTimeUtc: trip.startTime,
          endTimeUtc: trip.endTime,
        );
    if (!mounted) return;
    final state = ref.read(tripManagementProvider);
    if (state is TripManagementSaved) {
      ref.read(tripManagementProvider.notifier).reset();
      await _loadTrip();
    } else if (state is TripManagementError) {
      ref.read(tripManagementProvider.notifier).reset();
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save the trip. Try again.")),
      );
    }
  }

  Future<void> _handleDelete() async {
    final navigator = Navigator.of(context);
    await trip_actions.handleDeleteTrip(context, ref, widget.tripId);
    if (!context.mounted) return;
    final state = ref.read(tripManagementProvider);
    if (state is TripManagementSaved) {
      navigator.pop();
    }
  }

  void _showOptionsMenu() {
    // Options menu: edit + delete via showModalBottomSheet.
    final trip = _trip;
    if (trip == null) return;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_handleEdit(trip));
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(ctx).extension<TraevyTokensExt>()!.record,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(
                    color: Theme.of(ctx).extension<TraevyTokensExt>()!.record,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_handleDelete());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final trip = _trip;
    if (trip == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Text(
              kTripDetailNotFound,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }
    return _buildLoaded(context, trip);
  }

  Widget _buildLoaded(BuildContext context, TripRow trip) {
    return Scaffold(
      body: SafeArea(
        child: _TripDetailBody(
          trip: trip,
          onBack: () => Navigator.of(context).pop(),
          onOptions: _showOptionsMenu,
          onEdit: () => _handleEdit(trip),
          onDelete: _handleDelete,
          onDirectionChanged: (direction) =>
              _handleDirectionChanged(trip, direction),
        ),
      ),
    );
  }
}

class _TripDetailBody extends StatelessWidget {
  const _TripDetailBody({
    required this.trip,
    required this.onBack,
    required this.onOptions,
    required this.onEdit,
    required this.onDelete,
    required this.onDirectionChanged,
  });

  final TripRow trip;
  final VoidCallback onBack;
  final VoidCallback onOptions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onDirectionChanged;

  String _commutePartOfDay(DateTime startTime) {
    final local = startTime.toLocal();
    return local.hour < kDefaultDirectionCutoffHour
        ? 'Morning commute'
        : 'Evening commute';
  }

  String _directionDisplayName(String direction) {
    if (direction == kDirectionToOffice) return kDirectionToOfficeLabel;
    if (direction == kDirectionToHome) return kDirectionToHomeLabel;
    return 'Trip';
  }

  /// Map the stored direction to a value the [DirectionSegmentedToggle] can
  /// select. Any legacy / unknown value falls back to to-office so the toggle
  /// always renders a valid selection; the user can then pick the correct one.
  String _toggleSelected(String direction) =>
      direction == kDirectionToHome ? kDirectionToHome : kDirectionToOffice;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final localStart = trip.startTime.toLocal();
    final dateLabel = DateFormat('EEE, d MMM').format(localStart);
    final timeLabel = DateFormat('HH:mm').format(localStart);

    final movingMinutes = trip.timeMovingSeconds ~/ 60;
    final stuckMinutes = trip.timeStuckSeconds ~/ 60;
    final totalMinutes = trip.durationSeconds ~/ 60;

    final movingLabel = _formatMinutes(movingMinutes);
    final stuckLabel = _formatMinutes(stuckMinutes);

    final latLngPoints = decodedToLatLng(trip.routePolyline ?? '');
    final isGps = !trip.isManualEntry;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Custom header row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kHorizontalPadding,
              vertical: 12,
            ),
            child: Row(
              children: <Widget>[
                _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                  tokens: tokens,
                ),
                const Spacer(),
                Column(
                  children: <Widget>[
                    Text(
                      dateLabel,
                      style: textTheme.bodyMedium?.copyWith(color: onSurface),
                    ),
                    Text(
                      timeLabel,
                      style: TraevyFonts.mono(
                        size: 12,
                        color: tokens.textDim,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _CircleIconButton(
                  icon: Icons.more_horiz_rounded,
                  onPressed: onOptions,
                  tokens: tokens,
                ),
              ],
            ),
          ),

          // ── Map (GPS trips only) ─────────────────────────────────────────
          if (isGps)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kHorizontalPadding,
              ),
              child: _MapSection(latLngPoints: latLngPoints, tokens: tokens),
            ),

          if (isGps) const SizedBox(height: 20),

          // ── Stats + insight section ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kHorizontalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Commute part-of-day label
                SectionLabel(
                  text: _commutePartOfDay(trip.startTime),
                  fontSize: 11,
                ),
                const SizedBox(height: 4),
                // Direction title
                Text(
                  _directionDisplayName(trip.direction),
                  style: TraevyFonts.ui(
                    size: 24,
                    weight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                // Quick 1-tap direction toggle (TRACK-12, D-07). Writes via
                // the existing editTrip DAO path; the screen reloads on save
                // so this selection reflects the persisted value.
                DirectionSegmentedToggle(
                  selected: _toggleSelected(trip.direction),
                  onSelected: onDirectionChanged,
                ),
                const SizedBox(height: 16),

                // Duration + Distance stat card
                _StatPairCard(
                  durationSeconds: trip.durationSeconds,
                  distanceMeters: trip.distanceMeters,
                  tokens: tokens,
                  onSurface: onSurface,
                ),

                if (isGps) ...<Widget>[
                  const SizedBox(height: 12),
                  // StuckBar
                  StuckBar(
                    movingMinutes: movingMinutes,
                    stuckMinutes: stuckMinutes,
                  ),
                  const SizedBox(height: 8),
                  // Moving / stuck legend row
                  Row(
                    children: <Widget>[
                      _LegendDot(color: tokens.moving),
                      const SizedBox(width: 6),
                      Text(
                        '$movingLabel moving',
                        style: TraevyFonts.mono(
                          size: 12,
                          color: tokens.moving,
                        ),
                      ),
                      const Spacer(),
                      _LegendDot(color: tokens.stuck),
                      const SizedBox(width: 6),
                      Text(
                        '$stuckLabel stuck',
                        style: TraevyFonts.mono(
                          size: 12,
                          color: tokens.stuck,
                        ),
                      ),
                    ],
                  ),

                  if (stuckMinutes > 0) ...<Widget>[
                    const SizedBox(height: 20),
                    TrafficInsightCard(
                      stuckMinutes: stuckMinutes,
                      totalMinutes: totalMinutes,
                    ),
                  ],

                  const SizedBox(height: 24),
                  TripTimeline(
                    startTime: trip.startTime,
                    endTime: trip.endTime,
                    stuckMinutes: stuckMinutes,
                    direction: trip.direction,
                  ),
                ],

                const SizedBox(height: 24),

                // Edit / Delete action buttons
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit'),
                        onPressed: onEdit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Delete'),
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.record,
                          side: BorderSide(color: tokens.record),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

/// Circular icon button used in the custom header.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.tokens,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final TraevyTokensExt tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kHeaderIconSize,
      height: _kHeaderIconSize,
      decoration: BoxDecoration(
        color: tokens.surface2,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

/// Duration + Distance side-by-side card.
class _StatPairCard extends StatelessWidget {
  const _StatPairCard({
    required this.durationSeconds,
    required this.distanceMeters,
    required this.tokens,
    required this.onSurface,
  });

  final int durationSeconds;
  final double distanceMeters;
  final TraevyTokensExt tokens;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.bgElev,
        borderRadius: BorderRadius.circular(_kCardBorderRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatColumn(
              label: 'Duration',
              value: formatDuration(durationSeconds),
              onSurface: onSurface,
            ),
          ),
          Container(width: 1, height: 48, color: tokens.border),
          Expanded(
            child: _StatColumn(
              label: 'Distance',
              value: formatDistance(distanceMeters),
              onSurface: onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.onSurface,
  });

  final String label;
  final String value;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SectionLabel(text: label, fontSize: 11),
        const SizedBox(height: 4),
        Text(
          value,
          style: TraevyFonts.mono(
            size: 28,
            weight: FontWeight.w600,
            color: onSurface,
          ),
        ),
      ],
    );
  }
}

/// Small colored circle used in the moving/stuck legend row.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kLegendDotSize,
      height: _kLegendDotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Map section: real flutter_map TileLayer at 210dp wrapped in RepaintBoundary.
///
/// Review LOW #5 — RepaintBoundary isolates heavy tile rasterization from
/// adjacent state changes in StuckBar / TripTimeline rebuilds.
class _MapSection extends StatelessWidget {
  const _MapSection({required this.latLngPoints, required this.tokens});

  final List<LatLng> latLngPoints;
  final TraevyTokensExt tokens;

  @override
  Widget build(BuildContext context) {
    // Pitfall 2 guard: CameraFit.coordinates asserts on an empty list.
    // Render a placeholder when no decoded points exist (corrupt polyline).
    if (latLngPoints.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kMapBorderRadius),
        child: Container(
          height: _kMapHeight,
          color: tokens.mapBg,
        ),
      );
    }

    // Review LOW #5 — wrap FlutterMap in RepaintBoundary to isolate tile
    // rasterization from adjacent state changes (StuckBar, TripTimeline).
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
