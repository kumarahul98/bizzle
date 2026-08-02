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
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/trips/providers/geofence_backfill_provider.dart';
import 'package:traevy/shared/utils/formatters.dart';
import 'package:traevy/sync/preferences_sync_service.dart';

/// Resolves the device's current position for the picker, or null if it is
/// unavailable (services off or a timeout).
///
/// Injection seam so widget tests can drive the Locate-me control and the
/// initial-centre resolution without touching the geolocator platform
/// channel. Production default ([_defaultCurrentLocation]) reads a fix
/// ASSUMING the caller has already resolved permission — permission is
/// handled separately by [TrackingPermissionService] and is NOT this seam's
/// job.
typedef CurrentLocationResolver = Future<LatLng?> Function();

/// Full-screen map picker for a Home or Office anchor (LOC-01, D-12).
///
/// A fixed centre crosshair sits over a pannable flutter_map; the map slides
/// under the pin. The bottom confirm button reads `mapController.camera.center`
/// ONLY on tap (read-on-confirm — never mid-pan), persists via the matching
/// prefs setter, and pops with a confirmation SnackBar.
///
/// Initial camera (quick 260802-dgp, D-1): the picker REQUESTS
/// `locationWhenInUse` on open when the slot has no saved coord, because
/// landing a location picker on a hardcoded default city is worse than one
/// prompt at the moment the user has clearly asked to pick a location. This
/// supersedes the earlier D-13 "never prompt from the picker" rule for this
/// screen. Background location and notifications are deliberately NOT
/// requested (D-2). Initial camera chain: saved coord for this slot ??
/// device location (after the when-in-use request resolves granted) ??
/// most recent GPS trip's end point ?? a sane non-(0,0) default constant.
/// Declining the request is a legitimate answer and falls through that
/// chain silently (D-3).
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _resolveInitialCenter(),
    );
  }

  Future<void> _resolveInitialCenter() async {
    final prefs = await ref.read(userPreferencesDaoProvider).getOrDefault();
    final savedLat = widget.isHome ? prefs.homeLat : prefs.officeLat;
    final savedLng = widget.isHome ? prefs.homeLng : prefs.officeLng;

    LatLng? center;
    if (savedLat != null && savedLng != null) {
      center = LatLng(savedLat, savedLng);
    } else {
      // D-1: the user opened a location picker — asking for location here is
      // expected, not aggressive. D-2: when-in-use only.
      final status = await ref
          .read(trackingPermissionServiceProvider)
          .requestWhenInUse();
      if (status == LocationWhenInUseStatus.granted) {
        center = await _resolveLocation();
      }
      // D-3: a declined prompt is a legitimate answer — fall through the
      // remaining chain with no error UI.
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

  /// D-4: "Locate me" must never be a silent no-op. Every branch either
  /// moves the map or shows a SnackBar explaining why it can't.
  Future<void> _locateMe() async {
    final service = ref.read(trackingPermissionServiceProvider);
    final status = await service.requestWhenInUse();
    if (!mounted) return;
    switch (status) {
      case LocationWhenInUseStatus.denied:
        _showSnack(kLocationPickerPermissionDeniedMessage);
        return;
      case LocationWhenInUseStatus.permanentlyDenied:
        _showSnack(
          kLocationPickerPermissionBlockedMessage,
          action: SnackBarAction(
            label: kOpenPermissionSettingsLabel,
            onPressed: () => unawaited(service.openSystemSettings()),
          ),
        );
        return;
      case LocationWhenInUseStatus.granted:
        break;
    }
    final fix = await _resolveLocation();
    if (!mounted) return;
    if (fix == null) {
      // Granted but no fix: services off or timeout. Previously this path
      // returned silently, so the FAB looked broken.
      _showSnack(kLocationPickerLocationUnavailableMessage);
      return;
    }
    _mapController.move(fix, kLocationPickerInitialZoom);
  }

  void _showSnack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
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
    // LOC-02: re-label historical trips now that the anchor has changed.
    // The provider is keepAlive, so its cached body will not re-run on a
    // later save without an explicit invalidate; awaiting `.future` after
    // invalidating forces the backfill to actually run (invalidating a
    // never-listened keepAlive provider alone is a no-op). The scan is a
    // bounded local Drift read, so briefly awaiting it on confirm is fine.
    ref.invalidate(geofenceBackfillProvider);
    await ref.read(geofenceBackfillProvider.future);
    // LOC-03: push the new anchor to the cloud so a reinstall restores it.
    // Deliberately NOT awaited — CLAUDE.md forbids blocking the UI on the
    // network, and the push is best-effort by design: it returns false rather
    // than throwing, and the next change or sign-in re-sends the full current
    // value (D-02). Awaiting it would make confirming a pin as slow as the
    // user's connection for no benefit.
    unawaited(ref.read(preferencesSyncServiceProvider).push());
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

  /// Production position resolver: reads a fix assuming the caller has
  /// already resolved permission (permission is the caller's concern, not
  /// this seam's — see [CurrentLocationResolver]). Returns null when
  /// location services are off or the read times out. PII-adjacent — the
  /// returned coordinate is never logged.
  static Future<LatLng?> _defaultCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } on Exception {
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
