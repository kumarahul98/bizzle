---
phase: 09-authentication
plan: "01"
subsystem: auth
tags: [firebase, google-sign-in, flutter-secure-storage, wave-0, red-tests, constants]
dependency_graph:
  requires: []
  provides:
    - firebase_core, firebase_auth, google_sign_in, flutter_secure_storage packages
    - Phase 9 constants (kGoogleServerClientId, kFirebaseIdTokenKey, kDisabledSignInOpacity, kCopy*)
    - kRouteSignInSuccess route name
    - google_sign_in 7.2.0 verified idToken path (account.authentication.idToken)
    - Wave 0 RED contracts for AuthStateNotifier, AuthService, backfillUserId
  affects:
    - lib/config/constants.dart
    - lib/config/routes.dart
    - pubspec.yaml / pubspec.lock
    - test/unit/features/auth/ (4 new files)
    - .planning/phases/09-authentication/09-VALIDATION.md
tech_stack:
  added:
    - firebase_core 4.9.0
    - firebase_auth 6.5.1
    - google_sign_in 7.2.0
    - flutter_secure_storage 10.3.1 (resolver picked 10.3.1, plan expected 9.2.4)
  patterns:
    - Wave-0 compile-probe test for API surface verification
    - Hand-rolled fakes via implements+noSuchMethod for secure storage (AppleOptions for v10.3.1)
    - In-memory Drift via NativeDatabase.memory() for backfill contract tests
key_files:
  created:
    - test/unit/features/auth/google_sign_in_api_probe_test.dart
    - test/unit/features/auth/auth_state_notifier_test.dart
    - test/unit/features/auth/auth_service_test.dart
    - test/unit/features/auth/backfill_test.dart
  modified:
    - pubspec.yaml (4 new deps)
    - pubspec.lock (resolved + committed)
    - lib/config/constants.dart (Phase 9 constants block)
    - lib/config/routes.dart (kRouteSignInSuccess)
    - .planning/phases/09-authentication/09-VALIDATION.md (verification map + Wave 0 status)
decisions:
  - flutter_secure_storage resolved to 10.3.1 not 9.2.4; API uses AppleOptions not IOSOptions/MacOsOptions — fake updated accordingly
  - kRouteSignInSuccess NOT added to kAppRoutes (Plan 04 owns the screen; pushed as MaterialPageRoute)
  - Probe test uses GoogleSignInAuthentication const constructor (no platform channel) — pure Dart instantiation
  - backfill_test.dart uses real in-memory Drift DAOs (not fakes) to test the actual SQL UPDATE behavior
metrics:
  duration: "8 minutes"
  completed_date: "2026-05-29"
  tasks_completed: 3
  files_changed: 9
---

# Phase 09 Plan 01: Authentication Foundation (Wave 0) Summary

FlutterFire trio + flutter_secure_storage installed and resolved; google_sign_in 7.2.0 idToken path pinned via compile-probe (account.authentication.idToken); all Phase 9 string/key/route constants added; three Wave 0 RED test contracts written for AUTH-01/02/03.

## What Was Built

### Task 1: FlutterFire dependency set + Phase 9 constants + kRouteSignInSuccess

Added four production dependencies to `pubspec.yaml`:
- `firebase_core: ^4.9.0` — Firebase app initialization
- `firebase_auth: ^6.5.1` — Firebase Authentication
- `google_sign_in: ^7.2.0` — native Android Google account picker (v7 API)
- `flutter_secure_storage: ^10.3.1` — Android Keystore token cache

The resolver picked `flutter_secure_storage 10.3.1` (newer than the 9.2.4 in the research doc). Both `pubspec.yaml` and `pubspec.lock` are committed, satisfying the Pitfall 4 mitigation (no partial FlutterFire upgrades in isolation).

Added to `lib/config/constants.dart` (Phase 9 block):
- `kGoogleServerClientId` — Web OAuth client ID placeholder (to be filled after `flutterfire configure`)
- `kFirebaseIdTokenKey = 'firebase_id_token'` — secure storage key for cached ID token
- `kDisabledSignInOpacity = 0.38` — Material M3 disabled-state opacity for Firebase-unconfigured builds
- `kCopySignInSheetHeadline`, `kCopySignInSheetSubtext`, `kCopySettingsGuestSignIn`, `kCopyConfirmHeadline`, `kCopyConfirmBody`, `kCopyConfirmCta`, `kCopySignInDisabledTooltip`, `kCopySignInFailedHeadline`, `kCopySignInFailedBody` — all UI-SPEC copy strings

Added to `lib/config/routes.dart`:
- `kRouteSignInSuccess = '/sign-in-success'` — reserved route name for the one-time confirmation screen (D-12); not added to `kAppRoutes` as Plan 04 will push it as a `MaterialPageRoute`.

### Task 2: google_sign_in 7.x API surface probe

Created `test/unit/features/auth/google_sign_in_api_probe_test.dart` — 8 passing tests that pin the exact v7 API surface against the installed `google_sign_in 7.2.0` package.

**VERIFIED idToken access path:** `account.authentication.idToken`
- `account` is `GoogleSignInAccount` (returned by `GoogleSignIn.instance.authenticate()`)
- `.authentication` is a SYNCHRONOUS getter (no `await`) returning `GoogleSignInAuthentication`
- `.idToken` is `String?` (nullable; null when `serverClientId` is absent — RESEARCH Pitfall 2)

Confirmed symbols:
- `GoogleSignIn.instance` — static singleton (v7 replaces `GoogleSignIn()` constructor)
- `GoogleSignIn.instance.initialize({serverClientId:})` — one-time setup
- `GoogleSignIn.instance.authenticate()` — interactive sign-in
- `GoogleSignIn.instance.supportsAuthenticate()` — platform capability check
- `GoogleAuthProvider.credential(idToken:)` — pure Dart; no platform channel

Resolves RESEARCH Open Question A2 before any `AuthService` code is written.

### Task 3: Wave 0 RED behaviour contracts

Created three test files that define the AUTH-01/02/03 behaviour contracts. All three are intentionally RED (compile failure on missing symbols) — the intended Wave 0 state.

**`auth_state_notifier_test.dart`** (AUTH-01, AUTH-02) contracts:
- `AuthLoading`, `AuthGuest`, `AuthSignedIn` are `const`-constructible sealed subtypes
- Exhaustive `switch` over `AuthState` compiles without a `default` branch
- `firebaseReady=false` → `AuthGuest` immediately (D-15 degrade path)
- `user.displayName == null` → falls back to `kPlaceholderUserName`
- `authStateChanges` null → `AuthGuest`; non-null user → `AuthSignedIn(uid, name, email)`

**`auth_service_test.dart`** (AUTH-01, AUTH-02) contracts:
- `signIn()` writes Firebase ID token to `kFirebaseIdTokenKey` in secure storage
- Token is NEVER logged (security contract)
- `signIn()` calls `tripsDao.backfillUserId(uid)` and `prefsDao.backfillUserId(uid)`
- `signIn()` returns `true` when trips backfill changed > 0 rows (first sign-in signal for D-12)
- `signIn()` returns `false` when 0 rows changed (already signed in)
- Uses hand-rolled `implements ... noSuchMethod` fakes matching installed v10.3.1 API (`AppleOptions?`)

**`backfill_test.dart`** (AUTH-03) contracts:
- `tripsDao.backfillUserId(uid)` rewrites all `user_id = kDefaultUserId` trips rows
- Returns the changed-row count (first-sign-in signal)
- Second call returns `0` (idempotent)
- Returns `0` on empty table
- Does not touch rows with non-`kDefaultUserId` `user_id`
- `userPreferencesDao.backfillUserId(uid)` rewrites the single prefs row
- Combined backfill simulates `AuthService.signIn()` orchestration

Uses real in-memory Drift (`NativeDatabase.memory()`) — no platform channels. `09-VALIDATION.md` verification map populated with all four task rows.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `flutter_secure_storage` version mismatch: IOSOptions → AppleOptions**
- **Found during:** Task 3 (auth_service_test.dart compilation)
- **Issue:** The plan cited `flutter_secure_storage ^9.2.4`; the resolver picked `10.3.1`. In v10, the `iOptions` and `mOptions` parameters of `write()`/`read()` changed from `IOSOptions?`/`MacOsOptions?` to `AppleOptions?` (Apple platform unification).
- **Fix:** Updated the `_FakeSecureStorage` fake in `auth_service_test.dart` to use `AppleOptions?` to match the installed API signature.
- **Files modified:** `test/unit/features/auth/auth_service_test.dart`
- **Commit:** f440d6f

**2. [Rule 2 - Missing] `UserPreferencesDao` import missing from backfill_test.dart**
- **Found during:** Task 3 (backfill_test.dart compilation)
- **Issue:** `UserPreferencesValue` is defined in `user_preferences_dao.dart` but the import was absent.
- **Fix:** Added `import 'package:traevy/database/daos/user_preferences_dao.dart';`
- **Files modified:** `test/unit/features/auth/backfill_test.dart`
- **Commit:** f440d6f

**3. [Rule 1 - Bug] Lint: `[AuthGuest]`, `[MainShell]` doc comment references not in scope**
- **Found during:** Task 1 (`flutter analyze lib/config/`)
- **Issue:** `very_good_analysis` fires `comment_references` for doc-comment symbol links that aren't imported in the file being analyzed.
- **Fix:** Changed `[AuthGuest]` → "the guest auth state" and `[MainShell]` → "the main shell" in constants.dart and routes.dart comments.
- **Files modified:** `lib/config/constants.dart`, `lib/config/routes.dart`
- **Commit:** 2a86915

### Pre-existing Issue (Out of Scope)

Line 232 of `lib/config/constants.dart` exceeds 80 characters — a pre-existing Phase 2 comment about `kTrackingNotificationRefreshInterval`. Not introduced by this plan; deferred per deviation scope rules.

## Wave 0 Status

| File | Status | Pins / Tests |
|------|--------|-------------|
| google_sign_in_api_probe_test.dart | GREEN (8 tests pass) | v7 API surface + idToken path |
| auth_state_notifier_test.dart | RED (compile fail) | AuthState/AuthStateNotifier/providers |
| auth_service_test.dart | RED (compile fail) | AuthService |
| backfill_test.dart | RED (compile fail) | TripsDao/UserPreferencesDao.backfillUserId |

RED files become GREEN when Plans 09-02 (models, providers, DAOs) and 09-03 (AuthService) execute.

## Known Stubs

- `kGoogleServerClientId = 'REPLACE_WITH_WEB_CLIENT_ID_FROM_FIREBASE_CONSOLE'` — intentional placeholder; filled after the human `flutterfire configure` step (gated checkpoint before Plan 09-03). This does not block any code in this plan.

## Threat Flags

No new network endpoints, auth paths, or file access patterns introduced. The constants added are build-time config (public client identifiers — T-09-01-01 disposition: accept). T-09-01-02 and T-09-01-03 mitigations verified: pubspec.lock committed (Pitfall 4) and `cloud_firestore` confirmed absent (`grep -c cloud_firestore pubspec.yaml == 0`).

## Self-Check: PASSED
