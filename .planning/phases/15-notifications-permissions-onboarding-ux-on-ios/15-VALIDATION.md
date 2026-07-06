---
phase: 15
slug: notifications-permissions-onboarding-ux-on-ios
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-03
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Detailed per-task map is populated by the planner from RESEARCH.md §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) + mockito (existing) |
| **Config file** | none — uses repo `flutter test` defaults |
| **Quick run command** | `flutter test test/unit/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~60–90 seconds (current suite ~397 tests) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/` (targeted: permission service + notification + formatters)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite green + `flutter analyze` clean on touched files
- **Max feedback latency:** ~90 seconds

---

## Per-Task Verification Map

> Populated by the planner. Each Dart-side task maps to a unit test; the native
> Live Activity surface and on-device permission/Live-Activity behavior are
> manual-only (see below) and gate the phase as `human_needed`, mirroring Phase 14.

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| (planner fills) | — | — | IOS-09/10/11/13/14 | unit / manual | `flutter test ...` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **Device provisioning probe (BLOCKING, manual):** Confirm the personal-team free-provisioning profile can provision an **App Group** entitlement shared between `Runner` and a new `TraevyLiveActivity` Widget Extension target. Per RESEARCH.md this is LOW-confidence and MUST pass on a real iPhone before any Swift/Widget-Extension code is written. If it fails, the Live Activity (IOS-13) approach must be reconsidered before further work.
- [ ] Test stubs for the iOS branch of `TrackingPermissionService.preflight()` / `currentStatus()` (IOS-09/10 — `defaultTargetPlatform` injection seam already exists).
- [ ] Test stubs for new `formatElapsed` / shared `formatStuck` formatters (IOS-13/14 parity).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| When-In-Use → Always two-step prompt + degraded best-effort-background | IOS-09 | Real CoreLocation permission UI; Simulator can't reproduce the once-only Always upgrade prompt | On a real iPhone: onboard, grant When-In-Use; tap Start, confirm the Always system prompt; grant only When-In-Use on a fresh install and confirm degraded banner + recording proceeds |
| Notification permission (~1 week) + scheduled weekly-summary/departure-reminder fire | IOS-10 | Real UNUserNotificationCenter prompt + scheduled delivery | Trigger the notification prompt, grant, confirm scheduled notifications fire |
| No phantom tracking notification on iOS | IOS-11 | Real iOS notification shade | Start a trip on iPhone; confirm no foreground-service notification appears (only the blue location indicator / Live Activity) |
| Live Activity updates live during a backgrounded commute + Stop button ends trip + dismisses on stop | IOS-13 / SC #5 | ActivityKit on device; Simulator can't reproduce background-suspension update cadence | Start a trip on iPhone 17+/iOS 17+, lock screen, confirm Live Activity + Dynamic Island update; tap Stop from the Live Activity; confirm trip ends and activity dismisses |
| Android enriched notification shows live stats, no foreground-service regression | IOS-14 | Real Android foreground-service behavior | Record on Android; confirm enriched stats + single-shade-entry + stop works |

*Dart-side logic (permission branch, notification gate, formatters, Platform.isAndroid guard) is unit-tested and NOT manual.*

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers the device-provisioning probe + MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter (planner/checker)

**Approval:** pending
