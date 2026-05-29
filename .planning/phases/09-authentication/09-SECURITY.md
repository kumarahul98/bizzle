---
phase: 09
slug: authentication
status: verified
threats_open: 0
asvs_level: 2
created: 2026-05-29
---

# Phase 09 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| build config → app | `kGoogleServerClientId` / `firebase_options` identify the Firebase project | Public client identifiers (not secrets) |
| external package set → app | FlutterFire / google_sign_in versions control the native auth surface | Dependency provenance |
| auth uid → local Drift rows | Firebase uid written across local trip/preference rows | Trusted Firebase profile identity |
| Google account picker → app | OAuth flow returns a Google idToken | Untrusted until Firebase `signInWithCredential` validates |
| app → flutter_secure_storage | ID token written to Android Keystore-backed storage | Firebase ID token (sensitive) |
| Firebase SDK → app | `authStateChanges()` / `currentUser` drive auth state | Session / refresh token (SDK-managed) |
| auth state → UI routing | `AuthState` drives `MaterialApp.home` via unidirectional flow | Auth state |
| Firebase profile → UI | displayName / email rendered into account row / confirmation | User's own profile (null-coalesced) |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-09-01-01 | Information Disclosure | constants.dart secrets | accept | Public client identifiers only; doc comment `constants.dart:619-635` confirms no real secret in source | closed |
| T-09-01-02 | Tampering | dependency set | mitigate | Pinned FlutterFire trio `pubspec.yaml:47-49`; `pubspec.lock` committed | closed |
| T-09-01-03 | Tampering | cloud_firestore client leak | mitigate | `cloud_firestore` absent from `pubspec.yaml` and `pubspec.lock` (grep == 0) | closed |
| T-09-02-01 | Tampering | backfill UPDATE | mitigate | Explicit `where((t) => t.userId.equals(kDefaultUserId))` `trips_dao.dart:148-150`, `user_preferences_dao.dart:155-158`; never `.replace()` | closed |
| T-09-02-02 | Repudiation | partial backfill | mitigate | Both DAO backfills run inside `db.transaction()` `auth_service.dart:137-146`, awaited before `signIn()` returns | closed |
| T-09-03-01 | Information Disclosure | ID token storage | mitigate | Token written to `flutter_secure_storage` under `kFirebaseIdTokenKey` `auth_service.dart:124-128`; no SharedPreferences/plaintext path | closed |
| T-09-03-02 | Information Disclosure | token logging | mitigate | Zero `print`/`debugPrint`/`log(` of token/credential in `lib/features/auth/` (grep confirmed) | closed |
| T-09-03-03 | Spoofing | missing serverClientId | accept | Call site `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)` present `main.dart:82-83`. Real Web OAuth client ID is a deployment prerequisite — see Accepted Risks Log (R-09-01) | closed |
| T-09-03-04 | Denial of Service (self) | boot crash on missing config | mitigate | `try { initializeApp … } on Object catch (_) { firebaseReady = false }` `main.dart:77-87` → degrade to guest (D-15) | closed |
| T-09-03-05 | Spoofing | stale token reuse | accept | FlutterFire auto-refreshes ID tokens; Phase 11 reads a fresh `getIdToken()` per request | closed |
| T-09-03-06 | Tampering | userId backfill race | mitigate | Backfill transaction awaited before `signIn()` returns `auth_service.dart:137`; auth-stream event cannot observe stale userId | closed |
| T-09-04-01 | Information Disclosure | confirmation screen | mitigate | `sign_in_success_screen.dart` renders only displayName initial + fixed copy constants; no token/email/uid | closed |
| T-09-04-02 | Denial of Service (self) | unhandled auth variant | mitigate | Exhaustive sealed switch, no `default` — `app.dart:54-58`, `settings_screen.dart:86-100`, `onboarding_screen.dart:96-101` | closed |
| T-09-05-01 | Denial of Service (self) | sign-in cancel | mitigate | `on GoogleSignInException` caught → silent no-op, stay guest — `sign_in_sheet.dart:67-74`, `onboarding_screen.dart:111-112` | closed |
| T-09-05-02 | Information Disclosure | error copy / logging | mitigate | Generic `kCopySignInFailedHeadline`/`kCopySignInFailedBody` only `sign_in_sheet.dart:75-84`; exception never forwarded to UI/logs | closed |
| T-09-05-03 | Spoofing | sign-in when unconfigured | mitigate | `firebaseReady=false` renders disabled button at `kDisabledSignInOpacity` + tooltip — `sign_in_sheet.dart:161-172`, `onboarding_screen.dart:120-132` | closed |
| T-09-05-04 | Information Disclosure | profile rendering | accept | displayName/email are the user's own trusted Google profile; single-user local app, no cross-user exposure | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-09-01 | T-09-03-03 | The `serverClientId` initialization call is implemented; only the literal `kGoogleServerClientId` value (`constants.dart:635`) is the placeholder `REPLACE_WITH_WEB_CLIENT_ID_FROM_FIREBASE_CONSOLE`. Supplying the real Web OAuth 2.0 client ID is a deployment/config prerequisite, not a code change. Tracked as item #1 in `09-HUMAN-UAT.md` and as WR-01 in `09-REVIEW.md`. No insecure code path ships — a misconfigured build fails closed (StateError on null idToken), it does not silently authenticate. | rahulkumar@antstack.io | 2026-05-29 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-29 | 17 | 17 | 0 | gsd-security-auditor (verify) + user disposition |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-29
