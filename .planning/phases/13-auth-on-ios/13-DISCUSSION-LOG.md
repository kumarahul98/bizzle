# Phase 13: Auth on iOS - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-02
**Phase:** 13-auth-on-ios
**Areas discussed:** google_sign_in version strategy, iOS sign-in error/cancel UX, Android regression scope

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| iOS sign-in error/cancel UX | Safari OAuth flow cancel/failure handling | ✓ |
| google_sign_in version strategy | Keep v6.x vs upgrade to v7.x; how iosClientId is wired | ✓ |
| iOS Firebase config source | firebase_options.dart vs GoogleService-Info.plist | |
| Android regression scope | Re-verify Android sign-in vs iOS-only | ✓ |

**Note:** Pre-discussion code inspection found the codebase is already on `google_sign_in 7.2.0` (not v6.x as older docs stated), and `main.dart:83` already calls `GoogleSignIn.instance.initialize(serverClientId: ...)` with no iOS `clientId`. This reframed the "version strategy" area into "how to wire the iOS clientId," and the "error UX" area into "what to do beyond the already-implemented silent-cancel."

---

## SignIn Wiring (iOS client ID)

| Option | Description | Selected |
|--------|-------------|----------|
| Add clientId unconditionally | `initialize(serverClientId: ..., clientId: DefaultFirebaseOptions.currentPlatform.iosClientId)` — null on Android, set on iOS; no platform branch | ✓ (Claude's recommendation) |
| Platform-branch the clientId | `defaultTargetPlatform == iOS ? iosClientId : null` | |

**User's choice:** "what do you recommend" — deferred to Claude. Recommended and recorded: add `clientId` unconditionally (matches success criterion #4, no branch needed).
**Notes:** No `google_sign_in` version change — already on v7.2.0.

---

## Error UX (cancel + failure handling)

| Option | Description | Selected |
|--------|-------------|----------|
| Silent cancel + snackbar on real errors | Keep cancel silent; snackbar only on genuine failures | |
| Silent for everything | Match current behavior; no feedback | |
| Snackbar for both cancel and errors | Always show feedback, including on user-cancel | ✓ |

**User's choice:** Snackbar for both cancel and errors.
**Notes:** This intentionally changes the Phase 9 silent-cancel behavior in shared widgets (`sign_in_sheet.dart`, `onboarding_screen.dart`), which also affects Android — consistent with the Android regression decision below. Distinct copy for cancel vs failure.

---

## Android Scope (regression)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — include Android regression check | Re-verify Android sign-in after shared-code edits | ✓ |
| No — iOS-only scope | Validate iOS paths only | |

**User's choice:** Yes — include Android regression check.
**Notes:** Justified because both the `main.dart` initialize() edit and the snackbar UX change touch shared code on the Android path.

---

## Claude's Discretion

- iOS Firebase config source (firebase_options.dart vs GoogleService-Info.plist) — not selected; left to researcher/planner.
- Snackbar copy, styling, duration, and ScaffoldMessenger context per catch site.

## Deferred Ideas

- iOS `GoogleService-Info.plist` approach (discretion).
- Sign-out / account deletion (deferred since Phase 9).
- Background GPS / CoreLocation (Phase 14).
