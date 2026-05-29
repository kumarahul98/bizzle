# Phase 9: Authentication - Context

**Gathered:** 2026-05-21
**Updated:** 2026-05-29 — backend vendor switched AWS→Firebase (see `cloud-vendor-tradeoffs.pdf`). Auth approach changed from Cognito Hosted UI to Firebase Auth (Google provider). Auth-gate, optional-sign-in, and userId-backfill decisions carry over unchanged.
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire Google Sign-In via Firebase Auth into the existing app skeleton. Deliver working sign-in, persistent session, and user identity linked to local trip data. Sign-in is optional — the app runs fully offline without an account.

**In scope:**
- `lib/features/auth/` feature directory (providers, services, screens)
- `AuthStateNotifier` with three states: loading / guest / signed-in
- `app.dart` auth gate: static splash → onboarding or MainShell
- `OnboardingScreen` tap handler wiring (button was no-op in Phase 8)
- Settings → Account section: guest CTA vs signed-in profile row
- Sign-in bottom sheet (for sign-in from Settings)
- Silent `userId` backfill in Drift (local_user → Firebase uid) on sign-in
- Post-sign-in confirmation screen
- Firebase ID token persistence in `flutter_secure_storage` (for the Phase 11 sync layer)
- FlutterFire project config (`flutterfire configure` / `google-services.json`)

**Out of scope:**
- Backend Cloud Functions + Firestore setup (Phase 10)
- Trip sync to Firestore (Phase 11)
- Merge/conflict UI for local vs cloud trips (Phase 11)
- Sign-out / account deletion
- Firestore Security Rules (Phase 10)

</domain>

<decisions>
## Implementation Decisions

### Auth Gate Routing

- **D-01:** `AuthStateNotifier` lives in `lib/features/auth/providers/`. It subscribes to `FirebaseAuth.instance.authStateChanges()` on init and exposes three states: `AuthState.loading` / `AuthState.guest` / `AuthState.signedIn(uid, name, email)`.
- **D-02:** `app.dart` watches `authStateProvider` and renders accordingly: `loading` → static splash screen (Traevy logo + `bg` token background), `guest` → `MainShell()`, `signedIn` → `MainShell()`.
- **D-03:** On boot, FlutterFire restores the session automatically — no manual token validation. If `FirebaseAuth.instance.currentUser` is non-null, emit `signedIn`; otherwise `guest`. ID-token refresh is handled by the Firebase SDK (no custom 401 refresh logic needed).
- **D-04:** Static splash during `loading` state: a `Container` with `TraevyTokensExt.bg` fill + centered `TraevyLogoMark`. Not a named route — rendered inline from `app.dart`'s `authStateProvider.when(loading: ...)`.

### Skip / Optional Sign-In

- **D-05:** Sign-in is **optional**. Guest users reach `MainShell` by tapping "Sign in later" on the onboarding screen. The app is fully functional offline without an account.
- **D-06:** `AuthState` has three values — `loading`, `guest`, `signedIn`. Guest is a valid permanent state, not a fallback.
- **D-07:** Settings → Account section is **state-aware**:
  - **Guest state:** Replace `AccountRow` with a single "Sign in to back up" row — Google icon + label. Tapping opens the sign-in bottom sheet.
  - **Signed-in state:** Show `AccountRow` populated with the real Firebase profile name, email, and first-letter initial.
- **D-08:** Sign-in from Settings opens a **modal bottom sheet** over the Settings screen (not a full-screen navigation to `kRouteOnboarding`). Contains the Google sign-in button and a brief "Back up your commutes" headline. Dismissable.

### Auth Library

- **D-09:** Use **Firebase Auth (FlutterFire)** with the Google provider. Package stack: `firebase_core` + `firebase_auth` + `google_sign_in` + `flutter_secure_storage`. This is the first-party path (Google owns Flutter) and is dramatically simpler than the previous Cognito approach — no Hosted UI, no browser redirect, no deep-link callback, no manual `/oauth2/token` POST.
- **D-10:** `AuthService` owns the sign-in sequence as an **in-app flow** (no browser redirect): obtain a Google credential via `google_sign_in` → build a `GoogleAuthProvider` credential → `FirebaseAuth.instance.signInWithCredential(...)`. FlutterFire persists the session and refreshes ID tokens automatically. The current ID token (`user.getIdToken()`) is cached in `flutter_secure_storage` for the Phase 11 sync layer to attach to Cloud Function requests.

  > ✅ **Vendor switch (2026-05-29):** the Cognito Hosted UI + `amazon_cognito_identity_dart_2` + `url_launcher`/`app_links` deep-link approach from the prior spike (002a) is **dropped**. FlutterFire does the Google→Firebase exchange in-process. No deep link scheme, no `AndroidManifest` callback registration needed for auth.

- **D-10a:** No extra redirect/deep-link dependencies required. Project config comes from `flutterfire configure` (generates `firebase_options.dart`) and the `google-services.json` placed in `android/app/`. Pin FlutterFire versions in `pubspec.yaml` to a known-good set (FlutterFire moves fast).

### User ID Backfill

- **D-11:** Immediately after a successful sign-in, `AuthService.signIn()` runs a single Drift batch UPDATE: `UPDATE trips SET user_id = <firebaseUid> WHERE user_id = 'local_user'`. Same for `user_preferences`.
- **D-12:** After sign-in + backfill complete, navigate to a brief **confirmation screen**: "You're signed in. Your commutes will back up automatically." with the user's name/avatar and a "Let's go" button that pushes to `MainShell`. This is a one-time screen shown only at first sign-in.
- **D-13:** The merge/conflict UI (comparing local trips with cloud backup) is **deferred to Phase 11**. Phase 9 only does the local userId rewrite.

### Firebase Config Injection

- **D-14:** Firebase config comes from `flutterfire configure`, which generates `lib/firebase_options.dart` (committed). `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` runs in `main.dart` before `runApp`. No `--dart-define` flags needed.
- **D-15:** If Firebase fails to initialize or `google-services.json` is absent (e.g. a dev build without config), `AuthStateNotifier` starts in `guest` state and the sign-in button is disabled. App remains fully functional offline. No crash or assertion.
- **D-16:** Google OAuth + Firebase Android config are both handled by `google-services.json` placed in `android/app/` (plus the Google Services Gradle plugin). `google_sign_in` and `firebase_auth` read it automatically. SHA-1/SHA-256 fingerprints must be registered in the Firebase Console project.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Authentication — AUTH-01, AUTH-02, AUTH-03 (sign-in, session persistence, onboarding flow)
- `.planning/REQUIREMENTS.md` §Backend — BACK-01 (Firebase Auth with Google provider — Phase 9 Flutter side only)
- `cloud-vendor-tradeoffs.pdf` (repo root) — backend vendor decision (Firebase) and the Phase 9–11 implementation sketch
- `.planning/ROADMAP.md` §Phase 9 — success criteria and plan stubs

### Existing Scaffold (Phase 8 left these wired but no-op)
- `lib/features/onboarding/screens/onboarding_screen.dart` — "Continue with Google" button tap handler is a no-op; needs `AuthService.signIn()` call
- `lib/features/onboarding/widgets/google_continue_button.dart` — Google button widget (visual only in Phase 8)
- `lib/features/settings/widgets/account_row.dart` — accepts `name`, `email`, `initial` as constructor args; Phase 9 is the "constructor swap, not a widget rewrite"
- `lib/features/settings/screens/settings_screen.dart` §_AccountSection — currently uses `kPlaceholderUserName` / `kPlaceholderUserInitial`; needs auth-state-aware swap

### Placeholders to Replace
- `lib/config/constants.dart` — `kDefaultUserId = 'local_user'`, `kPlaceholderUserName`, `kPlaceholderUserInitial` — these remain as fallback values but real values come from `AuthState`
- `lib/database/tables/trips_table.dart` — `userId` defaults to `kDefaultUserId`; backfill replaces at runtime
- `lib/database/tables/user_preferences_table.dart` — same userId default

### App Root
- `lib/app.dart` — needs auth gate: `authStateProvider.when(loading/guest/signedIn)` replacing direct `home: const MainShell()`
- `lib/config/routes.dart` — `kRouteOnboarding` already registered; may need `kRouteSignInSuccess` for confirmation screen

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/onboarding/screens/onboarding_screen.dart` — UI scaffold complete; needs tap handler wiring only
- `lib/features/onboarding/widgets/google_continue_button.dart` — Google button visual; wire up with `onPressed: () => ref.read(authServiceProvider).signIn()`
- `lib/features/settings/widgets/account_row.dart` — already accepts runtime name/email/initial; no widget changes needed
- `lib/shared/widgets/traevy_logo_mark.dart` — use in static splash screen
- `lib/config/theme.dart` `TraevyTokensExt` — `bg`, `accentBg`, `accent`, `textDim` tokens needed for splash + confirmation screens

### Established Patterns
- **Riverpod manual providers (no codegen)** — locked. `AuthStateNotifier extends StateNotifier<AuthState>`. No `@riverpod` annotations. Consistent with every existing provider in the codebase.
- **`asyncPrefs.when(data/loading/error)`** — use the same pattern for `authStateProvider.when(signedIn/guest/loading)` in `app.dart`. Already used in `settings_screen.dart`.
- **Feature-first structure** — create `lib/features/auth/providers/auth_providers.dart`, `lib/features/auth/services/auth_service.dart`, `lib/features/auth/screens/` for splash + confirmation.
- **`ConsumerWidget`** — settings_screen.dart and dashboard widgets all use this. `_AccountSection` needs to become a `ConsumerWidget` to watch `authStateProvider`.

### Integration Points
- `lib/app.dart` line ~40 — `home: const MainShell()` becomes `home: _AuthGate()` (a `Consumer` widget watching `authStateProvider`)
- `lib/features/settings/screens/settings_screen.dart` `_AccountSection` — swap `AccountRow(kPlaceholderUserName...)` for auth-state-aware conditional
- `lib/database/daos/` — needs a `backfillUserId(String newId)` method (or inline UPDATE in `TripsDao`) called from `AuthService.signIn()`
- `pubspec.yaml` — add `firebase_core`, `firebase_auth`, `google_sign_in`, `flutter_secure_storage` (pin FlutterFire versions)

</code_context>

<specifics>
## Specific Ideas

- The confirmation screen after sign-in (D-12) is a **one-time screen**, not a persistent route. Show it once, then the user never sees it again. Gate with a `first_sign_in_shown` flag in `user_preferences` or simply navigate to MainShell and pop the confirmation after a short delay/tap.
- Bottom sheet for Settings sign-in (D-08) should include: Google icon + "Back up your commutes" headline + brief "Your trips sync automatically when you sign in." subtext + "Continue with Google" button.
- If Firebase isn't configured (init failed / `google-services.json` absent), the sign-in button in both onboarding and the Settings bottom sheet should be visually disabled with a tooltip: "Sign-in not configured" (dev/test builds).

</specifics>

<deferred>
## Deferred Ideas

- **Merge/conflict UI (local vs cloud trips)** — User wanted a "merge local trips with cloud on sign-in" flow. Deferred to Phase 11 restore flow where the backend connection exists.
- **Sign-out / account deletion** — Not in Phase 9 scope. Deferred to a future phase.
- **Token refresh flow** — Lazy refresh via 401 handling deferred to Phase 11 (when API calls actually happen).
- **Push notification permission prompt** — Came up tangentially; deferred (already handled in Phase 7).

### Reviewed Todos (not folded)
- `bug-manual-entry-missing-traffic-fields.md` — False positive match. About missing traffic time/distance fields in manual trip entry. Not related to auth. Remains in backlog.

</deferred>

---

*Phase: 9-Authentication*
*Context gathered: 2026-05-21*
