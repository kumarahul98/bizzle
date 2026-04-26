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

/// Convert the output of [decodePolyline] to a list of [LatLng] points
/// suitable for `flutter_map`'s `PolylineLayer`.
///
/// Returns an empty list if [encoded] is empty — guards Pitfall 2 in
/// RESEARCH.md (CameraFit.coordinates crash on empty list).
List<LatLng> decodedToLatLng(String encoded) =>
    decodePolyline(encoded).map((p) => LatLng(p.lat, p.lng)).toList();
