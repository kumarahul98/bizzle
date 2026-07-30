import type { Request, Response } from 'express';
import { AuthError, verifyAuth } from '../utils/auth';
import { softDeleteAllTripsForUser } from '../utils/bulk-delete';

/**
 * `DELETE /trips` — bulk soft-delete ALL of the caller's non-deleted trips
 * (Phase 38, BACK-05). This is the "delete all my data, keep my account"
 * action required alongside full account deletion for Google Play's in-app
 * data-deletion requirement.
 *
 * Contract (verify -> validate -> trust, D-07):
 *   1. Verify the ID token FIRST. Missing/invalid/expired -> 401, no
 *      Firestore access.
 *   2. No path param and no body — there is nothing to validate beyond the
 *      verified token uid, so step 2 of the usual contract is a no-op here.
 *   3. Trust + soft-delete via {@link softDeleteAllTripsForUser} (the
 *      <=500-per-batch chunking loop mirrors `sync-trips.ts`'s pattern).
 *      Trips are NEVER hard-deleted here (D-11) — this endpoint keeps the
 *      ordinary soft-delete rule. `DELETE /account` is the one deliberate,
 *      narrow exception to D-11 (see `delete-account.ts` /
 *      `hardDeleteAllTripsForUser`); this bulk "keep my account" endpoint is
 *      NOT part of that exception.
 *
 * Zero matching trips is a valid, successful outcome: `deletedCount: 0`, not
 * an error.
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
    const deletedCount = await softDeleteAllTripsForUser(uid);
    res.status(200).json({ statusCode: 200, body: { data: { deletedCount } } });
  } catch {
    res.status(500).json({ statusCode: 500, body: { error: 'Internal error' } });
  }
}
