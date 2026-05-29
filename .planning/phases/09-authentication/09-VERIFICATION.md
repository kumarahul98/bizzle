---
phase: 09-authentication
verified: 2026-05-29T12:00:00Z
status: human_needed
score: 4/4 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Perform a real Google Sign-In on a connected Android device after providing a valid kGoogleServerClientId"
    expected: "User sees Google account picker, selects an account, is signed in, AuthSignedIn state is emitted, SplashScreen clears, MainShell renders, SignInSuccessScreen appears on first sign-in. On subsequent app launches the session is restored without re-authentication."
    why_human: "kGoogleServerClientId is still the placeholder 'REPLACE_WITH_WEB_CLIENT_ID_FROM_FIREBASE_CONSOLE'. The entire sign-in chain (idToken returned by GoogleSignIn, Firebase credential exchange, secure-storage write, backfill, session-restore on reboot) cannot be exercised in automated tests without real Firebase project config. This is the gating WR-01 finding from the code review."
  - test: "Verify session persists across app restart"
    expected: "After signing in, kill and relaunch the app. The user should land directly on MainShell (AuthSignedIn state), not the onboarding screen and not a sign-in prompt. SplashScreen should flash briefly (Firebase session restore), then MainShell appears."
    why_human: "Session persistence via FlutterFire's auto-refresh and flutter_secure_storage is platform-channel behaviour. Automated tests stub these dependencies; real device verification is required to confirm AUTH-02."
  - test: "Verify firebaseReady=false degrade on a build without google-services.json"
    expected: "App launches normally. All local features (dashboard, trips, stats) work. No crash. The sign-in buttons on onboarding and settings are disabled (Opacity 0.38, tooltip 'Sign-in not configured', Semantics enabled:false). No sign-in attempt is possible."
    why_human: "The degrade path is logically verified in code and unit-tested, but functional verification on a real device (or CI build without google-services.json) is the only way to confirm no unexpected crash or race condition."
---

# Phase 09: Authentication Verification Report

**Phase Goal:** Users can sign in with Google via Firebase Auth and have their identity linked to existing local trip data
**Verified:** 2026-05-29T12:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can sign in with their Google account and receive a Firebase ID token | VERIFIED | `AuthService.signIn()` calls `GoogleSignIn.instance.authenticate()`, reads `account.authentication.idToken`, builds `GoogleAuthProvider.credential(idToken:)`, calls `firebaseAuth.signInWithCredential()`. Flow confirmed in `lib/features/auth/services/auth_service.dart` lines 93-118. google_sign_in v7 API surface confirmed by probe test (8/8 pass). |
| 2 | User's session survives app restart without re-authentication | VERIFIED | `Firebase.initializeApp` restores the Firebase session in `main.dart`. `AuthStateNotifier.build()` subscribes to `authStateChanges()` which re-emits the restored user. `FlutterSecureStorage` (Android Keystore) used as backing store — not plain text. Logic is fully wired; final confirmation requires device testing (see Human Verification). |
| 3 | User completes onboarding flow and existing trips are tagged with Firebase uid | VERIFIED | `OnboardingScreen` calls `ref.read(authServiceProvider).signIn()` on button tap. `AuthService.signIn()` calls `db.transaction(() async { tripsDao.backfillUserId(uid); prefsDao.backfillUserId(uid); })` atomically before returning. Returns `tripsChanged > 0` as first-sign-in signal, which triggers navigation to `SignInSuccessScreen`. `backfill_test.dart` 9/9 pass (in-memory Drift). |
| 4 | Auth tokens are stored in flutter_secure_storage, never in plain text | VERIFIED | Token written exclusively via `_secureStorage.write(key: kFirebaseIdTokenKey, value: firebaseIdToken)` (`auth_service.dart:125-127`). `flutter_secure_storage 10.3.1` (Android Keystore-backed). No `SharedPreferences` usage found. No `print`/`debugPrint`/`log` of token in any auth file. |

**Score:** 4/4 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `pubspec.yaml` | firebase_core, firebase_auth, google_sign_in, flutter_secure_storage | VERIFIED | All four present. firebase_core ^4.9.0, firebase_auth ^6.5.1, google_sign_in ^7.2.0, flutter_secure_storage ^10.3.1. No cloud_firestore. |
| `lib/config/constants.dart` | kGoogleServerClientId, kFirebaseIdTokenKey, kDisabledSignInOpacity, kCopy* | VERIFIED | All Phase 9 constants confirmed at lines 634-689. kGoogleServerClientId present as placeholder (see WR-01 below). |
| `lib/config/routes.dart` | kRouteSignInSuccess | VERIFIED | Present at line 46. Not in kAppRoutes (intentional — pushed as MaterialPageRoute). |
| `lib/features/auth/models/auth_state.dart` | sealed AuthState { AuthLoading, AuthGuest, AuthSignedIn } | VERIFIED | 77 lines. Sealed class with 3 final-class subtypes, const constructors, dartdoc with exhaustive-switch contract. |
| `lib/features/auth/providers/auth_providers.dart` | firebaseReadyProvider, firebaseAuthProvider, googleSignInProvider, secureStorageProvider, authServiceProvider, authStateProvider, AuthStateNotifier | VERIFIED | 186 lines. All 6 providers declared with `name:`. AuthStateNotifier extends `Notifier<AuthState>` (not StateNotifier). Subscription in `build()`, cancel in `ref.onDispose`. |
| `lib/features/auth/services/auth_service.dart` | AuthService.signIn() -> Future<bool> | VERIFIED | 151 lines. Full 7-step sign-in sequence implemented. Uses injected dependencies (no static singletons inside signIn()). |
| `lib/main.dart` | Firebase.initializeApp + GoogleSignIn.instance.initialize in try/catch + firebaseReadyProvider override | VERIFIED | Lines 77-92: try/catch with `on Object catch (_)`, `firebaseReady` flag injected via `ProviderScope.overrideWithValue`. |
| `lib/features/auth/screens/splash_screen.dart` | Static SplashScreen (bg Container + centered TraevyLogoMark) | VERIFIED | 39 lines. `ColoredBox(scaffoldBackgroundColor)` + `Center(TraevyLogoMark())`. No AppBar, no spinner, no text. |
| `lib/features/auth/screens/sign_in_success_screen.dart` | SignInSuccessScreen (avatar + headline + body + Let's go CTA) | VERIFIED | 155 lines. Uses kCopyConfirmHeadline, kCopyConfirmBody, kCopyConfirmCta. Avatar uses accentBg/accent tokens. CTA uses `pushReplacement`. |
| `lib/app.dart` | auth gate switching on sealed AuthState via Dart switch | VERIFIED | Lines 53-57: `final home = switch (auth) { AuthLoading() => SplashScreen(), AuthGuest() => MainShell(), AuthSignedIn() => MainShell() }`. No `.when()`, no `default` branch. |
| `lib/features/auth/widgets/sign_in_sheet.dart` | modal bottom sheet wired to signIn | VERIFIED | 179 lines. `showModalBottomSheet` with `surfaceContainerLowest` + `showDragHandle: true`. Reuses `GoogleContinueButton`. Handles disabled/cancel/failure states. |
| `lib/features/onboarding/screens/onboarding_screen.dart` | ConsumerWidget wiring GoogleContinueButton.onTap -> AuthService.signIn() | VERIFIED | `ref.read(authServiceProvider).signIn()` found at line 89. First-sign-in pushes `SignInSuccessScreen`. |
| `lib/features/settings/screens/settings_screen.dart` | state-aware _AccountSection switching on authStateProvider | VERIFIED | `ref.watch(authStateProvider)` at line 84. Guest/Loading -> SettingsRow with showSignInSheet. SignedIn -> AccountRow with real name/email. |
| `test/unit/features/auth/backfill_test.dart` | in-memory Drift backfill contract | VERIFIED | Uses `NativeDatabase.memory()`. 9/9 tests pass. |
| `test/unit/features/auth/auth_service_test.dart` | RED contract for sign-in + token write + backfill | VERIFIED | Contract file exists, 150+ lines, tests `kFirebaseIdTokenKey` write, both DAO backfill calls, return value logic. |
| `test/unit/features/auth/auth_state_notifier_test.dart` | RED contract for authStateChanges mapping + degrade-to-guest | VERIFIED | File exists. Groups 1-2 pass (sealed subtype identity + exhaustive switch). Group 3 (10 tests) appropriately skipped pending fake Firebase stream injection — this is the documented Wave 0 state. |
| `test/widget/features/onboarding/onboarding_screen_test.dart` | tap -> signIn() assertion, disabled state assertion | VERIFIED | 4 tests: tap invokes signIn(), double-tap invokes twice, disabled when firebaseReady=false (Semantics enabled:false), tooltip present when disabled. |
| `test/widget/features/settings/settings_screen_test.dart` | state-aware Account section assertions | VERIFIED | Guest override -> kCopySettingsGuestSignIn present, no AccountRow. SignedIn override -> AccountRow with real name+email. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `lib/config/constants.dart` | GoogleSignIn.instance.initialize | kGoogleServerClientId in main.dart | WIRED | `main.dart:83`: `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)` |
| `lib/features/auth/providers/auth_providers.dart` | FirebaseAuth.authStateChanges() | subscription inside build(), cancelled in ref.onDispose | WIRED | `_attach()` called from `build()`. `ref.onDispose(() { unawaited(_authSub?.cancel()); })` at lines 147-149. |
| `lib/features/auth/services/auth_service.dart` | flutter_secure_storage write(kFirebaseIdTokenKey) | getIdToken() cached before navigation | WIRED | `_secureStorage.write(key: kFirebaseIdTokenKey, value: firebaseIdToken)` at lines 125-128. |
| `lib/main.dart` | firebaseReadyProvider.overrideWithValue | ProviderScope override after try/catch init | WIRED | `ProviderScope(overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)], ...)` at lines 89-93. |
| `lib/features/onboarding/screens/onboarding_screen.dart` | AuthService.signIn() | ref.read(authServiceProvider).signIn() in GoogleContinueButton.onTap | WIRED | Confirmed at line 89. |
| `lib/features/settings/screens/settings_screen.dart` | sign_in_sheet | guest row onTap opens showSignInSheet | WIRED | `onTap: () => showSignInSheet(context)` at line 98. |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `lib/app.dart` | auth (AuthState) | `authStateProvider` → `FirebaseAuth.authStateChanges()` | Yes — Firebase stream emits User on session restore | FLOWING |
| `lib/features/settings/screens/settings_screen.dart` | auth (AuthState) | `authStateProvider` | Yes — sealed switch on stream-backed state | FLOWING |
| `lib/features/onboarding/screens/onboarding_screen.dart` | firstSignIn (bool) | `AuthService.signIn()` → `backfillUserId` changed-row count | Yes — real Drift UPDATE returns affected rows | FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED for the sign-in sequence — requires real Firebase project config and platform channels. The probe test (`google_sign_in_api_probe_test.dart`, 8/8 pass) validates the API surface. Full behavioral validation is in Human Verification section.

Runnable checks that do not require Firebase:

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Probe test confirms google_sign_in v7 API surface | `flutter test test/unit/features/auth/google_sign_in_api_probe_test.dart` | 8/8 pass (per 09-01 SUMMARY) | PASS |
| backfill test confirms DAO behavior with in-memory Drift | `flutter test test/unit/features/auth/backfill_test.dart` | 9/9 pass (per 09-02 SUMMARY) | PASS |
| Full suite passes (304 pass, 10 skip) | `flutter test` | 304 passed, 10 skipped (per 09-05 SUMMARY) | PASS |
| No StateNotifier in auth code | `grep "StateNotifier" lib/features/auth/providers/auth_providers.dart` | Only in comments (not class definition) | PASS |
| cloud_firestore absent from pubspec | `grep cloud_firestore pubspec.yaml` | No output (absent) | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AUTH-01 | 09-01, 09-03, 09-05 | User can sign in with Google account via Firebase Auth | SATISFIED | AuthService.signIn() implements full Google->Firebase exchange. OnboardingScreen wired to authServiceProvider. Widget test confirms tap invokes signIn(). |
| AUTH-02 | 09-01, 09-03, 09-04 | User session persists across app restarts via secure token storage | SATISFIED (needs device test) | Token written to flutter_secure_storage under kFirebaseIdTokenKey. Firebase SDK auto-restores session via authStateChanges(). AuthStateNotifier maps restored user to AuthSignedIn. Human verification required. |
| AUTH-03 | 09-01, 09-02, 09-05 | User completes onboarding flow (Google sign-in, done) | SATISFIED | OnboardingScreen -> signIn() -> backfillUserId atomic transaction -> SignInSuccessScreen on first sign-in. backfill_test 9/9 pass. |
| BACK-01 | 09-01, 09-03 | Firebase Auth with Google provider handles authentication | SATISFIED | firebase_auth + google_sign_in in pubspec. Firebase.initializeApp in main.dart. GoogleSignIn.instance.initialize with serverClientId. signInWithCredential() in AuthService. |

No orphaned requirements: all four mapped requirements (AUTH-01, AUTH-02, AUTH-03, BACK-01) are covered by plans and verified in code.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/config/constants.dart` | 634-635 | `kGoogleServerClientId = 'REPLACE_WITH_WEB_CLIENT_ID_FROM_FIREBASE_CONSOLE'` | Warning | Placeholder value causes null idToken on Android → `StateError` in `AuthService.signIn()`. Real sign-in fails on any Firebase-configured build until replaced. Documented as WR-01 in code review. Does not affect local features or tests. |
| `lib/features/auth/services/auth_service.dart` | 124 | `await user.getIdToken() ?? ''` | Warning | Null token cached as empty string in secure storage (WR-03 from code review). If getIdToken() returns null, Phase 11 sync layer reads an empty Authorization token and gets 401s. Does not affect this phase's goal (auth state is correctly set regardless). |
| `lib/features/auth/providers/auth_providers.dart` | 180-182 | onError cancels `_authSub` permanently with no re-attach | Warning | A transient Firebase auth stream error permanently degrades the session to AuthGuest for the app lifetime (WR-02 from code review). User must restart the app. Cosmetic degradation, not a correctness failure for this phase's goal. |

---

### Human Verification Required

#### 1. Real Google Sign-In on Android Device

**Test:** On a configured Android device with a real Firebase project: (a) set `kGoogleServerClientId` in `lib/config/constants.dart` to the actual Web OAuth client ID from Firebase Console, (b) run the app, (c) tap "Continue with Google" on the onboarding screen.
**Expected:** Google account picker appears. After selecting an account: `AuthSignedIn` state is emitted, `MainShell` renders, `SignInSuccessScreen` appears. All locally stored trips (with `user_id = 'local_user'`) are updated to the signed-in Firebase uid.
**Why human:** `kGoogleServerClientId` is still the placeholder constant. The entire auth chain (idToken issuance, Firebase credential exchange, secure-storage write, DAO backfill) requires a real configured Firebase project and an Android device. Cannot be exercised in automated tests.

#### 2. Session Persistence Across App Restart

**Test:** After completing sign-in per test #1 above, kill and relaunch the app.
**Expected:** SplashScreen flashes briefly. App lands on `MainShell` directly — no sign-in prompt. The auth state is `AuthSignedIn` restored from the Firebase SDK session.
**Why human:** `FlutterFire`'s session persistence and `authStateChanges()` session-restore behaviour is platform-channel dependent. Automated tests stub Firebase; device testing is required to confirm AUTH-02.

#### 3. Degrade Path Verification (firebaseReady=false)

**Test:** Build the app without a valid `google-services.json` (or comment out the Firebase init to force the try/catch failure path).
**Expected:** App launches, degrades to guest mode. Local features work. On onboarding and settings, the sign-in button is visually disabled (Opacity 0.38), shows tooltip "Sign-in not configured", and `Semantics.enabled` is false. No crash.
**Why human:** The degrade logic is unit-tested but platform crash scenarios (e.g. FirebaseApp missing exception variants) can only be fully confirmed on device.

---

### Gaps Summary

No automated verification gaps. All four success criteria are met by the implementation as verified in the codebase. The three warnings from the code review (WR-01 placeholder constant, WR-02 stream error recovery, WR-03 empty token caching) are pre-existing findings documented in `09-REVIEW.md` — they are robustness concerns for future phases, not blockers for this phase's goal.

**Status is `human_needed` because** AUTH-02 (session persistence) and the core AUTH-01 sign-in flow cannot be exercised without a real Firebase project configuration and a physical Android device. Three human test cases are required to confirm the end-to-end goal is achieved at runtime.

The single action required before human testing is replacing `kGoogleServerClientId` in `lib/config/constants.dart` with the actual Web OAuth client ID from Firebase Console (documented in Plan 09-01 `user_setup`).

---

_Verified: 2026-05-29T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
