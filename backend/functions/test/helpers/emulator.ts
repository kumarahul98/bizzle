/**
 * Emulator harness for the Phase 10 integration suite.
 *
 * Sets the emulator endpoints BEFORE firebase-admin is imported/initialized so
 * the Admin SDK talks to the local Auth + Firestore emulators (RESEARCH
 * "Emulator Testing"). Registered as the `integration` project's `setupFiles`
 * entry in jest.config.js, so these env vars are in place for every test file.
 *
 * Fail-fast: if the emulator endpoints are absent the Admin SDK would silently
 * try to reach prod. We default them, then assert they look like local hosts.
 */
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
process.env.GCLOUD_PROJECT ??= 'travey-298a7';

import { initializeApp, getApps } from 'firebase-admin/app';
import {
  getFirestore,
  FieldValue,
  Timestamp,
} from 'firebase-admin/firestore';
import type { DirectionSource, TripBreak, TripDoc } from '../../src/types/trip';

const FIRESTORE_HOST = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!FIRESTORE_HOST || !AUTH_HOST) {
  throw new Error(
    'Emulator hosts missing: FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST ' +
      'must be set before firebase-admin initializes. Run via `npm test` (emulators:exec).',
  );
}

if (!getApps().length) {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

/** Admin-SDK Firestore handle, wired to the emulator. Bypasses Security Rules. */
export const db = getFirestore();

/** The top-level `trips` collection (matches the handler's collection name). */
const TRIPS = 'trips';

/**
 * Delete every doc in the `trips` collection. Run in `beforeEach` so the shared
 * emulator namespace is clean between tests (the suite runs `--runInBand`).
 */
export async function clearFirestore(): Promise<void> {
  const snap = await db.collection(TRIPS).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

/** Overridable fields for {@link seedTrip}; everything else gets a sane default. */
export interface SeedTripInput {
  id: string;
  userId: string;
  deleted?: boolean;
  startTime?: string;
  endTime?: string;
  direction?: 'to_office' | 'to_home';
  totalPausedSeconds?: number;
  isEdited?: boolean;
  directionSource?: DirectionSource;
  breaks?: TripBreak[];
}

/**
 * Write a valid trip document straight to the emulator via the Admin SDK,
 * matching the Plan 02 doc shape ({@link TripDoc}): camelCase fields, ISO 8601
 * UTC string timestamps, server metadata. Used to pre-seed state for the
 * delete/restore/ownership tests without going through the sync handler.
 *
 * The 4 Phase 26 metadata fields default to their zero-values (matching
 * `tripConverter.fromFirestore`'s own defaults) when omitted, so every
 * existing call site stays backward compatible. For the SC4 "legacy doc"
 * test that needs a doc literally MISSING the 4 keys, write directly via the
 * exported `db` handle instead of this helper — `seedTrip`'s `TripDoc`-typed
 * literal always includes them.
 */
export async function seedTrip(input: SeedTripInput): Promise<void> {
  const deleted = input.deleted ?? false;
  const doc: TripDoc = {
    id: input.id,
    userId: input.userId,
    startTime: input.startTime ?? '2026-05-01T08:00:00.000Z',
    endTime: input.endTime ?? '2026-05-01T08:45:00.000Z',
    durationSeconds: 2700,
    distanceMeters: 12500,
    routePolyline: null,
    direction: input.direction ?? 'to_office',
    timeMovingSeconds: 2400,
    timeStuckSeconds: 300,
    isManualEntry: false,
    createdAt: '2026-05-01T08:45:00.000Z',
    updatedAt: '2026-05-01T08:45:00.000Z',
    totalPausedSeconds: input.totalPausedSeconds ?? 0,
    isEdited: input.isEdited ?? false,
    directionSource: input.directionSource ?? 'time',
    breaks: input.breaks ?? [],
    deleted,
    deletedAt: deleted ? Timestamp.now() : null,
    serverUpdatedAt: Timestamp.now(),
  };
  await db
    .collection(TRIPS)
    .doc(input.id)
    .set(doc as unknown as Record<string, unknown>);
}

/** Re-exported so seed/test helpers can build server-metadata fields if needed. */
export { FieldValue, Timestamp };
