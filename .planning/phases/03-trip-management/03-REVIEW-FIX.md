---
phase: 03-trip-management
fixed_at: 2026-04-25T00:00:00Z
fix_scope: critical_warning
findings_in_scope: 3
fixed: 3
skipped: 0
iteration: 1
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed:** 2026-04-25
**Scope:** Critical + Warning
**Findings in scope:** 3

## Applied Fixes

### WR-01: Zero-duration manual entry not rejected

**Status:** Fixed
**Commit:** fix(03): WR-01 reject zero-duration manual entry in parseHhMm
**Files modified:** `lib/features/trips/providers/trip_management_providers.dart`, `lib/features/trips/widgets/manual_entry_sheet.dart`, `test/unit/features/trips/manual_entry_notifier_test.dart`

`parseHhMm` now builds the `Duration` and returns `null` when it equals `Duration.zero`, so `'0:00'` produces null and `isFormValid` stays false. The validation error message in the sheet was updated to tell the user the minimum is `0:01`. The test that previously asserted `parseHhMm('0:00') == const Duration()` was updated to assert `isNull`.

### WR-02: Edit sheet allows equal start and end time (durationSeconds = 0)

**Status:** Fixed
**Commit:** fix(03): WR-02 reject equal start and end time in edit sheet
**Files modified:** `lib/features/trips/widgets/edit_trip_sheet.dart`

Both time-error conditions in `_pickStartTime` and `_pickEndTime` were changed from `isBefore` to `!isAfter`. This rejects both `end < start` and `end == start`, preventing a zero-duration trip row from being persisted through the edit flow.

### WR-03: `eveningCutoffHour` stored but never consumed

**Status:** Fixed
**Commit:** fix(03): WR-03 implement eveningCutoffHour in DirectionLabelService
**Files modified:** `lib/features/trips/services/direction_label_service.dart`, `lib/features/tracking/providers/backfill_provider.dart`, `lib/features/tracking/services/tracking_service_controller.dart`, `lib/features/trips/widgets/manual_entry_sheet.dart`, `test/unit/features/trips/direction_label_service_test.dart`

`DirectionLabelService.label` was updated to accept a third parameter `eveningCutoffHour` and applies the full two-cutoff rule: `hour < morningCutoffHour` → `to_office`, `hour >= eveningCutoffHour` → `to_home`, between the two cutoffs → `to_home` (ambiguous, default). All three call sites (`backfill_provider.dart`, `tracking_service_controller.dart`, `manual_entry_sheet.dart`) were updated to pass the third argument. The `manual_entry_sheet.dart` `initState` default uses `kDefaultDirectionCutoffHour` for both parameters since it has no DB access at that point. Tests were expanded to cover the two-cutoff rule and the same-cutoff edge case.

## Skipped Findings

None.

## Info Findings (Out of Scope)

IN-01 and IN-02 were not fixed (fix_scope = critical_warning).

---

_Fixed: 2026-04-25_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
