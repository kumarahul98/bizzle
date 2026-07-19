import {
  getFirestore,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
  Timestamp,
} from 'firebase-admin/firestore';
import type { Direction, DirectionSource, TripBreak, TripDoc } from '../types/trip';
import type { PreferencesDoc } from '../types/preferences';

/**
 * Coerce a Firestore timestamp-shaped value into an ISO 8601 UTC string.
 *
 * Trip time fields are stored as ISO strings (D-10), but a future write bug,
 * a manual console edit, or schema drift could leave a `Timestamp` in place.
 * Normalizing here means reads always map to the {@link TripDoc} string shape
 * — the JSON-safety guarantee is enforced, not merely asserted.
 */
function toIsoString(value: unknown): string {
  if (typeof value === 'string') {
    return value;
  }
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }
  return '';
}

/**
 * Coerce a nullable Firestore timestamp-shaped value into an ISO string or
 * `null` (for `deletedAt`).
 */
function toNullableTimestamp(value: unknown): Timestamp | null {
  return value instanceof Timestamp ? value : null;
}

/**
 * Typed converter for trip documents (D-09/D-10). Reads map raw snapshot data
 * to the {@link TripDoc} interface field-by-field (no blind `as` cast) so
 * handlers never touch untyped `DocumentData` and timestamp-shaped time fields
 * are coerced to ISO strings on the way out.
 */
export const tripConverter: FirestoreDataConverter<TripDoc> = {
  toFirestore: (trip: TripDoc) => trip,
  fromFirestore: (snapshot: QueryDocumentSnapshot): TripDoc => {
    const data = snapshot.data();
    return {
      id: data.id as string,
      userId: data.userId as string,
      startTime: toIsoString(data.startTime),
      endTime: toIsoString(data.endTime),
      durationSeconds: data.durationSeconds as number,
      distanceMeters: data.distanceMeters as number,
      routePolyline: (data.routePolyline as string | null) ?? null,
      direction: data.direction as Direction,
      timeMovingSeconds: data.timeMovingSeconds as number,
      timeStuckSeconds: data.timeStuckSeconds as number,
      isManualEntry: data.isManualEntry as boolean,
      createdAt: toIsoString(data.createdAt),
      updatedAt: toIsoString(data.updatedAt),
      // Phase 26 metadata fields: defaulted field-by-field for legacy docs
      // written before this phase (SC4). zod never runs on this read path
      // (Anti-Pattern in RESEARCH.md) — defaulting happens here, not via parse.
      totalPausedSeconds: (data.totalPausedSeconds as number | undefined) ?? 0,
      isEdited: (data.isEdited as boolean | undefined) ?? false,
      directionSource: (data.directionSource as DirectionSource | undefined) ?? 'time',
      breaks: (data.breaks as TripBreak[] | undefined) ?? [],
      deleted: data.deleted as boolean,
      deletedAt: toNullableTimestamp(data.deletedAt),
      serverUpdatedAt:
        data.serverUpdatedAt instanceof Timestamp
          ? data.serverUpdatedAt
          : Timestamp.now(),
    };
  },
};

/**
 * The top-level `trips` collection, typed via {@link tripConverter}. Document
 * id is the client trip UUID (D-09).
 */
export const tripsCollection = () =>
  getFirestore().collection('trips').withConverter(tripConverter);

/**
 * Coerce a stored coordinate to `number | null`.
 *
 * Anything that is not a finite number reads back as `null` — "not set" — which
 * is the safe direction to fail. A `NaN` or `Infinity` that reached the
 * document (console edit, schema drift, a write path predating the T-29-04
 * validation) would otherwise flow into the client's geofence resolver and
 * silently mislabel trip direction rather than erroring.
 */
function toCoordinate(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/**
 * Typed converter for per-user preference documents (Phase 29, D-04).
 *
 * Mirrors {@link tripConverter}: field-by-field mapping, no blind `as` cast on
 * the nested map, and legacy documents written before this phase default to
 * all-null rather than throwing.
 *
 * PII: this converter moves Home/Office coordinates. It must never log them —
 * T-21-03 stands (see `../types/preferences`).
 */
export const preferencesConverter: FirestoreDataConverter<PreferencesDoc> = {
  toFirestore: (prefs: PreferencesDoc) => prefs,
  fromFirestore: (snapshot: QueryDocumentSnapshot): PreferencesDoc => {
    const data = snapshot.data();
    // `savedLocations` may be absent on a doc written by another feature before
    // Phase 29, so guard the nested read rather than assuming the map exists.
    const saved = (data.savedLocations ?? {}) as Record<string, unknown>;
    return {
      userId: data.userId as string,
      savedLocations: {
        homeLat: toCoordinate(saved.homeLat),
        homeLng: toCoordinate(saved.homeLng),
        officeLat: toCoordinate(saved.officeLat),
        officeLng: toCoordinate(saved.officeLng),
      },
      serverUpdatedAt:
        data.serverUpdatedAt instanceof Timestamp
          ? data.serverUpdatedAt
          : Timestamp.now(),
    };
  },
};

/**
 * The top-level `users` collection, typed via {@link preferencesConverter}.
 * Document id is the verified token uid (D-04, T-29-03) — never a value taken
 * from the request body.
 */
export const usersCollection = () =>
  getFirestore().collection('users').withConverter(preferencesConverter);
