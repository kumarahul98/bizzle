/**
 * Integration suite for DELETE /trips/:tripId (BACK-03) against the live app on
 * the emulator. Asserts soft-delete semantics and cross-user ownership directly
 * on emulator Firestore — no mocks.
 *
 * Covers: AUTH-REJECT (criterion 4), soft-delete happy path with the doc still
 * present (criterion 2), and cross-user ownership: userA deleting userB's trip
 * returns 404 (existence-oracle defence, D-08) and leaves the doc unchanged.
 */
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { app } from '../../src/index';
import { mintIdToken } from '../helpers/mint-token';
import { clearFirestore, seedTrip, db } from '../helpers/emulator';

describe('DELETE /trips/:tripId', () => {
  let tokenA: string;

  beforeAll(async () => {
    tokenA = await mintIdToken('userA');
    // Ensure userB exists as a token-mintable user (not strictly needed for
    // these tests, but keeps the user set symmetric with the other suites).
    await mintIdToken('userB');
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  describe('auth-reject (criterion 4)', () => {
    it('no Authorization header -> 401', async () => {
      const res = await request(app).delete(`/trips/${randomUUID()}`);
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });

    it('invalid bearer token -> 401', async () => {
      const res = await request(app)
        .delete(`/trips/${randomUUID()}`)
        .set('Authorization', 'Bearer not-a-real-token');
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });
  });

  describe('soft-delete happy path (criterion 2)', () => {
    it('sets deleted:true + deletedAt, doc still present', async () => {
      const id = randomUUID();
      await seedTrip({ id, userId: 'userA' });

      const res = await request(app)
        .delete(`/trips/${id}`)
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.body.data.id).toBe(id);

      const snap = await db.collection('trips').doc(id).get();
      expect(snap.exists).toBe(true); // NOT hard-deleted
      const data = snap.data()!;
      expect(data.deleted).toBe(true);
      expect(data.deletedAt).not.toBeNull();
      expect(data.serverUpdatedAt).toBeDefined();
    });
  });

  describe('cross-user ownership (D-08, criterion 2)', () => {
    it("userA cannot delete userB's trip -> 404, doc unchanged", async () => {
      const id = randomUUID();
      await seedTrip({ id, userId: 'userB', deleted: false });

      const res = await request(app)
        .delete(`/trips/${id}`)
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(404);

      const snap = await db.collection('trips').doc(id).get();
      expect(snap.exists).toBe(true);
      expect(snap.data()!.deleted).toBe(false); // untouched
    });
  });
});
