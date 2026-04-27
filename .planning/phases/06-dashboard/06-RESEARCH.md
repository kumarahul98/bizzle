# Phase 6: Dashboard - Research

**Researched:** 2026-04-27
**Domain:** Flutter dashboard screen — widget composition, Riverpod provider derivation, HomeScreen migration
**Confidence:** HIGH (all findings verified against actual codebase files)

## Summary

Phase 6 is a pure Flutter UI phase with zero new backend, database, or package dependencies. Everything needed already exists: the provider graph (`trackingStateProvider`, `allTripSummariesProvider`, `statsSummaryProvider`), the reusable widget (`TripCard`), the formatter (`formatDuration`), the navigation constants, and the permission logic in `HomeScreen`. The work is: (1) create `lib/features/dashboard/` with three widget files and one provider file, (2) migrate `HomeScreen`'s `_handleStart`/`_handleAddManualTrip`/`_showSettingsDialog` methods verbatim into `DashboardScreen`, (3) add a derived `todaysTripSummariesProvider` that filters `allTripSummariesProvider`, (4) wire a dual-mode FAB driven by `trackingStateProvider`, and (5) update three files (`app.dart`, `test/widget/app_test.dart`, `test/unit/app_bootstrap_test.dart`) to point at `DashboardScreen` instead of `HomeScreen`.

The biggest risk is the test-file migration. Two existing widget tests (`app_test.dart`, `app_bootstrap_test.dart`) import `HomeScreen` directly — they must be updated to reference `DashboardScreen`. The `home_screen_test.dart` file must become `dashboard_screen_test.dart`. Missing this causes broken imports after `home_screen.dart` is deleted.

The second risk is `very_good_analysis`: every public member in `lib/features/dashboard/` needs a doc comment, all imports must use `package:traevy/...` absolute paths, and each widget file must stay under 100 lines.

**Primary recommendation:** Create four new files in `lib/features/dashboard/` (screen + 3 widgets + 1 provider), migrate `HomeScreen` logic verbatim, update 5 existing files (app.dart, routes.dart, constants.dart, app_test.dart, app_bootstrap_test.dart), rename home_screen_test.dart → dashboard_screen_test.dart, then delete `home_screen.dart`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Today's trips list | Frontend (Flutter widget) | Drift (data source via provider) | Filter happens in a derived Riverpod provider; Drift stream is the data origin |
| Weekly summary data | Frontend (Flutter widget) | Riverpod (statsSummaryProvider) | statsSummaryProvider already computes weekTotalSeconds + weekStuckSeconds; no new DAO query needed |
| In-progress tracking card | Frontend (Flutter widget) | Flutter background service (data source) | trackingStateProvider bridges fbs events to UI; dashboard just watches it |
| FAB dual-mode | Frontend (Flutter widget) | — | Pure UI state derived from trackingStateProvider; no backend involvement |
| Permission handling | Frontend (Flutter service) | — | TrackingPermissionService exists; HomeScreen logic migrates verbatim |
| App root wiring | Frontend (MaterialApp.home) | — | app.dart change: HomeScreen → DashboardScreen |

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** New `lib/features/dashboard/` feature folder with `screens/`, `widgets/`, and `providers/` subdirectories. `DashboardScreen` replaces `HomeScreen` as the app root — `MaterialApp.home:` in `app.dart` changes from `HomeScreen` to `DashboardScreen`. The old `lib/features/tracking/screens/home_screen.dart` is deleted once all its logic is migrated.
- **D-02:** Header + scrollable body. AppBar is slim: app name ("Traevy") or today's date/greeting on the left, History and Stats icons as trailing actions. The scrollable body contains in order: (1) weekly summary card, (2) section label ("Today"), (3) today's trips list. FAB anchored bottom-right.
- **D-03:** FAB is the primary Start CTA. When tracking is idle: FAB label/icon = "Start commute" (play icon). When tracking is active: FAB changes to "Go to tracking" (navigate icon). FAB always visible — does NOT disappear. The dashboard watches `trackingStateProvider` to drive this toggle.
- **D-04:** When tracking is active, a "In progress" card appears at the top of the today's list (above completed TripCards). Card shows elapsed time (watches `trackingStateProvider`) and tapping it navigates to the tracking screen. Implemented as a separate widget so it can be conditionally shown without branching inside `TripCard`.
- **D-05:** Filter `allTripSummariesProvider` client-side for trips where `startTime.toLocal()` date equals today. Show as a flat list of reused `TripCard` widgets (no date-section headers). Empty state when no trips: simple centered text label (e.g., "No commutes yet today") below the weekly summary card. The in-progress card (D-04) appears even when there are no completed trips today.
- **D-06:** Three rows displayed: (1) "This week" → total commute time formatted as `formatDuration()`, (2) "In traffic" → traffic time formatted as `formatDuration()`, (3) trip count ("5 trips" or "1 trip"). Sourced from `statsSummaryProvider` (`weekTotalSeconds`, `weekStuckSeconds`) plus a client-side count of today's trips from the filtered list. Tapping the card navigates to `kRouteStats`.
- **D-07:** History and Stats are reached via two trailing `IconButton`s in the AppBar (history icon → `kRouteHistory`; bar_chart icon → `kRouteStats`). The two outlined "View history" / "View stats" buttons from prior phases are removed entirely.
- **D-08:** The existing manual entry FAB (from `HomeScreen`) is moved or replaced — exact placement is Claude's discretion. Must remain accessible somewhere on the dashboard.

### Claude's Discretion
- Exact greeting / header text (date only vs "Good morning" without user name since auth is Phase 8)
- "In progress" card visual treatment (color, elapsed time format, icon)
- Trip count label pluralization ("1 trip" vs "5 trips")
- AppBar icon choices for History and Stats
- Whether `weekStuckSeconds` is shown as "In traffic" or "Stuck in traffic"
- Empty state label text
- File and widget naming within `lib/features/dashboard/`
- Provider naming for the dashboard's today-filtered list

### Deferred Ideas (OUT OF SCOPE)
- Surfacing user name in the greeting, profile avatar/icon, sign-out option (Phase 8)
- Bottom navigation bar (deferred from Phase 4 D-02)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UX-01 | Dashboard home screen shows today's trips and weekly summary card | Covered by: DashboardScreen (today's TripCard list via todaysTripSummariesProvider), WeeklySummaryCard (statsSummaryProvider.weekTotalSeconds + weekStuckSeconds), Start Trip FAB (D-03), DashboardScreen as app root (D-01) |
</phase_requirements>

---

## Standard Stack

### Core (all already in pubspec — no new packages)

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| flutter_riverpod | ^3.x (installed) | Provider graph: watch trackingStateProvider, allTripSummariesProvider, statsSummaryProvider | Already installed [VERIFIED: codebase] |
| drift | ^2.22 (installed) | Source of truth for TripSummary stream | Already installed [VERIFIED: codebase] |
| intl | ^0.19 (installed) | DateFormat for today's date in AppBar / greeting | Already installed [VERIFIED: codebase] |

**No new packages required for Phase 6.** [VERIFIED: codebase grep — all needed APIs already imported in existing feature files]

---

## Architecture Patterns

### System Architecture Diagram

```
Drift (watchAllSummaries stream)
        │
        ▼
allTripSummariesProvider  ──────────────────────────────────────┐
  (StreamProvider<List<TripSummary>>)                            │
        │                                                        │
        ├──► todaysTripSummariesProvider                         ├──► statsSummaryProvider
        │    (Provider<AsyncValue<List<TripSummary>>>)            │    (Provider<AsyncValue<StatsSummary>>)
        │         │                                              │         │
        │         ▼                                              │         ▼
        │    TodayTripsSection widget ────────────────►          │    WeeklySummaryCard widget
        │    (DashboardScreen body item 3)                       │    (DashboardScreen body item 1)
        │                                                        │
        └────────────────────────────────────────────────────────┘

flutter_background_service (1 Hz events)
        │
        ▼
trackingStateProvider
  (NotifierProvider<TrackingNotifier, TrackingState>)
        │
        ├──► DashboardScreen FAB (idle → "Start commute" / active → "Go to tracking")
        └──► InProgressCard (shown when TrackingActive, hides otherwise)

User taps FAB (idle) → _handleStart → TrackingPermissionService.currentStatus()
  → permanentlyDenied/notificationDenied: show settings dialog
  → other: Navigator.pushNamed(kRouteTracking)

User taps FAB (active) → Navigator.pushNamed(kRouteTracking)
```

### Recommended Project Structure

```
lib/features/dashboard/
├── screens/
│   └── dashboard_screen.dart       # Root screen, ~80 lines; DashboardScreen
├── widgets/
│   ├── weekly_summary_card.dart    # WeeklySummaryCard (~70 lines)
│   ├── in_progress_card.dart       # InProgressCard (~50 lines)
│   └── today_trips_section.dart    # TodayTripsSection (~60 lines)
└── providers/
    └── dashboard_providers.dart    # todaysTripSummariesProvider + weekTripCountProvider

test/widget/features/dashboard/
└── dashboard_screen_test.dart      # Migrated + expanded from home_screen_test.dart
```

### Pattern 1: Today's Trips Derived Provider (Manual Riverpod 3.x)

The filter is a synchronous date comparison applied inside `whenData`. No new DAO query needed.

```dart
// Source: verified against stats_providers.dart pattern in codebase
// lib/features/dashboard/providers/dashboard_providers.dart

/// Trips whose [TripSummary.startTime] (converted to local time) falls
/// on today's calendar date. Derived from [allTripSummariesProvider]
/// so no duplicate Drift subscription is opened.
///
/// Returns the same [AsyncValue] states (loading/error/data) as the
/// upstream provider.
final Provider<AsyncValue<List<TripSummary>>> todaysTripSummariesProvider =
    Provider<AsyncValue<List<TripSummary>>>(
  (ref) {
    final asyncTrips = ref.watch(allTripSummariesProvider);
    return asyncTrips.whenData((trips) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return trips.where((trip) {
        final local = trip.startTime.toLocal();
        final date = DateTime(local.year, local.month, local.day);
        return date == today;
      }).toList();
    });
  },
  name: 'todaysTripSummariesProvider',
);
```

[VERIFIED: pattern matches `statsSummaryProvider` in `lib/features/stats/providers/stats_providers.dart`]

### Pattern 2: FAB Dual-Mode (D-03)

```dart
// Source: verified against home_screen.dart + tracking_state.dart
// In DashboardScreen.build():
final trackingState = ref.watch(trackingStateProvider);
final isTracking = trackingState is TrackingActive;

// FAB:
floatingActionButton: isTracking
    ? FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, kRouteTracking),
        icon: const Icon(Icons.navigation_rounded),
        label: const Text(kDashboardFabActiveLabel),   // constant
      )
    : FloatingActionButton.extended(
        onPressed: () => _handleStart(context, ref),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text(kDashboardFabIdleLabel),     // constant
      ),
```

[VERIFIED: `TrackingActive` is a `final class` in `tracking_state.dart`; `is TrackingActive` pattern already used in `home_screen.dart` line 35]

### Pattern 3: In-Progress Card (D-04)

```dart
// Source: verified from tracking_state.dart — TrackingActive fields
// lib/features/dashboard/widgets/in_progress_card.dart

class InProgressCard extends ConsumerWidget {
  /// Create the in-progress commute card.
  const InProgressCard({required this.active, super.key});

  /// The live tracking state to display.
  final TrackingActive active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // active.elapsedSeconds — int, available directly on TrackingActive
    // formatDuration(active.elapsedSeconds) for display
    // Tap → Navigator.pushNamed(context, kRouteTracking)
    ...
  }
}
```

Key insight: `TrackingActive` already has `elapsedSeconds` (int), `distanceMeters` (double), `timeMovingSeconds` (int), `timeStuckSeconds` (int). All display fields are present with no additional computation needed. [VERIFIED: `tracking_state.dart` lines 47–79]

The caller (DashboardScreen or TodayTripsSection) does the conditional:
```dart
if (trackingState is TrackingActive)
  InProgressCard(active: trackingState),
```

### Pattern 4: Weekly Summary Card (D-06)

`statsSummaryProvider` is `Provider<AsyncValue<StatsSummary>>`. The card watches it with `ref.watch` and calls `.when(...)`:

```dart
// Source: verified from stats_providers.dart and stats_service.dart
// weekTotalSeconds: int (total commute seconds this Mon-Sun week)
// weekStuckSeconds: int (stuck seconds this week, non-manual only)
// Trip count: derived from todaysTripSummariesProvider (today's count only)
//             OR from allTripSummariesProvider filtered to current week

// D-06 spec: trip count is "client-side count of today's trips from the
// filtered list" — meaning today's trip count, NOT the full week count.
// This is sourced from todaysTripSummariesProvider.
```

[VERIFIED: D-06 in CONTEXT.md says "plus a client-side count of today's trips from the filtered list"]

**Important nuance:** The trip count in the weekly summary card (D-06) counts TODAY's trips (from `todaysTripSummariesProvider`), not the full week. This is counter-intuitive (card is titled "This week" but count is today's). The planner should clarify this or count the full-week trips instead — research cannot resolve this ambiguity from CONTEXT.md alone. See Open Questions.

### Pattern 5: `_handleStart` / `_handleAddManualTrip` Migration

Both methods migrate verbatim from `HomeScreen` to `DashboardScreen`. They have no `HomeScreen`-specific dependencies — only:
- `ref.read(trackingPermissionServiceProvider)` (provider, not class method)
- `Navigator.pushNamed(context, kRouteTracking)`
- `showModalBottomSheet<void>(... ManualEntrySheet ...)`
- `showDialog<bool>(...)` for settings dialogs

[VERIFIED: `home_screen.dart` lines 90–158 — zero references to `HomeScreen` fields or `this`; all are self-contained async methods taking `BuildContext, WidgetRef`]

D-08 (manual entry placement) is Claude's discretion. Recommended: long-press on the FAB (common Material pattern) or an `IconButton` in the AppBar. The `_handleAddManualTrip` logic is unchanged either way.

### Anti-Patterns to Avoid

- **Direct network read in widget:** All data must come from Drift-backed providers. Never call any HTTP client from the dashboard.
- **Inline today-filter in widget build:** Date filtering belongs in `todaysTripSummariesProvider`, not in a widget's `build()` method.
- **Watching `trackingStateProvider` multiple times:** Watch once in `DashboardScreen.build()`, pass the value down to child widgets as a constructor parameter (`active: trackingState is TrackingActive ? trackingState as TrackingActive : null`).
- **setState or StatefulWidget:** All state is in Riverpod. Dashboard screen and all child widgets must be `ConsumerWidget` or `ConsumerStatelessWidget`.
- **Codegen annotations:** No `@riverpod` annotation, no `.g.dart` files. Manual providers only.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Today's date comparison | Custom date utils | `DateTime.now()` + `toLocal()` + `DateTime(y, m, d)` equality | Pattern already used in `history_providers.dart` `groupTripsByDate` and `stats_service.dart` |
| Duration formatting | Custom formatter | `formatDuration(int seconds)` in `lib/shared/utils/formatters.dart` | Already handles both sub-hour and hour+ cases |
| Permission dialog | Custom dialog widget | `_showSettingsDialog` migrated verbatim from `HomeScreen` | Tested, battle-hardened, covers `permanentlyDenied` and `notificationDenied` cases |
| Trip card rendering | Custom card widget | `TripCard(summary: trip)` from `lib/features/trips/widgets/trip_card.dart` | Already handles tap-to-detail, edit, delete, direction chip |
| Stats computation | Custom week aggregation | `statsSummaryProvider` (already computed) | Phase 5 computed all needed fields; zero new computation required |

---

## Common Pitfalls

### Pitfall 1: Deleting `home_screen.dart` Before Updating All Importers

**What goes wrong:** `app.dart`, `test/widget/app_test.dart`, and `test/unit/app_bootstrap_test.dart` all import `home_screen.dart` directly. Deleting the file before updating these imports causes build failures.

**Why it happens:** The file has three importers spread across lib/ and test/.

**How to avoid:** Update all three files to import `DashboardScreen` FIRST, then delete `home_screen.dart`.

**Verification:** Run `grep -r "home_screen\|HomeScreen" lib/ test/ --include="*.dart"` — must return zero results before deletion.

[VERIFIED: `app.dart` line 7, `app_test.dart` line 10, `app_bootstrap_test.dart` line 11 — all import `home_screen.dart`]

### Pitfall 2: `home_screen_test.dart` Not Migrated

**What goes wrong:** After `HomeScreen` is deleted, `test/widget/features/tracking/home_screen_test.dart` has a broken import and the test suite fails.

**Why it happens:** The test file tests `HomeScreen` specifically — it imports `home_screen.dart` and contains `find.byType(HomeScreen)`.

**How to avoid:** The test file must become `test/widget/features/dashboard/dashboard_screen_test.dart`. The _handleStart permission path tests should be rewritten for `DashboardScreen`. The `_pumpHomeScreen` helper becomes `_pumpDashboardScreen`. Both `allTripSummariesProvider` and `statsSummaryProvider` need overrides since `DashboardScreen` watches both.

### Pitfall 3: `app_test.dart` and `app_bootstrap_test.dart` Assert `HomeScreen`

**What goes wrong:** Both tests contain `expect(find.byType(HomeScreen), findsOneWidget)`. After the migration these assertions fail because `DashboardScreen` is the root.

**Why it happens:** The tests were written to verify Phase 2's root screen.

**How to avoid:** Update both tests to assert `DashboardScreen` instead of `HomeScreen`. Also add provider overrides for `allTripSummariesProvider` and `statsSummaryProvider` since `DashboardScreen` watches both (unlike the old `HomeScreen` which only watched `trackingStateProvider`).

[VERIFIED: `app_test.dart` line 58 — `expect(find.byType(HomeScreen), findsOneWidget)`; `app_bootstrap_test.dart` lines 25–65 same pattern]

### Pitfall 4: DashboardScreen Widget Over 100 Lines

**What goes wrong:** `very_good_analysis` warns; CLAUDE.md mandates extraction.

**Why it happens:** `DashboardScreen` must render AppBar + FAB + body with three sections. If all widgets are inlined, it easily exceeds 100 lines.

**How to avoid:** Extract `WeeklySummaryCard`, `InProgressCard`, and `TodayTripsSection` as separate widget files in `lib/features/dashboard/widgets/`. `DashboardScreen.build()` then just assembles them. Estimated: DashboardScreen ~75 lines, each child ~40–70 lines.

### Pitfall 5: Missing Doc Comments on Public Members

**What goes wrong:** `very_good_analysis` strict mode enforces `public_member_api_docs`. Any public class, constructor, method, or field without a `///` doc comment causes a lint error.

**Why it happens:** Dashboard widgets are new code with no prior history.

**How to avoid:** Every public `class`, `const Constructor({...})`, and `final` field in the four new files needs a `///` doc comment. Private helpers (`_handleStart`, `_showSettingsDialog`, `_handleAddManualTrip`) do NOT need doc comments.

### Pitfall 6: Watching `allTripSummariesProvider` Twice

**What goes wrong:** Both `todaysTripSummariesProvider` and `statsSummaryProvider` derive from `allTripSummariesProvider`. If `DashboardScreen` watches all three providers, Riverpod deduplicates the upstream stream (same provider instance), so there is no actual duplication. However, if a widget accidentally calls `ref.watch(allTripSummariesProvider)` directly AND watches the derived providers, it gets three subscriptions that all trigger rebuilds from the same stream emission.

**How to avoid:** `DashboardScreen` watches `todaysTripSummariesProvider` and `statsSummaryProvider` only. Never watch `allTripSummariesProvider` directly in dashboard widgets.

### Pitfall 7: `context.mounted` After Every `await` in Migrated Methods

**What goes wrong:** `_handleStart` and `_handleAddManualTrip` each contain `await` calls. If `context` is not checked after each `await`, calling `Navigator.pushNamed` on a disposed widget triggers the "deactivated widget" exception.

**Why it happens:** The current `HomeScreen` code already handles this correctly (lines 101, 107). During migration copy-paste, these guards must be preserved.

**How to avoid:** Migrate the methods verbatim. The `if (!context.mounted) return;` checks in the current code are load-bearing — do not remove them.

[VERIFIED: `home_screen.dart` lines 101 and 107 already have the guard]

### Pitfall 8: `kRouteHome` Constant Stays Unchanged

**What goes wrong:** Changing `kRouteHome = '/'` to `kRouteDashboard = '/'` and removing `kRouteHome` would break any code that references `kRouteHome`.

**Why it happens:** The home route `'/'` is bound via `MaterialApp.home:`, not via `kAppRoutes`. Changing the constant name serves no purpose.

**How to avoid:** Leave `kRouteHome = '/'` as-is in `routes.dart`. Optionally add `kRouteDashboard = '/'` as an alias, but it is not necessary since the dashboard is not navigated to via named routes — it is the `home:` binding.

---

## Migration Plan: `HomeScreen` → `DashboardScreen`

### What Moves Verbatim

| Item | From | To |
|------|------|----|
| `_handleStart(BuildContext, WidgetRef)` | `home_screen.dart` lines 104–131 | `dashboard_screen.dart` private method |
| `_handleAddManualTrip(BuildContext, WidgetRef)` | `home_screen.dart` lines 90–102 | `dashboard_screen.dart` private method |
| `_showSettingsDialog(BuildContext, TrackingPermissionService, {title, body})` | `home_screen.dart` lines 133–158 | `dashboard_screen.dart` private method |
| `handleDeleteTrip(BuildContext, WidgetRef, String)` | `home_screen.dart` lines 167–171 | NOT migrated — this delegates to `trip_actions.handleDeleteTrip` which is already used by `TripCard` directly. The method on `HomeScreen` is dead code after Phase 6. |

### What Changes

| Item | Change |
|------|--------|
| `HomeScreen` class | Replaced by `DashboardScreen` |
| `MaterialApp.home: const HomeScreen()` in `app.dart` | → `home: const DashboardScreen()` |
| `import .../home_screen.dart` in `app.dart` | → `import .../dashboard_screen.dart` |
| `kStatsHomeButtonLabel` constant in `constants.dart` | Can be removed (button removed per D-07) OR kept for backward compat. Safe to remove — only used in `home_screen.dart` which is deleted. |
| `test/widget/features/tracking/home_screen_test.dart` | Renamed + rewritten as `test/widget/features/dashboard/dashboard_screen_test.dart` |
| `app_test.dart` / `app_bootstrap_test.dart` | Update `HomeScreen` → `DashboardScreen` references + add provider overrides |

### What Does NOT Change

| Item | Reason |
|------|--------|
| `kRouteHome = '/'` | Still valid; dashboard is the home |
| `kRouteTracking`, `kRouteHistory`, `kRouteStats`, `kRouteTripDetail` | Unchanged |
| `kAppRoutes` map | No new named route needed; dashboard is `MaterialApp.home:` |
| `TrackingScreen`, `HistoryScreen`, `StatsScreen` | No changes to these screens |
| `TripCard` widget | Reused directly; no modifications |
| `allTripSummariesProvider`, `statsSummaryProvider`, `trackingStateProvider` | Watched from dashboard; no modifications to these providers |
| `trip_actions.handleDeleteTrip` docstring reference to "HomeScreen" | Should be updated to say "DashboardScreen" for accuracy |

---

## Provider Design: Full Picture

```
dashboard_providers.dart
├── todaysTripSummariesProvider
│     Provider<AsyncValue<List<TripSummary>>>
│     Derives from: allTripSummariesProvider
│     Logic: filter by today's local date (same pattern as groupTripsByDate)
│     Used by: TodayTripsSection, WeeklySummaryCard (trip count row)
│
└── (no other providers needed — statsSummaryProvider already exists in Phase 5)
```

`DashboardScreen.build()` watches:
1. `trackingStateProvider` — for FAB mode and in-progress card visibility
2. `todaysTripSummariesProvider` — for today's trip list + trip count in weekly summary
3. `statsSummaryProvider` — for weekTotalSeconds + weekStuckSeconds in weekly summary

---

## File Modification Inventory

### New Files (create)

| File | Contents |
|------|----------|
| `lib/features/dashboard/screens/dashboard_screen.dart` | `DashboardScreen` ConsumerWidget (~75 lines) |
| `lib/features/dashboard/widgets/weekly_summary_card.dart` | `WeeklySummaryCard` ConsumerWidget (~70 lines) |
| `lib/features/dashboard/widgets/in_progress_card.dart` | `InProgressCard` ConsumerWidget, accepts `TrackingActive` param (~50 lines) |
| `lib/features/dashboard/widgets/today_trips_section.dart` | `TodayTripsSection` ConsumerWidget — empty state + TripCard list (~60 lines) |
| `lib/features/dashboard/providers/dashboard_providers.dart` | `todaysTripSummariesProvider` manual provider (~30 lines) |
| `test/widget/features/dashboard/dashboard_screen_test.dart` | Widget tests for DashboardScreen |

### Modified Files (update)

| File | Change |
|------|--------|
| `lib/app.dart` | Line 7: import → dashboard_screen; Line 40: `home: const DashboardScreen()` |
| `lib/config/constants.dart` | Add new string constants: `kDashboardFabIdleLabel`, `kDashboardFabActiveLabel`, `kDashboardTodaySectionLabel`, `kDashboardEmptyState`, `kDashboardInProgressLabel` |
| `lib/config/routes.dart` | No route change needed; optionally add `kRouteDashboard = '/'` alias |
| `test/widget/app_test.dart` | Update HomeScreen → DashboardScreen, add provider overrides for allTripSummariesProvider + statsSummaryProvider |
| `test/unit/app_bootstrap_test.dart` | Same — update HomeScreen references + add provider overrides |
| `lib/features/trips/services/trip_actions.dart` | Update docstring line 12: "HomeScreen and HistoryScreen" → "DashboardScreen and HistoryScreen" |

### Deleted Files

| File | When |
|------|------|
| `lib/features/tracking/screens/home_screen.dart` | After all importers updated |
| `test/widget/features/tracking/home_screen_test.dart` | After migration to dashboard_screen_test.dart |

---

## Constants Required in `lib/config/constants.dart`

All new string labels go here per CLAUDE.md. Recommended additions:

```dart
// ---------------------------------------------------------------------------
// Phase 6: Dashboard
// ---------------------------------------------------------------------------

/// FAB label when tracking is idle (D-03).
const String kDashboardFabIdleLabel = 'Start commute';

/// FAB label when tracking is active (D-03).
const String kDashboardFabActiveLabel = 'Go to tracking';

/// Section heading above today's trip list (D-02).
const String kDashboardTodaySectionLabel = 'Today';

/// Empty-state label shown when no trips exist today (D-05).
const String kDashboardEmptyStateLabel = 'No commutes yet today';

/// In-progress card title label (D-04).
const String kDashboardInProgressLabel = 'In progress';

/// Weekly summary card title (D-06).
const String kDashboardWeeklySummaryTitle = 'This week';

/// Weekly summary traffic row label (D-06).
const String kDashboardInTrafficLabel = 'In traffic';
```

---

## Integration Points: Exact Lines to Change

### `lib/app.dart`
- Line 6: `import 'package:traevy/features/tracking/screens/home_screen.dart';` → `import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';`
- Line 40: `home: const HomeScreen()` → `home: const DashboardScreen()`
- The class docstring on line 13 says "Phase 2 mounts HomeScreen" — update to reflect Phase 6.

### `test/widget/app_test.dart`
- Remove import of `home_screen.dart`; add import of `dashboard_screen.dart`
- Remove `_IdleTrackingNotifier` class if test is simplified, OR keep it (DashboardScreen also watches `trackingStateProvider`)
- Add `allTripSummariesProvider.overrideWith((ref) => Stream.value(const []))` to the ProviderScope overrides
- Update `expect(find.byType(HomeScreen), findsOneWidget)` → `expect(find.byType(DashboardScreen), findsOneWidget)`

### `test/unit/app_bootstrap_test.dart`
- Same import and assertion updates as `app_test.dart`
- Add `allTripSummariesProvider` override (and optionally `statsSummaryProvider` override) to prevent real Drift queries in widget test context

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built into Flutter SDK) |
| Config file | None (uses default flutter test runner) |
| Quick run command | `flutter test test/widget/features/dashboard/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-01 | DashboardScreen renders as app root | Widget | `flutter test test/widget/app_test.dart` | ✅ (update existing) |
| UX-01 | Today's trips list shows TripCard for each today trip | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | Empty state shown when no trips today | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | Weekly summary card renders weekTotalSeconds + weekStuckSeconds | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | FAB shows "Start commute" when tracking idle | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | FAB shows "Go to tracking" when tracking active | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | InProgressCard visible when TrackingActive, hidden otherwise | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | _handleStart with permanentlyDenied shows settings dialog | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 (migrate from home_screen_test.dart) |
| UX-01 | _handleStart with notificationDenied shows notification dialog | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 (migrate from home_screen_test.dart) |
| UX-01 | _handleStart with fullyGranted navigates to tracking screen | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 (migrate from home_screen_test.dart) |
| UX-01 | AppBar has History and Stats icon buttons | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | todaysTripSummariesProvider filters to today only | Unit | `flutter test test/unit/features/dashboard/` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/widget/features/dashboard/ && flutter test test/widget/app_test.dart && flutter test test/unit/app_bootstrap_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/widget/features/dashboard/dashboard_screen_test.dart` — covers all UX-01 widget behaviors; migrates permission path tests from `home_screen_test.dart`
- [ ] `test/unit/features/dashboard/dashboard_providers_test.dart` — unit test for `todaysTripSummariesProvider` filter logic (today boundary, yesterday exclusion)
- [ ] No new framework installs needed — `flutter_test` already available

---

## Security Domain

This phase has no security-sensitive surfaces. No authentication, no network calls, no user data input, no token handling. All data comes from Drift (local SQLite) via existing providers. No ASVS categories apply to this purely presentational phase.

---

## State of the Art

| Old Approach | Current Approach | Impact for Phase 6 |
|--------------|------------------|-------------------|
| `FloatingActionButton` (single mode) | `FloatingActionButton.extended` (with label) | Use `.extended` for both FAB states — clearer CTA text |
| Manual date filtering in widget `build()` | Derived Riverpod `Provider` wrapping `whenData` | Filter goes in `todaysTripSummariesProvider`, not in widget |
| Home screen as feature-owner of tracking logic | Dashboard as feature-owner; tracking logic belongs in tracking feature | `_handleStart` and friends are UI helpers, not feature logic — they stay in the screen file |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Trip count in WeeklySummaryCard (D-06) means today's count from `todaysTripSummariesProvider` | Weekly Summary Card pattern | If "trip count" means this week's count, a separate week-filter provider is needed. See Open Questions. |

---

## Open Questions

1. **Weekly summary trip count scope (D-06 ambiguity)**
   - What we know: D-06 says "plus a client-side count of today's trips from the filtered list" — this literally means today's count from `todaysTripSummariesProvider`.
   - What's unclear: Showing "2 trips" in a card titled "This week" is misleading if the user had 5 trips this week but only 2 today.
   - Recommendation: Implement as today's count (verbatim per D-06). If it looks wrong during review, escalate to the user. A week-count could be derived from `statsSummaryProvider.weekTotalSeconds > 0` and a separate filter, but that is out-of-scope unless user requests it.

2. **Manual entry placement (D-08, Claude's discretion)**
   - What we know: D-08 says exact placement is Claude's discretion; options listed are long-press FAB, AppBar action, or tracking screen.
   - Recommendation: Implement as an AppBar trailing `IconButton` (edit/add icon). This avoids gesture conflicts with FAB's primary action and is discoverable without long-press. The `_handleAddManualTrip` method is unchanged.

3. **Greeting text in AppBar (Claude's discretion)**
   - What we know: No user name available (auth is Phase 8). Date-only greeting or generic "Traevy" are both acceptable per D-02.
   - Recommendation: Show today's date formatted as `DateFormat('EEE, d MMM').format(DateTime.now())` (e.g. "Sun, 27 Apr"). This gives the screen immediate informational value without a user name.

---

## Environment Availability

Step 2.6: SKIPPED — no external dependencies. Phase 6 is purely Flutter UI code using only packages already installed in `pubspec.yaml`.

---

## Sources

### Primary (HIGH confidence)
- `lib/features/tracking/screens/home_screen.dart` — permission handling, FAB logic, manual entry flow (VERIFIED by file read)
- `lib/features/tracking/providers/tracking_providers.dart` — `trackingStateProvider` type, `TrackingNotifier` lifecycle (VERIFIED by file read)
- `lib/features/tracking/state/tracking_state.dart` — `TrackingActive` fields: `elapsedSeconds`, `distanceMeters`, `timeMovingSeconds`, `timeStuckSeconds` (VERIFIED by file read)
- `lib/features/trips/providers/history_providers.dart` — `allTripSummariesProvider` type signature, `groupTripsByDate` date-filtering pattern (VERIFIED by file read)
- `lib/features/stats/providers/stats_providers.dart` — `statsSummaryProvider` type, `whenData` derivation pattern (VERIFIED by file read)
- `lib/features/stats/services/stats_service.dart` — `StatsSummary` shape: `weekTotalSeconds`, `weekStuckSeconds`, `hasAnyTrips` (VERIFIED by file read)
- `lib/features/trips/widgets/trip_card.dart` — constructor signature `TripCard({required TripSummary summary})` (VERIFIED by file read)
- `lib/shared/utils/formatters.dart` — `formatDuration(int seconds)` signature (VERIFIED by file read)
- `lib/config/routes.dart` — `kRouteHistory`, `kRouteStats`, `kRouteTracking`, `kRouteHome` (VERIFIED by file read)
- `lib/config/constants.dart` — existing constants, confirmed `kStatsHomeButtonLabel` only used in `home_screen.dart` (VERIFIED by file read)
- `lib/app.dart` — `MaterialApp.home: const HomeScreen()` binding location (VERIFIED by file read)
- `test/widget/app_test.dart` — confirms `HomeScreen` reference needing migration (VERIFIED by file read)
- `test/unit/app_bootstrap_test.dart` — confirms second `HomeScreen` reference (VERIFIED by file read)
- `test/widget/features/tracking/home_screen_test.dart` — permission test patterns to migrate (VERIFIED by file read)
- `.planning/phases/06-dashboard/06-CONTEXT.md` — all locked decisions D-01..D-08 (VERIFIED by file read)
- `.planning/config.json` — `nyquist_validation: true` (VERIFIED by file read)

### Secondary (MEDIUM confidence)
- None required — all findings sourced from the actual codebase at HIGH confidence.

### Tertiary (LOW confidence)
- None.

---

## Metadata

**Confidence breakdown:**
- Migration plan: HIGH — all importers grep-verified, all methods located precisely by line number
- Provider design: HIGH — pattern directly mirrors `statsSummaryProvider` which is already working in Phase 5
- Pitfalls: HIGH — derived from reading the exact files that will change
- Widget sizes: MEDIUM — estimated, not counted; actual line counts depend on implementation style

**Research date:** 2026-04-27
**Valid until:** Phase 6 complete (no external dependencies, no version drift risk)
