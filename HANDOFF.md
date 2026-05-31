# HANDOFF — Phases 10 & 11 (Backend + Sync Engine)

**Date:** 2026-06-01
**Branch:** `gsd/phase-10-11-backend-sync` (58 commits ahead of `main`; pushed to origin)
**`main`:** untouched (still at `a3d04df`). No PR opened, nothing merged — as instructed.
**Outcome:** ✅ Both phases COMPLETE, cross-AI reviewed, tested, verified. Phase 10 deployed live.

Read this top-to-bottom; the **Wake-up verification checklist** at the end is the action list.

---

## TL;DR

- **Phase 10 (Backend):** self-contained `backend/` Firebase project — 3 HTTPS Cloud Function endpoints (sync/delete/restore) + deny-all Firestore rules + composite index. Strict TS, zod, verify→validate→trust, ownership-forced, soft-delete. **Deployed live to `travey-298a7`.** 48 emulator integration + 29 unit tests green. Live 401 auth-gate confirmed in prod.
- **Phase 11 (Sync Engine):** client `lib/sync/` — `api_client` + `sync_engine` (background, one-way, retry+backoff, queue-collapse) + restore-from-cloud + Settings rows wired. REST-only (no `cloud_firestore`). 481 Flutter tests green, `flutter analyze` clean.
- **Cross-AI (Gemini) review:** Phase 10 converged 0 HIGH (1 iter); Phase 11 converged 0 HIGH (2 iters). All findings resolved.
- **One thing to know:** live device E2E (signed-in Google user actually syncing to prod) is the only thing not provable headlessly — it's the main wake-up item. Everything else is tested.

---

## Phase 10 — Backend Infrastructure ✅ COMPLETE + DEPLOYED

### What was built (`backend/`)
Self-contained Firebase CLI project (separate from the repo-root FlutterFire `firebase.json`, which was left untouched):
- `backend/firebase.json` (functions + firestore rules+indexes + emulators), `backend/.firebaserc` (default `travey-298a7`), `backend/firestore.rules` (deny-all to clients), `backend/firestore.indexes.json` (composite `trips(userId, deleted)` for restore).
- `backend/functions/` — TypeScript (strict, Node 20, Functions v2), single `api` HTTPS function with an Express router:
  - `POST /trips/sync` — batch upsert, forced `userId`=token uid, chunked `set(merge:true)` ≤500/batch, `deleted:false`, zod cap 1000 trips.
  - `DELETE /trips/:tripId` — ownership-checked soft-delete (`deleted:true`+`deletedAt`), 404-before-403 (no existence oracle), never hard-deletes.
  - `GET /trips/restore` — `userId==uid AND deleted==false`, returns JSON-safe client `Trip[]` (strips Firestore Timestamps).
  - Utils: `auth.ts` (verifyIdToken + Bearer), `firestore.ts` (FirestoreDataConverter), `validation.ts` (zod), `response.ts`. Shared `types/trip.ts` is the Phase 10↔11 contract.

### Tests
- **29 unit** (zod accept/reject incl. 1001→400 DoS cap, UUID validation, bearer parsing) + **48 emulator integration** (auth-reject 401 ×3 endpoints, happy paths, ownership/cross-user isolation, server-forced userId on spoof, 600-trip chunking, deny-all rules) — **all green** on the live Firebase emulator (Java 26), no mocks, zero skipped. Re-verified independently by the verifier.

### Deploy status — LIVE
- Enabled GCP APIs (firestore, cloudfunctions, cloudbuild, artifactregistry, run, eventarc, pubsub) via the Service Usage API using the Firebase CLI's stored cloud-platform token (`gcloud` is not installed on this machine). Created the default Firestore DB (`(default)`, **nam5**).
- `firebase deploy --only functions,firestore:rules,firestore:indexes` → **function `api` v2 ACTIVE**, rules + composite index deployed.
- **Live function URL (use this in the app):** `https://us-central1-travey-298a7.cloudfunctions.net/api` (stable v2 alias). Cloud Run URL: `https://api-f3kobbitsa-uc.a.run.app`.
- **Live smoke (re-confirmed at handoff):** `GET /health` → **200**; `GET /trips/restore` (no token) → **401**; sync/delete (no token) → **401**. Auth gate enforced in prod.

### Phase 10 cross-AI review (Gemini) — converged 0 HIGH
- Iter 0: 1 HIGH — unbounded sync request body (DoS). Resolved: `express.json({limit:'10mb'})` + zod `trips.max(1000)` + rejection test (kept chunking). Iter 1: 0 HIGH. (`10-CONVERGENCE.md`)
- Internal plan-check caught real parallel-planning drift (wrong dep majors, double `jest.config`, missing composite index, `.min(1)` vs `.uuid()`) — all fixed before execution.

### Phase 10 code review — 0 Critical, 1 High (fixed)
- HI-01: `tripConverter.fromFirestore` blind cast → restore would emit Firestore `Timestamp` objects in JSON, breaking the Phase 11 contract. Fixed (typed converter + JSON-safe restore projection). Dead `response.ts` removed; bearer regex tightened. (`10-REVIEW.md` / `10-REVIEW-FIX.md`)

---

## Phase 11 — Sync Engine ✅ COMPLETE (verified 4/4)

### What was built (`lib/sync/` + Settings)
- `api_client.dart` — `http` client → the deployed backend (`kApiBaseUrl` = the stable alias above, injectable for tests). Bearer from `currentUser.getIdToken()`; 401→`getIdToken(true)`→retry once (refresh/network failures mapped to retryable; token never logged). `SyncException{statusCode, retryable}` (5xx/network→retryable, 4xx→non-retryable, DELETE 404→success/idempotent). Restore unwraps full `body.data.trips`.
- `trip_serializer.dart` — `TripSerializer.toJson/fromJson` matching the backend zod schema exactly (camelCase, ISO-8601 `Z`, 0-not-null numerics, `userId` omitted).
- `sync_engine.dart` — eager-mounted in `app.dart`. Collapse-per-tripId batching (create+update→one upsert; create-then-delete→no orphan; delete-only), retryable/non-retryable branching, exp backoff (max 3 then `failed`), in-flight mutex + `_backoffUntil` guard, triggers (new-pending-id watch / connectivity rising-edge / app-resume), gated on online && signed-in, fire-and-forget, full dispose.
- `restore_controller.dart` — restore → `TripSerializer.fromJson` → single Drift `batch(insertAll, insertOrIgnore)` dedupe-by-UUID, restored-count delta, sealed `RestoreState`, enqueues no sync rows.
- `sync_status.dart` — sealed `SyncStatus`. `SyncQueueDao` +`getPending/markFailed/resetFailed`; `TripsDao` +`insertAllOrIgnore/count`.
- Settings `_AccountSection` (signed-in only): `cloud_sync_row.dart` (All synced / Syncing… / N pending / Sync failed→`retryFailed()`) + `restore_row.dart` (Restore from cloud → SnackBar result, `mounted`-guarded). Guest branch unchanged. All copy in constants.
- deps added: `http: ^1.6.0`, `connectivity_plus: ^7.1.1`.

### Tests
- **481 Flutter tests pass** (unit + widget; +123 new across the phase), **0 skipped**, `flutter analyze` **clean**. `grep cloud_firestore lib/` → none (REST-only honored). Serializer field-matched to the backend zod schema. Independently re-run by the verifier.

### Phase 11 cross-AI review (Gemini) — converged 0 HIGH (2 iters)
- Iter 0: 3 HIGH — (1) batch must collapse per `tripId` before sending; (2) poison-pill: a 400 burned all 3 retries → must classify retryable vs non-retryable; (3) cross-plan symbol mismatch (`tripJsonToCompanion` vs `TripSerializer.fromJson`). + 3 MEDIUM (envelope unwrap, backoff-respects-triggers, restore single batch). All fixed (commit `5a36514`). Iter 1: 0 HIGH. Folded a LOW (delete-404→success). (`11-CONVERGENCE.md` / `11-REVIEWS.md`)

### Phase 11 code review — 0 Critical, 2 High (fixed)
- HI-01: a throwing `getIdToken(true)` during 401-refresh propagated unclassified → premature `markFailed`. Fixed → mapped to retryable.
- HI-02: `watchPending()` self-retriggered on the engine's own `markSynced`/`incrementRetry` writes → redundant drain loop. Fixed → triggers only on genuinely new pending IDs.
- + restore `mounted`-guard and minor mediums. (`11-REVIEW.md` / `11-REVIEW-FIX.md`)

---

## Gray-area defaults chosen (recorded; no interactive prompts were used)

**Phase 10** (full list in `10-CONTEXT.md`):
- Self-contained `backend/` dir (root `firebase.json` left for FlutterFire); Node 20 + Functions v2 + `us-central1`.
- Single `api` function + Express router (per-file handlers) over 3 separate functions.
- Top-level `trips` collection keyed by client UUID (not subcollection).
- Server forces `userId` from token; delete 404-not-403; soft-delete only.
- Trip timestamps stored as ISO strings (lossless restore) + server `Timestamp` metadata.
- Sync array capped at 1000 (keeps chunking meaningful) + `express.json({limit:'10mb'})`.
- Jest + ts-jest; emulator tests via `emulators:exec`.

**Phase 11** (full list in `11-CONTEXT.md`):
- Token via live `getIdToken()` (not the Phase-9 cached secure-storage token) + `getIdToken(true)` on 401.
- Batch create/update into one `POST /trips/sync` (chunk ≤1000); deletes individual; collapse per `tripId`.
- Exponential backoff (2s×2^n cap 60s), max 3 retries → `failed`; retryable vs non-retryable error classification.
- Triggers: new-pending watch + connectivity rising-edge + app-resume; online && signed-in gating.
- Restore dedupe via `insertOrIgnore` on the UUID PK, single Drift batch.
- Base URL = stable `cloudfunctions.net/api` alias (injectable for tests); manual Riverpod providers (no codegen).
- Sealed `SyncStatus`; Settings rows only in the signed-in branch.

---

## Gaps / blockers
- **No hard blockers.** Everything planned was built, tested, and (for Phase 10) deployed.
- **Node 20 deprecation** (Firebase): the function is deployed on `nodejs20` (locked decision D-02). Firebase deprecated Node 20 on 2026-04-30 (decommission 2026-10-30). Non-urgent: bump `backend/functions/package.json` engines to `22` and redeploy before Oct 2026. Deploy currently works fine.
- **Artifact Registry cleanup policy** not set (deploy warned). Optional: `cd backend && firebase functions:artifacts:setpolicy` to avoid a small storage bill from accumulating container images.
- The repo-root `firebase.json` is FlutterFire-only; backend deploys are run from `backend/`.

---

## ⏰ Wake-up verification checklist

**Backend (live) — quick (≈1 min):**
1. `curl -s -o /dev/null -w '%{http_code}\n' https://us-central1-travey-298a7.cloudfunctions.net/api/health` → expect **200**.
2. `curl -s -o /dev/null -w '%{http_code}\n' https://us-central1-travey-298a7.cloudfunctions.net/api/trips/restore` → expect **401** (auth gate).

**Backend (re-run tests, optional):** `cd backend/functions && npm test` → expect 7 suites / all green (needs the emulator + Java, both present).

**Flutter (re-run, optional):** from repo root `flutter analyze` (clean) and `flutter test` (481 green).

**Device E2E — the real wake-up task (needs a phone + Google sign-in; can't be done headlessly):**
1. `flutter run` on the Android device, sign in with Google (Phase 9 flow).
2. Record/finalize a trip (or add a manual entry). In Settings → Account, the **Cloud sync** row should show "Syncing…" then "All synced". Confirm a doc appears in Firestore console → `trips` (project travey-298a7) with your uid.
3. Edit then delete a trip → confirm the Firestore doc updates and ends with `deleted:true` (soft-delete).
4. Airplane-mode → record a trip (stays local, "N pending") → turn network back on / resume the app → confirm it drains to "All synced".
5. Uninstall + reinstall (or clear data), sign in, tap **Settings → Restore from cloud** → confirm trips reappear and a second restore says "Already up to date" (dedupe).

**Housekeeping (optional, non-urgent):**
- Set the Artifact Registry cleanup policy (above).
- Plan the Node 20→22 backend bump before Oct 2026.
- This branch is ready for a PR to `main` when you want it (not opened, per instructions). Note: `.planning/` docs are committed on the branch — use `/gsd:pr-branch` if you want a planning-free PR.

---

## Key artifacts
- Phase 10: `.planning/phases/10-backend-infrastructure/` — `10-CONTEXT/RESEARCH/01-03-PLAN/01-03-SUMMARY/SUMMARY/CONVERGENCE/REVIEWS/REVIEW/REVIEW-FIX/DEPLOY/VERIFICATION.md`
- Phase 11: `.planning/phases/11-sync-engine/` — `11-CONTEXT/RESEARCH/01-03-PLAN/01-03-SUMMARY/SUMMARY/CONVERGENCE/REVIEWS/REVIEW/REVIEW-FIX/VERIFICATION.md`
- `.planning/ROADMAP.md` (Phases 10 & 11 marked complete), `.planning/REQUIREMENTS.md` (BACK-02/03/04, SYNC-02/03 → Complete).
</content>
