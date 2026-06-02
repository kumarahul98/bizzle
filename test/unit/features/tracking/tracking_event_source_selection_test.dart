// Unit tests for [trackingEventSourceProvider] — the D-04 platform selection.
//
// Uses `debugDefaultTargetPlatformOverride` (flutter/foundation) to exercise
// both branches of the provider without a real device or platform channel.
// This is the same seam used by `location_settings_branch_test.dart` for SC#4.
//
// T-14-06 mitigation: no external input can force the wrong engine; the
// selection is by `defaultTargetPlatform`, which is a compile-time constant
// (test-overridable only via `debugDefaultTargetPlatformOverride`). This test
// proves both branches are correctly wired.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/main_isolate_tracking_engine.dart';
import 'package:traevy/features/tracking/services/tracking_event_source.dart';

void main() {
  group('trackingEventSourceProvider — D-04 platform selection', () {
    tearDown(() {
      // Always reset the override so later tests see the real platform.
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      'returns MainIsolateTrackingEngine on iOS (IOS-06/07, D-01)',
      () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final source = container.read(trackingEventSourceProvider);

        expect(
          source,
          isA<MainIsolateTrackingEngine>(),
          reason:
              'iOS must use MainIsolateTrackingEngine '
              '(main-isolate CoreLocation path, D-01)',
        );
      },
    );

    test(
      'returns FbsTrackingEventSource on Android (D-08 regression guard)',
      () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final source = container.read(trackingEventSourceProvider);

        expect(
          source,
          isA<FbsTrackingEventSource>(),
          reason:
              'Android must use FbsTrackingEventSource '
              '(fbs isolate path, D-08)',
        );
      },
    );

    test(
      'iOS and Android branches return distinct instance types (T-14-06)',
      () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final iosContainer = ProviderContainer();
        addTearDown(iosContainer.dispose);
        final iosSource = iosContainer.read(trackingEventSourceProvider);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final androidContainer = ProviderContainer();
        addTearDown(androidContainer.dispose);
        final androidSource = androidContainer.read(
          trackingEventSourceProvider,
        );

        expect(iosSource.runtimeType, isNot(equals(androidSource.runtimeType)));
      },
    );
  });
}
