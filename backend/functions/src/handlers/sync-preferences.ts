import type { Request, Response } from 'express';
import { FieldValue, WithFieldValue } from 'firebase-admin/firestore';
import { AuthError, verifyAuth } from '../utils/auth';
import { syncPreferencesBody } from '../utils/validation';
import { usersCollection } from '../utils/firestore';
import type { PreferencesDoc } from '../types/preferences';

/**
 * `POST /preferences/sync` — upsert the caller's saved Home / Office locations
 * (Phase 29, LOC-03).
 *
 * Contract (verify -> validate -> trust, matching the trip handlers):
 *   1. Verify the ID token FIRST. Missing/invalid/expired -> 401, no write.
 *   2. Validate the body with zod. Out-of-range or half-set coordinate pairs
 *      are rejected with a 400 before any Firestore work (T-29-04).
 *   3. Write to `users/{uid}` where the id comes from the VERIFIED TOKEN, never
 *      from the body (T-29-03). A client cannot name the document it writes.
 *
 * `set(merge: true)` makes re-sends idempotent and preserves any unrelated
 * fields a future feature adds to the same user document.
 *
 * ## Why there is no sync queue behind this (D-02)
 *
 * `sync_queue.tripId` on the client is non-nullable with an FK to `trips.id`,
 * so preferences cannot ride the existing queue without widening that FK — a
 * change that would put the trip sync path at risk for no gain here. A queue
 * exists to preserve ordering and survive partial failure across many entities;
 * this payload is ONE idempotent row that always carries its whole current
 * value. A failed push is re-sent by the next change or the next sign-in, and
 * cannot drift, because there are no deltas to lose.
 *
 * ## PII
 *
 * The body carries coordinates that reveal where the user lives. Nothing here
 * logs the payload, and the error responses are fixed strings — never an echo
 * of the input (T-29-02 / T-21-03).
 */
export async function syncPreferencesHandler(
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

  const parsed = syncPreferencesBody.safeParse(req.body);
  if (!parsed.success) {
    // Deliberately does NOT include zod's issue list. The issues would quote
    // the offending values back — i.e. the user's coordinates — into a response
    // body that may be logged by an intermediary (T-29-02).
    res.status(400).json({ statusCode: 400, body: { error: 'Invalid request body' } });
    return;
  }

  const { savedLocations } = parsed.data;

  try {
    const doc: WithFieldValue<PreferencesDoc> = {
      userId: uid,
      savedLocations,
      serverUpdatedAt: FieldValue.serverTimestamp(),
    };
    await usersCollection().doc(uid).set(doc, { merge: true });

    res.status(200).json({ statusCode: 200, body: { data: { synced: true } } });
  } catch {
    res.status(500).json({ statusCode: 500, body: { error: 'Internal error' } });
  }
}
