---
status: partial
phase: 14-background-gps-platform-branch
source: [14-VERIFICATION.md]
started: 2026-06-02
updated: 2026-06-02
---

## Current Test

[awaiting human testing on a real iPhone]

## Tests

### 1. Backgrounded / locked-screen commute (IOS-06)
expected: Start a trip, lock the screen, drive a full commute, stop — the saved GPS track is complete with no gaps.
result: [pending]

### 2. Stop-and-go traffic accuracy (IOS-07)
expected: Drive a stop-and-go route — the moving/stuck breakdown is plausible; GPS did not silently pause at low speed (`pauseLocationUpdatesAutomatically: false`).
result: [pending]

### 3. Approximate Location handling (IOS-08)
expected: Set Location → Approximate for the app in iOS Settings, tap Start — a precise-accuracy prompt appears; if declined, recording is blocked with a clear message (no garbage speed stats).
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

(none yet — automated layer verified; awaiting device run)

## Device prerequisite

Free-provisioning cert expires every 7 days. If the last install was >7 days ago, re-run `flutter run -d <device>` with the iPhone connected to re-provision (last install 2026-06-02). If item 1 shows background gaps under "When In Use" permission, that is the Phase 15 "Always" two-step upgrade (IOS-09), not a Phase 14 defect.
