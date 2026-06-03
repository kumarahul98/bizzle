// IOS-08 reduced-accuracy gate for the iOS tracking path.
//
// At trip start on iOS, CoreLocation may be in "Approximate Location" mode
// (LocationAccuracyStatus.reduced). Recording commutes in reduced mode would
// produce garbage speed stats — speeds derived from coarse 500-metre fixes are
// unreliable for the moving/stuck classification (RESEARCH §4, D-05, IOS-08).
//
// This gate runs BEFORE the geolocator stream opens:
//   1. Read current accuracy status.
//   2. If reduced, request temporary full accuracy with
//      kPreciseCommutePurposeKey.
//   3. If accuracy is still reduced after the prompt (user declined), BLOCK
//      recording — return false. Never start the stream with coarse fixes.
//
// The gate wraps Geolocator via injectable function parameters so unit tests
// can drive all three outcomes (blocked, proceed-after-request, proceed-direct)
// without a real device.

import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';

/// Injectable function type for getting the current location accuracy status.
typedef GetLocationAccuracyFn =
    Future<LocationAccuracyStatus> Function();

/// Injectable function type for requesting temporary full accuracy.
typedef RequestTemporaryFullAccuracyFn =
    Future<LocationAccuracyStatus> Function({required String purposeKey});

/// IOS-08 reduced-accuracy preflight gate.
///
/// Wraps `Geolocator.getLocationAccuracy` and
/// `Geolocator.requestTemporaryFullAccuracy` via injectable function
/// parameters so the gate is unit-testable without real CoreLocation APIs.
///
/// Production code constructs with no arguments to use the real Geolocator:
/// ```dart
/// final gate = LocationAccuracyGate();
/// final ok = await gate.ensurePrecise();
/// ```
///
/// Unit tests inject mock functions:
/// ```dart
/// final gate = LocationAccuracyGate(
///   getLocationAccuracy: () async => LocationAccuracyStatus.reduced,
///   requestTemporaryFullAccuracy: ({required purposeKey}) async =>
///       LocationAccuracyStatus.precise,
/// );
/// ```
final class LocationAccuracyGate {
  /// Create the gate with optionally injected accuracy functions.
  ///
  /// Defaults delegate to the real [Geolocator] static methods.
  LocationAccuracyGate({
    GetLocationAccuracyFn? getLocationAccuracy,
    RequestTemporaryFullAccuracyFn? requestTemporaryFullAccuracy,
  }) : _getLocationAccuracy =
           getLocationAccuracy ?? Geolocator.getLocationAccuracy,
       _requestTemporaryFullAccuracy =
           requestTemporaryFullAccuracy ??
           Geolocator.requestTemporaryFullAccuracy;

  final GetLocationAccuracyFn _getLocationAccuracy;
  final RequestTemporaryFullAccuracyFn _requestTemporaryFullAccuracy;

  /// Ensure full (precise) location accuracy is available before recording.
  ///
  /// Returns `true` if precise accuracy is available (safe to start recording).
  /// Returns `false` if accuracy is still reduced after the user declined the
  /// temporary-full-accuracy prompt — callers MUST NOT start the GPS stream.
  ///
  /// Three outcomes:
  ///   - Already precise → returns `true` immediately (no prompt shown).
  ///   - Reduced → request → precise → returns `true`.
  ///   - Reduced → request → still reduced (user declined) → returns `false`.
  ///
  /// The purposeKey [kPreciseCommutePurposeKey] MUST match the key under
  /// `NSLocationTemporaryUsageDescriptionDictionary` in `Info.plist` exactly
  /// (D-06). If it differs, iOS silently ignores the request.
  Future<bool> ensurePrecise() async {
    var status = await _getLocationAccuracy();
    if (status == LocationAccuracyStatus.precise) {
      return true;
    }
    // Accuracy is reduced — prompt the user for temporary full accuracy.
    status = await _requestTemporaryFullAccuracy(
      purposeKey: kPreciseCommutePurposeKey,
    );
    return status == LocationAccuracyStatus.precise;
  }
}
