// Unit tests for [buildLocationSettings] — the SC#4 platform branch.
//
// These tests assert the full locked [AppleSettings] configuration under
// `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` and the existing
// [AndroidSettings] configuration under `TargetPlatform.android`.
//
// Using `debugDefaultTargetPlatformOverride` (flutter/foundation) as the seam
// ensures the branch is exercisable without a real device or a platform
// channel (RESEARCH §3, PLAN phase_constraints).
//
// All four locked AppleSettings params are asserted individually:
//   pauseLocationUpdatesAutomatically, allowBackgroundLocationUpdates,
//   activityType, accuracy (IOS-06 / IOS-07 / D-02 / SC#4).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/location_settings_builder.dart';

void main() {
  group('buildLocationSettings() — SC#4 platform branch', () {
    tearDown(() {
      // Always reset the override so later tests see the real platform.
      debugDefaultTargetPlatformOverride = null;
    });

    group('iOS path (TargetPlatform.iOS)', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      });

      test('returns AppleSettings (not AndroidSettings)', () {
        final settings = buildLocationSettings();
        expect(settings, isA<AppleSettings>());
      });

      test('pauseLocationUpdatesAutomatically is false (IOS-07)', () {
        final settings = buildLocationSettings() as AppleSettings;
        expect(settings.pauseLocationUpdatesAutomatically, isFalse);
      });

      test('allowBackgroundLocationUpdates is true (IOS-06)', () {
        final settings = buildLocationSettings() as AppleSettings;
        expect(settings.allowBackgroundLocationUpdates, isTrue);
      });

      test(
        'activityType is automotiveNavigation (D-02)',
        () {
          final settings = buildLocationSettings() as AppleSettings;
          expect(settings.activityType, ActivityType.automotiveNavigation);
        },
      );

      test('accuracy is high (IOS-06)', () {
        final settings = buildLocationSettings() as AppleSettings;
        expect(settings.accuracy, LocationAccuracy.high);
      });

      test('showBackgroundLocationIndicator is true (D-07)', () {
        final settings = buildLocationSettings() as AppleSettings;
        expect(settings.showBackgroundLocationIndicator, isTrue);
      });

      test(
        'distanceFilter equals kIosTrackingDistanceFilterMeters (IOS-07)',
        () {
          final settings = buildLocationSettings() as AppleSettings;
          expect(
            settings.distanceFilter,
            kIosTrackingDistanceFilterMeters,
          );
        },
      );

      test(
        'all four locked params correct in a single call (SC#4 contract)',
        () {
          final settings = buildLocationSettings() as AppleSettings;

          // IOS-07: no auto-pause in stop-and-go traffic
          expect(
            settings.pauseLocationUpdatesAutomatically,
            isFalse,
            reason: 'pauseLocationUpdatesAutomatically must be false (IOS-07)',
          );
          // IOS-06: background updates keep stream alive
          expect(
            settings.allowBackgroundLocationUpdates,
            isTrue,
            reason: 'allowBackgroundLocationUpdates must be true (IOS-06)',
          );
          // D-02: automotive navigation activity type
          expect(
            settings.activityType,
            ActivityType.automotiveNavigation,
            reason: 'activityType must be automotiveNavigation (D-02)',
          );
          // IOS-06: precise accuracy for speed stats
          expect(
            settings.accuracy,
            LocationAccuracy.high,
            reason: 'accuracy must be high (IOS-06)',
          );
        },
      );
    });

    group('Android path (TargetPlatform.android)', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
      });

      test('returns AndroidSettings (not AppleSettings)', () {
        final settings = buildLocationSettings();
        expect(settings, isA<AndroidSettings>());
      });

      test('accuracy is high', () {
        final settings = buildLocationSettings() as AndroidSettings;
        expect(settings.accuracy, LocationAccuracy.high);
      });

      test(
        'intervalDuration equals kTrackingSampleInterval (D-08 regression)',
        () {
          final settings = buildLocationSettings() as AndroidSettings;
          expect(settings.intervalDuration, kTrackingSampleInterval);
        },
      );
    });
  });
}
