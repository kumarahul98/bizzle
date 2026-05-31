import type { Request, Response } from 'express';
import {
  getFirestore,
  FieldValue,
  WithFieldValue,
} from 'firebase-admin/firestore';
import { AuthError, verifyAuth } from '../utils/auth';
import { syncTripsBody } from '../utils/validation';
import { tripsCollection } from '../utils/firestore';
import type { TripDoc } from '../types/trip';

/**
 * Firestore caps a single batched write at 500 operations. Larger sync batches
 * (the schema permits up to 1000 trips) are split into chunks of this size and
 * committed sequentially (D-12).
 */
const FIRESTORE_BATCH_LIMIT = 500;

/**
 * `POST /trips/sync` — batch-upsert the caller's trips (BACK-02).
 *
 * Contract (verify -> validate -> trust, D-07):
 *   1. Verify the Firebase ID token FIRST. Missing/invalid/expired -> 401 with
 *      zero Firestore work.
 *   2. zod-validate the body via {@link syncTripsBody}. An empty batch, a
 *      malformed trip, or a batch over the 1000 cap (M1 DoS cap) -> 400 with
 *      zero Firestore work — the cap lives in the schema, not a manual check.
 *   3. Trust + write. Each trip is upserted to `trips/{trip.id}` with `userId`
 *      FORCED to the token uid (D-08, ignoring any client value), `deleted:false`,
 *      `deletedAt:null`, and a server timestamp. Writes are chunked at <=500
 *      ops per batch and committed sequentially. `set(merge:true)` keyed by the
 *      trip UUID makes re-sends idempotent.
 *
 * Response shape is the consistent `{ statusCode, body: { data? | error? } }`
 * (D-06); errors carry only short typed messages — never a token or stack trace.
 */
export async function syncTripsHandler(
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

  const parsed = syncTripsBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ statusCode: 400, body: { error: 'Invalid request body' } });
    return;
  }

  const { trips } = parsed.data;

  try {
    const db = getFirestore();
    const collection = tripsCollection();

    for (let start = 0; start < trips.length; start += FIRESTORE_BATCH_LIMIT) {
      const chunk = trips.slice(start, start + FIRESTORE_BATCH_LIMIT);
      const batch = db.batch();
      for (const trip of chunk) {
        const doc: WithFieldValue<TripDoc> = {
          id: trip.id,
          userId: uid,
          startTime: trip.startTime,
          endTime: trip.endTime,
          durationSeconds: trip.durationSeconds,
          distanceMeters: trip.distanceMeters,
          routePolyline: trip.routePolyline,
          direction: trip.direction,
          timeMovingSeconds: trip.timeMovingSeconds,
          timeStuckSeconds: trip.timeStuckSeconds,
          isManualEntry: trip.isManualEntry,
          createdAt: trip.createdAt,
          updatedAt: trip.updatedAt,
          // `deleted:false` is deliberate (D-11, client-authoritative): re-syncing
          // an id resurrects a server-soft-deleted trip. An offline client that
          // never saw the delete will un-delete it on next sync — by design.
          // Do NOT "fix" this into preserving `deleted:true` without revisiting D-11.
          deleted: false,
          deletedAt: null,
          serverUpdatedAt: FieldValue.serverTimestamp(),
        };
        batch.set(collection.doc(trip.id), doc, { merge: true });
      }
      await batch.commit();
    }

    const syncedIds = trips.map((trip) => trip.id);
    res.status(200).json({ statusCode: 200, body: { data: { syncedIds } } });
  } catch {
    res.status(500).json({ statusCode: 500, body: { error: 'Internal error' } });
  }
}
