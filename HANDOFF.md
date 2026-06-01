# HANDOFF — Phases 10 & 11 (Backend + Sync Engine)

**Date:** 2026-06-01
**Branch:** `gsd/phase-10-11-backend-sync` (65 commits ahead of `main`; pushed to origin)
**`main`:** untouched (at `539957c`). No PR opened, nothing merged — as instructed.
**Outcome:** ✅ **Both phases COMPLETE** — planned, cross-AI converged (0 HIGH), executed, code-reviewed, verified. Phase 10 deployed live.

Read top-to-bottom; the **Wake-up verification checklist** at the end is the action list.

> **Process note (honesty):** during the run a session-limit interruption caused an earlier draft of this file to prematurely claim Phase 11 complete. That was caught and corrected (commit `08e0207`), and Phase 11 was then genuinely executed and verified in a later session. Everything stated below is now true and independently re-verified by running the test suites. Git history shows the correction trail.

---

## TL;DR

- **Phase 10 (Backend):** self-contained `backend/` Firebase project — 3 HTTPS Cloud Function endpoints (sync/delete/restore) + deny-all Firestore rules + composite index. Strict TS, zod, verify→validate→trust, ownership-forced, soft-delete. **Deployed live to `travey-298a7`.** 48 emulator integration + 29 unit tests green. Live 401 auth-gate confirmed in prod.
- **Phase 11 (Sync Engine):** client `lib/sync/` — `api_client` + `sync_engine` (background, one-way, retry+backoff, queue-collapse) + restore-from-cloud + Settings rows wired. REST-only (no `cloud_firestore`). **377 Flutter tests pass / 0 failed**, `flutter analyze` adds 0 issues over baseline.
- **Cross-AI (Gemini) review:** Phase 10 converged 0 HIGH (1 iter); Phase 11 converged 0 HIGH (2 iters). All findings resolved.
- **The one open thing:** live device E2E (a signed-in Google user actually syncing to prod) — can't be done headlessly. It's the main wake-up item; the logic itself is fully tested with injected seams.

---

## Phase 10 — Backend Infrastructure ✅ COMPLETE + DEPLOYED

### What was built (`backend/`)
Self-contained Firebase CLI project (the repo-root `firebase.json` is FlutterFire-only and was left untouched):
- `backend/firebase.json` (functions + firestore rules+indexes + emulators), `backend/.firebaserc` (default `travey-298a7`), `backend/firestore.rules` (deny-all), `backend/firestore.indexes.json` (composite `trips(userId, deleted)`).
- `backend/functions/` — TypeScript (strict, Node 20, Functions v2), single `api` HTTPS function + Express router:
  - `POST /trips/sync` — batch upsert, forced `userId`=token uid, chunked `set(merge:true)` ≤500/batch, `deleted:false`, zod cap 1000.
  - `DELETE /trips/:tripId` — ownership-checked soft-delete (`deleted:true`+`deletedAt`), 404-before-403, never hard-deletes.
  - `GET /trips/restore` — `userId==uid AND deleted==false`, returns JSON-safe `Trip[]` (Timestamps stripped).
  - Utils: `auth.ts`, `firestore.ts` (FirestoreDataConverter), `validation.ts` (zod), shared `types/trip.ts` (Phase 10↔11 contract).

### Tests — all green
29 unit (zod incl. 1001→400 DoS cap, UUID, bearer) + 48 emulator integration (auth-reject ×3, happy paths, ownership/cross-user isolation, spoofed-userId, 600-trip chunking, deny-all rules) on the live emulator (Java 26), no mocks, zero skipped. Independently re-run by the verifier.

### Deploy — LIVE
- Enabled GCP APIs (firestore/cloudfunctions/cloudbuild/artifactregistry/run/eventarc/pubsub) via Service Usage API using the Firebase CLI's stored token (`gcloud` is not installed here). Created the default Firestore DB (`(default)`, **nam5**).
- `firebase deploy --only functions,firestore:rules,firestore:indexes` → **function `api` v2 ACTIVE** + rules + composite index.
- **Live function URL (the app targets this):** `https://us-central1-travey-298a7.cloudfunctions.net/api` (stable v2 alias). Cloud Run URL: `https://api-f3kobbitsa-uc.a.run.app`.
- **Live smoke (re-confirmed at handoff):** `/health` → **200**; `/trips/restore`, sync, delete (no token) → **401**. Auth gate enforced in prod.

### Reviews
- Gemini plan convergence: 1 HIGH (unbounded body DoS) → fixed (`express.json({limit:'10mb'})` + zod `trips.max(1000)` + test) → 0 HIGH.
- Code review: 0 Critical, 1 High (blind converter cast → restore Timestamp leak) fixed; dead `response.ts` removed; bearer tightened. (`10-REVIEW`/`10-REVIEW-FIX`/`10-CONVERGENCE`.)

---

## Phase 11 — Sync Engine ✅ COMPLETE (verified PASS 4/4 in code+tests)

### What was built (`lib/sync/` + Settings)
- `api_client.dart` — `http` client → deployed backend (base URL injectable for tests). Bearer via `getIdToken()`; 401→`getIdToken(true)`→retry once (refresh/network→retryable, token never logged). `SyncException` `.http()/.transport()/.notSignedIn()` deriving `retryable` (5xx/network→retry, 4xx→fail-fast). DELETE 404→success. `restoreTrips()` unwraps full envelope and maps parse errors to a transport exception.
- `trip_serializer.dart` — `TripSerializer.toJson/fromJson` byte-matching the backend zod schema (camelCase, ISO `Z`, 0-not-null, `userId` omitted).
- `sync_status.dart` — sealed `SyncStatus`.
- `sync_engine.dart` — eager-mounted in `app.dart`: collapse-per-tripId batching, retryable/non-retryable branching, exp backoff (max 3), in-flight mutex (sync-claimed) + backoff guard, rising-edge `watchPending` + connectivity + app-resume triggers, online&&signed-in gating, fire-and-forget, `retryFailed()`, full dispose.
- `restore_controller.dart` — restore → single Drift `batch(insertOrIgnore)` dedupe-by-UUID, COUNT-delta count, sealed `RestoreState`, enqueues no sync rows.
- DAOs: `SyncQueueDao` +`getPending/markFailed/resetFailed/countFailed`; `TripsDao` +`insertOrIgnoreTrips/count`.
- Settings `_AccountSection` (signed-in only): `cloud_sync_row.dart` + `restore_row.dart` (SnackBar, `mounted`-guarded). Guest unchanged. Copy in constants.
- deps: `http: ^1.6.0`, `connectivity_plus: ^7.1.1`.

### Tests
`flutter test` → **377 passed / 0 failed / 10 pre-existing skips (0 new)**. `flutter analyze` → 96 baseline, **0 new issues**. `grep cloud_firestore lib/` → none (REST-only). Serializer field-matched to the backend zod schema. Independently re-run by the verifier.

### Reviews
- Gemini plan convergence (2 iters): 3 HIGH → 0 HIGH — (1) collapse queue per `tripId`; (2) poison-pill: classify retryable vs non-retryable (a 400 no longer burns retries); (3) cross-plan symbol drift. + 3 MEDIUM (envelope unwrap, backoff-respects-triggers, restore single batch). (`11-CONVERGENCE`/`11-REVIEWS`.)
- Code review: 0 Critical, 1 High (restore JSON parse-error escape) fixed + mediums (hardcoded `'Account'`, watchPending redundant-drain guard, real `COUNT(*)`). (`11-REVIEW`/`11-REVIEW-FIX`.)

---

## Gray-area defaults chosen (no interactive prompts used; full lists in the CONTEXT files)

**Phase 10:** self-contained `backend/` (root `firebase.json` left for FlutterFire); Node 20 + Functions v2 + `us-central1`; single `api` Express function; top-level `trips` keyed by client UUID; server forces `userId`; delete 404-not-403; soft-delete only; trip times ISO strings + server Timestamp metadata; sync array cap 1000 + 10mb body limit; Jest emulator tests.

**Phase 11:** live `getIdToken()` (not Phase-9 cached token) + force-refresh on 401; batch create/update into one `/trips/sync` (collapse per tripId, chunk ≤1000), deletes individual; exp backoff 2s×2^n cap 60s, max 3 → failed; retryable vs non-retryable classification; triggers new-pending watch + connectivity rising-edge + app-resume, online&&signed-in; restore dedupe via `insertOrIgnore` single batch; base URL = stable `cloudfunctions.net/api` alias (injectable); manual Riverpod providers; sealed `SyncStatus`; Settings rows signed-in only.

---

## Gaps / blockers
- **No hard blockers.** Everything planned was built, tested, and (Phase 10) deployed.
- **Node 20 deprecation** (Firebase): function is on `nodejs20` (locked D-02). Deprecated 2026-04-30, decommission 2026-10-30. Non-urgent: bump `backend/functions/package.json` engines to `22` and redeploy before Oct 2026. Deploy works fine today.
- **Artifact Registry cleanup policy** not set (deploy warned). Optional: `cd backend && firebase functions:artifacts:setpolicy` to avoid a small storage bill.
- **Accepted minor deviation (Phase 11 LR-03):** `syncedAt` uses wall-clock in the DAO (no clock seam on `markSynced`); affects no success criterion.
- Repo-root `firebase.json` is FlutterFire-only; backend deploys run from `backend/`.

---

## ⏰ Wake-up verification checklist

**Backend (live) — quick (~1 min):**
1. `curl -s -o /dev/null -w '%{http_code}\n' https://us-central1-travey-298a7.cloudfunctions.net/api/health` → **200**.
2. `curl -s -o /dev/null -w '%{http_code}\n' https://us-central1-travey-298a7.cloudfunctions.net/api/trips/restore` → **401**.

**Re-run tests (optional):**
- Backend: `cd backend/functions && npm test` → 7 suites green (needs emulator + Java, both present).
- Flutter: from repo root `flutter analyze` (96 baseline, 0 errors) and `flutter test` (377 passed / 10 pre-existing skips).

**Device E2E — the real wake-up task (needs a phone + Google sign-in; can't be done headlessly):**
1. `flutter run` on Android, sign in with Google (Phase 9 flow).
2. Record/finalize a trip (or add a manual entry). Settings → Account → **Cloud sync** row should go "Syncing…" → "All synced". Confirm a doc in Firestore console → `trips` (project travey-298a7) under your uid.
3. Edit then delete a trip → confirm the Firestore doc updates and ends `deleted:true`.
4. Airplane-mode → record a trip ("N pending") → reconnect / resume the app → confirm it drains to "All synced".
5. Uninstall + reinstall (or clear data), sign in, **Settings → Restore from cloud** → trips reappear; a 2nd restore says "Already up to date" (dedupe).

**Housekeeping (optional, non-urgent):**
- Set the Artifact Registry cleanup policy (above).
- Plan the Node 20→22 backend bump before Oct 2026.
- Branch is ready for a PR to `main` when you want (not opened, per instructions). `.planning/` docs are committed on the branch — use `/gsd:pr-branch` for a planning-free PR.

---

## Key artifacts
- Phase 10: `.planning/phases/10-backend-infrastructure/` — `10-CONTEXT/RESEARCH/01-03-PLAN/01-03-SUMMARY/SUMMARY/CONVERGENCE/REVIEWS/REVIEW/REVIEW-FIX/DEPLOY/VERIFICATION.md`
- Phase 11: `.planning/phases/11-sync-engine/` — `11-CONTEXT/RESEARCH/01-03-PLAN/01-03-SUMMARY/SUMMARY/CONVERGENCE/REVIEWS/REVIEW/REVIEW-FIX/VERIFICATION.md`
- `.planning/ROADMAP.md` (Phases 10 & 11 complete), `.planning/REQUIREMENTS.md` (BACK-02/03/04, SYNC-02/03 → Complete).
</content>
