---
status: partial
phase: 09-authentication
source: [09-VERIFICATION.md]
started: 2026-05-29T11:48:29Z
updated: 2026-05-29T11:48:29Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Real Google Sign-In on Android
expected: After replacing `kGoogleServerClientId` (constants.dart) with the real Web OAuth client ID from the Firebase Console, tapping "Continue with Google" on a physical Android device completes the Google account picker, exchanges the credential with Firebase, and returns a non-null Firebase ID token (no `StateError`). User lands on the one-time `SignInSuccessScreen`.
result: [pending]

### 2. Session persistence across restart
expected: After a successful sign-in, fully killing and relaunching the app restores the authenticated session via FlutterFire `authStateChanges()` without re-prompting for Google sign-in. The cached ID token is present in `flutter_secure_storage` (Android Keystore). (AUTH-02)
result: [pending]

### 3. Degrade-to-guest on unconfigured build
expected: Building/running without `google-services.json` (or with Firebase init failing) does not crash. `main.dart` try/catch sets `firebaseReady=false`, the app renders as `AuthGuest`, and all auth entry points show the guest/sign-in-to-back-up state. (D-15)
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
