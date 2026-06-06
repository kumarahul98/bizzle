import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/widgets/location_picker_confirm_bar.dart';
import 'package:traevy/features/settings/widgets/location_picker_crosshair.dart';
import 'package:traevy/shared/utils/formatters.dart';

/// Resolves the device's current location for the picker, or null if it is
/// unavailable (permission not already granted, services off, or timeout).
///
/// Injection seam so widget tests can drive the Locate-me control and the
/// D-13 init fallback without touching the geolocator platform channel.
/// Production default ([_defaultCurrentLocation]) checks permission WITHOUT
/// prompting (D-13: do not aggressively prompt) and only then reads a fix.
typedef CurrentLocationResolver = Future<LatLng?> Function();

/// Full-screen map picker for a Home or Office anchor (LOC-01, D-12, D-13).
///
/// A fixed centre crosshair sits over a pannable flutter_map; the map slides
/// under the pin. The bottom confirm button reads `mapController.camera.center`
/// ONLY on tap (read-on-confirm — never mid-pan), persists via the matching
/// prefs setter, and pops with a confirmation SnackBar.
///
/// Initial camera (D-13): saved coord for this slot ?? device location (if
/// permission already granted) ?? most recent GPS trip's end point ?? a sane
/// non-(0,0) default constant.
///
/// PII note (T-21-02-01): the chosen coordinate is written to local Drift only
/// and is NEVER logged.
class LocationPickerScreen extends ConsumerStatefulWidget {
  /// Create a picker for the Home ([isHome] true) or Office slot.
  ///
  /// [currentLocation] overrides the device-location seam in tests.
  const LocationPickerScreen({
    required this.isHome,
    this.currentLocation,
    super.key,
  });

  /// True → edits the Home anchor; false → the Office anchor.
  final bool isHome;

  /// Optional override for the device-location resolver (tests only).
  final CurrentLocationResolver? currentLocation;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _initialCenter;
  bool _resolving = true;

  CurrentLocationResolver get _resolveLocation =>
      widget.currentLocation ?? _defaultCurrentLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveInitialCenter());
  }

  Future<void> _resolveInitialCenter() async {
    final prefs = await ref.read(userPreferencesDaoProvider).getOrDefault();
    final savedLat = widget.isHome ? prefs.homeLat : prefs.officeLat;
    final savedLng = widget.isHome ? prefs.homeLng : prefs.officeLng;

    LatLng? center;
    if (savedLat != null && savedLng != null) {
      center = LatLng(savedLat, savedLng);
    } else {
      center = await _resolveLocation();
      center ??= await _mostRecentTripEnd();
    }
    center ??= const LatLng(kMapDefaultCenterLat, kMapDefaultCenterLng);

    if (!mounted) return;
    setState(() {
      _initialCenter = center;
      _resolving = false;
    });
  }

  Future<LatLng?> _mostRecentTripEnd() async {
    final trip = await ref.read(tripsDaoProvider).mostRecentGpsTrip();
    final points = decodedToLatLng(trip?.routePolyline ?? '');
    return points.isEmpty ? null : points.last;
  }

  Future<void> _locateMe() async {
    final fix = await _resolveLocation();
    if (fix == null || !mounted) return;
    _mapController.move(fix, kLocationPickerInitialZoom);
  }

  Future<void> _confirm() async {
    // D-12: read the centre ONLY here, on confirm — never on map move.
    final center = _mapController.camera.center;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dao = ref.read(userPreferencesDaoProvider);
    if (widget.isHome) {
      await dao.setHomeLocation(center.latitude, center.longitude);
    } else {
      await dao.setOfficeLocation(center.latitude, center.longitude);
    }
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.isHome
              ? kLocationPickerHomeSavedSnack
              : kLocationPickerOfficeSavedSnack,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isHome
        ? kLocationPickerHomeTitle
        : kLocationPickerOfficeTitle;
    final buttonLabel = widget.isHome
        ? kLocationPickerSetHomeButton
        : kLocationPickerSetOfficeButton;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _resolving || _initialCenter == null
          ? const Center(child: CircularProgressIndicator())
          : _PickerMap(
              mapController: _mapController,
              initialCenter: _initialCenter!,
              onLocateMe: _locateMe,
            ),
      bottomNavigationBar: _resolving
          ? null
          : LocationPickerConfirmBar(label: buttonLabel, onConfirm: _confirm),
    );
  }

  /// Production location resolver: read a fix only when permission is ALREADY
  /// granted (D-13 — never prompt from the picker). PII-adjacent — never log
  /// the returned coordinate.
  static Future<LatLng?> _defaultCurrentLocation() async {
    final permission = await Geolocator.checkPermission();
    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!granted) return null;
    try {
      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } on Exception {
      // Services off / timeout — fall back to the next D-13 source silently.
      return null;
    }
  }
}

/// The map layer of the picker: tiles + fixed crosshair + Locate-me FAB.
class _PickerMap extends StatelessWidget {
  const _PickerMap({
    required this.mapController,
    required this.initialCenter,
    required this.onLocateMe,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final VoidCallback onLocateMe;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: kLocationPickerInitialZoom,
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: isDark ? kMapTileUrlDark : kMapTileUrlLight,
              subdomains: kMapTileSubdomains,
              userAgentPackageName: kMapUserAgentPackageName,
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
        const LocationPickerCrosshair(),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'locationPickerLocateMe',
            onPressed: onLocateMe,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }
}
