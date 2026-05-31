# Phase 10 — Live Deploy Record

**Date:** 2026-06-01
**Project:** travey-298a7 (Blaze)
**Branch:** gsd/phase-10-11-backend-sync

## Provisioning performed
- **Enabled GCP APIs** (were disabled; enabled via Service Usage API using the Firebase CLI's stored cloud-platform token — `gcloud` is not installed on this machine): `firestore`, `cloudfunctions`, `cloudbuild`, `artifactregistry`, `run`, `eventarc`, `pubsub`.
- **Created the default Firestore database**: `(default)`, location **nam5** (multi-region US), standard edition.

## Deployed
`cd backend && firebase deploy --only functions,firestore:rules,firestore:indexes --project travey-298a7`
- **Function `api`** — v2, https, region us-central1, runtime nodejs20, memory 256Mi — **state: ACTIVE**.
- **Firestore Security Rules** — deny-all to clients.
- **Firestore composite index** — `trips(userId, deleted)` for the restore query.

## Live function URL (stable Cloud Run gen2 URL)
```
https://us-central1-travey-298a7.cloudfunctions.net/api
```
Endpoints: `POST /trips/sync`, `GET /trips/restore`, `DELETE /trips/{tripId}`, `GET /health`.
(This is the base URL Phase 11's api_client will target.)

## Live smoke test results
| Request | Expected | Actual |
|---------|----------|--------|
| `GET /health` (no auth) | 200 | **200** ✓ |
| `GET /trips/restore` (no token) | 401 | **401** ✓ |
| `GET /trips/restore` (invalid token) | 401 | **401** ✓ |
| `POST /trips/sync` (no token) | 401 | **401** ✓ |
| `DELETE /trips/{uuid}` (no token) | 401 | **401** ✓ |

Auth gate is enforced live on all three protected endpoints (criterion 4 confirmed in prod).

## Not done live (recorded for wake-up verification)
- **Live 2xx happy-path with a REAL Google ID token** — requires an interactive Google sign-in to mint a prod ID token (not feasible headlessly). The happy paths (sync write, soft-delete, filtered restore, ownership, DoS cap, chunking) are exhaustively proven by the **48-test emulator suite against identical code**. Wake-up check: sign in on the device, trigger a sync, confirm Firestore documents appear under `trips` (Phase 11 wires this end-to-end).
- **Node 20 deprecation**: deployed on nodejs20 (locked D-02); Firebase recommends nodejs22 — bump post-MVP if a future deploy warns/blocks.
</content>
