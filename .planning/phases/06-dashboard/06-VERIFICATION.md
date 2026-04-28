---
phase: 06-dashboard
verified: 2026-04-28T16:00:00Z
status: human_needed
score: 3/3 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run flutter run on a connected Android device and open the app"
    expected: "App launches directly to DashboardScreen showing today's date in EEE, d MMM format in the AppBar; WeeklySummaryCard is visible at top; 'No commutes yet today' empty-state appears when no trips recorded; FAB shows 'Start commute' with a play icon"
    why_human: "Device-on device boot, screen rendering, and live Drift DB state cannot be verified programmatically"
  - test: "With no trips recorded, tap the FAB ('Start commute')"
    expected: "Navigates to the tracking screen (or shows a permission dialog if location permission is not granted)"
    why_human: "Permission dialog and navigation flow require a physical device with real Android permission state"
  - test: "Start a tracking session, return to the dashboard"
    expected: "FAB changes to 'Go to tracking'; InProgressCard appears above the trips list showing elapsed time and distance"
    why_human: "Real-time tracking state requires live GPS hardware; cannot simulate in automated tests"
  - test: "Tap the history icon (clock) in the AppBar"
    expected: "Navigates to the HistoryScreen"
    why_human: "Navigation to external screens requires device rendering"
  - test: "Tap the stats icon (bar chart) in the AppBar"
    expected: "Navigates to the StatsScreen"
    why_human: "Navigation to external screens requires device rendering"
  - test: "Tap the add icon (+) in the AppBar"
    expected: "ManualEntrySheet modal bottom sheet appears"
    why_human: "Modal bottom sheet display requires device rendering"
  - test: "Tap the WeeklySummaryCard"
    expected: "Navigates to the StatsScreen"
    why_human: "GestureDetector tap navigation requires device rendering"
---

# Phase 6: Dashboard Verification Report

**Phase Goal:** Users land on a home screen that immediately shows today's commutes and a weekly summary at a glance
**Verified:** 2026-04-28T16:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Dashboard is the first screen when opening the app, showing today's recorded trips | VERIFIED | `lib/app.dart` line 41: `home: const DashboardScreen()`. `DashboardScreen.build()` watches `todaysTripSummariesProvider` and passes result to `TodayTripsSection`. `app_test.dart` and `app_bootstrap_test.dart` both assert `find.byType(DashboardScreen)` and pass. |
| 2 | A weekly summary card displays total commute time and traffic time for the current week | VERIFIED | `WeeklySummaryCard` receives `weekTotalSeconds` and `weekStuckSeconds` extracted from `statsSummaryProvider` in `DashboardScreen.build()` (lines 39-43). `formatDuration` renders both values with `kStatsEmptyPlaceholder` fallback for zero. `StatsCard` wraps the column, `GestureDetector` navigates to `kRouteStats`. All three `dashboard_screen_test.dart` active/idle tests and the widget file itself pass `flutter analyze` with 0 issues. |
| 3 | User can start a new trip directly from the dashboard (FAB or prominent button) | VERIFIED | `DashboardScreen` renders a `FloatingActionButton.extended` (lines 91-101). Idle state: label `kDashboardFabIdleLabel` ('Start commute'), `onPressed: () => _handleStart(context, ref)`. Active state: label `kDashboardFabActiveLabel` ('Go to tracking'), navigates to `kRouteTracking`. `dashboard_screen_test.dart` test cases 'FAB shows Start commute label when tracking is idle' and 'FAB shows Go to tracking label when tracking is active' both pass. |

**Score:** 3/3 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/app.dart` | `home: const DashboardScreen()` binding | VERIFIED | Line 41 confirms `home: const DashboardScreen()`. Import present on line 5. `HomeScreen` reference is doc-comment only (line 11) — no functional import. |
| `lib/features/dashboard/screens/dashboard_screen.dart` | ConsumerWidget — app root | VERIFIED | 172 lines. `ConsumerWidget`. Watches `trackingStateProvider`, `todaysTripSummariesProvider`, `statsSummaryProvider`. Assembles `WeeklySummaryCard`, `TodayTripsSection`, dual-mode FAB, 3-icon AppBar. |
| `lib/features/dashboard/widgets/weekly_summary_card.dart` | `WeeklySummaryCard` StatelessWidget | VERIFIED | 84 lines. `StatelessWidget`. Receives `weekTotalSeconds`, `weekStuckSeconds`, `todayTripCount`. `GestureDetector` wraps `StatsCard` navigating to `kRouteStats`. `formatDuration` used for both durations. |
| `lib/features/dashboard/widgets/in_progress_card.dart` | `InProgressCard` StatelessWidget | VERIFIED | 71 lines. `StatelessWidget`. 4px `colorScheme.primary` left-border stripe via `Card.shape`. `Icons.timelapse`. `Semantics` wrapper. `InkWell` navigates to `kRouteTracking`. |
| `lib/features/dashboard/widgets/today_trips_section.dart` | `TodayTripsSection` StatelessWidget | VERIFIED | 82 lines. `StatelessWidget`. `asyncToday.when` dispatch. Conditionally renders `InProgressCard`, `TripCard` list with `shrinkWrap+NeverScrollableScrollPhysics`, or empty-state text. |
| `lib/features/dashboard/providers/dashboard_providers.dart` | `todaysTripSummariesProvider` | VERIFIED | 26 lines. Manual `Provider<AsyncValue<List<TripSummary>>>`. `ref.watch(allTripSummariesProvider)`. `whenData` filter with `.toLocal()` date comparison. All 4 unit tests pass. |
| `lib/config/constants.dart` | 10+ `kDashboard*` constants | VERIFIED | 16 `kDashboard*` constants confirmed (10 from UI-SPEC + 6 additional from code review WR-03). `kStatsHomeButtonLabel` confirmed removed. |
| `lib/features/tracking/screens/home_screen.dart` | Must NOT exist (deleted) | VERIFIED | `ls` returns file-not-found. Zero functional `HomeScreen` or `home_screen` references in `lib/` or `test/`. |
| `test/widget/features/dashboard/dashboard_screen_test.dart` | 12+ passing widget tests | VERIFIED | 12 `testWidgets` cases, all pass. Covers FAB idle/active labels, `InProgressCard` visibility, today's trips, empty state, AppBar icons, 3 permission-path flows. |
| `test/unit/features/dashboard/dashboard_providers_test.dart` | 4 passing unit tests | VERIFIED | 4 `test` cases, all pass. Covers today included, yesterday excluded, tomorrow excluded, empty input. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/app.dart` | `dashboard_screen.dart` | `home: const DashboardScreen()` | WIRED | Line 41 confirmed. Import on line 5 confirmed. |
| `dashboard_screen.dart` | `dashboard_providers.dart` | `ref.watch(todaysTripSummariesProvider)` | WIRED | Line 36. Import on line 6. |
| `dashboard_screen.dart` | `stats_providers.dart` | `ref.watch(statsSummaryProvider)` | WIRED | Line 37. Import on line 9. |
| `dashboard_screen.dart` | `tracking_providers.dart` | `ref.watch(trackingStateProvider)` | WIRED | Line 34. Import on line 10. |
| `dashboard_providers.dart` | `history_providers.dart` | `ref.watch(allTripSummariesProvider)` | WIRED | Line 14. Import on line 3. |
| `weekly_summary_card.dart` | `stats_card.dart` | `StatsCard(title: kDashboardWeeklySummaryTitle, ...)` | WIRED | Line 52-53 confirmed. |
| `today_trips_section.dart` | `trip_card.dart` | `TripCard(summary: trip)` | WIRED | Line 68 confirmed. |
| `today_trips_section.dart` | `in_progress_card.dart` | `InProgressCard(active: trackingState as TrackingActive)` | WIRED | Line 49 confirmed. Guard `if (isActive)` on line 48. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `TodayTripsSection` | `asyncToday` (AsyncValue<List<TripSummary>>) | `todaysTripSummariesProvider` → `allTripSummariesProvider` → `tripsDaoProvider.watchAllSummaries()` | Yes — `watchAllSummaries()` issues a Drift `select(trips)` query with `.watch()` stream (trips_dao.dart lines 79-87) | FLOWING |
| `WeeklySummaryCard` | `weekTotalSeconds`, `weekStuckSeconds` | `statsSummaryProvider` → `allTripSummariesProvider` → Drift | Yes — `statsSummaryProvider` uses `whenData` + `computeStatsSummary` on live trip stream | FLOWING |
| `WeeklySummaryCard` | `todayTripCount` | `todaysTripSummariesProvider` (filtered subset of Drift stream) | Yes — filtered in memory from live Drift stream | FLOWING |
| `InProgressCard` | `active.elapsedSeconds`, `active.distanceMeters` | `trackingStateProvider` (passed down from `DashboardScreen`) | Yes — `TrackingActive` state populated by the live tracking service | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Dashboard unit tests pass | `flutter test test/unit/features/dashboard/` | 4/4 pass | PASS |
| Dashboard widget tests pass | `flutter test test/widget/features/dashboard/` | 16/16 pass | PASS |
| App root tests pass | `flutter test test/widget/app_test.dart test/unit/app_bootstrap_test.dart` | 2/2 pass | PASS |
| No flutter analyze issues | `flutter analyze lib/features/dashboard/` | 0 issues | PASS |
| `home_screen.dart` absent | `ls lib/features/tracking/screens/home_screen.dart` | File not found | PASS |
| No functional HomeScreen references | `grep -r "HomeScreen\|home_screen" lib/ test/ --include="*.dart"` | 4 results, all doc/comments only | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| UX-01 | 06-01, 06-02, 06-03, 06-04 | Dashboard home screen shows today's trips and weekly summary card | SATISFIED | All three ROADMAP success criteria verified above. `DashboardScreen` is the `MaterialApp.home`. `WeeklySummaryCard` shows weekly totals. `TodayTripsSection` shows today's trips. FAB starts new trip. 3/3 SC pass. |

No orphaned requirements found. REQUIREMENTS.md traceability table maps UX-01 exclusively to Phase 6, and all four plans claim it.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/widget/features/stats/stats_screen_test.dart` | 124 | Pre-existing test failure: `expect(find.text(kStatsEmptyPlaceholder), findsNothing)` finds 2 widgets (not 0). Caused by StatsScreen rendering additional "—" placeholders for fields other than weekTotal. | Warning | Does NOT affect Phase 6 goal. Confirmed pre-existing via SUMMARY-04 (documented: "confirmed via git stash"). Not introduced by Phase 6 code — the stats test's `buildScreen` uses `MaterialApp(home: StatsScreen())` directly, not `DashboardScreen`. The 2 "—" widgets come from within `StatsScreen`'s own layout (monthly totals or weekday averages returning zero). Out of scope for Phase 6. |

No TODOs, FIXMEs, placeholder comments, empty implementations, or hardcoded empty data found in any Phase 6 production file.

### Human Verification Required

#### 1. App Launch to DashboardScreen

**Test:** Run `flutter run` on a connected Android device and open the app
**Expected:** App launches to DashboardScreen (not old tracking layout). AppBar shows today's date in "EEE, d MMM" format. WeeklySummaryCard visible. "No commutes yet today" shown if no trips. FAB shows "Start commute" with play icon.
**Why human:** Device boot, screen rendering, and live Drift DB state cannot be verified programmatically.

#### 2. FAB Start Commute Flow

**Test:** Tap the FAB ("Start commute") with location permission in various states
**Expected:** With `fullyGranted` → navigates to tracking screen. With `permanentlyDenied` → shows location permission dialog. With `notificationDenied` → shows notifications dialog.
**Why human:** Real Android permission state and dialog appearance require a physical device.

#### 3. Active Tracking State on Dashboard

**Test:** Start a tracking session, then navigate back to the dashboard
**Expected:** FAB changes label to "Go to tracking"; `InProgressCard` appears at top of today's section showing elapsed time and distance with the primary-color left border stripe.
**Why human:** Live GPS tracking state requires real GPS hardware; cannot simulate elapsed time / distance realistically.

#### 4. Navigation from AppBar Icons

**Test:** Tap history icon (clock), stats icon (bar chart), and add icon (+)
**Expected:** History → HistoryScreen; Stats → StatsScreen; Add → ManualEntrySheet modal.
**Why human:** Screen transitions and modal rendering require device rendering.

#### 5. WeeklySummaryCard Tap Navigation

**Test:** Tap the WeeklySummaryCard
**Expected:** Navigates to StatsScreen
**Why human:** `GestureDetector` tap navigation requires device rendering (widget test coverage confirmed at unit level but visual/tap feel requires device).

### Gaps Summary

No gaps. All three ROADMAP success criteria are verified:

1. **Dashboard is the first screen** — `DashboardScreen` is `MaterialApp.home` in `app.dart`. Widget tests for `TraevyApp` confirm this.
2. **Weekly summary card** — `WeeklySummaryCard` renders `weekTotalSeconds` and `weekStuckSeconds` from `statsSummaryProvider` with real Drift data flowing through the provider chain.
3. **Start trip from dashboard** — dual-mode `FloatingActionButton.extended` present; idle taps `_handleStart` with permission check; active navigates to tracking screen.

The one failing test (`stats_screen_test.dart "renders weekly duration when trips exist"`) is pre-existing, documented in SUMMARY-04, and unrelated to Phase 6's goal. It exists in `test/widget/features/stats/` and its `buildScreen` helper mounts `StatsScreen` directly, not `DashboardScreen`.

The 7 human verification items above represent standard device-on-device behavior checks that cannot be automated: visual rendering, real GPS state, real Android permission dialogs. Automated checks (16 dashboard widget tests + 4 provider unit tests + 2 app root tests) are all GREEN.

---

_Verified: 2026-04-28T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
