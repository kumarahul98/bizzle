import { initializeApp, getApps } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onRequest } from 'firebase-functions/v2/https';
import express from 'express';
import { syncTripsHandler } from './handlers/sync-trips';
import { deleteTripHandler } from './handlers/delete-trip';
import { deleteAllTripsHandler } from './handlers/delete-all-trips';
import { deleteAccountHandler } from './handlers/delete-account';
import { restoreTripsHandler } from './handlers/restore-trips';
import { syncPreferencesHandler } from './handlers/sync-preferences';
import { restorePreferencesHandler } from './handlers/restore-preferences';

// Guard initialization so importing the exported `app` in-process (supertest /
// the integration suite, which already initialized the Admin app against the
// emulator) does not throw "[DEFAULT] already exists with a different
// configuration". Idempotent init is also correct for the production runtime.
if (!getApps().length) {
  initializeApp();
}
setGlobalOptions({ region: 'us-central1' });

/**
 * The Express app behind the single `api` Cloud Function (D-04). Exported so
 * supertest can drive it in-process without the Functions wrapper.
 *
 * Mounts `GET /health` plus the three `/trips/*` REST routes (BACK-02/03/04).
 */
export const app = express();
// No CORS: the only caller is the Phase 11 native Android `http` client, which
// issues no preflight, so CORS is intentionally omitted (not a security gap).
// A future browser caller would need locked-origin CORS here — never `origin:'*'`.
// Body bounded at 10mb (H1 defense-in-depth): large enough for a full
// 1000-trip batch (the zod `kMaxSyncBatchTrips` cap rejects >1000 at the
// validation layer with 400), while preventing oversized-payload memory
// abuse. Plain `express.json()` defaults to 100kb, which would 413 realistic
// multi-hundred-trip syncs before the handler runs.
app.use(express.json({ limit: '10mb' }));

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.post('/trips/sync', syncTripsHandler);
app.get('/trips/restore', restoreTripsHandler);
// Phase 38 (BACK-05): bulk soft-delete ALL of the caller's trips ("delete all
// my data, keep my account"). Declared BEFORE the `/trips/:tripId` route: the
// two patterns don't actually collide (Express matches the literal `/trips`
// segment correctly regardless of order), but placing the exact route first
// removes any ambiguity for a future reader scanning top-to-bottom.
app.delete('/trips', deleteAllTripsHandler);
app.delete('/trips/:tripId', deleteTripHandler);

// Phase 38 (BACK-06): full account deletion (Google Play in-app
// account-deletion requirement). HARD-deletes all trips (the one deliberate
// exception to the project's soft-delete rule — see claude.md and the
// delete-account.ts header), hard-deletes the preferences doc, then deletes
// the Auth user — see delete-account.ts for the ordering rationale.
app.delete('/account', deleteAccountHandler);

// Phase 29 (LOC-03): saved Home/Office locations. Separate routes rather than
// fields on the trip endpoints — different entity, different lifecycle, and
// sync-trips.ts is already the most-churned file in this directory.
app.post('/preferences/sync', syncPreferencesHandler);
app.get('/preferences/restore', restorePreferencesHandler);

/** The single HTTPS Cloud Function wrapping the Express app (D-02/D-04). */
export const api = onRequest(app);
