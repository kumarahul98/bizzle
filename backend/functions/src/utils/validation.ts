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
 * Maximum number of break segments accepted per trip (Phase 26, T-26-01 DoS
 * cap). Rejects an oversized `breaks` array with a 400 before any Firestore
 * work, mirroring the `kMaxRoutePolylineChars`/`kMaxSyncBatchTrips` pattern.
 */
export const kMaxBreaksPerTrip = 50;

/**
 * zod schema for a single embedded break segment (Phase 26, T-26-03). Reuses
 * the same `.datetime()` validator already applied to the trip-level
 * `startTime`/`endTime` fields.
 */
const tripBreakSchema = z.object({
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
});

/**
 * zod schema mirroring the {@link import('../types/trip').Trip} contract.
 *
 * `id` is a UUID (D-09: the doc id is the client trip UUID). `userId` is
 * optional and ignored — the server forces it to the token uid (D-08).
 * Timestamps are ISO 8601 strings; `direction` is the locked enum.
 *
 * The 4 Phase 26 metadata fields (`totalPausedSeconds`, `isEdited`,
 * `directionSource`, `breaks`) are `.default()`-backed: zod 4 semantics make
 * the key optional on input AND fill the default in parsed output when
 * absent, so an older client that omits them still validates (old-client
 * compatibility, SC1/SC4). `directionSource`'s enum values are the literal
 * strings `'manual'`/`'geofence'`/`'time'`, matching the client's
 * `kDirectionSourceManual`/`kDirectionSourceGeofence`/`kDirectionSourceTime`
 * constants in `lib/config/constants.dart` byte-for-byte (T-26-02) — a
 * mismatch here would silently poison-pill every sync from a valid client.
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
  totalPausedSeconds: z.number().int().nonnegative().default(0),
  isEdited: z.boolean().default(false),
  directionSource: z.enum(['manual', 'geofence', 'time']).default('time'),
  breaks: z.array(tripBreakSchema).max(kMaxBreaksPerTrip).default([]),
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

/**
 * Latitude bounds. `.finite()` is load-bearing, not decoration: `z.number()`
 * rejects `NaN` but ACCEPTS `Infinity`, and an infinite coordinate would sail
 * through a naive `.min()/.max()` pair on the negative side.
 */
const latitudeSchema = z.number().finite().min(-90).max(90);

/** Longitude bounds. Same `.finite()` reasoning as {@link latitudeSchema}. */
const longitudeSchema = z.number().finite().min(-180).max(180);

/**
 * zod schema for the saved Home / Office coordinates (Phase 29, T-29-04).
 *
 * All four fields are nullable AND `.default(null)`-backed, so a user who has
 * never set either location still produces a valid payload (SC#5) rather than
 * a 400.
 *
 * The two `.refine`s enforce pair consistency: a latitude without its longitude
 * is not a location, it is corruption. Firestore would happily store the half
 * value, and the client's geofence resolver would then read a non-null lat with
 * a null lng on restore. Rejecting at the boundary is cheaper than defending
 * every downstream reader.
 *
 * Range validation matters more here than it looks (T-29-04): a poisoned
 * coordinate does not fail loudly, it silently mislabels the direction of every
 * future trip via the geofence resolver.
 */
export const savedLocationsSchema = z
  .object({
    homeLat: latitudeSchema.nullable().default(null),
    homeLng: longitudeSchema.nullable().default(null),
    officeLat: latitudeSchema.nullable().default(null),
    officeLng: longitudeSchema.nullable().default(null),
  })
  .refine(
    (v) => (v.homeLat === null) === (v.homeLng === null),
    { message: 'homeLat and homeLng must both be set or both be null' },
  )
  .refine(
    (v) => (v.officeLat === null) === (v.officeLng === null),
    { message: 'officeLat and officeLng must both be set or both be null' },
  );

/**
 * Request body schema for `POST /preferences/sync` (Phase 29).
 *
 * Wrapped in a `savedLocations` object rather than four top-level keys so the
 * document shape, the wire shape, and {@link import('../types/preferences').SavedLocations}
 * stay identical — one shape to reason about instead of a mapping step.
 */
export const syncPreferencesBody = z.object({
  savedLocations: savedLocationsSchema,
});

/** Inferred type for validated saved locations. */
export type SavedLocationsInput = z.infer<typeof savedLocationsSchema>;

/** Inferred type for a validated preferences sync body. */
export type SyncPreferencesBody = z.infer<typeof syncPreferencesBody>;
