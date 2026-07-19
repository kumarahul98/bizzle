import type { Request, Response } from 'express';
import { AuthError, verifyAuth } from '../utils/auth';
import { tripsCollection } from '../utils/firestore';
import type { Trip, TripDoc } from '../types/trip';

/**
 * `GET /trips/restore` — return the caller's non-deleted trips (BACK-04).
 *
 * Contract (verify -> validate -> trust, D-07):
 *   1. Verify the ID token FIRST. Missing/invalid/expired -> 401, no query.
 *   2. Query `trips` where `userId == uid` AND `deleted == false` via the typed
 *      converter (D-08/D-09/D-11). This two-equality query needs a composite
 *      index in prod (shipped in backend/firestore.indexes.json, Plan 01 / M2);
 *      the emulator is lenient.
 *   3. Strip server metadata (`deleted`, `deletedAt`, `serverUpdatedAt`) and
 *      return only the client {@link Trip} fields, so the response is JSON-safe
 *      (no Firestore `Timestamp` serialization) and matches the Phase 11
 *      client contract.
 *
 * Response uses the consistent `{ statusCode, body: { data? | error? } }` shape
 * (D-06); errors are short typed strings only.
 */
export async function restoreTripsHandler(
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
    const snap = await tripsCollection()
      .where('userId', '==', uid)
      .where('deleted', '==', false)
      .get();

    const trips: Trip[] = snap.docs.map((docSnap) => {
      // `docSnap.data()` is run through `tripConverter.fromFirestore`, which
      // coerces timestamp-shaped time fields to ISO strings (HI-01). We then
      // project to the client {@link Trip} shape, dropping the server-only
      // metadata (`deleted`, `deletedAt`, `serverUpdatedAt`) so the response is
      // JSON-safe with no Firestore `Timestamp` objects.
      const doc: TripDoc = docSnap.data();
      return {
        id: doc.id,
        userId: doc.userId,
        startTime: doc.startTime,
        endTime: doc.endTime,
        durationSeconds: doc.durationSeconds,
        distanceMeters: doc.distanceMeters,
        routePolyline: doc.routePolyline,
        direction: doc.direction,
        timeMovingSeconds: doc.timeMovingSeconds,
        timeStuckSeconds: doc.timeStuckSeconds,
        isManualEntry: doc.isManualEntry,
        createdAt: doc.createdAt,
        updatedAt: doc.updatedAt,
        // Phase 26 metadata: sourced from `doc`, already defaulted by
        // tripConverter.fromFirestore — no re-defaulting here.
        totalPausedSeconds: doc.totalPausedSeconds,
        isEdited: doc.isEdited,
        directionSource: doc.directionSource,
        breaks: doc.breaks,
      };
    });

    res.status(200).json({ statusCode: 200, body: { data: { trips } } });
  } catch {
    res.status(500).json({ statusCode: 500, body: { error: 'Internal error' } });
  }
}
