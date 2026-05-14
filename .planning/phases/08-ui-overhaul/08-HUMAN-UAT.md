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

- truth: "Tapping START on dashboard hero card starts recording and shows tracking screen in active state (elapsed timer + Stop button)"
  status: failed
  reason: "User reported: dashboard START button navigates to tracking screen but lands in IDLE state with another 'Start' button, requiring a second tap to actually start recording"
  severity: major
  test: 1
  artifacts: []
  missing: []

- truth: "Tracking screen SPEED tile reflects current instantaneous speed (drops to 0 when stationary)"
  status: failed
  reason: "User reported: SPEED tile stuck at 42 km/h after finishing the drive instead of dropping to 0 when stationary; observed mid-recording (00:03:29 elapsed, 3.25km, 42km/h, 19s stuck) — suggests speed sample not refreshed or last-non-zero value cached"
  severity: major
  test: 4
  artifacts: []
  missing: []
