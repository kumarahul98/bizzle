---
phase: 11-sync-engine
fixed_at: 2026-06-01
review_path: .planning/phases/11-sync-engine/11-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 4
skipped: 1
status: partial
---

# Phase 11: Code Review Fix Report — Sync Engine

**Fixed at:** 2026-06-01
**Source review:** .planning/phases/11-sync-engine/11-REVIEW.md
**Branch:** gsd/phase-10-11-backend-sync
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (HR-01, MR-01 required; MR-03, LR-02, LR-03 optional-if-trivial)
- Fixed: 4 (HR-01, MR-01, MR-03, LR-02)
- Skipped: 1 (LR-03 — not trivial, touches DAO public contract)

## Fixed Issues

### HR-01: `ApiClient.restoreTrips` leaked raw FormatException/TypeError

**Files modified:** `lib/sync/api_client.dart`, `test/unit/sync/api_client_test.dart`
**Commit:** 8159fd0 (lint follow-up: 95dd6b2)
**Applied fix:** Wrapped the `jsonDecode` + envelope-unwrap + per-trip
`TripSerializer.fromJson` mapping in a `try { … } on SyncException { rethrow }
on Object { throw const SyncException.transport(); }`. A non-object top level is
now an explicit `decoded is! Map` → `transport`. So truncated/invalid JSON
(FormatException), a non-object top level (TypeError on `as Map`), and a
malformed trip element (cast/missing-key) all surface as the documented
retryable `SyncException.transport` — no raw exception, no body/token/PII leak.
Added three unit tests: invalid/truncated JSON, top-level array, malformed trip
element — each asserts `isA<SyncException>()` with `retryable == true`. The
method doc (MR-02) is now accurate as written; no separate change needed.

### MR-01: Account section title hardcoded; new constant was dead

**Files modified:** `lib/features/settings/screens/settings_screen.dart`
**Commit:** 7a0b303
**Applied fix:** Replaced `SettingsSection(title: 'Account', …)` with
`SettingsSection(title: kSettingsAccountSectionTitle, …)`. The constant is now
live (no longer dead code) and the touched call site no longer violates the
no-hardcoded-strings rule. Value is byte-identical ('Account'), so the existing
widget test `find.text('ACCOUNT')` (SettingsSection upper-cases) stays valid.

### MR-03: Redundant empty drain from watchPending self-loop

**Files modified:** `lib/sync/sync_engine.dart`, `test/unit/sync/sync_engine_test.dart`
**Commit:** 1598fed (lint follow-up: 95dd6b2)
**Applied fix:** Gated the post-save `watchPending()` trigger on a rising edge
of the pending count (`var lastPending`; nudge only when `rows.length >
lastPending`). A genuine new enqueue (count rises) still drains promptly; a
successful drain's own `markSynced` writes (which shrink the pending set) no
longer re-fire a redundant empty `processPending()`. Failed-row retry is
unaffected — it flows through `retryFailed()` calling `processPending()`
directly; connectivity/resume triggers remain independent. Added a test that
drives the real `start()` path (connectivity method channel stubbed) and asserts
exactly ONE `SyncSynced` after a single enqueue+drain. Verified the test FAILS
without the guard (got 2 `SyncSynced`) and passes with it.

### LR-02: `countFailed` materialized rows just to count them

**Files modified:** `lib/database/daos/sync_queue_dao.dart`, `test/unit/database/sync_queue_dao_test.dart`
**Commit:** 61c3619
**Applied fix:** Replaced `select(...).get()` + `rows.length` with a real
`COUNT(*)` aggregate (`syncQueue.id.count(filter: status == failed)` via
`selectOnly`), matching the pattern already used elsewhere. Added two DAO tests
(two failed rows → 2; no failed rows → 0).

## Skipped Issues

### LR-03: `markSynced`/`syncedAt` use `DateTime.now()` while the engine has an injected clock

**File:** `lib/database/daos/sync_queue_dao.dart:127`
**Reason:** Skipped — not trivial. The injectable clock lives on `SyncEngine`
(`_now`), but `syncedAt` is stamped inside `SyncQueueDao.markSynced(int id)`,
which has no clock seam. Threading the clock through would change the DAO public
method signature and all call sites — i.e. touch the frozen persistence
contract, which the brief explicitly said to avoid. The review itself rates this
"Acceptable as-is for v0.1." Left as wall-clock by design.

**Also intentionally not changed (per brief):** the doc-comment LOWs (LR-04
`SyncOffline` wording, MR-04 connectivity comment), LR-01 `_failedCount`
de-dup, and LR-05 defensive `notSignedIn` catch — none were in the apply list
and several are doc-only; skipped to keep the diff scoped to the required +
trivial fixes.

## Verification

- **flutter analyze:** baseline 96 (87 info + 9 warning + 0 error) → after fixes
  **96** (zero new issues). New test code initially added 4 info lints
  (line-length / inner-quote escape); all resolved in commit 95dd6b2, returning
  analyze to exactly 96. 0 errors throughout.
- **flutter test (full suite):** **377 passed, 0 failed, 10 skipped.** The 10
  skips are pre-existing (`traevy_toggle_test.dart` and friends — untouched);
  no new skips were introduced in any touched file. No assertion was weakened.

---

_Fixed: 2026-06-01_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
