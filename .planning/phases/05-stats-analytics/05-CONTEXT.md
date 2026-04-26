# Phase 5: Stats & Analytics - Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can see the reality of their commute through a single scrollable stats screen: weekly and monthly total commute time, average duration split by direction, best and worst commute days of the week, a 4-week trend line chart, and a weekly total of time wasted in traffic.

Requirements covered: STAT-01, STAT-02, STAT-03, STAT-04, STAT-05.

Out of scope: the real dashboard home screen (Phase 6), dark mode and notification settings (Phase 7), auth and sync (Phases 8–10).

</domain>

<decisions>
## Implementation Decisions

### Screen Layout
- **D-01:** Single scrollable page with Material 3 cards stacked vertically. Card order: (1) This Week / This Month totals, (2) Direction averages (to-office vs to-home), (3) Best/worst commute day of the week, (4) 4-week trend chart, (5) Time in traffic this week.
- **D-02:** Entry point: add a "View stats" outlined/text button on the home screen, positioned below the existing "View history" button. No NavigationBar, no AppBar icon. Phase 6 replaces this home screen with the real dashboard — both history and stats buttons are temporary.

### Period Definitions
- **D-03:** "Current week" = Mon–Sun calendar week. Stats reset on Monday. "This week" always means the current Mon–Sun block containing today.
- **D-04:** "Current month" = calendar month (Jan 1–Jan 31, Feb 1–Feb 28, etc.). Stats reset on the 1st of each month.

### Manual Entry Handling
- **D-05:** Manually-entered trips (`isManualEntry == true`) are **included** in all time-based stats: STAT-01 totals, STAT-02 direction averages, STAT-03 best/worst day, STAT-04 trend. They are **excluded** from STAT-05 (time wasted in traffic) because their `timeMovingSeconds` and `timeStuckSeconds` are both 0 — counting them would understate traffic for users who log many manual trips. The stats engine must apply this filter explicitly.

### Stats Computation
- **D-06:** All stats computed in pure Dart inside a single Riverpod `StreamProvider`. The provider subscribes to `watchAllSummaries()` and runs a single-pass computation over the emitted list to produce all 5 stats at once. No new DAO aggregate query methods needed. Unit testing uses plain `List<TripSummary>` without a real database.

### Trend Line (STAT-04)
- **D-07:** Each data point = total commute time for that calendar day (sum of all trip durations on that day). Single combined line — not split by direction. The 4-week window spans the 28 calendar days ending today (inclusive).
- **D-08:** X-axis shows 4 week-level labels only: "Week 1", "Week 2", "Week 3", "This week". No per-day tick labels. Days with no trips show as 0-height (or a visual gap — Claude's discretion).

### Best/Worst Commute Day (STAT-03)
- **D-09:** Average commute duration per weekday (Mon, Tue, Wed, Thu, Fri) computed across all trips ever recorded. No minimum trip count threshold — all weekdays are always shown. Best = lowest average duration, worst = highest average. Weekend trips (Sat, Sun) are excluded from the day-of-week breakdown.

### Empty State
- **D-10:** When no trips exist, each stat card shows `—` in place of numbers (e.g., "This week: —"). Cards remain visible and structurally intact so the user sees what they'll populate once they record commutes. No full-screen replacement empty state.

### Claude's Discretion
- Exact card styling, padding, and typography within Material 3 conventions
- Whether trend chart days with no trips show 0-height bars or a visual gap
- `fl_chart` widget type (`LineChart` recommended given STAT-04 says "trend line")
- How the best and worst weekday are visually highlighted (color accent, bold, chip)
- File and folder naming within `lib/features/stats/`
- Whether all stats live in one combined provider or multiple focused providers
- AppBar title for the stats screen
- Exact empty-state label text for each stat card

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project spec
- `CLAUDE.md` — Full project spec: folder structure, Riverpod conventions (manual 3.x providers, no codegen), no hardcoded values, feature-first layout, `very_good_analysis` linting
- `.planning/PROJECT.md` — Core value: "show people the reality of their commute — time wasted in traffic and how it changes over time"
- `.planning/REQUIREMENTS.md` — STAT-01 through STAT-05 acceptance criteria

### Prior phase artifacts
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-01..D-13: schema decisions, `kDefaultUserId`, Riverpod setup, `very_good_analysis`
- `.planning/phases/02-core-tracking/02-CONTEXT.md` — D-02: manual Riverpod 3.x providers (no codegen)
- `.planning/phases/04-trip-history/04-CONTEXT.md` — D-02: "View history" button pattern on home screen (Phase 5 adds "View stats" below it, same temporary pattern)

### Existing code this phase builds on
- `lib/database/daos/trips_dao.dart` — `watchAllSummaries()` stream and `TripSummary` class; all fields needed for stats are present (`durationSeconds`, `direction`, `timeMovingSeconds`, `timeStuckSeconds`, `startTime`, `isManualEntry`)
- `lib/features/tracking/screens/home_screen.dart` — "View history" button already added by Phase 4; Phase 5 adds "View stats" button below it
- `lib/config/constants.dart` — `kDirectionToOffice`, `kDirectionToHome`; any new stat labels or thresholds added here
- `lib/config/routes.dart` — Phase 5 adds at minimum a `/stats` named route

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TripsDao.watchAllSummaries()` — reactive stream of all trips as `TripSummary`, ordered newest-first. The stats provider subscribes to this stream and recomputes on every emission. All required stats fields are present.
- `TripSummary.isManualEntry` — boolean flag for D-05: exclude these trips from STAT-05 traffic computation.
- `TripSummary.direction` — `kDirectionToOffice` / `kDirectionToHome` string constants; use for STAT-02 direction split.
- `TripSummary.startTime` — UTC `DateTime`; convert to local time for calendar-week and calendar-month bucketing (D-03, D-04).
- `kDirectionToOffice`, `kDirectionToHome` in `constants.dart` — use for direction grouping; never raw strings.

### Established Patterns
- **Manual Riverpod 3.x providers** — no `@riverpod` annotation; hand-written `StreamProvider` and `Provider` for all state
- **Feature-first folder layout** — Phase 5 creates `lib/features/stats/` with `screens/`, `widgets/`, `providers/` subdirectories
- **`very_good_analysis` strict linting** — doc comments on public members, `package:traevy/...` absolute imports, no `dynamic`
- **Constants in `lib/config/constants.dart`** — all new string labels and numeric thresholds go here
- **Drift is the only data source for UI** — stats screen reads from `watchAllSummaries()` only, never from network

### Integration Points
- **Home screen** (`lib/features/tracking/screens/home_screen.dart`): Phase 5 adds "View stats" outlined button below the "View history" button Phase 4 already added.
- **Routes** (`lib/config/routes.dart`): Phase 5 adds `/stats` named route.
- **`pubspec.yaml`**: confirm `fl_chart` is present; add if not already there.

</code_context>

<specifics>
## Specific Ideas

- Weekly/monthly totals card: show both in one card — "This week: 2h 34m" and "This month: 8h 12m" as two rows with clear labels
- Direction averages: two labeled rows "To office avg" and "To home avg" so users know which direction takes longer
- Best/worst day: horizontal row of 5 day chips (Mon–Fri), best highlighted green, worst highlighted amber/red
- 4-week trend: `fl_chart` `LineChart` — x-axis 4 week labels, y-axis in minutes, one data point per calendar day

</specifics>

<deferred>
## Deferred Ideas

- **Average trip distance** — `distanceMeters` is available on `TripSummary` but not in STAT-01..05 requirements; noted for future stats expansion
- **Month-over-month comparison** — ANLYT-01 in v2 requirements, explicitly out of scope for v0.1
- **Interactive trend chart** — tap a data point to reveal date + value; left to Claude's discretion if low-effort, deferred if complex

</deferred>

---

*Phase: 05-stats-analytics*
*Context gathered: 2026-04-26*
