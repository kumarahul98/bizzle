# Phase 5: Stats & Analytics - Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 14 (10 new, 4 modified)
**Analogs found:** 14 / 14

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/stats/providers/stats_providers.dart` | provider | request-response (derived) | `lib/features/trips/providers/history_providers.dart` | exact |
| `lib/features/stats/services/stats_service.dart` | service | transform (pure Dart) | `lib/features/tracking/services/trip_accumulator.dart` | role-match |
| `lib/features/stats/screens/stats_screen.dart` | screen/component | request-response | `lib/features/trips/screens/history_screen.dart` | exact |
| `lib/features/stats/widgets/stats_card.dart` | widget | request-response | `lib/features/trips/widgets/trip_card.dart` | role-match |
| `lib/features/stats/widgets/week_month_totals_card.dart` | widget | request-response | `lib/features/trips/widgets/trip_card.dart` | role-match |
| `lib/features/stats/widgets/direction_averages_card.dart` | widget | request-response | `lib/features/trips/widgets/trip_card.dart` | role-match |
| `lib/features/stats/widgets/best_worst_day_card.dart` | widget | request-response | `lib/features/trips/widgets/trip_card.dart` | role-match |
| `lib/features/stats/widgets/trend_chart_card.dart` | widget | request-response | `lib/features/trips/widgets/trip_card.dart` | partial-match (no chart analog exists) |
| `lib/features/stats/widgets/traffic_waste_card.dart` | widget | request-response | `lib/features/trips/widgets/trip_card.dart` | role-match |
| `lib/config/constants.dart` | config | — | `lib/config/constants.dart` (existing file, append-only) | exact |
| `lib/config/routes.dart` | config | — | `lib/config/routes.dart` (existing file, append pattern) | exact |
| `lib/features/tracking/screens/home_screen.dart` | screen (modify) | — | itself (add one `OutlinedButton` block) | exact |
| `test/unit/features/stats/stats_service_test.dart` | test | — | `test/unit/features/trips/history_grouping_test.dart` | exact |
| `test/widget/features/stats/stats_screen_test.dart` | test | — | `test/widget/features/trips/history_screen_test.dart` | exact |

---

## Pattern Assignments

### `lib/features/stats/providers/stats_providers.dart` (provider, derived)

**Analog:** `lib/features/trips/providers/history_providers.dart`

**Imports pattern** (lines 1-5):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/providers.dart';
```
Stats providers file adds its own service import: `package:traevy/features/stats/services/stats_service.dart`.

**Manual provider declaration pattern** (lines 12-16 of history_providers.dart):
```dart
final StreamProvider<List<TripSummary>> allTripSummariesProvider =
    StreamProvider<List<TripSummary>>(
      (ref) => ref.watch(tripsDaoProvider).watchAllSummaries(),
      name: 'allTripSummariesProvider',
    );
```
The stats provider is a derived `Provider<AsyncValue<StatsSummary>>` that watches `allTripSummariesProvider` and transforms via `whenData`. Pattern — no `@riverpod` annotation, explicit type params, `name:` argument always present:
```dart
final Provider<AsyncValue<StatsSummary>> statsSummaryProvider =
    Provider<AsyncValue<StatsSummary>>(
      (ref) {
        final asyncTrips = ref.watch(allTripSummariesProvider);
        return asyncTrips.whenData(
          (trips) => computeStatsSummary(trips, DateTime.now()),
        );
      },
      name: 'statsSummaryProvider',
    );
```

**UTC→local conversion pattern** (lines 30-33 of history_providers.dart — canonical pattern for the entire codebase):
```dart
final local = trip.startTime.toLocal();
final dateOnly = DateTime(local.year, local.month, local.day);
```
Copy this pattern verbatim inside `computeStatsSummary`'s per-trip loop.

---

### `lib/features/stats/services/stats_service.dart` (service, pure transform)

**Analog:** `lib/features/tracking/services/trip_accumulator.dart`

**Imports pattern** (lines 1-5 of trip_accumulator.dart):
```dart
import 'package:flutter/foundation.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
```
Stats service imports: `package:traevy/config/constants.dart` and `package:traevy/database/daos/trips_dao.dart` (for `TripSummary`). No Flutter/widget imports — pure Dart file.

**Immutable data class pattern** — `@immutable` + `const` constructor, all fields `final`, doc comment on class and every public field (lines 14-71 of trip_accumulator.dart, `TripSnapshot` class):
```dart
@immutable
class TripSnapshot {
  const TripSnapshot({
    required this.startedAt,
    required this.elapsedSeconds,
    // ...
  });

  /// Wall-clock time (UTC) the trip started.
  final DateTime startedAt;
  // ...
}
```
`StatsSummary` follows this exact shape: `@immutable`, `const` constructor, `required` named params, `final` typed fields, doc comment on every field.

**Single-pass accumulator pattern** (lines 128-185 of trip_accumulator.dart, `addSample`):
```dart
void addSample(Position p) {
  // ... per-sample guards ...
  _distanceMeters += Geolocator.distanceBetween(...);
  if (deltaSec <= kTrackingMaxAttributableGapSeconds) {
    if (prev.speed >= kStuckSpeedThresholdMs) {
      _timeMovingSeconds += deltaSecInt;
    } else {
      _timeStuckSeconds += deltaSecInt;
    }
  }
}
```
`computeStatsSummary` follows the same idiom: one loop over `trips`, multiple accumulators updated in-place, result returned at the end. All thresholds reference `constants.dart`, never raw literals.

**Injectable `now` for testability** — `TripAccumulator.snapshot(DateTime now)` (line 189) and `TripAccumulator.finalize(DateTime endedAt)` (line 203) both accept `DateTime` injection instead of calling `DateTime.now()` internally. `computeStatsSummary(List<TripSummary> trips, DateTime now)` follows the same contract.

**`@visibleForTesting` exposure pattern** (lines 223-232 of trip_accumulator.dart):
```dart
@visibleForTesting
double get distanceMetersForTest => _distanceMeters;
```
Stats service has no private state (it is a pure function), so this pattern is not needed there, but unit test access to `StatsSummary` fields is direct via public final fields.

---

### `lib/features/stats/screens/stats_screen.dart` (screen, ConsumerWidget)

**Analog:** `lib/features/trips/screens/history_screen.dart`

**Imports pattern** (lines 1-8 of history_screen.dart):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/features/trips/widgets/trip_card.dart';
```
Stats screen replaces trips-specific imports with stats equivalents; `package:traevy/features/stats/providers/stats_providers.dart` and each card widget.

**Layout constants block** (lines 11-16 of history_screen.dart — private, file-top):
```dart
const double _kHorizontalPadding = 16;
const double _kEmptyIconSize = 64;
const double _kEmptyHeadingGap = 24;
const double _kEmptyBodyGap = 8;
const double _kDateHeaderHeight = 40;
```
Stats screen declares its own private layout constants with the same `_k` prefix. Non-layout string constants go in `lib/config/constants.dart` (not inline).

**ConsumerStatefulWidget vs ConsumerWidget** — `HistoryScreen` is `ConsumerStatefulWidget` (needs `_ViewMode` toggle state). `StatsScreen` has no local state — use the simpler `ConsumerWidget` form:
```dart
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ...
  }
}
```

**`AsyncValue.when` dispatch pattern** (lines 81-97 of history_screen.dart — the entire `body:` block):
```dart
body: asyncTrips.when(
  data: (trips) {
    // ... build body from data ...
  },
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, _) => Center(child: Text('Error loading trips: $error')),
),
```
Stats screen uses the same three-branch dispatch. Replace `asyncTrips` with `asyncStats` (from `ref.watch(statsSummaryProvider)`). The `data:` branch builds a `ListView` of stat cards; `loading:` and `error:` match exactly.

**AppBar pattern** (lines 68-79 of history_screen.dart):
```dart
appBar: AppBar(
  title: const Text('History'),
  actions: <Widget>[ ... ],
),
```
Stats screen: `AppBar(title: const Text('Stats'))` — no actions (UI-SPEC).

**Empty state as private widget** (`_EmptyState` class, lines 241-271 of history_screen.dart) — per-card `—` placeholder is the Phase 5 empty strategy (D-10), so `StatsScreen` does not need a full-screen `_EmptyState` class. Cards handle null values inline.

**`colorScheme` and `textTheme` local variables** (lines 151-152 of history_screen.dart):
```dart
final colorScheme = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;
```
All stat card widgets and the screen extract these at the top of `build` — never repeat `Theme.of(context)` mid-widget.

---

### Stat card widgets (all 5: `stats_card.dart`, `week_month_totals_card.dart`, `direction_averages_card.dart`, `best_worst_day_card.dart`, `trend_chart_card.dart`, `traffic_waste_card.dart`)

**Analog:** `lib/features/trips/widgets/trip_card.dart`

**Imports pattern** (lines 1-10 of trip_card.dart):
```dart
import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/shared/utils/formatters.dart';
```
Each stat card imports `package:flutter/material.dart`, `package:traevy/config/constants.dart`, and `package:traevy/shared/utils/formatters.dart` (for `formatDuration`). `TrendChartCard` additionally imports `package:fl_chart/fl_chart.dart`.

**Private spacing constants** (lines 13-15 of trip_card.dart):
```dart
const double _kCardPadding = 16;
const double _kIconSize = 24;
const double _kIconGap = 12;
```
Each card file declares its own `_k`-prefixed private layout constants. No magic numbers inline.

**`StatelessWidget` (not `ConsumerWidget`)** — `TripCard` is a `ConsumerWidget` because it has delete/edit actions. Stat cards are read-only display — use `StatelessWidget`. They receive their data as constructor parameters (the screen passes `StatsSummary` fields down):
```dart
class WeekMonthTotalsCard extends StatelessWidget {
  const WeekMonthTotalsCard({
    required this.weekTotalSeconds,
    required this.monthTotalSeconds,
    super.key,
  });

  final int weekTotalSeconds;
  final int monthTotalSeconds;
  // ...
}
```

**`Card` with `surfaceContainerLow` pattern** (lines 38-40 of trip_card.dart):
```dart
return Card(
  color: colorScheme.surfaceContainerLow,
  child: InkWell(
```
Stat cards use `Card(color: colorScheme.surfaceContainerLow, child: Padding(...))` — no `InkWell` (UI-SPEC: cards are read-only, no tap handler).

**Padding + Column layout** (lines 46-79 of trip_card.dart):
```dart
child: Padding(
  padding: const EdgeInsets.all(_kCardPadding),
  child: Row(
    children: <Widget>[
      // ...
    ],
  ),
),
```
Stat cards use `Padding(padding: const EdgeInsets.all(16), child: Column(...))` since content is vertically stacked, not a row.

**`formatDuration` usage** (lines 35-36 of trip_card.dart):
```dart
final duration = formatDuration(summary.durationSeconds);
// ...
Text(duration, style: textTheme.bodyMedium?.copyWith(...))
```
Stat cards call `formatDuration(weekTotalSeconds)` for any duration display. Duration values go through this formatter — never manual string concatenation.

**`colorScheme` from `Theme.of(context)`** (line 33 of trip_card.dart):
```dart
final colorScheme = Theme.of(context).colorScheme;
```
Every color token comes from `colorScheme.*` — never `Color(0xFF...)`.

**`Chip` widget pattern for direction** (lines 136-153 of trip_card.dart, `_DirectionChip`):
```dart
class _DirectionChip extends StatelessWidget {
  const _DirectionChip({required this.direction});

  final String direction;

  @override
  Widget build(BuildContext context) {
    final label = direction == kDirectionToOffice ? 'To office' : ...;
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}
```
`BestWorstDayCard` uses `Chip` with `visualDensity: VisualDensity.standard` (not compact — 44px touch target). Best chip uses `color: colorScheme.primary`; worst chip uses `colorScheme.error`. This is the existing `Chip` API in the project.

---

### `lib/config/constants.dart` (modify — append Phase 5 section)

**Analog:** Itself. Pattern from Phase 4 section (lines 194-239).

**Phase-section header pattern** (lines 193-194 of constants.dart):
```dart
// ---------------------------------------------------------------------------
// Phase 4: Trip History
// ---------------------------------------------------------------------------
```
Append a `// Phase 5: Stats & Analytics` section header, then add constants below it. Never reorder or modify existing constants.

**Constant declaration pattern** (lines 197-215 of constants.dart):
```dart
/// Date header label for today's date group in the history list (D-03).
const String kHistoryDateToday = 'Today';
```
Every new constant: `///` doc comment referencing the requirement it satisfies (e.g., `(D-10)` or `(STAT-01)`), then `const` typed declaration with `k` prefix and camelCase name.

**New constants this phase adds** (names locked by UI-SPEC §Constants Required):
- `kStatsEmptyPlaceholder` — `'—'` (em-dash, D-10 empty placeholder)
- `kStatsErrorMessage` — `'Could not load stats.'` (RESEARCH open question 2, Option A)
- `kStatsTrendChartHeight` — `192.0` (UI-SPEC spacing exceptions)
- `kRouteStats` — must move to `routes.dart` (see below); referenced from constants only via the route constant

---

### `lib/config/routes.dart` (modify — add `/stats` route)

**Analog:** Itself. Pattern from lines 8-32.

**Route constant pattern** (lines 9-18 of routes.dart):
```dart
/// Home route — ...
const String kRouteHome = '/';

/// Live tracking screen route (D-12).
const String kRouteTracking = '/tracking';

/// Trip history screen route (D-02).
const String kRouteHistory = '/history';
```
Add: `/// Stats screen route (D-02, Phase 5). const String kRouteStats = '/stats';`

**`kAppRoutes` map entry pattern** (lines 25-32 of routes.dart):
```dart
final Map<String, WidgetBuilder> kAppRoutes = <String, WidgetBuilder>{
  kRouteTracking: (BuildContext context) => const TrackingScreen(),
  kRouteHistory: (BuildContext context) => const HistoryScreen(),
  kRouteTripDetail: (BuildContext context) { ... },
};
```
Add `kRouteStats: (BuildContext context) => const StatsScreen()` entry. Import `StatsScreen` at top of file following the existing `import 'package:traevy/features/trips/screens/history_screen.dart';` pattern.

---

### `lib/features/tracking/screens/home_screen.dart` (modify — add "View stats" button)

**Analog:** Itself. The "View history" button block (lines 62-68) is the exact pattern to copy.

**Button block to copy** (lines 62-68 of home_screen.dart):
```dart
const SizedBox(height: 12),
FractionallySizedBox(
  widthFactor: 0.7,
  child: OutlinedButton(
    onPressed: () => Navigator.pushNamed(context, kRouteHistory),
    child: const Text('View history'),
  ),
),
```
Insert immediately after line 68:
```dart
const SizedBox(height: 12),
FractionallySizedBox(
  widthFactor: 0.7,
  child: OutlinedButton(
    onPressed: () => Navigator.pushNamed(context, kRouteStats),
    child: const Text('View stats'),
  ),
),
```
No other changes to this file. The `kRouteStats` constant must be imported via `package:traevy/config/routes.dart` (already imported at line 3).

---

### `test/unit/features/stats/stats_service_test.dart` (new — pure function test)

**Analog:** `test/unit/features/trips/history_grouping_test.dart`

**Imports pattern** (lines 1-13 of history_grouping_test.dart):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:uuid/uuid.dart';
```
Stats service test imports: `flutter_test`, `package:traevy/config/constants.dart`, `package:traevy/database/daos/trips_dao.dart`, `package:traevy/features/stats/services/stats_service.dart`, `package:uuid/uuid.dart`. For locale-pinned day tests add `package:intl/intl.dart`.

**`_makeTrip` helper pattern** (lines 14-27 of history_grouping_test.dart):
```dart
TripSummary _makeTrip(DateTime startTime, {bool isManualEntry = false}) {
  final endTime = startTime.add(const Duration(hours: 1));
  return TripSummary(
    id: const Uuid().v4(),
    startTime: startTime,
    endTime: endTime,
    durationSeconds: endTime.difference(startTime).inSeconds,
    distanceMeters: 0,
    direction: kDirectionToOffice,
    timeMovingSeconds: 0,
    timeStuckSeconds: 0,
    isManualEntry: isManualEntry,
  );
}
```
Stats service test uses a similar `_trip(...)` helper with additional named params: `durationSeconds`, `direction`, `timeStuckSeconds`, `isManualEntry`. Same `TripSummary(...)` constructor call — all fields explicit, no named-param shortcuts.

**`group` / `test` nesting pattern** (lines 29-99 of history_grouping_test.dart):
```dart
void main() {
  group('groupTripsByDate', () {
    test('returns empty map for empty input', () {
      expect(groupTripsByDate(const <TripSummary>[]), isEmpty);
    });
    // ...
  });
}
```
One top-level `group('computeStatsSummary', ...)` containing named subtests for each STAT requirement. Locale pin goes in `setUpAll`: `Intl.defaultLocale = 'en_US';`.

**UTC input convention** (line 40 of history_grouping_test.dart):
```dart
final trip1 = _makeTrip(DateTime.utc(2026, 1, 1, 8));
```
All `startTime` values passed as `DateTime.utc(...)` — never local — to match `TripSummary.startTime` contract. The `now` argument to `computeStatsSummary` is a local `DateTime(...)` (no `.utc()`).

---

### `test/widget/features/stats/stats_screen_test.dart` (new — widget test)

**Analog:** `test/widget/features/trips/history_screen_test.dart`

**Imports pattern** (lines 10-23 of history_screen_test.dart):
```dart
import 'package:drift/dart.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';
import 'package:uuid/uuid.dart';
```
Stats screen widget test is simpler: no Drift in-memory DB needed because `StatsScreen` has no delete/edit actions. Override only `allTripSummariesProvider` — the derived `statsSummaryProvider` flows through automatically. Imports needed: `flutter/material.dart`, `flutter_riverpod`, `flutter_test`, `traevy/config/constants.dart`, `traevy/database/daos/trips_dao.dart`, `traevy/features/trips/providers/history_providers.dart`, `traevy/features/stats/screens/stats_screen.dart`, `uuid/uuid.dart`.

**`ProviderScope` override pattern** (lines 59-71 of history_screen_test.dart):
```dart
Widget buildScreen({List<TripSummary> trips = const <TripSummary>[]}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      tripsDaoProvider.overrideWithValue(db.tripsDao),
      syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
      allTripSummariesProvider.overrideWith(
        (ref) => Stream<List<TripSummary>>.value(trips),
      ),
    ],
    child: const MaterialApp(home: HistoryScreen()),
  );
}
```
Stats screen version (simpler — no DB needed):
```dart
Widget buildScreen({List<TripSummary> trips = const <TripSummary>[]}) {
  return ProviderScope(
    overrides: [
      allTripSummariesProvider.overrideWith(
        (ref) => Stream<List<TripSummary>>.value(trips),
      ),
    ],
    child: const MaterialApp(home: StatsScreen()),
  );
}
```
`statsSummaryProvider` derives from `allTripSummariesProvider` so the override flows through without needing a second override.

**`testWidgets` + `tester.pump()` pattern** (lines 73-85 of history_screen_test.dart):
```dart
testWidgets('renders History as AppBar title when trips exist', (tester) async {
  await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
  await tester.pump();
  expect(find.text('History'), findsOneWidget);
});
```
Stats tests follow same shape: `pumpWidget`, single `pump()` (not `pumpAndSettle`), `expect(find.text(...), findsOneWidget)`. Tests to include: AppBar title `'Stats'`, card titles present for non-empty input, `kStatsEmptyPlaceholder` (`'—'`) visible on empty input, `CircularProgressIndicator` absent after pump.

---

## Shared Patterns

### Manual Riverpod 3.x Provider Declaration
**Source:** `lib/database/providers.dart` (lines 38-64) and `lib/features/trips/providers/history_providers.dart` (lines 12-16)
**Apply to:** `stats_providers.dart`
```dart
final Provider<T> providerName = Provider<T>(
  (ref) { ... },
  name: 'providerName',  // always include name: for DevTools
);
```
No `@riverpod` annotation. Explicit generic type on both the variable and the `Provider<T>(...)` call. `name:` argument always present.

### UTC-to-Local Conversion Before Date Math
**Source:** `lib/features/trips/providers/history_providers.dart` (lines 30-33)
**Apply to:** `stats_service.dart` — every per-trip loop iteration
```dart
final local = trip.startTime.toLocal();
final dateOnly = DateTime(local.year, local.month, local.day);
```
Never call `.weekday`, `.month`, `.year` on a UTC `DateTime` for bucketing. Always `toLocal()` first, then strip time by constructing `DateTime(y, m, d)`.

### Error Handling / AsyncValue Dispatch
**Source:** `lib/features/trips/screens/history_screen.dart` (lines 81-97)
**Apply to:** `stats_screen.dart` body
```dart
body: asyncTrips.when(
  data: (trips) { /* build body */ },
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, _) => Center(child: Text('Error loading trips: $error')),
),
```
`loading:` always `const Center(child: CircularProgressIndicator())`. `error:` always `Center(child: Text(...))` — no `RefreshIndicator` (UI-SPEC deferred).

### Color — Never Raw Hex
**Source:** `lib/features/trips/screens/history_screen.dart` (lines 151, 296-300) and `lib/features/trips/widgets/trip_card.dart` (lines 33, 39, 109)
**Apply to:** all stat card widgets and `stats_screen.dart`
```dart
final colorScheme = Theme.of(context).colorScheme;
// Card background:
Card(color: colorScheme.surfaceContainerLow, ...)
// Error color:
color: Theme.of(sheetContext).colorScheme.error
```
`colorScheme.surfaceContainerLow` is the locked card background (UI-SPEC §Color). `colorScheme.primary` for accent (best chip, chart line). `colorScheme.error` for worst chip.

### `formatDuration` for All Duration Displays
**Source:** `lib/shared/utils/formatters.dart` (lines 7-14) and usage in `lib/features/trips/widgets/trip_card.dart` (line 36)
**Apply to:** all stat card widgets that render a duration value
```dart
import 'package:traevy/shared/utils/formatters.dart';
// ...
Text(formatDuration(weekTotalSeconds), style: textTheme.headlineMedium)
```
`formatDuration` handles both `< 60 min` (`'N min'`) and `>= 1 h` (`'NhNNmin'`) formats. Do not inline this logic in card widgets.

### Private Layout Constants with `_k` Prefix
**Source:** `lib/features/trips/screens/history_screen.dart` (lines 11-16), `lib/features/trips/widgets/trip_card.dart` (lines 13-15)
**Apply to:** `stats_screen.dart` and every stat card widget file
```dart
// Private, file-top, multiples of 4:
const double _kCardPadding = 16;
const double _kIconGap = 12;
```
Screen-level or widget-specific layout values go as private `_k` constants in the same file. Cross-file layout values (e.g., `kStatsTrendChartHeight`) go in `lib/config/constants.dart`.

### `package:traevy/...` Absolute Imports
**Source:** Every file in the codebase — e.g., `lib/features/trips/widgets/trip_card.dart` (lines 4-9)
**Apply to:** all Phase 5 files
```dart
import 'package:traevy/config/constants.dart';  // correct
// import '../../../config/constants.dart';      // WRONG — relative import
```
All imports use `package:traevy/` prefix. No relative imports anywhere in the project.

---

## No Analog Found

All 14 files have usable analogs. The one partial-match case:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/features/stats/widgets/trend_chart_card.dart` | widget | request-response | No existing `fl_chart` usage in the codebase — this is the first chart widget. Use RESEARCH.md Pattern 5 (fl_chart `LineChart` example) for the chart internals; use `trip_card.dart` for the card shell (imports, padding, `Card` color). |

---

## Metadata

**Analog search scope:** `lib/features/`, `lib/config/`, `lib/database/`, `lib/shared/`, `test/unit/features/`, `test/widget/features/`
**Files read:** 10 (history_providers.dart, history_screen.dart, trip_card.dart, history_grouping_test.dart, history_screen_test.dart, trip_accumulator.dart, home_screen.dart, constants.dart, routes.dart, database/providers.dart, formatters.dart)
**Pattern extraction date:** 2026-04-26
