/**
 * Integration suite for DELETE /trips (Phase 38, BACK-05) against the live app
 * on the emulator. Asserts bulk HARD-delete semantics and cross-user ownership
 * directly on emulator Firestore — no mocks.
 *
 * Covers: AUTH-REJECT (mirrors delete-trip.test.ts), empty-trips success (0
 * deleted is not an error), multi-trip bulk hard-delete erasing every one of
 * the caller's trip documents, mixed live+Trash trips (the case that
 * motivated D-1: trips already sitting in Trash must ALSO be erased, not
 * skipped), idempotent re-run (a second call finds nothing left because the
 * documents are gone, not because they were filtered out), and cross-user
 * ownership: userA's bulk delete never touches userB's trips
 * (existence-oracle-adjacent defence, D-08).
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

  describe('multi-trip bulk hard-delete', () => {
    it('hard-deletes every trip owned by the caller', async () => {
      const a1 = randomUUID();
      const a2 = randomUUID();
      const a3 = randomUUID();

      await seedTrip({ id: a1, userId: 'userA', deleted: false });
      await seedTrip({ id: a2, userId: 'userA', deleted: false });
      await seedTrip({ id: a3, userId: 'userA', deleted: false });

      const res = await request(app)
        .delete('/trips')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.body.data.deletedCount).toBe(3);

      for (const id of [a1, a2, a3]) {
        const snap = await db.collection('trips').doc(id).get();
        expect(snap.exists).toBe(false); // hard-deleted, document gone
      }
    });

    it('hard-deletes trips already sitting in Trash too (mixed live + Trash, D-1)', async () => {
      const live1 = randomUUID();
      const live2 = randomUUID();
      const trashed1 = randomUUID();
      const trashed2 = randomUUID();

      await seedTrip({ id: live1, userId: 'userA', deleted: false });
      await seedTrip({ id: live2, userId: 'userA', deleted: false });
      await seedTrip({ id: trashed1, userId: 'userA', deleted: true });
      await seedTrip({ id: trashed2, userId: 'userA', deleted: true });

      const res = await request(app)
        .delete('/trips')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      // All four counted: the hard helper has no `deleted` filter, so
      // already-trashed trips are erased too, not skipped.
      expect(res.body.body.data.deletedCount).toBe(4);

      const remaining = await db.collection('trips').where('userId', '==', 'userA').get();
      expect(remaining.empty).toBe(true);
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
      // deletedCount is 0 because the documents are gone entirely, not
      // because they were filtered out by a `deleted:true` predicate.
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
