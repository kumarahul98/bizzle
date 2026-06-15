# Phase 24: Automatic Cloud Sync & Restore - Context

**Gathered:** 2026-06-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Make cloud sync and restore hands-off, and add cloud↔local reconciliation on
sign-in. The phase has three sub-capabilities at very different maturity:

1. **Sync-on-finish (SYNC-05a) — mostly DONE, verify/harden only.** A finished
   trip already syncs immediately: `persistFinalizedTrip` enqueues a
   `sync_queue` row and `SyncEngine`'s `watchPending()` rising-edge nudge
   (`lib/sync/sync_engine.dart:316`) fires `processPending()` the instant the
   pending count increases. Do NOT rebuild — confirm the finalize→enqueue→drain
   path fires immediately and add a regression test if missing.

2. **Auto-restore + conflict-merge on sign-in (SYNC-04) — the BIG new piece.**
   `RestoreController.restore()` (`lib/sync/restore_controller.dart`) already
   downloads all cloud trips and inserts them dedupe-by-UUID (`insertOrIgnore`),
   but it is manual-only (Settings row). This phase auto-triggers it on every
   sign-in AND replaces silent dedupe with a **conflict detection + user
   reconciliation** flow (see D-01..D-06). This is a deliberate departure from
   the documented client-authoritative one-way design and is the dominant scope
   and risk of the phase.

3. **Auto-retry of failed sync items (SYNC-05b) — the real sync gap.** The three
   auto-triggers (post-save rising edge, connectivity-restored, app-resume) only
   drain `getPending()` (status `pending`). Rows that hit the retry cap or a
   non-retryable error become status `failed` and sit stuck until the user taps
   the manual Settings "Retry" row (`SyncEngine.retryFailed()`). This phase adds
   automatic, time-gated re-attempt of failed rows plus visible surfacing.

**In scope:**
- Verify/harden immediate sync-on-finish (SYNC-05a) with a test.
- Auto-trigger restore on every successful sign-in transition, once per sign-in
  (not per launch), with a subtle progress indicator + outcome toast.
- Conflict detection on restore: same-UUID field differences AND different-UUID
  time-overlap; bulk resolution (keep all local / use all cloud / merge) with
  per-trip override; clean restores stay silent.
- Auto-retry failed sync items, time-gated, on connectivity-restored + resume.
- Visible badge/banner when items are genuinely stuck.

**Out of scope:**
- Continuous two-way background sync (SYNC2-01, v2). Reconciliation here is a
  sign-in-time/restore-time event, not an ongoing server→client stream.
- Reworking the sign-in mechanism (Phase 9) or the first-run gate / guest→
  sign-in upload backlog (Phase 20 owns D-08/D-09 — the UPLOAD side).
- Interrupted-trip recovery (Phase 25, separate domain).
- Backend changes beyond what the existing `/trips/sync`, `/trips/restore`,
  `/trips/{id}` endpoints already provide (revisit only if merge needs it).

</domain>

<decisions>
## Implementation Decisions

### Auto-restore trigger (SYNC-04)
- **D-01:** Auto-restore runs on **every successful sign-in transition**
  (AuthGuest/AuthLoading → AuthSignedIn), **once per sign-in, not per launch**.
  Re-running is safe because detection + dedupe make it idempotent. This covers
  fresh install, new device, and Phase 20's sign-in-later uniformly. Trigger
  point is the sign-in success path (`AuthService.signIn()` / the auth-state
  transition) — planner picks the exact seam so it composes with Phase 20's
  backfill+enqueue without double-running.
- **D-02:** Restore + upload both run on sign-in and must not fight: Phase 20
  backfills local guest trips to the real uid and enqueues them (UPLOAD); this
  phase downloads cloud trips and reconciles (DOWNLOAD). Order is download-
  detect-reconcile; uploads of local-only trips proceed normally via the queue.
  Planner must sequence so a trip that is both local and cloud is reconciled
  once (not uploaded AND prompted as a conflict in a contradictory way).

### Conflict detection + merge on restore (SYNC-04) — DOMINANT RISK
- **D-03:** Detect **two** conflict classes client-side after the
  `/trips/restore` download:
  - **Same-UUID differences** — a trip exists locally and in cloud with the same
    UUID but differing field values (edited on another device). Exact detection.
  - **Time-overlap (different UUID)** — a cloud trip and a local trip with
    different UUIDs whose start/end ranges overlap (same commute recorded on two
    devices). Fuzzy — needs a defined overlap rule/threshold (RESEARCH this:
    overlap %, min-overlap minutes, direction match) to keep false positives low.
- **D-04:** Resolution UX = **bulk choice + per-trip override**. Show a conflict
  summary ("N conflicts") with bulk actions **Keep all local / Use all cloud /
  Merge**, expandable to decide individual trips (keep-local / use-cloud /
  field-by-field merge). The reconciliation UI appears **only when conflicts are
  detected**; a clean restore stays silent except the outcome toast (D-05).
- **D-05:** Non-conflicting cloud trips (new UUIDs, no overlap) are inserted
  silently as today. Outcome surfaced via a brief toast/snackbar
  ("Restored N trips" / "Already up to date"); restore errors stay quiet with
  the existing manual Settings Restore as fallback.
- **D-06:** "Use cloud" / field-merge means **cloud can overwrite local** — a
  conscious break from CLAUDE.md "client always wins / no conflict resolution."
  This is restore-time reconciliation only (not ongoing two-way). Overwrites
  must go through the trips DAO update path so the corrected row re-enters the
  sync queue (consistent with Phase 19's edit→re-queue behavior). Discarding/
  keep-local leaves local untouched. RESEARCH whether the restore envelope
  carries everything needed to compare/merge field-by-field (incl. breaks,
  edited flag) and whether soft-deleted cloud trips appear in `/trips/restore`.

### Auto-retry failed sync items (SYNC-05b)
- **D-07:** Auto-retry **all** failed rows (including non-retryable/poison-pill)
  but **time-gated**: at most once per long window (a new constant, e.g.
  `kFailedAutoRetryWindow` — pick a few hours / once per app session) so a
  permanently-failing item can never hammer the backend. Triggers: connectivity-
  restored and app-resume (NOT the post-save nudge). Mechanism reuses
  `retryFailed()` (clear backoff → `resetFailed()` → drain) but wrapped in the
  time-gate; add the gate state (last-auto-retry timestamp) so it survives within
  a session. Planner decides whether the timestamp needs persistence.
- **D-08:** Sync-on-finish (SYNC-05a) is already satisfied by the existing
  rising-edge nudge — scope is to VERIFY it fires immediately and add a test, not
  to rebuild the trigger.

### Stuck-item surfacing (SYNC-05b)
- **D-09:** When items are genuinely stuck (auto-retry window exhausted / poison
  pill remaining failed), show a **visible dismissible badge/banner** (e.g. on
  the dashboard) that links to the existing Settings retry action. Keep the
  existing `SyncFailed` status + Settings "Retry" row as the canonical control;
  the badge is an additional always-visible cue, non-nagging.

### Claude's Discretion (resolve in research/planning)
- Exact sign-in seam for the auto-restore trigger and the once-per-sign-in guard
  (transition listener vs `signIn()` callback vs a first-sign-in signal flag).
- Time-overlap matching rule/threshold for D-03 (the riskiest heuristic).
- Field-by-field merge granularity and which fields are user-mergeable.
- The `kFailedAutoRetryWindow` value and whether the last-auto-retry timestamp is
  in-memory or persisted.
- Badge/banner placement (dashboard header vs shell) — pick one always-visible
  guest+signed-in surface.
- Whether the merge/reconciliation work is large enough to be its own plan(s)
  within the phase (likely yes — treat it as the phase's centre of gravity).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Sync engine + restore (the core surfaces this phase extends)
- `lib/sync/sync_engine.dart` — triggers (post-save rising edge ~L316, connectivity ~L322, resume ~L331), `processPending()`, `retryFailed()` (~L294, the auto-retry mechanism to wrap), backoff window, failure branching (`_handleFailure` ~L247: retryable vs poison-pill).
- `lib/sync/restore_controller.dart` — `restore()` download+`insertOrIgnore` dedupe; sealed `RestoreState`. Extend for conflict detection + reconciliation.
- `lib/sync/api_client.dart` — `restoreTrips()` (returns `List<TripsCompanion>` already mapped), `syncTrips()`, `deleteTrip()`, `SyncException` (`retryable`/`notSignedIn`).
- `lib/sync/sync_status.dart` — sealed `SyncStatus` (`SyncSynced/Syncing/Failed/Offline`), `SyncStatusNotifier`; basis for the stuck badge (D-09).
- `lib/sync/trip_serializer.dart` — JSON↔Trip mapping; needed for field-by-field compare/merge (D-06).

### DAOs + DB
- `lib/database/daos/trips_dao.dart` — `insertOrIgnoreTrips`, `findById`, `updateTrip`/edit path (re-queue), `backfillUserId`. Conflict merge writes go through the update path.
- `lib/database/daos/sync_queue_dao.dart` — `getPending`, `watchPending`, `markFailed`, `resetFailed`, `countFailed`, `incrementRetry`, `enqueueUpdate`.
- `lib/database/database.dart` — schema version (if a merge/auto-retry state column or timestamp needs persistence, a migration is required; follow the snapshot + migration-test convention).
- `lib/config/constants.dart` — `kSyncQueueMaxRetries`, `kSyncRetryBaseDelay`, `kSyncRetryMaxDelay`, `kMaxSyncBatchTrips`, `kDefaultUserId`. Add `kFailedAutoRetryWindow` here (no hardcoded values).

### Settings UI (existing manual restore/retry surfaces to integrate with)
- `lib/features/settings/widgets/restore_row.dart` — manual restore row + outcome messaging (reuse copy/patterns for the auto-restore toast).
- `lib/features/settings/screens/settings_screen.dart` — account + sync-status + retry rows.

### Sign-in seam + prior-phase decisions
- `lib/features/auth/services/auth_service.dart` — `signIn()` (Step 6 backfill; first-sign-in signal). Auto-restore trigger hangs off this transition.
- `lib/features/auth/providers/auth_providers.dart`, `lib/features/auth/models/auth_state.dart` — sealed `AuthLoading/Guest/SignedIn`.
- `.planning/phases/20-first-run-login-skip/20-CONTEXT.md` — Phase 20 owns the UPLOAD side on sign-in (D-08 reconcile pending `local_user` queue items → uid, D-09 enqueue guest backlog). Phase 24 is the DOWNLOAD/reconcile complement — MUST stay consistent with these.
- `.planning/phases/11-sync-engine/11-CONTEXT.md` — original sync engine + restore decisions (one-way, client-authoritative). Phase 24 D-06 consciously revises the "no conflict resolution" stance for restore-time only.

### Requirements / roadmap
- `.planning/REQUIREMENTS.md` — SYNC-04, SYNC-05 (and SYNC2-01 in v2 — keep the two-way distinction).
- `.planning/ROADMAP.md` — Phase 24 SC#1–5. (CLAUDE.md "Client always wins / no conflict resolution" is intentionally overridden for restore-time reconciliation — note in the plan.)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RestoreController.restore()` + `TripsDao.insertOrIgnoreTrips` — the entire download+dedupe path exists; auto-restore = trigger it + branch into conflict detection before/around the insert.
- `SyncEngine.retryFailed()` — exact mechanism for auto-retry (clear backoff → resetFailed → drain); wrap with the D-07 time-gate.
- Sealed-state pattern (`SyncStatus`, `RestoreState`) — extend with conflict/auto-retry states; never raw strings (CLAUDE.md).
- `restore_row.dart` outcome messaging — reuse copy for the auto-restore toast (D-05).
- Phase 19 edit→re-queue path — model for D-06 cloud-overwrite re-queueing.

### Established Patterns
- Manual Riverpod `Notifier`/`Provider` (no codegen — drift_dev/analyzer pin); keepAlive providers. New controllers follow this.
- Triggers are fire-and-forget, never block UI; failures map to sealed status, never leak `error.toString()` (PII guard) — preserve in all new paths.
- Schema changes require a version bump + drift snapshot + migration test.

### Integration Points
- Auth sign-in transition → auto-restore (new).
- Restore download → conflict detector → reconciliation UI → trips DAO (insert for non-conflicts, update for "use cloud"/merge, which re-queues).
- Connectivity/resume triggers → time-gated auto-retry of failed rows (new gate around existing `retryFailed`).
- `SyncStatus`/failed count → dashboard stuck badge/banner (new UI).

</code_context>

<specifics>
## Specific Ideas

- User explicitly wants restore to be a **merge experience**, not silent
  overwrite: "identify duplicates or overlap and give user option to merge,
  override, or keep local." This is the headline feature — treat the conflict
  detection + reconciliation UI as the phase's core deliverable, not a footnote.
- Auto-retry should be persistent in intent ("auto-retry everything") but the
  user accepted time-gating to avoid hammering the server — balance reliability
  with not spamming a permanent failure.
- Stuck items should be **noticeable** (badge/banner), not buried in settings.

</specifics>

<deferred>
## Deferred Ideas

- **Continuous two-way / multi-device live sync** (server→client streaming) —
  SYNC2-01, stays in v2. The reconciliation here is sign-in/restore-time only.
- **Notification-on-give-up for permanently failed items** — considered for D-09;
  chose the in-app badge/banner instead. Revisit if users miss stuck items.
- **New-device detection via device id** (device_info_plus) — considered for the
  restore trigger; superseded by "every sign-in + idempotent detection" (D-01).
- **Interrupted-trip recovery** — now Phase 25 (force-quit/OS-kill mid-trip
  detection + resume/discard), TRACK-13.

</deferred>

---

*Phase: 24-automatic-cloud-sync-restore*
*Context gathered: 2026-06-06*
