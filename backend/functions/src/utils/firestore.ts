import {
  getFirestore,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
  Timestamp,
} from 'firebase-admin/firestore';
import type { Direction, DirectionSource, TripBreak, TripDoc } from '../types/trip';

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
