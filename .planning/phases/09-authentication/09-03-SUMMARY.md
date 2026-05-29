---
phase: 09-authentication
plan: "03"
subsystem: auth
tags: [riverpod, firebase-auth, google-sign-in, secure-storage, notifier, degrade]
dependency_graph:
  requires: [09-01, 09-02]
  provides: [authStateProvider, authServiceProvider, firebaseReadyProvider, Firebase bootstrap]
  affects: [lib/main.dart, lib/features/auth/providers/, lib/features/auth/services/]
tech_stack:
  added: []
  patterns:
    - Notifier<T> + stream subscription in build() + ref.onDispose cancel
    - Provider injection as overridable seam (firebaseAuthProvider, googleSignInProvider, secureStorageProvider)
    - ProviderScope.overrideWithValue for boot-time Firebase degrade flag
    - google_sign_in v7 authenticate() + synchronous .authentication.idToken access
    - Transaction-wrapped DAO orchestration (backfillUserId atomic)
key_files:
  created:
    - lib/features/auth/services/auth_service.dart
  modified:
    - lib/features/auth/providers/auth_providers.dart
    - lib/main.dart
decisions:
  - AuthService constructor takes optional firebaseAuth/googleSignIn — lazily resolved at signIn()-call time, not construction time, so test code can build AuthService without a live Firebase app present
  - firebaseReady flag injected via ProviderScope.overrideWithValue (not hardcoded) so the notifier cleanly degrades to AuthGuest without subscribing on an uninitialised Firebase SDK
  - on Object catch (_) used in main.dart Firebase try/catch to satisfy very_good_analysis avoid_catches_without_on_clauses rule
metrics:
  duration: "5m"
  completed: "2026-05-29"
  tasks_completed: 3
  files_modified: 3
---

# Phase 09 Plan 03: Auth Logic Layer (Providers + Service + main.dart Bootstrap) Summary

**One-liner:** Injectable Riverpod provider graph with FirebaseAuth stream-driven `AuthStateNotifier`, `AuthService` performing the google_sign_in v7 exchange with token caching + transactional backfill, and `main.dart` Firebase bootstrap with try/catch degrade-to-guest.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Auth provider graph + AuthStateNotifier | 166c79b | lib/features/auth/providers/auth_providers.dart |
| 2 | AuthService — sign-in, token cache, backfill | 166c79b | lib/features/auth/services/auth_service.dart |
| 3 | main.dart Firebase init + firebaseReady override | efbd737 | lib/main.dart |

## What Was Built

### Task 1 — Auth provider graph + AuthStateNotifier

`lib/features/auth/providers/auth_providers.dart` was completed from its Plan 02 shell into a full implementation:

- **`firebaseReadyProvider`** — `Provider<bool>` defaulting to `false`; injected from `main.dart` via `overrideWithValue`. Tests and dev builds without `google-services.json` get `false` automatically.
- **`firebaseAuthProvider`** — overridable `Provider<FirebaseAuth>` so tests never hit `FirebaseAuth.instance`.
- **`googleSignInProvider`** — overridable `Provider<GoogleSignIn>` for the same reason.
- **`secureStorageProvider`** — overridable `Provider<FlutterSecureStorage>` for token-write assertions.
- **`authServiceProvider`** — `Provider<AuthService>` injecting all five dependencies via `ref.watch`.
- **`authStateProvider`** — `NotifierProvider<AuthStateNotifier, AuthState>`.
- **`AuthStateNotifier extends Notifier<AuthState>`** — subscribes to `FirebaseAuth.authStateChanges()` in `build()`, cancels in `ref.onDispose`, maps `null→AuthGuest` / `user→AuthSignedIn(uid, name, email)`. When `firebaseReady=false`, returns `AuthGuest` immediately without opening a subscription (D-15). PII guard in `onError`: never forwards `error.toString()`.

### Task 2 — AuthService

`lib/features/auth/services/auth_service.dart` implements `Future<bool> signIn()`:

1. Guards `supportsAuthenticate()` before calling `authenticate()` (google_sign_in v7).
2. Reads `account.authentication.idToken` (synchronous getter verified in the probe test).
3. Builds `GoogleAuthProvider.credential(idToken: ...)` and calls `signInWithCredential()`.
4. Caches the Firebase ID token via `secureStorage.write(key: kFirebaseIdTokenKey, ...)`. No logging of the token anywhere.
5. Backfills both DAOs inside `db.transaction(...)` before returning (Pitfall 7 ordering).
6. Returns `tripsChanged > 0` (D-12 first-sign-in signal).

Constructor accepts optional `firebaseAuth`, `googleSignIn`, `db` — lazily accessed only during `signIn()` so tests can construct `AuthService` without a live Firebase app.

### Task 3 — main.dart Firebase bootstrap

`lib/main.dart` gains step 5 in the bootstrap sequence:

```dart
var firebaseReady = false;
try {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
  firebaseReady = true;
} on Object catch (_) {
  firebaseReady = false;
}
runApp(ProviderScope(
  overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
  child: const TraevyApp(),
));
```

## Verification Results

- `flutter test test/unit/features/auth/` — 24 tests passed, 10 skipped (Wave 0 RED stubs pending fake Firebase injection)
- `flutter test` (full suite) — 297 passed, 10 skipped
- `flutter analyze lib/features/auth/ lib/main.dart` — zero issues
- `grep "extends Notifier<AuthState>"` — found; no `StateNotifier` in production code
- `grep -iE "print\(|log\(|debugPrint"` in auth_service.dart — only in comments

## Deviations from Plan

None — plan executed exactly as written, with one minor deviation:

**1. [Rule 2 - Missing critical functionality] Lazy Firebase singleton access in AuthService constructor**

- **Found during:** Task 2 verification
- **Issue:** `AuthService` constructor used `_firebaseAuth = firebaseAuth ?? FirebaseAuth.instance` which called `FirebaseAuth.instance` at construction time. The test `AuthService is constructible with injected fakes` (which passes no `firebaseAuth`) failed with `[core/no-app] No Firebase App '[DEFAULT]' has been created`.
- **Fix:** Changed `_firebaseAuthOverride` and `_googleSignInOverride` to be stored as optional fields with lazy computed getters that fall back to the real singletons only during `signIn()`. This preserves the intended DI contract while allowing test construction without a live Firebase app.
- **Files modified:** `lib/features/auth/services/auth_service.dart`
- **Commit:** 166c79b

## Known Stubs

None — all providers are wired. `AuthStateNotifier` fully implements the Firebase stream subscription. `AuthService.signIn()` is fully implemented. `main.dart` bootstrap is complete.

## Threat Flags

No new security surface introduced beyond what the plan's threat model covers. All T-09-03-0x mitigations applied:
- T-09-03-01: ID token written to `flutter_secure_storage` under `kFirebaseIdTokenKey`
- T-09-03-02: No `print`/`log`/`debugPrint` of token anywhere in auth_service.dart
- T-09-03-03: `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)` called in main.dart
- T-09-03-04: `try/catch` around `Firebase.initializeApp` in main.dart
- T-09-03-06: Backfill `await`ed inside single `db.transaction` before `signIn()` returns

## Self-Check: PASSED

- `lib/features/auth/providers/auth_providers.dart` — FOUND
- `lib/features/auth/services/auth_service.dart` — FOUND
- `lib/main.dart` — FOUND (modified)
- Commit 166c79b — FOUND
- Commit efbd737 — FOUND
