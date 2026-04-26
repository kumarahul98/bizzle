# Phase 4: Trip History — Research

**Researched:** 2026-04-26
**Domain:** Flutter — map rendering (flutter_map), calendar widget (table_calendar), sliver list with sticky headers, Riverpod StreamProvider/FutureProvider
**Confidence:** HIGH (all package versions verified against pub.dev resolver; API patterns verified from official docs)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use `flutter_map` (OpenStreetMap tiles) — NOT `google_maps_flutter`. No API key required. `decodePolyline()` in `lib/shared/utils/polyline_codec.dart` already exists and returns `List<({double lat, double lng})>`.
- **D-02:** Add a "View history" outlined/text button on the existing home screen, below the "Start commute" CTA. No bottom NavigationBar. This is a temporary entry point; Phase 6 removes it.
- **D-03:** Group trips under sticky date-section headers. Format: "Today", "Yesterday", "Mon 21 Apr" for older dates. Client-side grouping from `watchAllSummaries()` stream.
- **D-04:** No new DAO method. `watchAllSummaries()` is the only data source for the list. Grouping in widget/helper, not the DB layer.
- **D-05:** `isManualEntry = true` trips hide the map entirely. Show "Manually entered — no route recorded" label + stats (duration, direction, date).
- **D-06:** GPS trip detail: map fills top (256dp), scrollable stats below.
- **D-07:** Full `TripRow` fetched once via `TripsDao.findById(id)` — not streamed.
- **D-08:** Edit/delete from history list reuse `EditTripSheet` and `HomeScreen.handleDeleteTrip`. How to surface them is Claude's discretion.
- **D-09:** Add `table_calendar`. Calendar shows event markers on days with trips. Tapping a date filters list to that day's trips.

### Claude's Discretion

- `flutter_map` version and tile provider configuration
- `table_calendar` version and marker styling
- Exact trip card layout (info density, icons, trailing actions)
- How edit/delete are triggered from list items (swipe, icon, long-press)
- Route name and file layout within `lib/features/trips/screens/`
- Whether history and detail are separate named routes or detail is pushed from history directly
- Calendar and list view switching mechanism (SegmentedButton, tab, toggle icon)

### Deferred Ideas (OUT OF SCOPE)

- Undo delete from history list
- Trip search or filtering by direction/date range
- Export trips to CSV/JSON
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HIST-01 | User can browse past commutes in a daily list view | `watchAllSummaries()` stream + client-side date grouping + `SliverPersistentHeader` sticky headers |
| HIST-02 | User can browse past commutes via calendar view | `table_calendar` 3.2.0 `eventLoader` pattern, `onDaySelected` callback, `calendarFormat: CalendarFormat.month` |
| HIST-03 | User can tap a trip to view route on map with full details | `flutter_map` 8.3.0 + `latlong2` 0.9.1, `decodePolyline()` → `List<LatLng>`, `CameraFit.coordinates()`, `PolylineLayer` |
</phase_requirements>

---

## Summary

Phase 4 adds the trip history browsing surface: a daily list screen with sticky date headers, a calendar view inside the same screen, and a trip detail screen with a flutter_map map and stats. All three capabilities draw data from existing DAO methods — `watchAllSummaries()` for the list/calendar and `findById()` for the detail — with no new database work.

The three new packages (`flutter_map`, `latlong2`, `table_calendar`) resolve cleanly against the existing `pubspec.yaml` at versions 8.3.0, 0.9.1, and 3.2.0 respectively. The `flutter_map ^8.1.0` constraint in the UI-SPEC selects 8.3.0 via pub resolver. The `latlong2 ^0.9.1` constraint is required because `flutter_map` 8.x pins `latlong2 ^0.9.1` — the standalone `latlong2 0.10.0` is NOT compatible with this flutter_map version.

The key implementation challenge is the `handleDeleteTrip` reuse across screens: the method is defined as an instance method on `HomeScreen` but its signature only uses passed-in `context` and `ref` parameters — no `this` state. It must be extracted to a standalone top-level function in a shared location so both `HomeScreen` and `HistoryScreen` can call it without importing `HomeScreen`.

**Primary recommendation:** Extract `handleDeleteTrip` to `lib/features/trips/services/trip_delete_service.dart` (or `lib/shared/utils/trip_actions.dart`) as a top-level function. Keep `HomeScreen` calling it from there. This removes the cross-feature import and is the only clean reuse path.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Daily list with sticky headers | UI (Flutter widget) | — | Pure read from Drift stream; grouping is presentation logic |
| Calendar view with event markers | UI (Flutter widget) | — | `table_calendar` consumes the same in-memory trip list; no server call |
| Trip detail map render | UI (Flutter widget) | — | `flutter_map` renders tiles + polyline client-side; data already in Drift |
| Polyline decode | Shared utility | UI | `decodePolyline()` in `lib/shared/utils/polyline_codec.dart` already exists |
| Trip fetch for detail | Drift DAO | — | `TripsDao.findById()` is a `Future` — fetched once in `initState` |
| Edit/delete actions | Shared function | UI trigger | Logic lives in `TripManagementNotifier`; UI triggers via a shared top-level function |

---

## Standard Stack

### Core (verified against pub resolver 2026-04-26)

| Library | Version Constraint | Resolved Version | Purpose | Source |
|---------|-------------------|-----------------|---------|--------|
| `flutter_map` | `^8.1.0` | `8.3.0` | Tile map widget with OSM tiles, Polyline layer | [VERIFIED: pub resolver dry-run] |
| `latlong2` | `^0.9.1` | `0.9.1` | `LatLng` type required by `flutter_map` 8.x | [VERIFIED: pub resolver dry-run] |
| `table_calendar` | `^3.1.3` | `3.2.0` | Monthly calendar with event markers, onDaySelected | [VERIFIED: pub resolver dry-run] |
| `intl` | already `^0.20.2` | already present | `DateFormat.jm()`, `DateFormat('EEE d MMM')` | [VERIFIED: pubspec.yaml] |

**Critical version note:** `flutter_map 8.x` transitively constrains `latlong2` to `^0.9.1`. Do NOT add `latlong2: ^0.10.0` — the pub resolver will pick `0.9.1` anyway because flutter_map's dependency wins, but a constraint mismatch will cause a warning. Use `^0.9.1` to match.

### Already Present (no new addition needed)

| Library | Version | Used By Phase 4 |
|---------|---------|-----------------|
| `flutter_riverpod` | `^3.3.1` | `StreamProvider` for history list, `FutureProvider` (or `initState` call) for detail |
| `drift` | `^2.32.1` | `watchAllSummaries()`, `findById()` |
| `intl` | `^0.20.2` | Date formatting throughout |

**Installation (pubspec.yaml additions only):**
```yaml
dependencies:
  flutter_map: ^8.1.0
  latlong2: ^0.9.1
  table_calendar: ^3.1.3
```

---

## Architecture Patterns

### System Architecture Diagram

```
User taps "View history"
        │
        ▼
HistoryScreen (/history)
  ├── StreamProvider<List<TripSummary>> (watchAllSummaries)
  │         │
  │         ▼
  │   Group by date → Map<DateTime, List<TripSummary>>
  │         │
  │   [List view]          [Calendar view]
  │         │                    │
  │   CustomScrollView      Column:
  │   ├─ SliverPersistent    TableCalendar
  │   │  Header (date)        eventLoader(date) → List<TripSummary>
  │   └─ SliverList           onDaySelected → _selectedDay
  │      (trip cards)         ListView (filtered by _selectedDay)
  │
  │  Tap card body
  │         │
  │         ▼
TripDetailScreen (/trip-detail, arguments: tripId)
  ├── FutureProvider or initState: TripsDao.findById(tripId)
  │         │
  │   [GPS trip: routePolyline != '']    [Manual trip: isManualEntry == true]
  │         │                                     │
  │   FlutterMap(                          Chip('Manually entered...')
  │     options: MapOptions(               + stats column (3 rows)
  │       initialCameraFit: CameraFit.coordinates(
  │         coordinates: latLngPoints,
  │         padding: EdgeInsets.all(32),
  │       ),
  │     ),
  │     children: [TileLayer, PolylineLayer,
  │                RichAttributionWidget],
  │   )
  │   + scrollable stats (6 rows)
  │
  │  Tap edit icon / "Edit trip" in options sheet
  │         │
  │         ▼
  │   showModalBottomSheet → EditTripSheet(summary: summary)
  │
  │  Tap delete icon / "Delete trip" in options sheet
  │         │
  │         ▼
  │   handleDeleteTrip(context, ref, tripId) [shared top-level fn]
```

### Recommended Project Structure

```
lib/features/trips/
├── screens/                         # NEW — Phase 4
│   ├── history_screen.dart          # List + calendar toggle (HIST-01, HIST-02)
│   └── trip_detail_screen.dart      # Map + stats (HIST-03)
├── providers/
│   ├── trip_management_providers.dart  # existing
│   └── history_providers.dart       # NEW — StreamProvider<List<TripSummary>>
├── services/
│   ├── direction_label_service.dart    # existing
│   └── trip_actions.dart            # NEW — handleDeleteTrip top-level fn
└── widgets/
    ├── edit_trip_sheet.dart             # existing
    ├── manual_entry_sheet.dart          # existing
    ├── trip_card.dart                   # NEW — reusable card (list + calendar sub-list)
    └── trip_stat_row.dart              # NEW — private _StatRow extracted widget
```

**Why `history_providers.dart` not inline:** Phase 5 stats screen also needs `watchAllSummaries()`. Declaring the `StreamProvider` once avoids duplication.

**Why `trip_actions.dart`:** `handleDeleteTrip` logic belongs to no single screen. Extracting it as a top-level function prevents `HistoryScreen` from importing `HomeScreen` (cross-feature widget import = code smell). `HomeScreen` is updated to call the extracted function.

### Pattern 1: Date Grouping (HIST-01)

**What:** Convert `List<TripSummary>` ordered newest-first into `Map<DateTime, List<TripSummary>>` keyed by date-only values, preserving order.
**When to use:** In the history provider or a helper called by the history screen widget.

```dart
// Source: [ASSUMED] — standard Dart grouping idiom
// Returns entries in insertion order (newest date first)
Map<DateTime, List<TripSummary>> groupTripsByDate(List<TripSummary> trips) {
  final result = <DateTime, List<TripSummary>>{};
  for (final trip in trips) {
    final local = trip.startTime.toLocal();
    final dateOnly = DateTime(local.year, local.month, local.day);
    (result[dateOnly] ??= <TripSummary>[]).add(trip);
  }
  return result;
}
```

**Date header label:**
```dart
// Source: [ASSUMED] — standard Flutter date comparison pattern
String formatDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (date == today) return kHistoryDateToday;       // 'Today'
  if (date == yesterday) return kHistoryDateYesterday; // 'Yesterday'
  return DateFormat('EEE d MMM').format(date);        // 'Mon 21 Apr'
}
```

### Pattern 2: SliverPersistentHeader for Sticky Date Headers (HIST-01)

**What:** Flutter-native sticky header that pins to the top of the scroll view as the user scrolls past its section. Requires a delegate class.
**When to use:** One per date group in the `CustomScrollView`.

```dart
// Source: [ASSUMED] — official Flutter SliverPersistentHeader pattern
// No new dependency required — this is core Flutter SDK.
class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DateHeaderDelegate({required this.label});
  final String label;

  static const double _kHeight = 40; // per UI-SPEC

  @override
  double get minExtent => _kHeight;

  @override
  double get maxExtent => _kHeight;

  @override
  bool shouldRebuild(_DateHeaderDelegate old) => old.label != label;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: _kHeight,
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

// Usage in CustomScrollView.slivers list:
SliverPersistentHeader(
  pinned: true,
  delegate: _DateHeaderDelegate(label: formatDateHeader(date)),
),
SliverList.list(
  children: trips.map((t) => TripCard(summary: t)).toList(),
),
```

### Pattern 3: flutter_map v8 — Route Map with CameraFit (HIST-03)

**What:** Display a route polyline on OpenStreetMap tiles, auto-fit to route bounds, non-interactive.
**Dependencies:** `flutter_map: ^8.1.0`, `latlong2: ^0.9.1`.

```dart
// Source: [CITED: docs.fleaflet.dev/llms-full.txt, docs.fleaflet.dev/layers/polyline-layer]
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';

// Convert existing decodePolyline output to List<LatLng>
List<LatLng> toLatLng(List<({double lat, double lng})> points) =>
    points.map((p) => LatLng(p.lat, p.lng)).toList();

// In TripDetailScreen build():
final rawPoints = decodePolyline(trip.routePolyline);
final latLngPoints = toLatLng(rawPoints);

SizedBox(
  height: kTripDetailMapHeight, // 256.0
  child: FlutterMap(
    options: MapOptions(
      initialCameraFit: CameraFit.coordinates(
        coordinates: latLngPoints,
        padding: const EdgeInsets.all(32),
      ),
    ),
    children: <Widget>[
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
      PolylineLayer(
        polylines: <Polyline>[
          Polyline(
            points: latLngPoints,
            color: Theme.of(context).colorScheme.primary,
            strokeWidth: 4,
          ),
        ],
      ),
      RichAttributionWidget(
        attributions: <SourceAttribution>[
          TextSourceAttribution('OpenStreetMap contributors'),
        ],
      ),
    ],
  ),
)
```

**Non-interactive (prevents map stealing scroll events from the outer CustomScrollView):**
```dart
// Source: [CITED: docs.fleaflet.dev/llms-full.txt]
// Option 1 (preferred per official docs): wrap in IgnorePointer
IgnorePointer(child: FlutterMap(...))

// Option 2: interactionOptions in MapOptions
MapOptions(
  interactionOptions: const InteractionOptions(
    flags: InteractiveFlag.none,
  ),
  initialCameraFit: ...,
)
```

**Recommendation:** Use `IgnorePointer` per the official documentation guidance (it is the officially recommended approach).

### Pattern 4: table_calendar v3.2.0 — Event Markers (HIST-02)

**What:** Monthly calendar with dot markers on days that have trips, filtered list below on day tap.
**Dependency:** `table_calendar: ^3.1.3` (resolves to 3.2.0).

```dart
// Source: [CITED: pub.dev/packages/table_calendar]
TableCalendar<TripSummary>(
  firstDay: DateTime.utc(2020, 1, 1),
  lastDay: DateTime.now(),
  focusedDay: _focusedDay,
  calendarFormat: CalendarFormat.month,
  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
  eventLoader: (day) {
    // Client-side lookup from the already-loaded trips list
    final dayKey = DateTime(day.year, day.month, day.day);
    return _groupedTrips[dayKey] ?? const <TripSummary>[];
  },
  onDaySelected: (selectedDay, focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  },
  headerStyle: const HeaderStyle(formatButtonVisible: false),
  calendarStyle: CalendarStyle(
    markerDecoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
    ),
    selectedDecoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
    ),
    todayDecoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: BoxShape.circle,
    ),
    markersMaxCount: 1,
  ),
)
```

### Pattern 5: handleDeleteTrip Extraction

**Problem:** `handleDeleteTrip` is currently an instance method on `HomeScreen`. Phase 4 trip cards need to call it from `HistoryScreen`. Importing `HomeScreen` into `HistoryScreen` is a cross-feature widget import.

**Solution:** Extract to a top-level function in `lib/features/trips/services/trip_actions.dart`.

```dart
// lib/features/trips/services/trip_actions.dart
// Source: [VERIFIED: lib/features/tracking/screens/home_screen.dart — logic identical]

/// Show delete confirmation dialog and call [TripManagementNotifier.deleteTrip].
///
/// Reused by HomeScreen and HistoryScreen trip cards.
Future<void> handleDeleteTrip(
  BuildContext context,
  WidgetRef ref,
  String tripId,
) async {
  // ... identical body to current HomeScreen.handleDeleteTrip ...
}
```

`HomeScreen.handleDeleteTrip` is then refactored to call this function. The `public` on `HomeScreen.handleDeleteTrip` can remain as a delegating wrapper or be removed once Phase 4 completes — but since STATE.md documents "Phase 3 Plan 04: handleDeleteTrip made public — very_good_analysis unused_element fires on private methods not referenced in the same file; Phase 4 trip cards invoke it across widget boundaries", the expected approach is to remove the redundancy by Phase 4 calling the extracted function directly.

### Pattern 6: History Screen Riverpod Provider

```dart
// lib/features/trips/providers/history_providers.dart
// Manual provider — no @riverpod annotation (project constraint, Phase 2 D-02)

/// Reactive stream of all trips as summaries, newest-first.
///
/// Consumed by HistoryScreen and CalendarView. Stats screen (Phase 5)
/// will also consume this provider.
final StreamProvider<List<TripSummary>> allTripSummariesProvider =
    StreamProvider<List<TripSummary>>(
  (ref) => ref.watch(tripsDaoProvider).watchAllSummaries(),
  name: 'allTripSummariesProvider',
);
```

### Anti-Patterns to Avoid

- **Importing HomeScreen into HistoryScreen:** Cross-feature widget import; extract `handleDeleteTrip` as a top-level function instead.
- **Streaming full TripRow for the list:** `watchAllSummaries()` already projects only the needed fields; never substitute with a query that includes `routePolyline` in the list stream (Pitfall 7 in DAO comment).
- **Creating a new DAO method for the list view:** D-04 locks this: grouping is client-side in the widget/helper layer.
- **Adding url_launcher for OSM attribution:** `RichAttributionWidget` works without `onTap` — `TextSourceAttribution('OpenStreetMap contributors')` with no callback satisfies the OSM license requirement without adding a dependency.
- **Using `flutter_map`'s `MapController.fitCamera()` in initState:** Controller is not safe until `onMapReady` fires. Use `initialCameraFit` in `MapOptions` instead (static, no controller needed) — this is exactly what the detail screen needs since the camera never changes after load.
- **Using `latlong2: ^0.10.0`:** Incompatible with `flutter_map 8.x` which pins `^0.9.1`. The resolver picks `0.9.1` anyway, but an explicit `^0.10.0` in pubspec.yaml would cause a resolution warning.
- **Hard-coding date format strings:** Use `DateFormat('EEE d MMM')` from `intl`, and define copy constants in `constants.dart` per the UI-SPEC contract.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Map tiles + polyline render | Custom canvas painter | `flutter_map` + `PolylineLayer` | flutter_map handles tile caching, zoom, projection, layer compositing — thousands of edge cases |
| Calendar widget | Custom grid of days | `table_calendar` | Handles month/week formats, localization, accessibility, event dots |
| Polyline decode | Custom polyline parser | `decodePolyline()` in `lib/shared/utils/polyline_codec.dart` | Already exists and is unit-tested |
| Sticky headers | Manual scroll controller + overlay | `SliverPersistentHeader(pinned: true)` | Flutter SDK native; no dependency needed |
| Date grouping | Complex stream transformation | Plain Dart `Map` with `for` loop | groupTripsByDate is a 10-line pure function; no library needed |

**Key insight:** Every "hand-rolled" item in this list has already been solved either in the project codebase or by a well-maintained package. The only custom code needed is the grouping logic and the date header formatter — both are trivial Dart.

---

## Common Pitfalls

### Pitfall 1: flutter_map MapController Used Before Ready
**What goes wrong:** Calling `_mapController.fitCamera(...)` or `_mapController.move(...)` inside `initState` or the widget `build` method before the map is fully initialised throws a `LateInitializationError` or silently does nothing.
**Why it happens:** The controller is only safe after the map widget completes its first layout pass and calls `onMapReady`.
**How to avoid:** Use `initialCameraFit: CameraFit.coordinates(coordinates: points, padding: EdgeInsets.all(32))` inside `MapOptions` instead of a controller call. This is static and set before rendering. No `MapController` instance needed for the detail screen.
**Warning signs:** App navigates to detail screen and the map renders at zoom level 1 showing the whole world.

### Pitfall 2: Empty Polyline Crash
**What goes wrong:** `CameraFit.coordinates(coordinates: [])` throws an assertion error (empty list has no bounding box).
**Why it happens:** `decodePolyline('')` returns `[]`. Manual trips have `routePolyline = ''`.
**How to avoid:** The D-05 layout branch already guards this: manual trips (`isManualEntry == true`) never render the map widget. Additionally, guard with `if (latLngPoints.isEmpty)` before constructing `CameraFit.coordinates`.
**Warning signs:** Detail screen crash for manually-entered trips.

### Pitfall 3: Date Comparison in groupTripsByDate
**What goes wrong:** `DateTime` equality in Dart compares both date AND time. Two `DateTime` objects representing noon and midnight on the same day are NOT equal.
**Why it happens:** `trip.startTime` is stored in UTC; grouping must compare date-only values.
**How to avoid:** Always convert to local time first (`trip.startTime.toLocal()`), then strip time components: `DateTime(local.year, local.month, local.day)`. Never compare `startTime` directly for date equality.
**Warning signs:** Every trip appears in its own date group (no grouping occurs).

### Pitfall 4: table_calendar CalendarFormat Toggle Still Visible
**What goes wrong:** The calendar renders a "2 weeks" / "month" toggle button in the header that users can tap to switch format, breaking the "month only" requirement from the UI-SPEC.
**Why it happens:** `formatButtonVisible` defaults to `true`.
**How to avoid:** Pass `headerStyle: const HeaderStyle(formatButtonVisible: false)` to `TableCalendar`.
**Warning signs:** A format-toggle button appears in the calendar header row.

### Pitfall 5: SliverPersistentHeader Requires Fixed Extent
**What goes wrong:** If `minExtent != maxExtent`, the header resizes during scroll in unexpected ways (or triggers layout exceptions if they differ by too much).
**Why it happens:** `SliverPersistentHeader` computes scroll offsets using these values.
**How to avoid:** The date header delegate has `minExtent = maxExtent = 40.0` (fixed height per UI-SPEC). The `shouldRebuild` override must compare the label, not be `true` always (causes unnecessary rebuilds).
**Warning signs:** Date headers animate in height during scrolling, or lint warns about missing `shouldRebuild` override.

### Pitfall 6: TripCard Widget Used in Both List and Calendar Sub-List
**What goes wrong:** If trip card is built as a column-level widget with `GestureDetector` wrapping and `ListTile` inside, the gesture detection can conflict with `table_calendar`'s own scroll/tap detection in the calendar view.
**Why it happens:** `table_calendar` uses a `TableCalendar` widget which handles its own taps internally.
**How to avoid:** The calendar sub-list is a plain `ListView` placed BELOW the `TableCalendar` in a `Column`, not inside it. The `TripCard` widget is reused in both positions with `InkWell` wrapping — no gesture conflict since the sub-list is outside the calendar widget entirely.
**Warning signs:** Tapping a trip card in the calendar view triggers the calendar's day-tap instead of navigating to detail.

### Pitfall 7: handleDeleteTrip Called Without context.mounted Check
**What goes wrong:** `ScaffoldMessenger.of(context).showSnackBar(...)` throws after the widget is unmounted (user navigated away during the async delete operation).
**Why it happens:** `deleteTrip` is async; the user can tap back before it completes.
**How to avoid:** The existing `handleDeleteTrip` implementation already includes `if (!context.mounted) return;` guards after every `await`. When extracted to a top-level function, preserve these guards exactly.
**Warning signs:** Flutter warning "Looking up a deactivated widget's ancestor is unsafe."

### Pitfall 8: Navigator.pop() After Delete on Detail Screen
**What goes wrong:** After a successful delete from the trip detail screen's AppBar delete action, the screen stays open showing a "Trip not found" error instead of returning to the history list.
**Why it happens:** The detail screen's state still holds the old `TripRow` even after delete; the navigator needs explicit `pop()`.
**How to avoid:** After calling `handleDeleteTrip` and confirming success (state is `TripManagementSaved`), call `Navigator.of(context).pop()` to return to history. The UI-SPEC documents this: "After successful delete, `Navigator.of(context).pop()` returns to history list."
**Warning signs:** Detail screen stays open after deletion; next visit to any screen reloads correctly.

---

## Code Examples

### Convert decodePolyline output to flutter_map LatLng

```dart
// Source: [VERIFIED: lib/shared/utils/polyline_codec.dart — return type confirmed]
// decodePolyline returns List<({double lat, double lng})>
// flutter_map Polyline.points expects List<LatLng> from latlong2

import 'package:latlong2/latlong2.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

List<LatLng> decodedToLatLng(String encoded) =>
    decodePolyline(encoded)
        .map((p) => LatLng(p.lat, p.lng))
        .toList();
```

### StreamProvider for trip summaries (manual Riverpod 3.x)

```dart
// Source: [VERIFIED: lib/database/providers.dart — manual provider pattern]
final StreamProvider<List<TripSummary>> allTripSummariesProvider =
    StreamProvider<List<TripSummary>>(
  (ref) => ref.watch(tripsDaoProvider).watchAllSummaries(),
  name: 'allTripSummariesProvider',
);
```

### Duration formatting utility

```dart
// Source: [ASSUMED] — standard Dart duration formatting
// Define once in lib/shared/utils/duration_formatter.dart
// (or lib/shared/utils/formatters.dart if one exists)
String formatDuration(int seconds) {
  if (seconds < 3600) {
    return '${seconds ~/ 60} min';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
}
```

**Note:** The UI-SPEC defines two cases: `< 60 min` → "N min", `>= 60 min` → "NhNNmin". The function above matches this. Since no formatter currently exists in `lib/shared/utils/`, this is a new file for Phase 4.

### Distance formatting utility

```dart
// Source: [ASSUMED] — standard Dart formatting
String formatDistance(double meters) {
  final km = meters / 1000;
  return '${km.toStringAsFixed(1)} km';
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `google_maps_flutter` for route display | `flutter_map` (OSM tiles) | D-01 locked decision | No API key, no Google Cloud console, zero infrastructure cost |
| `InteractiveFlag.none` field in `MapOptions` | `interactionOptions: InteractionOptions(flags: InteractiveFlag.none)` OR `IgnorePointer` wrapper | flutter_map v6+ | `InteractiveFlag` still exists; `interactionOptions` wraps it; `IgnorePointer` is official recommendation |
| `MapOptions.bounds` for initial fit | `MapOptions.initialCameraFit: CameraFit.coordinates(...)` | flutter_map v5+ | `bounds` parameter removed; `initialCameraFit` is the v5+ API |
| `latlong2` as standalone dependency | `latlong2` as transitive dependency of `flutter_map` | flutter_map v4 | Adding it explicitly at `^0.9.1` matches flutter_map's pin |
| `table_calendar` 3.0.x with separate `eventMarkerBuilder` | `table_calendar` 3.2.0 with `calendarStyle.markerDecoration` | v3.1+ | Marker styling through `CalendarStyle`, simpler API |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `groupTripsByDate()` helper placed in provider layer (history_providers.dart) or a utils file | Architecture Patterns | If placed in wrong layer, planner may need to restructure |
| A2 | `formatDuration()` and `formatDistance()` don't exist yet in `lib/shared/utils/` | Code Examples | If they do exist, use them instead of creating new ones |
| A3 | `IgnorePointer` is the preferred non-interactive approach for the detail screen (over `InteractionOptions`) | Pattern 3 | Both work; if lint rules flag `IgnorePointer` semantics, use `InteractionOptions` alternative |
| A4 | `TextSourceAttribution` with no `onTap` satisfies OSM attribution requirement | Pattern 3 | OSM guidelines technically require a link; if rejected in review, add `url_launcher` and `onTap` |
| A5 | `handleDeleteTrip` extraction to `trip_actions.dart` is the cleanest reuse path | Architecture Patterns | Planner could alternatively leave it on `HomeScreen` and have `HistoryScreen` import it — uglier but functional |

---

## Open Questions

1. **Duration/distance formatter location**
   - What we know: no `formatters.dart` or `duration_formatter.dart` found in `lib/shared/utils/`
   - What's unclear: whether the planner wants one file per formatter or a combined formatters file
   - Recommendation: Create `lib/shared/utils/formatters.dart` with both `formatDuration` and `formatDistance` — matches the "shared utils" convention

2. **trip_actions.dart vs keeping handleDeleteTrip on HomeScreen**
   - What we know: STATE.md documents "Phase 3 Plan 04: handleDeleteTrip made public — Phase 4 trip cards invoke it across widget boundaries"
   - What's unclear: whether "across widget boundaries" means the planner expected a shared function or expected HistoryScreen to call HomeScreen's method
   - Recommendation: Extract to `trip_actions.dart` — importing a screen widget for a utility function is an anti-pattern regardless

3. **flutter_map tile request load on Android emulator**
   - What we know: OSM tile requests require network; emulator has network access
   - What's unclear: whether CLAUDE.md's "test on real Android devices" note applies to map tile rendering
   - Recommendation: Flag in plan that map tile display should be verified on a device (not just emulator) given OSM network dependency

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All Phase 4 build | ✓ | 3.41.6 | — |
| `flutter_map` | HIST-03 map render | ✓ (not yet in pubspec) | 8.3.0 (pub resolver) | — |
| `latlong2` | HIST-03 LatLng type | ✓ (not yet in pubspec) | 0.9.1 (pub resolver) | — |
| `table_calendar` | HIST-02 calendar | ✓ (not yet in pubspec) | 3.2.0 (pub resolver) | — |
| OpenStreetMap tile server | HIST-03 map tiles (runtime) | ✓ (public CDN) | N/A | Blank map tiles (graceful degradation) |
| `intl` | Date formatting | ✓ in pubspec | ^0.20.2 | — |

**Missing dependencies with no fallback:** None — all three new packages resolve cleanly.

**Note on OSM tiles:** The `tile.openstreetmap.org` CDN is public and free for low-volume apps. No API key. Tiles load at runtime; offline tile caching is out of scope for v0.1 (and for this phase).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter 3.41.6) |
| Config file | none — standard Flutter test runner |
| Quick run command | `flutter test test/unit/features/trips/ test/widget/features/trips/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HIST-01 | `groupTripsByDate` groups correctly by local date | unit | `flutter test test/unit/features/trips/history_grouping_test.dart -x` | ❌ Wave 0 |
| HIST-01 | `formatDateHeader` returns "Today"/"Yesterday"/"Mon 21 Apr" | unit | `flutter test test/unit/features/trips/history_grouping_test.dart -x` | ❌ Wave 0 |
| HIST-01 | `formatDuration` formats < 60 min and >= 60 min correctly | unit | `flutter test test/unit/shared/formatters_test.dart -x` | ❌ Wave 0 |
| HIST-01 | History screen renders trip cards grouped under date headers | widget | `flutter test test/widget/features/trips/history_screen_test.dart -x` | ❌ Wave 0 |
| HIST-01 | History screen shows empty state when no trips | widget | `flutter test test/widget/features/trips/history_screen_test.dart -x` | ❌ Wave 0 |
| HIST-02 | Calendar view shows event marker on days with trips | widget | `flutter test test/widget/features/trips/history_screen_test.dart -x` | ❌ Wave 0 |
| HIST-02 | Tapping a calendar date filters the sub-list | widget | `flutter test test/widget/features/trips/history_screen_test.dart -x` | ❌ Wave 0 |
| HIST-03 | `decodedToLatLng` converts polyline records to LatLng list | unit | `flutter test test/unit/shared/formatters_test.dart -x` (or polyline test) | ❌ Wave 0 |
| HIST-03 | Trip detail screen shows CircularProgressIndicator while loading | widget | `flutter test test/widget/features/trips/trip_detail_screen_test.dart -x` | ❌ Wave 0 |
| HIST-03 | Trip detail screen shows "Trip not found" for invalid id | widget | `flutter test test/widget/features/trips/trip_detail_screen_test.dart -x` | ❌ Wave 0 |
| HIST-03 | Manual trip detail hides map, shows "Manually entered" chip | widget | `flutter test test/widget/features/trips/trip_detail_screen_test.dart -x` | ❌ Wave 0 |
| HIST-03 | GPS trip detail shows stats rows (Duration, Distance, etc.) | widget | `flutter test test/widget/features/trips/trip_detail_screen_test.dart -x` | ❌ Wave 0 |

**Note on flutter_map widget tests:** `FlutterMap` makes HTTP requests to OSM tile servers during widget tests unless mocked. Wrap the tile layer in a testable pattern or mock the HTTP client. Alternatively, test detail screen with a `manual` trip (no map rendered) for the core behavior, and test only stats rendering — tile network calls are not feasible in unit/widget tests.

### Sampling Rate

- **Per task commit:** `flutter test test/unit/features/trips/ test/unit/shared/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/unit/features/trips/history_grouping_test.dart` — covers HIST-01 grouping + date header formatting
- [ ] `test/unit/shared/formatters_test.dart` — covers `formatDuration`, `formatDistance`, `decodedToLatLng`
- [ ] `test/widget/features/trips/history_screen_test.dart` — covers HIST-01 list render, HIST-02 calendar, empty states
- [ ] `test/widget/features/trips/trip_detail_screen_test.dart` — covers HIST-03 (manual trip, loading state, not-found state, stats rendering)

---

## Project Constraints (from CLAUDE.md)

| Directive | Implication for Phase 4 |
|-----------|------------------------|
| Riverpod for all state — no `setState` except `ConsumerStatefulWidget` for local UI state | History screen uses `StreamProvider` for data; `setState` only for `_selectedDay` / `_viewMode` local toggle |
| No `dynamic` types | All providers, grouping maps, LatLng lists are fully typed |
| `very_good_analysis` strict linting | `public_member_api_docs: ignore` is already set — doc comments are not enforced on public members |
| `package:traevy/...` absolute imports | All new files use package imports, never relative |
| Constants in `lib/config/constants.dart` | UI-SPEC-defined constants (`kRouteHistory`, `kRouteTripDetail`, `kHistoryDateToday`, etc.) go there |
| Drift is the only data source for UI | `HistoryScreen` reads only from `watchAllSummaries()` via provider; `TripDetailScreen` reads only from `findById()` |
| Keep widgets under 100 lines | `TripCard`, `_DateHeaderDelegate`, `_StatRow` extracted as separate widgets/files |
| No dead code | `HomeScreen.handleDeleteTrip` either delegates to the extracted function or is removed once extraction is done |
| Manual Riverpod 3.x providers (no `@riverpod` annotation) | `allTripSummariesProvider` declared as `StreamProvider<List<TripSummary>>(...)` |
| Test on real Android devices for GPS behavior | Map tile rendering should be verified on device (OSM network tiles) |

---

## Sources

### Primary (HIGH confidence)
- `flutter_map 8.3.0` — verified via `flutter pub add --dry-run` against local pub resolver
- `latlong2 0.9.1` — verified as flutter_map 8.x transitive constraint via pub resolver
- `table_calendar 3.2.0` — verified via `flutter pub add --dry-run`
- `docs.fleaflet.dev/llms-full.txt` — CameraFit.coordinates API, RichAttributionWidget, InteractiveFlag.none / IgnorePointer pattern, PolylineLayer Polyline constructor
- `docs.fleaflet.dev/layers/polyline-layer` — Polyline(points: List<LatLng>, color, strokeWidth) confirmed
- `docs.fleaflet.dev/usage/options/interaction-options.md` — IgnorePointer as preferred non-interactive approach, InteractionOptions flags
- `pub.dev/packages/table_calendar` — CalendarFormat, eventLoader, onDaySelected, formatButtonVisible, selectedDayPredicate, firstDay/lastDay
- `lib/database/daos/trips_dao.dart` — watchAllSummaries() return type `Stream<List<TripSummary>>`, findById() return type `Future<TripRow?>`
- `lib/shared/utils/polyline_codec.dart` — decodePolyline() return type `List<({double lat, double lng})>`
- `lib/features/tracking/screens/home_screen.dart` — handleDeleteTrip signature, ConsumerWidget pattern
- `lib/database/providers.dart` — manual Riverpod provider pattern confirmed
- `analysis_options.yaml` — `public_member_api_docs: ignore` confirmed

### Secondary (MEDIUM confidence)
- `docs.fleaflet.dev/` (home page) — confirmed LatLng from latlong2, RichAttributionWidget, TileLayer urlTemplate pattern
- `pub.dev/packages/flutter_map/changelog` — v8 breaking changes summary (Point→Offset, tileDimension)

### Tertiary (LOW confidence)
- groupTripsByDate helper structure — [ASSUMED] standard Dart idiom
- formatDuration / formatDistance utilities not yet existing in codebase — [ASSUMED] based on grep finding no formatters file

---

## Metadata

**Confidence breakdown:**
- Standard stack versions: HIGH — all verified via pub resolver dry-run on the actual project
- flutter_map API (CameraFit, PolylineLayer, InteractiveFlag): HIGH — verified from official docs llms-full.txt
- table_calendar API: HIGH — verified from pub.dev documentation
- Architecture / grouping patterns: MEDIUM — standard Flutter patterns, codebase convention confirmed, specific function placement assumed
- Test structure: HIGH — mirrors existing Phase 3 test structure exactly

**Research date:** 2026-04-26
**Valid until:** 2026-07-26 (stable packages; flutter_map and table_calendar release infrequently)
