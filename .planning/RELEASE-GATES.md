# Release gates

Things that MUST be true before a release build ships to users. Not a nice-to-have
list — each item here is either a policy violation or a known-broken user experience
if skipped.

Check this file before building a release AAB/APK for the Play Store.

---

## 🟢 RESOLVED 2026-08-03 — Play Data Safety declaration (Phase 29, LOC-03)

**Status: SUBMITTED.** The App content section — including the Data Safety
declaration, the content rating questionnaire, target audience, and the
foreground-service-permissions declaration — was completed in the Play Console
on 2026-08-03.

The declaration content is preserved below as the record of WHAT was declared.
If the app's data handling changes, this is the sheet to diff against: any new
data type, purpose, or third-party SDK means the declaration must be resubmitted
before that build ships.

Note the two declarations that were REMOVED rather than answered, because the
app stopped needing the permissions behind them (both 2026-08-02):
`ACCESS_BACKGROUND_LOCATION` (quick-260802-itr — background GPS now relies on
the location-typed foreground service) and `USE_EXACT_ALARM` (quick-260802-x1q
— reminders moved to `inexactAllowWhileIdle`; the app is a commute tracker, not
an alarm clock or calendar, so it was never eligible). Neither may return
without re-opening a Play declaration; both are covered by regression tests in
`test/unit/android_manifest_permissions_test.dart`.

### What was declared (recorded 2026-08-02, submitted 2026-08-03)

`main` now contains code that uploads the user's saved Home and Office
coordinates to Firestore (`PreferencesSyncService`, merged from
`phase-29-sync-home-office`). The backend endpoints are deployed and live.

Before ANY release build carrying this code ships, the Play Console Data Safety
form must change from:

> no location data collected

to:

> **precise location** collected and stored, **linked to the user's account**

### Why this is a real blocker

Phase 21 originally decided (T-21-02) that these coordinates must never leave
the device, and wrote that guarantee into the schema's own dartdocs. Phase 29
reversed that deliberately — see D-01 in
`.planning/phases/29-sync-home-office-locations/29-PLAN.md`. The reversal is
legitimate, but it is exactly the kind of change Play's Data Safety declaration
exists to surface. Shipping undeclared collection of precise location risks app
removal and developer-account strikes.

### Why this file exists

Until 2026-07-20 the `phase-29-sync-home-office` branch being unmerged WAS the
enforcement mechanism — the code physically could not reach a release build.
That branch is now merged, so the structural guard is gone and this file
replaces it. Merging is not shipping; this gate is about shipping.

**T-21-03 was not reversed:** never log a coordinate. That still holds
everywhere.

### The answer sheet (recorded 2026-08-02 so it isn't re-derived under time pressure)

Declare as **COLLECTED**, all **"Linked to the user"**, **NONE shared** with
third parties:

| Category | Data type | Purpose | Required? |
|----------|-----------|---------|-----------|
| Location | Precise location (route polylines + Home/Office coords uploaded to Firestore) | App functionality | **Required** |
| Personal info | Email address (Firebase Auth via Google Sign-In) | Account management | Optional |
| Personal info | Name (`user.displayName`) | Account management | Optional |
| Personal info | User IDs (Firebase uid on every trip doc) | App functionality, Account management | Optional |
| App activity | Other user-generated content (trip records: times, duration, distance, direction, breaks) | App functionality | **Required** |

For every one of the five, the remaining two per-type questions answer the
same way: **Collected** (never "Shared"), and **not** processed ephemerally
(all of it is persisted).

On "Shared" — Firebase / Google Cloud is a **processor acting on our behalf**,
which Play explicitly excludes from its definition of sharing. The presence of
a third-party backend is not by itself a reason to tick "Shared". Nothing is
sold or handed to any third party for their own purposes.

**Required vs optional — the reasoning, in case it is ever questioned.**
The three Personal-info types are Optional because guest mode is real
(`AuthGuest`): the app is fully usable signed out, so the user genuinely
chooses whether to provide them. Precise location and trip content are
declared **Required** because GPS recording is the product's core purpose —
decided 2026-08-02. Note the arguable counter-position, recorded honestly:
Play's literal test for "optional" is whether the app remains usable without
the data, and it does (manual trip entry, history and stats all work with the
location permission denied). Required is the more conservative declaration and
was chosen deliberately; do not "correct" it to Optional without revisiting
this paragraph.

Declare **NOT collected**: advertising ID, contacts, photos, microphone,
financial info, health, messages, calendar, files. Verified by audit: the app
has no analytics, crash-reporting, ads, or third-party tracking SDK in
`pubspec.yaml`.

Security section answers: encrypted in transit — **YES**; users can request
data deletion — **YES**; location is **REQUIRED** for core function;
independent security review — **NO**; Play Families — **N/A**.

### Account-deletion URL for the Play Console

`https://traevy.com/privacy#delete-account` — the anchor exists in
`landing/src/pages/Privacy.jsx` and renders into the built output.

**Caveat — this URL is NOT live yet.** The landing site deploys from `main`
via Cloudflare's Git integration (there is no `.github/` directory in this
repo, so there's no separate CI deploy step to check — Cloudflare watches the
branch directly). As of 2026-08-02 there are **28 unpushed commits** on local
`main`, so this anchor will 404 until `main` is pushed. Push `main` before
submitting this URL to Play — submitting it first would fail validation.

---

## 🟢 Prod Firebase project — DONE (Android); iOS deferred

**Status: Android migrated 2026-07-26 (`3701dd3`), signing certs registered and
sign-in verified 2026-07-31 (`b2dc907`). Nothing outstanding for Android.**

The Android release build now targets a dedicated prod project **`traevy-prod`**
(#506224691565), not dev `travey-298a7`:

- ✅ `flutterfire configure` regenerated `google-services.json` +
  `firebase_options.dart` (Android) → traevy-prod.
- ✅ `kApiBaseUrl` → `https://us-central1-traevy-prod.cloudfunctions.net/api`
  (verified live: /health 200, /trips/restore 401).
- ✅ Backend deployed to traevy-prod: Firestore rules + indexes; Artifact
  Registry cleanup policy set. Firestore DB in `nam5` (US multi-region), kept
  by decision.
- ✅ **Cloud Functions confirmed live on traevy-prod, 2026-08-02** —
  `firebase deploy --only functions --project traevy-prod`. Deploy output
  confirmed runtime **Node.js 24 (2nd Gen)**, function `api(us-central1)`,
  URL `https://api-k3uvsqht3q-uc.a.run.app`. Route checks: `GET /health` →
  200; `DELETE /trips` → 401; `DELETE /account` → 401; `POST /trips/sync` →
  401; a bogus path → 404 (control, proving routing works so the 401s really
  mean registered + auth-gated). **Not verified:** the hard-delete behavior
  itself — that needs an authenticated token + real data, still outstanding.
  One non-urgent deploy warning: `firebase-functions` package is outdated
  (`npm install --save firebase-functions@latest` in `backend/functions`).
- ✅ **Play App Signing certs registered — DONE 2026-07-29 (`793a313`) and
  2026-07-31 (`b2dc907`).** This bullet previously said registration was still
  outstanding and claimed "no Android OAuth client / cert hash in the prod
  config; only the web client exists". That is FALSE and was stale: reading
  `android/app/google-services.json` shows **three** Android OAuth clients
  (`client_type: 1`) with cert hashes, plus the web client.

  The history matters, because this took two attempts and the second cause is
  non-obvious. Play delivers an APK signed with **three** certificates — a v3.0
  block plus v3.2 Hybrid Classical and v3.2 Hybrid PQC — and Play Console's
  "App signing key certificate" page surfaces only ONE of them, so that is the
  only cert a developer would know to register. `b2dc907` records the trap:
  `VerifyCallerOperation` succeeds on every attempt because it accepts any cert
  in the lineage, so a passing VerifyCaller is NOT evidence the cert is
  registered — the failure lands one step later at token mint.

  **No rebuild or re-upload is needed for sign-in.** The `(package, cert) →
  OAuth client` mapping resolves server-side, so registering a cert fixes
  already-installed builds after a force-stop. Verified on a Play-installed
  build (version code 2, installer `com.android.vending`): sign-in succeeded
  with zero `UNREGISTERED_ON_API_CONSOLE` in a 5,511-line logcat.
- 🔵 **iOS deferred (v0.2 paused):** the `firebase_options.dart` iOS block and
  `ios/Runner/GoogleService-Info.plist` still point at dev `travey-298a7`.
  Re-run `flutterfire configure` for iOS when iOS resumes.

Dev `travey-298a7` remains the emulator/test target and the iOS target for now;
prod holds real user data. Never mix the two.

---

## 🟡 Known-unverified — on-device behaviour

None of these are policy problems, but each is a real user-facing risk that no
test in this repo can catch. Full table with reasons lives under **Phase 23** in
`ROADMAP.md`.

### ⚠️ UAT-BG-01 — background recording survives leaving the app (HIGHEST PRIORITY)

**Status: OPEN. Scheduled 2026-08-03 (next device session).**

This is the single most important unverified item in the project. Quick task
260802-itr removed `ACCESS_BACKGROUND_LOCATION`, so background GPS now depends
**entirely** on the location-typed foreground service (`foregroundServiceType=
"location"` + `FOREGROUND_SERVICE_LOCATION`). If that does not hold on a real
device, the app's core feature is broken.

**It fails SILENTLY** — truncated route, frozen timer, no crash, no error
dialog, nothing in CI. `flutter test` being green proves nothing here. Only
this check can catch it.

Steps (run OUTDOORS, on the `1.0.0+5` release build, not debug):

1. Tap **Start**, grant the location + notification prompts.
2. Move at least **200 m** — under `kMinTripDistanceMeters` (100 m) the trip is
   DISCARDED on Stop and never reaches history, so a stationary run is a false
   negative, not a failure.
3. Press Home. Use a different app for **3+ minutes** while still moving.
4. Confirm the persistent tracking notification stays visible in the status bar
   the whole time.
5. Return to Traevy. **PASS = the timer and the distance both advanced during
   the gap, with no stall.** FAIL = either froze, or the route has a gap.
6. Tap **Stop**. Confirm the trip saved with a route on the map and a
   moving/stuck split.

If step 5 fails, STOP — do not promote the release. The fix is to restore
`ACCESS_BACKGROUND_LOCATION` and file the Play background-location declaration
(with its mandatory demo video), which is exactly what removing it avoided.

Steps 1-5 are the same beats as the Play demo video, so one session covers both.

- **Edge-to-edge rendering** (targetSdk 35). Android 15 forces edge-to-edge; the
  bottom nav, the `flutter_map` screens, and bottom sheets have never been seen
  on a device under it.
- **N05 — GPS stationary drift.** Must run OUTDOORS or at a window for 15 min —
  indoors the 30m accuracy gate rejects samples, so a 0m reading would be a
  FALSE PASS. A stationary trip under the 100m floor is discarded on Stop and
  never reaches history, so a false pass here is silent.
- **N08 + N15 — home-screen widget.** Overlapping; one session closes both
  (add widget → idle stats match Stats screen → START from widget → resize
  4x2 → shrink 2x2 → pause chip → STOP).
- **Phase 29 end-to-end** — runnable now that the backend is live: fresh install
  → sign in → pins restore → first trip labels by geofence.
- **Today's three client-side changes (2026-08-02)** — none of these can be
  validated on an emulator per `CLAUDE.md`'s "test on real Android devices"
  rule:
  - Fresh-install location-permission prompt (260802-dgp) — the location
    picker now requests `locationWhenInUse` on open; never exercised on a
    fresh install.
  - The 20s stuck-segment floor (260801-tjx, `kStuckSegmentMinSeconds` 60s →
    20s) — affects **newly recorded trips only**; existing trips cannot be
    back-filled, so this needs a fresh drive to confirm shorter slow stretches
    actually paint.
  - Stuck-segment retention across a trip edit (260801-tjx, `editTrip` no
    longer wipes all stuck segments, only ones wholly outside the new time
    window) — needs an on-device edit of a trip with painted segments to
    confirm the overlap logic behaves as intended outside the unit-test harness.

---

## 🟢 Satisfied

- **targetSdk 35** for Play compliance (`a5fffce`) — verified in the built APK
  via aapt2, not just source.
- **Phase 29 backend deployed** (2026-07-20) — SC#2 satisfied; the client can
  ship without stranding payloads, once the gate above clears.
- **WR-05 force-stop recovery — RESOLVED 2026-08-02.** This item used to sit
  under Known-unverified: "the fix has never been exercised against the
  original repro, so 'WR-05 is fixed' is an informed expectation, not a
  verified fact." That is no longer true — `.planning/STATE.md` records that
  **N04, the WR-05 force-stop repro, PASSED** in the 2026-07-21 device UAT
  session (`adb shell am force-stop traevy.traevy` while tracking, then Stop
  from the notification), one of 48/60 scenarios that passed that session.
  Verified fact now, not just an informed expectation.
- **Cloud Functions runtime bump to Node.js 24 — RESOLVED 2026-08-02.** Was
  tracked as a deadline, not a gate: `main` had pinned `nodejs24` since the
  2026-07-20 quick task, but the LIVE backend kept running `nodejs20`, which
  decommissions 2026-10-30 — after that date no deploy would succeed until the
  pinned runtime was actually deployed. The 2026-08-02
  `firebase deploy --only functions --project traevy-prod` run closed the
  gap: deploy output confirms the live function now runs **Node.js 24 (2nd
  Gen)**. Recorded here so the reasoning (why this was a hard ~3-month
  deadline, not housekeeping) isn't lost now that it's resolved. Kept in mind
  for the future: a runtime swap is riskier than a code change, and all five
  REST routes still share one `onRequest(app)` function.

---

## 🔵 Known issue — non-blocking

- **"Delete all data" is mislabeled.** The in-app Settings action is titled
  "Delete all data" but only deletes trips — it retains the user's Home/Office
  coordinates on both device and cloud. This was a compliance-relevant gap
  until 2026-08-02: now that account deletion (`DELETE /account`) genuinely
  wipes local `user_preferences` too (260802-fvp, `4882d14`), the full-erasure
  path exists and works — it's just under "Delete account," not "Delete all
  data." No longer a Data Safety risk, just a user-facing mislabel awaiting a
  decision: broaden the scope of "Delete all data" to include preferences, or
  rename the action so it stops overpromising.

---

## 📝 Observation — backend test flakiness (watching, not a known-broken test)

- The backend suite (`cd backend/functions && npm test`, which boots the
  Firebase emulator) was observed failing 1 test in 1 of 5 consecutive runs on
  2026-08-02. The next 4 runs passed 116/116, and the failure could not be
  reproduced or attributed to a specific test. Most likely emulator/port
  overlap with a preceding run rather than a real defect. Recording this as
  something to watch if it recurs — explicitly **not** a known-broken test,
  and not currently blocking anything.
