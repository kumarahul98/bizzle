---
phase: 20-first-run-login-skip
plan: 02
subsystem: dashboard
tags: [flutter, riverpod, auth, dashboard, guest-mode, widget-tests]

# Dependency graph
requires:
  - phase: 20-first-run-login-skip
    plan: 01
    provides: No-flash root gate routing a guest into MainShell so the dashboard HomeHeader (and thus the indicator) is reachable in guest mode
  - phase: 09-authentication
    provides: sealed AuthState (AuthLoading/AuthGuest/AuthSignedIn), authStateProvider, showSignInSheet bottom sheet, state-aware Settings _AccountSection
provides:
  - "GuestConnectionIndicator: ConsumerWidget rendering a calm cloud_off IconButton only in AuthGuest; SizedBox.shrink for AuthSignedIn/AuthLoading"
  - "HomeHeader converted to a ConsumerWidget hosting the indicator beside the avatar"
  - "kCopyGuestNotConnectedTooltip copy constant"
affects: [future guest/sign-in UX work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guest-only passive indicator: exhaustive sealed AuthState switch, AuthSignedIn|AuthLoading both render shrink() so no stale badge and no first-run flash; tap reuses the existing sign-in sheet (no nagging snackbar/dialog)"
    - "Convert a StatelessWidget to a ConsumerWidget to embed an auth-aware child without changing its signed-in visual output"

key-files:
  created:
    - lib/features/dashboard/widgets/guest_connection_indicator.dart
    - test/widget/features/dashboard/guest_connection_indicator_test.dart
  modified:
    - lib/features/dashboard/widgets/home_header.dart
    - lib/config/constants.dart

key-decisions:
  - "D-06 surface: the indicator lives in the dashboard HomeHeader (MainShell has no app bar; the HomeHeader is the always-visible guest surface) — per the plan's resolved Claude's-Discretion"
  - "D-07 verified, not modified: Settings _AccountSection already (Phase 9/11) renders the guest 'Sign in to back up' CTA and hides Sign out/Cloud sync/Restore in guest mode; the existing settings_screen_test already asserts this, so no settings change was made"

requirements-completed: [AUTH-04]

# Metrics
duration: ~20min
completed: 2026-06-06
---

# Phase 20 Plan 02: Guest "Not Connected" Indicator + Sign-In CTA Summary

**A calm, non-nagging `cloud_off` indicator in the dashboard HomeHeader, shown only in guest mode and hidden once signed in/loading, that opens the existing sign-in sheet on tap (AUTH-04, SC#3, D-06); Settings' guest sign-in entry verified by the existing suite (D-07).**

## Performance
- **Duration:** ~20 min
- **Tasks:** 2 (TDD)
- **Files modified:** 4 (2 created, 2 modified)
- **Test suite:** 510 -> 514 passing (4 net new), 10 pre-existing skips, 0 failures

## Accomplishments
- `GuestConnectionIndicator` (`lib/features/dashboard/widgets/guest_connection_indicator.dart`): a `ConsumerWidget` that watches `authStateProvider` and switches exhaustively on the sealed `AuthState` (no `default`). `AuthGuest` renders a muted (`TraevyTokensExt.textMuted`) `Icons.cloud_off_outlined` `IconButton` (iconSize 20, `kCopyGuestNotConnectedTooltip`); `AuthSignedIn` and `AuthLoading` both render `SizedBox.shrink()`. `onPressed` opens the existing `showSignInSheet(context)` — user-initiated only, no auto-shown snackbar/dialog (T-20-05 mitigation).
- `HomeHeader` converted from `StatelessWidget` to `ConsumerWidget`, hosting `const GuestConnectionIndicator()` immediately before the avatar circle with a 4px gap. The avatar is retained and the signed-in appearance is unchanged (the indicator is `shrink()` once signed in). File stays at 83 lines (<100).
- Added `kCopyGuestNotConnectedTooltip = 'Not connected — sign in to back up'` to `constants.dart` (no hardcoded strings).
- New widget test (`guest_connection_indicator_test.dart`) proves: guest shows the icon (and it is an `IconButton`, NOT a `SnackBar`), signed-in hides it, loading hides it (no flash), and tapping it opens the sign-in sheet (`kCopySignInSheetHeadline` + `GoogleContinueButton` shown). Uses `_FakeAuthNotifier` + `firebaseReadyProvider=false` (no platform channels).

## Task Commits
1. **Task 1 + 2: GuestConnectionIndicator wired into HomeHeader + widget tests** — `b840196` (`[dashboard]`)

_TDD: the indicator widget test was written first and confirmed RED (compile failure — widget absent), then the constant, widget, and HomeHeader wiring were added to drive it GREEN. Committed as a single atomic `[dashboard]` change since the test and its production code are one unit._

## Decisions Made
- **D-06 surface (dashboard HomeHeader):** MainShell has no app bar; the HomeHeader is the single always-visible surface in guest mode, so the indicator lives there (the plan's resolved Claude's-Discretion).
- **D-07 verified, not modified:** the Settings `_AccountSection` already (Phase 9/11) shows the guest `kCopySettingsGuestSignIn` ('Sign in to back up') CTA and hides Sign out / Cloud sync / Restore in guest mode, and the existing `settings_screen_test.dart` already asserts exactly this (guest entry present + sign-out absent, signed-in identity present). No redundant test or code change was added.

## Deviations from Plan

### Documentation deviation
**1. SUMMARY written despite the plan's `<output>` note**
- **Issue:** The plan's `<output>` block says "NO SUMMARY file for this phase". The orchestrator instruction explicitly required writing `20-02-SUMMARY.md`.
- **Resolution:** Followed the orchestrator instruction and wrote this SUMMARY. No code impact.

### Plan task scoped down (no code change needed)
**2. settings_screen_test.dart NOT modified**
- **Found during:** Task 2
- **Issue:** The plan's Task 2 said to "extend" the settings test "only if missing". The existing suite already asserts the guest "Sign in to back up" entry is present AND that Sign out / Cloud sync / Restore are absent in guest mode (`settings_screen_test.dart` lines 500-544). D-07 is already test-covered.
- **Resolution:** Per the plan's own "do not duplicate" guidance, no change was made to `settings_screen_test.dart`. D-07 verification is satisfied by the existing green test.

**Total deviations:** 1 documentation (SUMMARY), 1 scoped-down (settings test already covers D-07). No bugs, no auto-fixes, no architectural changes.

## Verification
- `flutter analyze` on the changed code files (`guest_connection_indicator.dart`, `home_header.dart`, `guest_connection_indicator_test.dart`): **No issues found.** The pre-existing 5 `info`-level items in `constants.dart` (comment_references / long-line) are unchanged — no new analyze issues were introduced (confirmed via a `git stash` baseline comparison).
- `flutter test`: full suite **514 passed / 10 skipped / 0 failed** (was 510 passing pre-plan).

## Known Stubs
None — the indicator reads the live `authStateProvider`, renders for real guests, and its tap opens the real `showSignInSheet`.

## Threat Flags
None — no new network endpoint, auth path, or trust-boundary surface. T-20-05 (UX nagging) is mitigated: the indicator is a passive `IconButton`, asserted by the test to be an `IconButton` (not a `SnackBar`) that opens the sheet only on tap. T-20-07 (stale-badge tampering) is mitigated by the exhaustive sealed switch with `AuthSignedIn`/`AuthLoading` -> `shrink()`, asserted by the signed-in/loading tests.

## Self-Check: PASSED
- Commit `b840196` exists in history.
- Created files present on disk: `lib/features/dashboard/widgets/guest_connection_indicator.dart`, `test/widget/features/dashboard/guest_connection_indicator_test.dart`.
- Modified files present: `lib/features/dashboard/widgets/home_header.dart` (now a `ConsumerWidget`, 83 lines), `lib/config/constants.dart` (`kCopyGuestNotConnectedTooltip` added).
- Full suite green: 514 passed / 10 skipped / 0 failed; changed-file analyze clean.

---
*Phase: 20-first-run-login-skip*
*Completed: 2026-06-06*
