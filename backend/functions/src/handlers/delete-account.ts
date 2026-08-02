import type { Request, Response } from 'express';
import { getAuth } from 'firebase-admin/auth';
import { AuthError, verifyAuth } from '../utils/auth';
import { hardDeleteAllTripsForUser } from '../utils/bulk-delete';
import { usersCollection } from '../utils/firestore';

/**
 * `DELETE /account` — full account deletion (Phase 38, BACK-06). Required by
 * Google Play for apps offering in-app sign-in: the user must be able to
 * delete their account and its data entirely, not just individual trips.
 *
 * Contract (verify -> validate -> trust, D-07):
 *   1. Verify the ID token FIRST. Missing/invalid/expired -> 401, no work.
 *   2. No path param and no body to validate — uid comes only from the
 *      verified token, never the request.
 *   3. Trust + delete, in a deliberate order:
 *      a. Hard-delete ALL the caller's trips (including any already sitting
 *         in Trash) via {@link hardDeleteAllTripsForUser}. Current deletion
 *         model: per-trip trash (`delete-trip.ts`) stays soft; the bulk
 *         "delete all my data, keep my account" endpoint
 *         (`delete-all-trips.ts`) is also hard; account deletion additionally
 *         removes the preferences doc and the Auth user, because deleting
 *         your account must actually erase the data — leaving it around
 *         would orphan it in Firestore forever with no purge job to reclaim
 *         it.
 *      b. Hard-delete `users/{uid}` (the per-user preferences doc). This was
 *         never trip data and never carried a soft-delete requirement —
 *         `.delete()` on a missing doc does not throw, so a caller with no
 *         preferences doc still succeeds.
 *      c. Delete the Firebase Auth user via `getAuth().deleteUser(uid)` LAST.
 *         Ordering is deliberate: if this final step fails, the user's data
 *         is already gone but their auth identity survives — the safer
 *         failure mode, since they can retry (re-running the hard-delete
 *         query and re-deleting an already-gone preferences doc are both
 *         idempotent — zero matches / no-op respectively) rather than losing
 *         their auth identity while data deletion silently failed.
 *
 * Response uses the consistent `{ statusCode, body: { data? | error? } }`
 * shape (D-06); errors are short typed strings only, never leaking internals.
 */
export async function deleteAccountHandler(
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
    await hardDeleteAllTripsForUser(uid);
    await usersCollection().doc(uid).delete();
    await getAuth().deleteUser(uid);

    res.status(200).json({ statusCode: 200, body: { data: { deleted: true } } });
  } catch {
    res.status(500).json({ statusCode: 500, body: { error: 'Internal error' } });
  }
}
