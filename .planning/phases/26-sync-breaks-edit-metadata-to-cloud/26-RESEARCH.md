# Phase 26: Sync Breaks & Edit Metadata to Cloud - Research

**Researched:** 2026-07-12
**Domain:** Drift↔Firestore payload extension (Dart client + TypeScript Cloud Functions), zod schema evolution, Drift transactional writes, Riverpod merge-flow refactor
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Backfill scope & trigger (roadmap SC4)
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

#### Breaks in the merge flow (roadmap SC5)
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

#### Breaks for existing trips on restore
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

### Deferred Ideas (OUT OF SCOPE)
- **Overlap-conflict UUID semantics** (carried from 25.1) — "Use Cloud"/merge on
  an `OverlapConflict` writes cloud fields into the local trip's UUID row; cloud
  copy stays under a different id and could re-conflict on future restores.
  Revisit if users report repeat conflicts.
- **"Highlight differing fields only" merge UI** (carried from 25.1) — polish
  candidate if the merge sheet gets attention later.

### Phase Boundary (from CONTEXT.md, for reference)

**In scope:** Extend the sync payload (`TripSerializer.toJson`) and Firestore
document with `totalPausedSeconds`, `isEdited`, `directionSource`, and an
embedded `breaks` array (bounded, e.g. max 50/trip); extend the zod `tripSchema`
and backend `Trip`/`TripDoc` types (all four optional with defaults); restore
parses the new fields and writes breaks into `trip_breaks` in the same
transaction as the trip insert; restore-time enrichment of existing local trips
whose metadata is empty/default (D-10, D-11); one-time backfill re-enqueue of
local trips with non-default metadata (D-01..D-03); merge-flow ride-along rules
for breaks/metadata + the deferred pure-function merge extraction (D-04..D-07);
backend deploys BEFORE any client that emits the new fields (roadmap SC2).

**Out of scope:** Per-break merge UI (SC5 locks: breaks ride along, never
merged per-segment); any continuous two-way sync (SYNC2-01, v2); reworking
conflict detection beyond excluding metadata fields (D-07); overlap-conflict
UUID semantics rework (still deferred from 25.1).
</user_constraints>


## Project Constraints (from CLAUDE.md)

These directives from `./CLAUDE.md` apply to this phase's plan and are treated
with the same authority as CONTEXT.md's locked decisions:

- **Drift is the only data source for UI / sync is one-way client→server.**
  "Never read from the server for normal app operation." This phase does NOT
  change that: restore is a deliberate, explicit exception (manual/auto restore
  flow), not a new server-read path for normal operation.
- **Never use the `cloud_firestore` SDK in the Flutter client.** All new
  fields flow through the existing `http` → HTTPS Cloud Functions →
  `TripSerializer` contract. No direct Firestore client access is introduced.
- **Never block UI on network.** The batch break lookup
  (`breaksForTripIds`) and the transactional restore write must stay on the
  existing fire-and-forget / async background paths (`SyncEngine`,
  `RestoreController`) — no synchronous network/DB calls on the UI thread.
- **Sealed classes / enums for finite state — never raw strings for state.**
  `RestoreState`, `SyncStatus` are already sealed and must stay that way; the
  4 new metadata fields themselves are plain data (not state), so this applies
  to any new control-flow state introduced (e.g. a backfill status), not to
  the wire fields.
- **No hardcoded values — all thresholds/labels/config go in
  `lib/config/constants.dart`.** The breaks-array cap, the backfill marker
  version, and any new copy strings (D-05 breaks indicator) must be added as
  named constants there, matching every existing example in that file.
- **Backend: verify token → validate (zod) → trust, no redundant checks
  deeper in the code.** The 4 new fields must be validated ONCE at the zod
  gate (`tripSchema`); handler code downstream should read them as trusted,
  typed values — matches the existing `sync-trips.ts`/`restore-trips.ts`
  pattern exactly.
- **Each Cloud Function handler is self-contained; one file per handler;
  shared utilities in `utils/`.** The `tripConverter` defaulting logic
  belongs in `backend/functions/src/utils/firestore.ts` (already the shared
  utility home), not duplicated into `sync-trips.ts`/`restore-trips.ts`.
- **Strict TypeScript, no `any` types.** The 4 new `TripDoc`/`Trip` interface
  fields must be fully typed (`number`, `boolean`, the 3-value directionSource
  union type, a typed `{startTime: string; endTime: string}[]` for breaks) —
  no `any`/untyped escape hatches.
- **Soft deletes everywhere; trips never hard-deleted from Firestore.**
  Unaffected by this phase — no delete-path changes.
- **Meaningful commit messages, prefixed by feature area.** This phase spans
  `[sync]` (client) and `[backend]` (Cloud Functions) — plan tasks should keep
  those prefixes distinct per commit, matching the two-tier wave structure
  Pitfall 6 already recommends for the deploy-ordering constraint.
- **No speculative abstractions — build only what's needed now.** The
  `merge_resolution.dart` extraction (D-06) is scoped to the CURRENT 5+4-field
  merge, not a generic "field merger" framework.

## Summary

This phase extends an existing, well-established sync pipeline rather than building anything new. The client already has `totalPausedSeconds`, `isEdited`, and `directionSource` as first-class `TripRow` columns (Phases 18/19/21) and a normalized `trip_breaks` table with a working DAO (`insertBreaks`/`breaksForTrip`/`deleteBreaksForTrip`). The backend already has a byte-for-byte camelCase wire contract (`TripSerializer.toJson` ↔ zod `tripSchema` ↔ `TripDoc`) and an established "verify → validate → trust" handler pattern. The work is almost entirely **additive plumbing**: join break rows into the serializer output, add four optional-with-default fields to the zod schema and `TripDoc`/`Trip` interfaces, extend the Firestore read/write mapping (`tripConverter` for reads, `sync-trips.ts`'s literal doc-object build for writes), wrap the restore insert-plus-breaks in a transaction (a pattern already used twice in this codebase — trip finalize and trip edit), and reuse the existing auth-transition auto-restore seam (`MainShell._MainShellState` in `lib/features/shell/main_shell.dart`) for the one-time backfill trigger.

The single most important sequencing fact, confirmed by reading `sync-trips.ts`/`restore-trips.ts`/`tripConverter`: **Firestore reads already funnel through one converter function** (`tripConverter.fromFirestore` in `backend/functions/src/utils/firestore.ts`), which already defensively coerces old/malformed data (see `toIsoString`/`toNullableTimestamp`). This is the exact, pre-existing seam where "old docs without the new fields restore cleanly with defaults" (SC4) belongs — extend the same field-by-field `?? default` pattern, not the zod schema (zod only validates inbound `POST /trips/sync` bodies; it plays no role in the `GET /trips/restore` read path).

**Primary recommendation:** Extend `TripSerializer.toJson`/`fromJson`, `tripSchema`, `Trip`/`TripDoc`, `tripConverter.fromFirestore`, and the sync-trips write-object literal in lockstep, mirroring the existing byte-for-byte camelCase contract exactly. Add a `TripBreaksDao.breaksForTripIds(List<String>)` batch-read method to avoid N+1 queries in the sync engine's per-chunk upload loop. Reuse `AppDatabase.transaction()` (already used in `TrackingServiceController.persistFinalizedTrip` and `TripManagementNotifier.editTrip`) for the restore insert-plus-breaks write. Reuse the `MainShell` `ref.listen<AuthState>` seam for the backfill trigger, guarded by a new version-keyed `user_preferences` marker column (schema v6→v7).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Break-row → wire-JSON join | Frontend Server (SSR-equivalent: `lib/sync/`) | Database / Storage (Drift) | `TripSerializer.toJson` is a pure function today; it needs a per-trip breaks list passed in, sourced by a new batch DAO query, not a schema change |
| zod schema evolution | API / Backend | — | `tripSchema` is the single inbound validation gate; owns default-filling for absent keys on write |
| Firestore read defaulting | API / Backend | Database / Storage (Firestore) | `tripConverter.fromFirestore` is the existing seam that already coerces malformed/legacy data; extend it, don't add defaulting logic in the handler |
| Restore transactional write (trip + breaks) | Frontend Server (Drift local DB, `lib/sync/restore_controller.dart`) | Database / Storage (Drift) | Mirrors the existing `TrackingServiceController`/`TripManagementNotifier` transaction pattern — insert parent row then children, atomic |
| Backfill trigger | Browser / Client (Riverpod listener in `MainShell`) | Database / Storage (`user_preferences` marker) | Same seam Phase 24's auto-restore already uses; marker persistence lives in the single-row prefs table |
| Merge-flow ride-along rules | Browser / Client (`conflict_resolution_sheet.dart` → extracted pure function) | — | Pure Dart function, unit-testable without widget harness — D-06 mandates the extraction first |
| Conflict-detection field exclusion | Browser / Client (`restore_controller.dart._isDifferent`) | — | Local, in-memory comparison; no backend involvement |

## Standard Stack

No new libraries are introduced by this phase. Every dependency below is already pinned in the project.

### Core (unchanged, verified in place)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| drift | ^2.32.1 | Local SQLite, transactional writes | `[VERIFIED: pubspec.yaml]` Already the sole local persistence layer; `AppDatabase.transaction()` already used for exactly this atomic-parent-plus-children pattern |
| drift_dev | ^2.32.1 | Schema dump/generate/migration test scaffolding | `[VERIFIED: pubspec.yaml]` The 3-command migration ceremony is already established (see Code Examples) |
| zod | ^4.4.3 | Backend request validation | `[VERIFIED: backend/functions/package.json]` Zod 4's `.default()` semantics differ materially from v3 — see Pitfall 1 |
| firebase-admin | ^13.10.0 | Firestore Admin SDK, typed converter | `[VERIFIED: backend/functions/package.json]` `tripConverter` (FirestoreDataConverter) is the existing typed read/write boundary |
| jest / ts-jest | ^30.4.2 / ^29.4.11 | Backend test runner | `[VERIFIED: backend/functions/package.json]` Two jest "projects": `unit` (fast, no emulator) and integration (emulator-backed, via `firebase emulators:exec`) |
| flutter_riverpod | ^3.x (Notifier/NotifierProvider) | State management | `[VERIFIED: existing code]` `RestoreController`, `SyncEngine` providers, `MainShell` listener all follow the established manual-provider (no `@riverpod` codegen) convention |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Embedded `breaks` array on the trip doc | A `trips/{id}/breaks` Firestore subcollection | Roadmap SC1 explicitly locks the embedded-array shape (bounded, max ~50) — a subcollection would need N extra reads/writes per trip and break the single-document atomicity the rest of sync relies on. Not applicable here. |
| Defaulting in `tripConverter.fromFirestore` | Defaulting in the handler (`restoreTripsHandler`) | The converter already owns exactly this responsibility (`toIsoString`, `toNullableTimestamp`) for other fields — putting defaults in the handler would split the defensive-coercion logic across two files for no benefit. |
| `TripBreaksDao.breaksForTripIds` batch query | N calls to `breaksForTrip(tripId)` in a loop | N+1 query pattern inside the chunked upload loop (`api_client.syncTrips` batches up to `kMaxSyncBatchTrips`=1000 trips per POST, chunked at 500 server-side) — a per-trip DB round trip per batch item is wasteful for a local SQLite call but still worth avoiding on principle and consistency with `breaksForTrip`'s existing ordered-by-startTime contract. |

**Installation:** None — no `pubspec.yaml` or `package.json` changes required.

## Architecture Patterns

### System Architecture Diagram

```
UPLOAD PATH (SyncEngine._drain → ApiClient.syncTrips)
──────────────────────────────────────────────────────
SyncQueueDao.getPending()
        │
        ▼
TripsDao.findById(tripId)  ──►  liveTrips: List<TripRow>
        │
        ▼
[NEW] TripBreaksDao.breaksForTripIds(liveTrips.map(id))  ──► Map<String, List<TripBreakRow>>
        │
        ▼
chunk (kMaxSyncBatchTrips)
        │
        ▼
[NEW] TripSerializer.toJson(trip, breaksForTrip[trip.id])
        │   {...existing 11 fields, totalPausedSeconds, isEdited,
        │    directionSource, breaks: [{startTime,endTime}, ...]}
        ▼
ApiClient.syncTrips(chunk)  ──HTTP POST /trips/sync──►  Cloud Function
                                                              │
                                                              ▼
                                                   verifyAuth(req) [401 gate]
                                                              │
                                                              ▼
                                              syncTripsBody.safeParse(req.body)
                                              [NEW fields .default()-filled]
                                                              │
                                                              ▼
                                              literal TripDoc build (forces
                                              userId, deleted:false) — [NEW]
                                              spreads the 4 new fields through
                                                              │
                                                              ▼
                                              Firestore batch.set(merge:true)


RESTORE PATH (GET /trips/restore → RestoreController.restore)
──────────────────────────────────────────────────────────────
Firestore query (userId == uid && deleted == false)
        │
        ▼
[EXISTING, extend] tripConverter.fromFirestore
   — old docs: missing keys → ?? defaults (0 / false / 'time' / [])
        │
        ▼
restoreTripsHandler: project TripDoc → Trip (strip server metadata)
        │  now includes totalPausedSeconds/isEdited/directionSource/breaks
        ▼
ApiClient.restoreTrips()  ──►  List<TripsCompanion>  [NEW: breaks carried
                                 alongside, not yet in TripsCompanion shape —
                                 see Pattern 2]
        │
        ▼
RestoreController.restore()
        │
        ├─ same-UUID? → _isDifferent() [D-07: 4 metadata fields EXCLUDED]
        │       │
        │       ├─ different (non-metadata) → conflict → ConflictResolutionSheet
        │       │        └─ merge: extracted pure fn (D-06) — breaks/
        │       │           totalPausedSeconds ride the time-fields winner (D-04)
        │       │
        │       └─ same → [NEW D-10/D-11] enrichment: local metadata
        │                 default/empty + cloud has real value → adopt cloud's
        │
        └─ no local match → [NEW] db.transaction(insert trip; insert breaks)
                             (mirrors TrackingServiceController pattern)
```

### Recommended Project Structure

No new files/directories. All work lands in existing files:
```
lib/sync/
├── trip_serializer.dart        # toJson/fromJson gain the 4 fields + breaks join/parse
├── sync_engine.dart             # _drain: batch-fetch breaks before serializing a chunk
├── api_client.dart               # syncTrips signature may need trip+breaks pairing
├── restore_controller.dart      # transactional insert-with-breaks, D-10/D-11 enrichment
├── restore_conflict.dart        # (no change — RestoreConflict shape is fine as-is)
└── merge_resolution.dart        # [NEW, per D-06] extracted pure merge function

lib/features/settings/widgets/
└── conflict_resolution_sheet.dart  # calls extracted fn; adds D-05 breaks indicator row

lib/database/
├── tables/trips_table.dart       # no change (columns already exist)
├── tables/trip_breaks_table.dart # no change
├── tables/user_preferences_table.dart  # [NEW] backfillMarkerVersion column
├── daos/trip_breaks_dao.dart     # [NEW] breaksForTripIds(List<String>) batch method
├── daos/user_preferences_dao.dart # [NEW] getter/setter for the marker
└── database.dart                 # schemaVersion 6 → 7, new onUpgrade branch

lib/features/auth/... (no change — MainShell listener is the seam, not auth code)
lib/features/shell/main_shell.dart  # [NEW] backfill call alongside _runAutoRestore

lib/config/constants.dart         # [NEW] kBreaksMaxPerTrip, kBackfillMarkerVersion, etc.

backend/functions/src/
├── utils/validation.ts           # tripSchema gains 4 fields with .default()
├── types/trip.ts                 # Trip/TripDoc interfaces gain 4 fields
├── utils/firestore.ts            # tripConverter.fromFirestore defaults the 4 fields
├── handlers/sync-trips.ts        # doc literal spreads the 4 new fields
└── handlers/restore-trips.ts     # Trip projection spreads the 4 new fields
```

### Pattern 1: Atomic parent+children write (already established twice)

**What:** Insert the parent `trips` row, then insert `trip_breaks` rows for it, inside one `AppDatabase.transaction()`. If anything throws, both roll back.

**When to use:** Any write path that creates/replaces a trip's break segments — restore-insert (new), finalize (existing), full-edit (existing).

**Example (existing code, `lib/features/tracking/services/tracking_service_controller.dart:252-279`):**
```dart
// Source: lib/features/tracking/services/tracking_service_controller.dart
await _database.transaction(() async {
  await _tripsDao.insertTrip(TripsCompanion.insert(/* ... */));
  final breakRows = _breakRowsFor(trip);
  if (breakRows.isNotEmpty) {
    await _tripBreaksDao.insertBreaks(breakRows);
  }
  await _syncQueueDao.enqueueCreate(trip.id);
});
```
The restore path (`RestoreController.restore()`) should follow this exact shape: insert the trip via `TripsDao.insertTrip` (not the existing batch `insertOrIgnoreTrips`, which has no seam for per-trip break inserts — batch insert of N trips would need N sub-transactions, one per non-conflicting cloud trip that carries breaks — OR keep the fast batch path for trips with no breaks and fall back to per-trip transactions only for trips with breaks. This is a genuine plan-time design decision — see Open Questions).

### Pattern 2: Firestore read-side defaulting lives in the typed converter, not the handler

**What:** `tripConverter.fromFirestore` (backend/functions/src/utils/firestore.ts) is the single point where every `trips` document read is mapped from raw `DocumentData` to the typed `TripDoc`. It already defends against missing/malformed data for existing fields (`toIsoString`, `?? null` for `routePolyline`).

**When to use:** SC4 ("trips already in Firestore without the new fields restore cleanly with defaults") — implement here, not as ad-hoc `??` in `restoreTripsHandler`.

**Example (extend the existing pattern):**
```typescript
// Source: backend/functions/src/utils/firestore.ts (existing function, extend the return object)
fromFirestore: (snapshot: QueryDocumentSnapshot): TripDoc => {
  const data = snapshot.data();
  return {
    // ...existing 11 fields unchanged...
    totalPausedSeconds: (data.totalPausedSeconds as number | undefined) ?? 0,
    isEdited: (data.isEdited as boolean | undefined) ?? false,
    directionSource: (data.directionSource as string | undefined) ?? 'time',
    breaks: (data.breaks as { startTime: string; endTime: string }[] | undefined) ?? [],
    deleted: data.deleted as boolean,
    deletedAt: toNullableTimestamp(data.deletedAt),
    serverUpdatedAt: /* ...unchanged... */,
  };
},
```
`restoreTripsHandler`'s existing field-by-field `Trip` projection then just adds the 4 fields — it never needs its own defaulting logic because the converter already guarantees non-undefined values.

### Pattern 3: zod `.default()` on Zod 4 (this repo's pinned version) fills absent keys, not just `undefined` values

**What:** Zod 4 changed `.default()` semantics from Zod 3. In this repo's pinned `zod ^4.4.3`, `.default(x)` alone makes the field optional in the *input* type AND supplies `x` in the *parsed output* whenever the key is absent (or explicitly `undefined`) — no `.optional()` needed.

**Example:**
```typescript
// Source: Context7 /websites/zod_dev_v4 (verified against zod 4 changelog)
export const tripSchema = z.object({
  // ...existing 11 fields unchanged...
  totalPausedSeconds: z.number().int().nonnegative().default(0),
  isEdited: z.boolean().default(false),
  directionSource: z.enum(['manual', 'geofence', 'time']).default('time'),
  breaks: z
    .array(
      z.object({
        startTime: z.string().datetime(),
        endTime: z.string().datetime(),
      }),
    )
    .max(kMaxBreaksPerTrip) // e.g. 50
    .default([]),
});
```
`z.object({...}).safeParse({...no breaks key...})` on this schema yields `{ ..., breaks: [] }` in `parsed.data` — the sync-trips handler's write-object literal can then unconditionally read `trip.breaks` with no additional `??` needed on the write path (defaulting already happened in validation). This is `[CITED: Context7 /websites/zod_dev_v4]`.

### Anti-Patterns to Avoid
- **Defaulting missing fields in the zod schema for the restore/read path:** zod (`tripSchema`) only runs on `POST /trips/sync` request bodies. It is never invoked on `GET /trips/restore` — that path reads raw Firestore documents through `tripConverter`. Do not add a zod parse to the restore handler "for safety"; it duplicates the converter's job and diverges from the established single-defaulting-point pattern.
- **N calls to `TripBreaksDao.breaksForTrip(tripId)` inside the sync engine's chunk loop:** each call is a separate `SELECT ... WHERE trip_id = ?` — for a `kMaxSyncBatchTrips`-sized batch this is N round trips to local SQLite per drain. Add a batch method (`breaksForTripIds(List<String>)`) that does one `WHERE trip_id IN (...)` query and returns a `Map<String, List<TripBreakRow>>`.
- **Re-implementing "insert trip, insert breaks" outside `db.transaction()`:** a crash/exception between the two inserts would leave a trip with an inconsistent `totalPausedSeconds` (nonzero) but zero break rows — exactly the SC3 failure mode the roadmap calls out ("paused time recomputing to zero" on next edit, since the edit sheet reads `trip_breaks` fresh via `TripBreaksDao.breaksForTrip`, `lib/features/trips/screens/trip_detail_screen.dart:92`).
- **Adding per-break merge controls to `ConflictResolutionSheet`:** explicitly out of scope (SC5, D-05). The sheet gets a read-only text indicator only.
- **Skipping the D-06 merge-function extraction and bolting D-04 ride-along logic directly onto `_applyAll`:** the user's decision (D-06) is explicit and sequenced — extract first, pin with unit tests, THEN add ride-along rules. This keeps the (currently un-unit-tested, widget-test-only) merge logic testable without a widget harness.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic trip+breaks write | Manual two-step insert with try/catch rollback | `AppDatabase.transaction(() async {...})` | Drift's transaction already provides real rollback semantics; the pattern is proven twice in this codebase (finalize, edit) |
| Batch break lookup | Loop of `breaksForTrip(id)` calls | New `breaksForTripIds(List<String>)` DAO method with a single `.. where((b) => b.tripId.isIn(ids))` query | Standard Drift `isIn` predicate; avoids N+1 |
| Schema migration test scaffolding | Hand-written SQL fixtures asserting column existence | `drift_dev schema dump` + `schema generate` + `SchemaVerifier.migrateAndValidate()` | Already the established convention (v2→v3 through v5→v6 all use this); hand-written migration tests are the #1 way to ship a broken migration (see `01-RESEARCH.md`) |
| "Which fields differ" conflict detection | New comparison utility | Extend the existing `RestoreController._isDifferent` — just don't add cases for the 4 metadata fields | The method already exists and is unit-testable; D-07 is a *subtraction* (exclude 4 fields), not a new comparator |
| Optional-with-default JSON parsing | Manual `json.containsKey('breaks') ? ... : []` checks scattered across call sites | Zod `.default()` (backend inbound) + explicit `?? default` in `tripConverter.fromFirestore` (backend outbound) + `json['breaks'] as List<dynamic>? ?? const []` in `TripSerializer.fromJson` (client inbound) | One defaulting point per direction, matching the existing pattern for `routePolyline` (`Value<String?>`) |

**Key insight:** Every piece of this phase has a direct structural precedent already in the codebase (Phase 18's break persistence, Phase 19's transactional edit, Phase 21's additive migration, Phase 24's auto-restore listener, the existing `tripConverter` defensive-read pattern). The planning risk here is *not* algorithmic — it's keeping the four new fields threaded correctly through eight call sites (serializer×2, zod, 2 TS interfaces, converter, 2 handlers) without a byte-for-byte mismatch, and getting the transaction boundaries right for D-10/D-11 enrichment vs. new-trip insert vs. merge-resolution.

## Common Pitfalls

### Pitfall 1: Zod 3 vs Zod 4 `.default()` semantics — do not copy Zod 3 patterns from memory
**What goes wrong:** Assuming `.default(x)` requires an explicit `.optional()` to make the input key absent-safe, or assuming a default nested inside `.optional()` is *not* applied when the key is missing (Zod 3 behavior).
**Why it happens:** Most zod tutorials/training data predate the v4 changelog. This repo is pinned to `zod ^4.4.3`.
**How to avoid:** Use `.default(x)` alone (no `.optional()` needed) for each of the 4 new fields; verified via Context7 `/websites/zod_dev_v4` changelog excerpt (see Pattern 3).
**Warning signs:** A validation test asserting `tripSchema.safeParse({ ...no breaks key })` produces `success: true` but `parsed.data.breaks === undefined` instead of `[]` — that would indicate a v3-style assumption crept in.

### Pitfall 2: `insertOrIgnoreTrips`'s batch-insert path has no seam for per-trip child rows
**What goes wrong:** The existing dedupe-by-UUID restore path (`TripsDao.insertOrIgnoreTrips`) inserts N trip companions in ONE `batch()` call for performance/jank reasons (Phase 11, D-08/MEDIUM-3). There is no hook to also insert each trip's break rows inside that same batch — Drift's `batch()` API supports multiple table inserts in one batch, but the current call site only touches `trips`.
**Why it happens:** Batch insert was designed before breaks existed; extending it to interleave `trips` + `trip_breaks` inserts per companion, still inside `InsertMode.insertOrIgnore` semantics, needs explicit plan-time design — is it one `batch()` call touching two tables (fine, Drift batches support this), or does insertOrIgnore's "silently skip existing rows" semantics create an orphan-break risk if a trip row is skipped but its breaks batch-insert unconditionally?
**How to avoid:** The plan should split the restore batch write into a single `batch((b) { b.insertAll(trips, ..., mode: insertOrIgnore); b.insertAll(tripBreaks, ..., mode: insertOrIgnore); })` — BUT only for trips whose id was not already present locally (precompute via the existing `localById` lookup already built in `RestoreController.restore()`), so a trip that gets silently skipped by `insertOrIgnore` never gets its breaks force-inserted (FK would still succeed since the trip DOES exist locally under that id from an EARLIER write — but the local trip's breaks would then be silently overwritten/duplicated). Recommend: compute `nonConflictTripIds`, batch-insert trips normally, THEN batch-insert breaks ONLY for the subset of `nonConflictTripIds` that are genuinely new (post-batch count delta is already computed — but per-id "was this one actually inserted" isn't; may need to switch strategy to per-id insert-or-skip check before this phase, OR accept that a coincidental existing-row-with-different-content is already an accepted edge case per the "client-authoritative, existing rows never overwritten" design and simply always batch-insert breaks for trips being restored — since `insertOrIgnore` protects the trip row, and orphaned breaks for a trip that already existed locally would violate the "local wins" principle). **This needs an explicit decision at plan time — flagged as Open Question 1.**

### Pitfall 3: `TripSerializer.toJson` is currently a pure, single-argument, static function — every call site assumes that signature
**What goes wrong:** `api_client.dart:132` does `trips.map(TripSerializer.toJson).toList()` — a direct tearoff. Changing `toJson`'s signature to `(TripRow, List<TripBreakRow>)` breaks this direct map-tearoff; it needs to become `trips.map((t) => TripSerializer.toJson(t, breaksByTripId[t.id] ?? const [])).toList()`, and `syncTrips`'s signature likely needs to accept the breaks map (or `List<(TripRow, List<TripBreakRow>)>` / a small wrapper record) rather than just `List<TripRow>`.
**Why it happens:** Breaks are normalized (Phase 18, D-01: "not a JSON blob on trips") specifically so Phase 19's editing could target individual segments — this phase now needs to DENORMALIZE them back into the wire payload, which is a legitimate but easy-to-under-scope signature change rippling through `SyncEngine._drain`, `ApiClient.syncTrips`, and every existing unit test that constructs `List<TripRow>` fixtures for these two.
**How to avoid:** Plan explicitly for the signature change and its test-fixture ripple (grep shows `sync_engine_test.dart` and `restore_controller_test.dart` — and the possibly-stale `test/sync/restore_controller_test.dart`, see Pitfall 5 — all construct fixtures against the current shapes).
**Warning signs:** Compile errors in `test/unit/sync/sync_engine_test.dart` and `test/unit/sync/restore_controller_test.dart` after the signature change — expected and should be fixed as part of this phase's Wave 0/plan, not treated as an unrelated regression.

### Pitfall 4: The `directionSource` wire value must be validated as an enum, not a free string, but the client uses raw string constants
**What goes wrong:** `directionSource` on the Dart side is a raw `String` column with three literal constants (`kDirectionSourceManual`/`Geofence`/`Time` = `'manual'`/`'geofence'`/`'time'`, `lib/config/constants.dart`). The backend zod schema must mirror these exactly as a `z.enum(['manual', 'geofence', 'time'])` — a typo or reordering desyncs client and server silently (a valid client value gets rejected with a 400, which SyncEngine then treats as a non-retryable poison pill, permanently stuck).
**How to avoid:** Reference the literal Dart constant values directly in the zod enum definition's comment/test, and add a backend unit test asserting all three client-side literal strings round-trip through `tripSchema.safeParse`.
**Warning signs:** A previously-working trip suddenly gets `markFailed` (non-retryable) on sync after this phase ships — check `directionSource` value against the zod enum first.

### Pitfall 5: Two `restore_controller_test.dart` files exist in the test tree
**What goes wrong:** `test/sync/restore_controller_test.dart` (182 lines) and `test/unit/sync/restore_controller_test.dart` (280 lines) both exist and are NOT identical — the former appears to predate the project's `test/unit/`/`test/widget/`/`test/integration/` reorganization (see `01-RESEARCH.md`'s structure) and may be stale/superseded.
**Why it happens:** Leftover from an earlier test-tree layout that wasn't cleaned up when the DAO/controller tests were moved under `test/unit/`.
**How to avoid:** Before editing restore-controller tests for this phase, `flutter test test/sync/restore_controller_test.dart` to check if it still passes/compiles against current code; if it's stale/duplicate, flag for removal as part of this phase's cleanup rather than maintaining two divergent copies of restore-flow tests.
**Warning signs:** Editing `RestoreController` for D-10/D-11 breaks one file's tests but not the other's, or `flutter test` reports duplicate test names.

### Pitfall 6: Backend deploy-before-client ordering (SC2) is a process constraint, not a code constraint — plan the WAVES accordingly
**What goes wrong:** Nothing in the code enforces deploy ordering; it's entirely a plan-sequencing concern. If a plan generates client-emitting-new-fields tasks in the same wave as backend-schema tasks with no explicit "deploy + verify" gate between them, a real device/CI run could sync new-field payloads against the OLD deployed backend, whose non-strict zod schema `z.object({...})` (not `.strict()`) will *silently strip unknown keys* rather than reject them — so `breaks`/`totalPausedSeconds`/`isEdited`/`directionSource` sent by a not-yet-deployed-matching client would be silently dropped, defeating the entire phase, with no error surfaced anywhere.
**How to avoid:** Structure the plan as backend wave(s) → explicit `firebase deploy --only functions` + verification step → client wave(s). This mirrors the existing Phase 10→11 relationship (backend was a separate phase from the client sync engine) and matches the `Deploy ordering (backend before client) stays a process rule from roadmap SC2` note already captured in CONTEXT.md's Specifics section.
**Warning signs:** None will be visible in code review — this is a plan/wave-structure risk, not a code risk. The planner must encode the ordering as a phase-dependency-style gate between waves.

## Code Examples

### Batch break lookup (new DAO method, mirrors `breaksForTrip`'s existing query shape)
```dart
// Pattern based on: lib/database/daos/trip_breaks_dao.dart (existing breaksForTrip)
Future<Map<String, List<TripBreakRow>>> breaksForTripIds(List<String> tripIds) async {
  if (tripIds.isEmpty) return {};
  final rows = await (select(tripBreaks)
        ..where((b) => b.tripId.isIn(tripIds))
        ..orderBy([(b) => OrderingTerm.asc(b.startTime)]))
      .get();
  final map = <String, List<TripBreakRow>>{};
  for (final row in rows) {
    map.putIfAbsent(row.tripId, () => []).add(row);
  }
  return map;
}
```

### Migration ceremony (exact commands used for every prior schema bump, e.g. Phase 21's v5→v6, `.planning/phases/21-home-office-locations-geofence/21-01-PLAN.md:167-168`)
```bash
# Source: .planning/phases/21-home-office-locations-geofence/21-01-PLAN.md
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/database/database.dart drift_schemas/drift_schema_v7.json
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```
The new `onUpgrade` branch in `lib/database/database.dart` follows the exact shape of the `from < 6 && to >= 6` branch already there — additive `m.addColumn(userPreferences, userPreferences.<newMarkerColumn>)`, no UPDATE/DROP of existing rows.

### zod schema extension (Zod 4 semantics — see Pitfall 1)
```typescript
// Source: backend/functions/src/utils/validation.ts (existing file, extend tripSchema)
export const kMaxBreaksPerTrip = 50;

const tripBreakSchema = z.object({
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
});

export const tripSchema = z.object({
  // ...existing 11 fields...
  totalPausedSeconds: z.number().int().nonnegative().default(0),
  isEdited: z.boolean().default(false),
  directionSource: z.enum(['manual', 'geofence', 'time']).default('time'),
  breaks: z.array(tripBreakSchema).max(kMaxBreaksPerTrip).default([]),
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Trip metadata (breaks/paused/edited/direction-source) lives ONLY in Drift, never synced | Same metadata mirrored to Firestore for lossless restore | This phase (26) | A device wipe/reinstall after this phase preserves the full v0.3 editing history, not just the v0.1 trip skeleton |
| `tripSchema` is a flat, all-required-except-`userId` object | Adds four `.default()`-backed optional fields | This phase (26) | Establishes the pattern for future additive wire-contract changes (schema evolution without breaking old clients) — worth documenting as a convention for future phases |
| `TripSerializer.toJson`/`fromJson` operate on `TripRow` alone | Operate on `(TripRow, List<TripBreakRow>)` (or equivalent) | This phase (26) | First cross-table join in the serializer; sets precedent if a future phase needs to sync another normalized child table |

**Deprecated/outdated:** None — this phase only adds fields additively; nothing in the existing contract is removed or changed in meaning.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The restore batch-insert strategy for trips WITH breaks needs a per-trip (not bulk) transaction, splitting the existing single-batch `insertOrIgnoreTrips` fast path from a new breaks-aware path | Pitfall 2 / Open Questions | If wrong, either breaks get orphaned/duplicated on restore, or the bulk-insert performance win is lost for all restores (not just ones with breaks) — plan-time design decision, not verified against actual Drift `batch()` multi-table semantics in this session |
| A2 | `test/sync/restore_controller_test.dart` is a stale duplicate of `test/unit/sync/restore_controller_test.dart` and safe to remove/ignore | Pitfall 5 | If it's actually still wired into CI and NOT a duplicate, deleting/ignoring it could silently drop test coverage — verify by running both files before touching restore controller tests |
| A3 | Firestore document size (existing 100k-char routePolyline cap + up to 50 embedded breaks) stays comfortably under the 1 MiB Firestore document cap | Standard Stack / Alternatives Considered | Low risk — this is arithmetic (≈100KB polyline + ≈4KB breaks array, both well under 1,048,576 bytes), not a verified-via-docs claim, but the margin is large enough that a wrong estimate by 10x would still be safe |

## Open Questions

1. **Restore batch-insert strategy for trips with breaks (Pitfall 2 / A1)**
   - What we know: `TripsDao.insertOrIgnoreTrips` does one `batch()` insert for ALL non-conflicting cloud trips (fast, jank-free); `TripBreaksDao.insertBreaks` does one `batch()` insert for a SINGLE trip's break list; no code path currently combines "N trips + each trip's breaks" atomically.
   - What's unclear: Whether the plan should (a) always split into per-trip transactions when the cloud trip carries `breaks`, keeping the fast bulk path only for breakless trips, or (b) restructure to one `batch()` call touching both `trips` and `tripBreaks` tables for the entire non-conflict set (Drift's `batch()` supports multiple tables in one batch — needs verification against the Drift API before committing to this in a plan).
   - Recommendation: Plan should spike/verify `Batch.insertAll` across two tables in one `batch()` call (should work per Drift's API — `BatchInsert` targets a specific table per call within the same batch closure) before deciding; this determines whether restore stays a single atomic operation or becomes two-phase (bulk trips, then per-trip breaks).

2. **`insertOrIgnoreTrips`'s "silently skip existing id" semantics vs. breaks for a skipped trip**
   - What we know: If a cloud trip's UUID already exists locally (but was NOT flagged as a same-UUID conflict because `_isDifferent` returned false — i.e., all fields including the excluded metadata fields happen to match, or metadata differs but D-07 excludes it from conflict detection), it currently gets silently skipped by `insertOrIgnore`.
   - What's unclear: For D-10/D-11 enrichment ("local has no breaks, cloud does → adopt cloud's"), this is exactly the "same-UUID, no conflict flagged" case — enrichment must run as a SEPARATE code path from `insertOrIgnoreTrips` (which never overwrites), likely alongside/inside the existing `_isDifferent`-false branch of `RestoreController.restore()`, which today does nothing (implicitly treated as "already up to date, don't touch").
   - Recommendation: Plan should add an explicit third branch (today there are only "conflict" and "non-conflict/new") for "same UUID, not flagged as conflict, but has enrichable metadata" — the D-10/D-11 write goes through `TripsDao.updateTrip` + `TripBreaksDao.insertBreaks` inside a transaction, NOT through the bulk `insertOrIgnoreTrips` path.

3. **Whether D-10/D-11 enrichment writes should re-enqueue for upload (Claude's discretion, deferred to plan time per CONTEXT.md)**
   - What we know: CONTEXT.md explicitly defers this to "pick the cleaner path" — either bypass sync_queue (since the enriched local row now matches cloud exactly, re-upload is redundant) or go through the normal `updateTrip`-triggers-`enqueueUpdate` path used everywhere else for consistency.
   - What's unclear: No code precedent settles this either way; `TripManagementNotifier.editTrip` always enqueues, but that's a user-facing edit, not a background sync reconciliation. Note also: contrary to CONTEXT.md's canonical-refs note that "cloud overwrites go through the DAO update path so rows re-queue (Phase 24 D-06)", this session's direct read of `ConflictResolutionSheet._applyAll` shows the `kConflictUseCloud`/merge branches call `tripsDao.updateTrip(companion)` alone, with NO accompanying `enqueueUpdate` call — i.e. cloud-overwrite conflict resolutions do NOT currently re-queue for upload. `updateTrip` itself never auto-enqueues (grepped: every `enqueueUpdate`/`enqueueCreate` call site in the codebase is an explicit, separate DAO call alongside the write, never a trigger).
   - Recommendation: Bypass the sync queue for D-10/D-11 enrichment writes (call `TripsDao.updateTrip` + `TripBreaksDao.insertBreaks` directly, no `enqueueUpdate`) — this is both the "cleaner path" per CONTEXT.md's discretion note AND consistent with the ACTUAL (not documented) behavior of the existing `kConflictUseCloud` branch. Flag the Phase 24 CONTEXT.md discrepancy for plan-time awareness — it does not block this phase, but the planner should not assume conflict-resolution writes currently re-queue.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter/Dart SDK | Client-side plan waves | ✓ | Flutter 3.41.6 / Dart 3.11.4 | — |
| Node.js | Backend build/test | ✓ | v25.2.1 (engines pins 20 — nvm/volta not verified but `node` on PATH resolves) | — |
| Firebase CLI | Backend deploy + emulator-backed integration tests | ✓ | 15.19.0 | — |
| Java (JRE) | Firebase emulator suite (Firestore/Auth emulators) | ✓ | 26+35 | — |
| npm | Backend dependency install/test | ✓ (bundled with Node) | — | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None — all tooling required for this phase (Dart/Flutter for client waves, Node/Firebase CLI/Java for backend waves + emulator-backed integration tests) is present and verified in this environment.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Client framework | `flutter_test` (unit/widget), `drift_dev`'s `SchemaVerifier` (migration) |
| Client config | `test/generated_migrations/schema.dart` (drift_dev-generated helper) |
| Backend framework | Jest 30 (`jest.config.js`, two projects: `unit` — no emulator, and default — emulator-backed via `firebase emulators:exec`) |
| Backend config | `backend/functions/package.json` scripts: `test` (full emulator suite), `test:unit` (fast, `--selectProjects unit`) |
| Quick run (client) | `flutter test test/unit/sync/ test/unit/database/` |
| Quick run (backend) | `cd backend/functions && npm run test:unit` |
| Full suite (client) | `flutter test` |
| Full suite (backend) | `cd backend/functions && npm test` (spins up Firestore + Auth emulators — Java required, confirmed available) |

### Phase Requirement → Test Map

No REQUIREMENTS.md IDs are mapped to Phase 26 (roadmap traceability table has no row for it — "TBD in roadmap" per the phase description). Success criteria from the roadmap map to tests as follows:

| Success Criterion | Behavior | Test Type | Automated Command | File Exists? |
|--------------------|----------|-----------|-------------------|-------------|
| SC1 (payload/schema shape) | `tripSchema` accepts all 4 new optional fields with defaults; old clients still sync | unit | `cd backend/functions && npx jest --selectProjects unit utils/__tests__/validation.test.ts` | ❌ Wave 0 — extend existing `validation.test.ts` |
| SC1 (client wire contract) | `TripSerializer.toJson`/`fromJson` round-trip the 4 new fields + breaks | unit | `flutter test test/unit/sync/trip_serializer_test.dart` | ❌ Wave 0 — no `trip_serializer_test.dart` found this session; verify/create |
| SC2 (deploy ordering) | Not directly testable in CI — process/plan-sequencing gate | manual-only | N/A — enforced by wave structure, not a test | N/A |
| SC3 (restore-then-edit preserves breaks) | A restored trip with breaks, when opened in the edit sheet, shows non-zero paused time and the correct break list | integration (client) | `flutter test test/unit/sync/restore_controller_test.dart` (new cases) + existing `trip_edit_recompute` tests | ❌ Wave 0 — new cases |
| SC4 (old-doc restore defaults cleanly) | `tripConverter.fromFirestore` on a doc missing the 4 fields returns defaults, no throw | integration (backend, emulator) | `cd backend/functions && npm test -- test/handlers/restore-trips.test.ts` | ❌ Wave 0 — extend existing `restore-trips.test.ts` (uses `seedTrip` helper — verify it can seed a doc WITHOUT the new fields to simulate a legacy doc) |
| SC4 (backfill re-enqueues) | Local trips with non-default metadata get re-enqueued exactly once after the marker-guarded auth transition | unit | `flutter test test/unit/database/user_preferences_dao_test.dart` (marker) + new backfill service test | ❌ Wave 0 — new backfill logic has no home file yet |
| SC5 (merge ride-along, no per-break UI) | Extracted merge function: breaks/totalPausedSeconds follow the time-field winner; conflict sheet shows read-only indicator when breaks differ | unit (merge fn) + widget (indicator) | `flutter test test/unit/sync/merge_resolution_test.dart` (new) + `flutter test test/widget/features/settings/conflict_resolution_sheet_test.dart` | ❌ Wave 0 — `merge_resolution.dart`/test do not exist yet (D-06 extraction) |
| D-07 (metadata excluded from conflict detection) | `_isDifferent` never flags a same-UUID conflict for the 4 metadata fields alone | unit | `flutter test test/unit/sync/restore_controller_test.dart` (new case) | ❌ Wave 0 — new case in existing file |
| Migration (v6→v7 additive) | New marker column defaults correctly; existing trips/prefs rows survive | unit (SchemaVerifier) | `flutter test test/unit/database/migration_v7_test.dart` | ❌ Wave 0 — follow `migration_v6_test.dart` pattern exactly |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/sync/ test/unit/database/` (client) and/or `cd backend/functions && npm run test:unit` (backend) depending on which side the task touches
- **Per wave merge:** Full client suite (`flutter test`) AND full backend suite (`cd backend/functions && npm test`, emulator-backed) — both required given this phase spans both tiers
- **Phase gate:** Both full suites green before `/gsd-verify-work`; additionally confirm the backend has actually been deployed (`firebase deploy --only functions` executed and verified, per SC2) before any client-emitting-new-fields task is considered mergeable to the branch that will ship

### Wave 0 Gaps
- [ ] `backend/functions/src/utils/__tests__/validation.test.ts` — extend with the 4 new fields (accepts-omitted-with-defaults cases, rejects-oversized-breaks-array, rejects-invalid-directionSource-enum)
- [ ] `backend/functions/test/handlers/sync-trips.test.ts` — extend happy-path assertion to check the 4 new fields land in the written Firestore doc; add a case sending breaks/metadata and reading back via `db` (the raw emulator handle already exported by `test/helpers/emulator.ts`)
- [ ] `backend/functions/test/handlers/restore-trips.test.ts` — add a "legacy doc missing new fields restores with defaults" case (seed a doc via the raw `db` handle bypassing `seedTrip`'s current field set, or extend `seedTrip` to support omitting fields)
- [ ] `test/unit/sync/trip_serializer_test.dart` — create if it doesn't exist; round-trip test for the 4 fields + breaks array, including empty-breaks and max-cap-breaks cases
- [ ] `test/unit/database/migration_v7_test.dart` — new file, follow `migration_v6_test.dart` structure exactly (open-at-v6, migrate-and-validate-to-v7, assert existing rows survive + new column defaults)
- [ ] `test/unit/sync/merge_resolution_test.dart` — new file for the D-06 extracted pure function, pinning current 5-field merge behavior BEFORE adding D-04 ride-along rules (mirrors the 25.1-01 "pin contract before rename" convention already used in this codebase)
- [ ] `test/unit/database/trip_breaks_dao_test.dart` — verify if this file exists; if so extend with `breaksForTripIds` batch-query cases; if not, create
- [ ] Resolve Pitfall 5 (duplicate `restore_controller_test.dart`) before adding new cases to either file

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (unchanged) | Firebase ID token verification (`verifyAuth`), already in place on both touched handlers — no new auth surface introduced |
| V3 Session Management | no | No session-related change in this phase |
| V4 Access Control | yes (unchanged) | `userId == uid` Firestore query filter in `restoreTripsHandler`, forced `userId` on write in `syncTripsHandler` — both pre-existing, unaffected by the new fields |
| V5 Input Validation | yes (extended) | zod `tripSchema` — the 4 new fields need the same validation rigor as existing ones (bounded array length via `.max()`, enum-constrained `directionSource`, ISO-datetime-validated break timestamps) — this IS new surface and must not regress the "reject unknown/malformed input" posture |
| V6 Cryptography | no | Not applicable — no crypto operations touched |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unbounded `breaks` array as a DoS vector (huge array in a sync payload inflating Firestore write cost / document size) | Denial of Service | `.max(kMaxBreaksPerTrip)` in zod (mirrors the existing `kMaxRoutePolylineChars`/`kMaxSyncBatchTrips` bound pattern) — reject BEFORE any Firestore work, matching the existing "cap lives in the schema" convention |
| Malformed `directionSource` string smuggling an unexpected value into Firestore (e.g. arbitrary string instead of the 3-value enum) | Tampering | `z.enum(['manual', 'geofence', 'time'])` — reject anything outside the closed set, same posture as the existing `direction: z.enum(['to_office', 'to_home'])` |
| Non-ISO break timestamps causing a downstream parse failure on restore | Tampering / Denial of Service (poison payload) | `z.string().datetime()` per break entry (same validator already used for `startTime`/`endTime` at the trip level) |
| Client spoofing `isEdited: true` to make server data appear user-verified for some future feature | Tampering (low severity — no current feature reads `isEdited` for trust decisions) | No additional mitigation needed now; `isEdited` is a display/UX flag only (drives the "~estimated" hint), not a security or trust decision — note for future phases if that ever changes |
| N+1 / query-amplification on the client from `breaksForTripIds` misuse | Denial of Service (local, self-inflicted battery/perf) | Not a security boundary — covered under performance in Common Pitfalls, not ASVS |

## Sources

### Primary (HIGH confidence)
- Direct code read: `lib/sync/trip_serializer.dart`, `lib/sync/sync_engine.dart`, `lib/sync/api_client.dart`, `lib/sync/restore_controller.dart`, `lib/sync/restore_conflict.dart`, `lib/features/settings/widgets/conflict_resolution_sheet.dart`, `lib/database/tables/trips_table.dart`, `lib/database/tables/trip_breaks_table.dart`, `lib/database/tables/user_preferences_table.dart`, `lib/database/daos/trip_breaks_dao.dart`, `lib/database/daos/trips_dao.dart`, `lib/database/daos/user_preferences_dao.dart`, `lib/database/daos/sync_queue_dao.dart`, `lib/database/database.dart`, `lib/config/constants.dart`, `lib/features/shell/main_shell.dart`, `lib/features/auth/providers/auth_providers.dart`, `lib/features/auth/models/auth_state.dart`, `lib/features/tracking/services/tracking_service_controller.dart`, `lib/features/trips/providers/trip_management_providers.dart`, `lib/features/trips/screens/trip_detail_screen.dart` (this session)
- Direct code read: `backend/functions/src/utils/validation.ts`, `backend/functions/src/types/trip.ts`, `backend/functions/src/utils/firestore.ts`, `backend/functions/src/handlers/sync-trips.ts`, `backend/functions/src/handlers/restore-trips.ts`, `backend/firestore.rules`, `backend/firestore.indexes.json`, `backend/functions/package.json`, `backend/functions/src/utils/__tests__/validation.test.ts`, `backend/functions/test/handlers/restore-trips.test.ts`, `backend/functions/test/handlers/sync-trips.test.ts`, `backend/functions/test/helpers/emulator.ts` (this session)
- Direct code read: `test/unit/database/migration_v6_test.dart` (migration test convention), `test/unit/sync/sync_engine_test.dart`, `test/unit/sync/restore_controller_test.dart`, `test/sync/restore_controller_test.dart` (this session)
- `.planning/phases/26-sync-breaks-edit-metadata-to-cloud/26-CONTEXT.md` — locked decisions D-01..D-11
- `.planning/phases/21-home-office-locations-geofence/21-01-PLAN.md` — exact migration ceremony commands (schema dump/generate)
- `.planning/phases/01-foundation/01-RESEARCH.md` — original migration test tooling rationale
- Context7 `/websites/zod_dev_v4` — `.default()` semantics change from Zod 3, confirmed against this repo's pinned `zod ^4.4.3`
- `npm view zod version` → `4.4.3` (matches `backend/functions/package.json` pin exactly)
- Local environment probes: `firebase --version` (15.19.0), `java -version` (26), `flutter --version` (3.41.6/Dart 3.11.4), `node --version` (v25.2.1) — this session

### Secondary (MEDIUM confidence)
- None — all findings this session were verified directly against the codebase or Context7, no unverified WebSearch claims were used.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — no new dependencies; every version verified against `pubspec.yaml`/`package.json` directly
- Architecture: HIGH — every pattern cited traces to an actual existing code path read this session (finalize transaction, edit transaction, auto-restore listener, tripConverter defensive read)
- Pitfalls: HIGH for zod/migration/signature-ripple pitfalls (directly verified in code); MEDIUM for Pitfall 2's exact resolution strategy (flagged as Open Question 1 / Assumption A1 — genuinely undecided until plan time)

**Research date:** 2026-07-12
**Valid until:** 30 days (stable, in-house codebase; no external API surface volatility expected) — re-verify zod pin if `package.json` changes before planning executes
