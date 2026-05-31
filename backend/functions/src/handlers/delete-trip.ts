import type { Request, Response } from 'express';
import { FieldValue } from 'firebase-admin/firestore';
import { AuthError, verifyAuth } from '../utils/auth';
import { tripIdParam } from '../utils/validation';
import { tripsCollection } from '../utils/firestore';

/**
 * `DELETE /trips/:tripId` — soft-delete the caller's trip (BACK-03).
 *
 * Contract (verify -> validate -> trust, D-07):
 *   1. Verify the ID token FIRST. Missing/invalid/expired -> 401, no Firestore
 *      access.
 *   2. Validate the path param via {@link tripIdParam} (UUID, D-09). Non-UUID
 *      -> 400.
 *   3. Read the doc. Missing -> 404. Owned by another uid -> 404 (NOT 403) so
 *      the response never reveals that another user's trip exists (D-08, the
 *      existence-oracle defence).
 *   4. Soft-delete (D-11): set `deleted:true`, `deletedAt`, and `serverUpdatedAt`.
 *      The document is NEVER hard-deleted (no `.delete()` call).
 *
 * Response uses the consistent `{ statusCode, body: { data? | error? } }` shape
 * (D-06); errors are short typed strings only.
 */
export async function deleteTripHandler(
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

  const parsed = tripIdParam.safeParse(req.params);
  if (!parsed.success) {
    res.status(400).json({ statusCode: 400, body: { error: 'Invalid trip id' } });
    return;
  }

  const { tripId } = parsed.data;

  try {
    const ref = tripsCollection().doc(tripId);
    const snap = await ref.get();
    const data = snap.data();
    if (!snap.exists || !data || data.userId !== uid) {
      res.status(404).json({ statusCode: 404, body: { error: 'Trip not found' } });
      return;
    }

    await ref.update({
      deleted: true,
      deletedAt: FieldValue.serverTimestamp(),
      serverUpdatedAt: FieldValue.serverTimestamp(),
    });

    res.status(200).json({ statusCode: 200, body: { data: { id: tripId } } });
  } catch {
    res.status(500).json({ statusCode: 500, body: { error: 'Internal error' } });
  }
}
