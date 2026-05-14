---
status: complete
phase: 08-ui-overhaul
source: [08-VERIFICATION.md]
started: 2026-05-14T16:30:00Z
updated: 2026-05-15T10:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Visual smoke test across all 7 screens (light + dark)
expected: Dashboard, Tracking, History, Trip Detail, Stats, Settings, and Onboarding screens render with Traevy design tokens — calm, spacious layout, correct typography, no visual regressions in either light or dark theme
result: issue
reported: "why are there 2 start button: dashboard START + tracking screen Start"
severity: major

### 2. Dark-mode visual sweep — 14-field lerp transitions
expected: Toggling system theme (light ↔ dark) animates smoothly across all screens via the TraevyTokensExt.lerp interpolation; no flashes, no token-mismatch artifacts
result: pass

### 3. Font asset loading on Android device
expected: Inter and JetBrains Mono fonts render correctly on a real Android device with `GoogleFonts.config.allowRuntimeFetching = false`. No silent fallback to Roboto/system fonts in any text element.
result: pass

### 4. Tracking screen Variant A end-to-end
expected: Active recording flow renders the pulsing RecordingHeader dot animation, real-time ElapsedDisplay timer in mono font, stat tiles updating with distance/speed/stuck, and Stop button correctly finalizes the trip
result: issue
reported: "after finishing the route the SPEED tile is stuck at 42km/h instead of dropping to 0 when stationary; screenshot taken mid-recording (00:03:29 elapsed, 3.25km, 42km/h speed, 19s stuck)"
severity: major

### 5. Hero record card drop shadow appearance
expected: HeroRecordCard's circular START button shows a calibrated drop shadow (0 12px 32px) that reads as elevated on both light and dark backgrounds. Two hardcoded shadow tints (`Color(0x66000000)`, `Color(0x40B43C28)`) are visually acceptable, or surfaced for token promotion.
result: pass

## Summary

total: 5
passed: 3
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Tapping START on the dashboard hero starts the commute IN PLACE — the hero card expands to show the active recording UI (RECORDING badge + direction label + ELAPSED timer + DISTANCE/SPEED/STUCK tiles + Stop and save button) without navigating to a separate screen. The rest of the dashboard (TodaySection, WeekLossCard) stays usable underneath so the user can keep using the app while a commute is running."
  status: failed
  reason: "User design feedback (2026-05-15): dashboard START currently navigates to a separate TrackingScreen that lands in IDLE state with a redundant second 'Start' button. User wants the entire commute flow consolidated into the dashboard — hero card transforms into the active recording view, no navigation, and the rest of the dashboard remains accessible during an active commute. TrackingScreen as a separate destination should likely be removed (or repurposed) since the hero will absorb all of its active-state UI."
  severity: major
  test: 1
  artifacts:
    - .planning/debug/hero-start-double-tap.md
  missing: []
  design_change: true
  scope_note: "This supersedes Phase 8 Plan 04's two-screen flow. UI-SPEC §3 (Active Recording) needs an addendum specifying the dashboard-resident active-state layout."
  root_cause: "DashboardScreen._handleStart (lib/features/dashboard/screens/dashboard_screen.dart:58-82) only navigates with Navigator.pushNamed(kRouteTracking) — never calls ref.read(trackingStateProvider.notifier).start(). The agent's recommended Path A (also call .start() before navigating) is superseded by the user's redesign request: collapse the active-recording UI into HeroRecordCard, remove the navigation, and treat TrackingScreen as deep-link-only or remove entirely."

- truth: "Tracking screen SPEED tile reflects current instantaneous speed (drops to 0 when stationary)"
  status: failed
  reason: "User reported: SPEED tile stuck at 42 km/h after finishing the drive instead of dropping to 0 when stationary; observed mid-recording (00:03:29 elapsed, 3.25km, 42km/h, 19s stuck) — suggests speed sample not refreshed or last-non-zero value cached"
  severity: major
  test: 4
  artifacts:
    - .planning/debug/active-speed-tile-stale.md
  missing: []
  root_cause: "TripAccumulator.snapshot() at lib/features/tracking/services/trip_accumulator.dart:196 emits currentSpeedMs: _lastAccepted?.speed ?? 0 with NO freshness check. The 1Hz UI snapshot timer (tracking_service.dart:131-137) keeps republishing the same _lastAccepted value indefinitely when GPS samples stop arriving (Android throttles emissions when stationary, and the 30m accuracy gate at trip_accumulator.dart:135 drops stationary low-accuracy samples). NOT a Phase 8 regression — pre-existing producer bug. UI path (CurrentSpeedTile → TrackingTilesRow → TrackingActiveLayout) is a transparent passthrough."
  fix_direction: "Add _lastAcceptedAt timestamp to TripAccumulator (set when _lastAccepted = p in addSample). In snapshot(now), emit currentSpeedMs: 0 when now - _lastAcceptedAt > kTrackingSpeedFreshnessWindow (suggested 6s = 2× kTrackingSampleInterval). Optional defensive distance cross-check: if cumulative distance hasn't moved for the window, force speed to 0 even when a sample reports non-zero (handles Android sticky-speed). Add unit tests for sample-then-silence → 0, sample-then-zero → 0, sample-then-silence-under-window → preserved."
