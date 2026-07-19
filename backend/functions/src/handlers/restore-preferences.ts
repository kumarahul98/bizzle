import type { Request, Response } from 'express';
import { AuthError, verifyAuth } from '../utils/auth';
import { usersCollection } from '../utils/firestore';
import type { SavedLocations } from '../types/preferences';

/**
 * All-null saved locations — the response for a user who has never synced.
 *
 * Returned as a 200 rather than a 404 deliberately: "this user has no saved
 * locations" is a normal, expected state (SC#5), not an error. A 404 would push
 * the client into an error branch for the most common first-run case.
 */
const EMPTY_LOCATIONS: SavedLocations = {
  homeLat: null,
  homeLng: null,
  officeLat: null,
  officeLng: null,
};

/**
 * `GET /preferences/restore` — return the caller's saved Home / Office
 * locations (Phase 29, LOC-03).
 *
 * Contract (verify -> read, matching `restore-trips.ts`):
 *   1. Verify the ID token FIRST. Missing/invalid/expired -> 401, no read.
 *   2. Read `users/{uid}` — the id comes from the VERIFIED TOKEN, so a caller
 *      can only ever read their own document (T-29-03).
 *   3. Project to the client {@link SavedLocations} shape, dropping `userId`
 *      and `serverUpdatedAt` so the response carries no Firestore `Timestamp`
 *      and stays JSON-safe.
 *
 * A missing document returns all-null, not a 404 — see {@link EMPTY_LOCATIONS}.
 *
 * ## PII
 *
 * The response body carries the user's Home/Office coordinates. It is never
 * logged here, and the error paths return fixed strings (T-29-02 / T-21-03).
 */
export async function restorePreferencesHandler(
  req: Request,
  res: Response,
): Promise<void> {
  let uid: string;
  try {
    uid = await verifyAuth(req);
  } catch (err) {
    const status = err instanceof AuthError ? err.statusCode : 401;
    res.status(status).json({ statusCode: status, body: { error: 'Unauthorized' } });
    return;
  }

  try {
    const snap = await usersCollection().doc(uid).get();
    const data = snap.data();
    // `data()` is undefined when the doc does not exist. The converter already
    // normalized every coordinate to `number | null`, so no defaulting is
    // needed on the present-document path.
    const savedLocations: SavedLocations = data?.savedLocations ?? EMPTY_LOCATIONS;

    res.status(200).json({ statusCode: 200, body: { data: { savedLocations } } });
  } catch {
    res.status(500).json({ statusCode: 500, body: { error: 'Internal error' } });
  }
}
