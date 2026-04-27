# Phase 6: Dashboard - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Users land on a real dashboard home screen that shows today's completed commutes and a weekly summary at a glance. The screen replaces the temporary `HomeScreen` placeholder and is the app's root. Phase 6 delivers: a header with today's date/greeting, a weekly summary card (commute time + traffic time + trip count, tappable to Stats), a live "In progress" card when GPS tracking is active, a scrollable list of today's `TripCard`s, and a FAB that starts a commute when idle or navigates to the tracking screen when active.

Requirements covered: UX-01.

Out of scope: dark mode / notifications (Phase 7), auth / onboarding (Phase 8), backend / sync (Phases 9–10), bottom navigation bar (deferred), manual entry FAB relocation (Claude's discretion).

</domain>

<decisions>
## Implementation Decisions

### Feature Folder
- **D-01:** New `lib/features/dashboard/` feature folder with `screens/`, `widgets/`, and `providers/` subdirectories. `DashboardScreen` replaces `HomeScreen` as the app root — `MaterialApp.home:` in `app.dart` changes from `HomeScreen` to `DashboardScreen`. The old `lib/features/tracking/screens/home_screen.dart` is deleted once all its logic is migrated.

### Screen Layout
- **D-02:** Header + scrollable body. AppBar is slim: app name ("Traevy") or today's date/greeting on the left, History and Stats icons as trailing actions. The scrollable body contains in order: (1) weekly summary card, (2) section label ("Today"), (3) today's trips list. FAB anchored bottom-right.

### FAB Behavior
- **D-03:** FAB is the primary Start CTA. When tracking is **idle**: FAB label/icon = "Start commute" (play icon). When tracking is **active**: FAB changes to "Go to tracking" (navigate icon). FAB always visible — does NOT disappear. The dashboard watches `trackingStateProvider` to drive this toggle.

### Live In-Progress Card
- **D-04:** When tracking is active, a "In progress" card appears at the top of the today's list (above completed `TripCard`s). Card shows elapsed time (watches `trackingStateProvider`) and tapping it navigates to the tracking screen. Implemented as a separate widget so it can be conditionally shown without branching inside `TripCard`.

### Today's Trips Section
- **D-05:** Filter `allTripSummariesProvider` client-side for trips where `startTime.toLocal()` date equals today. Show as a flat list of reused `TripCard` widgets (no date-section headers — this is today only). Empty state when no trips: simple centered text label (e.g., "No commutes yet today") below the weekly summary card. The in-progress card (D-04) appears even when there are no completed trips today.

### Weekly Summary Card
- **D-06:** Three rows displayed: (1) "This week" → total commute time formatted as `formatDuration()`, (2) "In traffic" → traffic time formatted as `formatDuration()`, (3) trip count ("5 trips" or "1 trip"). Sourced from `statsSummaryProvider` (`weekTotalSeconds`, `weekStuckSeconds`) plus a client-side count of today's trips from the filtered list. Tapping the card navigates to `kRouteStats`.

### AppBar Navigation
- **D-07:** History and Stats are reached via two trailing `IconButton`s in the AppBar (history icon → `kRouteHistory`; bar_chart icon → `kRouteStats`). The two outlined "View history" / "View stats" buttons from prior phases are removed entirely — they were temporary.

### Manual Entry
- **D-08:** The existing manual entry FAB (from `HomeScreen`) is moved or replaced — exact placement is Claude's discretion. Options: long-press on the main FAB, an AppBar action icon, or surfaced from within the tracking screen. Must remain accessible somewhere on the dashboard.

### Claude's Discretion
- Exact greeting / header text (date only vs "Good morning" without user name since auth is Phase 8)
- "In progress" card visual treatment (color, elapsed time format, icon)
- Trip count label pluralization ("1 trip" vs "5 trips")
- AppBar icon choices for History and Stats
- Whether `weekStuckSeconds` is shown as "In traffic" or "Stuck in traffic"
- Empty state label text
- File and widget naming within `lib/features/dashboard/`
- Provider naming for the dashboard's today-filtered list

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project spec
- `CLAUDE.md` — Full project spec: folder structure, manual Riverpod 3.x providers (no `@riverpod` codegen), no hardcoded values, feature-first layout, `very_good_analysis` linting, widgets under 100 lines
- `.planning/PROJECT.md` — Core value: "show people the reality of their commute — time wasted in traffic and how it changes over time"
- `.planning/REQUIREMENTS.md` — UX-01 acceptance criteria (dashboard home screen, weekly summary card, start trip CTA)

### Prior phase artifacts
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-01..D-13: schema, `kDefaultUserId`, Riverpod patterns, `very_good_analysis`
- `.planning/phases/02-core-tracking/02-CONTEXT.md` — D-02: manual Riverpod providers; tracking start flow and permission logic
- `.planning/phases/05-stats-analytics/05-CONTEXT.md` — D-02: temporary "View stats" button pattern being replaced; D-06: `statsSummaryProvider` is the source for weekly/traffic stats

### Existing code this phase builds on
- `lib/features/tracking/screens/home_screen.dart` — Contains the tracking start + permission logic (`_handleStart`, `_handleAddManualTrip`) to migrate into `DashboardScreen`; **delete this file after migration**
- `lib/features/tracking/providers/tracking_providers.dart` — `trackingStateProvider` and `TrackingActive` state; watch this on the dashboard to drive FAB toggle and in-progress card (D-03, D-04)
- `lib/features/trips/providers/history_providers.dart` — `allTripSummariesProvider` (`StreamProvider<List<TripSummary>>`); filter client-side for today's trips (D-05)
- `lib/features/stats/providers/stats_providers.dart` — `statsSummaryProvider`; provides `weekTotalSeconds` and `weekStuckSeconds` for the weekly summary card (D-06)
- `lib/features/trips/widgets/trip_card.dart` — Reuse directly for today's completed trips list (D-05); no changes needed
- `lib/shared/utils/formatters.dart` — `formatDuration(int seconds)` for time display
- `lib/config/routes.dart` — Add `kRouteDashboard = '/'` constant (or keep home bound directly via `MaterialApp.home:`); `kRouteHistory` and `kRouteStats` already defined
- `lib/app.dart` — Update `home:` binding from `HomeScreen` to `DashboardScreen`
- `lib/config/constants.dart` — Any new string labels go here

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TripCard` (`lib/features/trips/widgets/trip_card.dart`) — Takes a `TripSummary`; handles tap-to-detail, edit, delete. Reuse directly for today's trips. No changes needed.
- `statsSummaryProvider` — Derived `Provider<AsyncValue<StatsSummary>>`; already computes `weekTotalSeconds` and `weekStuckSeconds` from the reactive `allTripSummariesProvider` stream. No new provider needed for weekly card data.
- `allTripSummariesProvider` — `StreamProvider<List<TripSummary>>`; filter in a derived provider for today's date. Pattern: `provider.whenData((trips) => trips.where(...).toList())`.
- `trackingStateProvider` — `StateNotifierProvider<TrackingStateNotifier, TrackingState>`; `TrackingActive` cast gives elapsed state for in-progress card.
- `_handleStart` / tracking permission flow — In current `home_screen.dart`; migrate verbatim to `DashboardScreen` to preserve D-09 permission check behavior from Phase 2.
- `formatDuration(int seconds)` in `lib/shared/utils/formatters.dart` — Use for weekly totals and in-progress elapsed time.

### Established Patterns
- **Manual Riverpod 3.x providers** — Hand-written `StreamProvider`, `Provider`, `StateNotifierProvider`. No `@riverpod` annotation, no `.g.dart` files for dashboard providers.
- **Feature-first folder layout** — `lib/features/dashboard/screens/dashboard_screen.dart`, `lib/features/dashboard/widgets/`, `lib/features/dashboard/providers/`.
- **`very_good_analysis` strict linting** — Doc comments on public members, `package:traevy/...` absolute imports.
- **Constants in `lib/config/constants.dart`** — All new string labels (empty state text, button labels) go here.
- **Widgets under 100 lines** — Extract `WeeklySummaryCard`, `InProgressCard`, `TodayTripsSection` as separate files.

### Integration Points
- `lib/app.dart` — Change `home: const HomeScreen()` → `home: const DashboardScreen()`. Add `DashboardScreen` import.
- `lib/config/routes.dart` — No new routes needed; `kRouteHistory` and `kRouteStats` already exist. Optionally add `kRouteDashboard = '/'` constant for clarity.
- `lib/features/tracking/screens/home_screen.dart` — **Migrate then delete.** All logic moves to `DashboardScreen`. Verify no other file imports `HomeScreen` before deleting.

</code_context>

<specifics>
## Specific Ideas

- Weekly summary card: three labeled rows — "This week", "In traffic", and trip count. Tapping navigates to Stats.
- FAB dual-mode: play icon (idle) → navigation/arrow icon (active tracking). No disappearing FAB.
- Today section: flat `TripCard` list, no date grouping (unlike `HistoryScreen` which groups by date).
- In-progress card: appears at top of today's list even if zero completed trips today.

</specifics>

<deferred>
## Deferred Ideas

- **Phase 8 (auth) items on dashboard** — Surfacing user name in the greeting, profile avatar/icon, sign-out option. Auth comes in Phase 8 after backend infra (Phase 9 dependency). The greeting stays generic until then.
- **Bottom navigation bar** — Prior phases explicitly deferred this (Phase 4 D-02). AppBar icons cover navigation for now.

</deferred>

---

*Phase: 06-dashboard*
*Context gathered: 2026-04-27*
