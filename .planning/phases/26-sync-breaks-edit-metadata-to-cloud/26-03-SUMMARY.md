---
phase: 26-sync-breaks-edit-metadata-to-cloud
plan: 03
subsystem: sync
tags: [serializer, wire-contract, breaks, sync-engine, api-client, dart-records]

# Dependency graph
requires:
  - phase: 26-01
    provides: Live-deployed backend zod tripSchema accepting totalPausedSeconds/isEdited/directionSource/breaks (SC2 gate)
  - phase: 26-02
    provides: kMaxBreaksPerTrip constant + TripBreaksDao.breaksForTripIds batch lookup
provides:
  - "TripSerializer.toJson(TripRow, List<TripBreakRow>) emitting the 4 Phase 26 fields + breaks, capped client-side at kMaxBreaksPerTrip (oldest-first)"
  - "ParsedTrip record typedef ({trip, breaks}) — TripSerializer.fromJson parses the 4 fields with server-omission defaults and returns trip + break companions as one unit"
  - "ApiClient.syncTrips(trips, breaksByTripId) / restoreTrips() -> List<ParsedTrip> matching the new codec"
  - "SyncEngine._drain batch-fetches breaks ONCE per drain via breaksForTripIds before the chunk loop (never N+1)"
affects: [26-04, 26-05, 26-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dart 3 record typedef (ParsedTrip) as a multi-value wire-parse return — no wrapper class ceremony"
    - "Client-side defensive cap mirroring a backend zod .max() bound (take(kMaxBreaksPerTrip)) to prevent non-retryable 400 poison pills"

key-files:
  created:
    - (none — test file rewritten in place)
  modified:
    - lib/sync/trip_serializer.dart
    - lib/sync/api_client.dart
    - lib/sync/sync_engine.dart
    - lib/sync/restore_controller.dart
    - test/unit/sync/trip_serializer_test.dart
    - test/unit/sync/sync_engine_test.dart
    - test/unit/sync/api_client_test.dart
    - test/unit/sync/restore_controller_test.dart
    - test/sync/restore_controller_test.dart
    - test/widget/features/settings/conflict_resolution_sheet_test.dart
    - test/widget/features/settings/settings_screen_test.dart

key-decisions:
  - "RestoreController maps ParsedTrip.trip through unchanged (breaks discarded at that layer for now) — persisting restored break companions is Plan 05's explicit scope, so restore keeps compiling and passing without premature feature work"
  - "test/sync/restore_controller_test.dart (the stale duplicate) verified GREEN against pre-plan code first, so it was FIXED (per the plan's conditional) rather than flagged as dead code; deletion-or-keep remains Plan 05's Pitfall-5 call"
  - "api_client_test.dart and settings_screen_test.dart were unlisted ripple sites — fixed under Rule 3 (signature change broke their fakes/helpers), no new coverage added beyond one empty-breaks-array body assertion in the api_client happy path"

patterns-established:
  - "Fake ApiClient fixtures wrap stored companions as (trip: c, breaks: const <TripBreaksCompanion>[]) — smallest-diff adaptation that Plans 05/06 can extend with real break fixtures"

requirements-completed: []

duration: ~30min
completed: 2026-07-13
---

# Phase 26 Plan 03: Client Wire Codec — Breaks + Edit Metadata Summary

**TripSerializer now speaks the full Phase 26 wire contract in both directions (4 new fields + breaks array, 50-cap enforced client-side), with ApiClient/SyncEngine wired to batch-fetch breaks once per drain and every dependent test fixture mechanically fixed — full suite green.**

## Performance

- **Duration:** ~30 min (commits span 2026-07-13T00:34+05:30 – 01:01+05:30, including one mid-task session interruption/resume with no rework)
- **Tasks:** 3 completed
- **Files modified:** 11

## Accomplishments

- `TripSerializer.toJson(TripRow, List<TripBreakRow>)`: emits `totalPausedSeconds`, `isEdited`, `directionSource`, and a `breaks` array of `{startTime, endTime}` ISO-8601-UTC maps, truncated via `.take(kMaxBreaksPerTrip)` (T-26-18 mitigation — a >50-break trip can never become a non-retryable 400 poison pill; oldest-first retention since callers supply breaks startTime-ascending)
- `TripSerializer.fromJson` → `ParsedTrip` record: parses the 4 fields with clean server-omission defaults (`0`/`false`/`kDirectionSourceTime`/`[]`) and materializes break companions with fresh UUIDs + the parsed trip's id (wire format carries no break id by design, roadmap SC1)
- `ApiClient.syncTrips(trips, breaksByTripId)`: each trip serializes with its breaks or an empty array (`?? const []`, never throws); `restoreTrips()` returns `List<ParsedTrip>` with the malformed-envelope catch-all unchanged (T-26-09 — a bad break entry still maps to `SyncException.transport()`)
- `SyncEngine._drain`: ONE `breaksForTripIds` call per drain, positioned after `liveTrips` is built and before the chunk loop (T-26-10); `tripBreaksDao` injected seam + production wiring via `tripBreaksDaoProvider`
- 16 serializer unit tests (incl. >50 truncation, exactly-50 at-cap, omitted-fields defaulting) + a new engine test proving break rows flow from the test DB through `breaksForTripIds` into `syncTrips`

## Task Commits

Each task was committed atomically:

1. **Task 1: TripSerializer — 2-arg toJson (50-break cap), record-returning fromJson, round-trip tests** - `cea9217` (feat)
2. **Task 2: Wire ApiClient + SyncEngine to the new TripSerializer shape** - `274a660` (feat)
3. **Task 3: Compile-fix ripple in dependent test fixtures** - `8518ad9` (test)

_Note: Tasks 1–2 were `tdd="true"` but each landed as a single combined test+impl commit rather than separate RED/GREEN commits — the signature change (`toJson` 1-arg → 2-arg) makes the old test file uncompilable against the new API, so there is no meaningful standalone-failing RED state. Tests were written against the new behavior and run green before each commit; no untested code was committed. Same pragmatic pattern 26-02 documented._

## Files Created/Modified

**Production (plan scope):**
- `lib/sync/trip_serializer.dart` - `ParsedTrip` typedef; 2-arg `toJson` with cap; record-returning `fromJson`
- `lib/sync/api_client.dart` - `syncTrips` 2-arg signature; `restoreTrips` → `List<ParsedTrip>`
- `lib/sync/sync_engine.dart` - `tripBreaksDao` constructor seam + field; one batch fetch in `_drain`; provider wiring
- `lib/sync/restore_controller.dart` - maps `ParsedTrip.trip` through unchanged (Rule 3 — compile ripple; break persistence deferred to Plan 05 per plan scope)

**Tests (plan scope):**
- `test/unit/sync/trip_serializer_test.dart` - all 7 plan behaviors as distinct cases + preserved pre-existing coverage
- `test/unit/sync/sync_engine_test.dart` - FakeApiClient new signatures (+ `syncBreaksCalls` recorder); 3 `SyncEngine(...)` constructions gain `tripBreaksDao: db.tripBreaksDao`; new breaks-batch-fetch test
- `test/unit/sync/restore_controller_test.dart` - `_companion(...).trip`; fake returns breaks-less `ParsedTrip`s
- `test/sync/restore_controller_test.dart` - same two fixes (verified green pre-change first, per the plan's conditional)
- `test/widget/features/settings/conflict_resolution_sheet_test.dart` - `_companion(...).trip` only

**Tests (unlisted ripple, Rule 3):**
- `test/unit/sync/api_client_test.dart` - all `syncTrips` call sites → 2-arg; restore assertion → `.trip.id.value`; added empty-breaks-array assertion on the POST body
- `test/widget/features/settings/settings_screen_test.dart` - `_FakeApiClient.restoreTrips` wraps as `ParsedTrip`; `_restoreCompanion` takes `.trip`

## Decisions Made

- **RestoreController discards parsed breaks for now:** the plan locks this plan's job to the codec + call-site wiring; writing restored breaks into `trip_breaks` (and the conflict-sheet breaks indicator) is Plan 05/06 work. A doc comment at the call site marks the handoff explicitly.
- **Stale duplicate test fixed, not deleted:** `test/sync/restore_controller_test.dart` was run AS-IS against pre-plan code (via targeted `git checkout <pre-plan> -- lib/sync`, then restored) and passed 5/5 — so per the plan's conditional it received the minimal signature fixes. Its fix-or-delete fate stays with Plan 05 (RESEARCH.md Pitfall 5).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `restore_controller.dart` (production) broken by `restoreTrips` return-type change**
- **Found during:** Task 2 (`flutter analyze lib/`)
- **Issue:** `RestoreController.restore()` consumed `List<TripsCompanion>`; the new `List<ParsedTrip>` return type broke compilation.
- **Fix:** Map `parsed.map((p) => p.trip).toList()` with a comment deferring break persistence to Plan 05. No behavior change.
- **Files modified:** `lib/sync/restore_controller.dart`
- **Commit:** 274a660

**2. [Rule 3 - Blocking] `api_client_test.dart` broken by the signature change (unlisted in plan)**
- **Found during:** Task 2 verification
- **Issue:** 9 `syncTrips([sampleTrip()])` one-arg call sites + `restoreTrips()` companion-shape assertions no longer compiled.
- **Fix:** All call sites → `syncTrips([sampleTrip()], const {})`; restore assertions → `parsed.first.trip.id.value` + `parsed.first.breaks` empty; added an empty-breaks-array assertion to the POST-body happy path (directly pins the `?? const []` behavior).
- **Files modified:** `test/unit/sync/api_client_test.dart`
- **Commit:** 274a660

**3. [Rule 3 - Blocking] `settings_screen_test.dart` broken by the return-type change (unlisted in plan)**
- **Found during:** Task 3 (project-wide analyze)
- **Issue:** Its `_FakeApiClient.restoreTrips` returned `List<TripsCompanion>` and `_restoreCompanion` treated `fromJson`'s result as a companion.
- **Fix:** Same minimal wrap-as-`ParsedTrip` + `.trip` pattern as the listed fixture files. No new coverage.
- **Files modified:** `test/widget/features/settings/settings_screen_test.dart`
- **Commit:** 8518ad9

---

**Total deviations:** 3 auto-fixed (all Rule 3 — direct compile consequences of the plan's own instructed signature change). No scope creep; every unlisted file was touched only because it would not otherwise compile.

## Verification

- Task 1: `flutter test test/unit/sync/trip_serializer_test.dart` — 16/16 green; `flutter analyze` clean on both files; `grep` confirms `typedef ParsedTrip` and `take(kMaxBreaksPerTrip)` present.
- Task 2: `flutter test test/unit/sync/sync_engine_test.dart` — 29/29 green incl. the new breaks-batch-fetch test; `grep` confirms exactly ONE `breaksForTripIds` call site in `_drain`, before the chunk loop; `flutter analyze lib/sync/` — zero errors/warnings (remaining infos verified pre-existing via stash comparison).
- Task 3: scoped verify set (all of `test/unit/sync/` + both restore fixture files + conflict sheet + settings screen) — 109/109 green; **full `flutter test` suite — 619 passed, 10 pre-existing skips, zero regressions**; project-wide `flutter analyze` — zero errors, zero warnings.
- Threat register: T-26-18 mitigated (`take(kMaxBreaksPerTrip)`, test-pinned both sides of the boundary); T-26-09 mitigated (breaks parse failures fall through the pre-existing `SyncException.transport()` catch-all, unchanged); T-26-10 accepted per plan.

## Known Stubs

None in this plan's own scope. One intentional, plan-mandated deferral (not a stub): `RestoreController` receives parsed break companions and drops them — the plan explicitly assigns writing restored breaks into Drift to Plan 05, and the call site documents this.

## Threat Flags

None — no new network endpoints, auth paths, file access, or schema surface beyond the `<threat_model>`'s registered items.

## Next Phase Readiness

- The client now EMITS the 4 new fields + breaks against the live backend on every sync drain — SC1's outbound half is done end-to-end.
- Plan 04 (backfill re-sync) can enqueue trips knowing the serializer includes their breaks automatically.
- Plan 05 (restore writes breaks) has `ParsedTrip.breaks` waiting at the exact `RestoreController.restore()` call site, with fresh UUIDs and correct `tripId`s already materialized.
- No blockers. Full suite and analyze green at HEAD.

---
*Phase: 26-sync-breaks-edit-metadata-to-cloud*
*Completed: 2026-07-13*

## Self-Check: PASSED

All 11 claimed modified files and the SUMMARY exist on disk; commits cea9217, 274a660, 8518ad9 verified in git history.
