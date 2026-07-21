import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';

/// Guards Phase 36 D-04 — the notification's Stop action relaying a
/// confirmation instead of ending the trip silently.
///
/// The properties pinned here are the kind that fail SILENTLY in production
/// while a fresh-install smoke test still looks fine, which is why they are
/// asserted rather than trusted.
void main() {
  group('D-04 — the Stop action must not stop directly', () {
    test('the confirm command is distinct from the stop event', () {
      // If these ever collapse to the same string, the notification action
      // resumes ending trips with no confirmation — the precise behaviour this
      // change removed — and every other test here would still pass.
      expect(kStopConfirmCommand, isNot(equals(kStopTrackingEvent)));
    });

    test('the confirm event is distinct from the confirm command', () {
      // Command is notification-handler -> service; event is service -> UI.
      // Conflating them would make the service relay to itself.
      expect(kStopConfirmEvent, isNot(equals(kStopConfirmCommand)));
    });

    test('the stop relay is distinct from the auto-pause relay', () {
      // Both are "notification action -> confirm dialog" relays with the same
      // shape. Sharing a channel name would have a Stop tap open the pause
      // dialog, or worse.
      expect(kStopConfirmCommand, isNot(equals(kAutoPauseConfirmCommand)));
      expect(kStopConfirmEvent, isNot(equals(kAutoPauseConfirmEvent)));
    });

    test('no channel constant collides with any other', () {
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
        kStopConfirmCommand,
        kStopConfirmEvent,
        kStopConfirmAckCommand,
      ];
      expect(
        all.toSet().length,
        all.length,
        reason:
            'fbs routes purely by channel name — a duplicate would silently '
            "deliver one feature's events to another",
      );
    });
  });

  group('T-02-17 — exact action-id matching, no near-misses', () {
    // The handlers match `response.actionId == kTrackingStopActionId`. This
    // pins the property that matching is EXACT: loosening it to a prefix or
    // `contains` check would let a stale or forged id end a live trip (T-36-04).
    NotificationResponse responseWith(String? actionId) => NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: actionId,
    );

    /// The exact predicate both handlers apply.
    bool routesToStopConfirm(NotificationResponse r) =>
        r.actionId == kTrackingStopActionId;

    test('the real stop action id routes', () {
      expect(routesToStopConfirm(responseWith(kTrackingStopActionId)), isTrue);
    });

    test('near-miss ids do not route', () {
      final nearMisses = <String?>[
        null,
        '',
        '${kTrackingStopActionId}_',
        '_$kTrackingStopActionId',
        kTrackingStopActionId.toUpperCase(),
        ' $kTrackingStopActionId',
        '$kTrackingStopActionId ',
        kTrackingOpenActionId,
        kTrackingAutoPauseActionId,
      ];
      for (final id in nearMisses) {
        expect(
          routesToStopConfirm(responseWith(id)),
          isFalse,
          reason: 'actionId "$id" must not end a trip',
        );
      }
    });

    test('the stop action id is distinct from every sibling action id', () {
      final ids = <String>[
        kTrackingStopActionId,
        kTrackingOpenActionId,
        kTrackingAutoPauseActionId,
      ];
      expect(ids.toSet().length, ids.length);
    });
  });

  group('T-36-06 — the direct-stop fallback', () {
    test('the ack command is its own channel, distinct from the relay', () {
      // The ack travels UI -> service, opposite the event. Sharing a name with
      // kStopConfirmEvent would have the service ack itself the instant it
      // relayed, permanently disabling the fallback.
      expect(kStopConfirmAckCommand, isNot(equals(kStopConfirmEvent)));
      expect(kStopConfirmAckCommand, isNot(equals(kStopConfirmCommand)));
    });

    test('the ack timeout is a positive, bounded number of seconds', () {
      // Zero or negative would fire the fallback before any isolate could
      // possibly answer, turning every notification Stop into an unconfirmed
      // stop — inverting the whole point of D-04.
      expect(kStopConfirmAckTimeoutSeconds, greaterThan(0));
      // An unbounded wait is the other failure: the user taps Stop, no UI
      // answers, and nothing ever stops the trip. That is the loss T-36-06
      // exists to prevent.
      expect(kStopConfirmAckTimeoutSeconds, lessThanOrEqualTo(30));
    });

    test(
      'the timeout outlasts a cold Activity start but stays under the '
      'point a user would give up',
      () {
        // Stop carries showsUserInterface: true, so the Activity is starting
        // while the timer runs. Too short and a slow cold start stops the trip
        // without ever showing the dialog it was about to show.
        expect(kStopConfirmAckTimeoutSeconds, greaterThanOrEqualTo(3));
        expect(kStopConfirmAckTimeoutSeconds, lessThanOrEqualTo(10));
      },
    );
  });

  group('D-04 — confirmation copy', () {
    test('dialog strings are non-empty and the two buttons differ', () {
      expect(kStopConfirmTitle, isNotEmpty);
      expect(kStopConfirmBody, isNotEmpty);
      expect(kStopConfirmDismissLabel, isNotEmpty);
      expect(kStopConfirmAcceptLabel, isNotEmpty);
      expect(kStopConfirmDismissLabel, isNot(equals(kStopConfirmAcceptLabel)));
    });

    test('the dismiss label names the safe outcome rather than "Cancel"', () {
      // The trip-preserving choice should read as an action, matching the
      // auto-pause dialog's wording convention, so a hurried tap is an
      // informed one.
      expect(kStopConfirmDismissLabel.toLowerCase(), contains('recording'));
    });

    test('the accept label says what actually happens to the trip', () {
      // Stopping SAVES the trip. A bare "Stop" reads as discard, which is the
      // opposite of the behaviour.
      expect(kStopConfirmAcceptLabel.toLowerCase(), contains('save'));
    });

    test('the stop dialog is worded distinctly from the auto-pause one', () {
      expect(kStopConfirmTitle, isNot(equals(kAutoPauseConfirmTitle)));
      expect(kStopConfirmBody, isNot(equals(kAutoPauseConfirmBody)));
    });
  });
}
