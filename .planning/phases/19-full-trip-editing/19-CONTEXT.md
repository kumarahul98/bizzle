# Phase 19: Full Trip Editing - Context

**Gathered:** 2026-06-06 (--auto; recompute model reviewed with Gemini)
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the existing trip edit sheet so EVERY time-based detail is editable — start time, end time, and individual break segments — with duration and traffic stats recomputed consistently, validation that blocks impossible edits, and the edited trip re-queued for sync. Builds directly on Phase 18's `trip_breaks` table + active-duration semantics.

**In scope:**
- Edit start_time + end_time (date AND time-of-day) (TRACK-11, SC#1)
- Add / edit / remove individual break segments (TRACK-11, SC#2)
- Recompute total duration + moving/stuck breakdown from the new times/breaks, shown consistently (TRACK-11, SC#3)
- Validation: end>start, breaks within window, no overlapping/touching breaks — rejected with clear feedback, never persisted (TRACK-11, SC#4)
- Edited trip re-enters the one-way sync queue (TRACK-11, SC#5)

**Out of scope:**
- Editing the route polyline / distance (no map editing — distance stays as recorded; only time-based fields are editable)
- Creating breaks DURING recording (Phase 18 owns live pause); this phase edits breaks AFTER the fact
- Geofence labeling (Phase 21), widget (Phase 22)
- Changing the backend sync contract — reuse the existing update→sync_queue path (breaks themselves stay local per Phase 18; only the trip-row fields sync)

</domain>

<decisions>
## Implementation Decisions

### Moving/stuck recomputation (TRACK-11, SC#3) — raw speed samples are GONE
- **D-01:** **Proportional rescaling preserving the original moving:stuck ratio.** new_active = (end−start) − Σbreaks. `ratio = origMoving / (origMoving + origStuck)`; new_moving = round(new_active × ratio); new_stuck = new_active − new_moving. This is the only model that keeps `moving + stuck == active_duration` after edits without inventing a fabricated per-second timeline (Gemini).
- **D-02:** **0/0 stays 0** — if origMoving+origStuck == 0 (manual entries, no GPS), keep both 0; never invent a ratio. (duration_seconds still = new_active.)
- **D-03:** Expanding (extend end) or shrinking applies the ratio blindly — accepted assumption; transparency is handled by D-04.
- **D-04:** Add an **`is_edited` boolean** column to `trips` (default false), set true on any successful edit. The trip detail/stats UI shows a subtle **"~ estimated"** hint next to the moving/stuck figures when `is_edited` is true — we are deriving, not measuring, and owe the user honesty (Gemini). Schema bump **v3 → v4** (single `addColumn`, default false → existing rows unaffected; v4 schema snapshot + migration test per the established convention).

### Break validation (TRACK-11, SC#4)
- **D-05:** Window: `break.start >= trip.start` AND `break.end <= trip.end` — breaks MAY touch the exact trip start/end boundary (waiting in the car is legitimate).
- **D-06:** Duration: `break.start < break.end` strictly (>0 seconds).
- **D-07:** **Reject overlapping AND touching** breaks: for sorted breaks, require `prev.end < next.start` strictly. Two breaks sharing a boundary are logically one continuous break — force the user to edit the existing one rather than fragmenting DB rows.
- **D-08:** Validation runs in-memory on every change; the Save button is disabled (with an inline message naming the specific problem) until all rules pass. Nothing invalid is ever written.

### start/end + date editing (TRACK-11, SC#1)
- **D-09:** Allow full **DateTime** editing (date + time) — users log late or drive past midnight. Replace the time-only `showTimePicker`-only flow with date+time pickers (showDatePicker → showTimePicker, or equivalent), still storing UTC, displaying local.
- **D-10:** Breaks are **absolute wall-clock events** — do NOT proportionally stretch/squash them when the window changes. On window shrink: a break partially outside the new window is **clamped** to the boundary; a break entirely outside is **dropped**. Surface a one-line snackbar: "Some breaks were adjusted to fit the new trip times." (A pure ±24h date shift of the whole trip shifts breaks by the same delta — optional nicety, Claude's discretion.)

### Recompute timing + persistence (TRACK-11, SC#3/5)
- **D-11:** **Live in-memory preview**: the edit sheet recomputes active duration + moving/stuck split as the user edits (immediate feedback), with NO Drift writes during editing.
- **D-12:** **On Save: one atomic Drift transaction** — (1) update the trip row (new start/end, recomputed duration_seconds/total_paused_seconds/time_moving_seconds/time_stuck_seconds, is_edited=true), (2) DELETE existing trip_breaks for the trip, (3) INSERT the validated/clamped breaks, (4) enqueue the sync-queue update event (reuse the existing `editTrip`→sync path). All-or-nothing.

### Claude's Discretion (resolve in planning)
- The break-list editor UI within the edit sheet (rows with start/end pickers + add/remove) — keep each widget <100 lines; extract a `break_editor_list.dart` / `break_row.dart`.
- Whether the edit sheet grows tall enough to need a scrollable sheet / DraggableScrollableSheet.
- The exact "~ estimated" hint affordance (tooltip vs inline tilde) consistent with Traevy tokens.
- Whether the ±24h whole-trip date-shift convenience (re-anchor breaks) is worth including or deferred (clamp/drop is the safe default).
- Extending `editTrip` signature vs a new `editTripFull` method — prefer extending with optional params to keep one write path.

</decisions>

<canonical_refs>
## Canonical References

- Existing edit sheet (extend this): `lib/features/trips/widgets/edit_trip_sheet.dart` (direction + time-of-day today; `editTrip(tripId, direction, startTimeUtc, endTimeUtc)`)
- Trip management write/sync path: `lib/features/trips/providers/trip_management_providers.dart` (`editTrip`, TripManagement states), `lib/database/daos/trips_dao.dart`
- Breaks table + DAO (Phase 18): `lib/database/tables/trip_breaks_table.dart`, `lib/database/daos/trip_breaks_dao.dart`
- Trips table + migration: `lib/database/tables/trips_table.dart`, `lib/database/database.dart` (schemaVersion 3 → bump to 4), `drift_schemas/`, `test/generated_migrations/`
- Sync enqueue on edit: `lib/database/daos/sync_queue_dao.dart` / wherever `editTrip` enqueues the update
- Stats display surfaces (show "~ estimated"): `lib/features/trips/screens/` trip detail, `lib/shared/widgets/trip_row_card.dart`
- Constants: `lib/config/constants.dart`
- Requirements: TRACK-11. ROADMAP Phase 19 SC#1–5.

</canonical_refs>
