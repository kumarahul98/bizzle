---
phase: 9
slug: authentication
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) |
| **Config file** | `test/flutter_test_config.dart` (exists from Phase 8) |
| **Quick run command** | `flutter test test/unit/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green + `flutter analyze` zero warnings
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 0 | AUTH-01 | — | google_sign_in v7 `authenticate()` → `idToken` path confirmed against installed package | unit | `flutter test test/unit/auth/` | ❌ W0 | ⬜ pending |

*Populated by the planner during planning. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/auth/auth_state_test.dart` — sealed `AuthState` (loading/guest/signedIn) transitions
- [ ] `test/unit/auth/auth_service_test.dart` — sign-in sequence + userId backfill (mocked FirebaseAuth/GoogleSignIn)
- [ ] Confirm `google_sign_in 7.x` exact `authenticate()` / `idToken` API surface against the installed package (Open Question A2)

*Planner refines this list during planning.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real Google account sign-in on a device | AUTH-01 | Requires live Firebase project + registered SHA + a real Google account; cannot run in CI | Build with `google-services.json` present; tap "Continue with Google" on onboarding; complete Google picker; confirm landing on confirmation screen then MainShell |
| Session survives app restart | AUTH-02 | FlutterFire session persistence is device-level | Sign in, kill app, relaunch; confirm app opens signed-in without re-auth |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
