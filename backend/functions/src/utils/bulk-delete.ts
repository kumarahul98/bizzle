import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { tripsCollection } from './firestore';

/**
 * Firestore caps a single batched write at 500 operations (mirrors
 * `FIRESTORE_BATCH_LIMIT` in `handlers/sync-trips.ts`, D-12). Bulk soft-delete
 * chunks the caller's non-deleted trips at this size and commits sequentially.
 */
const FIRESTORE_BATCH_LIMIT = 500;

/**
 * Soft-delete every non-deleted trip owned by `uid` (Phase 38, BACK-05).
 *
 * Used by `DELETE /trips` (bulk "delete all my data, keep my account") — the
 * one caller left after the account-deletion path moved to
 * {@link hardDeleteAllTripsForUser} (see that function's doc for why the two
 * diverge). Kept as its own exported function rather than folded away because
 * the per-trip trash feature (`delete-trip.ts`) and this bulk endpoint both
 * still rely on the ordinary soft-delete rule (D-11) — only full account
 * deletion is an exception to it.
 *
 * Contract:
 *   1. Query `trips` where `userId == uid` AND `deleted == false` (same
 *      predicate as `restore-trips.ts`'s restore query, D-08: never touches
 *      another user's trips).
 *   2. Soft-delete each match: `deleted:true`, `deletedAt`, and
 *      `serverUpdatedAt` (the same 3-field update as `delete-trip.ts`'s
 *      single-trip soft-delete, D-11). Trips are NEVER hard-deleted here.
 *   3. Writes are chunked at <=500 ops per batch and committed sequentially,
 *      matching `sync-trips.ts`'s chunking pattern.
 *
 * Zero matching trips is a valid, successful outcome — returns `0`, not an
 * error. Callers propagate any Firestore error untouched; this function does
 * not do its own error translation (that is the handler's job, per the
 * `{ statusCode, body }` response contract).
 *
 * @returns The number of trips soft-deleted.
 */
export async function softDeleteAllTripsForUser(uid: string): Promise<number> {
  const db = getFirestore();

  const snap = await tripsCollection()
    .where('userId', '==', uid)
    .where('deleted', '==', false)
    .get();

  const docIds = snap.docs.map((docSnap) => docSnap.id);

  for (let start = 0; start < docIds.length; start += FIRESTORE_BATCH_LIMIT) {
    const chunk = docIds.slice(start, start + FIRESTORE_BATCH_LIMIT);
    const batch = db.batch();
    for (const id of chunk) {
      batch.update(tripsCollection().doc(id), {
        deleted: true,
        deletedAt: FieldValue.serverTimestamp(),
        serverUpdatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  return docIds.length;
}

/**
 * Hard-delete EVERY trip owned by `uid`, regardless of its current `deleted`
 * flag (Phase 38, BACK-06). Used only by `DELETE /account` (full account
 * deletion).
 *
 * This is a deliberate, narrow exception to the project's "never hard-delete
 * trips" rule (D-11), which still governs everywhere else — the per-trip
 * trash feature (`delete-trip.ts`) and the bulk "delete all my data, keep my
 * account" endpoint (`delete-all-trips.ts`, via
 * {@link softDeleteAllTripsForUser}) are both unaffected and remain
 * soft-delete-only. The exception exists because "delete my account" must
 * mean the data is actually gone — an account with no owner and no restore
 * path has no legitimate reason to keep orphaned Firestore documents around
 * forever with no purge job to clean them up.
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
 *      the same pattern as {@link softDeleteAllTripsForUser} and
 *      `sync-trips.ts`.
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
