import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onRequest } from 'firebase-functions/v2/https';
import express from 'express';

initializeApp();
setGlobalOptions({ region: 'us-central1' });

/**
 * The Express app behind the single `api` Cloud Function (D-04). Exported so
 * Plan 02's supertest can drive it in-process without the Functions wrapper.
 *
 * This plan mounts ONLY `GET /health`; the three `/trips/*` routes are added in
 * Plan 02.
 */
export const app = express();
app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

/** The single HTTPS Cloud Function wrapping the Express app (D-02/D-04). */
export const api = onRequest(app);
