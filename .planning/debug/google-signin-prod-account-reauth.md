---
status: resolved
trigger: "the login is not working"
created: 2026-07-26T00:00:00Z
updated: 2026-07-31T01:30:00Z
---

## Current Focus
<!-- OVERWRITE on each update - always reflects NOW -->

hypothesis: RESOLVED. Two DISTINCT root causes, fixed separately, produced
the identical `UNREGISTERED_ON_API_CONSOLE` / `Account reauth failed` /
`Activity finished with error` signature — which is why the investigation
initially believed one fix would explain everything and had to reopen after
a Play Store install failed the same way.

Root cause #1 (fixed first, explains the DEBUG-build failures): Google
enforces global uniqueness of the pair `(package_name, certificate_SHA-1)` →
Android OAuth client, across ALL Google Cloud projects, not just within one
project. The debug keystore cert
(B2:19:89:D3:73:4B:38:84:35:7F:0B:53:1D:68:16:86:2F:68:F4:DA) + package
`traevy.traevy` already had an auto-created Android OAuth client sitting in
the OLD dev project `travey-298a7`, left over from Phase 9 development. That
global lock meant `traevy-prod` could never auto-create its own Android
OAuth client for that cert. `firebase apps:android:sha:create` accepted the
SHA row regardless (so `sha:list` showed all 6 hashes registered), but the
backing OAuth client was never created.

Root cause #2 (found afterward, when the SAME failure recurred on a Play
Store install even after root cause #1 was fixed): Play App Signing does
NOT deliver the app signed with the single cert shown on the Play Console
"App signing key certificate" page. It delivers a THREE-certificate APK
(v3.0, v3.2 Hybrid Classical, v3.2 Hybrid PQC — the latter pair gated at
`minSdkVersion=37` for Android's post-quantum signing rollout), and TWO of
those three certs (v3.0 and v3.2 PQC) were never registered on `traevy-prod`
because the Play Console page only ever surfaces the v3.2 Classical cert.
Those two certs are discoverable only by pulling the delivered APK off a
device and inspecting its signature blocks with `apksigner`. See
`## Resolution` for both full writeups.

test: For root cause #2 — pulled the Play-delivered APK off the test device
(`adb shell pm path` + `adb pull`), ran
`apksigner verify --print-certs --verbose`, identified the two missing
SHA-1/SHA-256 pairs, registered all four missing hashes (both SHA-1s and
both SHA-256s) via `firebase apps:android:sha:create`, force-stopped the
already-installed Play app (no rebuild or re-upload), and re-tested sign-in
on the SAME installed build (version code 2,
`installerPackageName=com.android.vending`).
expecting: Confirmed. Sign-in succeeded on the Play-installed build with no
new version uploaded. 5,511-line logcat capture, zero occurrences of
`UNREGISTERED_ON_API_CONSOLE` / `Account reauth failed` / `Activity finished
with error` / `GetCredentialResponse error`. Flow reads
`[AccountReauth_flowRunner] Flow completed.`,
`[GoogleSignIn_flowRunner] Flow completed.`,
`Activity finished successfully`.
next_action: Investigation closed — both DEBUG builds and the actual Play
Store-installed release build are confirmed working. Outstanding follow-ups
(none blocking, none part of this bug):
  1. Any future signing-cert rotation by Play will silently reintroduce this
     failure mode. Re-run `apksigner verify --print-certs --verbose` on the
     Play-delivered APK (pulled via `adb shell pm path` + `adb pull`) after
     any future Play signing key change — never trust the Play Console "App
     signing key certificate" page alone, it has been shown to surface only
     one of the (potentially several) certs actually delivered.
  2. `lib/firebase_options.dart:61-66` — the iOS block still points at the
     old dev project (`projectId: 'travey-298a7'`, messagingSenderId
     `1076279794226`, plus a stale `iosClientId`). Harmless today since the
     app is Android-only, but it is an unmigrated Phase 37 remnant — clean
     up before any iOS work starts.
  3. The debug keystore's SHA-256
     (89c4fad775edbd39a2086f1f7491f418b7599e410293ba43356d8ed2e6369ef0) is
     still registered on `travey-298a7`; only its SHA-1 row was deleted
     during this investigation. Worth cleaning up if that project is ever
     decommissioned.

## Symptoms
<!-- Written during gathering, then immutable -->

expected: Tapping "Continue with Google" opens the Google account picker,
selecting an account signs the user in (AuthSignedIn state, dashboard shown).
actual: Account picker opens correctly. Selecting an account causes the
picker to close and the app returns to the login screen with NO visible
error, toast, or any UI feedback — looks like nothing happened.
errors: (native/system level, not visible in the app's own UI or Flutter
debug console — the app's own code swallows the exception, see Evidence)
Android system logcat shows:
```
[AccountReauth_flowRunner] Flow failed. [CONTEXT service_id=68 ]
cmsh: [8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE].
...
[GoogleSignIn_flowRunner] Flow failed. [CONTEXT service_id=68 ]
cmsh: [16] Account reauth failed.
...
[GoogleSignInChimeraActivity] Activity finished with error.
```
followed by `CredManProvService: GetCredentialResponse error returned from
framework`.
reproduction: Install the app (any signing cert — release/Play-distributed,
or a locally-built debug APK), tap "Continue with Google" on the first-run
login screen (or Settings → sign-in sheet), pick any Google account.
Reproduces 100% of the time, on every cert and every account tried so far.
started: First noticed immediately after Phase 37's migration of the Android
app + backend from the dev Firebase project (`travey-298a7`) to a new prod
project (`traevy-prod`, migrated 2026-07-26). Never confirmed working on
`traevy-prod` at all yet — only ever worked (per user's recollection) on the
older dev project, likely months ago during initial Phase 9 development.

## Eliminated
<!-- APPEND only - prevents re-investigating after /clear -->

- hypothesis: No Android OAuth client / SHA cert registered in traevy-prod
  (RELEASE-GATES.md flagged this explicitly as a known-open gate).
  evidence: Registered the upload keystore's SHA-1
  (79:00:01:D5:1D:FC:31:3A:4B:9B:DD:7F:8C:1B:BF:78:11:69:02:1D) and SHA-256 via
  `firebase apps:android:sha:create`. Confirmed via `sha:list`. Still failed
  identically on a rebuilt, freshly-signed release APK.
  timestamp: 2026-07-26

- hypothesis: `kGoogleServerClientId` (lib/config/constants.dart) still
  pointed at the OLD dev project's web OAuth client after the Phase 37 prod
  migration (confirmed: it was `1076279794226-...` = travey-298a7's project
  number, not traevy-prod's `506224691565`).
  evidence: Fixed to traevy-prod's actual web client ID
  (`506224691565-6abqullmr7enadsjn7hpgbgit4no3eqf.apps.googleusercontent.com`),
  rebuilt. Still failed identically.
  timestamp: 2026-07-26

- hypothesis: Play App Signing re-signs the app with a DIFFERENT cert than the
  local upload key once distributed via Play Store, and that cert's SHA
  wasn't registered.
  evidence: Retrieved the actual "App signing key certificate" SHA-1
  (79:63:FC:88:28:A4:89:92:F0:FE:21:8D:9C:89:BC:7F:51:40:A7:7D) and SHA-256
  (BB:F3:7E:DE:...:A0:47) from Play Console → Setup → App integrity, confirmed
  DIFFERENT from the upload key's hashes, registered both via
  `firebase apps:android:sha:create`. Confirmed via `sha:list`. Still failed
  identically on the actual Play Store-installed app.
  timestamp: 2026-07-29 (session date; see note on date discontinuity below)

- hypothesis: OAuth consent screen stuck in "Testing" publishing status,
  restricting sign-in to an explicit test-user allowlist.
  evidence: Confirmed via screenshot the consent screen ("Google Auth
  Platform" → Audience) was in Testing. Filled in required Branding fields
  (App name, support email, App domain = traevy.com /
  https://traevy.com/privacy, Authorised domains), explicitly clicked
  "Publish App". Confirmed via screenshot: Publishing status now "In
  production", User type "External", 0/100 OAuth user cap (does not apply —
  app only requests basic openid/email/profile scopes, no `.scopes()` call
  anywhere in the codebase). Still failed identically after publishing.
  timestamp: 2026-07-29

- hypothesis: Stale local device cache (app data or Google Play Services
  cache) referencing an earlier broken config from earlier in this same
  debugging session.
  evidence: User explicitly cleared app storage and Play Services
  storage/cache on the test device ("cleared the storage and everything").
  Still failed identically.
  timestamp: 2026-07-29

- hypothesis: Stale saved "Sign in with Google" credential/passkey tied
  specifically to the user's own Google account (server-side, in Google
  Password Manager, would survive local cache clears).
  evidence: Tested with a second Google account never previously used with
  this app. Failed identically (same AccountReauth/UNREGISTERED_ON_API_CONSOLE
  pattern).
  timestamp: 2026-07-29

- hypothesis: The failure is specific to one particular signing certificate
  (i.e., maybe the Play App Signing key specifically has some issue distinct
  from the upload key).
  evidence: Registered a THIRD certificate — the local debug keystore's SHA-1
  (B2:19:89:D3:73:4B:38:84:35:7F:0B:53:1D:68:16:86:2F:68:F4:DA) and SHA-256 —
  built and ran a debug APK via `flutter run` directly on the device
  (bypassing Play Store/Play App Signing entirely). `VerifyCallerOperation`
  (the package-name + cert check) succeeded for this cert too, exactly like
  the other two. The failure still occurred at the identical later step
  (`AccountReauth_flowRunner`, `UNREGISTERED_ON_API_CONSOLE`). This
  conclusively rules out "wrong/missing cert" as the cause — 3 different
  certs, 3 identical failures at the identical step.
  timestamp: 2026-07-29

- hypothesis: A required Google Cloud API isn't enabled on traevy-prod (e.g.
  Identity Toolkit API, People API).
  evidence: `gcloud services list --enabled --project=traevy-prod` confirms
  `identitytoolkit.googleapis.com` IS enabled. `people.googleapis.com` is
  NOT enabled — but it's also NOT enabled on the older dev project
  (`travey-298a7`), which (per user recollection) worked fine previously, so
  its absence is not a prod-vs-dev differentiator. Not conclusively ruled
  out as a general requirement, but ruled out as explaining the prod-specific
  failure.
  timestamp: 2026-07-29

- CORRECTION (supersedes the entry above dated 2026-07-29 that begins "The
  failure is specific to one particular signing certificate..."): that
  entry's conclusion — "3 different certs, 3 identical failures at the
  identical step... conclusively rules out 'wrong/missing cert' as the
  cause" — was WRONG. The debug cert's failure was genuinely caused by a
  missing Android OAuth client (see `## Resolution` for the confirmed root
  cause). `VerifyCallerOperation` succeeding for that cert was misleading:
  it validates package name + certificate hash only, and does NOT require
  the Android OAuth client that the later AccountReauth/token-mint step
  needs. The original entry is left in place above (this file is
  append-only) but its conclusion must not be trusted.
  timestamp: 2026-07-29 (this session, later same day)

- hypothesis: Firebase Auth → Google provider disabled on traevy-prod (the
  file's previously flagged `next_action`).
  evidence: Identity Toolkit admin API
  `GET /admin/v2/projects/traevy-prod/defaultSupportedIdpConfigs` returned
  `enabled: true` with
  `clientId: 506224691565-6abqullmr7enadsjn7hpgbgit4no3eqf...`, matching
  `kGoogleServerClientId`. Ruled out without needing the Firebase Console.
  timestamp: 2026-07-29 (this session, later same day)

- hypothesis: A missing/un-enabled GCP API on traevy-prod (beyond the
  Identity Toolkit / People API check already logged above) is blocking the
  flow.
  evidence: `gcloud services list --enabled` output is byte-identical
  between `traevy-prod` and the known-working `travey-298a7`.
  timestamp: 2026-07-29 (this session, later same day)

- hypothesis: A google_sign_in 6.x→7.x package migration confound is
  involved (e.g. the Credential Manager code path behaving differently
  post-migration).
  evidence: `git log -L '/google_sign_in/,+1:pubspec.yaml'` shows
  `google_sign_in: ^7.2.0` already present in the very commit that
  introduced it (`2a86915`, Phase 9). The Credential Manager code path was
  never different across the timeline in question.
  timestamp: 2026-07-29 (this session, later same day)

## Evidence
<!-- APPEND only - facts discovered during investigation -->

- timestamp: 2026-07-29
  checked: `adb logcat` during a release-APK (Play Store install) sign-in
  attempt, filtered for Credential Manager / Auth.Api.Credentials tags.
  found: Full sequence succeeds through `GenerateCallerVerificationTokenOperation`
  (succeeded), `GetGoogleIdOperation` (succeeded), `CredentialManager`
  reaches `CREDENTIALS_RECEIVED`, `GoogleSignInActivity` (assisted sign-in)
  is launched and displayed, user selects an account
  (`onUiEntrySelected entryType: credential_key`), THEN
  `[AccountReauth_flowRunner] Flow failed ... UNREGISTERED_ON_API_CONSOLE`,
  then `[GoogleSignIn_flowRunner] Flow failed ... Account reauth failed`,
  then `[GoogleSignInChimeraActivity] Activity finished with error`, then
  `CredManProvService: GetCredentialResponse error returned from framework`.
  implication: The failure is not in package/cert verification (that step
  passes) — it's in a distinct, later "account reauth" sub-flow that Google
  Play Services runs as part of the "assisted sign-in" UI path.

- timestamp: 2026-07-29
  checked: Same log sequence, reproduced with a locally-run `flutter run
  --debug` build (debug keystore cert, third distinct cert tested).
  found: Byte-for-byte identical failure signature at the identical step.
  implication: Confirms the issue is cert-independent — see Eliminated entry
  above.

- timestamp: 2026-07-29
  checked: `backend/functions/src/utils/auth.ts` / app code for any custom
  OAuth scope requests.
  found: No `.scopes(...)` call anywhere in `lib/main.dart` or
  `lib/features/auth/services/auth_service.dart` — only default
  `openid`/`email`/`profile` scopes are requested via
  `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)`
  (main.dart:152).
  implication: Rules out a sensitive/restricted-scope verification
  requirement as the blocker; also means the "0/100 OAuth user cap" seen on
  the Audience page is inapplicable/cosmetic for this app.

- timestamp: 2026-07-29
  checked: Google Cloud Console (traevy-prod) → Google Auth Platform →
  Clients.
  found: Exactly 3 OAuth clients exist: two "Android client for
  traevy.traevy (auto created by Google Service)" entries (one per
  registered Android SHA at time of screenshot — upload key and Play App
  Signing key; the debug key's SHA was registered afterward and had not yet
  produced a third auto-created client entry in a `google-services.json`
  pull, though `firebase apps:android:sha:list` confirmed the debug SHA hash
  registration itself succeeded — possible propagation lag on the
  auto-created-client side specifically, not the underlying SHA registration).
  One "Web client (auto created by Google Service)",
  ID `506224691565-6abqullmr7enadsjn7hpgbgit4no3eqf.apps.googleusercontent.com`
  — matches the (now-fixed) `kGoogleServerClientId`. Its Authorised redirect
  URI is the standard `https://traevy-prod.firebaseapp.com/__/auth/handler`,
  untouched/correct.
  implication: Web client config is correct and unmodified from Firebase's
  own defaults. The one open question is whether the debug key's
  auto-created Android client entry ever actually materialized server-side
  (not confirmed either way) — probably irrelevant since `VerifyCallerOperation`
  already succeeded for that cert in the logcat trace, meaning the SHA→package
  check passed regardless of whether a dedicated "Android client" row exists
  for it in this UI.

- timestamp: 2026-07-29
  checked: `.planning/RELEASE-GATES.md` (pre-existing project doc).
  found: This doc had ALREADY flagged, before this debugging session started,
  that traevy-prod had "no Android OAuth client / cert hash ... only the web
  client exists" as a known post-migration gap.
  implication: The SHA-registration fixes done early in this session were
  real, necessary fixes for a real documented gap — just not sufficient to
  explain the CURRENT remaining failure, which surfaced only after those
  fixes were in place and verified working (VerifyCallerOperation succeeding).

- timestamp: 2026-07-29
  checked: Added temporary diagnostic `debugPrint` calls in
  `lib/features/auth/screens/login_screen.dart` (`_onGoogleTap`'s catch
  blocks) and `lib/features/auth/widgets/sign_in_sheet.dart`
  (`_handleSignIn`'s catch blocks) — both previously swallowed EVERY
  exception (including non-cancel `GoogleSignInException` codes) with zero
  console output, by design (per their own dartdoc comments citing
  T-09-05-01/T-09-05-02). Now both print
  `[auth] GoogleSignInException: code=... description=...` or
  `[auth] signIn() failed: <type>: <message>` — safe, no token/credential
  ever included (verified: `GoogleSignInException.toString()` and
  `e.runtimeType` never carry the ID token).
  found: (not yet observed post-instrumentation — see Current Focus,
  `next_action`. The one test attempted right after adding these lines was
  inconclusive: user reported "no errors in debug console" but it's
  unconfirmed whether the running `flutter run` session had actually
  hot-restarted to pick up the new code before that attempt, since a prior
  `flutter run` process was left attached from an earlier install rather
  than being killed and restarted cleanly.)
  implication: This diagnostic is in place and uncommitted
  (`git status` shows both files modified) — a fresh session/agent picking
  this up should do a clean `flutter run` (kill any stale session first) and
  actually confirm the `[auth]` line appears in stdout on the next attempt,
  since that was never definitively confirmed working.

- timestamp: 2026-07-29
  checked: NOT yet checked this session — Firebase Console (not Cloud
  Console) → traevy-prod project → Authentication → Sign-in method → Google
  provider toggle.
  found: n/a — this is the flagged next_action, not yet done.
  implication: This is a real, distinct Firebase-Auth-level setting
  (separate from the GCP OAuth-client/consent-screen work already verified)
  that has never been explicitly confirmed ON for traevy-prod in this
  session. Cheap, high-value, next thing to check.

- timestamp: 2026-07-29 (this session, later same day)
  checked: Deleted the debug cert's SHA row from traevy-prod via
  `firebase apps:android:sha:delete`, then re-ran
  `firebase apps:android:sha:create` to re-add it.
  found: The re-add returned `409 ALREADY_EXISTS: "Oauth client already
  exists in a different project for package name traevy.traevy and
  certificate hash B2:19:89:D3:...:F4:DA."`
  implication: This is the proof of the actual root cause — the debug
  cert's Android OAuth client already existed, but in `travey-298a7`, not
  `traevy-prod`. Google's global uniqueness on (package, cert) blocked
  auto-creation in the new project.

- timestamp: 2026-07-29 (this session, later same day)
  checked: Compared `firebase apps:android:sha:list` (SHA rows registered
  on traevy-prod) against the LIVE backend config from
  `firebase apps:sdkconfig ANDROID <appId> --project traevy-prod` (actual
  OAuth client entries with `client_type: 1`).
  found: `sha:list` showed 3 SHA-1s registered; `sdkconfig` showed only 2
  `client_type: 1` (Android OAuth client) entries. The debug cert had a SHA
  row but no backing OAuth client.
  implication: This is the decisive diagnostic technique for this whole bug
  class — `sha:list` proves a SHA hash was accepted, NOT that an OAuth
  client was created for it. Recorded as the standing detection method for
  any future recurrence (see `## Current Focus` next_action).

- timestamp: 2026-07-29 (this session, later same day)
  checked: `dumpsys package traevy.traevy` on the test device during the
  most recent round of failing tests.
  found: `installerPackageName=null`, confirming the app was installed via
  `adb`/`flutter run` (debug build), not via Play Store.
  implication: Those particular failing tests were running with precisely
  the debug cert that had no OAuth client — consistent with, and part of
  the evidence for, the confirmed root cause.

- timestamp: 2026-07-29 (this session, later same day)
  checked: Device and Google Play Services state on the test device.
  found: Pixel 9a, Android 17 (SDK 37), Google Play Services 26.26.34 — not
  stale.
  implication: Rules out a stale/outdated Play Services version as a
  contributing factor; the device and GMS were current throughout.

- timestamp: 2026-07-29 (this session, later same day)
  checked: All Google sign-in entry points in the app for exception
  handling.
  found: A third entry point,
  `lib/features/onboarding/screens/onboarding_screen.dart`, had bare
  `on GoogleSignInException {}` and `on Object {}` catches that silently
  swallowed everything. `lib/main.dart`'s bootstrap catch was also fully
  silent.
  implication: Likely explains the earlier inconclusive "no errors in debug
  console" result logged above — the app had multiple silent-catch paths,
  not just the two already instrumented with `[auth]` debugPrint lines.

- timestamp: 2026-07-29 (this session, later same day)
  checked: The Google Cloud / Firebase project list under this account.
  found: Three similarly-named projects exist — `traevy-prod`,
  `traevy-492415` (display name "traevy"), and `travey-298a7` (display name
  "travey", misspelled). Initial Console navigation during this session went
  to the wrong one before the correct `travey-298a7` was identified as the
  source of the orphaned OAuth client.
  implication: Worth recording as a standing trap for anyone navigating
  these projects by display name in the Console — verify the project ID in
  the URL/selector, not just the display name.

- timestamp: 2026-07-31 (this session, root cause #2 investigation)
  checked: Google Cloud Console project picker, while attempting to delete
  the orphaned OAuth client as part of confirming root cause #2.
  found: A project-navigation trap that cost time: the Console project
  picker was on the wrong project. The account has three similarly-named
  projects — `traevy-prod`, `traevy-492415` (display name "traevy"), and
  `travey-298a7` (display name "travey", MISSPELLED). Deleting the orphaned
  OAuth client required being in `travey-298a7`; the user was initially in
  `traevy-prod`, where the two visible Android clients were the (correct,
  expected) upload and Play App Signing clients.
  implication: Confirms this is a recurring trap across both root-cause
  investigations in this file, not a one-off — same three-project confusion
  as the earlier entry above, hit again in a later session.

- timestamp: 2026-07-31 (this session, root cause #2 investigation)
  checked: What "proof of registration" actually means, now that two
  distinct root causes have both hidden behind a passing check.
  found: The standing detection method now covers BOTH root causes.
  Root cause #1: cross-check `firebase apps:android:sha:list` against the
  LIVE `firebase apps:sdkconfig ANDROID <appId> --project <project>`
  output — a registered SHA row is NOT proof a backing OAuth client exists.
  Root cause #2: for any Play-distributed build, enumerate the delivered
  APK's real certs with `apksigner verify --print-certs --verbose` rather
  than trusting Play Console's single displayed cert — the Console's "App
  signing key certificate" page shows only one of potentially several certs
  actually shipped to devices.
  implication: Both checks are now the standing verification procedure for
  this app; neither one alone would have caught the other's failure mode.

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: CONFIRMED — two DISTINCT root causes, fixed separately, each
independently capable of producing the exact same
`UNREGISTERED_ON_API_CONSOLE` / `Account reauth failed` / `Activity
finished with error` signature. Root cause #1 explains the DEBUG-build
failures. Root cause #2, found afterward, explains the PLAY-STORE-install
failures that persisted even after root cause #1 was fixed.

### Root cause #1 — orphaned OAuth client in the old dev project

Google enforces global uniqueness of the pair
`(package_name, certificate_SHA-1)` → Android OAuth client, across ALL
Google Cloud projects, not just within one project. The debug keystore cert
(B2:19:89:D3:73:4B:38:84:35:7F:0B:53:1D:68:16:86:2F:68:F4:DA) + package
`traevy.traevy` already had an auto-created Android OAuth client in the OLD
dev project `travey-298a7`, left over from Phase 9 development. That global
lock meant `traevy-prod` could NEVER auto-create its own Android OAuth
client for that cert.

Critically, this failed silently: `firebase apps:android:sha:create`
accepted the SHA row (so `apps:android:sha:list` showed all 6 hashes
registered, which is why the earlier investigation believed cert
registration had succeeded), but the backing OAuth client was never
created. The proof only surfaced when the SHA was deleted and re-added,
which returned `409 ALREADY_EXISTS: "Oauth client already exists in a
different project for package name traevy.traevy and certificate hash
B2:19:89:D3:...:F4:DA."` Play Services' AccountReauth step then had no
`(package, cert) → client` mapping in the serverClientId's project — which
is exactly what `UNREGISTERED_ON_API_CONSOLE` reports.

The diagnostic that exposed it: comparing `firebase apps:android:sha:list`
(showed 3 SHA-1s) against the LIVE backend config from
`firebase apps:sdkconfig ANDROID <appId> --project traevy-prod` (showed only
2 `client_type: 1` entries). The debug cert had a SHA row but no OAuth
client. This is the key technique to remember — the SHA list is NOT proof
an OAuth client exists.

Correction to an earlier conclusion in this file: the `## Eliminated` entry
dated 2026-07-29 claiming "3 different certs, 3 identical failures ... This
conclusively rules out 'wrong/missing cert' as the cause" was WRONG (see the
correction entry appended to `## Eliminated`). The debug cert's failure was
genuinely a missing OAuth client. `VerifyCallerOperation` succeeding was
misleading — it validates package+cert but does NOT require the OAuth
client that the later token-mint step needs.

Fix for root cause #1:
  1. `kGoogleServerClientId` corrected to traevy-prod's web client
     `506224691565-6abqullmr7enadsjn7hpgbgit4no3eqf.apps.googleusercontent.com`
     (was pointing at the old dev project's client). `lib/config/constants.dart`.
  2. Upload key, Play App Signing key, and debug key SHA-1/SHA-256
     registered on traevy-prod.
  3. OAuth consent screen published to "In production".
  4. The decisive step: deleted the orphaned Android OAuth client for
     `traevy.traevy` + debug cert from `travey-298a7` via Google Cloud
     Console (Google Auth Platform → Clients — there is NO CLI or API for
     deleting OAuth clients), then re-ran `firebase apps:android:sha:create`
     on traevy-prod. This time auto-creation succeeded, producing client
     `506224691565-1jh8mkdooaookrhtfctijdnmt6jfhbf7`.
  5. Regenerated `android/app/google-services.json`; the diff was exactly
     the addition of that one new debug android client, nothing else.

Verification for root cause #1: Debug APK (debug key `b21989d3...`), fresh
install: sign-in succeeded. 8,719-line logcat, zero failure markers, zero
`[auth]` diagnostic lines (none fired because nothing failed).

### Root cause #2 — Play App Signing delivers THREE certs, Console shows only ONE

After root cause #1 was fixed, the app was uploaded to Play, and sign-in
STILL failed from a Play Store install with the identical
`UNREGISTERED_ON_API_CONSOLE` signature. This is what actually broke PLAY
installs, distinct from the debug-build orphaned-client problem above.

Diagnosis: pulled the Play-delivered APK off the device
(`adb shell pm path`, `adb pull`) and ran
`apksigner verify --print-certs --verbose`. The APK Google Play delivers is
signed with THREE certificates, not one:

| Signer block | SHA-1 | Registered before this fix? |
|---|---|---|
| v3.0 | `ded10ff2915411e4d9da886b6f8a80443586a511` | NO |
| v3.2 Hybrid Classical (minSdkVersion=37) | `7963fc8828a48992f0fe218d9c89bc7f5140a77d` | YES |
| v3.2 Hybrid PQC (minSdkVersion=37) | `9725820cde6112dbddc31e6d36b62ec359d3af6f` | NO |

Corresponding SHA-256 values:
- v3.0: `0b32550bd5fb3fae4bad3322781053d02bdc95934ce64ae3416ab23d4b20bdd8`
- v3.2 Classical: `bbf37ede77769f47810acea970333522b3c55e3cad5e0f1179c4cd35e0f1a047`
- v3.2 PQC: `1fa212f879a16b1a1cb1e932e155701ece77f9a0455b1be9c1291ec52ea09de5`

The critical trap: Play Console's "App integrity → App signing key
certificate" page surfaces ONLY the v3.2 Classical cert (`7963fc88…`). That
is the only one a developer would ever know to register. The other two are
invisible from the Console and discoverable ONLY by pulling the delivered
APK from a device and inspecting its signature blocks. Play has rotated
this app's signing key (the platform reported a lineage:
`signatures:[cec52fbc], past signatures:[77e1ace9, efffeafd, cec52fbc]`),
and on Android 17 / SDK 37 it now dual-signs with a post-quantum key — hence
the v3.2 Hybrid Classical + PQC pair gated at `minSdkVersion=37`. The test
device (Pixel 9a) runs Android 17, right on that boundary.

Why this was so hard to see, and why it mimicked root cause #1 exactly:
`VerifyCallerOperation` SUCCEEDED on every attempt, because it accepts any
cert in the signing lineage. The failure came one step later at token mint,
where Google looks up an OAuth client for the SPECIFIC cert it resolved. A
passing `VerifyCallerOperation` is NOT evidence the cert is correctly
registered — that false signal is exactly what made the earlier
investigation repeatedly "prove" the certs were fine, for both root causes.

Fix for root cause #2: registered all four missing hashes (both SHA-1s and
both SHA-256s) on `traevy-prod` via `firebase apps:android:sha:create`. All
four registered with no 409 conflict. Two new Android OAuth clients
auto-created:
  - v3.0 cert → `506224691565-nkfiro9j6bi3uq2ut91hq4cr7p4e5q1`
  - v3.2 PQC cert → `506224691565-pmunde5c54lsv17i38d8el5i0t9iqif`

No rebuild or re-upload was required — the `(package, cert) → client`
mapping is resolved server-side in Google's auth backend, not baked into
the APK. The already-installed Play build began working after a
force-stop, with no new version uploaded. This is operationally important:
the fix for root cause #2 is entirely server-side, same as root cause #1.

Verification for root cause #2: user re-tested the SAME Play-installed
build (version code 2, `installerPackageName=com.android.vending`). Sign-in
succeeded. 5,511-line logcat capture, zero occurrences of
`UNREGISTERED_ON_API_CONSOLE` / `Account reauth failed` / `Activity finished
with error` / `GetCredentialResponse error`. Flows read
`[AccountReauth_flowRunner] Flow completed.`,
`[GoogleSignIn_flowRunner] Flow completed.`, `Activity finished
successfully.`.

### Remaining open question (honestly unresolved)

The PLAY-install failures ARE now fully explained by root cause #2 — the
2026-07-29 Play-installed-app failure is accounted for by the two missing
v3.0/v3.2-PQC certs above, and is no longer an open question.

What remains genuinely unresolved, and is stated plainly here rather than
glossed over: the single 2026-07-26 failure on a locally-built, upload-key-
signed release APK (i.e. NOT a Play-distributed build, so root cause #2's
multi-cert mechanism does not apply to it) is not conclusively explained by
either root cause, since the upload key had a valid, correctly-registered
OAuth client throughout. Between that failure and the eventual success, the
changes were the consent screen being published to production and elapsed
propagation time. Candidate causes: (a) OAuth-client/SHA propagation delay
in Google's auth backend, or (b) the consent-screen publish taking effect.
This could not be conclusively disambiguated with the evidence gathered —
neither is asserted as fact.

verification: Confirmed by the user on-device across both root causes,
logcat captured each time.
  - Release APK (upload key `790001d5...`), fresh install: sign-in
    succeeded. 8,651-line logcat, zero occurrences of
    `UNREGISTERED_ON_API_CONSOLE` / `Account reauth failed` / `Activity
    finished with error`.
  - Debug APK (debug key `b21989d3...`), fresh install: sign-in succeeded.
    8,719-line logcat, zero failure markers, zero `[auth]` diagnostic lines
    (none fired because nothing failed).
  - Play Store-installed build (root cause #2 fix, same installed APK, no
    reinstall): sign-in succeeded. 5,511-line logcat, zero occurrences of
    `UNREGISTERED_ON_API_CONSOLE` / `Account reauth failed` / `Activity
    finished with error` / `GetCredentialResponse error`.
  - The previously-failing steps now read:
    `[AccountReauth_flowRunner] Flow completed.`,
    `[GoogleSignIn_flowRunner] Flow completed.`,
    `[GoogleSignInChimeraActivity] Activity finished successfully.`,
    `CredManProvService: GetCredentialResponse returned from framework`.

files_changed:
  - lib/config/constants.dart (kGoogleServerClientId fixed to traevy-prod
    web client — part of the root cause #1 fix)
  - android/app/google-services.json (regenerated via `firebase
    apps:sdkconfig`, now includes the newly auto-created debug Android
    OAuth client `506224691565-1jh8mkdooaookrhtfctijdnmt6jfhbf7` from root
    cause #1)
  - lib/features/auth/screens/login_screen.dart (diagnostic debugPrint left
    in place; not load-bearing for either fix but useful for future
    debugging)
  - lib/features/auth/widgets/sign_in_sheet.dart (diagnostic debugPrint left
    in place; not load-bearing for either fix but useful for future
    debugging)
  - No app code change was the actual fix for either root cause — both were
    server-side: root cause #1's fix was deleting the orphaned OAuth client
    from `travey-298a7` and re-registering the SHA on `traevy-prod`; root
    cause #2's fix was registering the two previously-invisible Play
    App Signing certs (v3.0, v3.2 PQC) on `traevy-prod`. Neither required a
    rebuild, re-upload, or file change.

---

## Reference: exact state as of this handoff

**Firebase/GCP project:** `traevy-prod` (project number `506224691565`).
Android app ID: `1:506224691565:android:733f0ac76f1cab1277b264`, package
`traevy.traevy`.

**SHA certs registered on that Android app (confirmed via
`firebase apps:android:sha:list 1:506224691565:android:733f0ac76f1cab1277b264 --project traevy-prod`):**
6 total (3 SHA-1 + 3 SHA-256) — upload key, Play App Signing key, and local
debug key. All three verified passing `VerifyCallerOperation` in logcat.

**OAuth consent screen:** Publishing status = In production, User type =
External, no verification required/pending (basic scopes only).

**Test device used for every attempt so far:** Pixel 9a, adb serial
`63111XEBF4DEEC`. No other device or emulator has been tried yet.

**Note on dates:** this file's `updated` timestamp and some evidence
timestamps are taken from the live session clock (2026-07-29) even though
some early fixes in this same investigation were made and referenced as
"2026-07-26" earlier in the conversation transcript — both refer to the same
continuous debugging effort; the discrepancy is a pre-existing artifact of
the session's simulated date, not two separate incidents.
