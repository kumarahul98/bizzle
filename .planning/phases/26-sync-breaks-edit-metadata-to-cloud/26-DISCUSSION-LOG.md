# Phase 26: Sync Breaks & Edit Metadata to Cloud - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-12
**Phase:** 26-sync-breaks-edit-metadata-to-cloud
**Areas discussed:** Backfill scope & trigger, Breaks in the merge flow, Breaks for existing trips on restore

---

## Backfill scope & trigger

### Which local trips should the one-time backfill re-upload to the cloud?

| Option | Description | Selected |
|--------|-------------|----------|
| Any non-default metadata (Recommended) | Trips with breaks, isEdited=true, OR a non-default directionSource — uploads exactly what's needed | ✓ |
| Breaks or edits only | Literal roadmap wording (SC4); geofence-labeled trips keep incomplete cloud copies unless edited later | |
| Re-upload all trips | Simplest query, uniform cloud data, bigger one-time burst | |

**User's choice:** Any non-default metadata
**Notes:** User first picked "Re-upload all trips", then interrupted to ask what "re-enqueue" means. After a plain-language explanation of the sync-queue design (enqueue = mark for upload; payload read fresh at sync time; upsert-by-UUID makes re-upload harmless), the question was re-asked with clearer wording and the user chose the recommended need-based selection.

### When should the one-time backfill run?

| Option | Description | Selected |
|--------|-------------|----------|
| App startup after upgrade (Recommended) | One-time startup check; works for already-signed-in users without waiting for a sign-in event | |
| First sign-in after upgrade | Ties backfill to a sign-in transition | ✓ |
| You decide | Planning picks the exact trigger seam | |

**User's choice:** First sign-in after upgrade
**Notes:** Interpreted (and stated back to the user) as the same AuthLoading/AuthGuest → AuthSignedIn transition seam Phase 24's auto-restore uses — it also fires on session restore at launch, closing the "already signed in" gap flagged in the option description.

### How should the app remember that the one-time backfill already ran?

| Option | Description | Selected |
|--------|-------------|----------|
| user_preferences column (Recommended) | Plain boolean/timestamp column; schema bump + migration test | |
| Version-keyed marker | "Backfill done for payload schema v2" — future-proof for later backfill waves | ✓ |
| You decide | Any persistent, non-repeating mechanism | |

**User's choice:** Version-keyed marker

---

## Breaks in the merge flow

### In a mixed field-by-field merge, whose break segments (and paused total) does the merged trip keep?

| Option | Description | Selected |
|--------|-------------|----------|
| Follow the time fields (Recommended) | Breaks ride with whichever side won startTime/endTime; breaks never fall outside the merged window; paused total travels with breaks | ✓ |
| Always keep local breaks | Matches 25.1 local-first defaults but breaks could sit outside a cloud-times window | |
| Follow the bulk choice | Breaks come from the bulk-level side regardless of per-field toggles | |

**User's choice:** Follow the time fields

### Should the new metadata fields appear as rows in the conflict/merge sheet?

| Option | Description | Selected |
|--------|-------------|----------|
| No new rows (Recommended) | Sheet unchanged; metadata rides along invisibly | |
| Show a breaks indicator | Read-only line when sides differ (e.g. "Local: 2 breaks · Cloud: none"); no per-break controls | ✓ |
| Full mergeable rows | Toggleable rows for paused total / directionSource; most UI work | |

**User's choice:** Show a breaks indicator

### Do the deferred merge-logic refactor (extract into a pure, testable function) as part of this phase?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, extract first (Recommended) | Extract _applyAll resolution into a pure function, pin with unit tests, then add ride-along rules | ✓ |
| Minimal diff, no refactor | Add ride-along inside widget logic; tested only via widget tests | |
| You decide | Planning judges once the diff is visible | |

**User's choice:** Yes, extract first

### Should differences in the new metadata fields trigger a same-UUID conflict during restore?

| Option | Description | Selected |
|--------|-------------|----------|
| No — metadata never conflicts (Recommended) | Only the original five fields trigger conflicts; metadata resolves silently (local wins, backfill pushes up); no post-upgrade conflict storm | ✓ |
| Yes — full fidelity | Any difference flags a conflict; guaranteed noisy prompts right after upgrade | |
| Metadata conflicts only if a core field also differs | Middle ground: silent alone, included when a real conflict fires | |

**User's choice:** No — metadata never conflicts

---

## Breaks for existing trips on restore

### When restore finds an existing local trip that has NO breaks while the cloud copy has them, should it adopt the cloud breaks?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — enrich when local is empty (Recommended) | Attach cloud breaks (and paused total) when local has none; nothing overwritten | ✓ |
| No — fresh inserts only | Today's behavior; pre-upgrade restored trips stay breakless | |

**User's choice:** Yes — enrich when local is empty

### Should the same enrichment apply to the other metadata (directionSource, isEdited) when local holds defaults?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — uniform enrichment rule (Recommended) | One rule for all four metadata fields: adopt cloud's value when local is default/empty | ✓ |
| Breaks only | Narrower touch; labels stay incomplete | |
| You decide | Planning picks per-field | |

**User's choice:** Yes — uniform enrichment rule

---

## Claude's Discretion

- Marker set-timing (enqueue time vs after upload) — persistent queue makes enqueue-time natural.
- Backfill burst handling (existing batch caps suffice).
- Whether enrichment writes bypass the sync re-queue (redundant-but-harmless upload).
- Exact breaks-array cap value (~50) and break-UUID round-trip vs regeneration.
- Edit-flow paused-time recompute (roadmap SC3) implementation.
- `isEdited` value on a merged row (auto-resolve).
- Copy/placement of the breaks indicator line.

## Deferred Ideas

- Overlap-conflict UUID semantics rework (carried from 25.1).
- "Highlight differing fields only" merge UI (carried from 25.1).
