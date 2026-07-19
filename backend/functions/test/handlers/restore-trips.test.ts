/**
 * Integration suite for GET /trips/restore (BACK-04) against the live app on the
 * emulator. Asserts the response body filters to exactly the caller's
 * non-deleted trips — no mocks.
 *
 * Covers: AUTH-REJECT (criterion 4), filtered happy path (excludes deleted +
 * other users' trips, criterion 3), and cross-user isolation (D-08): userA's
 * restore never returns userB's data.
 */
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import type { Trip } from '../../src/types/trip';
import { app } from '../../src/index';
import { mintIdToken } from '../helpers/mint-token';
import { clearFirestore, seedTrip, db, Timestamp } from '../helpers/emulator';

describe('GET /trips/restore', () => {
  let tokenA: string;

  beforeAll(async () => {
    tokenA = await mintIdToken('userA');
    await mintIdToken('userB');
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  describe('auth-reject (criterion 4)', () => {
    it('no Authorization header -> 401', async () => {
      const res = await request(app).get('/trips/restore');
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });

    it('invalid bearer token -> 401', async () => {
      const res = await request(app)
        .get('/trips/restore')
        .set('Authorization', 'Bearer not-a-real-token');
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });
  });

  describe('filtered happy path + cross-user isolation (criterion 3, D-08)', () => {
    it("returns only the caller's non-deleted trips", async () => {
      const a1 = randomUUID();
      const a2 = randomUUID();
      const aDeleted = randomUUID();
      const bTrip = randomUUID();

      await seedTrip({ id: a1, userId: 'userA', deleted: false });
      await seedTrip({ id: a2, userId: 'userA', deleted: false });
      await seedTrip({ id: aDeleted, userId: 'userA', deleted: true });
      await seedTrip({ id: bTrip, userId: 'userB', deleted: false });

      const res = await request(app)
        .get('/trips/restore')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      const trips = res.body.body.data.trips as Trip[];
      const ids = trips.map((t) => t.id).sort();

      expect(ids).toEqual([a1, a2].sort());
      expect(ids).not.toContain(aDeleted); // deleted excluded
      expect(ids).not.toContain(bTrip); // other user excluded
      // Returned trips carry only the userA owner.
      expect(trips.every((t) => t.userId === 'userA')).toBe(true);

      // HI-01: the response must be clean, JSON-safe client Trip objects —
      // time fields are ISO 8601 strings, and NO server metadata
      // (`deleted`/`deletedAt`/`serverUpdatedAt`) leaks to the client.
      const isoPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
      for (const t of trips) {
        expect(typeof t.startTime).toBe('string');
        expect(t.startTime).toMatch(isoPattern);
        expect(typeof t.endTime).toBe('string');
        expect(t.endTime).toMatch(isoPattern);
        expect(typeof t.createdAt).toBe('string');
        expect(t.createdAt).toMatch(isoPattern);
        expect(typeof t.updatedAt).toBe('string');
        expect(t.updatedAt).toMatch(isoPattern);

        const raw = t as unknown as Record<string, unknown>;
        expect(raw).not.toHaveProperty('deleted');
        expect(raw).not.toHaveProperty('deletedAt');
        expect(raw).not.toHaveProperty('serverUpdatedAt');
      }
    });
  });

  describe('legacy doc + new metadata (SC4)', () => {
    it('defaults the 4 new fields for a doc that literally omits them', async () => {
      const id = randomUUID();
      // Raw write via the Admin SDK handle, deliberately omitting
      // totalPausedSeconds/isEdited/directionSource/breaks entirely (not just
      // setting them to their default values) to prove the converter defaults
      // a genuinely legacy (pre-Phase-26) Firestore doc without throwing.
      await db
        .collection('trips')
        .doc(id)
        .set({
          id,
          userId: 'userA',
          startTime: '2026-05-01T08:00:00.000Z',
          endTime: '2026-05-01T08:45:00.000Z',
          durationSeconds: 2700,
          distanceMeters: 12500,
          routePolyline: null,
          direction: 'to_office',
          timeMovingSeconds: 2400,
          timeStuckSeconds: 300,
          isManualEntry: false,
          createdAt: '2026-05-01T08:45:00.000Z',
          updatedAt: '2026-05-01T08:45:00.000Z',
          deleted: false,
          deletedAt: null,
          serverUpdatedAt: Timestamp.now(),
        });

      const res = await request(app)
        .get('/trips/restore')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      const trips = res.body.body.data.trips as Trip[];
      const trip = trips.find((t) => t.id === id);
      expect(trip).toBeDefined();
      expect(trip!.totalPausedSeconds).toBe(0);
      expect(trip!.isEdited).toBe(false);
      expect(trip!.directionSource).toBe('time');
      expect(trip!.breaks).toEqual([]);
    });

    it('round-trips explicit non-default metadata unchanged', async () => {
      const id = randomUUID();
      const breaks = [
        { startTime: '2026-05-01T08:10:00.000Z', endTime: '2026-05-01T08:12:00.000Z' },
      ];
      await seedTrip({
        id,
        userId: 'userA',
        totalPausedSeconds: 120,
        isEdited: true,
        directionSource: 'manual',
        breaks,
      });

      const res = await request(app)
        .get('/trips/restore')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      const trips = res.body.body.data.trips as Trip[];
      const trip = trips.find((t) => t.id === id);
      expect(trip).toBeDefined();
      expect(trip!.totalPausedSeconds).toBe(120);
      expect(trip!.isEdited).toBe(true);
      expect(trip!.directionSource).toBe('manual');
      expect(trip!.breaks).toEqual(breaks);
    });
  });
});
