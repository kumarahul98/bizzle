import { Timestamp } from 'firebase-admin/firestore';

/**
 * The user's saved Home / Office coordinates (Phase 29, LOC-03).
 *
 * Mirrors the four nullable `home_lat` / `home_lng` / `office_lat` /
 * `office_lng` columns on the client's single-row `user_preferences` table
 * (`lib/database/tables/user_preferences_table.dart`). `null` means "not set" —
 * the same meaning it carries locally.
 *
 * ## PII posture — read this before touching anything here
 *
 * These coordinates reveal where the user lives and works. Phase 21 originally
 * recorded (T-21-02 / T-21-02-01) that they must NEVER leave the device.
 * Phase 29 reverses that deliberately — see D-01 in
 * `.planning/phases/29-sync-home-office-locations/29-PLAN.md` for the rationale
 * and its costs, including the Play Data Safety declaration change.
 *
 * **What was NOT reversed: T-21-03, "never log".** Transporting a coordinate
 * over TLS to our own Firestore is a different act from writing it to a log
 * sink. Nothing in this module — handlers, converter, or error paths — may
 * echo a coordinate into a log line or an HTTP error body.
 */
export interface SavedLocations {
  homeLat: number | null;
  homeLng: number | null;
  officeLat: number | null;
  officeLng: number | null;
}

/**
 * The per-user preferences document (Phase 29, D-04).
 *
 * Exactly one document per user, keyed by the verified token uid, at
 * `users/{uid}` — NOT a subcollection, because there is one row per user
 * forever and a subcollection would add a hop for nothing.
 *
 * `userId` is redundant with the doc id and stored anyway, matching how
 * `TripDoc` carries `id`: it keeps a document self-describing if it is ever
 * exported or inspected outside its collection path.
 */
export interface PreferencesDoc {
  userId: string;
  savedLocations: SavedLocations;
  /** Server-assigned write time. Never read by the client; audit only. */
  serverUpdatedAt: Timestamp;
}
