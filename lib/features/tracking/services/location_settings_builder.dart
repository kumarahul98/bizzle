// Single source-of-truth for the SC#4 platform LocationSettings branch.
//
// This is the ONLY place in the codebase that branches on
// `defaultTargetPlatform` to select between `AppleSettings` (iOS) and
// `AndroidSettings` (Android). Keeping the branch here — rather than inline
// in tracking_service.dart or the iOS engine — lets unit tests override
// `debugDefaultTargetPlatformOverride` to exercise both paths without a
// real device.
//
// PII guard (T-02-07): this helper takes NO `Position` argument and produces
// only a `LocationSettings` configuration object. It MUST NEVER log, return,
// or forward a `Position`. Raw lat/lng is PII; only the encoded polyline
// egresses via `FinalizedTrip`.

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';

/// Returns the correct [LocationSettings] for the current platform.
///
/// - **iOS:** returns an [AppleSettings] with the four locked IOS-06/07
///   parameters (high accuracy, background updates enabled, auto-pause
///   disabled, automotive navigation activity type) plus the iOS-specific
///   `distanceFilter` and background location indicator flag.
/// - **Android:** returns the existing [AndroidSettings] (high accuracy,
///   3-second interval) unchanged — no behavioural regression (D-08).
///
/// Selection uses [defaultTargetPlatform] (not `dart:io Platform.isIOS`) so
/// the branch is exercisable in unit tests via
/// `debugDefaultTargetPlatformOverride` (RESEARCH §3, SC#4).
///
/// See D-02 in `.planning/phases/14-background-gps-platform-branch/14-CONTEXT.md`.
LocationSettings buildLocationSettings() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    // Locked AppleSettings per SC#4 / D-02 / IOS-06 / IOS-07:
    //   - accuracy: high      — precise GPS required for speed calculations
    //   - allowBackgroundLocationUpdates: true — keep stream alive when screen
    //     is off (CoreLocation + UIBackgroundModes:location, IOS-06)
    //   - pauseLocationUpdatesAutomatically: false — IOS-07 guarantee;
    //     CoreLocation must NOT auto-pause in stop-and-go (near-zero speed)
    //   - activityType: automotiveNavigation — hints CoreLocation to optimise
    //     for vehicle tracking; reduces false auto-pause triggers
    //   - showBackgroundLocationIndicator: true — shows the system blue pill
    //     when the app is backgrounded (D-07; Phase 15 owns the full "Always"
    //     two-step upgrade)
    //   - distanceFilter: kIosTrackingDistanceFilterMeters (0) — cadence is
    //     driven by pauseLocationUpdatesAutomatically:false + high accuracy;
    //     distanceFilter 0 ensures stop-and-go traffic still emits samples
    //     (RESEARCH §2 / IOS-07)
    // SC#4 locked AppleSettings. The full set of intended values:
    //   allowBackgroundLocationUpdates: true (default — IOS-06)
    //   pauseLocationUpdatesAutomatically: false (default — IOS-07)
    //   distanceFilter: 0 / kIosTrackingDistanceFilterMeters (default — IOS-07)
    //   accuracy: high (non-default — required)
    //   activityType: automotiveNavigation (non-default — D-02)
    //   showBackgroundLocationIndicator: true (non-default — D-07)
    // Params matching the LocationSettings/AppleSettings defaults are omitted
    // to satisfy very_good_analysis avoid_redundant_argument_values; the
    // dartdoc on buildLocationSettings() records the intended values.
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.automotiveNavigation,
      showBackgroundLocationIndicator: true,
    );
  }

  // Android: reproduce the existing AndroidSettings from tracking_service.dart
  // byte-for-byte so this branch is a transparent extraction, not a behaviour
  // change (D-08 regression guard).
  return AndroidSettings(
    accuracy: LocationAccuracy.high,
    intervalDuration: kTrackingSampleInterval,
  );
}
