# Phase 9: Authentication - Research

**Researched:** 2026-05-29
**Domain:** Flutter client-side authentication — Firebase Auth (FlutterFire) + Google provider
**Confidence:** HIGH (stack, integration patterns), MEDIUM (google_sign_in v7 exact API surface, Gradle wiring specifics)

> ⚠️ **This file fully replaces the prior Cognito-based research.** The backend vendor switched
> AWS → Firebase on 2026-05-27 (see `cloud-vendor-tradeoffs.pdf`, `.planning/PROJECT.md` Key
> Decisions). All Cognito Hosted UI / Identity Pool / deep-link / `amazon_cognito_identity_dart_2`
> content from the stale version is dropped. Phase 9 is **Flutter-side auth only** — no backend
> Cloud Functions or Firestore (that is Phase 10).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Auth Gate Routing**
- **D-01:** `AuthStateNotifier` lives in `lib/features/auth/providers/`. Subscribes to
  `FirebaseAuth.instance.authStateChanges()` on init; exposes three states:
  `AuthState.loading` / `AuthState.guest` / `AuthState.signedIn(uid, name, email)`.
- **D-02:** `app.dart` watches `authStateProvider` and renders: `loading` → static splash
  (Traevy logo + `bg` token background), `guest` → `MainShell()`, `signedIn` → `MainShell()`.
- **D-03:** On boot, FlutterFire restores the session automatically — no manual token validation.
  If `FirebaseAuth.instance.currentUser` is non-null → `signedIn`; else `guest`. ID-token refresh
  handled by the SDK (no custom 401 refresh logic).
- **D-04:** Static splash during `loading`: a `Container` with `TraevyTokensExt.bg` fill + centered
  `TraevyLogoMark`. Rendered inline from `app.dart`'s `authStateProvider.when(loading: ...)`. Not a
  named route.

**Skip / Optional Sign-In**
- **D-05:** Sign-in is **optional**. Guests reach `MainShell` via "Sign in later" on onboarding. App
  is fully functional offline without an account.
- **D-06:** `AuthState` has three values — `loading`, `guest`, `signedIn`. Guest is a valid
  permanent state, not a fallback.
- **D-07:** Settings → Account section is **state-aware**:
  - **Guest:** Replace `AccountRow` with a single "Sign in to back up" row (Google icon + label).
    Tapping opens the sign-in bottom sheet.
  - **Signed-in:** Show `AccountRow` populated with real Firebase profile name, email, first-letter
    initial.
- **D-08:** Sign-in from Settings opens a **modal bottom sheet** over Settings (not a full-screen
  nav to `kRouteOnboarding`). Contains Google sign-in button + brief "Back up your commutes"
  headline. Dismissable.

**Auth Library**
- **D-09:** Use **Firebase Auth (FlutterFire)** with the Google provider. Stack: `firebase_core` +
  `firebase_auth` + `google_sign_in` + `flutter_secure_storage`. First-party path, dramatically
  simpler than Cognito — no Hosted UI, no browser redirect, no deep-link callback, no manual
  `/oauth2/token` POST.
- **D-10:** `AuthService` owns the sign-in sequence as an **in-app flow** (no browser redirect):
  obtain Google credential via `google_sign_in` → build `GoogleAuthProvider` credential →
  `FirebaseAuth.instance.signInWithCredential(...)`. FlutterFire persists the session and refreshes
  ID tokens automatically. Current ID token (`user.getIdToken()`) is cached in
  `flutter_secure_storage` for the Phase 11 sync layer to attach to Cloud Function requests.
  > ✅ Vendor switch: Cognito Hosted UI + `amazon_cognito_identity_dart_2` + `url_launcher`/
  > `app_links` deep-link approach from prior spike (002a) is **dropped**. No deep link scheme, no
  > `AndroidManifest` callback registration needed for auth.
- **D-10a:** No extra redirect/deep-link dependencies. Project config comes from
  `flutterfire configure` (generates `firebase_options.dart`) and `google-services.json` placed in
  `android/app/`. Pin FlutterFire versions in `pubspec.yaml` to a known-good set.

**User ID Backfill**
- **D-11:** Immediately after successful sign-in, `AuthService.signIn()` runs a single Drift batch
  UPDATE: `UPDATE trips SET user_id = <firebaseUid> WHERE user_id = 'local_user'`. Same for
  `user_preferences`.
- **D-12:** After sign-in + backfill, navigate to a brief **confirmation screen**: "You're signed
  in. Your commutes will back up automatically." with name/avatar + "Let's go" button → `MainShell`.
  One-time screen, first sign-in only.
- **D-13:** Merge/conflict UI deferred to Phase 11. Phase 9 only does the local userId rewrite.

**Firebase Config Injection**
- **D-14:** Firebase config from `flutterfire configure` → generates `lib/firebase_options.dart`
  (committed). `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` runs in
  `main.dart` before `runApp`. No `--dart-define` flags.
- **D-15:** If Firebase fails to init or `google-services.json` absent (dev build), `AuthStateNotifier`
  starts in `guest` state and sign-in button is disabled. App fully functional offline. No crash.
- **D-16:** Google OAuth + Firebase Android config both handled by `google-services.json` in
  `android/app/` (plus Google Services Gradle plugin). `google_sign_in` and `firebase_auth` read it
  automatically. SHA-1/SHA-256 fingerprints must be registered in the Firebase Console project.

### Claude's Discretion

- Confirmation screen (D-12) gating mechanism: a `first_sign_in_shown` flag in `user_preferences`,
  OR navigate to MainShell and pop the confirmation after a short delay/tap. Researcher recommends a
  "backfill-changed-rows" signal to avoid a schema migration (see Architecture Pattern 4).
- Sign-in bottom sheet content (D-08): Google icon + "Back up your commutes" headline + "Your trips
  sync automatically when you sign in." subtext + "Continue with Google" button.
- Disabled-sign-in affordance when Firebase unconfigured: visually disabled button + tooltip
  "Sign-in not configured" (dev/test builds).

### Deferred Ideas (OUT OF SCOPE)

- **Merge/conflict UI (local vs cloud trips)** → Phase 11 restore flow.
- **Sign-out / account deletion** → future phase. (The existing Settings "Sign out" row stays a
  no-op visual in Phase 9.)
- **Token refresh flow** (lazy 401 handling) → Phase 11 (when API calls happen).
- **Push notification permission prompt** → already handled in Phase 7.
- **Backend Cloud Functions + Firestore setup** → Phase 10.
- **Trip sync to Firestore** → Phase 11.
- **Firestore Security Rules** → Phase 10.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | User can sign in with Google account via Firebase Auth (Google provider) | `google_sign_in` 7.x `authenticate()` → `GoogleAuthProvider.credential(idToken:)` → `FirebaseAuth.signInWithCredential()`. See Code Examples §1–2. |
| AUTH-02 | User session persists across app restarts via secure token storage | FlutterFire persists the session automatically; `authStateChanges()`/`currentUser` restore on launch (D-03). ID token additionally cached in `flutter_secure_storage` for Phase 11 (D-10). See Code Examples §3–4. |
| AUTH-03 | User completes onboarding flow (Google sign-in, location permission grant, done) | Onboarding scaffold exists (Phase 8). Phase 9 wires the no-op `GoogleContinueButton.onTap` to `AuthService.signIn()` + confirmation screen (D-12). Location-permission step is pre-existing; not auth-specific. |
| BACK-01 | Firebase Auth with Google provider handles authentication | **Flutter-side only this phase.** Firebase project config via `flutterfire configure` (D-14); Google provider enabled in Firebase Console; SHA fingerprints registered (D-16). No backend code. |
</phase_requirements>

## Summary

Phase 9 wires real Google Sign-In through Firebase Auth into the existing Traevy app skeleton.
The work is almost entirely **client-side Flutter** — Phase 8 already built the onboarding screen,
the Google button widget, the `AccountRow`, and the Settings Account section as no-op visual
scaffolds. Phase 9 swaps placeholders for live auth state and adds a thin `lib/features/auth/`
feature (one service, one provider file, a sealed-state model, two small screens, one bottom sheet).
The Firebase project itself is configured once with `flutterfire configure`, which generates
`lib/firebase_options.dart` and registers the Android app.

The single biggest technical risk is **package version skew and the google_sign_in 7.x API break.**
The current ecosystem is `firebase_core ^4.9.0`, `firebase_auth ^6.5.1`, and `google_sign_in ^7.2.0`
[VERIFIED: pub.dev, 2026-05-29]. google_sign_in 7.x is a hard break from 6.x: there is no longer a
`signIn()` method returning an account with `.authentication.accessToken`; instead you call
`GoogleSignIn.instance.initialize(serverClientId: ...)` once, then `authenticate()`, and read the
`idToken` from the resulting authentication object. The `serverClientId` (the **web** OAuth client
ID, not the Android one) is required on Android to receive an `idToken` that Firebase will accept —
omitting it is a leading cause of `firebase_auth/network-request-failed` and "I get an accessToken
but no idToken" failures [CITED: github.com/flutter/flutter/issues/173134, corroborated by FlutterFire docs].

**Primary recommendation:** Pin the trio `firebase_core: 4.9.0`, `firebase_auth: 6.5.1`,
`google_sign_in: 7.2.0` (or whatever `flutter pub add` resolves to at implementation time — verify
with `flutter pub outdated`), use the google_sign_in **7.x** `initialize()` + `authenticate()` flow
with `serverClientId`, keep `Firebase.initializeApp` in a try/catch so a missing config degrades to
`guest` (D-15), and model `AuthState` as a sealed class consumed via an exhaustive `switch` in
`app.dart` (the codebase's manual-Riverpod, no-codegen convention).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Google account selection / OAuth consent | Browser/Platform (Android Credential Manager) | — | `google_sign_in` 7.x delegates to the Android system account picker; no app UI for the picker itself. |
| Google → Firebase credential exchange | Client (Flutter `AuthService`) | Firebase Auth backend | In-process: `signInWithCredential` calls Firebase's `/accounts:signInWithIdp` endpoint; the app never sees a browser redirect. |
| Session persistence + token refresh | Firebase Auth SDK (client) | — | FlutterFire stores the refresh token in platform secure storage and silently refreshes ID tokens. Not the app's job. |
| Auth state → UI routing | Client UI layer (`app.dart` auth gate) | Riverpod provider | `AuthStateNotifier` (logic) drives `MaterialApp.home` (UI). State flows down (UDF). |
| ID token caching for sync | Client (`AuthService` → `flutter_secure_storage`) | — | Phase 11 sync layer reads the cached token. Phase 9 writes it; nothing reads it yet. |
| `user_id` backfill | Client data layer (Drift DAO) | — | Single local SQL UPDATE; Drift is SSOT. No network. |
| Firebase project / OAuth config | Build-time config (`firebase_options.dart`, `google-services.json`, Firebase Console) | — | Generated once by `flutterfire configure`; not runtime app logic. |

**Key tier note:** Nothing in Phase 9 talks to a backend Cloud Function or Firestore. The "Firebase
backend" tier is touched only as the *managed auth service* behind `signInWithCredential`. BACK-01
is satisfied on the Flutter side by configuring the project and enabling the Google provider.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `firebase_core` | `^4.9.0` | Initializes the Firebase app; prerequisite for all FlutterFire plugins | First-party; `Firebase.initializeApp` must run before any auth call. [VERIFIED: pub.dev, 2026-05-29] |
| `firebase_auth` | `^6.5.1` | Firebase Authentication: `signInWithCredential`, `authStateChanges`, `currentUser`, `getIdToken` | First-party FlutterFire auth plugin; depends on `firebase_core ^4.9.0`. [VERIFIED: pub.dev, 2026-05-29] |
| `google_sign_in` | `^7.2.0` | Native Android Google account picker → returns Google `idToken` for the Firebase credential | Official Flutter-team plugin; v7 is the current major. [VERIFIED: pub.dev, 2026-05-29] |
| `flutter_secure_storage` | `^9.2.4` | Android Keystore-backed storage for the cached Firebase ID token (D-10) | CLAUDE.md mandate — never store tokens in SharedPreferences. [ASSUMED — verify latest with `flutter pub add`] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| FlutterFire CLI | latest | `flutterfire configure` generates `firebase_options.dart` + registers the Android app | One-time project setup (D-14). Install: `dart pub global activate flutterfire_cli`. |
| Firebase CLI | latest | Auth for `flutterfire configure`; project selection | Prereq for FlutterFire CLI. Install: `npm i -g firebase-tools`; `firebase login`. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `google_sign_in` + manual credential | `signInWithProvider(GoogleAuthProvider())` | The PDF sketch mentions `signInWithProvider`. On Android, the credential-based `google_sign_in` flow gives the native account picker and is the canonical mobile path. `signInWithProvider` is primarily web/desktop and triggers a browser / Chrome-Custom-Tab flow — contradicts D-10's "in-app, no browser redirect." **Use the `google_sign_in` credential flow.** [CITED: firebase.google.com/docs/auth/flutter/federated-auth] |
| `firebase_auth` only | `firebase_ui_auth` | Pre-built sign-in screens. Rejected: the app already has a custom-themed onboarding screen + bottom sheet (D-07/D-08); `firebase_ui_auth` would fight the Traevy design system and pull extra deps. |
| `flutter_secure_storage` cache | rely solely on FlutterFire's internal persistence | FlutterFire already persists the session for AUTH-02. The extra secure-storage cache exists only because Phase 11's `http`-based sync layer needs the raw ID token string for the `Authorization` header. Both are needed (D-10). |

**Installation:**
```bash
# One-time tooling (machine-level)
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli

# Generate Firebase config (creates lib/firebase_options.dart, registers Android app)
flutterfire configure

# App dependencies — let the resolver pick the current compatible set, then pin
flutter pub add firebase_core firebase_auth google_sign_in flutter_secure_storage
```

**Version verification (run at implementation time — training data and even this research drift):**
```bash
flutter pub outdated
# Confirm firebase_core, firebase_auth, google_sign_in resolve to a mutually compatible set.
# firebase_auth pins firebase_core's minor — DO NOT pin them independently to mismatched minors.
```
Verified on 2026-05-29: `firebase_core 4.9.0`, `firebase_auth 6.5.1` (depends on
`firebase_core ^4.9.0`), `google_sign_in 7.2.0`. [VERIFIED: pub.dev]

## Architecture Patterns

### System Architecture Diagram

```
                              app launch (main.dart)
                                       │
                       Firebase.initializeApp(options: …)
                          ┌────────────┴────────────┐
                    success                       throws / no config
                          │                            │
              AuthStateNotifier                  AuthStateNotifier
          subscribes authStateChanges()        starts in guest (D-15)
                          │                            │
            ┌─────────────┼─────────────┐              ▼
       currentUser     null        (stream      sign-in button disabled
        non-null     (no session)    emits)
            │             │
            ▼             ▼
      signedIn(uid,…)   guest ──────────────────────────────┐
            │             │                                  │
            ▼             ▼                                  │
   app.dart  switch(authState) { loading→splash,            │
             guest→MainShell, signedIn→MainShell }           │
            │                                                │
            └──► MainShell (both guest & signedIn render it) │
                                                             │
   USER TAPS "Continue with Google" (onboarding or Settings sheet)
                          │                                  │
                          ▼                                  │
          AuthService.signIn()  ◄────────────────────────────┘
                          │
   1. GoogleSignIn.instance.authenticate()  → Google idToken
   2. GoogleAuthProvider.credential(idToken: …)
   3. FirebaseAuth.signInWithCredential(cred) → Firebase User (uid)
   4. user.getIdToken() → write to flutter_secure_storage  (for Phase 11)
   5. Drift batch UPDATE: trips/user_preferences user_id 'local_user' → uid
   6. (first sign-in only) → navigate to confirmation screen
                          │
                          ▼
        authStateChanges() emits signedIn(uid,name,email)
                          │
                          ▼
            Settings Account section re-renders (D-07)
```

### Recommended Project Structure
```
lib/features/auth/
├── providers/
│   └── auth_providers.dart      # authStateProvider (StateNotifierProvider) + authServiceProvider + firebaseReadyProvider
├── services/
│   └── auth_service.dart        # AuthService: signIn(), token cache, userId backfill
├── models/
│   └── auth_state.dart          # sealed AuthState { AuthLoading, AuthGuest, AuthSignedIn(uid,name,email) }
├── screens/
│   ├── splash_screen.dart       # static splash widget for loading state (D-04)
│   └── sign_in_success_screen.dart  # one-time confirmation (D-12)
└── widgets/
    └── sign_in_sheet.dart       # modal bottom sheet for Settings sign-in (D-08)
```

### Pattern 1: Sealed AuthState + manual StateNotifier (matches codebase convention)
**What:** A sealed `AuthState` with three subtypes, driven by a `StateNotifier` that subscribes to
`authStateChanges()`.
**When to use:** Always here — D-01/D-06 mandate exactly three states; CLAUDE.md mandates sealed
classes for finite state; the codebase uses manual Riverpod (no codegen) per
`lib/database/providers.dart` and `settings_providers.dart`.
**Example:**
```dart
// lib/features/auth/models/auth_state.dart
sealed class AuthState {
  const AuthState();
}
class AuthLoading extends AuthState {
  const AuthLoading();
}
class AuthGuest extends AuthState {
  const AuthGuest();
}
class AuthSignedIn extends AuthState {
  const AuthSignedIn({required this.uid, required this.name, required this.email});
  final String uid;
  final String name;
  final String email;
}
```
```dart
// lib/features/auth/providers/auth_providers.dart  (manual provider — no @riverpod)
final StateNotifierProvider<AuthStateNotifier, AuthState> authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(ref.watch(authServiceProvider)),
  name: 'authStateProvider',
);
```
> ⚠️ `app.dart` cannot use `.when(...)` on a plain `StateNotifierProvider` — that's the `AsyncValue`
> API used by `userPreferenceProvider` (a `StreamProvider`). For the sealed `AuthState`, use a Dart
> `switch` expression (exhaustive over the sealed subtypes). D-02/D-04 phrase routing as
> `.when(loading/guest/signedIn)`, which is shorthand for this switch, not a literal API.
> [ASSUMED — planner should confirm the `.when` wording is conceptual, see Assumptions A5.]

### Pattern 2: google_sign_in 7.x sign-in sequence (the v7 API, not v6)
**What:** v7 replaces `signIn()` with one-time `GoogleSignIn.instance.initialize()` +
`authenticate()`. Read `idToken` (not `accessToken`) from the result.
**When to use:** The entire AUTH-01 flow. See Code Examples §1.

### Pattern 3: Degrade-to-guest on missing Firebase config (D-15)
**What:** Wrap `Firebase.initializeApp` in try/catch; on failure set a `firebaseReady=false` flag so
the AuthService and sign-in buttons know Firebase is unavailable. See Code Examples §5.
**When to use:** Always — dev/CI builds may lack `google-services.json`.

### Pattern 4: One-time confirmation screen (D-12) — recommend no schema migration
**What:** After backfill, decide whether to show `SignInSuccessScreen`.
**Recommended approach:** `AuthService.signIn()` returns a `bool` that is true when the backfill
actually changed rows (i.e. a `local_user` row existed). The caller shows the confirmation only when
true. This needs **no Drift migration**.
**Alternative:** Add a `first_sign_in_shown` boolean to `user_preferences` — fully viable but
requires a schema migration for a one-time cosmetic screen.
**When to use:** Prefer the row-changed signal; both are correct.

### Anti-Patterns to Avoid
- **Calling google_sign_in 6.x API (`GoogleSignIn().signIn()`, `.authentication.accessToken`):**
  Does not exist in v7. Will not compile. Use `GoogleSignIn.instance.authenticate()` + `idToken`.
- **Omitting `serverClientId` on Android:** Returns a credential without a usable `idToken`;
  `signInWithCredential` then fails (`network-request-failed` / auth error).
- **Reading trips from Firestore / using `cloud_firestore` in the client:** Forbidden by CLAUDE.md
  and the PDF. Not in Phase 9 scope — Drift remains SSOT.
- **Blocking the UI on `getIdToken()` during boot:** Token caching is fire-and-forget after sign-in;
  never gate `MainShell` render on a network token fetch (offline-first).
- **Writing custom token-refresh / 401 logic:** FlutterFire refreshes ID tokens automatically
  (D-03). Deferred to Phase 11 if ever needed.
- **`update(trips).replace(row)` for the backfill:** CLAUDE.md and STATE.md (Phase 3) ban
  `.replace()` for partial updates. Use an explicit `UPDATE … WHERE user_id = 'local_user'`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OAuth token exchange | Manual `/oauth2/token` POST, PKCE, nonce | `signInWithCredential` | FlutterFire does the IdP exchange; the Cognito-era manual exchange is gone. |
| Session persistence | Custom refresh-token storage + expiry timer | FlutterFire auto-persistence + `authStateChanges()` | SDK stores the refresh token in platform secure storage and refreshes silently (AUTH-02, D-03). |
| Google account picker UI | Custom account-selection screen | `GoogleSignIn.instance.authenticate()` | Native Android Credential Manager picker; you cannot build the consent UI yourself. |
| Secure token storage | Encrypt-then-write to a file / SharedPreferences | `flutter_secure_storage` (Android Keystore) | CLAUDE.md mandate; Keystore is hardware-backed where available. |
| Firebase platform config | Hand-author `firebase_options.dart` / `google-services.json` | `flutterfire configure` | Generates correct API keys, app IDs, and Gradle wiring; hand-editing causes subtle mismatches. |

**Key insight:** The entire value of the AWS→Firebase switch is that auth becomes a thin
SDK-mediated flow. The moment you hand-roll any of the above you've recreated the Cognito complexity
the vendor switch was meant to delete.

## Runtime State Inventory

> Phase 9 has a rename-adjacent dimension: the `user_id` backfill rewrites a stored string
> (`'local_user'` → Firebase uid) across local data.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Drift `trips.user_id` and `user_preferences.user_id` default to `kDefaultUserId = 'local_user'` (`lib/database/tables/trips_table.dart`, `user_preferences_table.dart`). All existing local rows carry `'local_user'`. | **Data migration:** batch `UPDATE … SET user_id = <uid> WHERE user_id = 'local_user'` on first sign-in (D-11). **Code edit:** new rows continue to default to `'local_user'` until signed in — correct for guest mode. No table-default change needed. |
| Live service config | None local. Firebase project, Google OAuth client, and SHA fingerprints live in the **Firebase Console** (not in git). `flutterfire configure` writes `firebase_options.dart` (committed); the Console-side Google-provider toggle + SHA registration are manual one-time steps (D-16). | **Manual (Console):** enable Google provider; register debug + release SHA-1/SHA-256. Plan must list this as a human checklist item — cannot be automated from code. |
| OS-registered state | None — verified by absence of any background-registration code touching auth. (Android Credential Manager state is OS-managed, not app-managed.) | None. |
| Secrets / env vars | `serverClientId` (the web OAuth client ID) is **not a secret** — a public client identifier; lives in `constants.dart` or is derived from generated config. The Firebase API key in `firebase_options.dart` is also not a secret (it identifies, not authorizes). No `.env` needed (D-14: no `--dart-define`). | **Code edit:** add `kGoogleServerClientId` + `kFirebaseIdTokenKey` to `constants.dart`. No SOPS/secret-manager involvement. |
| Build artifacts / installed packages | After adding FlutterFire deps (+ the Google Services Gradle plugin if `flutterfire configure` adds it), the Android build needs a clean rebuild. `firebase_options.dart` is generated; `google-services.json` lands in `android/app/`. | **Reinstall/rebuild:** `flutter clean && flutter pub get`, then a full `flutter build apk` to pick up any Gradle plugin. `firebase_options.dart` is committed (D-14); `google-services.json` commit-vs-gitignore is a team choice (contains no secrets). |

**Canonical question — after every file is updated, what still has the old `'local_user'` string?**
Only Drift rows written *before* sign-in. The D-11 backfill handles them. Rows written in guest mode
after a sign-out (out of scope) would re-introduce `'local_user'`, but sign-out is deferred — no
concern this phase.

## Common Pitfalls

### Pitfall 1: google_sign_in 7.x API break (top risk)
**What goes wrong:** Code written from training data / old tutorials uses `GoogleSignIn().signIn()`
and `account.authentication.accessToken`. None exists in v7 — the build fails or an AI "fixes" it by
downgrading the package.
**Why it happens:** v7 restructured around `GoogleSignIn.instance`, `initialize()`, `authenticate()`,
and an `authorizationClient` for scopes. Most search results show v6 code.
[CITED: pub.dev/packages/google_sign_in — "If you used version 6.x or earlier … see the migration guide"]
**How to avoid:** Use the v7 sequence in Code Examples §1. Call `initialize()` exactly once
(idempotent-guard). Read `idToken` from the authentication object, not `accessToken`.
**Warning signs:** `signIn()` not found; `.authentication` has no `accessToken`; tutorials dated pre-2025.

### Pitfall 2: Missing `serverClientId` → no usable idToken on Android
**What goes wrong:** `authenticate()` succeeds and returns a user, but Firebase
`signInWithCredential` throws `firebase_auth/network-request-failed` or the credential's `idToken` is null.
**Why it happens:** On Android, google_sign_in needs the **web** OAuth client ID (`serverClientId`) —
the one auto-created in the Firebase/GCP project — to mint an ID token Firebase will accept. Passing
the Android client ID, or none, yields only an access token.
[CITED: github.com/flutter/flutter/issues/173134; corroborated by FlutterFire federated-auth docs]
**How to avoid:** In `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)`, set
the web client ID from the Firebase Console (APIs & Services → Credentials → "Web client (auto
created by Google Service)").
**Warning signs:** Works in the account picker, fails at `signInWithCredential`; `idToken == null`.

### Pitfall 3: Missing / wrong SHA fingerprints
**What goes wrong:** Picker appears, user picks an account, then immediately fails
(`canceled` / `DEVELOPER_ERROR` / code 10).
**Why it happens:** Google requires the app's signing SHA-1 (and SHA-256 for newer flows) registered
in the Firebase Console for the Android OAuth client. The project signs **release** with the **debug
keystore** (`android/app/build.gradle.kts`: `signingConfig = signingConfigs.getByName("debug")`), so
the *debug* keystore SHA must be registered for both build types today.
**How to avoid:** `./gradlew signingReport` (or `keytool`) to get the debug SHA-1/SHA-256, register
both in the Firebase Console, re-download `google-services.json` (D-16). Plan must list this as a
human checklist step.
**Warning signs:** `GoogleSignInExceptionCode.canceled` right after account selection; error code 10.

### Pitfall 4: Version skew across FlutterFire packages
**What goes wrong:** `pub get` resolves `firebase_auth` to a version whose `firebase_core` lower
bound conflicts with a separately-pinned `firebase_core`, or `flutter pub upgrade` bumps one plugin
and breaks the native build.
**Why it happens:** FlutterFire plugins are released as a coordinated set; each `firebase_auth` pins
a `firebase_core` minor (6.5.1 → `firebase_core ^4.9.0`).
**How to avoid:** Pin the verified trio (or let `flutter pub add` resolve them together), commit
`pubspec.lock`, never bump one FlutterFire plugin in isolation (D-10a). PDF: "Pin SDK versions."
**Warning signs:** `version solving failed`; native Android build errors after an upgrade.

### Pitfall 5: Boot-time crash when Firebase isn't configured
**What goes wrong:** A dev/CI build without `google-services.json` crashes at `Firebase.initializeApp`
instead of running offline.
**Why it happens:** `initializeApp` throws if platform config is absent/invalid.
**How to avoid:** try/catch around `initializeApp` in `main.dart`; on failure AuthStateNotifier starts
in `guest` and sign-in buttons are disabled with a tooltip (D-15). Code Examples §5.
**Warning signs:** App crashes on launch only on machines without Firebase config.

### Pitfall 6: Riverpod state-class API mismatch in app.dart
**What goes wrong:** Developer copies the `userPreferenceProvider.when(data/loading/error)` pattern
onto `authStateProvider`, but `authStateProvider` is a `StateNotifierProvider<…, AuthState>` (sync
sealed value), not a `StreamProvider`/`AsyncValue` — `.when` won't apply.
**Why it happens:** D-02/D-04 describe routing as `.when(loading/guest/signedIn)`, which reads like
the AsyncValue API but is conceptually a sealed-class switch.
**How to avoid:** Use Dart `switch` exhaustive pattern matching on the sealed `AuthState`.
**Warning signs:** `The method 'when' isn't defined for the type 'AuthState'`.

### Pitfall 7: Backfill racing the auth stream / transaction boundary
**What goes wrong:** `signInWithCredential` resolving triggers `authStateChanges()` immediately;
the UI re-renders before the local rows are rewritten, briefly showing stale `user_id`; or an async
prefs read spans a Drift transaction (a Phase 3 documented hazard).
**Why it happens:** Stream emission and the backfill await are separate.
**How to avoid:** In `AuthService.signIn()`, `await` the backfill UPDATE *before* navigating to the
confirmation screen, and keep any `getOrDefault()`/prefs reads outside the Drift transaction (per
Phase 3 STATE.md note). The backfill is local-only and fast.
**Warning signs:** Trips momentarily attributed to `local_user` after sign-in.

## Code Examples

### §1 — google_sign_in 7.x → Firebase credential (AUTH-01, D-10)
```dart
// Source: firebase.google.com/docs/auth/flutter/federated-auth +
//         pub.dev/packages/google_sign_in (v7 API). [CITED]
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Call once at startup (or lazily, guarded). serverClientId = WEB client ID
// from the Firebase/GCP project (Pitfall 2).
await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);

Future<UserCredential> signInWithGoogle() async {
  // v7: authenticate() replaces v6 signIn(). Throws GoogleSignInException on
  // cancel — catch it and treat as a no-op (stay guest).
  if (!GoogleSignIn.instance.supportsAuthenticate()) {
    throw StateError('Platform does not support interactive auth');
  }
  final GoogleSignInAccount account =
      await GoogleSignIn.instance.authenticate();

  final GoogleSignInAuthentication auth = account.authentication;
  // Firebase needs the idToken (NOT accessToken).
  final credential = GoogleAuthProvider.credential(idToken: auth.idToken);

  return FirebaseAuth.instance.signInWithCredential(credential);
}
```
> [ASSUMED] Exact field/method names (`account.authentication`, `auth.idToken`,
> `supportsAuthenticate()`) are from v7 docs but the precise return shape should be confirmed against
> the installed `google_sign_in 7.2.0` API reference during Wave 0 — v7.x had minor surface changes
> across 7.0→7.2.

### §2 — AuthService with token cache + userId backfill (D-10, D-11)
```dart
// AuthService is a stateless service (per flutter-architecting-apps skill).
class AuthService {
  AuthService(this._secureStorage, this._tripsDao, this._prefsDao);
  final FlutterSecureStorage _secureStorage;
  final TripsDao _tripsDao;
  final UserPreferencesDao _prefsDao;

  /// Returns true if this was a first sign-in (local rows were backfilled),
  /// so the caller can show the one-time confirmation screen (D-12).
  Future<bool> signIn() async {
    final cred = await signInWithGoogle();
    final user = cred.user!;
    // Cache ID token for the Phase 11 sync layer (D-10).
    final idToken = await user.getIdToken();
    await _secureStorage.write(key: kFirebaseIdTokenKey, value: idToken);
    // Backfill local data (D-11). Explicit WHERE — never .replace().
    final changed = await _tripsDao.backfillUserId(user.uid);
    await _prefsDao.backfillUserId(user.uid);
    return changed > 0;
  }
}
```
```dart
// lib/database/daos/trips_dao.dart — add:
Future<int> backfillUserId(String newUserId) {
  return (update(trips)..where((t) => t.userId.equals(kDefaultUserId)))
      .write(TripsCompanion(userId: Value(newUserId)));
}
```

### §3 — AuthStateNotifier subscribing to authStateChanges (D-01, D-03, D-15)
```dart
class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._authService, {required bool firebaseReady})
      : super(const AuthLoading()) {
    if (!firebaseReady) {
      state = const AuthGuest(); // D-15 degrade path
      return;
    }
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      state = user == null
          ? const AuthGuest()
          : AuthSignedIn(
              uid: user.uid,
              name: user.displayName ?? kPlaceholderUserName,
              email: user.email ?? '',
            );
    });
  }
  late final StreamSubscription<User?> _sub;
  final AuthService _authService;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

### §4 — app.dart auth gate (D-02, D-04) — sealed switch, NOT .when
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // ... existing theme + backfill watches ...
  final auth = ref.watch(authStateProvider);
  final Widget home = switch (auth) {
    AuthLoading() => const SplashScreen(),       // bg token + TraevyLogoMark
    AuthGuest() => const MainShell(),
    AuthSignedIn() => const MainShell(),
  };
  return MaterialApp(/* … */, home: home);
}
```

### §5 — main.dart degrade-to-guest init (D-14, D-15)
```dart
// Source: firebase.google.com/docs/flutter/setup [CITED]
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... existing tz / notification / background-service bootstraps ...
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false; // D-15: no crash, run as guest, disable sign-in
  }
  runApp(ProviderScope(
    overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
    child: const TraevyApp(),
  ));
}
```

## State of the Art

| Old Approach (stale 09-RESEARCH / training data) | Current Approach | When Changed | Impact |
|--------------------------------------------------|------------------|--------------|--------|
| AWS Cognito Hosted UI + `amazon_cognito_identity_dart_2` + deep-link callback | Firebase Auth + `google_sign_in` credential flow, in-process | 2026-05-27 vendor switch | No browser, no deep link, no AndroidManifest callback scheme. Far less code. |
| `GoogleSignIn().signIn()` + `account.authentication.accessToken` (v6) | `GoogleSignIn.instance.initialize()` + `authenticate()` + `idToken` (v7) | google_sign_in 7.0 | Old v6 code won't compile; `serverClientId` now load-bearing on Android. |
| `signInWithProvider(GoogleAuthProvider())` (PDF sketch shorthand) | `signInWithCredential` from google_sign_in idToken (mobile) | — | `signInWithProvider` is the web/desktop popup path; mobile uses the credential flow (D-10's "in-app"). |

**Deprecated/outdated:**
- Everything Cognito in the prior `09-RESEARCH.md` — fully superseded.
- `firebase_auth` v4/v5 + `firebase_core` v2/v3 tutorials — current majors are 6.x / 4.x.
- `google_sign_in` ≤ 6.x API — replaced by v7.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `flutter_secure_storage ^9.2.4` is current | Standard Stack | Low — verify with `flutter pub add`; API stable across 9.x. |
| A2 | v7 fields are `account.authentication.idToken` and `supportsAuthenticate()` exists | Code Examples §1 | Medium — confirm against installed 7.2.0 API ref in Wave 0; wrong names = compile error caught immediately. |
| A3 | `serverClientId` (web client ID) is required on Android for a Firebase-usable idToken | Pitfall 2 | Medium — strongly supported by issue threads + FlutterFire docs; if wrong, sign-in fails loudly. |
| A4 | `flutterfire configure` auto-wires any needed Gradle plugin; `firebase_auth` does NOT strictly require the Google Services plugin (only Crashlytics/Perf do) | Standard Stack / Setup | Medium — Firebase setup docs only explicitly require the plugin for Crashlytics/Perf; verify by building once in Wave 0. |
| A5 | D-02/D-04 `.when(loading/guest/signedIn)` is shorthand for a sealed-class switch, not the AsyncValue API | Architecture Pattern 1 / Pitfall 6 | Low — either implementation routes correctly; switch is idiomatic. |
| A6 | The one-time confirmation screen can be gated by "backfill changed rows" without a schema migration | Architecture Pattern 4 | Low — prefs-flag alternative is also viable. |
| A7 | The existing Settings "Sign out" row stays a no-op visual (sign-out deferred) | User Constraints / Deferred | Low — confirmed by CONTEXT "Out of scope: Sign-out". |

## Open Questions (RESOLVED)

1. **Exact google_sign_in 7.2.0 authentication object shape**
   - What we know: v7 uses `authenticate()` and exposes an `idToken`.
   - What's unclear: precise property path (`.authentication.idToken` vs `.idToken`) and whether
     `idToken` is sync or requires an await in 7.2.0.
   - **RESOLVED:** pinned by Plan 09-01 Task 2 — a Wave 0 compile-probe test reads the installed
     package's real types and documents the exact `idToken` access path in the test header before
     09-03 writes `AuthService`. No implementation code is written against an unverified API.

2. **`google-services.json` in git?**
   - What we know: contains no secrets (public identifiers only) but is project/environment-specific.
   - **RESOLVED:** commit it (solo hobby project — simplest; no secrets in the file).

3. **Release signing & SHA registration timing**
   - What we know: release currently uses the debug keystore (build.gradle.kts).
   - **RESOLVED:** register the **debug** keystore SHA-1/SHA-256 now (covers both build types today).
     Re-register when a real release keystore is introduced (out of v0.1 scope).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | ✓ | 3.41.6 / Dart 3.11.4 | — |
| Firebase CLI (`firebase`) | `flutterfire configure` | ✗ (not verified on machine) | — | `npm i -g firebase-tools && firebase login` |
| FlutterFire CLI (`flutterfire`) | config generation | ✗ (not verified) | — | `dart pub global activate flutterfire_cli` |
| A Firebase project (Console) | BACK-01, Google provider, SHA registration | ✗ (must be created) | — | None — must create one + enable Google provider |
| Android debug keystore | SHA fingerprint for OAuth client | ✓ (default `~/.android/debug.keystore`) | — | `./gradlew signingReport` to read SHA |
| AGP 8.11.1 / Kotlin 2.2.20 / compileSdk 36 | Gradle plugin compatibility | ✓ (already in `settings.gradle.kts`/`build.gradle.kts`) | — | Google Services plugin added by `flutterfire configure` if needed (A4) |

**Missing dependencies with no fallback:**
- A configured Firebase project with the Google sign-in provider enabled and SHA fingerprints
  registered. This is a **human prerequisite** (Console clicks) the plan must call out — code cannot
  create it.

**Missing dependencies with fallback:**
- Firebase CLI / FlutterFire CLI — installable via the commands above. The plan should include an
  install step or assume the developer runs `flutterfire configure` interactively.

> Per CLAUDE.md, GPS/auth-style platform behavior must be tested on a **real Android device**, not
> the emulator. The Firebase Console setup (project, Google provider, SHA, re-download
> `google-services.json`) is a manual checklist task gated before the sign-in flow can be tested.

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` — section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled) + Riverpod `ProviderContainer`/`overrides`; `mockito` pattern per CLAUDE.md |
| Config file | `test/flutter_test_config.dart` (exists) |
| Quick run command | `flutter test test/unit/features/auth/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | `AuthService.signIn()` exchanges Google idToken → Firebase credential and writes token to secure storage | unit (mocked `FirebaseAuth`, `GoogleSignIn`, secure storage) | `flutter test test/unit/features/auth/auth_service_test.dart` | ❌ Wave 0 |
| AUTH-01 | `AuthStateNotifier` maps `authStateChanges` null→guest, user→signedIn | unit (fake stream) | `flutter test test/unit/features/auth/auth_state_notifier_test.dart` | ❌ Wave 0 |
| AUTH-02 | App boot with non-null `currentUser` → `signedIn`; degrade-to-guest when `firebaseReady=false` (D-15) | unit / widget | `flutter test test/unit/features/auth/auth_state_notifier_test.dart` | ❌ Wave 0 |
| AUTH-02 | ID token persisted to `flutter_secure_storage` under `kFirebaseIdTokenKey` | unit | `flutter test test/unit/features/auth/auth_service_test.dart` | ❌ Wave 0 |
| AUTH-03 | Onboarding "Continue with Google" wires to `AuthService.signIn()`; "Sign in later"/"Skip" → MainShell as guest | widget | `flutter test test/widget/features/onboarding/onboarding_screen_test.dart` | ⚠️ Phase 8 visual test exists; extend |
| AUTH-03 | Settings Account section renders guest CTA vs populated `AccountRow` per auth state (D-07) | widget | `flutter test test/widget/features/settings/settings_screen_test.dart` | ✅ exists — extend with auth-state overrides |
| AUTH-03 | Backfill: `trips`/`user_preferences` `user_id` rewrites `'local_user'`→uid; returns changed-count | unit (in-memory Drift) | `flutter test test/unit/features/auth/backfill_test.dart` (or extend `test/unit/features/trips/`) | ❌ Wave 0 |
| BACK-01 | (config-only) Firebase project + Google provider — manual, not unit-testable | manual | n/a — device smoke test on real Android device | n/a |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/features/auth/` + `flutter analyze` (very_good_analysis is strict)
- **Per wave merge:** `flutter test`
- **Phase gate:** full suite green + on-device Google sign-in smoke test (real device) before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/unit/features/auth/auth_service_test.dart` — covers AUTH-01, AUTH-02 (token cache, backfill)
- [ ] `test/unit/features/auth/auth_state_notifier_test.dart` — covers AUTH-01, AUTH-02 (state mapping, degrade path)
- [ ] `test/unit/features/auth/backfill_test.dart` (or extend trips dao tests) — covers AUTH-03 backfill
- [ ] Mocks/fakes for `FirebaseAuth`, `GoogleSignIn`, `FlutterSecureStorage` (mockito or hand-rolled — FlutterFire calls crash on the test host, so they MUST be injected via providers and overridden)
- [ ] Extend `test/widget/features/settings/settings_screen_test.dart` with `authStateProvider` overrides (guest vs signedIn)
- [ ] Extend onboarding widget test to assert tap wiring (override `authServiceProvider` with a fake)

> Critical for testability: `FirebaseAuth.instance` and `GoogleSignIn.instance` are singletons that
> hit platform channels. Inject them through Riverpod providers (`firebaseAuthProvider`,
> `authServiceProvider`) so tests can override with fakes — mirror the existing
> `notificationServiceProvider` override pattern in `settings_providers.dart`.

## Security Domain

> `security_enforcement` not explicitly `false` in config — section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Firebase Auth (managed IdP); Google OAuth via `google_sign_in`. No password handling in-app. |
| V3 Session Management | yes | FlutterFire SDK manages session + refresh token in platform secure storage; ID token cached in `flutter_secure_storage` (Android Keystore). |
| V4 Access Control | partial (Phase 10/11) | Phase 9 only tags local data with uid. Server-side access control (Firestore rules, Cloud Function auth) is Phase 10. |
| V5 Input Validation | minimal | No user-typed auth input (OAuth flow). `displayName`/`email` from Google are trusted profile data; null-coalesce only. |
| V6 Cryptography | yes (delegated) | Never hand-roll. ID token is a Google-signed JWT; secure storage uses Keystore. No custom crypto. |
| V7 Error Handling & Logging | yes | Catch `GoogleSignInException` (cancel) and `FirebaseAuthException`; never log the ID token. |

### Known Threat Patterns for Flutter + Firebase Auth (Android)

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Token stored in plaintext / SharedPreferences | Information Disclosure | `flutter_secure_storage` (Keystore) — CLAUDE.md mandate (D-10). |
| Logging the ID token / credential | Information Disclosure | Never log `idToken`, `getIdToken()` result, or the credential. |
| Stale token reused after expiry | Spoofing | FlutterFire auto-refresh; Phase 11 reads a *fresh* `getIdToken()` per request (deferred). |
| Missing SHA → wrong app obtains tokens | Spoofing | SHA-1/SHA-256 registration ties the OAuth client to the signing cert (D-16). |
| Firestore SDK leaked into client (PDF warning) | Tampering / portability | Forbidden by CLAUDE.md; not in Phase 9 scope. Drift remains SSOT. |
| Cancel treated as error → crash | Denial of Service (self) | Catch `GoogleSignInException(canceled)` and remain `guest` — no crash (Pitfall 1/5). |

## Project Constraints (from CLAUDE.md)

The planner MUST honor these — they have the authority of locked decisions:

- **Auth tokens go in `flutter_secure_storage`.** Never SharedPreferences or plaintext.
- **Drift is the only data source for UI.** No network reads for normal operation; **never use the
  `cloud_firestore` SDK in the client** (PROJECT.md / PDF). Phase 9 touches no backend data anyway.
- **Riverpod for all state.** No `setState`/`ChangeNotifier`. Manual providers (no codegen) per
  `lib/database/providers.dart` — `AuthStateNotifier extends StateNotifier<AuthState>`.
- **Sealed classes/enums for finite state.** `AuthState` must be a sealed class (loading/guest/signedIn).
- **No hardcoded values.** `serverClientId`, secure-storage key, route names → `constants.dart` /
  `routes.dart`. (`serverClientId` is a public client ID, safe in `constants.dart`.)
- **Widgets under ~100 lines;** extract sub-widgets (splash, sheet, success screen) into separate files.
- **Feature-first structure:** `lib/features/auth/{providers,services,models,screens,widgets}/`.
- **Format + analyze + test after changes:** `dart format .`, `flutter analyze`
  (very_good_analysis is strict — private-unused-element fires, see Phase 3 STATE note), `flutter test`.
- **No `// TODO` / stubs / dead code.** The "Sign out" Settings row stays a deliberate, rendered
  no-op visual (sign-out deferred) — documented, not a stub method.
- **Never use `update().replace()` for partial updates** (Phase 3 decision) — backfill uses explicit
  `WHERE user_id = 'local_user'`.
- **Test on a real Android device** for the actual Google sign-in flow (emulator unreliable for
  platform auth, mirrors the GPS testing rule).
- **One concern per commit**, prefix `[auth]` (CLAUDE.md commit convention).

## Sources

### Primary (HIGH confidence)
- pub.dev/packages/firebase_auth — latest `6.5.1`, depends on `firebase_core ^4.9.0` [VERIFIED 2026-05-29]
- pub.dev/packages/firebase_core — `4.9.0` [VERIFIED 2026-05-29]
- pub.dev/packages/google_sign_in — latest `7.2.0`; v7 migration noted [VERIFIED 2026-05-29]
- firebase.google.com/docs/auth/flutter/federated-auth — Google sign-in credential flow [CITED]
- firebase.google.com/docs/flutter/setup — `flutterfire configure`, `firebase_options.dart`, `Firebase.initializeApp` [CITED]
- Repo files read directly: `lib/app.dart`, `lib/main.dart`, `lib/database/providers.dart`,
  `lib/features/settings/providers/settings_providers.dart`, onboarding/account scaffolds,
  `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `pubspec.yaml`,
  `09-CONTEXT.md`, `REQUIREMENTS.md`, `STATE.md`, `PROJECT.md`, `cloud-vendor-tradeoffs.pdf`,
  `.agents/skills/flutter-architecting-apps/SKILL.md` [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- github.com/flutter/flutter/issues/173134 — google_sign_in 7.x `canceled` / `network-request-failed`,
  pointing at serverClientId/SHA misconfiguration [CITED, corroborated by FlutterFire docs]

### Tertiary (LOW confidence)
- Community tutorials (Medium/Codemagic/GeeksforGeeks) on Google+Firebase sign-in — most show **v6**
  API; used only to confirm the credential-exchange shape, NOT the v7 method names. Marked for Wave 0
  verification against the installed package.

## Metadata

**Confidence breakdown:**
- Standard stack (versions): HIGH — verified on pub.dev 2026-05-29.
- Integration architecture (auth gate, sealed state, backfill, degrade path): HIGH — derived from
  locked decisions + verified codebase patterns.
- google_sign_in v7 exact API surface: MEDIUM — v7 confirmed; precise field names need Wave 0 check (A2).
- serverClientId / SHA requirements: MEDIUM — strongly supported, fails loudly if wrong.
- Gradle plugin necessity for firebase_auth alone: MEDIUM — verify with one build (A4).

**Research date:** 2026-05-29
**Valid until:** ~2026-06-12 (FlutterFire + google_sign_in move fast — re-verify versions if planning
slips past two weeks).
