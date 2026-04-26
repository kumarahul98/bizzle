---
phase: "05-stats-analytics"
plan: "03"
subsystem: "stats-widgets"
tags: [flutter, stats, ui, material3, stateless-widgets]
dependency_graph:
  requires: ["05-02"]
  provides: ["StatsCard", "WeekMonthTotalsCard", "DirectionAveragesCard", "TrafficWasteCard"]
  affects: ["05-05"]
tech_stack:
  added: []
  patterns:
    - "StatelessWidget stat cards receiving primitives via constructor"
    - "Private _k-prefixed layout constants per file"
    - "StatsCard shared wrapper: Card(surfaceContainerLow) + padding + title + child slot"
    - "Null-guarded formatDuration with kStatsEmptyPlaceholder fallback"
key_files:
  created:
    - lib/features/stats/widgets/stats_card.dart
    - lib/features/stats/widgets/week_month_totals_card.dart
    - lib/features/stats/widgets/direction_averages_card.dart
    - lib/features/stats/widgets/traffic_waste_card.dart
  modified: []
decisions:
  - "StatsCard title uses titleMedium w600 matching UI-SPEC §Typography for card headings"
  - "WeekMonthTotalsCard: zero values render as kStatsEmptyPlaceholder — consistent with D-10 (no trips = no data)"
  - "DirectionAveragesCard: private _DirectionRow extracted within same file — stays under 100-line limit without extra file"
  - "CrossAxisAlignment.center removed from Row in _DirectionRow — it is the default value (very_good_analysis avoid_redundant_argument_values)"
metrics:
  duration_seconds: 143
  completed_date: "2026-04-26"
  tasks_completed: 2
  files_changed: 4
---

# Phase 05 Plan 03: Stats Simple Cards Summary

Four read-only StatelessWidget stat cards built with Material 3 tokens, all strings from constants.dart, all colors from Theme.of(context).colorScheme.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | StatsCard wrapper + WeekMonthTotalsCard + TrafficWasteCard | 3e4b44a | stats_card.dart, week_month_totals_card.dart, traffic_waste_card.dart |
| 2 | DirectionAveragesCard | 8401d1c | direction_averages_card.dart |

## Artifacts

### lib/features/stats/widgets/stats_card.dart — 56 lines
Reusable Card wrapper. `Card(color: surfaceContainerLow)` + 16px padding + `Column(title, SizedBox(8), child)`. Title rendered as `titleMedium w600`. No `InkWell`, no taps — read-only per UI-SPEC.

### lib/features/stats/widgets/week_month_totals_card.dart — 75 lines
STAT-01 card. Wraps `StatsCard(title: kStatsCardWeekLabel)`. Renders `weekTotalSeconds` and `monthTotalSeconds` via `formatDuration`, falling back to `kStatsEmptyPlaceholder` for zero values. Week helper "Mon–Sun" in `bodyMedium onSurfaceVariant`.

### lib/features/stats/widgets/direction_averages_card.dart — 87 lines
STAT-02 card. Wraps `StatsCard(title: kStatsCardDirectionTitle)`. Two `_DirectionRow` widgets: `Row(Expanded(label) + Text(value))` layout so labels left-align and values right-align. Nullable `int?` averages render as `kStatsEmptyPlaceholder`. Private `_DirectionRow` defined in same file.

### lib/features/stats/widgets/traffic_waste_card.dart — 51 lines
STAT-05 card. Wraps `StatsCard(title: kStatsCardTrafficTitle)`. Renders `weekStuckSeconds` via `formatDuration` with `kStatsEmptyPlaceholder` for zero. "This week" helper in `bodyMedium onSurfaceVariant`.

## Private Widgets Extracted

| Widget | File | Reason |
|--------|------|--------|
| `_DirectionRow` | direction_averages_card.dart | Repeated layout for to-office and to-home rows — extracted to eliminate duplication while staying in same file |

## Verification

- `flutter analyze lib/features/stats/`: No issues found
- `flutter test`: 170 tests passed, 0 failures, 0 regressions
- All 4 files under 100 lines
- Zero `Color(0xFF...)` literals across all 4 files
- Zero `ConsumerWidget` usage across all 4 files
- All visible strings sourced from `constants.dart` kStats* constants
- All colors sourced from `Theme.of(context).colorScheme`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unresolvable dartdoc reference in TrafficWasteCard**
- **Found during:** Task 1 — `flutter analyze` returned `comment_references` info
- **Issue:** `[computeStatsSummary]` in doc comment was a dartdoc link to a symbol not imported in the file
- **Fix:** Changed to backtick code span `` `computeStatsSummary` `` which renders correctly without an import
- **Files modified:** lib/features/stats/widgets/traffic_waste_card.dart

**2. [Rule 1 - Bug] Removed redundant CrossAxisAlignment.center from Row**
- **Found during:** Task 2 — `flutter analyze` returned `avoid_redundant_argument_values` info
- **Issue:** `crossAxisAlignment: CrossAxisAlignment.center` is the Row default value — very_good_analysis flags it
- **Fix:** Removed the redundant named argument from `_DirectionRow.build`
- **Files modified:** lib/features/stats/widgets/direction_averages_card.dart

## Known Stubs

None — all four cards receive real primitives from StatsSummary fields and render them via formatDuration.

## Threat Flags

No new security surface introduced. Read-only display widgets with no input, no auth, no network, no PII written.

## Self-Check: PASSED

- [x] lib/features/stats/widgets/stats_card.dart — FOUND
- [x] lib/features/stats/widgets/week_month_totals_card.dart — FOUND
- [x] lib/features/stats/widgets/direction_averages_card.dart — FOUND
- [x] lib/features/stats/widgets/traffic_waste_card.dart — FOUND
- [x] Commit 3e4b44a — FOUND (Task 1)
- [x] Commit 8401d1c — FOUND (Task 2)
