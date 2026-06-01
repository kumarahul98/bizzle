---
title: "Bug: Manual entry missing traffic time and distance fields"
type: bug
area: trips
severity: medium
created: 2026-04-28
phase_hint: 7
status: resolved
resolved: 2026-06-01
resolved_by: 0b225a2
---

## Resolution (2026-06-01)

Already fixed by commit `0b225a2 fix(07-04): ManualEntrySheet traffic/distance
fields + stats exclusion fix` during Phase 7 work. This todo (filed 2026-04-28)
was simply never closed. Verified all three layers the todo named:

- **UI** — `manual_entry_sheet.dart` collects optional "Time in traffic (HH:MM)"
  and "Distance (km)" fields, both defaulting to 0 when blank.
- **Provider** — `insertManualTrip` accepts/clamps `timeStuckSeconds` and
  `distanceMeters`, computes `timeMovingSeconds = durationSeconds - clampedStuck`.
- **Stats** — `stats_service.dart` implements the requested "D-05 refined" rule:
  exclude manual trips from `weekStuckSeconds` ONLY when both traffic and
  distance are blank (`isManualEntry && timeStuckSeconds == 0 && distanceMeters == 0`).

Test coverage confirmed green (23 tests): `stats_service_test.dart` has a
dedicated "STAT-05 refined manual exclusion (D-05)" group covering blank-excluded,
traffic-included, and distance-included cases; `manual_entry_notifier_test.dart`
covers the insert path. No code change needed.

## Problem

The "Add missed commute" sheet (`lib/features/trips/widgets/manual_entry_sheet.dart`) only collects:
- Date
- Duration (HH:MM)
- Direction (to_office / to_home)

It saves `timeMovingSeconds=0`, `timeStuckSeconds=0`, `distanceMeters=0` for all manual entries. This means:

1. **STAT-05 (time in traffic) excludes all manual trips** — the stats logic in Phase 5 deliberately filters manual entries because their traffic fields are zero. If a user manually logs a commute where they sat in traffic for 30 mins, that 30 mins is never counted.

2. **Dashboard weekly card traffic row is wrong** — `weekStuckSeconds` undercounts for users who manually log trips.

3. **Trip detail screen shows 0 for distance and traffic** — correct currently (user didn't enter it) but unintuitive.

## Expected Behavior

The manual entry sheet should optionally allow users to enter:
- **Time stuck in traffic** (optional, defaults to 0) — e.g. a duration field "Time in traffic: 0:20"
- **Distance** (optional, defaults to 0) — e.g. a numeric field in km

If these fields are populated, the stats engine should include the manual trip in STAT-05 (current logic excludes manual entries only because timeStuckSeconds=0 — need to revisit that assumption).

## Impact

- `lib/features/trips/widgets/manual_entry_sheet.dart` — add optional traffic + distance fields
- `lib/features/stats/services/stats_service.dart` — revisit STAT-05 exclusion logic (D-05 from Phase 5 CONTEXT.md: currently excludes all manual trips from traffic stats; after fix should only exclude manual trips where timeStuckSeconds is genuinely 0 because user left it blank vs GPS trips where 0 is computed)
- `lib/features/stats/providers/stats_providers.dart` — no change needed if stats_service handles it

## Notes

- Phase 5 D-05 explicitly documents the exclusion as intentional (manual trips have 0 traffic by design). This todo changes that design intent.
- `routePolyline` stays empty for manual entries (no GPS) — do NOT add a polyline input field.
- Fields should be optional — user should not be forced to enter traffic time.
