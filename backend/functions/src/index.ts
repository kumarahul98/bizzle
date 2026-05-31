import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onRequest } from 'firebase-functions/v2/https';
import express from 'express';
import { syncTripsHandler } from './handlers/sync-trips';
import { deleteTripHandler } from './handlers/delete-trip';
import { restoreTripsHandler } from './handlers/restore-trips';

initializeApp();
setGlobalOptions({ region: 'us-central1' });

/**
 * The Express app behind the single `api` Cloud Function (D-04). Exported so
 * supertest can drive it in-process without the Functions wrapper.
 *
 * Mounts `GET /health` plus the three `/trips/*` REST routes (BACK-02/03/04).
 */
export const app = express();
app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.post('/trips/sync', syncTripsHandler);
app.get('/trips/restore', restoreTripsHandler);
app.delete('/trips/:tripId', deleteTripHandler);

/** The single HTTPS Cloud Function wrapping the Express app (D-02/D-04). */
export const api = onRequest(app);
