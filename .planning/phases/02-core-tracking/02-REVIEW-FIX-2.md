---
phase: 02-core-tracking
fixed_at: 2026-04-12T00:00:00Z
review_path: inline-spec (UX-03 gap-closure, no separate REVIEW.md)
iteration: 2
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 02: Code Review Fix Report (Iteration 2)

**Fixed at:** 2026-04-12
**Source review:** Inline UX-03 gap-closure spec (no separate REVIEW.md)
**Iteration:** 2

**Summary:**
- Findings in scope: 1
- Fixed: 1
- Skipped: 0

## Fixed Issues

### UX-03-01: POST_NOTIFICATIONS runtime permission never requested on Android 13+

**Files modified:**
- `lib/features/tracking/services/tracking_permission_service.dart`
- `lib/features/tracking/widgets/permission_gate.dart`
- `lib/features/tracking/screens/tracking_screen.dart`
- `lib/features/tracking/screens/home_screen.dart`
- `test/unit/features/tracking/tracking_permission_service_test.dart`
- `test/widget/features/tracking/home_screen_test.dart`

**Commits:**
- `6e2ff02` fix(02-1): UX-03 add notification permission step to TrackingPermissionService
- `b8a7777` fix(02-1): UX-03 wire notificationDenied through HomeScreen dialog and PermissionGate
- `704ef7c` fix(02-1): UX-03 add notification permission test coverage

**Applied fix:**

1. **TrackingPermissionService — enum + four-step dance.** Added a fifth
   variant `TrackingPermissionStatus.notificationDenied` that leaves the
   four original semantics untouched. Extended `preflight()` with a
   third probe/request step for `Permission.notification` that runs
   ONLY after the location dance resolves to fully-granted or
   foreground-only. Extended `currentStatus()` with a matching
   probe-only step so build-time callers never trigger a system prompt.
   Both ordering invariants are preserved: `locationAlways` still never
   fires before `locationWhenInUse` resolves granted, and `notification`
   never fires before the full location dance resolves (so a user who
   denies fine location is never asked about notifications).

2. **PermissionGate widget.** Replaced the two-branch `isPermanent`
   conditional with a pattern-matched switch over the enum, adding a
   dedicated `notificationDenied` branch whose title is "Notifications
   are required to track commutes in the background" and whose button
   opens system settings. The two non-blocking variants
   (`fullyGranted` / `foregroundOnly`) fall through to a neutral
   defensive fallback because PermissionGate is only ever rendered by
   the tracking screen for blocking states.

3. **TrackingScreen branch guard.** Extended the
   `denied`/`permanentlyDenied` block to also intercept
   `notificationDenied`, wiring its CTA to `openSystemSettings()` (the
   only reliable route on Android 13+ once the user has hit "Don't
   allow"). Re-check happens implicitly on the next preflight run.

4. **HomeScreen Start-tap gate.** Added a second branch alongside the
   existing `permanentlyDenied` dialog: on `notificationDenied`,
   HomeScreen shows a "Notifications required" dialog with a
   Cancel / Open settings pair and does NOT call
   `Navigator.pushNamed('/tracking')`. Factored the dialog helper into
   a parameterised method so the two blocking cases share a single
   implementation.

5. **Unit tests.** Rewrote the service tests to cover the full
   four-step matrix. Eleven preflight tests now pin every ordering
   invariant (fine short-circuits, locationAlways ordering,
   notification ordering after the full location dance, no-request
   when probe already granted, fully-granted via request flow) plus
   the two new notificationDenied paths. Six currentStatus tests
   cover the mirrored probe-only cases plus the critical "requester
   is never touched even when notification is denied" invariant.

6. **Widget tests.** Replaced the single-`PermissionStatus` harness
   with a per-permission probe/requester map so every
   `TrackingPermissionStatus` value resolves with the correct
   four-step probe sequence. Added two tests for the
   notificationDenied path: "tapping Start shows the Notifications
   required dialog and does NOT navigate" and "tapping Open settings
   invokes the opener".

**Verification performed:**

- `flutter analyze` → 0 issues across the entire project
- `flutter test` → 93/93 passing (includes all 18 permission service
  unit tests + all 6 HomeScreen widget tests + all existing tests)
- `flutter build apk --debug` → success (compileSdk 36, minSdk 34)

**Logic status:** `fixed` — the logic is exhaustively covered by
new unit tests (ordering invariants, short-circuits, probe-only
classification) and widget tests (Start gate, dialog body, Open
Settings delegation). No human verification required beyond the
existing test coverage.

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
