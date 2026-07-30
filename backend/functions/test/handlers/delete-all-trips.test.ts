/**
 * Integration suite for DELETE /trips (Phase 38, BACK-05) against the live app
 * on the emulator. Asserts bulk soft-delete semantics and cross-user ownership
 * directly on emulator Firestore — no mocks.
 *
 * Covers: AUTH-REJECT (mirrors delete-trip.test.ts), empty-trips success (0
 * deleted is not an error), multi-trip bulk soft-delete leaving `deleted:true`
 * on every one of the caller's non-deleted trips, already-deleted trips left
 * alone (idempotent re-run), and cross-user ownership: userA's bulk delete
 * never touches userB's trips (existence-oracle-adjacent defence, D-08).
 */
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { app } from '../../src/index';
import { mintIdToken } from '../helpers/mint-token';
import { clearFirestore, seedTrip, db } from '../helpers/emulator';

describe('DELETE /trips', () => {
  let tokenA: string;

  beforeAll(async () => {
    tokenA = await mintIdToken('userA');
    await mintIdToken('userB');
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  describe('auth-reject', () => {
    it('no Authorization header -> 401', async () => {
      const res = await request(app).delete('/trips');
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });

    it('invalid bearer token -> 401', async () => {
      const res = await request(app)
        .delete('/trips')
        .set('Authorization', 'Bearer not-a-real-token');
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });
  });

  describe('empty-trips success', () => {
    it('returns 200 with deletedCount:0 when the caller has no trips', async () => {
      const res = await request(app)
        .delete('/trips')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.body.data.deletedCount).toBe(0);
    });
  });

  describe('multi-trip bulk soft-delete', () => {
    it('soft-deletes every non-deleted trip owned by the caller', async () => {
      const a1 = randomUUID();
      const a2 = randomUUID();
      const a3 = randomUUID();
      const alreadyDeleted = randomUUID();

      await seedTrip({ id: a1, userId: 'userA', deleted: false });
      await seedTrip({ id: a2, userId: 'userA', deleted: false });
      await seedTrip({ id: a3, userId: 'userA', deleted: false });
      await seedTrip({ id: alreadyDeleted, userId: 'userA', deleted: true });

      const res = await request(app)
        .delete('/trips')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      // Only the 3 non-deleted trips were matched; the already-deleted one
      // was excluded from the query, not re-processed.
      expect(res.body.body.data.deletedCount).toBe(3);

      for (const id of [a1, a2, a3]) {
        const snap = await db.collection('trips').doc(id).get();
        expect(snap.exists).toBe(true); // NOT hard-deleted
        const data = snap.data()!;
        expect(data.deleted).toBe(true);
        expect(data.deletedAt).not.toBeNull();
        expect(data.serverUpdatedAt).toBeDefined();
      }
    });

    it('is idempotent: a second call finds nothing left to delete', async () => {
      const id = randomUUID();
      await seedTrip({ id, userId: 'userA', deleted: false });

      const first = await request(app)
        .delete('/trips')
        .set('Authorization', `Bearer ${tokenA}`);
      expect(first.status).toBe(200);
      expect(first.body.body.data.deletedCount).toBe(1);

      const second = await request(app)
        .delete('/trips')
        .set('Authorization', `Bearer ${tokenA}`);
      expect(second.status).toBe(200);
      expect(second.body.body.data.deletedCount).toBe(0);
    });
  });

  describe('cross-user ownership (D-08)', () => {
    it("userA's bulk delete never touches userB's trips", async () => {
      const aTrip = randomUUID();
      const bTrip = randomUUID();

      await seedTrip({ id: aTrip, userId: 'userA', deleted: false });
      await seedTrip({ id: bTrip, userId: 'userB', deleted: false });

      const res = await request(app)
        .delete('/trips')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.body.data.deletedCount).toBe(1);

      const bSnap = await db.collection('trips').doc(bTrip).get();
      expect(bSnap.exists).toBe(true);
      expect(bSnap.data()!.deleted).toBe(false); // untouched
    });
  });
});
