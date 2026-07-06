# Phase 24: Automatic Cloud Sync & Restore - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-06
**Phase:** 24-automatic-cloud-sync-restore
**Areas discussed:** Phase scope vs Phase 11, Phase structure (split), Restore trigger, Restore UX, Auto-retry policy, Stuck surfacing, Conflict scope, Resolution UX

---

## Phase scope vs completed Phase 11

Phase 11 (Sync Engine) already auto-syncs trips, retries 3× with backoff, and offers manual restore. Asked what the new phase adds.

**User's choice:** Auto-restore on sign-in + Auto-retry failed syncs + (free text) "i want the trip to be synced as soon as it is finished. Also i want the app to detect app closes due to force quit or app clear or os level interruptions. Log that and give a user option to resume the trip once he logs back in."
**Notes:** Trip-finish sync found to be already wired (rising-edge nudge). The force-quit/resume request is a different domain (active-trip durability), split out.

---

## Phase structure (split)

| Option | Description | Selected |
|--------|-------------|----------|
| Two phases | Phase 24 cloud sync/restore + Phase 25 interrupted-trip recovery | ✓ |
| One combined phase | All four capabilities in a single phase | |

**User's choice:** Two phases (recommended)
**Notes:** Crash-recovery lives in the tracking layer, not the sync layer — separate concern. Phase 25 added to roadmap (TRACK-13).

---

## Restore trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Every sign-in | Run once per successful sign-in; safe via dedupe | (superseded) |
| Only when local DB empty | Auto-restore only on fresh install/new device | |
| New-device detection | Track device id, restore only on unsynced device | |

**User's choice:** Free text — "i want it to give an option to merge cloud with local. identify duplicates or overlap and give user option to merge, override or keep local, etc."
**Notes:** Major change — turns silent dedupe restore into a conflict detection + reconciliation flow. Departs from client-authoritative architecture. Trigger timing resolved as "every sign-in" (idempotent via detection); the merge requirement drove follow-up questions below.

---

## Restore UX

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle indicator + outcome toast | Non-blocking spinner + "Restored N trips" toast; errors quiet | ✓ |
| Fully silent | Background, no UI | |
| Blocking progress on first run | "Restoring…" screen before app on fresh install | |

**User's choice:** Subtle indicator + outcome toast
**Notes:** Conflict UI appears only when conflicts exist; clean restore stays silent except the toast.

---

## Auto-retry policy

| Option | Description | Selected |
|--------|-------------|----------|
| Retry network-failures, leave poison pills | Auto-retry transient fails only; 400s stay manual | |
| Auto-retry everything, time-gated | Retry all failed items at most once per long window | ✓ |
| Auto-retry everything, every trigger | Reset+retry all on every connectivity/resume | |

**User's choice:** Auto-retry everything, time-gated
**Notes:** Balances "retry everything" intent with not hammering a permanent failure. New constant `kFailedAutoRetryWindow`.

---

## Stuck surfacing

| Option | Description | Selected |
|--------|-------------|----------|
| Keep settings status + manual retry | Existing SyncFailed + Settings Retry row only | |
| Add a visible badge/banner | Dismissible badge/banner linking to retry | ✓ |
| Notification on give-up | Local notification when an item permanently fails | |

**User's choice:** Add a visible badge/banner
**Notes:** Keeps the settings retry as canonical control; badge is an additional always-visible cue.

---

## Conflict scope (follow-up on merge)

| Option | Description | Selected |
|--------|-------------|----------|
| Same-UUID differences only | Flag only same-UUID trips with differing fields; exact | |
| Same-UUID + time overlap | Also detect different-UUID trips with overlapping times; fuzzy | ✓ |

**User's choice:** Same-UUID + time overlap
**Notes:** Requires an overlap heuristic/threshold — flagged as the riskiest part to research.

---

## Resolution UX (follow-up on merge)

| Option | Description | Selected |
|--------|-------------|----------|
| Bulk choice + per-trip override | Summary with bulk actions, expandable per-trip | ✓ |
| Per-trip prompt only | One trip at a time | |
| Bulk choice only | Single decision for all conflicts | |

**User's choice:** Bulk choice + per-trip override (recommended)
**Notes:** Keep all local / Use all cloud / Merge, expandable to individual trips (incl. field-by-field).

---

## Claude's Discretion

- Exact sign-in seam + once-per-sign-in guard for auto-restore.
- Time-overlap matching rule/threshold (riskiest heuristic).
- Field-by-field merge granularity.
- `kFailedAutoRetryWindow` value + whether last-auto-retry timestamp persists.
- Badge/banner placement.
- Whether the merge/reconciliation work becomes its own plan(s) within the phase.

## Deferred Ideas

- Continuous two-way / multi-device live sync — SYNC2-01, stays v2.
- Notification-on-give-up for permanently failed items — chose badge/banner instead.
- New-device detection via device id — superseded by every-sign-in + idempotent detection.
- Interrupted-trip recovery — moved to Phase 25 (TRACK-13).
