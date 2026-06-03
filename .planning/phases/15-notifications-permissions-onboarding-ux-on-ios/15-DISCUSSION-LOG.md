# Phase 15: Notifications, Permissions & Onboarding UX on iOS - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-03
**Phase:** 15-notifications-permissions-onboarding-ux-on-ios
**Areas discussed:** "Always" prompt timing, When-In-Use degraded mode, Notification decoupling on iOS, Onboarding priming, Live Activity / Dynamic Island (scope expansion)

---

## "Always" prompt timing

| Option | Description | Selected |
|--------|-------------|----------|
| At first trip Start | When-In-Use in onboarding, Always at first Start (Apple's contextual pattern) | ✓ |
| Immediately in onboarding | When-In-Use then Always back-to-back (Android-style) | |
| After first completed trip | First trip records under When-In-Use, prompt Always afterward | |

**User's choice:** At first trip Start.
**Notes:** Follow-up — when still When-In-Use-only on a later Start (iOS won't re-prompt), proceed degraded + dismissible "Open Settings" hint (chosen over an explainer sheet or silent proceed).

---

## When-In-Use degraded mode

| Option | Description | Selected |
|--------|-------------|----------|
| Best-effort background, warn it may stop | Stream with allowBackgroundLocationUpdates=true, warn of possible gaps | ✓ |
| Foreground-only, pause when backgrounded | Treat as keep-app-open recording | |
| Block recording until Always granted | Refuse trips until Always (contradicts SC #1) | |

**User's choice:** Best-effort background, warn it may stop.
**Notes:** Surface via the existing `permission_banner` / `foregroundOnly` state with iOS-specific copy (chosen over a new iOS-only widget or inline-hint-only).

---

## Notification decoupling on iOS

| Option | Description | Selected |
|--------|-------------|----------|
| Platform-branch preflight | iOS preflight ends after location; never probes notification; never blocks Start | ✓ |
| Keep step, downgrade severity on iOS | Still probe notification on iOS but non-blocking | |

**User's choice:** Platform-branch preflight.
**Notes:** Timing — user chose (free-text) "after 1 week of usage" over per-reminder or onboarding asks. Captured as weekly-summary-timed (~1 week), with an edge: request earlier if a departure reminder is enabled before then.

---

## Onboarding priming

| Option | Description | Selected |
|--------|-------------|----------|
| Prime location only | One priming screen before When-In-Use; no Always/notification priming | ✓ |
| Prime every permission | Priming for location, Always, notifications up front | |
| No priming, inline prompts | Straight to system prompts (current Android model) | |

**User's choice:** Prime location only.

---

## Live Activity / Dynamic Island (scope expansion)

**Origin:** User asked whether the app could use Apple Live Activities / Dynamic Island, and what the Android equivalent is. Claude explained: technically a strong fit but requires a native ActivityKit Widget Extension + Flutter bridge; Android's equivalent is the existing ongoing foreground notification (UX-03); and it contradicts the locked SC #3.

| Disposition option | Description | Selected |
|--------|-------------|----------|
| Defer to its own phase | Keep Phase 15 minimal; new phase for Live Activity | |
| Pull into Phase 15 scope now | Expand Phase 15, rewrite SC #3 | ✓ |
| Note it, decide later | Record as deferred idea | |

**User's choice:** Pull into Phase 15 scope now.

| Structure option | Description | Selected |
|--------|-------------|----------|
| New dedicated phase right after 15 | Phase 15 minimal, separate Live Activity phase | |
| Expand Phase 15 to include it | Rewrite SC #3, plan permissions + Live Activity together | ✓ |
| Spike it first | Throwaway spike to prove backgrounded updates | |

**User's choice:** Expand Phase 15 to include it.

| Content option | Description | Selected |
|--------|-------------|----------|
| Live stats + tap-to-open | Display-only, iOS 16.1+ | |
| Live stats + in-place Stop button | Stop in the Live Activity (App Intents, iOS 17+) | ✓ |
| Minimal (timer only) | Elapsed + indicator, tap to open | |

**User's choice:** Live stats + in-place Stop button.

| Fallback option | Description | Selected |
|--------|-------------|----------|
| Graceful tiering | 17+ full, 16.x display-only, <16.1 blue bar | |
| iOS 17+ only, blue-bar below | Only the 17+ version; below → blue bar | |
| Decide floor during research | Leave tiering to research | |

**User's choice:** (free-text) "iOS apps 17+ only as the userbase on older iOS versions is less than 10%." → iOS 17+ floor; below 17 degrades to blue-bar + in-app Stop, no 16.x middle tier.

| Android option | Description | Selected |
|--------|-------------|----------|
| Leave Android as-is | Keep existing ongoing notification unchanged | |
| Enrich the Android notification to match | Show same stats layout for parity | ✓ |
| Android Live Updates (16+) | Adopt Android 16 Live Updates API | |

**User's choice:** Enrich the Android notification to match.
**Notes:** Hard constraint flagged — no regression to the foreground-service binding.

---

## Claude's Discretion
- Live Activity bridge: `live_activities` plugin vs custom platform channel (decide in research).
- Dynamic Island compact/minimal/expanded layouts (UI-SPEC / planning).
- Exact "1 week of usage" anchor for the notification prompt.
- Stop App Intent wiring: direct end vs deep-link + end to `TrackingServiceController.stop()`.

## Deferred Ideas
- Android 16 "Live Updates" API as a true Live-Activity analog — future phase.
- iOS 16.1–16.x display-only Live Activity middle tier — explicitly cut.

## Scope-change record
- Phase 15 SC #3 rewritten and SC #5/#6 added in ROADMAP.md; IOS-13 (Live Activity) + IOS-14 (Android notification parity) added to REQUIREMENTS.md (v0.2 count 12 → 14). Recorded 2026-06-03 during this discussion.
