# Phase 20: First-Run Login with Skip - Context

**Gathered:** 2026-06-06 (--auto; gate + sync correctness reviewed with Gemini)
**Status:** Ready for planning

<domain>
## Phase Boundary

On first install, show a login screen offering Google sign-in AND a clearly visible Skip. Skip drops into the full app (local-only), persists across restarts, and shows a non-nagging "not connected" indicator. The user can sign in later from settings, after which local trips sync. Most backend plumbing already exists — this phase is mostly the first-run gate UI + a persisted flag + one sync-queue correctness fix.

**What ALREADY exists (do NOT rebuild — verify + reuse):**
- Guest mode: trips + user_preferences default `userId = kDefaultUserId ('local_user')`. AuthGuest is a valid permanent state that gives full local access.
- Sync already gates on auth: `sync_engine` only processes when `authStateProvider is AuthSignedIn` (guest = no sync attempts).
- Sign-in migration: `AuthService.signIn()` already backfills trips + prefs to the real uid in a Drift transaction (`trips_dao.backfillUserId`, `prefs_dao.backfillUserId`) and returns a first-sign-in signal.
- An `OnboardingScreen` (logo + feature ticks + Google continue button) exists but is NOT currently used as a gate.

**In scope:**
- A persisted first-run flag so the login screen shows ONLY on a never-decided first launch (SC#2).
- The first-run login screen (adapt `OnboardingScreen`) with Google sign-in + a clearly visible **Skip** (SC#1).
- Root-gate logic that composes auth state + the flag with NO flash of either screen (SC#1/2).
- A non-nagging guest "not connected" indicator with a sign-in CTA (SC#3).
- Fix the guest→sign-in sync backlog so previously-queued `local_user` pending items sync with the correct uid exactly once (SC#4).

**Out of scope:**
- Reworking the Google sign-in mechanism itself (Phase 9, works).
- Email/password or other providers.
- Two-way sync; the existing one-way push is unchanged.
- Geofence (Phase 21), widget (Phase 22).

</domain>

<decisions>
## Implementation Decisions

### First-run flag + gate (AUTH-04, SC#1/2)
- **D-01:** Persist a **`has_seen_onboarding` boolean** (default false) on the single-row `user_preferences` Drift table — consistent with Drift-as-source-of-truth; do NOT introduce shared_preferences. Schema bump **v4 → v5** (single `addColumn`, default false → existing installs read false; but see D-02 for the returning-user guard). v5 schema snapshot + migration test per convention.
- **D-02:** **Returning-user safety:** existing installs (pre-v5) would get `has_seen_onboarding = false` and wrongly see the login wall after update. Guard against this in the v5 migration: in `onUpgrade from < 5`, after adding the column, **set `has_seen_onboarding = true` for the existing row** (an already-running install has, by definition, already passed first-run). Fresh installs (onCreate) keep the default false. (This makes the wall truly first-install-only.)
- **D-03:** **No-flash gate** (Gemini): the root (`app.dart`) routes off BOTH `authStateProvider` and the initial `userPreferenceProvider` read:
  - `AuthLoading` OR prefs still loading → `SplashScreen` (no flash either way).
  - `AuthSignedIn` → `MainShell` (never show the wall to a signed-in user).
  - `AuthGuest` AND `hasSeenOnboarding == true` → `MainShell`.
  - `AuthGuest` AND `hasSeenOnboarding == false` → the first-run **LoginScreen**.
  Keep the existing sealed `switch` exhaustiveness discipline.

### Login screen + Skip (AUTH-04, SC#1)
- **D-04:** Build the first-run LoginScreen by adapting `OnboardingScreen` (reuse logo + feature ticks + the Google continue button) and adding a clearly visible **Skip** action (text/secondary button — visible, not hidden). Google path → `AuthService.signIn()` then set `has_seen_onboarding = true`. Skip → set `has_seen_onboarding = true` and route to `MainShell` (no sign-in). Both write the flag via a prefs DAO method.
- **D-05:** Setting the flag must be its own small prefs DAO update (e.g. `setHasSeenOnboarding(true)`), written before/at navigation so the gate is stable across restarts.

### Guest "not connected" indicator (AUTH-04, SC#3)
- **D-06:** A small, unobtrusive indicator (e.g. `Icons.cloud_off` / outlined account) shown only in guest mode — placement in the MainShell top bar or dashboard header. NO persistent snackbars/popups (non-nagging, Gemini). Tapping it opens a sign-in CTA (bottom sheet or routes to the settings account section) with copy like "You're in offline mode. Sign in to back up your trips." + the Google sign-in button. Reuse the existing `sign_in_sheet.dart` if suitable.
- **D-07:** Settings already has the account/profile section — ensure it presents a clear "Sign in" entry while guest and the signed-in identity once signed in (verify Phase 9 settings still correct; minimal change).

### SC#4 — guest→sign-in sync backlog correctness
- **D-08:** Server derives uid from the verified Firebase token regardless of payload, BUT the client must be pristine: during the sign-in Drift transaction (right after `backfillUserId`), **reconcile pending sync_queue items** that reference `local_user` so they carry the real uid — either re-serialize each pending payload's `userId` → uid, OR delete the pending items for those trips and re-enqueue from the freshly-backfilled Drift rows (planner picks based on the actual sync_queue payload shape). Net effect: after sign-in the guest's backlog syncs once with the correct uid, no duplicates. Add a test proving a guest-saved trip's pending queue item ends up with the real uid after sign-in.
- **D-09:** Whatever exists for trips already (verify): if guest trips were NOT enqueued at save (because enqueue was auth-gated), then on first sign-in enqueue all `local_user` trips for sync. Planner must determine the actual current behavior (enqueue-at-save vs enqueue-on-sign-in) and ensure exactly-once sync of the backlog. This is the riskiest correctness point — pin it with a test.

### Claude's Discretion (resolve in planning)
- Whether the LoginScreen is a new screen or a parameterized `OnboardingScreen` with a `showSkip`/onSkip — prefer reusing/parameterizing to avoid duplication.
- Exact indicator placement (shell app bar vs dashboard header) — pick the one surface that's always visible in guest mode.
- Whether D-08 uses re-serialize vs delete+re-enqueue — based on the real `sync_queue` payload + `SyncQueueDao` API.

</decisions>

<canonical_refs>
## Canonical References

- Root gate: `lib/app.dart` (the AuthState switch — extend with the prefs flag)
- Auth: `lib/features/auth/models/auth_state.dart` (sealed AuthLoading/Guest/SignedIn), `lib/features/auth/providers/auth_providers.dart`, `lib/features/auth/services/auth_service.dart` (`signIn()` Step 6 backfill — extend for D-08), `lib/features/auth/widgets/sign_in_sheet.dart`, `lib/features/auth/screens/splash_screen.dart`
- Onboarding (adapt to LoginScreen): `lib/features/onboarding/screens/onboarding_screen.dart`, `lib/features/onboarding/widgets/google_continue_button.dart`, `lib/config/routes.dart` (`kRouteOnboarding`)
- Prefs: `lib/database/tables/user_preferences_table.dart`, `lib/database/daos/user_preferences_dao.dart` (add `has_seen_onboarding` + setter; note existing `backfillUserId`/`rewriteUserId`), `lib/features/settings/providers/settings_providers.dart` (`userPreferenceProvider`)
- DB + migration: `lib/database/database.dart` (schemaVersion 4 → 5), `drift_schemas/`, `test/generated_migrations/`
- Sync: `lib/sync/sync_engine.dart` (`isSignedIn` gate, line ~379), `lib/sync/api_client.dart` (`notSignedIn` skip), `lib/database/daos/sync_queue_dao.dart`, `lib/database/daos/trips_dao.dart` (`backfillUserId` ~line 178)
- Settings account section: `lib/features/settings/screens/settings_screen.dart`
- Constants: `lib/config/constants.dart` (`kDefaultUserId='local_user'`)
- Requirements: AUTH-04. ROADMAP Phase 20 SC#1–4.

