# Auto-pause notification update — handoff brief

**Repo:** `traevy` (Flutter/Android commute tracker) · **Commit:** `318b005` on `main`
**Status:** Code complete, tests green, **not verified on a device**

---

## What the feature is

While a commute is recording, if the user stays stationary for 15 minutes the
app posts a notification asking whether to pause the trip. Paused time is
excluded from their stats. It is opt-in (`autoPauseEnabled` in Settings) and
defaults ON.

## What changed on 2026-07-21

Two user-requested changes.

### 1. The prompt is now a heads-up notification

It previously appeared silently in the notification shade, below the ongoing
"recording" notification, and was easy to miss. It now pops over the screen and
sorts above the recording notification.

**The non-obvious part — read before touching this.** The prompt used to share
`kTrackingNotificationChannelId` with the ongoing recording notification, which
is created at `Importance.low`. On Android 8+ importance is a property of the
**channel**, not the notification, and **a channel's importance cannot be
changed after it is created.**

So the obvious fix — setting `importance: Importance.high` in
`AndroidNotificationDetails` — does nothing for anyone who already has the app
installed. It works on a fresh install (channel created for the first time) and
silently fails for every existing user. That failure mode is why the prompt got
its own channel, `kAutoPauseChannelId`, at `Importance.high`.

The tracking channel stays `low` deliberately: its notification refreshes every
~5 seconds during a trip and would buzz continuously at any higher importance.

Side benefit: the two channels appear separately in Android's per-app
notification settings, so a user can silence the prompt without silencing the
recording notification.

### 2. Tapping "Pause" now asks before pausing

It previously paused the trip immediately and silently — no confirmation, no
feedback that anything had happened. It now opens the app and shows a dialog:

> **Still stopped?**
> You've been stationary for 15 minutes. Pause this trip? Time paused is
> excluded from your stats.
> `[ Keep recording ]` `[ Pause ]`

This matches the existing home-screen widget's Pause button, so both entry
points behave identically.

**How the routing works.** The notification tap can arrive on either of two
handlers: `_onForegroundResponse` (app in foreground, UI isolate) or
`trackingNotificationBackgroundHandler` (app backgrounded, its own isolate that
cannot reach the UI). Rather than two mechanisms, both invoke
`kAutoPauseConfirmCommand` to the `flutter_background_service` isolate, which
bounces `kAutoPauseConfirmEvent` back to whichever isolate owns the UI. The
service is guaranteed alive because this prompt only fires during an active trip.

---

## Constraints — do not break these

* **The prompt must never act on its own.** Ignoring or swiping it away leaves
  the trip recording, untouched. Nothing pauses without explicit confirmation.
  (Phase 18, decision D-12.)
* **Sound and vibration stay off.** `Importance.high` alone produces the
  heads-up banner. The prompt can fire on every 15-minute stationary streak — in
  heavy traffic that could be several times per commute.
* **The prompt stays dismissible** (`autoCancel`, not `ongoing`).
* **The 15-minute threshold is unchanged** (`kAutoPauseStationaryThresholdSeconds`).
* **Do not merge the two notification channels back together.** See above.
* **Do not route the prompt through `kTrackingNotificationId`.** Android dedupes
  on channel+id, so the prompt would replace the ongoing recording notification
  and take its Stop button with it.

---

## Files changed

| File | Change |
|---|---|
| `lib/config/constants.dart` | new channel id/name/description, dialog strings |
| `lib/features/tracking/services/tracking_service_events.dart` | `kAutoPauseConfirmCommand`, `kAutoPauseConfirmEvent` |
| `lib/features/tracking/services/tracking_notification_service.dart` | new high-importance channel; prompt posts to it; both response handlers relay instead of pausing |
| `lib/features/tracking/services/tracking_service.dart` | service-side relay listener |
| `lib/features/tracking/services/tracking_event_source.dart` | `onAutoPauseConfirmRequest` added to the interface |
| `lib/features/tracking/services/main_isolate_tracking_engine.dart` | empty stream for iOS (no isolate boundary there, so nothing to relay) |
| `lib/features/tracking/providers/tracking_providers.dart` | `autoPauseConfirmRequestProvider` |
| `lib/features/shell/main_shell.dart` | listens and shows the dialog |
| `test/unit/features/tracking/auto_pause_confirm_routing_test.dart` | new, 8 tests |

---

## Verification status

**Automated — passing:**
* `flutter analyze` — 0 errors, 0 warnings
* `flutter test` — 717 passed, 10 skipped
* `flutter build apk --release` — succeeds

**Device — NOT DONE. This is the important part.**

Nothing in the test suite can observe a heads-up banner or a notification tap.
The automated tests only pin the *constants and wiring* (that the confirm
command is distinct from the pause command, that the channel ids differ, that
the dialog copy quotes the real threshold). The actual behaviour is unverified.

To verify, on a real Android device:

1. Confirm Settings → Auto-pause is ON.
2. Start a commute, then stay stationary for 15 minutes.
3. **Expect:** a heads-up banner appears over whatever is on screen, and sits
   above the ongoing recording notification in the shade.
4. Tap **Pause** on the notification.
5. **Expect:** the app opens and shows the confirmation dialog.
6. Tap **Pause** in the dialog. **Expect:** the trip pauses.
7. **Negative case, do not skip:** repeat steps 1–3, then swipe the notification
   away instead. **Expect:** the trip keeps recording normally.

**Gotcha for step 3:** if you are testing on an install that predates this
change and had previously silenced the "Active commute" notification channel in
Android system settings, that setting does **not** carry over — the new
"Auto-pause prompts" channel starts fresh. Check the app's notification settings
if the banner does not appear.

---

## Known limitation (accepted, recorded)

If the UI isolate has been killed when the Pause action fires, the app launches
but may miss the relayed event, so no dialog appears. The prompt fires at most
once per stationary streak, so a miss means no dialog until the user moves and
stops again. Accepted because the trip keeps recording — the safe failure
direction — and no data is lost.

---

## Background context

Full reasoning, including the decisions and what was deliberately not changed,
is in `.planning/quick/20260721-auto-pause-heads-up/PLAN.md`.
