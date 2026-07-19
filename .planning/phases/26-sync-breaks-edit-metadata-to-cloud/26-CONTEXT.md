# Phase 26: Sync Breaks & Edit Metadata to Cloud - Context

**Gathered:** 2026-07-12
**Status:** Ready for planning

<domain>
## Phase Boundary

The cloud copy of a trip carries everything the local copy knows — break segments,
paused total, edited flag, and direction source — so a restore to a new device
reproduces the trip exactly instead of silently dropping v0.3 metadata.

**In scope:**
- Extend the sync payload (`TripSerializer.toJson`) and Firestore document with
  `totalPausedSeconds`, `isEdited`, `directionSource`, and an embedded `breaks`
  array of `{startTime, endTime}` ISO-string segments (bounded, e.g. max 50/trip).
- Extend the zod `tripSchema` and backend `Trip`/`TripDoc` types — all four new
  fields optional with defaults so older clients keep syncing.
- Restore parses the new fields (`TripSerializer.fromJson`), writes breaks into
  `trip_breaks` in the same transaction as the trip insert.
- Restore-time enrichment of existing local trips whose metadata is empty/default
  (D-10, D-11).
- One-time backfill re-enqueue of local trips with non-default metadata (D-01..D-03).
- Merge-flow ride-along rules for breaks/metadata + the deferred pure-function
  merge extraction (D-04..D-07).
- Backend deploys BEFORE any client that emits the new fields (roadmap SC2 —
  the non-strict zod schema would silently strip unknown keys without an error).

**Out of scope:**
- Per-break merge UI (roadmap SC5 locks: breaks ride along, never merged per-segment).
- Any continuous two-way sync (SYNC2-01, v2).
- Reworking conflict detection beyond excluding metadata fields (D-07).
- Overlap-conflict UUID semantics rework (still deferred from 25.1).

</domain>

<decisions>
## Implementation Decisions

### Backfill scope & trigger (roadmap SC4)
- **D-01:** The one-time backfill re-enqueues trips with **any non-default
  metadata**: breaks present, `isEdited = true`, OR a non-default
  `directionSource` (e.g. geofence/manual from Phase 21). Wider than the literal
  roadmap wording ("breaks or edits") so geofence-labeled trips don't keep an
  incomplete cloud copy forever.
- **D-02:** The backfill runs off the **same auth-transition seam Phase 24's
  auto-restore uses** (AuthLoading/AuthGuest → AuthSignedIn) — user framed this
  as "first sign-in after upgrade"; the transition also fires on session restore
  at launch, so already-signed-in users get it on their next launch. Guarded by
  the D-03 marker so it runs exactly once.
- **D-03:** "Already ran" is tracked as a **version-keyed marker** (e.g.
  "backfill done for payload schema v2") persisted in `user_preferences` —
  future-proof for later backfill waves. Requires a schema bump + drift snapshot
  + migration test per project convention.

### Breaks in the merge flow (roadmap SC5)
- **D-04:** In a mixed field-by-field merge, breaks + `totalPausedSeconds`
  **follow whichever side won the time fields** (startTime/endTime) so a break
  can never fall outside the merged trip's window. `directionSource` follows the
  direction toggle's chosen side. `isEdited` resolves automatically (Claude's
  discretion; merged output is user-touched, so `true` is the natural result).
- **D-05:** The conflict sheet gains a **read-only breaks indicator** shown only
  when the two sides differ in breaks (e.g. "Local: 2 breaks · Cloud: none").
  No per-break controls, no new toggleable rows — the five existing mergeable
  fields stay as-is.
- **D-06:** Do the **deferred merge refactor from Phase 25.1 first**: extract
  the merge resolution (currently inside `conflict_resolution_sheet.dart`'s
  `_applyAll`) into a pure function, pin it with unit tests, THEN add the D-04
  ride-along rules to it.
- **D-07:** The new metadata fields **never trigger same-UUID conflict
  detection**. Only the original five fields (times, duration, distance,
  direction) flag conflicts; metadata differences resolve silently — local wins
  and the backfill pushes local metadata up. This prevents a post-upgrade storm
  of conflict prompts while cloud copies are still metadata-less.

### Breaks for existing trips on restore
- **D-10:** When restore finds an existing local trip with **no breaks** while
  the cloud copy has them, it **enriches** the local trip: attach cloud breaks
  (and paused total). Nothing local is overwritten — local just has nothing to
  win with. Covers trips restored on this device before the upgrade.
- **D-11:** Enrichment is a **uniform rule across all four metadata fields**:
  when the local value is default/empty and cloud carries a real value, adopt
  cloud's (`breaks`, `totalPausedSeconds`, `directionSource`, `isEdited`). Real
  local values are never replaced by enrichment.

### Claude's Discretion
- When the D-03 marker is set (enqueue time vs after upload) — the sync queue is
  persistent with retries, so enqueue-time is the natural choice.
- Backfill burst handling — existing batch cap (`kMaxSyncBatchTrips`) and
  server-side 500-chunking already bound it.
- Whether a D-10/D-11 enrichment write bypasses the sync re-queue (it matches
  cloud exactly, so re-upload is redundant but harmless) — pick the cleaner path.
- Exact breaks-array cap value (roadmap suggests 50) and whether break segments
  round-trip their UUIDs or restore regenerates ids.
- Edit-flow interaction for roadmap SC3 (restored trip with breaks survives a
  subsequent edit without paused time recomputing to zero) — implementation
  detail of the edit path reading `trip_breaks`.
- Exact copy/placement of the D-05 breaks indicator line.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap + prior-phase decisions
- `.planning/ROADMAP.md` — Phase 26 section (goal, 5 success criteria; SC1/SC5
  lock the payload shape and no-per-break-merge; SC2 locks deploy ordering).
- `.planning/phases/25.1-fix-sync-conflict-auto-retry-bugs/25.1-CONTEXT.md` —
  merge default = 'local' (D-05), Merge All ≡ Keep All Local accepted (D-06),
  and the deferred pure-function merge extraction this phase now executes.
- `.planning/phases/24-automatic-cloud-sync-restore/24-CONTEXT.md` — conflict
  classes (D-03), bulk + per-trip merge UX (D-04), cloud overwrites go through
  the DAO update path so rows re-queue (D-06), auth-transition auto-restore seam
  (D-01) that the backfill trigger (this phase's D-02) reuses.

### Client sync surfaces (the code this phase extends)
- `lib/sync/trip_serializer.dart` — `toJson`/`fromJson`; the wire contract that
  gains the four new fields + embedded breaks. Note: `toJson` currently takes a
  `TripRow` only — it needs break rows joined in (fresh read at sync time).
- `lib/sync/sync_engine.dart` — payload is read fresh at sync time (not enqueue
  time), so backfill = `enqueueUpdate` per trip id and the engine does the rest.
- `lib/sync/api_client.dart` — `syncTrips` (`:132` serializes via
  `TripSerializer.toJson`), `restoreTrips` (`:186` parses via `fromJson`).
- `lib/sync/restore_controller.dart` — sealed `RestoreState`, conflict branch,
  `insertOrIgnoreTrips` insert path; extend for transactional break writes +
  D-10/D-11 enrichment.
- `lib/sync/restore_conflict.dart` — conflict model; D-07 excludes metadata
  fields from same-UUID difference detection.
- `lib/features/settings/widgets/conflict_resolution_sheet.dart` — `_applyAll`
  merge logic to extract (D-06), per-field defaults now 'local' (25.1), site of
  the D-05 breaks indicator.

### Local schema + DAOs
- `lib/database/tables/trips_table.dart` — `totalPausedSeconds` (:53),
  `directionSource` (:78), `isEdited` (:101) already exist locally.
- `lib/database/tables/trip_breaks_table.dart` — normalized breaks table;
  finalized trips never carry an open (null-endTime) break.
- `lib/database/daos/trip_breaks_dao.dart` — `insertBreaks`, breaks-for-trip
  query, delete-by-tripId (needed for use-cloud/merge break replacement).
- `lib/database/daos/trips_dao.dart` — `insertOrIgnoreTrips`, `updateTrip`
  (re-queue path), backfill query home.
- `lib/database/database.dart` — schema version; D-03 marker column needs a
  bump + snapshot + migration test.
- `lib/database/tables/user_preferences_table.dart` — single-row table hosting
  the D-03 version-keyed marker.
- `lib/config/constants.dart` — home for the breaks cap and marker version
  constant; no hardcoded values.

### Backend (deploys FIRST — roadmap SC2)
- `backend/functions/src/utils/validation.ts` — zod `tripSchema`; add the four
  fields as optional-with-defaults (non-strict schema currently strips unknown
  keys silently — the reason for the deploy ordering).
- `backend/functions/src/types/trip.ts` — `Trip`/`TripDoc` interfaces to extend.
- `backend/functions/src/handlers/sync-trips.ts`,
  `backend/functions/src/handlers/restore-trips.ts` — upsert + restore handlers
  that must round-trip the new fields losslessly.

### Auth seam (backfill trigger)
- `lib/features/auth/providers/auth_providers.dart` +
  `lib/features/auth/models/auth_state.dart` — the AuthSignedIn transition that
  Phase 24's auto-restore hooks; D-02 backfill rides the same seam.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SyncQueueDao.enqueueUpdate(tripId)` — the entire backfill mechanism: payloads
  are read fresh at sync time, so backfill is just "enqueue the matching ids
  once" and the new serializer does the rest.
- Phase 24's auth-transition listener (auto-restore trigger) — the exact seam
  D-02 reuses; compose so backfill and auto-restore don't fight on sign-in.
- `TripBreaksDao` (insert/query/delete by tripId) — everything restore and merge
  need to attach/replace break rows.
- Drift migration convention (version bump + snapshot + migration test) —
  established pattern for the D-03 marker column.
- Conflict-sheet widget test harness + `sync_engine_test.dart` fake clock /
  `FakeApiClient` patterns (from 25.1) — reuse for merge-function unit tests and
  backfill tests.

### Established Patterns
- Sealed classes for finite state (`RestoreState`, `SyncStatus`); no raw strings.
- Constants in `constants.dart`; camelCase wire keys mirroring the zod schema
  byte-for-byte; RFC-3339 UTC timestamps ending in `Z`.
- Fire-and-forget triggers, never block UI; errors map to sealed states, never
  leak `error.toString()` (PII guard).
- Backend: verify token → zod-validate → trust; one handler per file; strict TS.

### Integration Points
- `TripSerializer.toJson` call site in `api_client.syncTrips` — breaks must be
  fetched per trip before serialization (signature or call-path change).
- Restore download → (D-07-filtered) conflict detection → transactional
  insert+breaks for new trips, enrichment for existing default-metadata trips.
- Merge resolution (extracted pure function) → DAO update path → re-queue
  (Phase 24 D-06) with the winning side's breaks written via `TripBreaksDao`.
- Auth sign-in transition → marker check → backfill enqueue → normal queue drain.

</code_context>

<specifics>
## Specific Ideas

- User initially picked "re-upload all trips" for backfill scope, then on
  re-asking (after clarifying what "re-enqueue" means) settled on **any
  non-default metadata** — the recommended, need-based selection.
- User explicitly wants the merge sheet to *show* when breaks differ (chose the
  read-only indicator over an invisible ride-along) — visibility without new
  controls.
- Deploy ordering (backend before client) stays a process rule from roadmap SC2;
  the user did not select it for discussion — treat it as a hard sequencing
  constraint in the plan (backend plan/wave first, deploy verified before the
  client emits new fields).

</specifics>

<deferred>
## Deferred Ideas

- **Overlap-conflict UUID semantics** (carried from 25.1) — "Use Cloud"/merge on
  an `OverlapConflict` writes cloud fields into the local trip's UUID row; cloud
  copy stays under a different id and could re-conflict on future restores.
  Revisit if users report repeat conflicts.
- **"Highlight differing fields only" merge UI** (carried from 25.1) — polish
  candidate if the merge sheet gets attention later.

</deferred>

---

*Phase: 26-sync-breaks-edit-metadata-to-cloud*
*Context gathered: 2026-07-12*
