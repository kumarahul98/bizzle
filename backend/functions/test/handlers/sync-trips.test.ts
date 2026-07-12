/**
 * Integration suite for POST /trips/sync (BACK-02), driven against the live
 * exported Express app on the Firebase emulator via supertest. Asserts real
 * emulator Firestore state read back through the Admin SDK — no mocks.
 *
 * Covers: AUTH-REJECT (criterion 4), happy-path write with forced userId +
 * deleted:false (criterion 1), server-forces-ownership (D-08), the 1001-trip
 * DoS cap with zero writes (M1), and 600-trip 2-batch chunking (D-12).
 */
import request from 'supertest';
import { app } from '../../src/index';
import { mintIdToken } from '../helpers/mint-token';
import { clearFirestore, db } from '../helpers/emulator';
import { makeTrip, makeTrips } from '../helpers/fixtures';

describe('POST /trips/sync', () => {
  let tokenA: string;

  beforeAll(async () => {
    tokenA = await mintIdToken('userA');
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  describe('auth-reject (criterion 4)', () => {
    it('no Authorization header -> 401', async () => {
      const res = await request(app)
        .post('/trips/sync')
        .send({ trips: [makeTrip()] });
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });

    it('invalid bearer token -> 401', async () => {
      const res = await request(app)
        .post('/trips/sync')
        .set('Authorization', 'Bearer not-a-real-token')
        .send({ trips: [makeTrip()] });
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });
  });

  describe('happy path (criterion 1)', () => {
    it('writes trip docs with forced userId and deleted:false', async () => {
      const t1 = makeTrip();
      const t2 = makeTrip({
        totalPausedSeconds: 180,
        isEdited: true,
        directionSource: 'geofence',
        breaks: [
          { startTime: '2026-05-01T08:10:00.000Z', endTime: '2026-05-01T08:12:00.000Z' },
          { startTime: '2026-05-01T08:20:00.000Z', endTime: '2026-05-01T08:23:00.000Z' },
        ],
      });

      const res = await request(app)
        .post('/trips/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ trips: [t1, t2] });

      expect(res.status).toBe(200);
      expect(res.body.body.data.syncedIds.sort()).toEqual([t1.id, t2.id].sort());

      const snap1 = await db.collection('trips').doc(t1.id).get();
      const snap2 = await db.collection('trips').doc(t2.id).get();
      expect(snap1.exists).toBe(true);
      expect(snap2.exists).toBe(true);

      const d1 = snap1.data()!;
      expect(d1.userId).toBe('userA');
      expect(d1.deleted).toBe(false);
      expect(d1.deletedAt).toBeNull();
      // ISO-string round-trip preserved losslessly.
      expect(d1.startTime).toBe(t1.startTime);
      expect(d1.endTime).toBe(t1.endTime);
      expect(d1.serverUpdatedAt).toBeDefined();

      // Phase 26 metadata round-trips losslessly to the raw Firestore doc.
      const d2 = snap2.data()!;
      expect(d2.totalPausedSeconds).toBe(180);
      expect(d2.isEdited).toBe(true);
      expect(d2.directionSource).toBe('geofence');
      expect(d2.breaks).toEqual(t2.breaks);
    });
  });

  describe('server-forces-ownership (D-08, criterion 1 hardening)', () => {
    it('overwrites a spoofed client userId with the token uid', async () => {
      const trip = makeTrip({ userId: 'attacker' });

      const res = await request(app)
        .post('/trips/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ trips: [trip] });

      expect(res.status).toBe(200);
      const snap = await db.collection('trips').doc(trip.id).get();
      expect(snap.data()!.userId).toBe('userA');
    });
  });

  describe('DoS cap (M1) + chunking (D-12)', () => {
    it('1001 trips -> 400 and writes zero docs', async () => {
      const trips = makeTrips(1001);

      const res = await request(app)
        .post('/trips/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ trips });

      expect(res.status).toBe(400);
      const snap = await db.collection('trips').get();
      expect(snap.size).toBe(0);
    });

    it('600 trips -> 200 and writes all 600 across 2 batches', async () => {
      const trips = makeTrips(600);

      const res = await request(app)
        .post('/trips/sync')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ trips });

      expect(res.status).toBe(200);
      expect(res.body.body.data.syncedIds).toHaveLength(600);

      const snap = await db.collection('trips').get();
      expect(snap.size).toBe(600);
      // Every stored doc is owned by the token uid.
      expect(snap.docs.every((d) => d.data().userId === 'userA')).toBe(true);
    });
  });
});
