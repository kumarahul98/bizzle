---
status: partial
phase: 14-background-gps-platform-branch
source: [14-VERIFICATION.md]
started: 2026-06-02
updated: 2026-06-03
---

## Current Test

[testing paused — 3 items deferred to post-Phase 15 device run]

## Tests

### 1. Backgrounded / locked-screen commute (IOS-06)
expected: Start a trip, lock the screen, drive a full commute, stop — the saved GPS track is complete with no gaps.
result: blocked
blocked_by: physical-device
reason: "Deferred until after Phase 15 per user — background-gap behavior depends on the Phase 15 'Always' permission upgrade (IOS-09); requires real-iPhone drive."

### 2. Stop-and-go traffic accuracy (IOS-07)
expected: Drive a stop-and-go route — the moving/stuck breakdown is plausible; GPS did not silently pause at low speed (`pauseLocationUpdatesAutomatically: false`).
result: blocked
blocked_by: physical-device
reason: "Deferred until after Phase 15 per user — requires real-iPhone stop-and-go drive."

### 3. Approximate Location handling (IOS-08)
expected: Set Location → Approximate for the app in iOS Settings, tap Start — a precise-accuracy prompt appears; if declined, recording is blocked with a clear message (no garbage speed stats).
result: blocked
blocked_by: physical-device
reason: "Deferred until after Phase 15 per user — requires real-iPhone Settings toggle."

## Summary

total: 3
passed: 0
issues: 0
pending: 0
skipped: 0
blocked: 3

## Gaps

(none yet — automated layer verified; awaiting device run)

## Device prerequisite

Free-provisioning cert expires every 7 days. If the last install was >7 days ago, re-run `flutter run -d <device>` with the iPhone connected to re-provision (last install 2026-06-02). If item 1 shows background gaps under "When In Use" permission, that is the Phase 15 "Always" two-step upgrade (IOS-09), not a Phase 14 defect.
