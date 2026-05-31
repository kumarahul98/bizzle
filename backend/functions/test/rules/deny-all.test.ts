/**
 * Deny-all Firestore Security Rules test (criterion 5, D-13).
 *
 * Proves the deployed rules close the client SDK -> Firestore boundary: BOTH an
 * unauthenticated client AND a signed-in client are denied direct read and
 * write of `trips/*`. Only the Admin SDK (Cloud Functions) — which bypasses
 * rules and is what every other test in this suite uses — may touch trip data.
 *
 * rules-unit-testing loads firestore.rules directly and talks to the firestore
 * emulator; it does not need the auth emulator. Host/port come from
 * FIRESTORE_EMULATOR_HOST (set by test/helpers/emulator.ts setupFiles).
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  initializeTestEnvironment,
  assertFails,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const [emuHost, emuPort] = (
  process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080'
).split(':');

describe('Firestore Security Rules — deny-all (criterion 5)', () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'travey-298a7',
      firestore: {
        rules: readFileSync(
          resolve(__dirname, '../../../firestore.rules'),
          'utf8',
        ),
        host: emuHost,
        port: Number(emuPort),
      },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it('denies an unauthenticated client read AND write of trips/*', async () => {
    const ctx = testEnv.unauthenticatedContext();
    const ref = doc(ctx.firestore(), 'trips', 'anon-trip');
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, { userId: 'anon' }));
  });

  it('denies a signed-in client read AND write of trips/*', async () => {
    const ctx = testEnv.authenticatedContext('userA');
    const ref = doc(ctx.firestore(), 'trips', 'userA-trip');
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, { userId: 'userA' }));
  });
});
