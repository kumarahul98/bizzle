# Phase 11 (Sync Engine) — Plan Check

**Checked:** 2026-06-01
**Checker:** gsd-plan-checker (goal-backward)
**Verdict:** **CONDITIONAL PASS for 11-01 — PHASE BLOCKED (11-02, 11-03, 11-RESEARCH.md not yet written)**

---

## State of the phase directory

| Artifact | Status |
|---|---|
| `11-CONTEXT.md` | present (D-01..D-10) |
| `11-RESEARCH.md` | **MISSING** |
| `11-01-PLAN.md` | **present** — foundation (transport, serializer, SyncStatus, DAO additions) |
| `11-02-PLAN.md` | **MISSING** — engine + triggers |
| `11-03-PLAN.md` | **MISSING** — restore + Settings UI |

Only the foundation plan exists. The phase goal needs all three plans; the
verification of cross-plan contract integrity (the explicit reason this check
was requested, given Phase 10's drift) is **only half-checkable**: I can confirm
what 11-01 PRODUCES and that it froze its public names, but I cannot confirm that
11-02/11-03 CONSUME those exact names because those files do not exist yet.

**Action:** Run `/gsd-plan-phase 11 --research` (or the planner) to produce
`11-RESEARCH.md`, `11-02-PLAN.md`, `11-03-PLAN.md`, then re-run this check. The
re-check is mechanical: diff every symbol 11-02/11-03 import against the frozen
list in 11-01's `<objective>`.

---

## 11-01-PLAN.md — full verification (PASS with notes)

### Requirement coverage
- Frontmatter `requirements: [SYNC-02, SYNC-03]` matches the ROADMAP Phase 11
  requirement set. 11-01 is foundation only — it does not by itself satisfy either
  requirement end-to-end (no triggers, no Settings action), which is correct for a
  Wave-1 foundation plan. Full SYNC-02/03 delivery depends on 11-02/11-03. **OK.**

### Success-criterion traceability (phase-level, what 11-01 contributes)
| SC | 11-01 contribution | Delivered by 11-01 alone? |
|----|--------------------|---------------------------|
| SC1 post-save background sync | `ApiClient.syncTrips`, serializer, `markFailed` | No — triggers/`processPending` are 11-02. Foundation present. |
| SC2 retry ≤3 + exp backoff | `markFailed`, `resetFailed`, reuse `kSyncQueueMaxRetries`, backoff consts | No — backoff loop is 11-02. Foundation present. |
| SC3 restore + dedupe | `ApiClient.restoreTrips` → `List<TripsCompanion>`, `TripSerializer.fromJson` | Partial — insert-or-ignore dedupe is 11-03. Transport + parser present. |
| SC4 never block UI | typed `SyncException` (caught upstream), no UI reads | No — fire-and-forget wiring is 11-02/11-03. Foundation present. |
This is the correct decomposition: foundation provides the proven contracts; the
two proving paths (background trigger, dedupe-on-restore) land in 11-02/11-03.

### Task completeness — all three tasks have files/action/verify/done
- **Task 1** (deps + constants + `markFailed`/`resetFailed` + DAO tests): complete.
  `<automated>` runs `flutter pub get && build_runner build && flutter test ...dao_test`.
- **Task 2** (`SyncStatus` sealed + `TripSerializer` toJson/fromJson), `tdd=true` with
  a real `<behavior>` block asserting the exact key set, `Z`-suffix, 0-not-null,
  round-trip, `userId` absent. `<automated>` runs the serializer test. complete.
- **Task 3** (`ApiClient` + `SyncException` + `apiClientProvider`), `tdd=true`,
  MockClient behavior covering happy-path, 401→refresh→retry-once, persistent-401,
  500-no-retry, restore parse, delete, not-signed-in. `<automated>` runs the test. complete.
- Scope: 3 tasks / ~11 files — within budget. **OK.**

### Serialization contract vs backend zod `tripSchema` (validation.ts) — MATCH
Verified key-by-key against `backend/functions/src/utils/validation.ts`:
- Key set `{id,startTime,endTime,durationSeconds,distanceMeters,routePolyline,
  direction,timeMovingSeconds,timeStuckSeconds,isManualEntry,createdAt,updatedAt}`
  — exact camelCase, **`userId` omitted** (schema marks it `.optional()` / server-forced). ✔
- Timestamps `toUtc().toIso8601String()` → RFC3339 with `Z`; Task 2 test asserts
  `endsWith('Z')` and non-UTC-input still emits `Z`. Satisfies `z.string().datetime()`. ✔
- `direction` pass-through `'to_office'|'to_home'` → `z.enum([...])`. ✔
- `routePolyline` nullable. ✔ (zod `.max(100000).nullable()` — the 100000 cap is
  server-enforced; client does not need to pre-validate length; correctly not added.)
- Numeric fields 0-not-null for manual entries; Task 2 has an explicit manual-entry
  test. `distanceMeters` emitted as Dart `double` → `z.number()`. ✔
- Batch body `{ trips: [...] }` `.min(1).max(1000)` — 11-01 sends what it's given;
  the `.min(1)` guard and ≤1000 chunking are correctly deferred to engine (11-02).
  **Flag for 11-02 (see M1):** the engine MUST never call `syncTrips([])` (empty →
  server 400) and MUST chunk at `kMaxSyncBatchTrips=1000`.

### CLAUDE.md compliance (frontend rules) — PASS
- Drift-only UI reads: 11-01 adds no UI; restore returns `TripsCompanion`s for the DB. ✔
- Manual Riverpod (no `@riverpod` codegen): `NotifierProvider`/`Provider` used explicitly;
  interfaces block calls out the drift_dev analyzer conflict. ✔
- Sealed finite state: `SyncStatus` sealed with `SyncIdle/Syncing/Synced/Offline/Failed(count)`
  (D-10), consumers told to use exhaustive `switch`, never `.when()`. ✔
- Retries max 3 + exp backoff: reuses `kSyncQueueMaxRetries=3`, adds
  `kSyncRetryBaseDelay=2s` / `kSyncRetryMaxDelay=60s`. Foundation only; loop in 11-02. ✔
- No `cloud_firestore`: explicitly forbidden in Task 3; transport is `http` only. ✔
- No hardcoded strings: all Settings copy + URLs/paths defined as constants in Task 1
  (pre-staged for 11-03). ✔ One guard noted in M3 below.
- Secure-token note: uses live `getIdToken()` not the cached secure-storage token —
  matches D-03 and is the safer choice. ✔

### Testability — PASS
- Serializer tests are pure (no DB). ✔
- `ApiClient` injects `http.Client` (MockClient) + a **token-getter function seam**
  instead of touching `FirebaseAuth` statically — so 401/refresh/not-signed-in paths
  run with no Firebase platform channels. ✔ (Strong design; pre-empts a common trap.)
- DAO tests use the in-memory `NativeDatabase.memory()` harness. ✔
- Restore dedupe test is correctly NOT here (insert-or-ignore lives in 11-03); 11-01
  proves the parser round-trips. ✔

### Threat model — present and reasonable
STRIDE register covers token non-leakage in `SyncException.toString()` (T-11-01),
fresh-token + 401 refresh (T-11-02), typed-cast restore parse (T-11-03). Good.

---

## Cross-plan contract integrity (the requested focus)

11-01 did the right thing: it published a **frozen public-name block** ("DO NOT RENAME")
in `<objective>` lines 73-86. Confirmed those names exist in the plan body and map to
real, existing types in the codebase:
- `apiClientProvider`, `ApiClient.{syncTrips, deleteTrip, restoreTrips}`, `SyncException`
  (with `int? statusCode` + `notSignedIn`) — defined in Task 3. ✔
- `syncStatusProvider`, `SyncStatusNotifier extends Notifier<SyncStatus>`, variants
  `SyncIdle/SyncSyncing/SyncSynced/SyncOffline/SyncFailed(int count)` — Task 2. ✔
- `TripSerializer.toJson(TripRow)` / `fromJson(Map)` — Task 2. **Note:** these are
  named `TripSerializer.toJson/fromJson`, NOT `tripRowToJson/tripJsonToCompanion` as the
  check brief guessed. The actual frozen names are the authority; 11-02/11-03 must bind
  to `TripSerializer.toJson/fromJson`. Recorded here so the re-check uses the right names.
- `SyncQueueDao.markFailed(int id)` / `resetFailed()` — Task 1. Confirmed neither exists
  in the current `sync_queue_dao.dart` (which has enqueue*/getPending? + watchPending/
  markSynced/incrementRetry); 11-01 adds them in the foundation, so 11-02 can depend on
  them without a backward wave dependency. ✔ (Note: current DAO has `watchPending()` but
  the CONTEXT also mentions `getPending()` oldest-first for the engine — see M2.)
- Constants `kApiBaseUrl`, `kSyncTripsPath`, `kRestoreTripsPath`, `kDeleteTripPathPrefix`,
  `kSyncRetryBaseDelay`, `kSyncRetryMaxDelay`, Settings copy — Task 1. ✔

**The retry-entrypoint question (explicitly raised):** 11-03 will need a "tap to retry"
action. 11-01 provides the *primitive* (`SyncQueueDao.resetFailed()` flips failed→pending
+ zeroes retryCount). It does NOT define an engine-level `retryFailed()`/`retrySync()`
method — that is 11-02's surface and **does not exist yet**. This is the single highest
cross-plan risk and is unresolved because 11-02 is unwritten. See H2.

---

## Findings (HIGH / MEDIUM / LOW)

### HIGH

- **H1 — Phase incompletely planned.** `11-02-PLAN.md`, `11-03-PLAN.md`, and
  `11-RESEARCH.md` do not exist. The phase goal (SYNC-02 + SYNC-03 end-to-end) cannot
  be verified and MUST NOT be executed as-is. 11-01 alone is safe to execute (Wave 1,
  `depends_on: []`, fully self-contained and self-tested) but delivers no user-visible
  success criterion. Generate the remaining plans, then re-check.

- **H2 — Retry-entrypoint contract is the #1 Phase-10-style drift risk and is currently
  UNDECIDABLE.** 11-03's Settings "Sync failed — tap to retry" row (D-09) must call an
  engine method. 11-01 exposes only the DAO primitive `SyncQueueDao.resetFailed()`, not
  an engine method. When 11-02 is written it MUST publish an exact, named entrypoint
  (recommend `SyncEngine.retryFailed()` = `await dao.resetFailed(); await processPending();`)
  and 11-03 MUST import that exact symbol. **Bake this name into 11-02's frozen
  public-name block before execution** the same way 11-01 froze its names. Add it to
  11-01's SUMMARY hand-off note so 11-02/11-03 share one spelling. Until 11-02 exists
  this cannot be confirmed — flag as the must-resolve item.

### MEDIUM

- **M1 — Empty-batch + 1000-chunk guard must live in 11-02.** Backend `syncTripsBody`
  is `.min(1).max(1000)`. 11-01's `syncTrips` sends whatever list it gets and would
  surface a server 400 as a `SyncException`. 11-02's `processPending` MUST (a) never call
  `syncTrips([])` when there are no create/update rows, and (b) chunk create/update at
  `kMaxSyncBatchTrips=1000`. Verify when 11-02 is written.

- **M2 — Oldest-first pending fetch (`getPending()`) is referenced by CONTEXT D-05 but
  not added by 11-01.** Current DAO exposes `watchPending()` (a stream, unordered) but
  the engine wants a one-shot oldest-first `getPending()` (D-05 "pull pending rows
  oldest-first"). Decide ownership: either 11-01 should have added `getPending()` to the
  foundation, or 11-02 adds it. If 11-02 adds a DAO method, that's still fine (same DAO
  file, Wave 2) but call it out so it isn't missed. Re-check: confirm the engine has an
  ordered fetch, not just the unordered `watchPending()` stream.

- **M3 — One hardcoded section title remains in Settings (`'Account'`).** `settings_screen.dart`
  line 116 passes `SettingsSection(title: 'Account', ...)` as a literal, and other
  sections use literals too ('Recording', 'Notifications'). 11-01 Task 1 conditionally
  adds `kSettingsAccountSectionTitle` "only if not already present" — but it is NOT
  present today, so 11-03 (which edits `_AccountSection`) should either add+use the
  constant or be explicitly exempted (matching the existing literal style of sibling
  sections). Minor; resolve in 11-03 to satisfy the no-hardcoded-strings rule cleanly.

- **M4 — `11-RESEARCH.md` missing → new-dep versions unverified.** 11-01 pins
  `http: ^1.2.2` and `connectivity_plus: ^6.1.0` calling them "research-verified," but
  there is no RESEARCH.md to back that. `connectivity_plus` 6.x changed
  `onConnectivityChanged` to emit `List<ConnectivityResult>` (not a single value) — 11-02's
  "transition to online" trigger must be coded against the List shape. Have the research
  step confirm this so 11-02 doesn't code the 5.x single-value API.

### LOW

- **L1 — `apiClientProvider` keeps a long-lived `http.Client`.** Task 3 adds
  `ref.onDispose(client.close)` — good. No action; noted for completeness.
- **L2 — Restore parser ignores server `userId` by design** (local auth backfill owns
  it). Correct and matches D-08/Phase-9. No action.
- **L3 — Dependency order is sound in intent**: 11-01 `depends_on: []` (Wave 1) →
  11-02 engine (Wave 2, depends on 11-01) → 11-03 restore+UI (Wave 2/3, depends on
  11-01 and the engine retry entrypoint). Cannot confirm `depends_on` frontmatter on
  02/03 until they exist.

---

## Re-check checklist (after 11-02 + 11-03 + 11-RESEARCH.md are generated)

1. Files exist with valid frontmatter; `depends_on` reflects 01→02→03 ordering.
2. Diff every symbol 11-02/11-03 import against 11-01's frozen names — **zero mismatches**.
   Authoritative names: `TripSerializer.toJson/fromJson` (NOT tripRowToJson/…),
   `SyncStatusNotifier`/`syncStatusProvider`, `ApiClient.{syncTrips,deleteTrip,restoreTrips}`,
   `SyncException`, `apiClientProvider`, `SyncQueueDao.{markFailed,resetFailed}`.
3. **H2:** 11-02 publishes the exact engine retry entrypoint (e.g. `retryFailed()`) and
   11-03 calls it verbatim. Resolve the name in BOTH or fail.
4. **M1:** engine never POSTs an empty batch and chunks at 1000.
5. **M2:** engine has an oldest-first pending fetch.
6. **M3:** Settings retry/restore rows use copy constants (no new hardcoded strings).
7. **M4:** RESEARCH confirms `connectivity_plus` 6.x `List<ConnectivityResult>` shape.
8. SC1 (background trigger) and SC3 (restore dedupe) each have a delivering task AND an
   injected-dependency test (fake connectivity stream / manual lifecycle; in-memory Drift;
   insert-or-ignore dedupe assertion).
9. CLAUDE.md re-verified against 11-02/11-03 written tasks (async fire-and-forget,
   in-flight guard, no UI network reads, no cloud_firestore).
