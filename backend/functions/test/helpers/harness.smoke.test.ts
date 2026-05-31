/**
 * Harness smoke test (Task 1): proves the emulator/token plumbing works before
 * the endpoint suites rely on it. Runs under the `integration` jest project.
 */
import request from 'supertest';
import { getAuth } from 'firebase-admin/auth';
import { app } from '../../src/index';
import { mintIdToken } from './mint-token';
import { clearFirestore, seedTrip, db } from './emulator';

describe('harness smoke', () => {
  it('mints a token verifyIdToken accepts with the matching uid', async () => {
    const token = await mintIdToken('userA');
    expect(typeof token).toBe('string');
    expect(token.length).toBeGreaterThan(0);

    const decoded = await getAuth().verifyIdToken(token);
    expect(decoded.uid).toBe('userA');
  });

  it('mints distinct uids for userA and userB', async () => {
    const [a, b] = await Promise.all([
      mintIdToken('userA'),
      mintIdToken('userB'),
    ]);
    const [da, db2] = await Promise.all([
      getAuth().verifyIdToken(a),
      getAuth().verifyIdToken(b),
    ]);
    expect(da.uid).toBe('userA');
    expect(db2.uid).toBe('userB');
    expect(da.uid).not.toBe(db2.uid);
  });

  it('clearFirestore empties the trips collection', async () => {
    await seedTrip({ id: '11111111-1111-4111-8111-111111111111', userId: 'userA' });
    let snap = await db.collection('trips').get();
    expect(snap.size).toBeGreaterThan(0);

    await clearFirestore();
    snap = await db.collection('trips').get();
    expect(snap.size).toBe(0);
  });

  it('exposes the exported Express app (unknown route -> 404)', async () => {
    const res = await request(app).get('/nope');
    expect(res.status).toBe(404);
  });
});
