# Phase 4: Trip History - Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 13
**Analogs found:** 12 / 13

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/trips/screens/history_screen.dart` | screen (ConsumerStatefulWidget) | streaming (StreamProvider) | `lib/features/tracking/screens/tracking_screen.dart` | role-match |
| `lib/features/trips/screens/trip_detail_screen.dart` | screen (ConsumerStatefulWidget) | request-response (FutureProvider/initState) | `lib/features/tracking/screens/tracking_screen.dart` | role-match |
| `lib/features/trips/widgets/trip_card.dart` | widget | request-response | `lib/features/tracking/widgets/tracking_active_layout.dart` + `lib/features/trips/widgets/edit_trip_sheet.dart` | partial |
| `lib/features/trips/providers/history_providers.dart` | provider | streaming | `lib/database/providers.dart` | exact |
| `lib/features/trips/services/trip_actions.dart` | service (top-level fn) | request-response | `lib/features/trips/services/direction_label_service.dart` + `lib/features/tracking/screens/home_screen.dart` (handleDeleteTrip body) | role-match |
| `lib/shared/utils/formatters.dart` | utility (pure functions) | transform | `lib/features/trips/providers/trip_management_providers.dart` (parseHhMm) | partial |
| `lib/config/routes.dart` | config | — | `lib/config/routes.dart` (self) | exact |
| `lib/config/constants.dart` | config | — | `lib/config/constants.dart` (self) | exact |
| `lib/features/tracking/screens/home_screen.dart` | screen (modify) | request-response | self | exact |
| `pubspec.yaml` | config | — | no analog | — |
| `test/unit/features/trips/history_grouping_test.dart` | unit test | — | `test/unit/features/trips/direction_label_service_test.dart` | exact |
| `test/unit/shared/formatters_test.dart` | unit test | — | `test/unit/shared/polyline_codec_test.dart` | exact |
| `test/widget/features/trips/history_screen_test.dart` | widget test | — | `test/widget/features/trips/edit_trip_sheet_test.dart` | exact |
| `test/widget/features/trips/trip_detail_screen_test.dart` | widget test | — | `test/widget/features/trips/edit_trip_sheet_test.dart` | exact |

---

## Pattern Assignments

### `lib/features/trips/screens/history_screen.dart` (screen, streaming)

**Analog:** `lib/features/tracking/screens/tracking_screen.dart`

**Imports pattern** (tracking_screen.dart lines 1–13):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
// ... feature-specific imports
```
History screen equivalent:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/features/trips/services/trip_actions.dart';
import 'package:traevy/features/trips/widgets/edit_trip_sheet.dart';
import 'package:traevy/features/trips/widgets/trip_card.dart';
import 'package:traevy/shared/utils/formatters.dart';
```

**ConsumerStatefulWidget scaffold** (tracking_screen.dart lines 18–24):
```dart
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}
```

**initState with postFrameCallback** (tracking_screen.dart lines 26–33):
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _runPreflight());
}
```
Note: History screen uses `setState` for local UI state (`_selectedDay`, `_viewMode`) — not postFrameCallback. Local `setState` is acceptable for ephemeral UI state per project constraint ("setState only for local toggle").

**StreamProvider watch pattern** — use `ref.watch(allTripSummariesProvider)` and handle `AsyncValue` with `.when(data:, loading:, error:)`:
```dart
// In build():
final asyncTrips = ref.watch(allTripSummariesProvider);
return asyncTrips.when(
  data: (trips) => _buildContent(trips),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => Center(child: Text('Error: $e')),
);
```

**mounted check after async** (tracking_screen.dart line 39, home_screen.dart line 82):
```dart
if (!mounted) return; // ConsumerState uses mounted, not context.mounted
```

---

### `lib/features/trips/screens/trip_detail_screen.dart` (screen, request-response)

**Analog:** `lib/features/tracking/screens/tracking_screen.dart`

**ConsumerStatefulWidget + initState fetch** (tracking_screen.dart lines 18–34):
```dart
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({required this.tripId, super.key});
  final String tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  TripRow? _trip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTrip());
  }

  Future<void> _loadTrip() async {
    final dao = ref.read(tripsDaoProvider);
    final trip = await dao.findById(widget.tripId);
    if (!mounted) return;
    setState(() {
      _trip = trip;
      _loading = false;
    });
  }
}
```

**Two-branch layout for manual vs GPS trips** (per D-05/D-06):
The `isManualEntry` flag on `TripRow` (same field as `TripSummary.isManualEntry`) drives layout. Guard empty polyline before constructing `CameraFit.coordinates` (Pitfall 2 in RESEARCH.md).

**showModalBottomSheet reuse** (home_screen.dart lines 75–83):
```dart
Future<void> _handleAddManualTrip(BuildContext context, WidgetRef ref) async {
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
Apply same pattern for `EditTripSheet` from detail screen's edit action.

**Navigator.pop after delete** — after `handleDeleteTrip` confirms `TripManagementSaved`, call `Navigator.of(context).pop()` to return to history list (Pitfall 8 in RESEARCH.md).

---

### `lib/features/trips/widgets/trip_card.dart` (widget, request-response)

**Analog:** `lib/features/trips/widgets/edit_trip_sheet.dart` (imports, const sizing, colorScheme usage)

**Imports pattern** (edit_trip_sheet.dart lines 1–7):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';
```

**Private sizing constants** (edit_trip_sheet.dart lines 9–13):
```dart
const double _kFieldGap = 16;
const double _kSectionGap = 24;
```
Trip card follows the same pattern: define private `_k*` sizing constants at file top.

**colorScheme access** (edit_trip_sheet.dart line 130):
```dart
final colorScheme = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;
```

**const constructor** (edit_trip_sheet.dart line 31):
```dart
const EditTripSheet({required this.summary, super.key});
```
Trip card: `const TripCard({required this.summary, super.key});`

`TripCard` is a `ConsumerWidget` (reads no providers itself — edit/delete actions are passed via callbacks or trigger via `handleDeleteTrip`/`showModalBottomSheet` invoked with `context, ref`). Keep under 100 lines per CLAUDE.md; extract sub-parts if needed.

---

### `lib/features/trips/providers/history_providers.dart` (provider, streaming)

**Analog:** `lib/database/providers.dart` — exact pattern for manual Riverpod 3.x providers

**Manual StreamProvider declaration** (providers.dart lines 38–51 structure):
```dart
/// Reactive stream of all trips as summaries, newest-first.
///
/// Consumed by HistoryScreen (Phase 4) and StatsScreen (Phase 5).
/// Manual provider — no @riverpod annotation per lib/database/providers.dart
/// constraint (analyzer version conflict documented there).
final StreamProvider<List<TripSummary>> allTripSummariesProvider =
    StreamProvider<List<TripSummary>>(
  (ref) => ref.watch(tripsDaoProvider).watchAllSummaries(),
  name: 'allTripSummariesProvider',
);
```

**Provider naming convention** (providers.dart lines 38–64): every provider receives a `name:` parameter matching the variable name as a string. This is the only project-wide provider convention (see all four providers in providers.dart).

**Watch vs read**: use `ref.watch(tripsDaoProvider)` inside the provider body — consistent with `userPreferencesDaoProvider` pattern (providers.dart line 62).

---

### `lib/features/trips/services/trip_actions.dart` (service, request-response)

**Analog:** `lib/features/tracking/screens/home_screen.dart` lines 150–194 (handleDeleteTrip body to extract)

**Complete handleDeleteTrip body to copy verbatim** (home_screen.dart lines 150–194):
```dart
/// Show a delete confirmation dialog and call
/// [TripManagementNotifier.deleteTrip] on confirmation.
///
/// Two-step guard (T-03-14): user must tap the destructive 'Delete'
/// button explicitly; dialog dismissal is treated as cancel.
///
/// Called from HomeScreen and HistoryScreen trip cards.
Future<void> handleDeleteTrip(
  BuildContext context,
  WidgetRef ref,
  String tripId,
) async {
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete trip?'),
      content: const Text('This trip will be permanently removed.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (confirmed ?? false) {
    await ref.read(tripManagementProvider.notifier).deleteTrip(tripId);
    if (!context.mounted) return;
    final state = ref.read(tripManagementProvider);
    if (state is TripManagementSaved) {
      ref.read(tripManagementProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip deleted')),
      );
    } else if (state is TripManagementError) {
      ref.read(tripManagementProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete the trip. Try again.")),
      );
    }
  }
}
```
This is a top-level function (not a class method). Imports needed:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';
```

After extracting, `HomeScreen.handleDeleteTrip` becomes a one-line delegating call:
```dart
Future<void> handleDeleteTrip(
  BuildContext context,
  WidgetRef ref,
  String tripId,
) => tripActions.handleDeleteTrip(context, ref, tripId);
```
Or remove `HomeScreen.handleDeleteTrip` and have every caller use the top-level function directly.

---

### `lib/shared/utils/formatters.dart` (utility, transform)

**Analog:** `lib/features/trips/providers/trip_management_providers.dart` lines 183–195 (parseHhMm — pure top-level utility function pattern)

**Pure top-level function pattern** (trip_management_providers.dart lines 183–195):
```dart
/// Parse a `HH:MM` duration string.
///
/// Returns null for any of: malformed input, ...
Duration? parseHhMm(String input) {
  final parts = input.trim().split(':');
  // ...
}
```

Apply same pattern — pure top-level functions with doc comments:
```dart
/// Format a duration in seconds to a human-readable string.
///
/// Under 60 minutes: 'N min'. 60 minutes or more: 'NhNNmin'.
String formatDuration(int seconds) {
  if (seconds < 3600) {
    return '${seconds ~/ 60} min';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
}

/// Format a distance in meters to a kilometres string with one decimal place.
String formatDistance(double meters) {
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
```

Also add `decodedToLatLng` here (per RESEARCH.md validation test map):
```dart
import 'package:latlong2/latlong2.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

/// Convert the output of [decodePolyline] to a list of [LatLng] points
/// suitable for `flutter_map`'s [PolylineLayer].
List<LatLng> decodedToLatLng(String encoded) =>
    decodePolyline(encoded).map((p) => LatLng(p.lat, p.lng)).toList();
```

---

### `lib/config/routes.dart` (config, modify)

**Analog:** `lib/config/routes.dart` (self — append to existing pattern)

**Existing pattern** (routes.dart lines 1–19):
```dart
import 'package:flutter/widgets.dart';
import 'package:traevy/features/tracking/screens/tracking_screen.dart';

/// Live tracking screen route (D-12).
const String kRouteTracking = '/tracking';

/// App-level named routes.
///
/// The map is declared `final` instead of `const` because Dart 3.11
/// rejects `const` maps whose values are tear-off [WidgetBuilder]
/// closures.
final Map<String, WidgetBuilder> kAppRoutes = <String, WidgetBuilder>{
  kRouteTracking: (BuildContext context) => const TrackingScreen(),
};
```

Phase 4 appends:
```dart
import 'package:traevy/features/trips/screens/history_screen.dart';
import 'package:traevy/features/trips/screens/trip_detail_screen.dart';

/// Trip history screen route (D-02).
const String kRouteHistory = '/history';

/// Trip detail screen route (HIST-03). Argument: tripId (String).
const String kRouteTripDetail = '/trip-detail';
```
And adds entries to `kAppRoutes`:
```dart
kRouteHistory: (BuildContext context) => const HistoryScreen(),
kRouteTripDetail: (BuildContext context) {
  final tripId = ModalRoute.of(context)!.settings.arguments! as String;
  return TripDetailScreen(tripId: tripId);
},
```

---

### `lib/config/constants.dart` (config, modify)

**Analog:** `lib/config/constants.dart` (self — append after Phase 2 section)

**Existing section pattern** (constants.dart lines 87–90):
```dart
// ---------------------------------------------------------------------------
// Phase 2: Core Tracking (GPS, accumulators, notification)
// ---------------------------------------------------------------------------
```

Phase 4 appends a new section block:
```dart
// ---------------------------------------------------------------------------
// Phase 4: Trip History
// ---------------------------------------------------------------------------

/// Route constant for the history screen (D-02).
/// Mirrors kRouteHistory in lib/config/routes.dart — defined here too so
/// widgets can import constants.dart without importing routes.dart.
// Note: Only add string copy/label constants here, not route strings which
// are already in routes.dart. Add label constants like:

/// Date header label for today's date group in the history list (D-03).
const String kHistoryDateToday = 'Today';

/// Date header label for yesterday's date group in the history list (D-03).
const String kHistoryDateYesterday = 'Yesterday';

/// Height (logical pixels) of the map widget on the trip detail screen (D-06).
const double kTripDetailMapHeight = 256.0;

/// Label shown on manual trips in place of the route map (D-05).
const String kManualEntryNoRouteLabel = 'Manually entered — no route recorded';
```

---

### `lib/features/tracking/screens/home_screen.dart` (screen, modify)

**Analog:** self — minimal addition below existing FilledButton.icon

**Existing button pattern** (home_screen.dart lines 53–59):
```dart
FractionallySizedBox(
  widthFactor: 0.7,
  child: FilledButton.icon(
    icon: const Icon(Icons.play_arrow_rounded),
    label: const Text('Start commute'),
    onPressed: () => _handleStart(context, ref),
  ),
),
```

Phase 4 adds a "View history" button immediately below, wrapped in `SizedBox(height: 12)` gap + new `OutlinedButton`:
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
Import addition: `kRouteHistory` from `package:traevy/config/routes.dart` (already imported in home_screen.dart line 3).

Also update `handleDeleteTrip` to delegate to the extracted top-level function from `trip_actions.dart`.

---

## Test Pattern Assignments

### `test/unit/features/trips/history_grouping_test.dart` (unit test)

**Analog:** `test/unit/features/trips/direction_label_service_test.dart`

**Exact test file structure to copy** (direction_label_service_test.dart lines 1–84):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';

void main() {
  group('DirectionLabelService', () {
    // test cases using expect(actual, matcher)
  });
}
```

Phase 4 equivalent:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/trips/providers/history_providers.dart'; // or wherever groupTripsByDate lives
import 'package:traevy/shared/utils/formatters.dart';

void main() {
  group('groupTripsByDate', () { ... });
  group('formatDateHeader', () { ... });
}
```

---

### `test/unit/shared/formatters_test.dart` (unit test)

**Analog:** `test/unit/shared/polyline_codec_test.dart`

**Structure to copy** (polyline_codec_test.dart lines 1–81):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

void main() {
  group('encodePolyline', () {
    test('returns empty string for empty input', () {
      expect(encodePolyline(const []), isEmpty);
    });
    // ...
  });
}
```

Phase 4 equivalent:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/shared/utils/formatters.dart';

void main() {
  group('formatDuration', () { ... });
  group('formatDistance', () { ... });
  group('decodedToLatLng', () { ... });
}
```

---

### `test/widget/features/trips/history_screen_test.dart` and `trip_detail_screen_test.dart` (widget tests)

**Analog:** `test/widget/features/trips/edit_trip_sheet_test.dart`

**Complete widget test scaffold to copy** (edit_trip_sheet_test.dart lines 1–84):
```dart
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/widgets/edit_trip_sheet.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('EditTripSheet', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() async => db.close());

    Widget buildSheet(TripSummary summary) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        ],
        child: MaterialApp(
          home: Scaffold(body: EditTripSheet(summary: summary)),
        ),
      );
    }

    TripSummary makeSummary({String direction = kDirectionToOffice}) { ... }

    testWidgets('...', (tester) async {
      await tester.pumpWidget(buildSheet(makeSummary()));
      expect(find.text('Edit trip'), findsOneWidget);
    });
  });
}
```

Key points for history screen test:
- `ProviderScope.overrides` must include `appDatabaseProvider`, `tripsDaoProvider`, `syncQueueDaoProvider` — same three as edit_trip_sheet_test.
- Also override `allTripSummariesProvider` when testing empty/populated states.
- `pumpWidget` pattern: wrap in `MaterialApp(routes: kAppRoutes, home: HistoryScreen())`.
- `tester.pump()` after async stream emissions.

Key points for trip detail screen test:
- `flutter_map` makes HTTP tile requests — wrap `TileLayer` in a `testMode`-flagged conditional or test only with `isManualEntry = true` trips (no map rendered), per RESEARCH.md note on tile network calls.
- `buildTrip` factory helper mirrors `makeSummary` — constructs a `TripRow` via `db.tripsDao.insertTrip`.

---

## Shared Patterns

### Manual Riverpod 3.x Provider Declaration
**Source:** `lib/database/providers.dart` lines 38–64
**Apply to:** `lib/features/trips/providers/history_providers.dart`
```dart
final Provider<SomeType> someProvider = Provider<SomeType>(
  (ref) => ...,
  name: 'someProvider', // REQUIRED: name string matches variable name
);
```

### mounted Check After Every await
**Source:** `lib/features/tracking/screens/home_screen.dart` lines 82, 88; `lib/features/trips/widgets/edit_trip_sheet.dart` lines 60, 84, 112
**Apply to:** `history_screen.dart`, `trip_detail_screen.dart`, `trip_actions.dart`
- Inside `ConsumerStatefulWidget` states: use `if (!mounted) return;`
- Inside `ConsumerWidget` or top-level functions: use `if (!context.mounted) return;`

### TripManagementSaved / TripManagementError State Consumption
**Source:** `lib/features/trips/widgets/edit_trip_sheet.dart` lines 113–126
**Apply to:** `trip_actions.dart`, `trip_detail_screen.dart`
```dart
final state = ref.read(tripManagementProvider);
if (state is TripManagementSaved) {
  ref.read(tripManagementProvider.notifier).reset();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Trip deleted')),
  );
} else if (state is TripManagementError) {
  ref.read(tripManagementProvider.notifier).reset();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Couldn't delete the trip. Try again.")),
  );
}
```

### showModalBottomSheet for EditTripSheet
**Source:** `lib/features/tracking/screens/home_screen.dart` lines 75–83
**Apply to:** `trip_card.dart` (edit action), `trip_detail_screen.dart` (edit action)
```dart
await showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheetContext) => EditTripSheet(summary: summary),
);
if (!context.mounted) return;
```

### Error-Only try/catch with Object
**Source:** `lib/features/trips/providers/trip_management_providers.dart` line 84
**Apply to:** Any async operation in new services
```dart
} on Object catch (e) {
  state = TripManagementError(e.toString());
}
```

### Absolute Package Imports
**Source:** Every file in `lib/` — e.g., `home_screen.dart` line 3
**Apply to:** All new files
```dart
import 'package:traevy/config/constants.dart'; // YES
import '../../../config/constants.dart';         // NO — never relative
```

### In-memory DB for Widget Tests
**Source:** `test/widget/features/trips/edit_trip_sheet_test.dart` lines 17–21
**Apply to:** `history_screen_test.dart`, `trip_detail_screen_test.dart`
```dart
db = AppDatabase(
  DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  ),
);
```

### Constants Section Header
**Source:** `lib/config/constants.dart` lines 87–90
**Apply to:** New Phase 4 constants block in `constants.dart`
```dart
// ---------------------------------------------------------------------------
// Phase 4: Trip History
// ---------------------------------------------------------------------------
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `pubspec.yaml` (add flutter_map, latlong2, table_calendar) | config | — | No existing analog for adding new packages — follow RESEARCH.md versions exactly: `flutter_map: ^8.1.0`, `latlong2: ^0.9.1`, `table_calendar: ^3.1.3` |

---

## Metadata

**Analog search scope:** `lib/` (all Dart files), `test/` (all test files)
**Files scanned:** 25 source files, 20 test files
**Key finding:** The project uses `package:traevy/...` absolute imports throughout. The app name/package is `traevy`. All new files must use this prefix, never relative paths.
**Key finding:** `TripSummary` already has `isManualEntry` — the detail screen layout branch (D-05) can use it directly without a DB fetch to check.
**Key finding:** `handleDeleteTrip` in `home_screen.dart` is the exact body to extract to `trip_actions.dart` — zero logic changes needed, only relocation and import fix.
**Pattern extraction date:** 2026-04-26
