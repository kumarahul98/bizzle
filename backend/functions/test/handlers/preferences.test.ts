/**
 * Integration suite for the Phase 29 preferences endpoints (LOC-03) against the
 * live app on the emulator — no mocks.
 *
 * Covers: auth rejection, the round trip, the never-synced user (SC#5),
 * idempotent re-sync, validation rejection (T-29-04), and — most importantly —
 * cross-user isolation (T-29-03): the document id comes from the verified
 * token, so a caller must never be able to read or write another user's saved
 * locations, no matter what the body says.
 */
import request from 'supertest';
import { app } from '../../src/index';
import { mintIdToken } from '../helpers/mint-token';
import { clearFirestore, db } from '../helpers/emulator';

const HOME = { homeLat: 12.9716, homeLng: 77.5946 };
const OFFICE = { officeLat: 12.9352, officeLng: 77.6245 };
const FULL = { ...HOME, ...OFFICE };

describe('preferences endpoints', () => {
  let tokenA: string;
  let tokenB: string;

  beforeAll(async () => {
    tokenA = await mintIdToken('prefUserA');
    tokenB = await mintIdToken('prefUserB');
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  describe('auth rejection', () => {
    it('POST /preferences/sync with no Authorization header -> 401', async () => {
      const res = await request(app)
        .post('/preferences/sync')
        .send({ savedLocations: FULL });
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });

    it('GET /preferences/restore with no Authorization header -> 401', async () => {
      const res = await request(app).get('/preferences/restore');
      expect(res.status).toBe(401);
    });

    it('invalid bearer token -> 401', async () => {
      const res = await request(app)
        .post('/preferences/sync')
        .set('Authorization', 'Bearer not-a-real-token')
        .send({ savedLocations: FULL });
      expect(res.status).toBe(401);
    });

    it('rejects BEFORE writing anything (401 leaves no document)', async () => {
      await request(app)
        .post('/preferences/sync')
        .set('Authorization', 'Bearer not-a-real-token')
        .send({ savedLocations: FULL });
      const snap = await db.collection('users').get();
      expect(snap.empty).toBe(true);
    });
  });

  describe('round trip (SC#1, SC#3)', () => {
    it('syncs then restores the same coordinates', async () => {
      const post = await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ savedLocations: FULL });
      expect(post.status).toBe(200);

      const get = await request(app)
        .get('/preferences/restore')
        .set('Authorization', `Bearer ${tokenA}`);
      expect(get.status).toBe(200);
      expect(get.body.body.data.savedLocations).toEqual(FULL);
    });

    it('writes the document under the token uid, not a body-supplied id', async () => {
      await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        // A hostile client tries to name the document AND the owner.
        .send({ savedLocations: FULL, userId: 'prefUserB', id: 'prefUserB' });

      const victim = await db.collection('users').doc('prefUserB').get();
      expect(victim.exists).toBe(false);

      const own = await db.collection('users').doc('prefUserA').get();
      expect(own.exists).toBe(true);
      expect(own.data()?.userId).toBe('prefUserA');
    });

    it('response carries no Firestore Timestamp (JSON-safe)', async () => {
      await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ savedLocations: FULL });

      const get = await request(app)
        .get('/preferences/restore')
        .set('Authorization', `Bearer ${tokenA}`);
      expect(get.body.body.data.savedLocations).toEqual(FULL);
      expect(get.body.body.data.serverUpdatedAt).toBeUndefined();
      expect(get.body.body.data.userId).toBeUndefined();
    });
  });

  describe('never-synced user (SC#5)', () => {
    it('restore returns all-null with 200, not 404', async () => {
      const res = await request(app)
        .get('/preferences/restore')
        .set('Authorization', `Bearer ${tokenA}`);
      expect(res.status).toBe(200);
      expect(res.body.body.data.savedLocations).toEqual({
        homeLat: null,
        homeLng: null,
        officeLat: null,
        officeLng: null,
      });
    });

    it('syncing all-null is valid, not an error', async () => {
      const res = await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({
          savedLocations: {
            homeLat: null,
            homeLng: null,
            officeLat: null,
            officeLng: null,
          },
        });
      expect(res.status).toBe(200);
    });
  });

  describe('idempotency (D-02 — no queue, so re-sends must be safe)', () => {
    it('re-syncing the same payload leaves one document, unchanged', async () => {
      for (let i = 0; i < 3; i += 1) {
        await request(app)
          .post('/preferences/sync')
          .set('Authorization', `Bearer ${tokenA}`)
          .send({ savedLocations: FULL });
      }
      const snap = await db.collection('users').get();
      expect(snap.size).toBe(1);

      const get = await request(app)
        .get('/preferences/restore')
        .set('Authorization', `Bearer ${tokenA}`);
      expect(get.body.body.data.savedLocations).toEqual(FULL);
    });

    it('a later sync overwrites the earlier value (last-write-wins)', async () => {
      await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ savedLocations: FULL });

      const moved = { homeLat: 1.1, homeLng: 2.2, officeLat: 3.3, officeLng: 4.4 };
      await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ savedLocations: moved });

      const get = await request(app)
        .get('/preferences/restore')
        .set('Authorization', `Bearer ${tokenA}`);
      expect(get.body.body.data.savedLocations).toEqual(moved);
    });

    it('clearing a location back to null persists as null', async () => {
      await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ savedLocations: FULL });

      await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({
          savedLocations: { ...OFFICE, homeLat: null, homeLng: null },
        });

      const get = await request(app)
        .get('/preferences/restore')
        .set('Authorization', `Bearer ${tokenA}`);
      // merge:true must not resurrect the old home coords from the prior write.
      expect(get.body.body.data.savedLocations).toEqual({
        homeLat: null,
        homeLng: null,
        ...OFFICE,
      });
    });
  });

  describe('validation rejection (T-29-04)', () => {
    it.each([
      ['out-of-range latitude', { ...FULL, homeLat: 91 }],
      ['out-of-range longitude', { ...FULL, homeLng: 181 }],
      ['half-set pair', { ...FULL, homeLng: null }],
      ['string coordinate', { ...FULL, homeLat: '12.97' }],
    ])('rejects %s with 400 and writes nothing', async (_label, savedLocations) => {
      const res = await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ savedLocations });
      expect(res.status).toBe(400);

      const snap = await db.collection('users').get();
      expect(snap.empty).toBe(true);
    });

    it('the 400 body does not echo the submitted coordinates (T-29-02)', async () => {
      const res = await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ savedLocations: { ...FULL, homeLat: 91 } });
      expect(res.status).toBe(400);
      // zod's issue list would quote the offending value back. A PII-bearing
      // error body could be captured by any logging intermediary.
      const serialized = JSON.stringify(res.body);
      expect(serialized).not.toContain('77.5946');
      expect(serialized).not.toContain('91');
    });
  });

  describe('cross-user isolation (T-29-03)', () => {
    it("userA's restore never returns userB's locations", async () => {
      await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ savedLocations: FULL });

      const get = await request(app)
        .get('/preferences/restore')
        .set('Authorization', `Bearer ${tokenA}`);
      expect(get.status).toBe(200);
      expect(get.body.body.data.savedLocations).toEqual({
        homeLat: null,
        homeLng: null,
        officeLat: null,
        officeLng: null,
      });
    });

    it("userA's sync cannot overwrite userB's document", async () => {
      await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ savedLocations: FULL });

      const overwrite = { homeLat: 1, homeLng: 1, officeLat: 2, officeLng: 2 };
      await request(app)
        .post('/preferences/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ savedLocations: overwrite, userId: 'prefUserB' });

      const b = await request(app)
        .get('/preferences/restore')
        .set('Authorization', `Bearer ${tokenB}`);
      expect(b.body.body.data.savedLocations).toEqual(FULL);
    });
  });
});
