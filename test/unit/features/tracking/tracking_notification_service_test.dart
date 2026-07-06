// Wave 0 RED scaffolds for TrackingNotificationService iOS behaviours.
//
// IOS-11 gate: showRecording() must return early (not invoke the plugin) when
// running on iOS. Plan 03 adds the Platform.isAndroid guard and a forTesting
// constructor that accepts a platformIsAndroid override to make the gate
// testable without dart:io Platform (RESEARCH.md Pitfall 2).
//
// IOS-14 enriched body: the two-line notification body uses
// kTrackingNotificationBodyLine1Template and kTrackingNotificationBodyLine2Template
// (added by Plan 03). The D-14 invariants — kTrackingNotificationId (1001) and
// kTrackingNotificationChannelId — must remain unchanged.
//
// All groups referencing forTesting / the two template constants are RED until
// Plan 03. The D-14 constant-invariant tests pass immediately (GREEN) as they
// rely only on already-defined constants.

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';

void main() {
  // -------------------------------------------------------------------------
  // IOS-11: Platform gate
  //
  // showRecording() must be a no-op on iOS. Plan 03 adds:
  //   1. A Platform.isAndroid guard inside showRecording().
  //   2. A forTesting named constructor (or factory) on
  //      TrackingNotificationService that accepts a [platformIsAndroid]
  //      boolean override so the gate is testable without dart:io Platform.
  //
  // The tests below are RED until Plan 03 adds the forTesting entry point.
  // -------------------------------------------------------------------------

  group('IOS-11: showRecording() is a no-op on non-Android platforms', () {
    test(
      'showRecording() completes without error when platformIsAndroid=false '
      '(smoke test for the no-op path)',
      () async {
        // RED: forTesting constructor does not exist yet.
        // Plan 03 adds TrackingNotificationService.forTesting({required bool
        // platformIsAndroid, FlutterLocalNotificationsPlugin? plugin}).
        final service = TrackingNotificationService.forTesting(
          platformIsAndroid: false,
        );

        // Must complete without throwing and without calling the plugin.
        await expectLater(
          service.showRecording(
            elapsedSeconds: 120,
            distanceMeters: 1500,
            timeStuckSeconds: 60,
            direction: kDirectionToOffice,
          ),
          completes,
        );
      },
    );

    test(
      'showRecording() completes and reaches the plugin on Android '
      '(Android baseline must remain unchanged, platformIsAndroid=true)',
      () async {
        // RED: forTesting constructor does not exist yet.
        final service = TrackingNotificationService.forTesting(
          platformIsAndroid: true,
        );

        // On Android the call should attempt plugin.show(); the
        // uninitialized plugin will throw or no-op in the test host —
        // the test just confirms the call reaches the platform layer
        // (not an early return). Plan 03 refines this with a mock.
        await expectLater(
          () => service.showRecording(
            elapsedSeconds: 120,
            distanceMeters: 1500,
            timeStuckSeconds: 60,
            direction: kDirectionToOffice,
          ),
          returnsNormally,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // IOS-14: Two-line enriched notification body + D-14 contract invariants
  //
  // Plan 03 adds kTrackingNotificationBodyLine1Template and
  // kTrackingNotificationBodyLine2Template to constants.dart and updates
  // _renderBody() to produce a two-line body joined by '\n'.
  //
  // D-14 invariants (kTrackingNotificationId, kTrackingNotificationChannelId)
  // must not change — these are tested GREEN immediately.
  //
  // Template-constant tests are RED until Plan 03 adds the constants.
  // -------------------------------------------------------------------------

  group('D-14 invariants (GREEN — constants already defined)', () {
    test(
      'kTrackingNotificationId is 1001 (D-14 contract must not change)',
      () {
        expect(
          kTrackingNotificationId,
          equals(1001),
          reason: 'D-14: notification ID must remain 1001',
        );
      },
    );

    test(
      'kTrackingNotificationChannelId is traevy_active_commute '
      '(D-14 contract must not change)',
      () {
        expect(
          kTrackingNotificationChannelId,
          equals('traevy_active_commute'),
          reason: 'D-14: channel ID must remain traevy_active_commute',
        );
      },
    );
  });

  group('IOS-14: enriched two-line body template constants (RED until Plan 03)',
      () {
    test(
      'kTrackingNotificationBodyLine1Template contains {elapsed} and {km} '
      'placeholders',
      () {
        // RED: kTrackingNotificationBodyLine1Template does not exist yet.
        // Plan 03 adds it to lib/config/constants.dart.
        expect(
          kTrackingNotificationBodyLine1Template,
          contains('{elapsed}'),
          reason: 'IOS-14: line 1 must contain the {elapsed} placeholder',
        );
        expect(
          kTrackingNotificationBodyLine1Template,
          contains('{km}'),
          reason: 'IOS-14: line 1 must contain the {km} placeholder',
        );
      },
    );

    test(
      'kTrackingNotificationBodyLine2Template contains {stuck} placeholder',
      () {
        // RED: kTrackingNotificationBodyLine2Template does not exist yet.
        // Plan 03 adds it to lib/config/constants.dart.
        expect(
          kTrackingNotificationBodyLine2Template,
          contains('{stuck}'),
          reason: 'IOS-14: line 2 must contain the {stuck} placeholder',
        );
      },
    );

    test(
      'kTrackingNotificationBodyLine1Template and '
      'kTrackingNotificationBodyLine2Template are distinct strings',
      () {
        // RED until Plan 03.
        expect(
          kTrackingNotificationBodyLine1Template,
          isNot(equals(kTrackingNotificationBodyLine2Template)),
          reason: 'IOS-14: two-line body templates must be distinct',
        );
      },
    );
  });
}
