---
phase: 35-deleted-trips-trash
completed: 2026-07-22
status: code_complete_device_unverified
mode: manual-gsd
requirements: [TRIP-07]
branch: main
commits:
  - 67fe6ff (Wave 1 · 35-01 schema v11, soft delete, purge, FK cascade)
  - e74ed17 (Wave 2 · 35-02 Trash UI)
result: >
  Both waves built on main. Schema v11 landed (last of the post-v0.3-UAT
  batch, after Phase 31 v9 and Phase 33 v10). Deleting a trip is now a
  recoverable soft delete kept for 30 days under Settings → Deleted trips,
  and the pre-existing FK bug that made trips-with-breaks undeletable is
  fixed. flutter test 925 passed / 10 skipped (was 896 / 10, +29), analyze
  0 errors / 0 warnings / 295 info, dart format clean. SchemaVerifier
  v10 → v11 green. The two cloud/device success criteria (a restore over a
  real network; a real clock advanced past 30 days) are covered by a
  fake-backend integration test and a fixed-cutoff unit test respectively,
  NOT by a device — see "What is NOT verified".
---

# Phase 35 — Deleted Trips (Trash) — SUMMARY

## What shipped

| Wave | Commit | Content |
|---|---|---|
| 1 (35-01) | `67fe6ff` | Schema **v11**: nullable `trips.deletedAt` (null = live) + `trip_breaks` FK-cascade rebuild via `TableMigration`. `watchAllSummaries` filters `deletedAt IS NULL`; new `watchDeletedSummaries`; `softDeleteTrip` / `restoreTrip` / `purgeTripsDeletedBefore` DAO methods; the three D-02 reader decisions. `TripManagementNotifier.deleteTrip` → soft delete, plus `restoreTrip` and `deleteTripPermanently`. Startup `tripPurgeProvider` wired into `TraevyApp.build`. ~30 tests |
| 2 (35-02) | `e74ed17` | Settings → Data → "Deleted trips" row; `DeletedTripsScreen` (newest-deleted first, empty state); `DeletedTripTile` (reuses `TripRowCard` + countdown + Restore / Delete-permanently); `formatRetentionCountdown`; `deletedTripSummariesProvider`; `handleRestoreTrip` / `handleDeleteTripPermanently`. 13 tests |

**Verification:** `flutter analyze` **0 errors / 0 warnings** (295 info, all
pre-existing — none added, none fixed) · `flutter test` **925 passed, 10
skipped** (pre-phase baseline on `main` was **896 passed, 10 skipped**, +29) ·
`dart format` clean · `SchemaVerifier.migrateAndValidate(db, 11)` green.

> The prompt quoted a **283** pre-existing-info-lint bar and a **896 / 10**
> test baseline. The test baseline was correct; the lint number was stale — the
> measured pre-phase baseline on `main` is **295** info lints. The bar
> ("add none, fix none") was met against the real 295.

## Success criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Deleting removes a trip from history, dashboard and stats at once, and it appears under Settings → Deleted trips | ✅ one `watchAllSummaries` filter reaches all three (`statsSummaryProvider` derives from it); a provider-level test asserts week totals drop; the Trash stream shows it |
| 2 | Restoring returns it to all three surfaces with breaks and metadata intact | ✅ soft delete performs no `DELETE`, so breaks/segments are never removed; restore clears `deletedAt`; notifier + DAO tests assert the round-trip and break survival |
| 3 | Deleting a trip **that has breaks** succeeds — the pre-existing FK path is fixed | ✅ confirmed the bug is real first (see *Surprises*), then fixed by the cascade; regression tests at DAO, notifier and migrated-v11 levels |
| 4 | A soft-deleted trip is **not** resurrected by a cloud restore | ✅ `getAllTrips()` still sees deleted rows; T-35-01 integration test (fake backend) asserts the trip stays deleted and no duplicate live row is created |
| 5 | Trips deleted > 30 days ago are purged on app start with their children; nothing enqueued | ✅ `purgeTripsDeletedBefore` (UTC cutoff, cascade) + `tripPurgeProvider`; boundary tests 29/30/31 days, future-dated tombstone, and a "purge enqueues nothing" test |
| 6 | Each Trash row shows how long ago it was deleted and how long remains | ✅ `formatRetentionCountdown`, computed from `deletedAt` every render; unit tests for the canonical example, plural/singular, boundary, clamp |
| 7 | "Delete permanently" confirms first, then the trip is unrecoverable locally | ✅ confirm dialog, then hard delete + cascade; widget test taps through the dialog and asserts `findById` is null |
| 8 | The sync wire format is unchanged — Phase 26 payload key-set test passes untouched | ✅ `trip_serializer_test` unchanged and green; the soft-delete path enqueues the same delete action + `{id, userId}` payload (asserted by a notifier test) |
| 9 | `schemaVersion` is 11 and v10 → v11 preserves every trip and break | ✅ `migration_v11_test`: row + break survival, `deletedAt` reads null, `SchemaVerifier` DDL match, and cascade-on-a-migrated-db |

## Decisions as-built

D-01 through D-05 held. Three things were sharper in code than on paper:

**The FK bug is real — verified against a live v10 database before designing
around it, as the plan asked.** A throwaway probe inserted a trip with a break
on the current (v10) schema and called the old hard `deleteTrip`: it threw
`SqliteException(787): FOREIGN KEY constraint failed` and left the break row
behind. So the plan's severity claim stands unamended — under
`PRAGMA foreign_keys = ON`, any trip with a break was undeletable, and the
broad `on Object catch` in `deleteTrip` turned that into a generic "couldn't
delete" snackbar. `trip_stuck_segments` already cascaded (Phase 31, v9);
only `trip_breaks` lacked it.

**Restore re-pushes a create with a NULL payload, not an inline "full payload".**
The plan's wording ("enqueues a CREATE with the full payload") describes intent,
not mechanism. The house contract is that `enqueueCreate(tripId)` stores a NULL
payload and the sync engine re-reads the freshly un-deleted row at flush time
(same as a manual entry or a finalized trip). `restoreTrip` therefore just calls
`enqueueCreate` — the row is live again by then, so the re-read produces the
correct payload and the wire format is provably untouched.

**Soft delete keeps the "build payload before mutating" ordering even though it
no longer needs it.** With a hard delete the row vanished, so the `{id, userId}`
delete payload had to be built first (Pitfall 3). Soft delete leaves the row in
place, so the constraint has relaxed — but the payload is still built inside the
same transaction, before `softDeleteTrip`, so the enqueue stays consistent with
the write and the ordering rule does not quietly rot.

## Surprises

**Wave 1's FK change broke the *v3* migration test, not just the v11 one, and
the fix was a historical raw-DDL statement — not a golden regeneration.**
`m.createTable(tripBreaks)` emits the **live** table definition. Once the Dart
FK carried `ON DELETE CASCADE`, a v2 → v3 upgrade produced a v11-shaped
`trip_breaks` and failed the frozen v3 schema snapshot
(`Not equal: 'NOT NULL REFERENCES trips(id)' vs '... ON DELETE CASCADE'`). Only
`migration_v3` runs that `createTable`, so only it drifted (v4–v10 start from
their goldens and never recreate the table). Regenerating the frozen v3–v10
goldens would have rewritten history and is not something `drift_dev schema
dump` can even do per-version. The surgical fix: the v3 branch now creates
`trip_breaks` at its exact **historical** (no-cascade) shape via a raw
`customStatement`, so every frozen snapshot stays valid; the cascade is
installed for existing installs by the v11 `TableMigration` and for fresh
installs by `createAll`. Both paths converge on cascade. This was folded into
the Wave 1 commit since it is schema-migration correctness, not UI.

**There is no `TripCard` — the reusable trip widget is `TripRowCard`.** The plan
said "Reuse the existing `TripCard`". No such class exists; the history list
renders `TripRowCard` (in `lib/shared/widgets/`, taking primitive fields).
`DeletedTripTile` composes that widget — trip summary via `TripRowCard`, then the
countdown caption and the two action buttons below it — so the Trash rows match
history rows exactly, as intended.

**Two pre-existing tests asserted values this phase changes.**
`migration_v10_test`'s `schemaVersion is 10` and `settings_screen_test`'s
`renders 4 SettingsSection blocks` both encode "the head as of the previous
phase". The version-pin assertion moved to `migration_v11_test` (asserting each
head's version in one place, so future bumps touch one test); the section-count
test now expects 5 (Commute, Recording, Notifications, Appearance, **Data**).

## What is NOT verified

**SC#4 and SC#5 have no device/network coverage — the automated tests are the
substitute, and they are honestly narrower than the real thing.**

- **SC#4 (a cloud restore does not resurrect a deleted trip)** is proven only by
  the T-35-01 integration test with a **fake** `ApiClient` returning the same
  trip. It exercises the real `RestoreController` and the real Drift conflict
  logic, so it proves the *mechanism* (a soft-deleted id is recognised and not
  re-imported). It does **not** exercise a real `GET /trips/restore` over the
  network against real Firestore. That round-trip is device/backend-only.
- **SC#5 (purge after 30 days)** is proven by unit tests that pass a fixed
  cutoff and by boundary cases including a future-dated tombstone. No device has
  had its clock advanced past 30 days and been relaunched. The plan's two manual
  checks — deleting a trip with a break on a real device across all three
  surfaces, and advancing the device clock to watch the purge fire — remain
  outstanding.

Everything else (soft delete, restore, permanent delete, the FK cascade, the
countdown, the DAO filter reaching stats) is covered by unit + widget tests
against in-memory Drift and passes.

## Follow-ups

1. **Device-verify SC#4/SC#5** — on a real build: delete a trip with a break,
   confirm it leaves history/dashboard/stats and returns with its break on
   restore; then advance the device clock past 30 days, relaunch, and confirm
   the trip is purged from the Trash. Add to the Phase 23 device-only queue.
2. **Optional: an undo snackbar on delete** — explicitly out of scope here
   (D-05) because it changes the primary delete flow shared by three screens via
   `handleDeleteTrip`. A reasonable, separate follow-up if wanted.
