---
phase: 22-home-screen-widget
verified: 2026-07-14T00:00:00Z
status: human_needed
score: 4/4 code-level truths verified (wiring intact); end-to-end behavior device-only
overrides_applied: 0
human_verification:
  - test: "Add Commute Tracker widget from the Android widget picker"
    expected: "The Commute Tracker widget appears in the launcher's widget picker and can be placed on the home screen, rendering the idle 'TAP TO START COMMUTE' state."
    why_human: "Widget-picker registration and RemoteViews rendering can only be confirmed on a physical Android launcher; static checks confirm the receiver, widget_info.xml, layout, and drawables exist but not that the OS surfaces and draws them."
  - test: "One-tap start from the widget (idle state)"
    expected: "Tapping the START button on the placed widget launches the app, runs the permission preflight, and begins a commute via the same trip pipeline as the in-app Start button, bringing up the foreground GPS service and persistent notification."
    why_human: "The HomeWidgetLaunchIntent -> widgetClicked stream -> trackingStateProvider.start() chain plus foreground-service startup and the OS notification are runtime platform behaviors that cannot be exercised statically."
  - test: "Stop / pause from the widget (active state)"
    expected: "While tracking, the widget shows the active state (DIST/TIME + PAUSE/STOP). Tapping STOP or PAUSE opens the confirmation dialog and, on confirm, stops-and-saves or pauses the trip through the same pipeline as the in-app controls."
    why_human: "Requires an active trip and a real tap on the RemoteViews button to confirm the confirmation-dialog + trackingStateProvider path end-to-end."
  - test: "Live state reflection (idle vs active, incl. changes initiated inside the app)"
    expected: "Starting/stopping from inside the app flips the widget between idle and active states, and while active the widget's DIST/TIME values update roughly every 5s with real distance/duration."
    why_human: "SharedPreferences writes (widget_show_stats / widget_distance / widget_duration) + HomeWidget.updateWidget re-rendering the home-screen RemoteViews is an OS-side refresh that only a device can confirm; two prior UAT sessions stalled at test 1 without reaching this."
---

# Phase 22: Home-Screen Widget Verification Report

**Phase Goal:** Users can add an Android home-screen widget that starts or stops a commute with one tap and always reflects the current tracking state
**Verified:** 2026-07-14
**Status:** human_needed
**Re-verification:** No — initial verification (traceability/verification debt from the v0.3 milestone audit)

## Goal Achievement

### Observable Truths

Each roadmap Success Criterion is verified at the code/wiring level. None can be fully confirmed without a physical Android device — the device-only portion of each is routed to Human Verification, not marked as a failure.

| #   | Truth (ROADMAP Success Criteria)                                                                                                            | Status                          | Evidence                                                                                                                                                                                                                                          |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | User can add a Commute Tracker widget to the Android home screen from the widget picker                                                    | ✓ VERIFIED (code) · device-only confirm | Manifest declares `.CommuteWidgetProvider` receiver with `APPWIDGET_UPDATE` + `@xml/widget_info` metadata; `widget_info.xml`, `widget_layout.xml`, and all three drawables (`widget_bg`, `widget_btn_record`, `widget_btn_pause`) exist |
| 2   | Tapping the widget when idle starts a commute; tapping while tracking stops and saves — same trip pipeline as the in-app button           | ✓ VERIFIED (code) · device-only confirm | Layout buttons -> `HomeWidgetLaunchIntent` URIs (`traevy://widget?action=start/pause/stop`) -> `MainShell._onWidgetClicked` (host `widget`) -> `trackingStateProvider.notifier.start()/.stop()/.pause()` — the identical provider the dashboard `hero_record_card` uses |
| 3   | The widget visually reflects tracking state (idle vs active) and updates on start/stop, including changes initiated inside the app         | ✓ VERIFIED (code) · device-only confirm | `tracking_service.onStart` writes `widget_show_stats=true` + `updateWidget`; stop handler writes `false` + `updateWidget`; a 5s-throttled timer pushes `widget_distance`/`widget_duration`. `CommuteWidgetProvider.onUpdate` reads these and toggles `widget_idle_state`/`widget_active_state` visibility |
| 4   | Starting from the widget brings up the foreground GPS service + persistent notification exactly as in-app Start (no degraded capture)      | ✓ VERIFIED (code) · device-only confirm | Widget start routes through `_handleStart()` -> permission preflight -> `trackingStateProvider.notifier.start()`, the same entry the in-app Start uses; this drives `FlutterBackgroundService` (foreground `location` service in manifest) |

**Score:** 4/4 code-level truths verified (wiring intact). Overall status is `human_needed` because every truth's user-observable outcome (placing the widget, tapping RemoteViews, live home-screen refresh, foreground-service startup) is inherently device-only and remains unconfirmed.

### Required Artifacts

| Artifact                                                                    | Expected                                              | Status     | Details                                                                                              |
| --------------------------------------------------------------------------- | ---------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------- |
| `android/app/src/main/res/xml/widget_info.xml`                              | AppWidget provider metadata (makes widget pickable)  | ✓ VERIFIED | Valid `appwidget-provider` with `initialLayout=@layout/widget_layout`, resize modes, `home_screen`  |
| `android/app/src/main/res/layout/widget_layout.xml`                         | Idle START + active DIST/TIME + PAUSE/STOP           | ✓ VERIFIED | Idle/active `LinearLayout`s; `widget_distance` + `widget_duration` TextViews; three tappable buttons |
| `android/.../kotlin/traevy/traevy/CommuteWidgetProvider.kt`                 | RemoteViews update + visibility toggle + click intents | ✓ VERIFIED | Overrides `onUpdate`; reads `widget_show_stats/_distance/_duration`; sets 3 `HomeWidgetLaunchIntent`s |
| `android/app/src/main/AndroidManifest.xml`                                  | Receiver registration + foreground-service type      | ✓ VERIFIED | `.CommuteWidgetProvider` receiver + `HomeWidgetBackgroundReceiver`; FGS `foregroundServiceType=location` |
| `lib/features/shell/main_shell.dart`                                        | Widget-tap handler (active path)                     | ✓ VERIFIED | `HomeWidget.widgetClicked` stream + `initiallyLaunchedFromHomeWidget()`; host `widget` -> start/pause/stop |
| `lib/features/tracking/services/tracking_service.dart`                      | Stats sync into HomeWidget SharedPreferences         | ✓ VERIFIED | `saveWidgetData` for title/show_stats/distance/duration + `updateWidget`, throttled to 5s            |
| `lib/main.dart` `backgroundCallback`                                        | Background toggle path (per plan T04)                | ⚠️ ORPHANED | Present and registered, but keys off host `toggletracking` which no widget intent emits — dead path (see Anti-Patterns) |

### Key Link Verification

| From                     | To                          | Via                                                   | Status       | Details                                                                                             |
| ------------------------ | --------------------------- | ----------------------------------------------------- | ------------ | -------------------------------------------------------------------------------------------------- |
| `widget_layout.xml`      | `CommuteWidgetProvider.kt`  | `setOnClickPendingIntent(btn_*)`                      | ✓ WIRED      | Start/pause/stop buttons each bound to a `HomeWidgetLaunchIntent`                                   |
| `CommuteWidgetProvider.kt` | `main_shell.dart`         | `HomeWidgetLaunchIntent` (`traevy://widget?action=`) -> `HomeWidget.widgetClicked` | ✓ WIRED | Host `widget` + `action` query parsed in `_onWidgetClicked`                                         |
| `main_shell.dart`        | `tracking_providers.dart`   | `trackingStateProvider.notifier.start()/.stop()/.pause()` | ✓ WIRED  | Same provider the in-app dashboard uses — shared trip pipeline (SC#2, SC#4)                         |
| `tracking_service.dart`  | `CommuteWidgetProvider.kt`  | `saveWidgetData` -> SharedPreferences -> `updateWidget` | ✓ WIRED    | Provider reads the same keys the service writes; visibility + text driven by `widget_show_stats`   |
| `widget layout tap`      | `main.dart backgroundCallback` | host `toggletracking`                              | ✗ NOT_WIRED  | No intent emits host `toggletracking`; this is a redundant/dead path, not the active one           |

### Data-Flow Trace (Level 4)

| Artifact                     | Data Variable                          | Source                                                        | Produces Real Data | Status     |
| ---------------------------- | -------------------------------------- | ------------------------------------------------------------ | ------------------ | ---------- |
| `CommuteWidgetProvider.kt`   | `widget_distance` / `widget_duration`  | `tracking_service` `accumulator.snapshot()` (GPS-derived)     | Yes                | ✓ FLOWING  |
| `CommuteWidgetProvider.kt`   | `widget_show_stats`                    | `tracking_service` onStart (`true`) / stop handler (`false`)  | Yes                | ✓ FLOWING  |

The rendered values originate from the live tracking accumulator, not hardcoded/static placeholders (the `"--"` in XML is only the pre-tracking default, overwritten once a trip is active).

### Behavioral Spot-Checks

Step 7b: SKIPPED — the phase's runnable behavior is a native Android AppWidget requiring a physical launcher/home screen. There is no headless entry point that can exercise widget placement, RemoteViews rendering, or the foreground-service tap path within the spot-check constraints. All behavioral confirmation is routed to Human Verification.

### Requirements Coverage

| Requirement | Source Plan | Description                                                                                                       | Status       | Evidence                                                                                     |
| ----------- | ----------- | --------------------------------------------------------------------------------------------------------------- | ------------ | ------------------------------------------------------------------------------------------- |
| WIDGET-01   | 22-01-PLAN  | User can add an Android home-screen widget that starts/stops a commute with one tap and reflects tracking state | ? NEEDS HUMAN | Code + wiring complete and correct (truths 1-4, all key links WIRED); user-observable behavior is device-only and never confirmed on-device (UAT stalled at test 1) |

### Anti-Patterns Found

| File                                     | Line     | Pattern                                                                 | Severity   | Impact                                                                                                                            |
| ---------------------------------------- | -------- | ---------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `lib/main.dart`                          | 70-98    | `backgroundCallback` keys on host `toggletracking`, which no widget intent emits | ⚠️ Warning | Dead/redundant code path. The active tap path (launch intent -> `main_shell`) fully works, so WIDGET-01 is not broken — but this registered callback never fires and should be removed or reconciled to avoid confusion |
| `lib/main.dart`                          | 72, 78   | `print('=== BACKGROUND CALLBACK FIRED ...')` debug logging            | ℹ️ Info    | Debug `print` left in shipped code (also in the dead path)                                                                       |
| `lib/features/tracking/services/tracking_service.dart` | 97, 170 | `print(...)` debug logging                                            | ℹ️ Info    | Debug `print` in the tracking isolate; cosmetic                                                                                  |
| plan vs. implementation                  | —        | Plan T03/must_have located stats sync in `tracking_providers.dart`; actual sync lives in `tracking_service.dart` | ℹ️ Info | Functionality is present and arguably better-placed (in the background isolate where the live snapshot exists). The plan's file-level claim is stale but the goal is met |

### Human Verification Required

The following must be run on a real Android device. These are the three scenarios the stalled `22-UAT.md` never completed, and they are formally owned by **Phase 23 (Resolve Deferred UAT Items), Success Criterion #3**.

### 1. Add Commute Tracker Widget

**Test:** From the Android launcher's widget picker, place the Commute Tracker widget on the home screen.
**Expected:** The widget appears in the picker and, once placed, renders the idle state ("TAP TO START COMMUTE" + crimson START).
**Why human:** Widget-picker registration and RemoteViews drawing are OS-side behaviors not observable statically.

### 2. One-Tap Start (and Foreground Service parity)

**Test:** With no active trip, tap the widget's START button.
**Expected:** App launches, permission preflight runs, a commute starts through the same pipeline as the in-app Start, and the foreground GPS service + persistent notification appear — no degraded capture.
**Why human:** The launch-intent -> widgetClicked -> `trackingStateProvider.start()` chain plus foreground-service/notification startup are runtime platform behaviors.

### 3. Stop/Pause + Live State Reflection

**Test:** While a trip is active, observe the widget's active state (DIST/TIME) updating (~every 5s), then tap STOP (and separately PAUSE), confirming the dialog. Also start/stop from inside the app and watch the widget flip states.
**Expected:** Live values update; STOP saves the trip and PAUSE pauses it; in-app start/stop flips the widget idle<->active.
**Why human:** SharedPreferences-driven RemoteViews refresh and the confirmation-dialog path require a device; both prior UAT sessions stalled before reaching this.

### Gaps Summary

No code-level gaps. All four ROADMAP success criteria are satisfied at the artifact + wiring + data-flow level: the native receiver, metadata, layout, and drawables exist; the widget-tap launch path is correctly wired into the same `trackingStateProvider` trip pipeline the in-app controls use; and live stats flow from the tracking isolate into the widget's SharedPreferences keys with a matching Kotlin reader.

The phase does **not** pass as fully verified because WIDGET-01 is, by nature, a native home-screen surface whose user-observable behavior (placing the widget, tapping RemoteViews, live refresh on the home screen, foreground-service startup from a widget tap) can only be confirmed on a physical Android device. That device UAT has never been completed — `22-UAT.md` is still `testing`, stalled at test 1 of 3 since 2026-06-09. Closing this is explicitly Phase 23's job (SC#3).

Two non-blocking cleanups are noted for a future touch: the orphaned `backgroundCallback` (`toggletracking` host) that no intent triggers, and leftover debug `print` statements.

---

_Verified: 2026-07-14_
_Verifier: Claude (gsd-verifier)_
