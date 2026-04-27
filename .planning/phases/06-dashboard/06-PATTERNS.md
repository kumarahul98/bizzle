# Phase 6: Dashboard - Pattern Map

**Mapped:** 2026-04-27
**Files analyzed:** 11 new/modified files
**Analogs found:** 11 / 11

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/dashboard/screens/dashboard_screen.dart` | screen | request-response | `lib/features/tracking/screens/home_screen.dart` | exact |
| `lib/features/dashboard/providers/dashboard_providers.dart` | provider | CRUD/transform | `lib/features/stats/providers/stats_providers.dart` | exact |
| `lib/features/dashboard/widgets/weekly_summary_card.dart` | widget | request-response | `lib/features/stats/widgets/week_month_totals_card.dart` | exact |
| `lib/features/dashboard/widgets/in_progress_card.dart` | widget | request-response | `lib/features/tracking/screens/home_screen.dart` (TrackingActive branch) | role-match |
| `lib/features/dashboard/widgets/today_trips_section.dart` | widget | request-response | `lib/features/trips/screens/history_screen.dart` (_EmptyState + _CalendarSubList) | role-match |
| `lib/app.dart` | config | request-response | self (modify line 6 + line 40) | self |
| `lib/config/routes.dart` | config | — | self (read-only; no new routes needed) | self |
| `lib/config/constants.dart` | config | — | self (append Phase 6 block) | self |
| `test/widget/features/dashboard/dashboard_screen_test.dart` | test | request-response | `test/widget/features/tracking/home_screen_test.dart` | exact |
| `test/unit/features/dashboard/dashboard_providers_test.dart` | test | CRUD/transform | `test/unit/features/trips/history_grouping_test.dart` | exact |
| `test/widget/app_test.dart` | test | request-response | self (update HomeScreen → DashboardScreen) | self |

---

## Pattern Assignments

### `lib/features/dashboard/screens/dashboard_screen.dart` (screen, request-response)

**Analog:** `lib/features/tracking/screens/home_screen.dart`
**Secondary analog:** `lib/features/stats/screens/stats_screen.dart` (scrollable body + AppBar pattern)

**Imports pattern** (`home_screen.dart` lines 1–10, `stats_screen.dart` lines 1–9):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/dashboard/providers/dashboard_providers.dart';
import 'package:traevy/features/dashboard/widgets/in_progress_card.dart';
import 'package:traevy/features/dashboard/widgets/today_trips_section.dart';
import 'package:traevy/features/dashboard/widgets/weekly_summary_card.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/widgets/manual_entry_sheet.dart';
```

**Class declaration pattern** (`home_screen.dart` lines 28–30):
```dart
class DashboardScreen extends ConsumerWidget {
  /// Create the dashboard screen.
  const DashboardScreen({super.key});
```

**Provider watch pattern** (`home_screen.dart` lines 33–35):
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingStateProvider);
    final isTracking = trackingState is TrackingActive;
    final asyncToday = ref.watch(todaysTripSummariesProvider);
    final asyncStats = ref.watch(statsSummaryProvider);
```

**AppBar with trailing icons pattern** (analog: `history_screen.dart` lines 69–80):
```dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traevy'),   // or DateFormat('EEE, d MMM').format(DateTime.now())
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () => Navigator.pushNamed(context, kRouteHistory),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Stats',
            onPressed: () => Navigator.pushNamed(context, kRouteStats),
          ),
        ],
      ),
```

**Scrollable body pattern** (`stats_screen.dart` lines 39–50):
```dart
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _kHorizontalPadding,
          _kHorizontalPadding,
          _kHorizontalPadding,
          _kBottomSafeArea,
        ),
        child: Column(
          children: <Widget>[
            WeeklySummaryCard(...),
            const SizedBox(height: _kCardGap),
            TodayTripsSection(
              trackingState: trackingState,
              asyncToday: asyncToday,
            ),
          ],
        ),
      ),
```

**FAB dual-mode pattern** (derived from `home_screen.dart` lines 39–45, D-03):
```dart
      floatingActionButton: isTracking
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, kRouteTracking),
              icon: const Icon(Icons.navigation_rounded),
              label: const Text(kDashboardFabActiveLabel),
            )
          : FloatingActionButton.extended(
              onPressed: () => _handleStart(context, ref),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(kDashboardFabIdleLabel),
            ),
```

**`_handleAddManualTrip` method — migrate verbatim** (`home_screen.dart` lines 90–102):
```dart
  Future<void> _handleAddManualTrip(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => const ManualEntrySheet(),
    );
    if (!context.mounted) return;
  }
```

**`_handleStart` method — migrate verbatim** (`home_screen.dart` lines 104–131):
```dart
  Future<void> _handleStart(BuildContext context, WidgetRef ref) async {
    final service = ref.read(trackingPermissionServiceProvider);
    final status = await service.currentStatus();
    if (!context.mounted) return;
    if (status == TrackingPermissionStatus.permanentlyDenied) {
      await _showSettingsDialog(
        context, service,
        title: 'Location permission denied',
        body: 'Location permission is permanently denied. Open system '
            'settings to enable it?',
      );
      return;
    }
    if (status == TrackingPermissionStatus.notificationDenied) {
      await _showSettingsDialog(
        context, service,
        title: 'Notifications required',
        body: 'Notifications are required to track commutes in the '
            'background. Open system settings to enable them?',
      );
      return;
    }
    await Navigator.pushNamed(context, kRouteTracking);
  }
```

**`_showSettingsDialog` method — migrate verbatim** (`home_screen.dart` lines 133–158):
```dart
  Future<void> _showSettingsDialog(
    BuildContext context,
    TrackingPermissionService service, {
    required String title,
    required String body,
  }) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (shouldOpen ?? false) {
      await service.openSystemSettings();
    }
  }
```

**Critical guards:** Every `await` in `_handleStart` and `_handleAddManualTrip` is followed by `if (!context.mounted) return;` — do not omit these when migrating.

---

### `lib/features/dashboard/providers/dashboard_providers.dart` (provider, transform)

**Analog:** `lib/features/stats/providers/stats_providers.dart` (exact pattern)

**Full file pattern** (`stats_providers.dart` lines 1–37):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';

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

**Key points:**
- Manual `Provider` (no `@riverpod` annotation, no `.g.dart` file) — matches every other provider in the project
- `name:` parameter for Riverpod DevTools tracing — always include it
- `whenData` preserves loading/error states without extra handling
- Date comparison uses `toLocal()` + `DateTime(y, m, d)` — same pattern as `groupTripsByDate` in `history_providers.dart` lines 30–34 and `history_grouping_test.dart`

---

### `lib/features/dashboard/widgets/weekly_summary_card.dart` (widget, request-response)

**Analog:** `lib/features/stats/widgets/week_month_totals_card.dart`
**Secondary analog:** `lib/features/stats/widgets/stats_card.dart` (card shell)

**Imports pattern** (`week_month_totals_card.dart` lines 1–4):
```dart
import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';
import 'package:traevy/shared/utils/formatters.dart';
```

**Constructor pattern** — receives already-computed values, not raw `AsyncValue` (`week_month_totals_card.dart` lines 16–27):
```dart
class WeeklySummaryCard extends StatelessWidget {
  /// Construct the weekly summary card from already-computed totals.
  const WeeklySummaryCard({
    required this.weekTotalSeconds,
    required this.weekStuckSeconds,
    required this.todayTripCount,
    super.key,
  });

  /// Total commute seconds Mon–Sun per [statsSummaryProvider].
  final int weekTotalSeconds;

  /// Stuck-in-traffic seconds this week per [statsSummaryProvider].
  final int weekStuckSeconds;

  /// Today's completed trip count from [todaysTripSummariesProvider].
  final int todayTripCount;
```

**Card shell pattern — reuse `StatsCard`** (`stats_card.dart` lines 33–56):
```dart
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, kRouteStats),
      child: StatsCard(
        title: kDashboardWeeklySummaryTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Row 1: "This week" total duration
            Text(
              weekTotalSeconds == 0
                  ? kStatsEmptyPlaceholder
                  : formatDuration(weekTotalSeconds),
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // Row 2: "In traffic" stuck duration
            ...
            // Row 3: trip count with pluralization
            Text(
              todayTripCount == 1 ? '1 trip' : '$todayTripCount trips',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
```

**Empty placeholder pattern** (`week_month_totals_card.dart` lines 33–35):
```dart
    final weekValue = weekTotalSeconds == 0
        ? kStatsEmptyPlaceholder
        : formatDuration(weekTotalSeconds);
```

**Card styling** (`stats_card.dart` lines 33–55): Use `StatsCard` wrapper — `Card` with `colorScheme.surfaceContainerLow`, 16px padding, `titleMedium` w600 heading.

**Tappable card:** Wrap `StatsCard` in `GestureDetector` (no ripple needed; `StatsCard` is not an `InkWell`). Tap navigates to `kRouteStats`.

---

### `lib/features/dashboard/widgets/in_progress_card.dart` (widget, request-response)

**Analog:** `lib/features/stats/widgets/stats_card.dart` (card shell pattern) + `lib/features/tracking/state/tracking_state.dart` (field access)

**`TrackingActive` fields available** (`tracking_state.dart` lines 46–79):
```dart
final class TrackingActive extends TrackingState {
  const TrackingActive({
    required this.startedAt,       // DateTime (UTC)
    required this.elapsedSeconds,  // int — use formatDuration()
    required this.distanceMeters,  // double
    required this.currentSpeedKmh, // double
    required this.timeMovingSeconds,
    required this.timeStuckSeconds,
  });
}
```

**Constructor pattern** (receives `TrackingActive` from parent — no `ref.watch` needed here):
```dart
class InProgressCard extends StatelessWidget {
  /// Create the in-progress commute card.
  const InProgressCard({required this.active, super.key});

  /// The live tracking state to display elapsed time.
  final TrackingActive active;

  @override
  Widget build(BuildContext context) {
    // formatDuration(active.elapsedSeconds) for elapsed time display
    // Navigator.pushNamed(context, kRouteTracking) on tap
  }
}
```

**Card shell:** Use `StatsCard` OR a plain `Card` with `colorScheme.surfaceContainerLow`. Apply `InkWell` wrapping for tap-to-navigate (unlike read-only stat cards, this card is tappable).

**Conditional rendering at call site** (in `TodayTripsSection` or `DashboardScreen`):
```dart
if (trackingState is TrackingActive)
  InProgressCard(active: trackingState),
```

---

### `lib/features/dashboard/widgets/today_trips_section.dart` (widget, request-response)

**Analog:** `lib/features/trips/screens/history_screen.dart` (_EmptyState lines 241–271, _CalendarSubList lines 196–238)

**Empty state pattern** (`history_screen.dart` lines 241–271 — simplified for dashboard):
```dart
// Dashboard uses simpler empty state (text only, no icon — dashboard is not the primary empty-state screen)
Center(
  child: Padding(
    padding: const EdgeInsets.all(_kHorizontalPadding),
    child: Text(
      kDashboardEmptyStateLabel,
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    ),
  ),
)
```

**Trip list pattern** (`history_screen.dart` _CalendarSubList lines 233–237):
```dart
ListView(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  children: <Widget>[
    for (final trip in trips) TripCard(summary: trip),
  ],
)
```

Use `shrinkWrap: true` + `NeverScrollableScrollPhysics` because `TodayTripsSection` lives inside `SingleChildScrollView` in the dashboard body.

**Section label pattern** (`history_screen.dart` AppBar title pattern):
```dart
Text(
  kDashboardTodaySectionLabel,   // 'Today'
  style: Theme.of(context).textTheme.titleMedium?.copyWith(
    fontWeight: FontWeight.w600,
  ),
),
```

**Constructor:**
```dart
class TodayTripsSection extends StatelessWidget {
  /// Create the today trips section.
  const TodayTripsSection({
    required this.asyncToday,
    required this.trackingState,
    super.key,
  });

  /// Today's trips from [todaysTripSummariesProvider].
  final AsyncValue<List<TripSummary>> asyncToday;

  /// Current tracking state, used to show/hide [InProgressCard].
  final TrackingState trackingState;
```

**AsyncValue dispatch pattern** (`stats_screen.dart` lines 39–77):
```dart
  @override
  Widget build(BuildContext context) {
    return asyncToday.when(
      data: (trips) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Section label
          const SizedBox(height: _kSectionLabelGap),
          Text(kDashboardTodaySectionLabel, ...),
          const SizedBox(height: _kCardGap),
          // In-progress card — always first when active
          if (trackingState is TrackingActive)
            InProgressCard(active: trackingState as TrackingActive),
          // Empty state or trip list
          if (trips.isEmpty && trackingState is! TrackingActive)
            Center(child: Text(kDashboardEmptyStateLabel, ...))
          else
            for (final trip in trips) TripCard(summary: trip),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text(kDashboardEmptyStateLabel)),
    );
  }
```

---

### `lib/app.dart` (config, modify)

**Self-modification — exact lines to change** (`app.dart` lines 6, 12–13, 40):

Line 6 (import swap):
```dart
// Remove:
import 'package:traevy/features/tracking/screens/home_screen.dart';
// Add:
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
```

Line 40 (home binding swap):
```dart
// Remove:
      home: const HomeScreen(),
// Add:
      home: const DashboardScreen(),
```

Doc comment on line 12–13: Update "Phase 2 mounts HomeScreen as the root — the minimal Start commute CTA per D-13." to reflect Phase 6.

---

### `lib/config/constants.dart` (config, append)

**Pattern:** Append a new Phase 6 block at the bottom, matching the style of existing phase blocks (`constants.dart` lines 87–89 show the Phase 2 block header pattern).

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

`kStatsHomeButtonLabel` (`constants.dart` line 258) is safe to remove — used only in `home_screen.dart` (being deleted) per research verification.

---

### `lib/config/routes.dart` (config, no changes needed)

No route changes required. `DashboardScreen` is bound via `MaterialApp.home:`, not `kAppRoutes`. `kRouteHome = '/'` stays unchanged. `kRouteHistory` and `kRouteStats` already exist and are used in `DashboardScreen`'s AppBar icon buttons.

---

### `test/widget/features/dashboard/dashboard_screen_test.dart` (test, request-response)

**Analog:** `test/widget/features/tracking/home_screen_test.dart` (migrate and expand)

**_IdleTrackingNotifier class** (`home_screen_test.dart` lines 22–25 — copy verbatim):
```dart
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}
```

**_PermissionHarness typedef and _buildFakePermissionService function** (`home_screen_test.dart` lines 27–115 — copy verbatim). These are battle-tested; no changes needed.

**`_pumpDashboardScreen` helper** (replaces `_pumpHomeScreen`, `home_screen_test.dart` lines 117–138):
```dart
Future<void> _pumpDashboardScreen(
  WidgetTester tester, {
  required TrackingPermissionService permissionService,
  List<TripSummary> todayTrips = const <TripSummary>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackingPermissionServiceProvider.overrideWithValue(permissionService),
        trackingStateProvider.overrideWith(_IdleTrackingNotifier.new),
        // DashboardScreen watches both providers — must override both
        allTripSummariesProvider.overrideWith(
          (ref) => Stream<List<TripSummary>>.value(todayTrips),
        ),
      ],
      child: MaterialApp(
        home: const DashboardScreen(),
        routes: kAppRoutes,
      ),
    ),
  );
  await tester.pump();
}
```

**Permission path tests** (`home_screen_test.dart` lines 140–333 — migrate all 6 tests):
- Rename `HomeScreen` → `DashboardScreen` in `find.byType()` calls
- Rename `_pumpHomeScreen` → `_pumpDashboardScreen`
- `FilledButton` with "Start commute" label still applies (FAB idle mode uses `kDashboardFabIdleLabel`)
- Remove the `OutlinedButton` / `kStatsHomeButtonLabel` test — that button is deleted in Phase 6

**Additional tests for new dashboard behaviors** (pattern from `stats_screen_test.dart` lines 39–48):
```dart
Widget _buildDashboard({
  List<TripSummary> trips = const <TripSummary>[],
  TrackingState trackingState = const TrackingIdle(),
}) {
  return ProviderScope(
    overrides: [
      allTripSummariesProvider.overrideWith(
        (ref) => Stream<List<TripSummary>>.value(trips),
      ),
      trackingStateProvider.overrideWith(
        () => // inline notifier returning trackingState
      ),
      trackingPermissionServiceProvider.overrideWithValue(
        _buildFakePermissionService(TrackingPermissionStatus.fullyGranted).service,
      ),
    ],
    child: MaterialApp(
      home: const DashboardScreen(),
      routes: kAppRoutes,
    ),
  );
}
```

**Two-pump pattern for async** (`home_screen_test.dart` lines 165–166, `stats_screen_test.dart` line 43):
```dart
await tester.pumpWidget(buildDashboard(...));
await tester.pump(); // resolves StreamProvider emission
```

**fl_chart animation workaround** (`home_screen_test.dart` lines 326–327 — needed if StatsScreen is navigated to in tests):
```dart
await tester.pump();
await tester.pump(const Duration(seconds: 2));
```

---

### `test/unit/features/dashboard/dashboard_providers_test.dart` (test, CRUD/transform)

**Analog:** `test/unit/features/trips/history_grouping_test.dart` (pure-function date test pattern)

**TripSummary factory** (`history_grouping_test.dart` lines 14–27 — copy and adapt):
```dart
TripSummary _makeTrip(DateTime startTime) {
  final endTime = startTime.add(const Duration(hours: 1));
  return TripSummary(
    id: const Uuid().v4(),
    startTime: startTime,
    endTime: endTime,
    durationSeconds: endTime.difference(startTime).inSeconds,
    distanceMeters: 0,
    direction: kDirectionToOffice,
    timeMovingSeconds: 3600,
    timeStuckSeconds: 0,
    isManualEntry: false,
  );
}
```

**Pure-function test structure** (`history_grouping_test.dart` lines 29–99):

`todaysTripSummariesProvider` is a derived `Provider` — it cannot be tested purely without Riverpod. Use a `ProviderContainer` to test it without a widget:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

test('filters today trips only', () {
  final todayTrip = _makeTrip(DateTime.now());
  final yesterdayTrip = _makeTrip(
    DateTime.now().subtract(const Duration(days: 1)),
  );
  final container = ProviderContainer(
    overrides: [
      allTripSummariesProvider.overrideWith(
        (ref) => Stream<List<TripSummary>>.value(
          [todayTrip, yesterdayTrip],
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Give the stream time to emit
  // container.read(todaysTripSummariesProvider) returns AsyncValue
  final value = container.read(todaysTripSummariesProvider);
  // Assert...
});
```

**Date boundary test cases** (model after `history_grouping_test.dart` line 65–81):
- Trip with `startTime = DateTime.now()` local → included
- Trip with `startTime = DateTime.now().subtract(Duration(days: 1))` → excluded
- Trip with UTC time that maps to today in local timezone → included
- Empty input → empty result

---

### `test/widget/app_test.dart` (test, modify)

**Self-modification — exact changes:**

Line 10: swap import:
```dart
// Remove:
import 'package:traevy/features/tracking/screens/home_screen.dart';
// Add:
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
```

Lines 38–46: add `allTripSummariesProvider` override to existing `ProviderScope.overrides` list:
```dart
overrides: [
  appDatabaseProvider.overrideWithValue(db),
  tripsDaoProvider.overrideWithValue(db.tripsDao),
  syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
  userPreferencesDaoProvider.overrideWithValue(db.userPreferencesDao),
  directionBackfillProvider.overrideWith((_) async {}),
  trackingStateProvider.overrideWith(_IdleTrackingNotifier.new),
  // DashboardScreen also watches allTripSummariesProvider via todaysTripSummariesProvider
  // and statsSummaryProvider — override to avoid Drift I/O in test
  allTripSummariesProvider.overrideWith(
    (ref) => const Stream<List<TripSummary>>.empty(),
  ),
],
```

Lines 57–64: update assertions:
```dart
// Remove:
expect(find.byType(HomeScreen), findsOneWidget);
expect(find.text('Start commute'), findsOneWidget);

// Add:
expect(find.byType(DashboardScreen), findsOneWidget);
```

---

## Shared Patterns

### ConsumerWidget Declaration
**Source:** `lib/features/stats/screens/stats_screen.dart` lines 30–33, `lib/features/trips/widgets/trip_card.dart` lines 24–29
**Apply to:** `DashboardScreen` (watches 3 providers), `WeeklySummaryCard` (if it watches providers directly), `InProgressCard` (if it watches `trackingStateProvider`; prefer receiving `TrackingActive` as a constructor param so it can be a plain `StatelessWidget`)

```dart
class FooWidget extends ConsumerWidget {
  /// Create the widget.
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

### Manual Provider Declaration (no codegen)
**Source:** `lib/features/stats/providers/stats_providers.dart` lines 28–37, `lib/features/trips/providers/history_providers.dart` lines 12–16
**Apply to:** `todaysTripSummariesProvider` in `dashboard_providers.dart`

```dart
final Provider<AsyncValue<List<TripSummary>>> todaysTripSummariesProvider =
    Provider<AsyncValue<List<TripSummary>>>(
  (ref) { ... },
  name: 'todaysTripSummariesProvider',   // always include name
);
```

### Absolute Imports with `package:traevy/`
**Source:** Every file in the project
**Apply to:** All four new dashboard files

```dart
import 'package:traevy/config/constants.dart';       // not ../../../config/constants.dart
import 'package:traevy/features/dashboard/...';
```

### Doc Comments on All Public Members
**Source:** `lib/features/stats/widgets/stats_card.dart` lines 8–29, `lib/features/trips/widgets/trip_card.dart` lines 23–29
**Apply to:** Every `class`, `const Constructor`, and `final` field in all four new dashboard files.

```dart
/// Brief description of what this member does.
const WidgetName({required this.field, super.key});

/// What this field holds and where it comes from.
final int field;
```

Private methods (`_handleStart`, `_handleAddManualTrip`, `_showSettingsDialog`) do NOT need doc comments.

### `formatDuration` Usage
**Source:** `lib/features/stats/widgets/week_month_totals_card.dart` lines 33–38, `lib/shared/utils/formatters.dart`
**Apply to:** `WeeklySummaryCard` (weekly totals), `InProgressCard` (elapsed time)

```dart
import 'package:traevy/shared/utils/formatters.dart';
// ...
final display = seconds == 0 ? kStatsEmptyPlaceholder : formatDuration(seconds);
```

### `context.mounted` Guard After Every `await`
**Source:** `lib/features/tracking/screens/home_screen.dart` lines 101 and 107
**Apply to:** `_handleStart` and `_handleAddManualTrip` in `DashboardScreen`

```dart
await someAsyncCall();
if (!context.mounted) return;   // load-bearing — do not omit
```

### `AsyncValue.when` Dispatch
**Source:** `lib/features/stats/screens/stats_screen.dart` lines 39–77
**Apply to:** `TodayTripsSection.build()` for `asyncToday`

```dart
asyncToday.when(
  data: (trips) => ...,
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, _) => ...,
)
```

### `StatsCard` Card Shell Reuse
**Source:** `lib/features/stats/widgets/stats_card.dart`
**Apply to:** `WeeklySummaryCard` (tappable wrapper over `StatsCard`)

```dart
import 'package:traevy/features/stats/widgets/stats_card.dart';
// ...
StatsCard(
  title: kDashboardWeeklySummaryTitle,
  child: Column(...),
)
```

### Layout Spacing Constants at File Top
**Source:** `lib/features/stats/screens/stats_screen.dart` lines 11–13, `lib/features/trips/screens/history_screen.dart` lines 11–15
**Apply to:** All new dashboard widget files

```dart
const double _kHorizontalPadding = 16;
const double _kCardGap = 16;
const double _kBottomSafeArea = 32;
```

---

## Deletion Checklist

| File | Condition Before Deleting |
|------|--------------------------|
| `lib/features/tracking/screens/home_screen.dart` | All importers updated: `app.dart`, `test/widget/app_test.dart`, `test/unit/app_bootstrap_test.dart`. Run `grep -r "home_screen\|HomeScreen" lib/ test/ --include="*.dart"` — must return 0 results. |
| `test/widget/features/tracking/home_screen_test.dart` | `test/widget/features/dashboard/dashboard_screen_test.dart` created and passes. |

---

## No Analog Found

All files in this phase have close analogs in the codebase. No entries.

---

## Metadata

**Analog search scope:** `lib/features/stats/`, `lib/features/tracking/`, `lib/features/trips/`, `lib/config/`, `test/widget/`, `test/unit/`
**Files read:** 16
**Pattern extraction date:** 2026-04-27
