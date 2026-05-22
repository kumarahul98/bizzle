# Phase 9: Authentication - Context

**Gathered:** 2026-05-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire Google Sign-In + AWS Cognito token exchange into the existing app skeleton. Deliver working sign-in, persistent session, and user identity linked to local trip data. Sign-in is optional — the app runs fully offline without an account.

**In scope:**
- `lib/features/auth/` feature directory (providers, services, screens)
- `AuthStateNotifier` with three states: loading / guest / signed-in
- `app.dart` auth gate: static splash → onboarding or MainShell
- `OnboardingScreen` tap handler wiring (button was no-op in Phase 8)
- Settings → Account section: guest CTA vs signed-in profile row
- Sign-in bottom sheet (for sign-in from Settings)
- Silent `userId` backfill in Drift (local_user → Cognito sub) on sign-in
- Post-sign-in confirmation screen
- Token persistence in `flutter_secure_storage`
- `--dart-define` constants for Cognito config

**Out of scope:**
- Backend Cognito User Pool setup (Phase 10)
- Trip sync to DynamoDB (Phase 11)
- Merge/conflict UI for local vs cloud trips (Phase 11)
- Sign-out / account deletion
- Token refresh (deferred — lazy refresh via 401 handling in Phase 11)

</domain>

<decisions>
## Implementation Decisions

### Auth Gate Routing

- **D-01:** `AuthStateNotifier` lives in `lib/features/auth/providers/`. It reads `flutter_secure_storage` on init and exposes three states: `AuthState.loading` / `AuthState.guest` / `AuthState.signedIn(sub, name, email)`.
- **D-02:** `app.dart` watches `authStateProvider` and renders accordingly: `loading` → static splash screen (Traevy logo + `bg` token background), `guest` → `MainShell()`, `signedIn` → `MainShell()`.
- **D-03:** On boot, trust the stored token by existence check only — no network validation. If a Cognito token exists in secure storage, emit `signedIn`. Refresh happens lazily when a sync/API call returns 401 (Phase 11).
- **D-04:** Static splash during `loading` state: a `Container` with `TraevyTokensExt.bg` fill + centered `TraevyLogoMark`. Not a named route — rendered inline from `app.dart`'s `authStateProvider.when(loading: ...)`.

### Skip / Optional Sign-In

- **D-05:** Sign-in is **optional**. Guest users reach `MainShell` by tapping "Sign in later" on the onboarding screen. The app is fully functional offline without an account.
- **D-06:** `AuthState` has three values — `loading`, `guest`, `signedIn`. Guest is a valid permanent state, not a fallback.
- **D-07:** Settings → Account section is **state-aware**:
  - **Guest state:** Replace `AccountRow` with a single "Sign in to back up" row — Google icon + label. Tapping opens the sign-in bottom sheet.
  - **Signed-in state:** Show `AccountRow` populated with real Cognito name, email, and first-letter initial.
- **D-08:** Sign-in from Settings opens a **modal bottom sheet** over the Settings screen (not a full-screen navigation to `kRouteOnboarding`). Contains the Google sign-in button and a brief "Back up your commutes" headline. Dismissable.

### Auth Library

- **D-09:** Keep the Google → Cognito token exchange. Package stack: `google_sign_in` + `amazon_cognito_identity_dart_2` + `flutter_secure_storage` + `url_launcher` + `app_links`. This keeps API Gateway's native Cognito Authorizer working in Phase 10 without a custom Lambda. Chosen over plain Google Sign-In for 30-day refresh token durability (Google tokens expire hourly).
- **D-10:** `AuthService` owns the sign-in sequence via **Cognito Hosted UI** (not a direct SDK token exchange — see spike finding below). Flow: launch Hosted UI URL in browser → user completes Google OAuth → Cognito redirects to deep link callback → app receives authorization code → POST to Cognito `/oauth2/token` endpoint → store tokens in `flutter_secure_storage`.

  > ⚠️ **Spike 002a finding:** `amazon_cognito_identity_dart_2` v3.7 has NO method that takes a Google ID token and returns a Cognito User Pool JWT directly. The package supports `USER_SRP_AUTH` and `CUSTOM_AUTH` only. The federated Google login flows through Cognito's Hosted UI. Planner must account for `url_launcher` + `app_links` (deep link handler) + HTTP POST to `/oauth2/token`. The Flutter-side sign-in is a browser redirect, not an in-app flow.

- **D-10a:** Additional pubspec dependencies required: `url_launcher: ^6.x`, `app_links: ^6.x` (deep link interception for the Cognito callback URI). Deep link scheme: `commutetracker://callback` — must be registered in `AndroidManifest.xml`.

### User ID Backfill

- **D-11:** Immediately after a successful sign-in, `AuthService.signIn()` runs a single Drift batch UPDATE: `UPDATE trips SET user_id = <cognitoSub> WHERE user_id = 'local_user'`. Same for `user_preferences`.
- **D-12:** After sign-in + backfill complete, navigate to a brief **confirmation screen**: "You're signed in. Your commutes will back up automatically." with the user's name/avatar and a "Let's go" button that pushes to `MainShell`. This is a one-time screen shown only at first sign-in.
- **D-13:** The merge/conflict UI (comparing local trips with cloud backup) is **deferred to Phase 11**. Phase 9 only does the local userId rewrite.

### Cognito Config Injection

- **D-14:** Cognito values injected via `--dart-define` build flags: `COGNITO_POOL_ID`, `COGNITO_CLIENT_ID`, `COGNITO_REGION`. Read in `lib/config/constants.dart` via `String.fromEnvironment()`.
- **D-15:** If Cognito config values are empty (missing `--dart-define` flags), `AuthStateNotifier` starts in `guest` state and the sign-in button is disabled. App remains fully functional offline. No crash or assertion.
- **D-16:** Google OAuth client ID is handled by `google-services.json` placed in `android/app/`. No `--dart-define` needed for Google config — `google_sign_in` reads it automatically.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Authentication — AUTH-01, AUTH-02, AUTH-03 (sign-in, session persistence, onboarding flow)
- `.planning/REQUIREMENTS.md` §Backend — BACK-01 (Cognito User Pool with Google federation — Phase 9 Flutter side only)
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
- `pubspec.yaml` — add `google_sign_in`, `amazon_cognito_identity_dart_2`, `flutter_secure_storage`

</code_context>

<specifics>
## Specific Ideas

- The confirmation screen after sign-in (D-12) is a **one-time screen**, not a persistent route. Show it once, then the user never sees it again. Gate with a `first_sign_in_shown` flag in `user_preferences` or simply navigate to MainShell and pop the confirmation after a short delay/tap.
- Bottom sheet for Settings sign-in (D-08) should include: Google icon + "Back up your commutes" headline + brief "Your trips sync automatically when you sign in." subtext + "Continue with Google" button.
- If `COGNITO_POOL_ID` is empty, the sign-in button in both onboarding and the Settings bottom sheet should be visually disabled with a tooltip: "Sign-in not configured" (dev/test builds).

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
