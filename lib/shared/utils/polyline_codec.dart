// Google Polyline Encoding Algorithm.
//
// Spec: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
//
// Pure Dart, no Flutter or platform plugin dependencies — safe to call
// from the service isolate, a unit test, or any plain Dart VM.
//
// Encoding is lossy to 1e-5 degrees (~1.1m at the equator) by design; the
// spec rounds coordinates to five decimal places before delta-encoding.

/// Encode a sequence of `(lat, lng)` pairs into a Google Polyline Algorithm
/// string.
///
/// The algorithm multiplies each coordinate by 1e5, rounds to int, then
/// delta-encodes against the previous point using signed-to-unsigned
/// zigzag encoding and a 5-bit-chunk variable-length base-32 scheme offset
/// by 63 to produce printable ASCII.
///
/// Returns an empty string for an empty input list.
///
/// Deterministic and pure — safe to call from any isolate.
String encodePolyline(List<({double lat, double lng})> points) {
  final sb = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;

  for (final p in points) {
    final lat = (p.lat * 1e5).round();
    final lng = (p.lng * 1e5).round();
    _encodeSigned(lat - prevLat, sb);
    _encodeSigned(lng - prevLng, sb);
    prevLat = lat;
    prevLng = lng;
  }
  return sb.toString();
}

/// Decode a Google Polyline Algorithm string back into `(lat, lng)` pairs.
///
/// This is the symmetric inverse of [encodePolyline]. Because encoding is
/// lossy to 1e-5 degrees, decoding round-trips input coordinates within
/// that tolerance, not exactly.
///
/// Used by Phase 4's trip-detail map screen and by the round-trip unit
/// test in Phase 2 plan 02-02. Phase 2 production code only calls
/// [encodePolyline].
///
/// Returns an empty list for an empty input string.
List<({double lat, double lng})> decodePolyline(String encoded) {
  final result = <({double lat, double lng})>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var shift = 0;
    var dLat = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      dLat |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (dLat & 1) != 0 ? ~(dLat >> 1) : dLat >> 1;

    shift = 0;
    var dLng = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      dLng |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (dLng & 1) != 0 ? ~(dLng >> 1) : dLng >> 1;

    result.add((lat: lat / 1e5, lng: lng / 1e5));
  }
  return result;
}

/// Write one signed integer to [sb] using the polyline zigzag + 5-bit-chunk
/// base-32 encoding scheme.
void _encodeSigned(int value, StringBuffer sb) {
  var v = value < 0 ? ~(value << 1) : value << 1;
  while (v >= 0x20) {
    sb.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  sb.writeCharCode(v + 63);
}
