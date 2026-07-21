import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';

/// Guards the 2026-07-21 auto-pause change (D-01/D-02).
///
/// Both properties pinned here are the kind that fail SILENTLY in production
/// while looking fine in a fresh-install smoke test, which is exactly why they
/// are asserted rather than trusted.
void main() {
  group('D-02 — the Pause action must not pause directly', () {
    test('the confirm command is distinct from the pause command', () {
      // If these ever collapse to the same string, the notification action
      // would resume pausing silently — the precise behaviour this change
      // removed — and every other test here would still pass.
      expect(kAutoPauseConfirmCommand, isNot(equals(kTrackingPauseCommand)));
    });

    test('the confirm event is distinct from the prompt event', () {
      // kAutoPausePromptEvent = "you have been stationary" (service -> UI).
      // kAutoPauseConfirmEvent = "the user tapped Pause"  (service -> UI).
      // Conflating them would make the mere appearance of the prompt open the
      // confirmation dialog, unprompted, mid-drive.
      expect(kAutoPauseConfirmEvent, isNot(equals(kAutoPausePromptEvent)));
    });

    test('neither name collides with any other channel constant', () {
      final all = <String>[
        kTrackingStateEvent,
        kTripFinalizedEvent,
        kStopTrackingEvent,
        kTrackingPauseCommand,
        kTrackingResumeCommand,
        kTrackingErrorEvent,
        kAutoPausePromptEvent,
        kServiceReadyEvent,
        kSetInitialStateCommand,
        kAutoPauseConfirmCommand,
        kAutoPauseConfirmEvent,
      ];
      expect(
        all.toSet().length,
        all.length,
        reason:
            'fbs routes purely by channel name — a duplicate would '
            'silently deliver one feature\'s events to another',
      );
    });
  });

  group('D-01 — the prompt needs its own channel', () {
    test('the auto-pause channel id differs from the tracking channel id', () {
      // The whole point of the change. Android reads importance from the
      // CHANNEL and a channel is immutable once created, so sharing
      // kTrackingNotificationChannelId (Importance.low) makes a heads-up
      // impossible — and setting importance on the notification would appear
      // to work on a fresh install while doing nothing for existing users.
      expect(
        kAutoPauseChannelId,
        isNot(equals(kTrackingNotificationChannelId)),
      );
    });

    test('the prompt keeps its own notification id, separate from the '
        'ongoing recording notification', () {
      // Sharing the id would make the prompt REPLACE the ongoing foreground
      // notification (Android dedupes on channel+id), taking the Stop button
      // with it.
      expect(kAutoPauseNotificationId, isNot(equals(kTrackingNotificationId)));
    });
  });

  group('D-03 — confirmation copy', () {
    test('dialog strings are non-empty and distinct', () {
      expect(kAutoPauseConfirmTitle, isNotEmpty);
      expect(kAutoPauseConfirmBody, isNotEmpty);
      expect(kAutoPauseConfirmDismissLabel, isNotEmpty);
      expect(kAutoPauseConfirmAcceptLabel, isNotEmpty);
      expect(
        kAutoPauseConfirmDismissLabel,
        isNot(equals(kAutoPauseConfirmAcceptLabel)),
      );
    });

    test('the dismiss label names the safe outcome rather than "Cancel"', () {
      // The trip-preserving choice should read as an action, so a hurried tap
      // is an informed one.
      expect(
        kAutoPauseConfirmDismissLabel.toLowerCase(),
        contains('recording'),
      );
    });

    test('the threshold quoted in the body matches the real constant', () {
      // The copy says "15 minutes". If the threshold is ever retuned, this
      // fails instead of quietly lying to the user.
      final minutes = kAutoPauseStationaryThresholdSeconds ~/ 60;
      expect(kAutoPauseConfirmBody, contains('$minutes minutes'));
    });
  });

  group('2026-07-21 — recording notification ranking', () {
    test('the tracking channel id was bumped away from the legacy id', () {
      // Channel importance is immutable on Android once created. The legacy
      // channel shipped at Importance.low, so raising the recording
      // notification's rank REQUIRED a new id. If these ever become equal
      // again, every existing install silently reverts to the low-importance
      // channel while a fresh install still looks correct — the exact failure
      // mode that motivated the bump.
      expect(
        kTrackingNotificationChannelId,
        isNot(equals(kLegacyTrackingNotificationChannelId)),
      );
    });

    test('the legacy id is retained so it can be deleted', () {
      // Kept ONLY for deleteNotificationChannel. Without the delete, upgrading
      // users see two identically named "Active commute" entries in system
      // settings, one of them dead.
      expect(kLegacyTrackingNotificationChannelId, isNotEmpty);
      expect(kLegacyTrackingNotificationChannelId, 'traevy_active_commute');
    });

    test('all three channel ids are mutually distinct', () {
      final ids = <String>[
        kTrackingNotificationChannelId,
        kAutoPauseChannelId,
        kLegacyTrackingNotificationChannelId,
      ];
      expect(
        ids.toSet().length,
        ids.length,
        reason:
            'a collision would make the delete of the legacy channel tear '
            'down a live one',
      );
    });
  });
}
