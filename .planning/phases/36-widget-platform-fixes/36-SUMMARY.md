---
phase: 36-widget-platform-fixes
completed: 2026-07-22
status: code_complete_pending_device_verification
mode: manual-gsd
requirements: [WIDGET-03, UX-12, TRACK-16]
branch: main
commits:
  - a77e862 (36-01 widget resources)
  - 86031a6 (36-02 permission deep-link)
  - 98b883c (36-03 stop-confirm relay)
result: >
  All 3 plans built and tested on main. Flutter 804 tests green (was 776,
  +28), analyze 0 errors / 0 warnings, 283 info lints unchanged from
  baseline, debug APK builds. FIVE of the nine success criteria are
  device-only checks that cannot be performed here — no launcher, no fresh
  install, no release build on hardware. They are marked unverified, not
  green. One plan instruction (Settings.ACTION_APP_PERMISSIONS) did not
  compile and was replaced; see Corrections.
---

# Phase 36 — Widget & Platform Fixes — SUMMARY

## What shipped

| Plan | Commit | Content |
|---|---|---|
| 36-01 | `a77e862` | One-cell widget height, `ic_widget_stop.xml` + `widget_btn_stop.xml`, both layouts reworked, size-map corrected |
| 36-02 | `86031a6` | `traevy/platform` MethodChannel, three denial paths unified, `permission_gate.dart` deleted, 10 tests |
| 36-03 | `98b883c` | Stop-confirm relay, T-36-06 direct-stop fallback, shared dialog, 18 tests |

**Verification:** `flutter analyze` 0 errors / 0 warnings · 283 info lints
(baseline 283 — none added) · `flutter test` **804 passed, 10 skipped**
(was 776/10) · `dart format lib test` clean · `flutter build apk --debug`
succeeds.

## Success criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Widget places/resizes to one cell on a real launcher without clipping | ⏸ **unverified — pending device**. No launcher available. |
| 2 | Stop button is unmistakably a stop control | ⏸ **unverified — pending device**. The vector is a square and the drawables build; whether it *reads* as stop at 18dp is a visual judgement only a screen can make. |
| 3 | `ic_media_ff` appears nowhere in the project | ✅ verified — remaining occurrences are three comments explaining its removal |
| 4 | Deny location on fresh install → "Open settings" lands on the permission list | ⏸ **unverified — pending device**. Needs a fresh install; and see the Corrections note, which makes this the highest-risk unverified item. |
| 5 | On a device where the primary intent does not resolve, the fallback opens App Info without crashing | ⏸ **unverified — pending device**. The Dart-side fallback branch is unit-tested; the Kotlin `ActivityNotFoundException` branch is not reachable from a Dart test. |
| 6 | All three denial paths lead to the same destination; `permission_gate.dart` deleted | ✅ code + tests. Deletion verified unreferenced first. |
| 7 | Notification Stop shows a confirmation; confirm stops, cancel leaves it recording | ✅ code + widget tests for all four behaviours |
| 8 | The stop path works in a **release** build with the app backgrounded | ⏸ **unverified — pending device**. This is the tree-shaking check; no unit test can see it. |
| 9 | Notification and widget confirmations use the same dialog and wording | ✅ by construction — both call `_showStopConfirm` |

**Five of nine are device-gated.** That is the honest shape of this phase: it
is largely about what things look like and where intents land, and neither is
observable from a test host.

## Corrections to the plan

**`Settings.ACTION_APP_PERMISSIONS` does not exist.** D-03 names it directly.
It is `@SystemApi` and hidden — referencing it does not compile. Verified
against `android-36/android.jar`, which exposes
`ACTION_APPLICATION_DETAILS_SETTINGS` and `ACTION_MANAGE_APPLICATIONS_SETTINGS`
but nothing for app permissions.

`MainActivity` now fires the raw string
`"android.intent.action.MANAGE_APP_PERMISSIONS"` with both the data URI and
`EXTRA_PACKAGE_NAME`. **This makes the plan's mandatory fallback more
load-bearing than the plan itself assumed**: the primary action is unsupported
API, not merely an action that some OEM might not implement. If it does not
resolve, SC#4 quietly degrades to the App Info page the phase set out to move
away from — with no crash, but no improvement either. SC#4 is therefore the
device check most likely to come back negative, and the one worth running
first.

**The plan's line references were stale, as flagged.** `318b005` and `f5dfe7a`
had already moved the tracking channel to `Importance.high` and converted the
auto-pause action to a confirm relay. The D-04 *decision* held exactly; only
the line numbers and the "`Importance.low`" description were wrong. `318b005`
was followed as the shape.

**The size-selection rule does not carry over on width alone.** D-01 says to
"re-check" the breakpoint at `CommuteWidgetProvider.kt:52-57` and confirm the
large variant still renders sensibly. It does not. Both `SizeF` entries
declared a **110dp height**, so at one cell tall *neither* fit and the layout
choice fell through to Android's fallback — a selection nothing in that file
was actually expressing. The compact entry is now `SizeF(110, 50)`; the large
entry deliberately keeps `110f` so selection is on both dimensions and a
wide-but-short widget still gets the compact layout.

**`initialLayout`/`previewLayout` pointed at the large layout**, which cannot
render at the new 4x1 target. Both now point at the compact one. The plan did
not mention them.

## Decisions as-built

D-01 through D-04 held. Four things were sharper in code than on paper:

**One cell of height forces a horizontal active state.** The declaration alone
would only have squeezed the layout, exactly as D-01 predicted — but the fix is
structural, not a matter of trimming padding. Stats stacked *above* the buttons
is what made two cells mandatory; nothing else about the content did. The
active state is now a single row, which lets the 48dp touch targets survive
inside a 50dp widget with 1dp of vertical padding. The START button came down
64 → 48dp for the same reason. The large layout's pause/stop buttons were also
raised 46 → 48dp; they had been under the touch-target minimum all along.

**The T-36-06 fallback needs an acknowledgement channel, not just a timeout.**
"If the confirmation cannot be delivered" is only observable if the UI says it
received it. `kStopConfirmAckCommand` carries that, and the UI acks on
**receipt, not on the user's answer** — which is what keeps a user deliberating
over the open dialog from having the trip stopped out from under them at the
five-second mark.

**The stop body had to be extracted, not duplicated.** The timeout and
`kStopTrackingEvent` both need to finalize, persist to `PendingTripStore`,
write the widget idle state and `stopSelf`. A second copy of that would be a
second chance to get trip persistence subtly wrong, so both now call one
`performStop()`.

**`_showStopConfirm` deliberately does NOT gate on `TrackingActive`,** unlike
its auto-pause sibling. `stop()` on a finished trip is a no-op, and the
notification path can legitimately arrive while the state stream is still
catching up on a cold resume. Suppressing the dialog there would reproduce the
exact "Stop did nothing visible" complaint the phase exists to fix.

## Surprises

**A fourth denial path already existed.** `dashboard_screen.dart`'s
permanently-denied and notification-denied dialogs already routed through
`openSystemSettings()`, so they inherited the new destination for free. The
plan listed three paths; there were four.

**The tracking-error button's label was a fifth inconsistency.** It read "Open
Location Settings" — accurate for the device-wide screen it used to open, and
wrong the moment it stopped opening it. All CTAs now take
`kOpenPermissionSettingsLabel`.

**`318b005` left a duplicated `@override`** in `FbsTrackingEventSource`, which
left `onAutoPausePrompt` with none. Analyzed clean either way, so it was
invisible; corrected here rather than left to be pattern-matched by whoever
adds the next member.

**Six test fakes needed the two new interface members** — the same tax
`318b005` paid. Not a design smell so much as the cost of `TrackingEventSource`
being an interface rather than a base class with defaults; noted, not acted on.

**`pumpAndSettle` cannot be used on an actively-recording shell.** The hero
animates continuously, so it never settles. The new widget tests use fixed
pumps, matching what the file's existing back-button test already does for the
same reason.

## What is NOT done

**The five device checks above.** Concretely, on a real Android device:

1. Place the widget, resize it to one cell, confirm no clipping and all three
   buttons tappable (SC#1, SC#5-of-threat-model).
2. Confirm the stop glyph reads as stop at 18dp (SC#2).
3. Fresh install → deny location → "Open settings" → **confirm it lands on the
   permission list, not App Info** (SC#4). Highest risk; see Corrections.
4. Repeat 3 on a second OEM device to exercise the fallback (SC#5).
5. **Release** build, start a trip, background the app, tap Stop on the
   notification → confirm the dialog appears and confirming ends the trip
   (SC#8). This is the only check that catches a tree-shaken background
   handler.

**D-04's investigation step was not performed.** The plan asks to confirm on a
real device whether the trip currently stops before building. It could not be.
Reading the code, both handlers did invoke `kStopTrackingEvent`, so the trip
almost certainly did stop and this is a feedback fix — but "almost certainly"
is what a device would replace with "yes". If check 5 above shows the trip does
*not* stop even with the dialog, there is a second bug in the isolate relay
that this phase has not addressed.

**`kStopConfirmAckTimeoutSeconds` is untuned.** Five seconds is a reasoned
guess at "long enough for a cold Activity start, short enough that a user who
gets no dialog is not left wondering". Only check 5 can say whether it is right;
too short and a slow cold start would stop a trip without ever showing the
dialog it was about to show.

## Follow-ups

1. Run the five device checks above; SC#4 first.
2. If SC#4 fails, `MANAGE_APP_PERMISSIONS` did not resolve — decide between
   accepting App Info or investigating per-OEM intents (the plan explicitly
   judged the latter too fragile, and nothing found here contradicts that).
3. If SC#8 shows a slow cold start, retune `kStopConfirmAckTimeoutSeconds`.
4. Consider whether `targetCellWidth="4"` still makes sense now that a 4x1
   placement gets the *compact* layout, which centres its content and leaves
   the extra width unused. Not a correctness problem, so left alone.
