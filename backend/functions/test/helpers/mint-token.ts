/**
 * Mint an emulator-issued Firebase ID token for a KNOWN uid.
 *
 * `getAuth().verifyIdToken()` (the handlers' auth gate) accepts tokens the Auth
 * emulator issues when FIREBASE_AUTH_EMULATOR_HOST is set. We need a
 * deterministic uid per test (userA / userB) so ownership/isolation assertions
 * are exact, so we use createCustomToken -> accounts:signInWithCustomToken
 * (NOT anonymous sign-up): the exchanged idToken's uid equals the chosen uid.
 *
 * Requires the Admin app to be initialized first (test/helpers/emulator.ts does
 * this via jest `setupFiles` before any test file imports this module).
 */
import { getAuth } from 'firebase-admin/auth';

const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!AUTH_HOST) {
  throw new Error(
    'FIREBASE_AUTH_EMULATOR_HOST is not set — mint-token must run under the ' +
      'emulator (via `npm test`).',
  );
}

interface SignInResponse {
  idToken?: string;
  error?: unknown;
}

/**
 * Ensure an Auth-emulator user exists at the exact uid. Swallows the
 * already-exists error so repeated mints for the same uid are idempotent.
 */
async function ensureUser(uid: string): Promise<void> {
  try {
    await getAuth().createUser({ uid });
  } catch (err) {
    const code = (err as { code?: string }).code;
    if (code !== 'auth/uid-already-exists') {
      throw err;
    }
  }
}

/**
 * Return an emulator ID token whose verified `uid` equals {@link uid}. The token
 * is accepted by `verifyIdToken()` in the handlers under the emulator.
 */
export async function mintIdToken(uid: string): Promise<string> {
  await ensureUser(uid);
  const customToken = await getAuth().createCustomToken(uid);

  const res = await fetch(
    `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );

  const json = (await res.json()) as SignInResponse;
  if (!json.idToken) {
    throw new Error(`mintIdToken failed: ${JSON.stringify(json)}`);
  }
  return json.idToken;
}
