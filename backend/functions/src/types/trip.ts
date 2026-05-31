import { Timestamp } from 'firebase-admin/firestore';

/**
 * Trip direction label. Auto-assigned from the morning/evening cutoff on the
 * client; always user-editable. Mirrors the Drift `direction` column values.
 */
export type Direction = 'to_office' | 'to_home';

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
