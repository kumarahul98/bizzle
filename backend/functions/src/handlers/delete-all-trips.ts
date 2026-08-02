import type { Request, Response } from 'express';
import { AuthError, verifyAuth } from '../utils/auth';
import { hardDeleteAllTripsForUser } from '../utils/bulk-delete';

/**
 * `DELETE /trips` — the "delete all my data, keep my account" action
 * (Phase 38, BACK-05) required alongside full account deletion for Google
 * Play's in-app data-deletion requirement.
 *
 * HARD-deletes every trip owned by the caller via
 * {@link hardDeleteAllTripsForUser}, INCLUDING trips already sitting in the
 * user's Trash. Nothing is retained for that uid.
 *
 * WHY it is hard: the in-app confirm dialog (`kDeleteAllDataDialogBody`)
 * promises "This permanently deletes every trip on this device, and in the
 * cloud if you're signed in," and the local Drift wipe is a genuine hard
 * delete. A "delete all my data" action that quietly retains records on the
 * backend is a false promise to the user and a Play / GDPR exposure. Device
 * and cloud must agree. The per-trip trash flow (`delete-trip.ts`) is still
 * SOFT, because Trash restore depends on it — that contrast remains true.
 *
 * Contract (verify -> validate -> trust, D-07):
 *   1. Verify the ID token FIRST. Missing/invalid/expired -> 401, no
 *      Firestore access.
 *   2. No path param and no body — there is nothing to validate beyond the
 *      verified token uid, so step 2 of the usual contract is a no-op here.
 *   3. Trust + hard-delete via {@link hardDeleteAllTripsForUser} (the
 *      <=500-per-batch chunking loop mirrors `sync-trips.ts`'s pattern).
 *
 * Zero matching trips is a valid, successful outcome: `deletedCount: 0`, not
 * an error. `deletedCount` now means "trips erased", not "trips marked
 * deleted".
 *
 * Response uses the consistent `{ statusCode, body: { data? | error? } }`
 * shape (D-06); errors are short typed strings only, never leaking internals.
 */
export async function deleteAllTripsHandler(
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
    const deletedCount = await hardDeleteAllTripsForUser(uid);
    res.status(200).json({ statusCode: 200, body: { data: { deletedCount } } });
  } catch {
    res.status(500).json({ statusCode: 500, body: { error: 'Internal error' } });
  }
}
