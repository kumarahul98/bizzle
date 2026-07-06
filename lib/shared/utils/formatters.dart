import 'package:latlong2/latlong.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

/// Format a duration in seconds to a human-readable string.
///
/// Under 60 minutes: 'N min'. 60 minutes or more: 'NhNNmin'.
String formatDuration(int seconds) {
  if (seconds < 3600) {
    return '${seconds ~/ 60} min';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
}

/// Format a distance in meters to a kilometres string with one decimal place.
///
/// Example: 12400 → '12.4 km'.
String formatDistance(double meters) {
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Format elapsed trip seconds for live tracking surfaces (notification,
/// Live Activity). Outputs [MM:SS] under 1 hour, [H:MM:SS] at/above 1 hour.
///
/// Distinct from [formatDuration] (which outputs 'N min') — use
/// [formatElapsed] only for active-tracking displays (IOS-13, IOS-14).
String formatElapsed(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h == 0) return '$mm:$ss';
  return '$h:$mm:$ss';
}

/// Compact stuck-time formatter for live tracking surfaces. Outputs the
/// shortest readable form: [Xm] under one hour, [XhYm] over (or [Xh] on
/// the hour).
///
/// Extracted from [TrackingNotificationService._formatStuck] so the Android
/// notification and the Live Activity bridge share one implementation.
String formatStuck(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remMinutes = minutes % 60;
  return remMinutes == 0 ? '${hours}h' : '${hours}h${remMinutes}m';
}

/// Convert the output of [decodePolyline] to a list of [LatLng] points
/// suitable for `flutter_map`'s `PolylineLayer`.
///
/// Returns an empty list if [encoded] is empty — guards Pitfall 2 in
/// RESEARCH.md (CameraFit.coordinates crash on empty list).
List<LatLng> decodedToLatLng(String encoded) =>
    decodePolyline(encoded).map((p) => LatLng(p.lat, p.lng)).toList();
