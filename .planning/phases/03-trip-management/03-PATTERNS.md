# Phase 3: Trip Management - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 12 (8 new, 4 modified)
**Analogs found:** 12 / 12

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/database/daos/trips_dao.dart` (MODIFIED) | DAO | CRUD | `lib/database/daos/sync_queue_dao.dart` | exact |
| `lib/features/trips/services/direction_label_service.dart` | service/utility | transform | `lib/shared/utils/polyline_codec.dart` | role-match |
| `lib/features/trips/providers/trip_management_providers.dart` | provider/notifier | request-response | `lib/features/tracking/providers/tracking_providers.dart` | exact |
| `lib/features/tracking/providers/backfill_provider.dart` | provider | batch | `lib/features/tracking/providers/tracking_providers.dart` | exact |
| `lib/features/tracking/services/tracking_service_controller.dart` (MODIFIED) | service | request-response | self | exact |
| `lib/features/tracking/screens/home_screen.dart` (MODIFIED) | screen/widget | request-response | self | exact |
| `lib/features/trips/widgets/edit_trip_sheet.dart` | widget | request-response | `lib/features/tracking/screens/home_screen.dart` | role-match |
| `lib/features/trips/widgets/manual_entry_sheet.dart` | widget | request-response | `lib/features/tracking/screens/home_screen.dart` | role-match |
| `test/unit/features/trips/direction_label_service_test.dart` | test | — | `test/unit/database/trips_dao_test.dart` | role-match |
| `test/unit/features/trips/trip_management_notifier_test.dart` | test | — | `test/unit/features/tracking/persist_finalized_trip_test.dart` | exact |
| `test/unit/features/trips/parse_hh_mm_test.dart` | test | — | `test/unit/database/trips_dao_test.dart` | role-match |
| `test/unit/features/trips/direction_backfill_test.dart` | test | — | `test/unit/features/tracking/persist_finalized_trip_test.dart` | exact |

---

## Pattern Assignments

### `lib/database/daos/trips_dao.dart` (MODIFIED — add `updateTrip`, `deleteTrip`)

**Analog:** `lib/database/daos/sync_queue_dao.dart`

**Imports pattern** (`trips_dao.dart` lines 1–5 — no changes needed):
```dart
import 'package:drift/drift.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/tables/trips_table.dart';

part 'trips_dao.g.dart';
```

**Core DAO method pattern — partial update via companion** (modeled on `sync_queue_dao.dart` lines 76–82, Drift `update().write()` pattern):
```dart
/// Update the trip identified by [companion.id.value]. Only columns
/// wrapped in [Value(...)] are touched; [Value.absent()] leaves the
/// column unchanged. Callers must always pass
/// `updatedAt: Value(DateTime.now().toUtc())`.
///
/// Pitfall 4 mitigation: the WHERE clause is set explicitly via
/// `..where((t) => t.id.equals(companion.id.value))`. Never use
/// `update(trips).replace(row)` for partial updates — that form
/// requires a full [TripRow], not a companion.
Future<void> updateTrip(TripsCompanion companion) {
  return (update(trips)
        ..where((t) => t.id.equals(companion.id.value)))
      .write(companion);
}
```

**Core DAO method pattern — delete by PK** (modeled on `sync_queue_dao.dart` lines 86–95, `customUpdate`/`delete` pattern):
```dart
/// Delete the trip with [id]. Intended to be called exclusively
/// inside an `appDatabase.transaction()` that also calls
/// `SyncQueueDao.enqueueDelete` — never standalone (D-08).
Future<void> deleteTrip(String id) {
  return (delete(trips)..where((t) => t.id.equals(id))).go();
}
```

---

### `lib/features/trips/services/direction_label_service.dart` (NEW)

**Analog:** `lib/shared/utils/polyline_codec.dart` (stateless pure-Dart utility class)

**Imports pattern** (follow `polyline_codec.dart` — minimal imports, package alias):
```dart
import 'package:traevy/config/constants.dart';
```

**Core pattern — const stateless class** (follow the established "plain Dart class with `const` constructor" pattern visible in `TrackingPermissionService` and `polyline_codec.dart`):
```dart
/// Stateless direction-labeling utility.
///
/// Takes [startTimeLocal] already converted to device-local time and
/// [morningCutoffHour] from [UserPreferencesValue.morningCutoffHour].
/// Returns [kDirectionToOffice] or [kDirectionToHome].
///
/// No Riverpod, no async — construct inline wherever needed. The const
/// constructor allows callers to write `const DirectionLabelService()`
/// without allocation cost.
class DirectionLabelService {
  /// Create a direction label service.
  const DirectionLabelService();

  /// Apply the morning-cutoff rule (D-04).
  ///
  /// [startTimeLocal] MUST already be in local time —
  /// call `startTime.toLocal()` at every call site.
  ///
  /// `startTimeLocal.hour < morningCutoffHour` → [kDirectionToOffice]
  /// `startTimeLocal.hour >= morningCutoffHour` → [kDirectionToHome]
  String label(DateTime startTimeLocal, int morningCutoffHour) {
    return startTimeLocal.hour < morningCutoffHour
        ? kDirectionToOffice
        : kDirectionToHome;
  }
}
```

---

### `lib/features/trips/providers/trip_management_providers.dart` (NEW)

**Analog:** `lib/features/tracking/providers/tracking_providers.dart`

**Imports pattern** (lines 1–13 of `tracking_providers.dart`; adapt to trips domain):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';
```

**Sealed state pattern** (modeled on `lib/features/tracking/state/tracking_state.dart` lines 26–105 — `@immutable sealed class` with `final class` variants):
```dart
/// Finite state for the edit / delete / manual-entry operations.
///
/// Use sealed exhaustive switch at every call site (CLAUDE.md rule:
/// "Use sealed classes for finite state"). Never add a `default` branch.
@immutable
sealed class TripManagementState {
  const TripManagementState();
}

final class TripManagementIdle extends TripManagementState {
  const TripManagementIdle();
}

final class TripManagementSaving extends TripManagementState {
  const TripManagementSaving();
}

final class TripManagementSaved extends TripManagementState {
  const TripManagementSaved();
}

final class TripManagementError extends TripManagementState {
  const TripManagementError(this.message);
  final String message;
}
```

**Provider declaration pattern** (lines 48–86 of `tracking_providers.dart` — manual `NotifierProvider`, named, keepAlive by default):
```dart
/// Notifier for trip edit / delete / manual-entry operations.
///
/// Manual provider (no @riverpod annotation) per the project-wide
/// constraint documented in `lib/database/providers.dart`. keepAlive = true
/// by default in Riverpod 3.x bare `NotifierProvider(...)`.
final NotifierProvider<TripManagementNotifier, TripManagementState>
    tripManagementProvider =
    NotifierProvider<TripManagementNotifier, TripManagementState>(
  TripManagementNotifier.new,
  name: 'tripManagementProvider',
);
```

**Notifier body pattern** (modeled on `TrackingNotifier` — `ref.read` for DAOs, `appDatabase.transaction()` for atomicity):
```dart
class TripManagementNotifier extends Notifier<TripManagementState> {
  @override
  TripManagementState build() => const TripManagementIdle();

  Future<void> editTrip({
    required String tripId,
    required String direction,
    required DateTime startTimeUtc,
    required DateTime endTimeUtc,
  }) async {
    state = const TripManagementSaving();
    try {
      final db = ref.read(appDatabaseProvider);
      final tripsDao = ref.read(tripsDaoProvider);
      final syncDao = ref.read(syncQueueDaoProvider);
      await db.transaction(() async {
        await tripsDao.updateTrip(
          TripsCompanion(
            id: Value(tripId),
            direction: Value(direction),
            startTime: Value(startTimeUtc),
            endTime: Value(endTimeUtc),
            durationSeconds:
                Value(endTimeUtc.difference(startTimeUtc).inSeconds),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await syncDao.enqueueUpdate(tripId);
      });
      state = const TripManagementSaved();
    } on Object catch (e) {
      state = TripManagementError(e.toString());
    }
  }

  Future<void> deleteTrip(String tripId) async { ... }

  Future<void> insertManualTrip({ ... }) async { ... }

  /// Reset to idle after the caller has consumed the Saved / Error result.
  void reset() => state = const TripManagementIdle();
}
```

---

### `lib/features/tracking/providers/backfill_provider.dart` (NEW)

**Analog:** `lib/features/tracking/providers/tracking_providers.dart`

**Imports pattern** (tracking_providers.dart lines 1–13; adapt for backfill):
```dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';
```

**FutureProvider pattern** (manual, keepAlive, named — matches all other providers in the project):
```dart
/// One-shot background backfill that labels all [kDirectionUnknown] rows
/// saved by Phase 2 with the correct direction from [DirectionLabelService].
///
/// keepAlive = true (default for bare `FutureProvider(...)` in Riverpod 3.x)
/// — must NOT be `.autoDispose` or the backfill re-runs on every widget
/// rebuild cycle (Pitfall 5).
///
/// Wiring: consume via `ref.watch(directionBackfillProvider)` inside
/// [TraevyApp.build] or a wrapper widget so the provider is read exactly
/// once at startup. The UI must not await or block on its result.
final FutureProvider<void> directionBackfillProvider = FutureProvider<void>(
  (ref) async {
    final db = ref.read(appDatabaseProvider);
    final prefsDao = ref.read(userPreferencesDaoProvider);
    final tripsDao = ref.read(tripsDaoProvider);
    final syncDao = ref.read(syncQueueDaoProvider);

    final prefs = await prefsDao.getOrDefault();
    final unknownTrips = await (db.select(db.trips)
          ..where((t) => t.direction.equals(kDirectionUnknown)))
        .get();

    if (unknownTrips.isEmpty) return;

    const labeler = DirectionLabelService();
    await db.transaction(() async {
      for (final trip in unknownTrips) {
        final direction = labeler.label(
          trip.startTime.toLocal(),  // Pitfall 2: must convert to local
          prefs.morningCutoffHour,
        );
        await tripsDao.updateTrip(TripsCompanion(
          id: Value(trip.id),
          direction: Value(direction),
          updatedAt: Value(DateTime.now().toUtc()),
        ));
        await syncDao.enqueueUpdate(trip.id);
      }
    });
  },
  name: 'directionBackfillProvider',
);
```

---

### `lib/features/tracking/services/tracking_service_controller.dart` (MODIFIED — replace `kDirectionUnknown` at line 150)

**Analog:** self

**Constructor injection pattern** (`tracking_service_controller.dart` lines 35–51 — add `UserPreferencesDao` as 6th named required parameter):
```dart
// BEFORE (line 35-45):
TrackingServiceController({
  required FlutterBackgroundService service,
  required AppDatabase database,
  required TripsDao tripsDao,
  required SyncQueueDao syncQueueDao,
  required TrackingNotificationService notifications,
})

// AFTER — add userPreferencesDao:
TrackingServiceController({
  required FlutterBackgroundService service,
  required AppDatabase database,
  required TripsDao tripsDao,
  required SyncQueueDao syncQueueDao,
  required TrackingNotificationService notifications,
  required UserPreferencesDao userPreferencesDao,
})
```

**Transaction pattern — the one-line direction change** (`tracking_service_controller.dart` lines 141–157; replace line 150):
```dart
// BEFORE (line 150):
direction: kDirectionUnknown,

// AFTER:
// Phase 3 D-06: label at save time using the cutoff from user prefs.
// startTime is UTC from the accumulator; convert to local for the rule.
final prefs = await _userPreferencesDao.getOrDefault();
const labeler = DirectionLabelService();
final direction = labeler.label(trip.startTime.toLocal(), prefs.morningCutoffHour);
// ... then inside the transaction companion:
direction: direction,
```

**Provider wiring update** (tracking_providers.dart lines 76–86 — add the 6th dependency):
```dart
// In trackingServiceControllerProvider:
final Provider<TrackingServiceController> trackingServiceControllerProvider =
    Provider<TrackingServiceController>(
  (ref) => TrackingServiceController(
    service: FlutterBackgroundService(),
    database: ref.watch(appDatabaseProvider),
    tripsDao: ref.watch(tripsDaoProvider),
    syncQueueDao: ref.watch(syncQueueDaoProvider),
    notifications: ref.watch(trackingNotificationServiceProvider),
    userPreferencesDao: ref.watch(userPreferencesDaoProvider), // NEW
  ),
  name: 'trackingServiceControllerProvider',
);
```

---

### `lib/features/tracking/screens/home_screen.dart` (MODIFIED — add FAB)

**Analog:** self

**Scaffold FAB pattern** (home_screen.dart lines 29–52 — `Scaffold` currently has no `floatingActionButton`; add it):
```dart
// Add to the Scaffold in HomeScreen.build:
floatingActionButton: FloatingActionButton(
  onPressed: () => _handleAddManualTrip(context, ref),
  tooltip: 'Add missed commute',
  child: const Icon(Icons.add),
),
```

**Async handler with `context.mounted` guard** (home_screen.dart lines 54–79 — copy the exact guard pattern from `_handleStart`):
```dart
Future<void> _handleAddManualTrip(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: const ManualEntrySheet(),
    ),
  );
  // context.mounted check matches the established pattern from _handleStart
  // (home_screen.dart line 57): always check after every await.
}
```

**AlertDialog pattern** (home_screen.dart lines 87–106 — `_showSettingsDialog` establishes the exact dialog structure to follow for delete confirmation):
```dart
// Pattern for delete confirmation — follow _showSettingsDialog exactly:
final confirmed = await showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Delete trip?'),
    content: const Text('This trip will be permanently removed.'),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialogContext, true),
        child: const Text('Delete'),
      ),
    ],
  ),
);
if (!context.mounted) return;  // Pitfall 1: always check after await
if (confirmed ?? false) {
  ref.read(tripManagementProvider.notifier).deleteTrip(tripId);
}
```

---

### `lib/features/trips/widgets/edit_trip_sheet.dart` (NEW)

**Analog:** `lib/features/tracking/screens/home_screen.dart` (ConsumerWidget + async handlers + context.mounted)

**Imports pattern** (home_screen.dart lines 1–6; adapt for sheet):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';
```

**ConsumerStatefulWidget pattern** — the sheet holds local form state (direction, startTime, endTime) that does not belong in Riverpod; use `ConsumerStatefulWidget` + `ConsumerState` per the CLAUDE.md rule "All state flows through Riverpod" for persistence operations, while ephemeral form state lives in `State`:
```dart
class EditTripSheet extends ConsumerStatefulWidget {
  const EditTripSheet({required this.tripId, required this.summary, super.key});

  final String tripId;
  final TripSummary summary;

  @override
  ConsumerState<EditTripSheet> createState() => _EditTripSheetState();
}

class _EditTripSheetState extends ConsumerState<EditTripSheet> {
  late String _direction;
  late DateTime _startTimeUtc;
  late DateTime _endTimeUtc;

  @override
  void initState() {
    super.initState();
    _direction = widget.summary.direction;
    _startTimeUtc = widget.summary.startTime;
    _endTimeUtc = widget.summary.endTime;
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTimeUtc.toLocal()),
    );
    if (!mounted) return;  // Pitfall 1 — always check after await
    if (picked != null) {
      final local = _startTimeUtc.toLocal();
      setState(() {
        _startTimeUtc = DateTime(
          local.year, local.month, local.day,
          picked.hour, picked.minute,
        ).toUtc();
      });
    }
  }

  Future<void> _save() async {
    await ref.read(tripManagementProvider.notifier).editTrip(
      tripId: widget.tripId,
      direction: _direction,
      startTimeUtc: _startTimeUtc,
      endTimeUtc: _endTimeUtc,
    );
    if (!mounted) return;  // Pitfall 1
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // SegmentedButton for direction — Material 3 standard (D-01)
    // Scaffold/Column layout stays under 100 lines (CLAUDE.md cap)
    ...
  }
}
```

**SegmentedButton for direction** (Material 3 — no existing analog in codebase, use RESEARCH.md Pattern 5):
```dart
SegmentedButton<String>(
  segments: const <ButtonSegment<String>>[
    ButtonSegment(value: kDirectionToOffice, label: Text('To office')),
    ButtonSegment(value: kDirectionToHome, label: Text('To home')),
  ],
  selected: <String>{_direction},
  onSelectionChanged: (Set<String> newSelection) {
    setState(() => _direction = newSelection.first);
  },
  multiSelectionEnabled: false,
);
```

---

### `lib/features/trips/widgets/manual_entry_sheet.dart` (NEW)

**Analog:** `lib/features/tracking/screens/home_screen.dart` (ConsumerWidget + async handlers + context.mounted); same sheet skeleton as `edit_trip_sheet.dart`

**Manual entry state fields** (form fields per D-09/D-10):
```dart
class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _durationController = TextEditingController();
  String? _durationError;
  late String _direction;  // defaults from DirectionLabelService at initState

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }
  ...
}
```

**Date picker pattern** (RESEARCH.md Pattern 7 — past-only constraint):
```dart
Future<void> _pickDate() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),  // cannot enter future trips
  );
  if (!mounted) return;  // Pitfall 1
  if (picked != null) setState(() => _selectedDate = picked);
}
```

**HH:MM validation + save** (RESEARCH.md Code Example — `parseHhMm` is a free function, not a method; keep in same file or a shared utils file):
```dart
/// Parse a `HH:MM` duration string. Returns null for malformed input or
/// values outside 0:00–23:59. No library needed — 4 lines of Dart.
Duration? parseHhMm(String input) {
  final parts = input.trim().split(':');
  if (parts.length != 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return Duration(hours: hours, minutes: minutes);
}

void _handleSave() {
  final duration = parseHhMm(_durationController.text);
  if (duration == null) {
    setState(() => _durationError = 'Enter a valid duration (e.g. 0:45)');
    return;
  }
  setState(() => _durationError = null);
  // D-10: start = midnight local → UTC; Pitfall 6 mitigation
  final startUtc = DateTime(
    _selectedDate.year, _selectedDate.month, _selectedDate.day,
  ).toUtc();
  final endUtc = startUtc.add(duration);
  ref.read(tripManagementProvider.notifier).insertManualTrip(
    startTimeUtc: startUtc,
    endTimeUtc: endUtc,
    direction: _direction,
  );
}
```

---

## Test Pattern Assignments

### `test/unit/features/trips/direction_label_service_test.dart` (NEW)

**Analog:** `test/unit/database/trips_dao_test.dart`

**Structure pattern** (trips_dao_test.dart lines 1–11 — plain `flutter_test` unit test, no fakes needed):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';

void main() {
  group('DirectionLabelService', () {
    const labeler = DirectionLabelService();

    test('hour < cutoff → kDirectionToOffice', () {
      expect(labeler.label(DateTime(2026, 1, 1, 7), 12), kDirectionToOffice);
    });

    test('hour == cutoff → kDirectionToHome', () {
      expect(labeler.label(DateTime(2026, 1, 1, 12), 12), kDirectionToHome);
    });

    test('UTC-offset pitfall: midnight UTC is local morning for UTC+5:30', () {
      // 2026-01-01 00:00 UTC = 05:30 IST — should be kDirectionToOffice.
      // The caller must pass startTime.toLocal(); this test verifies the
      // labeler works correctly given a local DateTime.
      final localMorning = DateTime(2026, 1, 1, 5, 30); // local
      expect(labeler.label(localMorning, 12), kDirectionToOffice);
    });
  });
}
```

---

### `test/unit/features/trips/trip_management_notifier_test.dart` (NEW)

**Analog:** `test/unit/features/tracking/persist_finalized_trip_test.dart`

**In-memory DB + ProviderContainer pattern** (persist_finalized_trip_test.dart lines 67–89 — AppDatabase in-memory, manual provider overrides):
```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';

void main() {
  group('TripManagementNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
      );
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    // Tests assert: editTrip → updateTrip + enqueueUpdate are both present;
    // deleteTrip → deleteTrip + enqueueDelete are both present;
    // Pitfall 4: updateTrip only mutates the targeted row.
  });
}
```

---

### `test/unit/features/trips/parse_hh_mm_test.dart` (NEW)

**Analog:** `test/unit/database/trips_dao_test.dart` (plain unit test, no DB needed)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/features/trips/widgets/manual_entry_sheet.dart';

void main() {
  group('parseHhMm', () {
    test('0:00 → zero duration', () {
      expect(parseHhMm('0:00'), const Duration());
    });
    test('23:59 → max valid duration', () {
      expect(parseHhMm('23:59'), const Duration(hours: 23, minutes: 59));
    });
    test('empty string → null', () { expect(parseHhMm(''), isNull); });
    test('24:00 → null (out of range)', () { expect(parseHhMm('24:00'), isNull); });
    test('no colon → null', () { expect(parseHhMm('90'), isNull); });
    test('non-numeric → null', () { expect(parseHhMm('a:b'), isNull); });
  });
}
```

---

### `test/unit/features/trips/direction_backfill_test.dart` (NEW)

**Analog:** `test/unit/features/tracking/persist_finalized_trip_test.dart`

**Pattern:** Use in-memory `AppDatabase` (NativeDatabase.memory()), insert `kDirectionUnknown` rows, run the backfill logic directly (call the DAO operations the provider calls — do not spin up a ProviderContainer), assert directions changed and already-labeled rows are untouched.

---

### `test/unit/database/trips_dao_test.dart` (EXTENDED)

**Analog:** self (lines 1–121 — copy setUp/tearDown pattern exactly)

Add test cases inside the existing `group('TripsDao', ...)`:
```dart
// updateTrip pattern — follows existing insert test at line 26:
test('updateTrip only mutates the targeted row (Pitfall 4)', () async {
  // Insert two rows, call updateTrip on one, assert the other is unchanged.
  ...
});

// deleteTrip pattern:
test('deleteTrip removes only the targeted row', () async {
  // Insert two rows, deleteTrip one, watchAllSummaries → hasLength(1).
  ...
});

// manual entry pattern:
test('manual entry insert has isManualEntry=true, distanceMeters=0.0, routePolyline=null', () async {
  ...
});
```

---

### `test/unit/features/tracking/persist_finalized_trip_test.dart` (EXTENDED)

**Analog:** self (lines 130–166)

Add one test case inside the existing `group`:
```dart
test(
  'persisted trip has a real direction (not kDirectionUnknown) after Phase 3',
  () async {
    // Requires injecting a UserPreferencesDao (with in-memory DB).
    // Assert summaries.single.direction != kDirectionUnknown after persist.
    ...
  },
);
```

---

## Shared Patterns

### Transaction pattern — atomic multi-DAO operations
**Source:** `lib/features/tracking/services/tracking_service_controller.dart` lines 141–158
**Apply to:** `TripManagementNotifier.editTrip`, `TripManagementNotifier.deleteTrip`, `TripManagementNotifier.insertManualTrip`, `backfill_provider.dart`
```dart
// The ONLY established transaction pattern in the project:
await _database.transaction(() async {
  await _tripsDao.someOperation(...);
  await _syncQueueDao.enqueueX(...);
});
```
The `appDatabase` instance is accessed via `ref.read(appDatabaseProvider)` in Riverpod notifiers.

### context.mounted guard after every await
**Source:** `lib/features/tracking/screens/home_screen.dart` line 57
**Apply to:** All async widget handlers in `edit_trip_sheet.dart`, `manual_entry_sheet.dart`, `home_screen.dart` modifications
```dart
// In ConsumerWidget / ConsumerState methods:
await someAsyncOperation();
if (!context.mounted) return;  // in ConsumerWidget
if (!mounted) return;           // in ConsumerState
```

### ProviderContainer override pattern for unit tests
**Source:** `test/unit/features/tracking/tracking_notifier_test.dart` lines 105–111
**Apply to:** `trip_management_notifier_test.dart`, `direction_backfill_test.dart`
```dart
container = ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    tripsDaoProvider.overrideWithValue(db.tripsDao),
    syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
  ],
);
```

### In-memory Drift DB setup/teardown for unit tests
**Source:** `test/unit/database/trips_dao_test.dart` lines 13–24
**Apply to:** All new unit tests that need the DB
```dart
setUp(() {
  db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
});

tearDown(() async {
  await db.close();
});
```

### Manual provider declaration (no @riverpod codegen)
**Source:** `lib/database/providers.dart` lines 38–64; `lib/features/tracking/providers/tracking_providers.dart` lines 48–95
**Apply to:** All new providers in Phase 3 (`tripManagementProvider`, `directionBackfillProvider`)
```dart
// Named, keepAlive=true (default), typed explicitly:
final Provider<Foo> fooProvider = Provider<Foo>(
  (ref) => Foo(...),
  name: 'fooProvider',
);

final NotifierProvider<FooNotifier, FooState> fooStateProvider =
    NotifierProvider<FooNotifier, FooState>(
  FooNotifier.new,
  name: 'fooStateProvider',
);
```

### Import path style
**Source:** Every existing file — e.g., `lib/database/daos/trips_dao.dart` line 2
**Apply to:** All new files
```dart
// Always package-absolute imports, never relative:
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';
// NOT: import '../../config/constants.dart';
```

### updatedAt in every TripsCompanion write
**Source:** trips_table.dart doc comment (referenced in RESEARCH.md anti-patterns)
**Apply to:** `updateTrip` calls in `TripManagementNotifier` and `backfill_provider.dart`
```dart
// Always pass this in every TripsCompanion for writes:
updatedAt: Value(DateTime.now().toUtc()),
```

### UTC-to-local conversion at every DirectionLabelService call site
**Source:** RESEARCH.md Pitfall 2; `tracking_service_controller.dart` line 150 context
**Apply to:** `tracking_service_controller.dart` (modified), `backfill_provider.dart`, `manual_entry_sheet.dart`
```dart
// Always convert before calling label():
labeler.label(trip.startTime.toLocal(), prefs.morningCutoffHour)
//                             ^^^^^^^^ required — startTime is stored UTC
```

---

## No Analog Found

All files in Phase 3 have close analogs in the existing codebase. No items in this section.

---

## Metadata

**Analog search scope:** `lib/`, `test/`
**Files scanned:** 32 Dart source files + 19 test files
**Pattern extraction date:** 2026-04-24
