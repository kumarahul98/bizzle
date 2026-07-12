import { Timestamp } from 'firebase-admin/firestore';

/**
 * Trip direction label. Auto-assigned from the morning/evening cutoff on the
 * client; always user-editable. Mirrors the Drift `direction` column values.
 */
export type Direction = 'to_office' | 'to_home';

/**
 * How `direction` was determined on the client (Phase 26). Mirrors the Drift
 * `direction_source` column values and the `kDirectionSource*` constants in
 * `lib/config/constants.dart` byte-for-byte.
 */
export type DirectionSource = 'manual' | 'geofence' | 'time';

/**
 * A single paused segment within a trip (Phase 26). Mirrors a row in the
 * client's `trip_breaks` table, projected to its two wire-relevant fields.
 */
export interface TripBreak {
  startTime: string;
  endTime: string;
}

/**
 * The cross-phase trip contract (Phase 10 server <-> Phase 11 client).
 *
 * Fields mirror the Drift `trips` table (lib/database/tables/trips_table.dart)
 * exactly, in camelCase. Timestamps are ISO 8601 UTC strings (D-10): they are
 * stored in Firestore as received for lossless restore round-trips. The server
 * forces `userId` to the verified token uid on write (D-08), so the client may
 * omit it.
 */
export interface Trip {
  id: string;
  userId: string;
  startTime: string;
  endTime: string;
  durationSeconds: number;
  distanceMeters: number;
  routePolyline: string | null;
  direction: Direction;
  timeMovingSeconds: number;
  timeStuckSeconds: number;
  isManualEntry: boolean;
  createdAt: string;
  updatedAt: string;
  /** Total time paused across all breaks, in seconds (Phase 26). */
  totalPausedSeconds: number;
  /** Whether the user manually edited this trip's details (Phase 26). */
  isEdited: boolean;
  /** How `direction` was determined (Phase 26). */
  directionSource: DirectionSource;
  /** Embedded paused segments for this trip (Phase 26), bounded by `kMaxBreaksPerTrip`. */
  breaks: TripBreak[];
}

/**
 * The Firestore document shape on read (D-10/D-11): a {@link Trip} plus the
 * server-owned metadata. `serverUpdatedAt` is set to a server timestamp on
 * every write; `deleted`/`deletedAt` drive the soft-delete model.
 */
export interface TripDoc extends Trip {
  deleted: boolean;
  deletedAt: Timestamp | null;
  serverUpdatedAt: Timestamp;
}
