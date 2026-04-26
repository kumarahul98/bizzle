import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';
import 'package:traevy/features/trips/services/trip_actions.dart'
    as trip_actions;
import 'package:traevy/features/trips/widgets/edit_trip_sheet.dart';
import 'package:traevy/shared/utils/formatters.dart';

// Spacing constants — all multiples of 4 per UI-SPEC. Map height is the
// only allowed off-grid value (kTripDetailMapHeight = 256dp).
const double _kBodyPadding = 16;
const double _kManualBadgeGap = 24;
const double _kStatRowVerticalPadding = 8;
const double _kStatRowIconGap = 12;
const double _kStatRowIconSize = 20;
const double _kMapCameraPadding = 32;
const double _kPolylineStrokeWidth = 4;
const double _kManualBadgeIconSize = 16;

/// Trip detail screen (HIST-03).
///
/// Two layouts driven by `TripRow.isManualEntry`:
///   * GPS trip (D-06): scrolling map + 6 stat rows (Duration, Distance,
///     Direction, Date, Moving, Stuck in traffic).
///   * Manual trip (D-05): no map; "Manually entered" chip + 3 stat rows
///     (Duration, Direction, Date). Distance and traffic stats omitted
///     because manual entries have no GPS speed samples.
///
/// Loading state shows a `CircularProgressIndicator`. When `findById`
/// returns null the screen renders [kTripDetailNotFound] instead.
///
/// AppBar carries Edit and Delete icon actions for both layouts. The
/// Delete action calls [trip_actions.handleDeleteTrip] (the shared
/// confirmation flow) and `Navigator.of(context).pop()`s back to the
/// history list on success (Pitfall 8 in 04-RESEARCH.md).
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

  String _directionLabel(String direction) {
    if (direction == kDirectionToOffice) return 'To office';
    if (direction == kDirectionToHome) return 'To home';
    return 'Trip';
  }

  String _directionStatValue(String direction) {
    if (direction == kDirectionToOffice) return 'To office';
    if (direction == kDirectionToHome) return 'To home';
    return 'Unknown';
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
    // After edit, refresh the loaded row so updated fields render.
    await _loadTrip();
  }

  Future<void> _handleDelete() async {
    // Capture Navigator before the await so we can pop without re-touching
    // BuildContext after the async gap (use_build_context_synchronously).
    final navigator = Navigator.of(context);
    await trip_actions.handleDeleteTrip(context, ref, widget.tripId);
    if (!context.mounted) return;
    final state = ref.read(tripManagementProvider);
    if (state is TripManagementSaved) {
      // Pitfall 8: pop back to history only after confirmed delete success.
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final trip = _trip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: Center(
          child: Text(
            kTripDetailNotFound,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return _buildLoaded(context, trip);
  }

  Widget _buildLoaded(BuildContext context, TripRow trip) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _directionLabel(trip.direction);
    final appBar = AppBar(
      title: Text(title),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit trip',
          onPressed: () => _handleEdit(trip),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          tooltip: 'Delete trip',
          onPressed: _handleDelete,
        ),
      ],
    );

    if (trip.isManualEntry) {
      return Scaffold(
        appBar: appBar,
        body: _ManualLayout(
          trip: trip,
          directionStatValue: _directionStatValue(trip.direction),
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: _GpsLayout(
        trip: trip,
        directionStatValue: _directionStatValue(trip.direction),
      ),
    );
  }
}

class _GpsLayout extends StatelessWidget {
  const _GpsLayout({required this.trip, required this.directionStatValue});

  final TripRow trip;
  final String directionStatValue;

  @override
  Widget build(BuildContext context) {
    final latLngPoints = decodedToLatLng(trip.routePolyline ?? '');
    final dateLabel = DateFormat(
      'EEE, d MMM yyyy',
    ).format(trip.startTime.toLocal());
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: SizedBox(
            height: kTripDetailMapHeight,
            child: _MapView(latLngPoints: latLngPoints),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(_kBodyPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _StatRow(
                  icon: Icons.schedule_outlined,
                  label: 'Duration',
                  value: formatDuration(trip.durationSeconds),
                ),
                _StatRow(
                  icon: Icons.straighten_outlined,
                  label: 'Distance',
                  value: formatDistance(trip.distanceMeters),
                ),
                _StatRow(
                  icon: Icons.explore_outlined,
                  label: 'Direction',
                  value: directionStatValue,
                ),
                _StatRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: dateLabel,
                ),
                _StatRow(
                  icon: Icons.timer_outlined,
                  label: 'Moving',
                  value: formatDuration(trip.timeMovingSeconds),
                ),
                _StatRow(
                  icon: Icons.traffic_outlined,
                  label: 'Stuck in traffic',
                  value: formatDuration(trip.timeStuckSeconds),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ManualLayout extends StatelessWidget {
  const _ManualLayout({
    required this.trip,
    required this.directionStatValue,
  });

  final TripRow trip;
  final String directionStatValue;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'EEE, d MMM yyyy',
    ).format(trip.startTime.toLocal());
    return Padding(
      padding: const EdgeInsets.all(_kBodyPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Chip(
            avatar: Icon(
              Icons.edit_note_outlined,
              size: _kManualBadgeIconSize,
            ),
            label: Text(kManualEntryBadge),
          ),
          const SizedBox(height: _kManualBadgeGap),
          _StatRow(
            icon: Icons.schedule_outlined,
            label: 'Duration',
            value: formatDuration(trip.durationSeconds),
          ),
          _StatRow(
            icon: Icons.explore_outlined,
            label: 'Direction',
            value: directionStatValue,
          ),
          _StatRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: dateLabel,
          ),
        ],
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({required this.latLngPoints});

  final List<LatLng> latLngPoints;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Pitfall 2 guard: CameraFit.coordinates asserts on an empty list.
    // Render a neutral placeholder for GPS trips that somehow have no
    // decoded points (corrupt polyline, partial Tracelet capture).
    if (latLngPoints.isEmpty) {
      return Container(
        color: colorScheme.surfaceContainerLow,
        height: kTripDetailMapHeight,
      );
    }
    // IgnorePointer keeps the map from eating CustomScrollView pan/scroll
    // gestures (D-06: detail map is a static preview, not interactive).
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.coordinates(
            coordinates: latLngPoints,
            padding: const EdgeInsets.all(_kMapCameraPadding),
          ),
        ),
        children: <Widget>[
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.traevy.app',
          ),
          PolylineLayer(
            polylines: <Polyline>[
              Polyline(
                points: latLngPoints,
                color: colorScheme.primary,
                strokeWidth: _kPolylineStrokeWidth,
              ),
            ],
          ),
          const RichAttributionWidget(
            attributions: <SourceAttribution>[
              TextSourceAttribution('OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _kStatRowVerticalPadding),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: _kStatRowIconSize,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: _kStatRowIconGap),
          Expanded(child: Text(label, style: textTheme.labelLarge)),
          Text(value, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
