---
phase: 35-deleted-trips-trash
created: 2026-07-21
status: not_started
mode: manual-gsd
requirements: [TRIP-07]
depends_on: [24, 26, 31, 33]
result: >
  NOT STARTED. Plan only. Schema v11 — must land AFTER Phase 31 (v9) and
  Phase 33 (v10). Also fixes a PRE-EXISTING bug not raised in the original
  request: trip_breaks has no FK cascade under PRAGMA foreign_keys = ON, so
  deleting a trip that has breaks may currently fail outright.
---

# Phase 35 — Deleted Trips (Trash)

**Goal**: Deleting a trip is recoverable for 30 days instead of instantly permanent, and
deleting a trip that has breaks stops being a coin flip.

**Depends on**: Phase 24 (restore, whose conflict detection must keep seeing deleted
rows), Phase 26 (the sync wire contract this must leave untouched), Phase 31 (the stuck
segments that must cascade), Phase 33 (schema ordering only)

---

## D-01 — Soft delete via `deletedAt`, and the cascade bug this exposes

CLAUDE.md states "**Soft deletes everywhere.** Trips are never hard-deleted." That is
true of Firestore and false of the client: `trips_dao.dart:199` issues a real `DELETE`,
and there has never been a `deleted` or `deleted_at` column on `Trips`. The only trace
of the intent is a stale comment at `constants.dart:64`.

Migration v11 adds `trips.deletedAt` (nullable UTC). Null means live.

**The same migration must fix a pre-existing bug that was not in the original report.**
`TripBreaks.tripId` declares `.references(Trips, #id)` with **no** `onDelete` action,
while `beforeOpen` sets `PRAGMA foreign_keys = ON` (`database.dart:186`). Deleting a trip
that has break rows should therefore raise a foreign-key violation, get swallowed by the
broad `on Object catch` in `TripManagementNotifier.deleteTrip`
(`trip_management_providers.dart:152`), and surface to the user as a generic
"couldn't delete" snackbar. **Any trip with a break may currently be undeletable.**

Verify this against a real database before designing around it — if SQLite is deferring
or the constraint is not enforced as expected, the fix is still correct but the
severity claim in this plan should be corrected rather than repeated.

Add `onDelete: KeyAction.cascade` to `TripBreaks.tripId` (and confirm the Phase 31
stuck-segments FK already has it). Changing a foreign-key clause requires a
`TableMigration` rebuild of `trip_breaks` — `addColumn` cannot alter a constraint.

Soft delete makes this less urgent day to day, since the normal path stops issuing
`DELETE` at all — but the purge in D-04 and "delete permanently" in D-05 both still hard
delete, so the cascade must be right or the bug simply moves.

## D-02 — Filter at the DAO, not at the call sites

Add `..where((t) => t.deletedAt.isNull())` to `watchAllSummaries()`
(`trips_dao.dart:88`).

That single change is sufficient for history, the dashboard **and** stats, because
`statsSummaryProvider` derives from `allTripSummariesProvider`, which wraps this exact
stream. Filtering at the call sites instead would require finding all three and would
leave the next consumer to rediscover the requirement.

Three other readers need individual judgement, and getting these wrong is how soft
delete corrupts a restore:

- `getAllTrips()` — restore conflict detection. **Must keep seeing deleted rows.** If it
  cannot, a soft-deleted trip is treated as absent, re-imported from the cloud backup as
  new, and the deletion silently undoes itself on the next restore.
- `tripIdsWithNonDefaultMetadata()` (Phase 26) — should exclude deleted rows; there is no
  reason to push metadata for a trip the user deleted.
- `mostRecentGpsTrip()` — should exclude deleted rows; it seeds the location-picker
  camera and a deleted trip is a poor anchor.

## D-03 — Sync contract unchanged; restore re-pushes a create

On soft delete, keep enqueuing the **existing delete action** with the existing payload.
The server still soft-deletes, the wire format is untouched, and no backend change is
needed in this phase.

One ordering detail survives from the current implementation and must not be lost: the
delete payload is built **before** the row is modified (`trip_management_providers.dart:169`,
"Pitfall 3"). With soft delete the row no longer disappears, so the constraint relaxes —
but the payload must still be captured inside the same transaction to stay consistent.

Restoring enqueues a **create** carrying the full payload; the server's upsert clears
`deleted: true`. This is safe precisely because sync is one-way and client-authoritative:
the client is the only writer, so there is no remote state that could disagree, and no
conflict resolution is needed. This is the same reasoning recorded in CLAUDE.md's sync
strategy.

## D-04 — Purge on app start, not on a timer

`initialize()` deletes rows where `deletedAt < now - kTrashRetentionDays` (**30**).
Cascade removes the associated breaks and stuck segments.

**The purge enqueues nothing.** The server was told at soft-delete time and keeps its own
soft-deleted copy per the project rule that Firestore never hard-deletes. Pushing a
second delete for a trip already deleted would be a no-op at best and, given the sync
engine treats a 404 as success (`api_client.dart:155`), pure noise.

A `WorkManager` job or periodic timer for a once-a-day cleanup of a handful of rows is
unjustified machinery. App start is frequent enough that no user will accumulate a
meaningful backlog, and if the app is never opened, nothing needs cleaning.

Purge must be defensive about clock changes: a device whose clock jumps backward must not
resurrect rows, and one that jumps forward must not purge a trip deleted this morning.
Compare against `deletedAt` in UTC and treat a negative age as zero.

## D-05 — Trash lives under Settings

New "Deleted trips" row in Settings opening a screen that lists soft-deleted trips
newest-first, each showing "Deleted 3 days ago · auto-removes in 27 days" so the 30-day
window is visible rather than a surprise.

Two actions per trip: **Restore**, and **Delete permanently** (with a confirmation, since
this one really is irreversible). Reuse the existing `TripCard` rather than building a
variant. An empty state when nothing is deleted.

The countdown must be computed from `deletedAt`, not stored — a stored countdown would
be wrong the moment the app is closed for a day.

| Option | Verdict |
|---|---|
| Undo snackbar only, no Trash screen | **Rejected.** Does not survive an app switch, and the request was explicitly for a section under Settings. |
| Trash as a filter on the history screen | **Rejected.** Puts deleted trips one tap from the main browsing flow and complicates the history query for a rarely-used view. |
| **Dedicated screen under Settings** | **Chosen.** Matches the request and keeps deleted rows out of every hot path. |

Adding an undo snackbar on delete is a reasonable follow-up but is **not** in this phase —
it changes the primary delete flow, which is currently shared by three screens via
`handleDeleteTrip` (`trip_actions.dart:15`), and that is a separate blast radius.

---

## Execution waves (conflict-safe)

**Wave 1 — data**

- `35-01` — schema **v11** (`trips.deletedAt`, `trip_breaks` FK cascade rebuild), the
  `watchAllSummaries` filter plus the three D-02 reader decisions, soft-delete and
  restore in `TripManagementNotifier`, and the startup purge. **Owns all Drift work.**

**Wave 2 — UI** *(blocked on Wave 1)*

- `35-02` — the Trash screen, the Settings entry, restore and permanent-delete actions,
  and the retention countdown.

---

## Threat model

| ID | Category | Asset | Decision | Mitigation |
|---|---|---|---|---|
| T-35-01 | Data loss | A deleted trip silently resurrected by cloud restore | **mitigate — the subtlest risk here** | `getAllTrips()` keeps seeing deleted rows (D-02) so restore's conflict detection recognises them as known ids and skips them. Explicit test: soft-delete a trip, run restore, assert it does not reappear in history. |
| T-35-02 | Data loss | Trips purged earlier than 30 days by clock skew | mitigate | UTC comparison, negative ages clamped to zero (D-04). |
| T-35-03 | Data loss | Cascade removing breaks for a *soft*-deleted trip | mitigate | Soft delete performs no `DELETE`, so cascade never fires on it. Cascade runs only on purge and permanent delete, where removing children is correct. |
| T-35-04 | Information disclosure | Deleted trips still present on device and in the cloud after the user believes they are gone | **accept, with disclosure** | This is the point of a trash. The retention countdown is shown on every row (D-05), and "Delete permanently" is available immediately. The server copy persists regardless, per the project-wide soft-delete rule that predates this phase. |
| T-35-05 | Data integrity | Deleted trips inflating stats | mitigate | The single `watchAllSummaries` filter covers stats, dashboard and history at once (D-02), with a test asserting stats totals drop when a trip is soft-deleted. |
| T-35-06 | Availability | The pre-existing FK violation making trips with breaks undeletable | mitigate | Cascade added in Wave 1 (D-01), with a regression test that deletes a trip having breaks. |

---

## Success criteria (what must be TRUE)

1. Deleting a trip removes it from history, the dashboard and stats simultaneously, and
   it appears under Settings → Deleted trips.
2. Restoring returns it to all three surfaces with its breaks and metadata intact.
3. Deleting a trip **that has breaks** succeeds — the pre-existing FK path is fixed.
4. A soft-deleted trip is **not** resurrected by a cloud restore.
5. Trips soft-deleted more than 30 days ago are purged on app start, along with their
   breaks and stuck segments; nothing is enqueued for sync by the purge.
6. Each Trash row shows how long ago it was deleted and how long remains.
7. "Delete permanently" confirms first, and afterwards the trip is unrecoverable locally.
8. The sync wire format is unchanged — the Phase 26 payload key-set test passes
   untouched.
9. `schemaVersion` is 11 and a v10 → v11 upgrade preserves every existing trip and break.

## Verification

- Unit: `watchAllSummaries` excludes soft-deleted rows; `getAllTrips` includes them.
- Unit: soft delete enqueues the existing delete action with an unchanged payload shape.
- Unit: restore enqueues a create with the full payload.
- Unit: purge boundary — 29 days, 30 days, 31 days, a future `deletedAt`, and a clock
  moved backward.
- Unit: stats totals drop when a trip is soft-deleted and return on restore.
- Integration: soft-delete → restore-from-cloud → assert the trip does **not** reappear
  (T-35-01).
- Regression: delete a trip that has breaks, on a v11 database (T-35-06).
- Migration: `SchemaVerifier` v10 → v11, including the `trip_breaks` FK rebuild.
- `flutter analyze` and `dart format .` clean.
- **Manual**: delete a trip with a break on a real device, confirm it is gone from all
  three surfaces, restore it, confirm the break survived.
- **Manual**: set the device clock forward past 30 days, relaunch, confirm the purge runs
  and the trip is gone from Trash.
