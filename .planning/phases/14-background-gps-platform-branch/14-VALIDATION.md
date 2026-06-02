---
phase: 14
slug: background-gps-platform-branch
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-02
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
| (planner fills) | | | IOS-06/07/08 | T-02-07 (no PII/position logging) | encoded polyline is the only location egress | unit | `flutter test test/unit/tracking/` | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/tracking/location_settings_branch_test.dart` — assert `AppleSettings` (4 locked params) on iOS via `debugDefaultTargetPlatformOverride`, `AndroidSettings` on Android
- [ ] `test/unit/tracking/reduced_accuracy_gate_test.dart` — mock accuracy wrapper; `reduced→request→reduced` blocks, `precise` proceeds
- [ ] `test/unit/tracking/ios_engine_stop_race_test.dart` — controllable `StreamController<Position>`; late sample dropped after stop
- [ ] Existing Phase 2 tracking tests cover the Android regression — no new infra needed

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

- [ ] All code tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers the branch, gate, and stop-race tests
- [ ] No watch-mode flags
- [ ] Feedback latency < 120 s
- [ ] The three IOS-06/07/08 device behaviors are explicitly recorded as human-gated (not silently auto-passed)
- [ ] `nyquist_compliant: true` set once the planner has mapped every task

**Approval:** pending
