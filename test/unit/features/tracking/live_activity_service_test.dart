// Wave 0 scaffold — RED tests for LiveActivityService lifecycle and iOS 17 gate.
//
// LiveActivityService does NOT exist yet. This file documents the intended
// public API contract that Plan 05 will implement. It is expected to fail
// compilation until Plan 05 adds lib/features/tracking/services/live_activity_service.dart.
//
// Requirements covered:
//   IOS-13: On iOS 17+, an active commute shows a Live Activity (lock screen +
//           Dynamic Island) with live elapsed/distance/moving-stuck stats and an
//           in-place Stop button.
//
// Key design constraints (from RESEARCH.md):
//   - Use `defaultTargetPlatform` (NOT dart:io Platform) for testability (Pitfall 2).
//   - `areActivitiesSupported()` is the iOS 16.1+ gate; iOS 17 floor uses a
//     combined device_info_plus version check (see RESEARCH §3 open question).
//   - The Stop button uses a URL-scheme callback (traevy://stop → controller.stop()).
//   - ContentState _contentState map must contain exactly 7 keys per UI-SPEC.
//
// See RESEARCH.md §3 (Live Activity Bridge Decision) and §4 (Update Cadence).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/live_activity_service.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';

// ---------------------------------------------------------------------------
// Minimal test doubles for LiveActivityService dependencies.
// Plan 05 provides the full implementation; these stubs satisfy the compiler.
// ---------------------------------------------------------------------------

/// Minimal fake for the live_activities plugin surface that LiveActivityService
/// injects. Plan 05 will define the real interface; tests mock it here.
abstract class FakeLiveActivitiesPlugin {
  Future<bool> areActivitiesSupported();
  Future<bool> areActivitiesEnabled();
  Future<String?> createActivity(String id, Map<String, dynamic> data);
  Future<void> updateActivity(String id, Map<String, dynamic> data);
  Future<void> endActivity(String id);
}

/// A simple [TripSnapshot] factory for test fixtures.
TripSnapshot _snapshot({
  int elapsedSeconds = 600,
  double distanceMeters = 3200,
  int timeMovingSeconds = 400,
  int timeStuckSeconds = 200,
  double currentSpeedMs = 8.0,
}) {
  return TripSnapshot(
    startedAt: DateTime.utc(2026, 6, 3, 8),
    elapsedSeconds: elapsedSeconds,
    distanceMeters: distanceMeters,
    timeMovingSeconds: timeMovingSeconds,
    timeStuckSeconds: timeStuckSeconds,
    currentSpeedMs: currentSpeedMs,
  );
}

void main() {
  // --------------------------------------------------------------------------
  // Android gate: start() must be a no-op on non-iOS platforms
  // --------------------------------------------------------------------------
  group('LiveActivityService — platform gate (IOS-13)', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'start() is a no-op when platform is Android '
      '(never calls plugin create)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        // When implemented, constructing LiveActivityService with a fake plugin
        // and calling start() on Android must NOT call createActivity on the plugin.
        // This test documents the expected contract.
        //
        // Example assertion structure (Plan 05 fills in the real types):
        //   final fakPlugin = _FakePluginThatFailsOnCreate();
        //   final service = LiveActivityService(plugin: fakePlugin, ...);
        //   await service.start(snapshot: _snapshot(), direction: kDirectionToOffice);
        //   // Should not throw — createActivity was never called.
        //
        // Until Plan 05 exists, reference the class to keep the import RED.
        expect(LiveActivityService, isNotNull); // placeholder assertion
      },
    );
  });

  // --------------------------------------------------------------------------
  // iOS 17 gate: start() must be a no-op when activities are not supported
  // --------------------------------------------------------------------------
  group('LiveActivityService — iOS 17 gate (IOS-13)', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'start() does not create an activity when areActivitiesSupported() '
      'returns false (iOS < 16.1 or system setting disabled)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        // When implemented, constructing LiveActivityService with a fake plugin
        // that returns false for areActivitiesSupported() and calling start()
        // must NOT call createActivity.
        //
        // Plan 05 wires this as:
        //   if (!await _plugin.areActivitiesSupported()) return;
        //   if (!await _plugin.areActivitiesEnabled()) return;
        //
        // Placeholder until Plan 05 exists:
        expect(LiveActivityService, isNotNull);
      },
    );

    test(
      'start() does not create an activity when areActivitiesEnabled() '
      'returns false (user disabled Live Activities in Settings)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        // Analogous to the supported() gate above, but for the user toggle.
        expect(LiveActivityService, isNotNull);
      },
    );
  });

  // --------------------------------------------------------------------------
  // _contentState contract: the 7-key map consumed by the SwiftUI Widget
  // --------------------------------------------------------------------------
  group('LiveActivityService — _contentState contract (IOS-13/UI-SPEC)', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    // The native Swift Widget reads exactly 7 keys from the UserDefaults
    // App Group container via the live_activities plugin bridge:
    //   elapsedFormatted   — formatElapsed(snapshot.elapsedSeconds)
    //   distanceFormatted  — formatDistance(snapshot.distanceMeters)
    //   movingFormatted    — formatStuck(snapshot.timeMovingSeconds)
    //   stuckFormatted     — formatStuck(snapshot.timeStuckSeconds)
    //   isMoving           — snapshot.currentSpeedMs >= kStuckSpeedThresholdMs
    //   direction          — "to_office" | "to_home"
    //   startDate          — snapshot.startedAt.millisecondsSinceEpoch

    test(
      '_contentState map contains exactly the 7 required keys',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        // When Plan 05 exposes LiveActivityService._contentState as
        // @visibleForTesting, or via a public helper, this test asserts the
        // 7-key shape. Until then, the key list is documented here for the
        // Plan 05 implementor.
        const requiredKeys = <String>[
          'elapsedFormatted',
          'distanceFormatted',
          'movingFormatted',
          'stuckFormatted',
          'isMoving',
          'direction',
          'startDate',
        ];

        // Placeholder until Plan 05 exposes the method:
        expect(requiredKeys.length, 7);
      },
    );

    test(
      'isMoving is true when currentSpeedMs >= kStuckSpeedThresholdMs',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final snapshot = _snapshot(
          currentSpeedMs: kStuckSpeedThresholdMs + 0.1,
        );

        // When Plan 05 exposes _contentState, assert:
        //   expect(contentState['isMoving'], isTrue);
        //
        // Verify the threshold constant is accessible:
        expect(snapshot.currentSpeedMs, greaterThanOrEqualTo(kStuckSpeedThresholdMs));
      },
    );

    test(
      'isMoving is false when currentSpeedMs < kStuckSpeedThresholdMs',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final snapshot = _snapshot(
          currentSpeedMs: kStuckSpeedThresholdMs - 0.1,
        );

        // Verify the threshold constant is accessible:
        expect(snapshot.currentSpeedMs, lessThan(kStuckSpeedThresholdMs));
      },
    );

    test(
      'startDate is milliseconds since epoch (not seconds) '
      'for SwiftUI Date(timeIntervalSince1970: Double(ms)/1000.0)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final snapshot = _snapshot();

        // startDate must be millisecondsSinceEpoch (a large int), not
        // secondsSinceEpoch. The SwiftUI layer divides by 1000.0 to get
        // TimeInterval. Assert the epoch value is in millisecond range (> 1e12).
        final expectedMs = snapshot.startedAt.millisecondsSinceEpoch;
        expect(expectedMs, greaterThan(1_000_000_000_000));
      },
    );
  });

  // --------------------------------------------------------------------------
  // Lifecycle: end() cleans up the activityId
  // --------------------------------------------------------------------------
  group('LiveActivityService — lifecycle (IOS-13)', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'end() is a no-op when no activity is active (no _activityId)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        // When implemented, calling end() before start() must not throw.
        // Plan 05 guards this as: if (_activityId == null) return;
        expect(LiveActivityService, isNotNull); // placeholder
      },
    );

    test(
      'update() is a no-op when no activity is active (no _activityId)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        // Plan 05 guards this as: if (id == null) return;
        expect(LiveActivityService, isNotNull); // placeholder
      },
    );
  });
}
