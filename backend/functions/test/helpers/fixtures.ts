/**
 * Typed trip fixtures for the handler suites. Builds valid {@link Trip} payloads
 * (real v4 UUID ids, ISO 8601 UTC timestamps, locked direction enum) so they
 * pass the handler's zod validation — invalid ids/timestamps would (correctly)
 * 400 at the sync schema.
 */
import { randomUUID } from 'node:crypto';
import type { Trip } from '../../src/types/trip';

/**
 * A valid sync-trip payload. `id` defaults to a fresh UUID. `userId` is set to a
 * deliberately spoofed value by default so server-forced-ownership tests can
 * assert the token uid wins; pass overrides for everything else.
 */
export function makeTrip(overrides: Partial<Trip> = {}): Trip {
  return {
    id: randomUUID(),
    userId: 'spoofed-client-uid',
    startTime: '2026-05-01T08:00:00.000Z',
    endTime: '2026-05-01T08:45:00.000Z',
    durationSeconds: 2700,
    distanceMeters: 12500,
    routePolyline: 'a~l~Fjk~uOwHJy@P',
    direction: 'to_office',
    timeMovingSeconds: 2400,
    timeStuckSeconds: 300,
    isManualEntry: false,
    createdAt: '2026-05-01T08:45:00.000Z',
    updatedAt: '2026-05-01T08:45:00.000Z',
    ...overrides,
  };
}

/** Build `count` valid trips with fresh UUID ids. */
export function makeTrips(count: number): Trip[] {
  return Array.from({ length: count }, () => makeTrip());
}
