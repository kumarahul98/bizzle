---
task: auto-pause-heads-up
created: 2026-07-21
status: complete
mode: manual-gsd-quick
requirements: [UX-08 follow-up]
---

# Quick task — auto-pause prompt: heads-up + confirm-in-app
#      + recording notification raised to high importance

User request (2026-07-21), two parts:

1. The 15-minute auto-pause prompt should be a **priority notification** so it
   surfaces above the ongoing tracking notification instead of being buried.
2. Tapping **Pause** on it should **open the app and show a confirmation
   dialog**, rather than pausing silently.

## D-01 — A new channel is mandatory, not a preference

On Android 8+ importance lives on the **channel**, not the notification, and a
channel's importance is **immutable once created**. `showAutoPausePrompt()`
currently posts on `kTrackingNotificationChannelId`, which is created with
`Importance.low` (`tracking_notification_service.dart:340`).

So raising `importance:` in `AndroidNotificationDetails` would do **nothing** on
any existing install. It would appear to work on a fresh-install test and
silently fail for every real user — the worst kind of change.

The prompt therefore moves to its own channel at `Importance.high`.

This is also better design regardless: the tracking channel is deliberately
`low` because the ongoing notification refreshes every ~5 s and would buzz
constantly at high importance. The prompt is a different kind of message and
earns its own channel + its own user-facing toggle in system settings.

## D-02 — Route the Pause action through the service, not straight to pause

Today both response handlers call
`FlutterBackgroundService().invoke(kTrackingPauseCommand)` — an immediate,
silent pause with no feedback.

New flow: the action invokes `kAutoPauseConfirmCommand` to the **service**,
which echoes `kAutoPauseConfirmEvent` back to the UI, which shows the dialog.

Why relay through the service rather than a direct in-app stream: the Pause tap
can arrive on EITHER handler — `_onForegroundResponse` (UI isolate) or
`trackingNotificationBackgroundHandler` (its own background isolate, which
cannot reach the UI). Both can talk to the service, and the service is
guaranteed alive because this prompt only ever fires during an active trip.
One path for both cases beats two mechanisms that drift.

## D-03 — Reuse the widget's confirmation pattern

`main_shell.dart:104` already does exactly "open app → confirm → pause" for the
home-screen widget's Pause button. The notification routes into the same
`_showConfirmationDialog` shape so the two entry points behave identically.

Copy is auto-pause specific rather than the widget's generic wording, because
the user needs to know WHY the app is asking:

> **Still stopped?**
> You've been stationary for 15 minutes. Pause this trip?
> [ Keep recording ] [ Pause ]

## D-04 — What is deliberately NOT changed

* `kAutoPauseStationaryThresholdSeconds` stays at 15 min.
* The prompt stays **dismissible** (`autoCancel`, not `ongoing`). Ignoring or
  swiping it away must still leave the trip recording untouched — the D-12
  "prompt only, never acts on its own" guarantee from Phase 18.
* `playSound` / `enableVibration` stay **false**. `Importance.high` alone gives
  the heads-up banner; the prompt can fire on every 15-min stuck streak, which
  in heavy traffic could be several times per commute.
* The opt-in gate is unchanged — with `autoPauseEnabled` off, nothing is posted.

## Known limitation

If the UI isolate is dead when the Pause action fires, the app launches but may
miss the relayed event, so no dialog appears. The prompt fires at most once per
stuck streak, so a miss means no dialog until the user moves and stops again.
Accepted for now: the trip keeps recording, which is the safe failure direction,
and nothing is lost. Recorded here rather than papered over.

## Result — complete 2026-07-21

Built as planned; no decision changed mid-flight. `flutter analyze` 0/0, full
suite **717 passed** (was 709, +8), release APK builds.

One thing the change forced that the plan did not anticipate: the file header of
`tracking_notification_service.dart` carried a flat "DO NOT introduce a second
channel" rule from the D-14 unification contract. That rule is about the
FOREGROUND-SERVICE notification's id/channel pair, not about the file in
general, so the header was rescoped to say so. Left as a scope note rather than
deleted — the D-14 constraint is still real and still load-bearing.

Six test fakes implement `TrackingEventSource` and all needed the new getter.
They return an empty stream, matching how they already treat `onAutoPausePrompt`.

**Device verification outstanding** — this is the whole point of the change and
nothing in CI can see it. Add to the Phase 23 device queue:
stand still 15 min → heads-up banner appears ABOVE the ongoing tracking
notification → tap Pause → app opens with the dialog → confirm → trip pauses.
Then the negative case: swipe the prompt away → the trip must keep recording.

Note for that test: existing installs already have the old low-importance
channel. The new channel is created on next launch, so the heads-up will work —
but if you had previously silenced "Active commute" in system settings, that
setting does NOT carry over to the new channel.

## Follow-up 2026-07-21 (same session) — recording notification ranking

User asked for the RECORDING notification to also be high priority and stick to
the top, and to be non-dismissible.

**Non-dismissible is impossible and was NOT built.** Verified against the
official Android 14 behaviour-changes doc: `FLAG_ONGOING_EVENT` /
`setOngoing(true)` no longer prevents dismissal, and the exception list
(CallStyle, media, device-policy-controller, default Search Selector) does not
cover a commute tracker. `ongoing: true` + `autoCancel: false` stay set — they
are still correct, the OS simply overrides them.

What IS still guaranteed and largely satisfies the intent: the notification is
non-dismissible **while the phone is locked**, and **survives "Clear all"**.
The residual gap is a deliberate swipe while unlocked, which
`_maybeRefreshNotification` should heal within 5 s by re-posting. That healing
is UNVERIFIED on device — worth 30 seconds to confirm.

The stale `02-CONTEXT.md` D-15 claim of "non-dismissible while service is
running" was corrected in `b0245db`; it is what set the wrong expectation.

**High importance WAS built.** `kTrackingNotificationChannelId` bumped to
`traevy_active_commute_v2` at `Importance.high`, because channel importance is
immutable once created and the original channel shipped at `low`. Sound and
vibration stay off — importance alone drives ranking and the heads-up, and
`onlyAlertOnce: true` means the ~5 s refreshes never re-alert. The legacy
channel is explicitly deleted so upgrading users do not end up with two
identically named "Active commute" entries in system settings.

A pre-existing D-14 guard test pinned the literal channel string and failed.
It was over-specified: D-14's real invariant is that the fbs service and our
`show()` call use the SAME channel, not that it equals one particular value —
and both read the same constant, so sameness holds by construction. Rewritten
to pin what can actually break (non-empty, not the retired legacy id, no
collision with the auto-pause channel).

Both channels now sit at `Importance.high`, which retires the original reason
for splitting them. They stay separate for a different and still-valid reason:
independent user control, so silencing the prompt does not silence recording.

Suite 717 -> 721. Release APK builds.

## Files

| File | Change |
|---|---|
| `tracking_service_events.dart` | `kAutoPauseConfirmCommand`, `kAutoPauseConfirmEvent` |
| `constants.dart` | new channel id/name/description, dialog strings |
| `tracking_notification_service.dart` | new high-importance channel; prompt posts to it; both handlers relay instead of pausing |
| `tracking_service.dart` | `service.on(confirm command)` → `service.invoke(confirm event)` |
| `tracking_event_source.dart` | `onAutoPauseConfirmRequest` on the interface + fbs impl |
| `main_isolate_tracking_engine.dart` | same stream for the iOS engine |
| `tracking_providers.dart` | `autoPauseConfirmRequestProvider` |
| `main_shell.dart` | `ref.listen` → confirmation dialog → `pause()` |

## Verification

* `flutter analyze` 0/0, full suite green.
* Unit: the notification response handler invokes the CONFIRM command and
  **never** `kTrackingPauseCommand` directly (that regression is the whole
  point of the change).
* Unit: the new channel is created with `Importance.high`.
* On device: stand still 15 min → heads-up banner appears over the tracking
  notification → tap Pause → app opens with the dialog → confirm → trip pauses.
  Also: swipe the prompt away → trip keeps recording.
