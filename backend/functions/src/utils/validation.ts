import { z } from 'zod';

/**
 * Maximum number of trips accepted in a single `POST /trips/sync` request
 * body. Bounds the request to reject an unbounded sync payload with a 400
 * before any Firestore work (M1 DoS cap). Per-commit cost is further bounded
 * by <=500 batch chunking in the sync handler (Plan 02).
 */
export const kMaxSyncBatchTrips = 1000;

/**
 * Maximum encoded-polyline length accepted. An encoded polyline for a normal
 * commute is well under this; the cap bounds parse-memory before Firestore's
 * 1 MiB document limit would throw (cross-AI review hardening).
 */
const kMaxRoutePolylineChars = 100000;

/**
 * zod schema mirroring the {@link import('../types/trip').Trip} contract.
 *
 * `id` is a UUID (D-09: the doc id is the client trip UUID). `userId` is
 * optional and ignored — the server forces it to the token uid (D-08).
 * Timestamps are ISO 8601 strings; `direction` is the locked enum.
 */
export const tripSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().optional(),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  durationSeconds: z.number().int().nonnegative(),
  distanceMeters: z.number().nonnegative(),
  routePolyline: z.string().max(kMaxRoutePolylineChars).nullable(),
  direction: z.enum(['to_office', 'to_home']),
  timeMovingSeconds: z.number().int().nonnegative(),
  timeStuckSeconds: z.number().int().nonnegative(),
  isManualEntry: z.boolean(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});

/**
 * Request body schema for `POST /trips/sync`: a non-empty array of trips capped
 * at {@link kMaxSyncBatchTrips} (D-12 + M1 DoS cap). `.min(1)` rejects an empty
 * batch; `.max()` rejects an oversized one.
 */
export const syncTripsBody = z.object({
  trips: z.array(tripSchema).min(1).max(kMaxSyncBatchTrips),
});

/**
 * Path-param schema for `DELETE /trips/:tripId`: the trip UUID (D-09). Reject
 * non-UUID ids.
 */
export const tripIdParam = z.object({
  tripId: z.string().uuid(),
});

/** Inferred type for a validated trip payload. */
export type TripInput = z.infer<typeof tripSchema>;

/** Inferred type for a validated sync request body. */
export type SyncTripsBody = z.infer<typeof syncTripsBody>;
