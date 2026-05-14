---
status: partial
phase: 08-ui-overhaul
source: [08-VERIFICATION.md]
started: 2026-05-14T16:30:00Z
updated: 2026-05-14T16:30:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Visual smoke test across all 7 screens (light + dark)
expected: Dashboard, Tracking, History, Trip Detail, Stats, Settings, and Onboarding screens render with Traevy design tokens — calm, spacious layout, correct typography, no visual regressions in either light or dark theme
result: [pending]

### 2. Dark-mode visual sweep — 14-field lerp transitions
expected: Toggling system theme (light ↔ dark) animates smoothly across all screens via the TraevyTokensExt.lerp interpolation; no flashes, no token-mismatch artifacts
result: [pending]

### 3. Font asset loading on Android device
expected: Inter and JetBrains Mono fonts render correctly on a real Android device with `GoogleFonts.config.allowRuntimeFetching = false`. No silent fallback to Roboto/system fonts in any text element.
result: [pending]

### 4. Tracking screen Variant A end-to-end
expected: Active recording flow renders the pulsing RecordingHeader dot animation, real-time ElapsedDisplay timer in mono font, stat tiles updating with distance/speed/stuck, and Stop button correctly finalizes the trip
result: [pending]

### 5. Hero record card drop shadow appearance
expected: HeroRecordCard's circular START button shows a calibrated drop shadow (0 12px 32px) that reads as elevated on both light and dark backgrounds. Two hardcoded shadow tints (`Color(0x66000000)`, `Color(0x40B43C28)`) are visually acceptable, or surfaced for token promotion.
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
