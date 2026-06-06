# Phase 18: Trip Pause & Breaks - Context

**Gathered:** 2026-06-06 (--auto; architecture reviewed with Gemini)
**Status:** Ready for planning

<domain>
## Phase Boundary

Add pause/resume to an active commute, with paused time excluded from all stats, persisted as editable break segments, plus an opt-in auto-pause prompt. This is the schema-affecting foundation that Phase 19 (full trip editing) builds on.

**In scope:**
- Pause/Resume an active trip without ending it; resumes as one continuous record (TRACK-09, SC#1)
- Break segments persisted per trip; saved duration + moving/stuck exclude all paused time (TRACK-09, SC#2)
- Active-tracking UI shows a distinct paused state + break count (TRACK-09, SC#3)
- Opt-in auto-pause: when an active trip looks stationary beyond a threshold, post a notification offering to pause (TRACK-10, SC#4)
- Auto-pause off by default; dismissing leaves the trip recording normally (TRACK-10, SC#5)

**Out of scope:**
- EDITING breaks (add/delete/adjust break times) — that is Phase 19 (TRACK-11). This phase only CREATES/persists breaks and shows their count.
- Geofence labeling (Phase 21), widget (Phase 22).
- iOS-specific surfaces (Live Activity pause control) — Android-first; the iOS Live Activity is paused-state-aware only insofar as it reads the same snapshot, but no new iOS native work here.

</domain>

<decisions>
## Implementation Decisions

### Break data model + duration semantics (TRACK-09, SC#2)
- **D-01:** New Drift table **`trip_breaks`** (`id` text UUID PK, `trip_id` text FK → trips.id, `start_time` dateTime UTC, `end_time` dateTime UTC nullable-while-open). Normalized 1:N — required because Phase 19 must edit individual segments (JSON column rejected per Gemini: targeted updates + cross-trip queries become painful). FK enforced (PRAGMA foreign_keys already ON).
- **D-02:** Add **`total_paused_seconds`** integer column (default 0) to the `trips` table — denormalized aggregate so the daily-log/list and stats render without a JOIN. Written at finalize.
- **D-03:** Redefine `trips.duration_seconds` to mean **ACTIVE duration = wall-clock (end−start) − total_paused_seconds**. Safe for all existing v1/v2 rows: with no breaks, active == wall-clock, so historical rows are unchanged (total_paused_seconds defaults 0). Moving/stuck already exclude paused intervals (D-05), so existing stats queries need no change.
- **D-04:** Schema bump **v2 → v3**. Migration `onUpgrade from<3`: `m.createTable(tripBreaks)` + `m.addColumn(trips, trips.totalPausedSeconds)`. Follow the existing `addColumn` migration pattern in `database.dart`. A new DAO (`trip_breaks_dao.dart`) + wire into AppDatabase. Add a schema v3 snapshot/test mirroring the existing schema-test convention.

### Accumulator pause behavior (TRACK-09, SC#1/2)
- **D-05:** `TripAccumulator` gains `isPaused` + `_currentPauseStart` + accumulated prior-pause duration + a list of completed `(start,end)` break segments. `pause(at)` sets the flag and records pause start; `resume(at)` closes the segment and adds to accumulated paused time. While `isPaused`, `addSample` STILL appends the position to `_samples` (so the polyline bridges the gap naturally — last-pre-pause → first-post-resume draws a straight line) BUT contributes **no distance, no moving/stuck time** (early-return after the polyline append, before distance/time attribution).
- **D-06:** `snapshot.elapsedSeconds = (isPaused ? _currentPauseStart : now) − startedAt − accumulatedPausedSeconds` — freezes the displayed timer the instant pause fires (Gemini). Snapshot gains **`isPaused` (bool)** and **`pausedSeconds` (int)** and **`breakCount` (int)** fields (primitive-safe for the isolate channel — extend `TripSnapshot.toMap`/`fromMap`).
- **D-07:** `finalize(endedAt)`: if currently paused, close the open segment at `endedAt`. Compute `durationSeconds = (end−start).inSeconds − totalPausedSeconds`. Emit the break segments on the `FinalizedTrip` DTO (new `breaks` field, primitive list in `toMap`) so the persist path can write `trip_breaks` rows + `total_paused_seconds`. `timeMoving + timeStuck` already exclude paused intervals.

### Cross-isolate pause/resume commands (TRACK-09, SC#1)
- **D-08:** Mirror the existing Stop command path: UI isolate calls `service.invoke(kTrackingPauseCommand)` / `kTrackingResumeCommand`; the service isolate handler calls `accumulator.pause/resume(DateTime.now().toUtc())`. Add the two event-name constants to `constants.dart`. The UI is a **dumb terminal** — it never runs a local pause timer; it reflects whatever the latest snapshot's `isPaused`/`pausedSeconds` says (Gemini). This gives free recovery after backgrounding/kill: the UI reconnects to the service stream and the first snapshot dictates the paused/resume UI state.

### Active-tracking UI (TRACK-09, SC#3)
- **D-09:** On `_HeroActive` (in `hero_record_card.dart` — the PRODUCTION active surface; `tracking_active_layout.dart` is dead, do not touch), add a **Pause/Resume** button (toggles by `snapshot.isPaused`) and a distinct **PAUSED** visual state (e.g. dim/badge + frozen timer) plus a **break count** indicator ("2 breaks"). Keep widgets <100 lines (extract a `pause_resume_button.dart` / paused-state treatment as needed). Reuse Traevy tokens.

### Auto-pause prompt (TRACK-10, SC#4/5)
- **D-10:** **Opt-in, OFF by default.** Add `autoPauseEnabled` boolean column to `user_preferences` (default false) in the SAME v3 migration, plus settings toggle. (Threshold: a `kAutoPauseStationaryThresholdSeconds` constant, default **15 minutes**.)
- **D-11:** **Detect via continuous STUCK time, not raw speed** (Gemini — protects the app's core stuck-time metric): the service tracks an uninterrupted stuck streak; stop-and-go micro-movements break the streak and prevent false positives. When the streak exceeds the threshold (and auto-pause is enabled and the trip is not already paused), post a notification.
- **D-12:** **ONLY PROMPT — never auto-pause** (Gemini — silent pause risks data loss in tunnels/urban canyons). The notification carries a **"Pause" action button** that fires the same `kTrackingPauseCommand` path (reuse the existing `AndroidNotificationAction` + `_onForegroundResponse`/background-handler wiring already used for the Stop action). Dismissing/ignoring leaves the trip recording normally. Fire at most once per stationary streak (re-arm only after movement resumes).

### Claude's Discretion (resolve in planning)
- Exact `trip_breaks` DAO surface (insert-batch at finalize vs incremental) — finalize-time batch insert is sufficient (no incremental persistence, matching accumulator D-06 "samples live in memory only").
- Whether `total_paused_seconds` also feeds an updated stats query, or stays display-only for now (stats already key off moving/stuck) — keep display-only unless a stat visibly double-counts.
- Paused-state visual design specifics within Traevy tokens.
- Whether the sync payload (`sync_queue`/Cloud Function) needs the breaks — breaks are local-only this phase unless trivial to include; flag if the sync DTO must change (prefer NOT changing the backend contract this phase; note for a later sync phase).

</decisions>

<canonical_refs>
## Canonical References

- Accumulator: `lib/features/tracking/services/trip_accumulator.dart` (`TripSnapshot`, `addSample`, `snapshot`, `finalize`)
- Finalized DTO: `lib/features/tracking/state/finalized_trip.dart`
- Tracking service isolate + commands: `lib/features/tracking/services/tracking_service.dart`, `tracking_service_events.dart`, `tracking_service_controller.dart`
- Notifier (UI isolate): `lib/features/tracking/providers/tracking_providers.dart`
- Active UI surface: `lib/features/dashboard/widgets/hero_record_card.dart` (`_HeroActive`)
- Notification + action buttons (Stop pattern to mirror for Pause action): `lib/features/tracking/services/tracking_notification_service.dart` (`AndroidNotificationAction`, `_onForegroundResponse`, `trackingNotificationBackgroundHandler`)
- DB + migration: `lib/database/database.dart` (schemaVersion 2, onUpgrade pattern), `lib/database/tables/trips_table.dart`, `lib/database/tables/user_preferences_table.dart`, `lib/database/daos/`
- Constants: `lib/config/constants.dart` (`kStuckSpeedThresholdMs`, intervals; add pause command names + auto-pause threshold)
- Requirements: TRACK-09, TRACK-10. ROADMAP Phase 18 SC#1–5.

</canonical_refs>
