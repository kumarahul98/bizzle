---
phase: 14
slug: background-gps-platform-branch
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-02
updated: 2026-06-02
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Background GPS is **partly human-gated** (real-device drive) — automated coverage targets the platform branch, the reduced-accuracy gate, the accumulator, and the iOS stop-race; it does NOT and cannot validate actual iOS background suspension (Simulator can't reproduce it). See `14-RESEARCH.md` §6.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (`package:flutter_test`) + `mockito` for injected wrappers |
| **Config file** | none — standard `flutter test` |
| **Quick run command** | `flutter test test/unit/tracking/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | full suite ~60–120 s (377+ tests) |

---

## Sampling Rate

- **After every task commit:** `flutter test test/unit/tracking/` (+ `flutter analyze`)
- **After every plan wave:** `flutter test` (full suite — must stay green; Android regression guard, CONTEXT D-08)
- **Before `/gsd:verify-work`:** full suite green + `flutter analyze` no new issues over the 96 baseline
- **Max feedback latency:** ~120 s

---

## Per-Task Verification Map

> Filled by the planner per task. Every code task MUST map to an automated unit/regression test except the three human-gated device behaviors below.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-T1 | 01 | 0 | IOS-06/07 (SC#4 platform branch) | T-02-07 (no PII logging) | buildLocationSettings() never takes a Position; test asserts settings fields only | unit | `flutter test test/unit/features/tracking/location_settings_branch_test.dart` | ✅ | ✅ green |
| 14-01-T2a | 01 | 0→1 | IOS-08 (reduced-accuracy gate) | T-02-07 | gate blocks recording when precise accuracy unavailable; no Position logged | unit | `flutter test test/unit/features/tracking/reduced_accuracy_gate_test.dart` | ✅ | ✅ green |
| 14-01-T2b | 01 | 0→1 | iOS stop-race | T-02-07 | stopping flag before cancel; late sample never reaches accumulator | unit | `flutter test test/unit/features/tracking/ios_engine_stop_race_test.dart` | ✅ | ✅ green |
| 14-03-T2 | 03 | 2 | IOS-06/07/08 + D-04 + T-14-06 | T-14-06 | platform selection correct under both overrides; Android type ≠ iOS type | unit | `flutter test test/unit/features/tracking/tracking_event_source_selection_test.dart` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/unit/features/tracking/location_settings_branch_test.dart` — asserts `AppleSettings` (4 locked params + showBackgroundLocationIndicator + distanceFilter) on iOS via `debugDefaultTargetPlatformOverride`; `AndroidSettings` on Android — **11 tests GREEN** (14-01 Task 1)
- [x] `test/unit/features/tracking/reduced_accuracy_gate_test.dart` — 3 outcomes (blocked/proceed-after/proceed-direct); @Skip removed in Wave 1; **3 tests GREEN** (14-02 Task 3)
- [x] `test/unit/features/tracking/ios_engine_stop_race_test.dart` — stop-race contract: late-drop, flag-before-cancel, N-pre-M-post; @Skip removed in Wave 1; **3 tests GREEN** (14-02 Task 2)
- [x] Existing Phase 2 tracking tests cover the Android regression — Wave 2 full-suite run: **397 tests GREEN** (14-03 Task 2 D-08 guard)

## Wave 2 Requirements

- [x] `test/unit/features/tracking/tracking_event_source_selection_test.dart` — iOS→MainIsolateTrackingEngine, Android→FbsTrackingEventSource via `debugDefaultTargetPlatformOverride`; instance types distinct — **3 tests GREEN** (14-03 Task 2)

*Existing Flutter test infrastructure covers all automated phase requirements; no framework install needed.*

---

## Manual-Only Verifications (HUMAN-GATED — user runs on a real iPhone)

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full backgrounded / locked-screen commute → GPS track complete, no gaps | IOS-06 | iOS Simulator cannot reproduce CoreLocation background suspension | Start a trip, lock the screen, drive a full commute, stop; inspect the saved track for gaps |
| Stop-and-go commute → moving/stuck breakdown accurate (no silent GPS pause) | IOS-07 | Requires real GPS + real slow traffic | Drive a stop-and-go route; verify the moving/stuck split is plausible (GPS didn't pause) |
| "Approximate Location" set → app warns/blocks (no garbage speed stats) | IOS-08 | Requires toggling the iOS Settings privacy control on device | Set Location → Approximate for the app; tap Start; confirm the precise-accuracy prompt then a block if declined |

*Free-provisioning cert expires every 7 days — re-run `flutter run -d <device>` before the session if the last install was >7 days ago (signing memory).*

---

## Validation Sign-Off

- [x] All code tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers the branch, gate, and stop-race tests
- [x] No watch-mode flags
- [x] Feedback latency < 120 s
- [x] The three IOS-06/07/08 device behaviors are explicitly recorded as human-gated (not silently auto-passed)
- [x] `nyquist_compliant: true` set once the planner has mapped every task

**Approval:** Wave 2 complete — 397/397 tests GREEN, 0 new analyzer issues, platform selection proven under both overrides.
