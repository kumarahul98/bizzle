---
phase: 18-trip-pause-breaks
plan: 04
subsystem: tracking
tags: [flutter, riverpod, flutter_local_notifications, flutter_background_service, geolocator, auto-pause, drift]

# Dependency graph
requires:
  - phase: 18-01
    provides: user_preferences.auto_pause_enabled column (BoolColumn default false) + UserPreferencesValue.autoPauseEnabled
  - phase: 18-02
    provides: TripAccumulator pause model (isPaused, break segments) + stuck/moving classification
  - phase: 18-03
    provides: kTrackingPauseCommand cross-isolate command + pause/resume wiring + PAUSED hero UI
provides:
  - AutoPauseDetector — pure once-per-streak stuck-time state machine (service-isolate)
  - Service-isolate auto-pause detection fed from the accumulator's own stuck classification (no second speed threshold)
  - kAutoPausePromptEvent service→UI channel + TrackingEventSource.onAutoPausePrompt
  - showAutoPausePrompt() notification with a Pause AndroidNotificationAction routing to kTrackingPauseCommand
  - Opt-in Settings Auto-pause toggle bound to user_preferences.auto_pause_enabled (default OFF)
affects: [sync (breaks/total_paused_seconds local-only — later sync phase), trip-editing-phase-19]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Service-side detection + UI-side opt-in gate: detection runs in the service isolate next to the accumulator; the UI isolate reads the Drift-backed opt-in flag and gates the prompt post (keeps prefs where Drift lives, no start-payload race)"
    - "addSample returns the attributed interval's classification record ({bool stuck, int seconds})? — informational, backward-tolerant; existing callers ignore it"
    - "Separate dismissible notification id (kAutoPauseNotificationId) so the prompt never collides with the ongoing recording notification"

key-files:
  created:
    - lib/features/tracking/services/auto_pause_detector.dart
    - test/unit/features/tracking/auto_pause_detector_test.dart
    - test/unit/features/tracking/auto_pause_prompt_gate_test.dart
  modified:
    - lib/config/constants.dart
    - lib/features/tracking/services/tracking_service_events.dart
    - lib/features/tracking/services/trip_accumulator.dart
    - lib/features/tracking/services/tracking_service.dart
    - lib/features/tracking/services/main_isolate_tracking_engine.dart
    - lib/features/tracking/services/tracking_event_source.dart
    - lib/features/tracking/services/tracking_notification_service.dart
    - lib/features/tracking/providers/tracking_providers.dart
    - lib/features/settings/screens/settings_screen.dart
    - test/widget/features/settings/settings_screen_test.dart

key-decisions:
  - "Detection stays service-side; the opt-in gate lives on the UI isolate (where Drift/userPreferenceProvider is reachable) rather than passing autoPauseEnabled in the start payload — avoids a start-invoke race and still satisfies SC#5 (OFF → no prompt)"
  - "addSample now returns ({bool stuck, int seconds})? (option A) so the detector consumes the SAME classification as the metric — no second kStuckSpeedThresholdMs comparison"
  - "Auto-pause prompt is a SEPARATE notification (kAutoPauseNotificationId 1002), non-ongoing + autoCancel, so it never replaces the recording notification and is trivially dismissible"

patterns-established:
  - "Pure injected-threshold detector (AutoPauseDetector) — deterministic, unit-testable with synthetic intervals, latch re-arms only on movement"
  - "Reuse the Stop-action notification wiring for the Pause action (exact action-id match in both foreground + @pragma background handlers)"

requirements-completed: [TRACK-10]

# Metrics
duration: 31min
completed: 2026-06-06
---

# Phase 18 Plan 04: Opt-in Auto-Pause Prompt Summary

**Opt-in auto-pause: a service-isolate stuck-streak detector (15-min continuous stuck time, keyed off the accumulator's own classification) posts a once-per-streak notification with a Pause action that fires kTrackingPauseCommand — gated OFF by default via a real Settings toggle.**

## Performance

- **Duration:** 31 min
- **Started:** 2026-06-06T05:50:07Z
- **Completed:** 2026-06-06T06:21:34Z
- **Tasks:** 3
- **Files modified:** 10 (3 created, 7 modified) + 3 supporting test-fake edits

## Accomplishments
- `AutoPauseDetector`: pure stuck-streak state machine — extends an uninterrupted stuck streak, fires `shouldPrompt()` exactly once when the streak crosses the injected threshold, resets + re-arms on any moving interval (stop-and-go can never false-trigger; the core stuck-time metric is untouched — D-11).
- Wired the detector into BOTH the Android service isolate (`tracking_service.dart`) and the iOS main-isolate engine (`main_isolate_tracking_engine.dart`), fed from the accumulator's own per-interval stuck/moving classification (`addSample` now returns that record). On a streak crossing while not already paused, the engine emits `kAutoPausePromptEvent`.
- `showAutoPausePrompt()` posts a separate, dismissible notification carrying a single "Pause" `AndroidNotificationAction` (`kTrackingAutoPauseActionId`) that routes to `kTrackingPauseCommand` via the existing foreground + `@pragma('vm:entry-point')` background response handlers — prompt only, never silent auto-pause (D-12).
- `TrackingNotifier` subscribes to `onAutoPausePrompt` and posts the prompt ONLY when `user_preferences.auto_pause_enabled` is true (opt-in gate on the UI isolate, SC#5).
- Replaced the visual-only Settings placeholder with a real Auto-pause toggle bound to `user_preferences.auto_pause_enabled` (default OFF), with no notification side-effect.

## Task Commits

Each task was committed atomically (TDD where applicable):

1. **Task 1: AutoPauseDetector + constants (TDD)** — `141b3de` (feat/test)
2. **Task 2: Service-isolate wiring + Pause-action notification** — `e61bc10` (feat)
3. **Task 3: Settings Auto-pause toggle** — `69929f1` (feat)
4. **Test-lint tidy (cascades + import order)** — `3846964` (refactor)

**Plan metadata:** committed separately with this SUMMARY.

## Files Created/Modified
- `lib/features/tracking/services/auto_pause_detector.dart` — pure once-per-streak detector (injected threshold, no raw speed).
- `lib/config/constants.dart` — `kAutoPauseStationaryThresholdSeconds` (15×60), `kAutoPauseNotificationId` (1002), `kTrackingAutoPauseActionId`/`Label`, prompt title/body, settings label + ON/OFF subtitles.
- `lib/features/tracking/services/tracking_service_events.dart` — `kAutoPausePromptEvent` channel constant.
- `lib/features/tracking/services/trip_accumulator.dart` — `addSample` returns `({bool stuck, int seconds})?`; added public `isPaused` getter.
- `lib/features/tracking/services/tracking_service.dart` — constructs the detector, feeds each attributed interval, invokes the prompt event once per streak (Android isolate).
- `lib/features/tracking/services/main_isolate_tracking_engine.dart` — same detector wiring + `onAutoPausePrompt` controller (iOS).
- `lib/features/tracking/services/tracking_event_source.dart` — `onAutoPausePrompt` interface getter + Android passthrough to `kAutoPausePromptEvent`.
- `lib/features/tracking/services/tracking_notification_service.dart` — `showAutoPausePrompt()`; Pause-action branch in both response handlers; additive Pause Darwin action.
- `lib/features/tracking/providers/tracking_providers.dart` — `_autoPausePromptSub` subscription with the opt-in gate; cancellation in dispose + `_cancelSiblingSubs`.
- `lib/features/settings/screens/settings_screen.dart` — real Auto-pause toggle, `_copyPrefs(autoPauseEnabled:)`, `_toggleAutoPause`, removed `_noopBool`.
- Tests: `auto_pause_detector_test.dart` (streak/threshold/re-arm/stop-and-go), `auto_pause_prompt_gate_test.dart` (UI opt-in gate), settings widget tests (default-OFF + toggle-upsert), plus `onAutoPausePrompt` getter added to the four existing `TrackingEventSource` test fakes.

## Decisions Made
- **Service learns the opt-in flag via the UI isolate, not the start payload.** The Android `start()` is a payload-less `startService()`, and the isolate can't reach Drift cleanly. Rather than introduce a racey config-invoke, detection runs service-side while the UI-isolate notifier reads `userPreferenceProvider.autoPauseEnabled` and gates the prompt post. This keeps prefs where they live, keeps detection service-side (D-11), and still guarantees OFF → no prompt (SC#5, T-18-13). This is the plan's recommended fallback path, chosen because it fits the existing payload-less start wiring with zero race surface.
- **`addSample` option A** (return the attributed interval record) over option B (separate `lastInterval` accessor) — single source of truth, no extra mutable field, backward-tolerant for all existing callers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected an inverted stuck/moving assignment while refactoring addSample**
- **Found during:** Task 2 (accumulator return-type change)
- **Issue:** The original code read `if (prev.speed >= threshold) movingSeconds += …; else stuckSeconds += …`. When extracting the classification into the returned record I expressed it as `stuck = prev.speed < threshold` and re-bucketed accordingly. The net behaviour is identical, but writing the branch in stuck-first terms required care not to invert the buckets.
- **Fix:** Wrote `final stuck = prev.speed < kStuckSpeedThresholdMs;` and assigned `_timeStuckSeconds`/`_timeMovingSeconds` from it; returned `(stuck: stuck, seconds: deltaSecInt)`.
- **Verification:** All pre-existing `trip_accumulator_test.dart` moving/stuck assertions still pass (full suite green).
- **Committed in:** `e61bc10`

**2. [Rule 3 - Blocking] Updated four existing TrackingEventSource test fakes for the new interface getter**
- **Found during:** Task 2 (adding `onAutoPausePrompt` to the interface)
- **Issue:** Adding `onAutoPausePrompt` to `TrackingEventSource` broke compilation of every fake implementing it.
- **Fix:** Added a `const Stream.empty()` `onAutoPausePrompt` getter to the fakes in `tracking_notifier_test.dart`, `tracking_notifier_direction_test.dart`, `tracking_notifier_pause_test.dart`, `persist_finalized_trip_test.dart`.
- **Verification:** Full `flutter test` green.
- **Committed in:** `e61bc10`

---

**Total deviations:** 2 auto-fixed (1 bug-prevention during refactor, 1 blocking compile fix). No scope creep.
**Impact on plan:** Both necessary to land the planned change correctly.

## Issues Encountered
- The first cut of `auto_pause_prompt_gate_test.dart` timed out / threw "provider disposed during loading" because it `await`ed `userPreferenceProvider.future` on a `Stream.value` provider that never closes. Resolved by adding `_awaitPrefsData` — a `container.listen(..., fireImmediately: true)` that resolves once the provider reaches the data state and keeps the subscription alive. Production code unaffected.

## Threat Model Compliance
- **T-18-11 (false-positive stationary detection):** mitigated — detection keys off the accumulator's continuous STUCK classification; any moving interval resets the streak; a stop-and-go test proves the threshold is never reached. No raw-speed path, no second threshold constant.
- **T-18-12 (spoofed/stale Pause action):** mitigated — both response handlers match the exact `kTrackingAutoPauseActionId` before invoking `kTrackingPauseCommand` (mirrors the Stop V5 validation).
- **T-18-13 (prompt firing while opted out):** mitigated — the post is gated on `autoPauseEnabled` (default false) on the UI isolate; a settings test asserts default OFF and a notifier test asserts OFF → no post.
- **T-18-14 (prompt spam):** mitigated — `shouldPrompt()` latches once per streak and only re-arms after `onMovingInterval()`.

## Sync Contract Flag (CONTEXT D discretion)
Breaks and `total_paused_seconds` remain **LOCAL-ONLY** this phase. No `sync_queue` payload or Cloud Function (`/trips/sync`) change was made. **A later sync phase must decide whether `trip_breaks` + `total_paused_seconds` should sync to Firestore** — the backend contract is unchanged here.

## Verification
- `flutter test` — **453 passing** (442 baseline + 7 detector + 2 gate + 2 settings), 0 failures, pre-existing skips unchanged. No regressions.
- `flutter analyze` on all touched files — no NEW issues (only the project's pre-existing `info`-level `comment_references`/line-length norms in `constants.dart`, and the pre-existing non-const `showRecording` infos in `tracking_notification_service.dart`).
- Grep gates: `kTrackingAutoPauseActionId` + `kTrackingPauseCommand` present in the notification service; `AutoPauseDetector` present in the service isolate; `autoPauseEnabled` present in the settings screen.

## Next Phase Readiness
- TRACK-10 (opt-in auto-pause prompt) complete. Phase 18 SC#4 + SC#5 satisfied.
- Phase 19 (full trip editing, TRACK-11) builds on the break persistence from 18-01/02/03 — unaffected by this plan.
- Open item for a sync phase: decide whether breaks/paused-time sync to the backend.

## Self-Check: PASSED

- Created files verified on disk: `auto_pause_detector.dart`, `auto_pause_detector_test.dart`, `auto_pause_prompt_gate_test.dart`, `18-04-SUMMARY.md`.
- Task commits verified in history: `141b3de`, `e61bc10`, `69929f1`, `3846964`.

---
*Phase: 18-trip-pause-breaks*
*Completed: 2026-06-06*
