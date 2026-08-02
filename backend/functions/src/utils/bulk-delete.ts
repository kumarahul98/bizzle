import { getFirestore } from 'firebase-admin/firestore';
import { tripsCollection } from './firestore';

/**
 * Firestore caps a single batched write at 500 operations (mirrors
 * `FIRESTORE_BATCH_LIMIT` in `handlers/sync-trips.ts`, D-12). Hard-delete
 * chunks the caller's trips at this size and commits sequentially.
 */
const FIRESTORE_BATCH_LIMIT = 500;

/**
 * Hard-delete EVERY trip owned by `uid`, regardless of its current `deleted`
 * flag. Used by both bulk erasure flows: `DELETE /trips` (Phase 38, BACK-05
 * — "delete all my data, keep my account") and `DELETE /account` (Phase 38,
 * BACK-06 — full account deletion).
 *
 * Current deletion model: the per-trip trash flow (`delete-trip.ts`) is
 * SOFT, because Trash restore depends on it. Both bulk erasure flows are
 * HARD, because both promise the user their data is gone — the in-app
 * "delete all data" dialog and the account-deletion flow both say
 * "permanently deletes" / "erases", and a backend that quietly retains
 * records would make that promise false.
 *
 * Contract:
 *   1. Query `trips` where `userId == uid` — deliberately WITHOUT a `deleted`
 *      filter. Account deletion must also purge trips already sitting in the
 *      user's Trash (soft-deleted, `deleted:true`); those are still owned by
 *      this uid and must not be left behind as unreachable documents.
 *   2. Hard-delete each match via `batch.delete()` (not `.update()`) — no
 *      soft-delete fields are written because the document itself is
 *      removed.
 *   3. Writes are chunked at <=500 ops per batch and committed sequentially,
 *      the same pattern as `sync-trips.ts`.
 *
 * Zero matching trips is a valid, successful outcome — returns `0`, not an
 * error. Callers propagate any Firestore error untouched; this function does
 * not do its own error translation (that is the handler's job).
 *
 * @returns The number of trips hard-deleted.
 */
export async function hardDeleteAllTripsForUser(uid: string): Promise<number> {
  const db = getFirestore();

  const snap = await tripsCollection().where('userId', '==', uid).get();

  const docIds = snap.docs.map((docSnap) => docSnap.id);

  for (let start = 0; start < docIds.length; start += FIRESTORE_BATCH_LIMIT) {
    const chunk = docIds.slice(start, start + FIRESTORE_BATCH_LIMIT);
    const batch = db.batch();
    for (const id of chunk) {
      batch.delete(tripsCollection().doc(id));
    }
    await batch.commit();
  }

  return docIds.length;
}
