---
phase: 09-authentication
plan: "05"
subsystem: auth
tags: [riverpod, flutter, auth-wiring, onboarding, settings, bottom-sheet, widget-test]
dependency_graph:
  requires: [09-03, 09-04]
  provides: [sign_in_sheet, wired-onboarding, state-aware-settings-account-section]
  affects:
    - lib/features/auth/widgets/sign_in_sheet.dart
    - lib/features/onboarding/screens/onboarding_screen.dart
    - lib/features/settings/screens/settings_screen.dart
    - test/widget/features/onboarding/onboarding_screen_test.dart
    - test/widget/features/settings/settings_screen_test.dart
tech_stack:
  added: []
  patterns:
    - ConsumerStatefulWidget for sheet with loading/error/cancel state machine
    - ConsumerWidget sealed switch on AuthState for state-aware section rendering
    - Extends AuthStateNotifier for overrideWith factory type safety in tests
    - context.mounted guard after every await (trip_actions.dart discipline)
    - implements+noSuchMethod fake pattern for AuthService in widget tests
key_files:
  created:
    - lib/features/auth/widgets/sign_in_sheet.dart
    - test/widget/features/onboarding/onboarding_screen_test.dart
  modified:
    - lib/features/onboarding/screens/onboarding_screen.dart
    - lib/features/settings/screens/settings_screen.dart
    - test/widget/features/settings/settings_screen_test.dart
decisions:
  - _SignInSheetContent uses ConsumerStatefulWidget to manage _isLoading/_hasFailed state inside the sheet — no external provider needed for ephemeral UI state
  - GoogleSignIn cancel path is a silent no-op in both onboarding and sheet (stays guest, no toast) per UI-SPEC error contract
  - _FakeAuthNotifier extends AuthStateNotifier (not Notifier<AuthState>) so authStateProvider.overrideWith passes Riverpod 3.x type check
  - Onboarding non-first-sign-in path requires no explicit push — app.dart auth gate already routes MainShell when AuthSignedIn fires from the stream
  - _AccountSection drops the prefs constructor parameter entirely since it no longer uses UserPreferencesValue
metrics:
  duration: "7m"
  completed: "2026-05-29"
  tasks_completed: 3
  files_modified: 5
---

# Phase 09 Plan 05: Sign-In Entry Points Wiring Summary

**One-liner:** Modal sign-in sheet mirroring the theme-picker pattern, onboarding button wired to AuthService.signIn() with first-sign-in confirmation navigation, and state-aware settings Account section switching on AuthState — all covered by injectable widget tests.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Build the sign-in bottom sheet (D-08, UI-SPEC §B) | 4e289bb | lib/features/auth/widgets/sign_in_sheet.dart |
| 2 | Wire onboarding + settings _AccountSection | feec1cc | lib/features/onboarding/screens/onboarding_screen.dart, lib/features/settings/screens/settings_screen.dart |
| 3 | Extend onboarding + settings widget tests | 3808c37 | test/widget/features/onboarding/onboarding_screen_test.dart, test/widget/features/settings/settings_screen_test.dart |

## What Was Built

### Task 1 — Sign-In Bottom Sheet

`lib/features/auth/widgets/sign_in_sheet.dart` exposes `Future<void> showSignInSheet(BuildContext context)` using the exact `_openThemePicker` pattern (`showModalBottomSheet` with `surfaceContainerLowest` background, `showDragHandle: true`, dismissable).

The builder returns `_SignInSheetContent`, a `ConsumerStatefulWidget` managing `_isLoading` and `_hasFailed` state. Content order per UI-SPEC §B: Google glyph (20px) → headline (`kCopySignInSheetHeadline`, Inter 22px w700, letterSpacing -0.6) → 12px gap → subtext (`kCopySignInSheetSubtext`, Inter 16px textDim) → error copy block (shown when `_hasFailed`) → 24px gap → `GoogleContinueButton`.

State machine:
- `firebaseReady=false`: Opacity(0.38) + Tooltip(kCopySignInDisabledTooltip) + Semantics(enabled:false) on the button (T-09-05-03)
- `_isLoading=true`: Same disabled treatment during in-flight sign-in
- Sign-in success: `Navigator.of(context).pop()` after `context.mounted` guard
- `GoogleSignInException` (cancel): silent no-op, `_isLoading=false`, sheet stays open (T-09-05-01)
- Other errors: `_hasFailed=true`, shows `kCopySignInFailedHeadline` / `kCopySignInFailedBody`, CTA re-enabled (T-09-05-02)

No `SignInSuccessScreen` push from the sheet — the Account section re-renders via `authStateProvider`.

### Task 2 — Onboarding + Settings Wiring

**Onboarding (`lib/features/onboarding/screens/onboarding_screen.dart`):**
- Converted `StatelessWidget` → `ConsumerWidget` (build gains `WidgetRef ref`)
- `GoogleContinueButton.onTap` wired to `() async { final firstSignIn = await ref.read(authServiceProvider).signIn(); if (!context.mounted) return; if (firstSignIn) { Navigator.push(SignInSuccessScreen(initial: ...)) } }`
- Initial derived from `ref.read(authStateProvider)` sealed switch on `AuthSignedIn(:name)` after `signIn()` resolves
- `GoogleSignInException` → silent no-op; other errors → silent (sheet owns rich copy)
- `firebaseReady=false` → disabled button with Opacity + Tooltip + Semantics

**Settings (`lib/features/settings/screens/settings_screen.dart`):**
- `_AccountSection` converted `StatelessWidget` → `ConsumerWidget`, drops `prefs` parameter
- Sealed switch on `ref.watch(authStateProvider)`:
  - `AuthSignedIn(:name, :email)` → `AccountRow(name: name, email: email, initial: name[0].toUpperCase())`
  - `AuthGuest()` / `AuthLoading()` → `SettingsRow(label: kCopySettingsGuestSignIn, onTap: () => showSignInSheet(context))`
- Cloud sync, Restore from cloud, Sign out rows kept as-is (no new wiring)
- Call site in `SettingsScreen.build` updated: `_AccountSection(prefs: prefs)` → `const _AccountSection()`

### Task 3 — Widget Tests

**`test/widget/features/onboarding/onboarding_screen_test.dart` (new):**
- `_FakeAuthService implements AuthService` with `signInCallCount` capture
- `_FakeAuthNotifier extends AuthStateNotifier` for type-safe `overrideWith`
- `_pumpOnboardingScreen` helper with `authServiceProvider`, `firebaseReadyProvider`, `authStateProvider` overrides
- 4 tests: tap invokes signIn(); two taps = two calls; disabled (Semantics enabled:false) when `firebaseReady=false`; tooltip present when disabled

**`test/widget/features/settings/settings_screen_test.dart` (extended):**
- Added `_FakeAuthNotifier extends AuthStateNotifier`
- `_pumpSettingsScreen` gains `authState` param (defaults to `AuthGuest()`)
- Existing "renders AccountRow with placeholder" test updated to supply `AuthSignedIn` state
- New group "SettingsScreen _AccountSection — state-aware": guest → `kCopySettingsGuestSignIn` present / no AccountRow; signed-in → AccountRow with real name+email; Sign out row has no InkWell descendant

## Verification Results

- `flutter analyze lib/features/auth/widgets/ lib/features/onboarding/ lib/features/settings/` — zero issues
- `flutter test` — 304 passed, 10 skipped (pre-existing Wave 0 stubs)
- `grep "showModalBottomSheet"` in sign_in_sheet.dart — found; `surfaceContainerLowest` + `showDragHandle: true` confirmed
- `grep "GoogleContinueButton"` in sign_in_sheet.dart — found (reused, not rebuilt)
- `grep "authServiceProvider).signIn"` in onboarding_screen.dart — found
- `grep "ShowSignInSheet\|showSignInSheet"` in settings_screen.dart — found
- `grep "Sign out"` in settings_screen.dart — present, no `onTap` wired
- `flutter test test/widget/features/onboarding/ test/widget/features/settings/` — 17 tests, all GREEN

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Existing settings test broke when _AccountSection became state-aware**

- **Found during:** Task 2 verification (full test suite)
- **Issue:** The existing test "renders AccountRow with placeholder name+initial" passed `_pumpSettingsScreen` without an `authStateProvider` override. After converting `_AccountSection` to a `ConsumerWidget`, the default provider state (`firebaseReady=false` → `AuthGuest`) rendered the guest row, not the AccountRow, causing `findsOneWidget` to fail on `AccountRow`.
- **Fix:** Updated `_pumpSettingsScreen` to accept an `authState` parameter (defaults to `AuthGuest`), updated the failing test to supply `AuthSignedIn` state. This was addressed in the same task commit as the other test extensions.
- **Files modified:** `test/widget/features/settings/settings_screen_test.dart`
- **Commit:** 3808c37

**2. [Rule 3 - Blocking] Riverpod 3.x `overrideWith` requires exact Notifier subtype**

- **Found during:** Task 3 compilation
- **Issue:** The initial `_FakeAuthNotifier extends Notifier<AuthState>` failed to compile because `authStateProvider.overrideWith` expects a factory returning `AuthStateNotifier`, not any `Notifier<AuthState>`. Riverpod 3.x's `NotifierProvider.overrideWith` enforces the exact declared notifier type.
- **Fix:** Changed both `_FakeAuthNotifier` classes (in settings and onboarding tests) to `extends AuthStateNotifier`, which overrides only `build()` to return the fixed state without subscribing to Firebase streams.
- **Files modified:** `test/widget/features/onboarding/onboarding_screen_test.dart`, `test/widget/features/settings/settings_screen_test.dart`
- **Commit:** 3808c37

## Known Stubs

None — all entry points are fully wired.
- `showSignInSheet` calls real `AuthService.signIn()` via the injected `authServiceProvider`
- `OnboardingScreen` calls real `authServiceProvider.signIn()` and navigates to `SignInSuccessScreen` on first sign-in
- `_AccountSection` watches real `authStateProvider` and renders `AccountRow` with real Firebase `displayName`/`email`

The only deferred items are outside this plan's scope:
- Sign-out wiring (deferred, Sign out row is a no-op visual)
- Cloud sync / Restore from cloud (deferred to Phase 11)

## Threat Flags

No new security surface beyond what the plan's threat model covers:

- T-09-05-01 (DoS/self — cancel): `GoogleSignInException` caught → silent no-op in both sheet and onboarding handlers
- T-09-05-02 (Info disclosure — error copy): only generic `kCopySignInFailedBody` shown; no token/credential logged anywhere in sign_in_sheet.dart or onboarding_screen.dart
- T-09-05-03 (Spoofing — unconfigured): `firebaseReady=false` disables button with opacity + tooltip + `Semantics(enabled:false)` in both surfaces

## Self-Check: PASSED

- `lib/features/auth/widgets/sign_in_sheet.dart` — FOUND
- `lib/features/onboarding/screens/onboarding_screen.dart` — FOUND (modified)
- `lib/features/settings/screens/settings_screen.dart` — FOUND (modified)
- `test/widget/features/onboarding/onboarding_screen_test.dart` — FOUND
- `test/widget/features/settings/settings_screen_test.dart` — FOUND (modified)
- Commit 4e289bb — FOUND
- Commit feec1cc — FOUND
- Commit 3808c37 — FOUND
