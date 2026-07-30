/**
 * Integration suite for DELETE /account (Phase 38, BACK-06) against the live
 * app on the emulator. Asserts full account deletion — trips HARD-deleted
 * (including any already sitting in Trash), `users/{uid}` doc gone, and the
 * Auth user gone — directly against emulator Firestore + Auth, no mocks.
 *
 * Hard-delete here is a deliberate, narrow exception to the project's D-11
 * "never hard-delete trips" rule, scoped ONLY to full account deletion — the
 * per-trip trash feature and the bulk `DELETE /trips` endpoint both remain
 * soft-delete-only (see their own test suites).
 *
 * Each deletion test mints its OWN dedicated uid (rather than reusing a
 * shared `tokenA`) because deleting the Auth user invalidates that uid for
 * the rest of the suite — reusing a shared token across a deleting test and
 * a later auth-dependent test would make the later test fail for the wrong
 * reason.
 */
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { getAuth } from 'firebase-admin/auth';
import { app } from '../../src/index';
import { mintIdToken } from '../helpers/mint-token';
import { clearFirestore, seedTrip, db } from '../helpers/emulator';

describe('DELETE /account', () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  describe('auth-reject', () => {
    it('no Authorization header -> 401', async () => {
      const res = await request(app).delete('/account');
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });

    it('invalid bearer token -> 401', async () => {
      const res = await request(app)
        .delete('/account')
        .set('Authorization', 'Bearer not-a-real-token');
      expect(res.status).toBe(401);
      expect(res.body.body.error).toBeDefined();
    });
  });

  describe('full account deletion', () => {
    it('hard-deletes trips, removes the preferences doc, and deletes the Auth user', async () => {
      const uid = `delacct-${randomUUID()}`;
      const token = await mintIdToken(uid);

      const t1 = randomUUID();
      const t2 = randomUUID();
      await seedTrip({ id: t1, userId: uid, deleted: false });
      await seedTrip({ id: t2, userId: uid, deleted: false });
      await db.collection('users').doc(uid).set({
        userId: uid,
        savedLocations: {
          homeLat: 12.9,
          homeLng: 77.6,
          officeLat: null,
          officeLng: null,
        },
        serverUpdatedAt: new Date(),
      });

      const res = await request(app)
        .delete('/account')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.body.data.deleted).toBe(true);

      // Trips: HARD-deleted (the deliberate D-11 exception for account
      // deletion) — the docs must be gone entirely, not merely flagged.
      for (const id of [t1, t2]) {
        const snap = await db.collection('trips').doc(id).get();
        expect(snap.exists).toBe(false);
      }

      // Preferences doc: hard-deleted.
      const prefsSnap = await db.collection('users').doc(uid).get();
      expect(prefsSnap.exists).toBe(false);

      // Auth user: gone.
      await expect(getAuth().getUser(uid)).rejects.toThrow();
    });

    it('also purges a trip that was already in Trash (soft-deleted) before account deletion', async () => {
      const uid = `delacct-trashed-${randomUUID()}`;
      const token = await mintIdToken(uid);

      const activeTrip = randomUUID();
      const trashedTrip = randomUUID();
      await seedTrip({ id: activeTrip, userId: uid, deleted: false });
      await seedTrip({ id: trashedTrip, userId: uid, deleted: true });

      const res = await request(app)
        .delete('/account')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.body.data.deleted).toBe(true);

      // Both the active trip AND the already-trashed one must be purged —
      // the hard-delete query in bulk-delete.ts deliberately omits the
      // `deleted` filter so nothing owned by this uid is left orphaned.
      for (const id of [activeTrip, trashedTrip]) {
        const snap = await db.collection('trips').doc(id).get();
        expect(snap.exists).toBe(false);
      }
    });

    it('succeeds even when the caller has no trips and no preferences doc', async () => {
      const uid = `delacct-empty-${randomUUID()}`;
      const token = await mintIdToken(uid);

      const res = await request(app)
        .delete('/account')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.body.data.deleted).toBe(true);

      await expect(getAuth().getUser(uid)).rejects.toThrow();
    });

    it("does not touch another user's trips", async () => {
      const uid = `delacct-iso-${randomUUID()}`;
      const token = await mintIdToken(uid);
      await mintIdToken('bystander');

      const ownTrip = randomUUID();
      const otherTrip = randomUUID();
      await seedTrip({ id: ownTrip, userId: uid, deleted: false });
      await seedTrip({ id: otherTrip, userId: 'bystander', deleted: false });

      const res = await request(app)
        .delete('/account')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);

      const otherSnap = await db.collection('trips').doc(otherTrip).get();
      expect(otherSnap.exists).toBe(true);
      expect(otherSnap.data()!.deleted).toBe(false); // untouched

      const bystanderStillExists = await getAuth().getUser('bystander');
      expect(bystanderStillExists.uid).toBe('bystander'); // untouched
    });
  });
});
