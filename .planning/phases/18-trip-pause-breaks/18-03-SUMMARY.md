---
phase: 18-trip-pause-breaks
plan: 03
subsystem: tracking
tags: [pause, resume, isolate-boundary, dumb-terminal, hero-card, widget-tests, tdd]

# Dependency graph
requires:
  - phase: 18-02
    provides: pause-aware TripAccumulator (pause/resume model) + TripSnapshot.isPaused/pausedSeconds/breakCount primitive fields
provides:
  - kTrackingPauseCommand / kTrackingResumeCommand cross-isolate commands (mirror Stop, primitive-only)
  - service-isolate pause/resume handlers toggling accumulator.pause/resume(now UTC), stopping-guarded
  - TrackingEventSource.pause()/resume() on both fbs (Android) and MainIsolateTrackingEngine (iOS)
  - TrackingServiceController.pause()/resume() passthroughs
  - TrackingNotifier.pause()/resume() (dumb terminal — no local paused state)
  - TrackingActive.isPaused/pausedSeconds/breakCount + tolerant snapshot decode
  - PauseResumeButton + PausedBadge + BreakCountChip widgets
  - _HeroActive PAUSED visual state (dimmed frozen timer + badge) + break-count indicator
affects: [18-04 auto-pause reuses the same command path, notification Pause action (future)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cross-isolate command mirror: a UI->service command is a feature-local event-name constant invoked exactly like Stop; ONLY the primitive channel name crosses the boundary, no payload (T-18-08)"
    - "Dumb-terminal UI: pause()/resume() forward the command and set NO local state; the displayed paused flag arrives via the next snapshot's isPaused, giving automatic recovery after backgrounding/kill (D-08, T-18-09)"
    - "Stop-race guard reuse: pause/resume handlers early-return when `stopping` is set so a late pause cannot touch a finalized accumulator (T-18-10)"
    - "Frozen-timer paused styling without a local clock: the elapsed value already arrives frozen from the snapshot, so the hero only dims it (Opacity) rather than altering the value"

key-files:
  created:
    - lib/features/tracking/widgets/pause_resume_button.dart
    - lib/features/tracking/widgets/paused_indicators.dart
    - test/unit/features/tracking/tracking_notifier_pause_test.dart
    - test/widget/features/tracking/pause_resume_button_test.dart
    - test/widget/features/dashboard/hero_record_card_paused_test.dart
  modified:
    - lib/features/tracking/services/tracking_service_events.dart
    - lib/features/tracking/services/tracking_service.dart
    - lib/features/tracking/services/tracking_event_source.dart
    - lib/features/tracking/services/main_isolate_tracking_engine.dart
    - lib/features/tracking/services/tracking_service_controller.dart
    - lib/features/tracking/state/tracking_state.dart
    - lib/features/tracking/providers/tracking_providers.dart
    - lib/config/constants.dart
    - lib/features/dashboard/widgets/hero_record_card.dart
    - test/unit/features/tracking/persist_finalized_trip_test.dart
    - test/unit/features/tracking/tracking_notifier_direction_test.dart
    - test/unit/features/tracking/tracking_notifier_test.dart
    - test/widget/features/dashboard/dashboard_screen_test.dart

key-decisions:
  - "iOS MainIsolateTrackingEngine wires pause/resume to ITS OWN accumulator directly (it owns one) rather than a no-op — that engine drives an accumulator on the main isolate, so the same toggle works without a second isolate. Stop-race-guarded with the existing _stopping flag."
  - "Command constants stay feature-local in tracking_service_events.dart (NOT constants.dart) per that file's stated rationale — the invoke channel is a local protocol; UI label constants DO go in constants.dart."
  - "Break-count singular/plural handled with two constants (kTrackingBreakCountSingularLabel + kTrackingBreakCountPluralTemplate with {n}) so the choice is data, not string concatenation in the widget."
  - "PAUSED badge + break-count chip extracted into paused_indicators.dart to keep _HeroActive's build body well under the 100-line CLAUDE.md widget limit."

metrics:
  duration_minutes: 22
  completed: 2026-06-06
  tasks_completed: 2
  files_created: 5
  files_modified: 13
  tests_added: 16
  full_suite: "442 passing, 10 skipped"
---

# Phase 18 Plan 03: Cross-Isolate Pause/Resume Commands + Active-Tracking Pause UI Summary

Wired pause/resume from the running app to the pause-aware accumulator (18-02) across the isolate boundary using the exact Stop-command pattern, and surfaced a Pause/Resume button, a distinct PAUSED visual state, and a break-count indicator on the production `_HeroActive` hero surface — all driven purely by `snapshot.isPaused`/`breakCount` (dumb terminal, free recovery after backgrounding/kill).

## What shipped

**Task 1 — commands + notifier API + state fields (commit 378e52f)**
- `kTrackingPauseCommand` / `kTrackingResumeCommand` added to `tracking_service_events.dart`, documented as UI->service commands mirroring `kStopTrackingEvent`.
- Service isolate (`tracking_service.dart`) gains `service.on(kTrackingPauseCommand)` / `(kTrackingResumeCommand)` handlers that call `accumulator.pause/resume(DateTime.now().toUtc())`. They do NOT cancel subs or stop the service, and early-return when `stopping` is set (T-18-10). The next uiTimer tick emits the updated `isPaused` snapshot.
- `TrackingEventSource` interface gains `pause()`/`resume()`. `FbsTrackingEventSource` (Android) implements them as `_service.invoke(...)` (primitive-only, T-18-08). `MainIsolateTrackingEngine` (iOS) implements them against its own accumulator, stop-race-guarded.
- `TrackingServiceController.pause()/resume()` passthroughs mirror `stop()`.
- `TrackingActive` gains `isPaused`/`pausedSeconds`/`breakCount` (defaults false/0/0); `trackingActiveFromSnapshotMap` decodes them tolerantly (`map['k'] as bool?/num? ?? default`).
- `TrackingNotifier.pause()/resume()` guard `state is! TrackingActive` then forward to the controller — setting NO local paused state (D-08).
- UI label constants added to `constants.dart`: `kTrackingPauseLabel`, `kTrackingResumeLabel`, `kTrackingPausedBadgeLabel`, `kTrackingBreakCountSingularLabel`, `kTrackingBreakCountPluralTemplate`.
- All three test fakes implementing `TrackingEventSource` updated with no-op `pause()`/`resume()`.

**Task 2 — Pause/Resume button + PAUSED hero state (commit 2ba4824)**
- `PauseResumeButton` (stateless, 64 lines): label/icon toggle by `isPaused`, styled as an outlined sibling to `StopButton`.
- `paused_indicators.dart` (74 lines): `PausedBadge` ("PAUSED" pill) + `BreakCountChip` ("1 break" / "2 breaks").
- `_HeroActive` extended with `isPaused`/`breakCount`/`onPause`/`onResume`; build renders the PAUSED badge + dimmed (Opacity 0.4) frozen `ElapsedDisplay` when paused, a break-count chip when `breakCount > 0`, and the `PauseResumeButton` above the existing `StopButton`.
- Direction toggle + `RecordingHeader` + tiles behaviour unchanged.

## Verification

- `flutter analyze lib/features/tracking/ lib/features/dashboard/`: no new issues (the only 4 infos are pre-existing in `tracking_notification_service.dart`, an untouched file — out of scope).
- New tests (16): `tracking_notifier_pause_test.dart` (7 — pause/resume forwarding, no-local-state, no-op guards, snapshot decode), `pause_resume_button_test.dart` (3), `hero_record_card_paused_test.dart` (6 — running vs paused UI, badge, break count singular/plural, pause/resume routing).
- Full `flutter test`: **442 passing, 10 skipped** (was 426 passing before this plan; +16 new, no regressions).
- Pause/Resume route through `service.invoke(kTrackingPauseCommand/kTrackingResumeCommand)` and the service handler toggles the accumulator (grep + unit suite confirm).
- Paused hero state driven purely by the injected `snapshot.isPaused` (dumb-terminal widget test), proving automatic recovery.

## Plan-assumption check (Stop-command wiring)

The plan's documented Stop path matched the actual codebase **exactly** — no deviation needed. `tracking_service.dart` `service.on(kStopTrackingEvent)` sets `stopping=true` first, the `stopping` flag guards the uiTimer and position listener, and `FbsTrackingEventSource.stop()` is `_service.invoke(kStopTrackingEvent)`. The pause/resume handlers were added immediately above the Stop handler and mirror it precisely (minus the cancel/finalize/stopSelf).

One interface detail worth noting: `MainIsolateTrackingEngine` (iOS) owns its accumulator directly, so pause/resume were wired to `_accumulator?.pause/resume(...)` (stop-race-guarded) rather than the documented "no-op fallback" — the engine's existing structure made the real wiring the natural, non-breaking choice.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] dashboard_screen_test InProgressCard test made brittle by the taller active hero**
- **Found during:** Task 2 (running the dashboard regression test).
- **Issue:** The active hero gained a Pause/Resume button (+~50px), pushing `TodaySection` (which hosts `InProgressCard`) below the initial viewport. The dashboard uses a lazy `CustomScrollView`, so the off-screen sliver was not built during the single `pump()`, and `find.byType(InProgressCard)` returned 0. This is a test-harness viewport fragility caused by the intended UI change, not a production regression — `InProgressCard` still renders correctly.
- **Fix:** Added `tester.scrollUntilVisible(find.byType(InProgressCard), 300, scrollable: ...)` before the assertion in the "shows InProgressCard when tracking is active" test, with an explanatory comment.
- **Files modified:** `test/widget/features/dashboard/dashboard_screen_test.dart`
- **Commit:** 2ba4824

**2. [Rule 3 - Blocking] Missing UserPreferencesValue import in new hero paused test**
- **Found during:** Task 2 (first compile of `hero_record_card_paused_test.dart`).
- **Issue:** The test overrides `userPreferenceProvider` with `UserPreferencesValue.defaults()` (mirroring the dashboard test) but did not import the DAO file that defines the type.
- **Fix:** Added `import 'package:traevy/database/daos/user_preferences_dao.dart';`.
- **Files modified:** `test/widget/features/dashboard/hero_record_card_paused_test.dart`
- **Commit:** 2ba4824

## Threat surface

No new security-relevant surface beyond the plan's `<threat_model>`. The three registered mitigations are all implemented:
- **T-18-08 (Spoofing):** handlers match the exact event name, no payload parsed — only the channel name routes.
- **T-18-09 (Tampering):** UI is a dumb terminal (no local pause clock); a widget test asserts paused UI is driven purely by the injected snapshot.
- **T-18-10 (DoS — pause racing Stop):** pause/resume handlers early-return when `stopping` is true.

## Known Stubs

None. Pause/resume are fully wired end-to-end (UI -> notifier -> controller -> source -> service isolate -> accumulator) on Android, and to the main-isolate accumulator on iOS. No placeholder data flows to the UI.

## Self-Check: PASSED

- All 5 created files exist on disk; SUMMARY exists.
- Both per-task commits (378e52f, 2ba4824) present in git log.
- `kTrackingPauseCommand` present in tracking_service_events.dart; `accumulator.pause` handler present in tracking_service.dart.
