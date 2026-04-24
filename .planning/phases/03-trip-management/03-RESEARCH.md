# Phase 3: Trip Management - Research

**Researched:** 2026-04-24
**Domain:** Flutter trip editing (modal bottom sheet), direction auto-labeling, delete flow, manual entry, Drift DAO extensions, one-shot backfill
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Trip editing uses a **modal bottom sheet** — not a full-screen route. Swipe-to-dismiss closes without saving. Contains: direction toggle (SegmentedButton "To office" / "To home"), start time picker, end time picker, Cancel and Save buttons.
- **D-02:** No new named route for editing. The bottom sheet is invoked directly from wherever the trip is shown.
- **D-03:** Auto-label logic reads `morning_cutoff_hour` from `UserPreferencesDao`. Fallback: `kDefaultDirectionCutoffHour = 12`.
- **D-04:** Labeling rule: `startTime.hour < morning_cutoff_hour → kDirectionToOffice`, `startTime.hour >= morning_cutoff_hour → kDirectionToHome`. Uses local time.
- **D-05:** On app start, one-shot background backfill queries all `direction == kDirectionUnknown` trips and batch-updates them. Must not block the home screen render. Enqueues `kSyncActionUpdate` for each trip updated.
- **D-06:** New trips are labeled at save time inside the tracking finalization flow (same transaction as `TripsDao.insertTrip`). The `kDirectionUnknown` default in `TrackingServiceController.persistFinalizedTrip` is replaced.
- **D-07:** Delete shows a Material `AlertDialog` with "Delete trip?" confirmation. After delete: remove from `trips` table, enqueue `kSyncActionDelete` in `sync_queue`. Show a `SnackBar` "Trip deleted" (no undo).
- **D-08:** Both DAO calls (`TripsDao.deleteTrip` + `SyncQueueDao.enqueueDelete`) are wrapped in a single `appDatabase.transaction()` for atomicity.
- **D-09:** A **[+] FAB** on the home screen invokes manual entry. Same modal bottom sheet pattern. Form fields: date picker, duration text field (HH:MM), direction toggle.
- **D-10:** Manual trip saved with `isManualEntry = true`, `routePolyline = null` (nullable column), `distanceMeters = 0.0`, `timeMovingSeconds = 0`, `timeStuckSeconds = 0`. Start time = midnight of chosen date; end time = `startTime + duration`.
- **D-11:** HH:MM input validation: max 23:59. Empty or malformed → inline field error, block save.
- **D-12:** `TripsDao` gains `updateTrip(TripsCompanion companion)` and `deleteTrip(String id)`.
- **D-13:** `SyncQueueDao` gains `enqueueUpdate(String tripId)` and `enqueueDelete(String tripId, String payload)`. (Note: `enqueueUpdate` already exists — see §Code Context.)

### Claude's Discretion

- Exact SegmentedButton vs ToggleButtons vs two-chip approach for direction selector
- Time picker implementation (showTimePicker with MaterialTimePickerTheme)
- Date picker implementation (showDatePicker with reasonable past-only constraint)
- Exact bottom sheet height and drag handle styling
- SnackBar copy
- File/folder layout within `lib/features/trips/` and backfill service location
- Whether backfill runs via a dedicated Riverpod provider or as a side-effect in the app's init flow

### Deferred Ideas (OUT OF SCOPE)

- Trip list / daily log — Phase 4 (HIST-01)
- Trip detail with route map — Phase 4 (HIST-03)
- Undo delete — not in scope for Phase 3
- Evening cutoff (`evening_cutoff_hour`) settings UI — Phase 7
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRACK-03 | Trip direction auto-labeled (morning = to_office, evening = to_home) with editable override | D-03/D-04: `UserPreferencesDao.getOrDefault()` provides cutoff; direction label service applies rule; bottom sheet provides override. D-05/D-06 cover backfill and new-trip labeling. |
| TRACK-06 | User can edit trip details (direction label, adjust times) | D-01/D-02: modal bottom sheet with SegmentedButton + showTimePicker. D-12: `TripsDao.updateTrip`. D-13: `enqueueUpdate`. |
| TRACK-07 | User can delete a trip with confirmation dialog | D-07/D-08: AlertDialog + transaction wrapping `deleteTrip` + `enqueueDelete`. |
| TRACK-08 | User can manually enter a forgotten trip (date, duration, direction — no GPS data) | D-09/D-10/D-11: FAB → manual entry sheet with date picker, HH:MM field, direction toggle. |
</phase_requirements>

---

## Summary

Phase 3 adds the full trip management surface on top of the Phase 2 tracking core. The primary new capabilities are: (1) editing a trip's direction and times via a modal bottom sheet, (2) deleting a trip with a confirmation dialog, (3) manually entering a forgotten trip via a FAB-triggered sheet, and (4) auto-labeling trips by direction at save time and backfilling all `kDirectionUnknown` rows from Phase 2. None of these require new routes; all editing uses `showModalBottomSheet` directly.

The code foundations are solid. The Drift schema, constants, and DAO patterns from Phases 1–2 are exactly what Phase 3 needs. `SyncQueueDao.enqueueUpdate` and `enqueueDelete` already exist in the codebase (Phase 1 shipped them per the schema spec) — `TripsDao.updateTrip` and `deleteTrip` are the only genuinely new DAO methods. The backfill is a one-shot async task that reads `UserPreferencesDao.getOrDefault()`, queries for `kDirectionUnknown` rows, and batch-updates them in a single Drift transaction.

The critical integration point is `TrackingServiceController.persistFinalizedTrip`: this is where D-06's "label at save time" requires a one-line change — replace the hardcoded `direction: kDirectionUnknown` with a call to a `DirectionLabelService.label(startTime)` helper. The helper reads preferences from the DAO and applies the cutoff rule. Keeping the helper a plain Dart class (not a Riverpod provider) makes it synchronously testable and avoids async complexity inside the Drift transaction.

**Primary recommendation:** Build the `DirectionLabelService` as a stateless utility class first, test it in isolation, then wire it into the existing `persistFinalizedTrip` transaction and the new backfill provider.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Trip edit bottom sheet (direction, times) | Flutter UI | Drift (via DAO) | Widget owns form state; DAO owns persistence. No server call. |
| Direction auto-labeling | App logic (service class) | Drift (user prefs read) | Pure computation; reads one preference; writes trip column. |
| `kDirectionUnknown` backfill | App init (Riverpod provider or init hook) | Drift (batch update transaction) | Runs once on startup; must not block UI render. |
| Delete confirmation dialog | Flutter UI | Drift (via transaction) | AlertDialog is pure UI; DAO transaction is persistence. |
| Manual trip entry sheet | Flutter UI | Drift (via DAO) | Form validation in widget; persistence via `insertTrip` with `isManualEntry = true`. |
| Sync queue enqueue | Drift (SyncQueueDao) | — | All enqueue calls piggyback on existing transaction pattern; no network in Phase 3. |

---

## Standard Stack

### Core (all already in pubspec.yaml — no new packages needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| drift | ^2.32.1 | `updateTrip`, `deleteTrip`, batch backfill | Already the project's data layer [VERIFIED: pubspec.yaml] |
| flutter_riverpod | ^3.3.1 | State for edit/delete/manual notifiers, backfill trigger | Established state management for this project [VERIFIED: pubspec.yaml] |
| intl | ^0.20.2 | Format `DateTime` for display in pickers and cards | Already in pubspec.yaml [VERIFIED: pubspec.yaml] |
| flutter (Material) | bundled with Flutter 3.41.6 | `showModalBottomSheet`, `showTimePicker`, `showDatePicker`, `AlertDialog`, `SegmentedButton`, `FloatingActionButton`, `SnackBar` | Standard Material 3 widgets, no additional package needed [VERIFIED: Flutter 3.41.6 installed] |

**No new packages required.** Phase 3 is entirely served by dependencies already present in the project.

### Supporting (already present)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| uuid | ^4.5.3 | Generate UUID for manual trip `id` | Every `insertTrip` call for a manual entry needs a client-side v4 UUID |
| very_good_analysis | ^10.2.0 | Lint enforcement | `dart format` + `flutter analyze` must pass after every file |

---

## Architecture Patterns

### System Architecture Diagram

```
User taps [+] FAB / Edit on trip card
        |
        v
ManualEntrySheet / EditTripSheet   (lib/features/trips/widgets/)
  - Form state: TripFormNotifier   (lib/features/trips/providers/)
  - Validate (HH:MM, time ordering)
  - On Save ─────────────────────────────────────────────────────┐
                                                                 |
User taps Delete on trip card                                    |
        |                                                        |
        v                                                        |
AlertDialog "Delete trip?"                                       |
  - On confirm ──────────────────────────────────────────────┐  |
                                                             |  |
                                           TripManagementNotifier (trips/providers/)
                                             ref.read(appDatabaseProvider)
                                                    |
                                          appDatabase.transaction()
                                         /                    \
                              TripsDao                   SyncQueueDao
                           updateTrip()                 enqueueUpdate()
                           deleteTrip()                 enqueueDelete()
                           insertTrip()                 enqueueCreate()
                                         \                    /
                                          Drift → SQLite (trips, sync_queue)
                                                    |
                              TripsDao.watchAllSummaries() reactive stream
                                                    |
                                         UI rebuilds automatically


App startup (ProviderScope init)
        |
        v
DirectionBackfillProvider     (lib/features/trips/providers/)
  reads UserPreferencesDao.getOrDefault()
  queries: SELECT * FROM trips WHERE direction = 'unknown'
  for each: applies DirectionLabelService.label(startTime.toLocal())
  writes: appDatabase.transaction() → batch TripsDao.updateTrip + SyncQueueDao.enqueueUpdate


New trip saved (Phase 2 tracking finalization — modified)
        |
        v
TrackingServiceController.persistFinalizedTrip()   (existing file, Phase 2)
  DirectionLabelService.label(trip.startTime.toLocal())   ← Phase 3 change
  TripsDao.insertTrip(... direction: labeledDirection ...)
  SyncQueueDao.enqueueCreate(trip.id)
```

### Recommended Project Structure

```
lib/
├── features/
│   ├── trips/                          # NEW in Phase 3
│   │   ├── providers/
│   │   │   └── trip_management_providers.dart   # edit/delete/manual notifiers
│   │   ├── services/
│   │   │   └── direction_label_service.dart     # pure label(DateTime) → String
│   │   └── widgets/
│   │       ├── edit_trip_sheet.dart             # bottom sheet for edit
│   │       └── manual_entry_sheet.dart          # bottom sheet for manual entry
│   └── tracking/
│       ├── providers/
│       │   ├── backfill_provider.dart           # one-shot backfill on app init
│       │   └── tracking_providers.dart          # MODIFIED: wire DirectionLabelService
│       ├── screens/
│       │   └── home_screen.dart                 # MODIFIED: add FAB, delete/edit triggers
│       └── services/
│           └── tracking_service_controller.dart # MODIFIED: direction at save time
├── database/
│   └── daos/
│       ├── trips_dao.dart     # MODIFIED: add updateTrip, deleteTrip
│       └── sync_queue_dao.dart  # already has enqueueUpdate, enqueueDelete
└── config/
    └── constants.dart         # no changes needed
```

**Note on `sync_queue_dao.dart`:** `enqueueUpdate(String tripId)` and `enqueueDelete({required String tripId, required String payload})` already exist in the codebase [VERIFIED: lib/database/daos/sync_queue_dao.dart]. D-13 is already implemented. Only `TripsDao.updateTrip` and `TripsDao.deleteTrip` are missing.

### Pattern 1: Drift Partial Update via Companion

**What:** Update only specific columns of a row by passing a `TripsCompanion` with `Value.absent()` for unchanged fields.
**When to use:** Edit trip — only direction, startTime, endTime, durationSeconds, updatedAt change.

```dart
// Source: https://drift.simonbinder.eu/dart_api/writes
Future<void> updateTrip(TripsCompanion companion) {
  return (update(trips)
    ..where((t) => t.id.equals(companion.id.value)))
    .write(companion);
}
```

Caller constructs the companion with only the fields that changed:

```dart
// Source: established project pattern (trips_dao.dart, tracking_service_controller.dart)
await tripsDao.updateTrip(
  TripsCompanion(
    id: Value(tripId),
    direction: Value(newDirection),
    startTime: Value(newStart),
    endTime: Value(newEnd),
    durationSeconds: Value(newEnd.difference(newStart).inSeconds),
    updatedAt: Value(DateTime.now().toUtc()),
  ),
);
```

### Pattern 2: Drift Delete by Primary Key

**What:** Delete a single row by its UUID.
**When to use:** User confirms delete dialog.

```dart
// Source: https://drift.simonbinder.eu/dart_api/writes
Future<void> deleteTrip(String id) {
  return (delete(trips)..where((t) => t.id.equals(id))).go();
}
```

### Pattern 3: Atomic Delete + Sync Enqueue Transaction

**What:** Delete a trip and enqueue the tombstone in a single Drift transaction — matching the Phase 2 pattern in `persistFinalizedTrip`.
**When to use:** Every trip delete.

```dart
// Source: established project pattern (tracking_service_controller.dart Phase 2)
// Source: https://drift.simonbinder.eu/dart_api/transactions
await appDatabase.transaction(() async {
  // Build payload BEFORE deleting — the row must still exist at this point.
  final payload = jsonEncode({'id': tripId, 'userId': kDefaultUserId});
  await tripsDao.deleteTrip(tripId);
  await syncQueueDao.enqueueDelete(tripId: tripId, payload: payload);
});
```

### Pattern 4: showModalBottomSheet with isScrollControlled

**What:** Present the edit/manual-entry sheet as a modal that can grow beyond half-screen and respects keyboard insets.
**When to use:** All trip editing in Phase 3.

```dart
// Source: Flutter Material docs (docs.flutter.dev/ui/widgets/material — Bottom sheet)
await showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,       // allows full-height sheets
  useSafeArea: true,              // avoids notch / home indicator
  builder: (sheetContext) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: const EditTripSheet(tripId: tripId),
    );
  },
);
```

`isScrollControlled: true` is required when the sheet contains a text field (manual entry HH:MM) so the keyboard does not cover it. [VERIFIED: Flutter 3.41.6 Material docs]

### Pattern 5: SegmentedButton for Direction Toggle

**What:** Two-segment button for "To office" / "To home" selection. Material 3 replacement for `ToggleButtons`.
**When to use:** Both the edit sheet and the manual entry sheet for direction selection.

```dart
// Source: https://docs.flutter.dev/release/breaking-changes/material-3-migration
enum TripDirection { toOffice, toHome }

SegmentedButton<TripDirection>(
  segments: const <ButtonSegment<TripDirection>>[
    ButtonSegment(value: TripDirection.toOffice, label: Text('To office')),
    ButtonSegment(value: TripDirection.toHome, label: Text('To home')),
  ],
  selected: <TripDirection>{_direction},
  onSelectionChanged: (Set<TripDirection> newSelection) {
    setState(() => _direction = newSelection.first);
  },
  multiSelectionEnabled: false,
);
```

`SegmentedButton` is the Material 3 standard [VERIFIED: flutter.dev migration guide]; `ToggleButtons` is the deprecated predecessor.

### Pattern 6: showTimePicker

**What:** System time picker for start/end time editing.
**When to use:** Edit sheet time adjustment.

```dart
// Source: Flutter Material API (docs.flutter.dev/ui/widgets/material — TimePicker)
final TimeOfDay? picked = await showTimePicker(
  context: context,
  initialTime: TimeOfDay.fromDateTime(currentTime.toLocal()),
);
if (picked != null) {
  // combine with existing date to get new DateTime
  final updated = DateTime(
    currentTime.toLocal().year,
    currentTime.toLocal().month,
    currentTime.toLocal().day,
    picked.hour,
    picked.minute,
  ).toUtc();
}
```

### Pattern 7: showDatePicker with Past-Only Constraint

**What:** Calendar date picker for the manual entry sheet, restricted to today or earlier.
**When to use:** Manual trip date selection.

```dart
// Source: Flutter Material API (docs.flutter.dev/ui/widgets/material — DatePicker)
final DateTime? picked = await showDatePicker(
  context: context,
  initialDate: DateTime.now(),
  firstDate: DateTime(2020),      // reasonable lower bound
  lastDate: DateTime.now(),       // cannot enter future trips
);
```

### Pattern 8: DirectionLabelService — Pure Utility Class

**What:** Stateless helper that applies the cutoff rule. Takes `DateTime` (already in local time) and `int morningCutoffHour`, returns a direction string constant.
**When to use:** At trip save time (injected into `persistFinalizedTrip`), at backfill time, and in manual entry.

```dart
// Source: established project pattern + D-03/D-04 decisions
// lib/features/trips/services/direction_label_service.dart
import 'package:traevy/config/constants.dart';

/// Stateless direction-labeling utility.
///
/// Takes [startTimeLocal] already converted to device-local time and
/// [morningCutoffHour] from [UserPreferencesValue.morningCutoffHour].
/// Returns [kDirectionToOffice] or [kDirectionToHome].
class DirectionLabelService {
  const DirectionLabelService();

  /// Apply the morning-cutoff rule (D-04).
  ///
  /// `startTimeLocal.hour < morningCutoffHour` → to_office
  /// `startTimeLocal.hour >= morningCutoffHour` → to_home
  String label(DateTime startTimeLocal, int morningCutoffHour) {
    return startTimeLocal.hour < morningCutoffHour
        ? kDirectionToOffice
        : kDirectionToHome;
  }
}
```

This is a plain Dart class — no `Provider`, no `async`. It can be constructed inline wherever needed. [ASSUMED: keeping it as a plain class (not a Provider) is the simplest approach; alternative would be a Provider wrapping the async `getOrDefault` call, but that adds complexity for a pure computation]

### Pattern 9: One-Shot Backfill Provider

**What:** A Riverpod `FutureProvider` or `AsyncNotifier` that runs exactly once after the app starts. Queries `kDirectionUnknown` trips, applies the label, batch-updates.
**When to use:** App startup — `ProviderScope` consumer reads it so it fires.

```dart
// Source: established project Riverpod pattern (tracking_providers.dart)
// lib/features/tracking/providers/backfill_provider.dart
final FutureProvider<void> directionBackfillProvider = FutureProvider<void>(
  (ref) async {
    final db = ref.read(appDatabaseProvider);
    final prefsDao = ref.read(userPreferencesDaoProvider);
    final tripsDao = ref.read(tripsDaoProvider);
    final syncDao = ref.read(syncQueueDaoProvider);

    final prefs = await prefsDao.getOrDefault();
    final unknownTrips = await (select(db.trips)
          ..where((t) => t.direction.equals(kDirectionUnknown)))
        .get();

    if (unknownTrips.isEmpty) return;

    const labeler = DirectionLabelService();
    await db.transaction(() async {
      for (final trip in unknownTrips) {
        final direction = labeler.label(
          trip.startTime.toLocal(),
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

**Backfill wiring:** The provider must be eagerly consumed on app startup. The lightest approach is to add `ref.watch(directionBackfillProvider)` inside a `ConsumerWidget` that wraps the `HomeScreen` (or in the existing `TraevyApp.build`), or add a `ProviderObserver`. [ASSUMED: consumer widget approach is simplest for this project; alternative is `container.read(directionBackfillProvider)` in `main()`]

### Pattern 10: TripManagementNotifier — Sealed State

**What:** Notifier for the edit and delete flows. Uses a sealed class matching the established `TrackingState` pattern.
**When to use:** Bottom sheet "Save" and delete dialog "Delete" actions.

```dart
// Source: established project pattern (tracking_state.dart, CLAUDE.md "sealed classes for finite state")
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

### Anti-Patterns to Avoid

- **Setting `direction: kDirectionUnknown` in new trips after Phase 3:** Phase 3 modifies `persistFinalizedTrip` to call `DirectionLabelService.label(...)`. The `kDirectionUnknown` constant remains in `constants.dart` for the backfill query, but no new row should ever land with it after Phase 3.
- **Blocking the UI on backfill:** The backfill `FutureProvider` must be consumed asynchronously. Never `await` it before `runApp` or before the first frame is rendered.
- **Running backfill in a transaction-per-row loop outside a single transaction:** All backfill updates must be inside a single `appDatabase.transaction()` for atomicity. Individual per-row transactions are slow and leave the database in a partial state on crash.
- **Reading the full `TripRow` (including `routePolyline`) for list or aggregate operations:** Use `TripSummary` projections. The `findById` method exists for the single-row detail use case only.
- **Using `setState` in bottom sheet widgets:** All state flows through `Riverpod` per CLAUDE.md. The sheet's form state belongs in a `Notifier`.
- **Hardcoding `'unknown'` as a string literal** when `kDirectionUnknown` already exists in `constants.dart`.
- **Updating `updatedAt` inside the Drift table trigger rather than in the DAO companion:** The table comment in `trips_table.dart` already documents this: "Currently updated manually by the DAO on every write." Pass `Value(DateTime.now().toUtc())` in every `TripsCompanion` for writes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Time picker | Custom clock widget | `showTimePicker` (Material) | Platform-native, accessibility-compliant, locale-aware |
| Date picker | Custom calendar | `showDatePicker` (Material) | Same — plus `lastDate: DateTime.now()` for past-only constraint |
| Direction toggle | Custom two-button row | `SegmentedButton<TripDirection>` | Material 3 standard, handles accessibility, selection state, theming automatically |
| Confirmation dialog | Custom overlay widget | `AlertDialog` via `showDialog` | Already used in home screen permission dialogs — consistent pattern |
| HH:MM parsing | Regex parser | `Duration` + `int.tryParse` split on `:` | Not worth a library; logic is 3 lines with clear unit tests |
| UUID for manual entries | Timestamp-based ID | `uuid` package v4 (already in pubspec) | Collision-free, already used for all other trips |

**Key insight:** Phase 3's entire UI surface is standard Material 3 widgets already bundled with Flutter 3.41.6. No new packages are needed.

---

## Common Pitfalls

### Pitfall 1: `context.mounted` Check After `await` in Bottom Sheet
**What goes wrong:** A bottom sheet is dismissed by the user while an async save is in flight. The save completes, and the code tries to `Navigator.pop(context)` or `ScaffoldMessenger.of(context).showSnackBar(...)` on a `BuildContext` that belongs to a dead widget — throws `FlutterError` in debug, silently no-ops in release.
**Why it happens:** `await tripsDao.updateTrip(...)` suspends the async function; the widget can be disposed in that window.
**How to avoid:** Always check `context.mounted` after every `await` in a widget method. This is already the established pattern in `HomeScreen._handleStart`.
**Warning signs:** The existing home screen already checks `if (!context.mounted) return;` after its `await` calls — follow this pattern exactly.

### Pitfall 2: Local Time vs UTC in Direction Labeling
**What goes wrong:** `trip.startTime` is stored in UTC (CLAUDE.md schema and all Phase 2 inserts use `.toUtc()`). Applying the cutoff rule to `startTime.hour` without converting to local time misclassifies commutes that cross midnight UTC (common for commuters in UTC+5:30, UTC+8, etc.).
**Why it happens:** The CONTEXT.md D-04 rule explicitly says "Uses local time" but `DateTime` from Drift comes out as UTC.
**How to avoid:** `DirectionLabelService.label` must receive `startTime.toLocal()`, not the raw UTC `startTime`. This conversion must happen at every call site (backfill, `persistFinalizedTrip`, manual entry).
**Warning signs:** Unit tests for `DirectionLabelService` should include a UTC-offset test case (e.g., midnight UTC = 5:30 AM IST should label as `to_office` for `morningCutoffHour = 12`).

### Pitfall 3: `enqueueDelete` Payload Built After `deleteTrip`
**What goes wrong:** The JSON payload for the delete sync entry needs `{id, user_id}` from the trip row. If `deleteTrip` runs first, the row is gone and the payload cannot be built from the database.
**Why it happens:** D-08 says the operations must be in a single transaction. It does not specify order — developers might naturally put the delete first.
**How to avoid:** Inside `appDatabase.transaction()`, build the payload JSON first (using the already-known `tripId` and `kDefaultUserId`), then call `deleteTrip`, then `enqueueDelete`. No read is required — both fields are known at call time.
**Warning signs:** If you see a `getSingleOrNull` call to fetch the trip inside the delete transaction, the order is likely wrong.

### Pitfall 4: `TripsCompanion` Without `id` Value in `updateTrip`
**What goes wrong:** `update(trips)..where(...)` combined with `.write(companion)` ignores the `id` field in the companion (it is not used as the `WHERE` clause — `where` is set separately). If the developer accidentally omits the `.where(...)` clause, every trip gets updated.
**Why it happens:** Drift's `update().replace(row)` auto-sets the WHERE from the primary key; `update().write(companion)` does not.
**How to avoid:** `updateTrip(TripsCompanion companion)` in the DAO must always use `..where((t) => t.id.equals(companion.id.value))`. Unit tests should assert that `updateTrip` only mutates the targeted row when multiple rows exist.
**Warning signs:** Tests should insert two trips and verify only one changes after calling `updateTrip`.

### Pitfall 5: Backfill Fires More Than Once
**What goes wrong:** `FutureProvider` with `keepAlive: false` (auto-dispose) can re-fire if its listeners all leave the tree and re-subscribe. For a backfill this is not catastrophic (re-labeling already-labeled rows with the correct label is idempotent), but it adds unnecessary DB writes and sync-queue entries.
**Why it happens:** `Provider(...)` in Riverpod 3.x is `keepAlive: true` by default — but `FutureProvider` with autoDispose semantics might be constructed if the developer uses `.autoDispose` modifier.
**How to avoid:** Use `FutureProvider<void>(...)` without autoDispose. This matches the `keepAlive: true` pattern established for all providers in this project. Document in the provider comment that it must stay alive.
**Warning signs:** If `isAutoDispose` is `true` in the generated provider, the backfill can run on every widget rebuild cycle.

### Pitfall 6: Manual Entry `startTime` Midnight Boundary
**What goes wrong:** D-10 says "Start time is set to midnight of the chosen date." If the developer uses `DateTime.now()` and zeroes the time components, the result is in local time. All other trip `startTime` values are UTC. Storing this as UTC midnight in a different timezone produces a `startTime` that is hours off from the user's intended date.
**Why it happens:** The `DateTime` date picker returns a local date; converting midnight local to UTC shifts it.
**How to avoid:** Build the local-midnight `DateTime` first, then convert to UTC: `DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 0, 0, 0).toUtc()`. The direction labeler then receives `startTime.toLocal()` which correctly reconstructs the local hour = 0.
**Warning signs:** Unit tests for manual entry should assert `startTime.isUtc == true` and verify that the local hour of `startTime.toLocal()` is 0.

---

## Code Examples

### Drift: `updateTrip` in `TripsDao`

```dart
// Source: https://drift.simonbinder.eu/dart_api/writes
// Follows existing DAO pattern (trips_dao.dart)
Future<void> updateTrip(TripsCompanion companion) {
  return (update(trips)
    ..where((t) => t.id.equals(companion.id.value)))
    .write(companion);
}
```

### Drift: `deleteTrip` in `TripsDao`

```dart
// Source: https://drift.simonbinder.eu/dart_api/writes
Future<void> deleteTrip(String id) {
  return (delete(trips)..where((t) => t.id.equals(id))).go();
}
```

### Atomic Delete + Enqueue Transaction

```dart
// Source: established project pattern (tracking_service_controller.dart)
// Source: https://drift.simonbinder.eu/dart_api/transactions
import 'dart:convert';
import 'package:traevy/config/constants.dart';

await appDatabase.transaction(() async {
  final payload = jsonEncode(<String, String>{
    'id': tripId,
    'userId': kDefaultUserId,
  });
  await tripsDao.deleteTrip(tripId);
  await syncQueueDao.enqueueDelete(tripId: tripId, payload: payload);
});
```

### Atomic Update + Enqueue Transaction

```dart
// Source: established project pattern (tracking_service_controller.dart)
await appDatabase.transaction(() async {
  await tripsDao.updateTrip(
    TripsCompanion(
      id: Value(tripId),
      direction: Value(newDirection),
      startTime: Value(newStartUtc),
      endTime: Value(newEndUtc),
      durationSeconds: Value(newEndUtc.difference(newStartUtc).inSeconds),
      updatedAt: Value(DateTime.now().toUtc()),
    ),
  );
  await syncQueueDao.enqueueUpdate(tripId);
});
```

### showModalBottomSheet for Edit/Manual Entry

```dart
// Source: Flutter Material docs (docs.flutter.dev/ui/widgets/material — Bottom sheet)
await showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
    ),
    child: const EditTripSheet(tripId: tripId),
  ),
);
```

### Delete Confirmation AlertDialog

```dart
// Source: Flutter Material docs + established project pattern (home_screen.dart)
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
if (confirmed ?? false) {
  // proceed with delete
}
```

### HH:MM Duration Parsing

```dart
// Source: [ASSUMED] plain Dart — no library needed
Duration? parseHhMm(String input) {
  final parts = input.trim().split(':');
  if (parts.length != 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return Duration(hours: hours, minutes: minutes);
}
```

---

## Code Context: What Already Exists

### `SyncQueueDao` — Already Has Both New Methods

CONTEXT.md D-13 says "Phase 3 adds `enqueueUpdate` and `enqueueDelete`." However, inspecting the actual codebase reveals both methods already exist [VERIFIED: lib/database/daos/sync_queue_dao.dart]:

```dart
Future<int> enqueueUpdate(String tripId) { ... }        // line ~52
Future<int> enqueueDelete({required String tripId, required String payload}) { ... }  // line ~65
```

D-13 is already satisfied. The planner must NOT re-implement these methods.

### `TripsDao` — The Two Missing Methods

`updateTrip` and `deleteTrip` do NOT yet exist [VERIFIED: lib/database/daos/trips_dao.dart]. The DAO doc comment explicitly defers them to Phase 3: "Update/delete methods arrive in Phase 3 when trip editing lands."

### `TrackingServiceController.persistFinalizedTrip` — Uses `kDirectionUnknown`

The existing code at line ~67 of `tracking_service_controller.dart` passes `direction: kDirectionUnknown` [VERIFIED]. Phase 3 D-06 requires this to be replaced with `DirectionLabelService.label(trip.startTime.toLocal(), prefs.morningCutoffHour)`. This requires the controller to read preferences — either injecting the `UserPreferencesDao` into the controller or calling `getOrDefault()` inside `persistFinalizedTrip`. Injecting the DAO into the controller at construction time is the cleanest approach (matches the existing `_tripsDao`, `_syncQueueDao` injection pattern).

### Home Screen — No FAB Yet

The current `HomeScreen` `build` method has no `floatingActionButton` property on its `Scaffold` [VERIFIED: lib/features/tracking/screens/home_screen.dart]. Phase 3 adds a standard `FloatingActionButton` with `Icons.add`.

### Existing Test Baseline

93 tests pass as of research date [VERIFIED: `flutter test` run]. Phase 3 must not regress this.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ToggleButtons` for multi-select | `SegmentedButton<T>` | Flutter 3.0 (Material 3) | Use `SegmentedButton` — `ToggleButtons` still works but is the pre-M3 API |
| `showBottomSheet` (persistent) | `showModalBottomSheet` (modal) | Stable for years | Use `showModalBottomSheet` for trip editing — blocks interaction with the rest of the screen, which is the correct behavior for a form |
| Manual `isAutoDispose: false` in Riverpod 2.x | Default `Provider(...)` is keepAlive in Riverpod 3.x | Riverpod 3.x | No explicit `keepAlive` annotation needed in manual providers |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `DirectionLabelService` as a plain Dart class (not a Provider) is the simplest wiring approach | Architecture Patterns, Pattern 8 | Low — alternative (Provider wrapper) is slightly more testable but adds complexity; either works |
| A2 | Backfill wired as a `FutureProvider` consumed in `TraevyApp.build` or a wrapper widget is the lightest approach | Architecture Patterns, Pattern 9 | Low — `main()` eager-read is a valid alternative |
| A3 | `parseHhMm` implemented as 3–4 lines of Dart (no package) | Code Examples | Very low — the logic is trivially correct and unit-testable |

---

## Open Questions

1. **FAB on home screen vs. trips screen wrapper**
   - What we know: D-09 says the FAB is on the home screen. D-02 says no new named routes.
   - What's unclear: Phase 4 will add a trip list screen. Should the FAB move there? The CONTEXT says Phase 3 puts it on the home screen.
   - Recommendation: Put it on the current `HomeScreen` as specified. Phase 4 can move it if needed.

2. **`TrackingServiceController` dependency on `UserPreferencesDao`**
   - What we know: The controller is constructed in `trackingServiceControllerProvider` with 5 injected dependencies.
   - What's unclear: Adding a 6th dependency (`UserPreferencesDao`) could be done at construction time or via a one-off `ref.read` inside `persistFinalizedTrip`.
   - Recommendation: Inject `UserPreferencesDao` at construction time — consistent with the existing pattern and keeps the method testable without Riverpod.

---

## Environment Availability

Step 2.6: Dependency audit — Phase 3 uses no external tools beyond existing Flutter/Dart toolchain.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter | All | ✓ | 3.41.6 | — |
| Dart | All | ✓ | 3.11.4 | — |
| `flutter test` | Test suite | ✓ | bundled | — |
| `dart run build_runner build` | Drift code gen | ✓ | ^2.13.1 | — |

No new external dependencies. No missing dependencies with no fallback.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter 3.41.6) |
| Config file | None — standard `flutter test` discovery |
| Quick run command | `flutter test test/unit/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRACK-03 | `DirectionLabelService.label` applies cutoff rule correctly | unit | `flutter test test/unit/features/trips/direction_label_service_test.dart` | ❌ Wave 0 |
| TRACK-03 | Backfill updates `kDirectionUnknown` rows and leaves already-labeled rows unchanged | unit | `flutter test test/unit/features/trips/direction_backfill_test.dart` | ❌ Wave 0 |
| TRACK-03 | `persistFinalizedTrip` no longer saves `kDirectionUnknown` | unit | `flutter test test/unit/features/tracking/persist_finalized_trip_test.dart` | ✅ (extend) |
| TRACK-06 | `TripsDao.updateTrip` only mutates targeted row | unit | `flutter test test/unit/database/trips_dao_test.dart` | ✅ (extend) |
| TRACK-06 | Edit transaction: updateTrip + enqueueUpdate are atomic | unit | `flutter test test/unit/features/trips/trip_management_notifier_test.dart` | ❌ Wave 0 |
| TRACK-07 | `TripsDao.deleteTrip` removes only targeted row | unit | `flutter test test/unit/database/trips_dao_test.dart` | ✅ (extend) |
| TRACK-07 | Delete transaction: deleteTrip + enqueueDelete are atomic | unit | `flutter test test/unit/features/trips/trip_management_notifier_test.dart` | ❌ Wave 0 |
| TRACK-08 | Manual trip insert: `isManualEntry = true`, `distanceMeters = 0.0`, `routePolyline = null` | unit | `flutter test test/unit/database/trips_dao_test.dart` | ✅ (extend) |
| TRACK-08 | `parseHhMm` validates 0:00–23:59 and rejects malformed input | unit | `flutter test test/unit/features/trips/parse_hh_mm_test.dart` | ❌ Wave 0 |
| TRACK-06/07/08 | Edit, delete, and manual entry sheets render correctly | widget | `flutter test test/widget/features/trips/` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/unit/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green (currently 93 tests) before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/unit/features/trips/direction_label_service_test.dart` — covers TRACK-03 label logic
- [ ] `test/unit/features/trips/direction_backfill_test.dart` — covers TRACK-03 backfill
- [ ] `test/unit/features/trips/trip_management_notifier_test.dart` — covers TRACK-06/07 transaction atomicity
- [ ] `test/unit/features/trips/parse_hh_mm_test.dart` — covers TRACK-08 input validation
- [ ] `test/widget/features/trips/edit_trip_sheet_test.dart` — covers TRACK-06 UI
- [ ] `test/widget/features/trips/manual_entry_sheet_test.dart` — covers TRACK-08 UI

Existing files to extend:
- `test/unit/database/trips_dao_test.dart` — add `updateTrip` / `deleteTrip` / manual insert cases
- `test/unit/features/tracking/persist_finalized_trip_test.dart` — assert direction is no longer `kDirectionUnknown`

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Not in scope for Phase 3 |
| V3 Session Management | no | Not in scope for Phase 3 |
| V4 Access Control | no | All data is local-user-only in Phase 3 |
| V5 Input Validation | yes | HH:MM field: `parseHhMm` validates range; date picker: `lastDate = DateTime.now()` prevents future dates; direction: enum-constrained `SegmentedButton` |
| V6 Cryptography | no | No crypto in Phase 3 |

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Invalid HH:MM input (overflow) | Tampering | `parseHhMm` validates 0 ≤ hours ≤ 23, 0 ≤ minutes ≤ 59 before allowing save |
| Future trip date injection | Tampering | `showDatePicker(lastDate: DateTime.now())` — platform picker enforces bound |
| Direction value outside known set | Tampering | `SegmentedButton<TripDirection>` enum — cannot produce an arbitrary string; mapping to `kDirectionToOffice` / `kDirectionToHome` constants at save time |
| Orphaned sync_queue entry on delete | Elevation of privilege | Atomic transaction (D-08) prevents delete without enqueue; rollback on failure leaves both tables consistent |

---

## Sources

### Primary (HIGH confidence)
- `/websites/drift_simonbinder_eu` (Context7) — update, delete, transaction, companion patterns
- `/websites/flutter_dev` (Context7) — showModalBottomSheet, SegmentedButton, showTimePicker, showDatePicker, AlertDialog
- `lib/database/daos/trips_dao.dart` — verified existing DAO surface [VERIFIED: file read]
- `lib/database/daos/sync_queue_dao.dart` — verified enqueueUpdate/enqueueDelete already exist [VERIFIED: file read]
- `lib/features/tracking/services/tracking_service_controller.dart` — verified `direction: kDirectionUnknown` pattern [VERIFIED: file read]
- `lib/features/tracking/screens/home_screen.dart` — verified no FAB exists [VERIFIED: file read]
- `pubspec.yaml` — verified exact package versions [VERIFIED: file read]
- `flutter --version` — Flutter 3.41.6, Dart 3.11.4 [VERIFIED: shell]
- `flutter test` — 93 tests passing baseline [VERIFIED: shell]

### Secondary (MEDIUM confidence)
- `lib/config/constants.dart` — all relevant direction / sync constants confirmed present
- `.planning/phases/03-trip-management/03-CONTEXT.md` — decisions D-01 through D-13 cross-checked against codebase

### Tertiary (LOW confidence)
- None — all research findings are verified against official docs or the codebase directly.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already in pubspec.yaml, versions verified
- Architecture: HIGH — existing patterns (sealed state, manual Riverpod providers, Drift transactions) are verified in codebase
- Pitfalls: HIGH — UTC/local time pitfall is verified against schema; other pitfalls are confirmed by reading the actual code
- Test mapping: HIGH — existing test files verified, gaps identified from directory listing

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (stable stack — Flutter 3.41.6 and Drift 2.32.1 are locked in pubspec.yaml)
