# Phase 1: Foundation - Research

**Researched:** 2026-04-12
**Domain:** Flutter project scaffold + Drift 2.32 database + Riverpod 3.x state setup
**Confidence:** HIGH

## Summary

Phase 1 establishes a runnable Flutter project named **Traevy** (`traevy.traevy`) with a complete Drift database schema (trips, sync_queue, user_preferences), DAOs, config constants, Riverpod 3.x provider scaffolding, and build_runner code generation. It is the foundation everything else builds on — no UI features, no GPS, no auth.

The research surfaced **three stack deltas from STACK.md** that must be honored by the planner:

1. **Drift has moved from 2.22 to 2.32.1** (March 2026). The Flutter setup story has changed: `sqlite3_flutter_libs` is now **end-of-life** (0.6.0+eol, Feb 2026). The current blessed approach is the `drift_flutter` package which wraps `path_provider` + `sqlite3` + platform channels into a single `driftDatabase(name: 'app_db')` call.
2. **Riverpod has shipped 3.0** (Sept 2025) and is now at 3.3.1 (March 2026). This is a **breaking major version** from the `^2.6` reference in STACK.md. `StateProvider`/`StateNotifierProvider` moved to `legacy.dart`, `AsyncValue.value` semantics changed, and `StreamProvider` now pauses when no listeners are attached. The `@riverpod` annotation pattern remains the recommended path forward.
3. **very_good_analysis is at 10.2.0** (Feb 2026), significantly newer than STACK.md's implicit `^6.x`. The include line is `package:very_good_analysis/analysis_options.yaml`.

**Primary recommendation:** Use `drift ^2.32.1` + `drift_flutter ^0.3.0` + `flutter_riverpod ^3.3.1` + `riverpod_annotation ^4.0.2` + `very_good_analysis ^10.2.0`. Scaffold with `flutter create --org traevy --project-name traevy .` inside the repo root. Start schemaVersion at 1 with an explicit `MigrationStrategy` and generate migration-test scaffolding via `dart run drift_dev schema dump` + `schema generate` even though there are no migrations yet — that gives future phases a working harness.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Schema Design**
- **D-01:** Polylines stored in the trips table (same table, not separate). Load selectively on detail screens to avoid list query bloat.
- **D-02:** `user_id` column uses default placeholder value `'local_user'` instead of null. Phase 8 replaces with Cognito sub via UPDATE.
- **D-03:** Indexes on `start_time` and `direction` columns for daily log and stats query performance. Claude decides exact index composition.
- **D-04:** `user_preferences` is created on demand (no seeded row). Code must handle missing row with defaults.

**Project Scaffold**
- **D-05:** App name is "Traevy" with package identifier `traevy.traevy`.
- **D-06:** Feature directories created phase-by-phase, not all upfront. **Phase 1 creates only `database/`, `config/`, and `shared/` directories.** No `features/`, `sync/`, or `notifications/` subtrees.
- **D-07:** Only core packages in Phase 1: Drift, Riverpod, build_runner, uuid, intl. GPS, charts, notifications, http, connectivity_plus, secure_storage, google_sign_in all added in their respective later phases.
- **D-08:** Target latest Android API level. Set `minSdkVersion` to latest stable (API 34/Android 14).

**Migration Strategy**
- **D-09:** Drift schema starts at schemaVersion 1. Every future schema change increments version with an explicit migration step.
- **D-10:** Migration test scaffolding created in Phase 1 — test infrastructure ready to verify migrations work when schema changes happen.

**Dev Workflow**
- **D-11:** Use `very_good_analysis` for strict linting rules.
- **D-12:** Test directory structure created upfront: `test/unit/`, `test/widget/`, `test/integration/` with a sample DAO test.

### Claude's Discretion

- Sync queue payload format (JSON text column vs structured columns)
- Exact index composition beyond `start_time` + `direction`
- `build_runner` configuration and watch mode setup
- Exact Drift DAO organization (one per table vs grouped)
- Theme and routes placeholder setup

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

### Additional CLAUDE.md-Level Constraints

- No `dynamic` types unless absolutely necessary. Dart 3 null safety throughout.
- Prefer `const` constructors wherever possible.
- Files `snake_case.dart`; classes `PascalCase`.
- Widgets ≤ 100 lines; extract sub-widgets when larger.
- Sealed classes or enums for finite state (tracking state, sync status, direction).
- UUIDs generated client-side (v4 random) via the `uuid` package.
- All timestamps ISO 8601 / UTC; convert to local only in UI layer.
- **No hardcoded strings for labels, thresholds, or config values — everything in `lib/config/constants.dart`.**
- Drift is the only data source for UI. No network reads in Phase 1 (no network layer yet anyway).
- All state flows through Riverpod providers. No `setState`/`ChangeNotifier`.
- No `SELECT *` in Drift DAOs — always explicit column selection (polyline must not be loaded for list queries — see Pitfall 3).
- **GSD workflow:** file changes must originate from a GSD command. Phase 1 plans will be executed through `/gsd-execute-phase`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SYNC-01 | All trip data stored locally in Drift (offline-first, works without network) | The Drift 2.32 + `drift_flutter` setup, the three-table schema (trips, sync_queue, user_preferences), the DAO pattern with reactive streams, and `schemaVersion: 1` with explicit `MigrationStrategy` together satisfy SYNC-01. No network code is introduced in Phase 1, which inherently proves "works without network" — the app boots, opens the DB, and surfaces empty DAO streams. Actual trip writes happen in Phase 2/3 but they will use the DAOs this phase creates. |

**Requirement satisfaction criteria for SYNC-01 in Phase 1:**
- `AppDatabase` opens successfully at app launch via `driftDatabase(name: 'traevy')`.
- Schema is at version 1, contains `trips`, `sync_queue`, `user_preferences` tables.
- `TripsDao`, `SyncQueueDao`, `UserPreferencesDao` exist and compile with generated code.
- A DAO-level unit test (Drift `NativeDatabase.memory()`) demonstrates CRUD round-trip with no network involvement.
- Migration test scaffolding (`drift_schemas/` + `test/generated_migrations/`) exists even if empty, so Phase 2+ can add migrations safely.
</phase_requirements>

## Standard Stack

> All versions verified **2026-04-12** against the live pub.dev registry. `[VERIFIED: pub.dev API]`

### Core (Phase 1 only)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | 3.41.6 (stable) | UI framework + tooling | `[VERIFIED: flutter --version]` locally installed. Ships Dart 3.11.4 with sealed classes, pattern matching, records. |
| Dart | 3.11.4 | Language | `[VERIFIED: dart --version]` Ships with Flutter 3.41.6. |
| drift | ^2.32.1 | Type-safe SQLite with reactive queries | `[VERIFIED: pub.dev, published 2026-03-22]` Current stable. Superset of sqflite with code-gen, migrations, streams, DAOs. |
| drift_flutter | ^0.3.0 | Platform glue for opening Drift on Flutter | `[VERIFIED: pub.dev, published 2026-02-28]` Replaces the old `sqlite3_flutter_libs + path_provider + NativeDatabase` hand-wired setup. Single-call `driftDatabase(name: 'app_db')` that works on Android/iOS/desktop/web. |
| path_provider | ^2.1.5 | App-support directory lookup | `[VERIFIED: pub.dev]` Still needed explicitly if we want full control over the database path. `drift_flutter` depends on it transitively but referencing it directly is fine and often clearer. |
| flutter_riverpod | ^3.3.1 | State management runtime | `[VERIFIED: pub.dev, published 2026-03-09]` Riverpod 3.x is current (3.0 shipped 2025-09-10). Compile-safe, no `BuildContext` dependency. `[CITED: pub.dev/packages/flutter_riverpod/changelog]` |
| riverpod_annotation | ^4.0.2 | `@riverpod` annotation class | `[VERIFIED: pub.dev, published 2026-02-03]` Keep major version aligned with `riverpod_generator`. |
| uuid | ^4.5.3 | Client-side v4 UUID generation | `[VERIFIED: pub.dev, published 2026-02-21]` For trip IDs. |
| intl | ^0.20.2 | Date/time formatting | `[VERIFIED: pub.dev, published 2025-01-24]` Note: STACK.md lists ^0.19 — 0.20.x is current. |

### Dev Dependencies (Phase 1)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| drift_dev | ^2.32.1 | Drift code generator + schema tooling | `[VERIFIED: pub.dev]` Must match `drift` major.minor. Provides `drift_dev schema dump/generate` commands for migration test scaffolding. |
| build_runner | ^2.13.1 | Dart code-gen orchestrator | `[VERIFIED: pub.dev, published 2026-03-20]` Note: STACK.md lists ^2.4 — 2.13.x is current. |
| riverpod_generator | ^4.0.3 | `@riverpod` code generator | `[VERIFIED: pub.dev, published 2026-02-03]` Must match `riverpod_annotation` major version. |
| custom_lint | ^0.8.1 | Host for riverpod_lint rules | `[VERIFIED: pub.dev]` Required runner for `riverpod_lint`. |
| riverpod_lint | latest | Lint rules that catch common Riverpod mistakes | `[CITED: riverpod.dev]` Standard for new Riverpod projects. Catches missing `ref.watch`, stale providers, etc. |
| very_good_analysis | ^10.2.0 | Strict lint ruleset | `[VERIFIED: pub.dev, published 2026-02-16]` Note: this is a major version jump from STACK.md's implicit ^6. Confirmed as the current latest. |
| test | ^1.25.0 | Dart unit test framework | Ships transitively with `flutter_test` but test files use `package:test/test.dart` idiom; the Flutter test harness re-exports it. |

### What is explicitly **not** installed in Phase 1 (per D-07)

| Deferred to | Packages |
|-------------|----------|
| Phase 2 (tracking) | `geolocator`, `flutter_background_service`, `flutter_polyline_points`, `google_maps_flutter`, `flutter_local_notifications`, `permission_handler` |
| Phase 7 (charts/polish) | `fl_chart`, `table_calendar` |
| Phase 8 (auth) | `google_sign_in`, `amazon_cognito_identity_dart_2`, `flutter_secure_storage` |
| Phase 9/10 (sync/backend) | `http`, `connectivity_plus`, anything in `backend/` |

### Alternatives Considered and Rejected

| Instead of | Could Use | Why rejected |
|------------|-----------|--------------|
| `drift_flutter` | Hand-rolled `NativeDatabase` + `sqlite3_flutter_libs` + `path_provider` | `sqlite3_flutter_libs` is **EOL at 0.6.0+eol** (2026-02-15). The readme explicitly says "Not used anymore, update to version 3.x of package:sqlite3 instead." `drift_flutter` is the first-party blessed replacement. `[VERIFIED: pub.dev/packages/sqlite3_flutter_libs]` |
| `drift` | `sqflite`, `isar`, `objectbox`, `hive` | D-04 and schema complexity rule these out. Drift is the locked choice in STACK.md and CLAUDE.md. |
| `flutter_riverpod` | `bloc`, `provider`, `get` | Locked by CLAUDE.md ("Riverpod for all state"). |
| `very_good_analysis` | `flutter_lints`, `lint` | D-11 locks `very_good_analysis`. |
| `@riverpod` codegen | Manual `StateNotifierProvider` / `StreamProvider` | Manual providers are **legacy in 3.x** and moved to `legacy.dart`. Codegen is the forward-compatible path. `[CITED: pub.dev/packages/flutter_riverpod/changelog]` |

### Installation

```bash
# Create project at repo root (note the trailing dot)
flutter create --org traevy --project-name traevy .

# Runtime dependencies (Phase 1 only)
flutter pub add drift drift_flutter path_provider
flutter pub add flutter_riverpod riverpod_annotation
flutter pub add uuid intl

# Dev dependencies
flutter pub add -d drift_dev build_runner riverpod_generator
flutter pub add -d custom_lint riverpod_lint
flutter pub add -d very_good_analysis

# Generate code (first run)
dart run build_runner build --delete-conflicting-outputs
```

**Version verification performed 2026-04-12:** Every package above was queried directly against `https://pub.dev/api/packages/<name>` and the `latest.version` + `latest.published` fields were recorded. `[VERIFIED: pub.dev registry API]`

## Architecture Patterns

### Recommended Phase 1 Project Structure

Per D-06, **only these directories exist after Phase 1**:

```
traevy/
├── pubspec.yaml
├── analysis_options.yaml          # include: very_good_analysis + riverpod_lint
├── build.yaml                     # (optional) build_runner config
├── android/
│   └── app/build.gradle           # minSdkVersion = 34, targetSdk = 34
├── drift_schemas/                 # exported schema snapshots (schema v1 dump)
│   └── drift_schema_v1.json
├── lib/
│   ├── main.dart                  # runApp(ProviderScope(child: TraevyApp()))
│   ├── app.dart                   # MaterialApp, theme, (empty) home
│   ├── config/
│   │   ├── constants.dart         # speed threshold, cutoff hours, retry limits
│   │   ├── theme.dart             # light/dark ThemeData placeholders
│   │   └── routes.dart            # named route constants (empty map for now)
│   ├── database/
│   │   ├── database.dart          # AppDatabase class, schemaVersion, migration
│   │   ├── database.g.dart        # generated
│   │   ├── tables/
│   │   │   ├── trips_table.dart
│   │   │   ├── sync_queue_table.dart
│   │   │   └── user_preferences_table.dart
│   │   ├── daos/
│   │   │   ├── trips_dao.dart
│   │   │   ├── trips_dao.g.dart
│   │   │   ├── sync_queue_dao.dart
│   │   │   ├── sync_queue_dao.g.dart
│   │   │   ├── user_preferences_dao.dart
│   │   │   └── user_preferences_dao.g.dart
│   │   └── providers.dart         # @riverpod appDatabase + DAO providers
│   └── shared/
│       ├── models/                # (empty, placeholder for shared DTOs)
│       ├── utils/                 # (empty)
│       └── widgets/               # (empty)
└── test/
    ├── unit/
    │   └── database/
    │       └── trips_dao_test.dart       # sample in-memory DAO test
    ├── widget/
    │   └── app_test.dart                 # smoke test that the app builds
    ├── integration/                      # empty placeholder
    └── generated_migrations/             # drift_dev schema generate output
        └── schema.dart
```

**What is deliberately absent and why:** `features/`, `sync/`, `notifications/`, and `backend/` are not created in Phase 1 because D-06 says directories are created phase-by-phase. Creating them empty invites dead-code lint warnings and misleads future phases.

### Pattern 1: `drift_flutter` Database Opening

**What:** Use `drift_flutter`'s `driftDatabase(name: ...)` instead of manually composing `NativeDatabase` + `path_provider`.

**When to use:** Always on Flutter. The only reason to drop back to `NativeDatabase.memory()` is inside unit tests.

**Example:**
```dart
// Source: drift.simonbinder.eu/docs/getting-started/ [CITED]
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/trips_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/user_preferences_table.dart';
import 'daos/trips_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/user_preferences_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Trips, SyncQueue, UserPreferences],
  daos: [TripsDao, SyncQueueDao, UserPreferencesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // No upgrades yet at v1 — scaffolding only.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'traevy',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
```

**Why the explicit executor parameter matters:** It allows test files to inject `NativeDatabase.memory()` (see Pattern 4 below). Without it, you can't unit-test the database.

### Pattern 2: Table Definition with Indexes (D-03)

**What:** Define each table in its own file under `database/tables/`. Apply indexes via `@TableIndex` annotations.

**Example:**
```dart
// Source: drift.simonbinder.eu/docs/dart_api/tables/ [CITED]
import 'package:drift/drift.dart';

@DataClassName('TripRow')
@TableIndex(name: 'idx_trips_start_time', columns: {#startTime})
@TableIndex(name: 'idx_trips_direction_start', columns: {#direction, #startTime})
class Trips extends Table {
  TextColumn get id => text()(); // UUID, generated client-side
  TextColumn get userId =>
      text().withDefault(const Constant('local_user'))(); // D-02
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  IntColumn get durationSeconds => integer()();
  RealColumn get distanceMeters => real()();
  TextColumn get routePolyline => text().nullable()(); // D-01: same table
  TextColumn get direction => text()(); // "to_office" | "to_home"
  IntColumn get timeMovingSeconds => integer()();
  IntColumn get timeStuckSeconds => integer()();
  BoolColumn get isManualEntry =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

**Index rationale for D-03:**
- `idx_trips_start_time` — covers daily log queries and date-range stats (`WHERE start_time BETWEEN`).
- `idx_trips_direction_start` — composite, covers "my last 4 weeks of to-office trips" style queries that the stats phase will need. Direction-first ordering is correct because it has lower cardinality (2 values) and queries always filter by direction before sorting by time.
- Claude's discretion per D-03 — document the rationale so Phase 5 stats planner understands why.

### Pattern 3: DAO With Selective Column Loading

**What:** DAOs project only the columns they need. **Never `SELECT *` on `trips`** because that loads `routePolyline`. (Pitfall 7 in PITFALLS.md.)

```dart
// Source: drift.simonbinder.eu/docs/daos/ [CITED]
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/trips_table.dart';

part 'trips_dao.g.dart';

// Lightweight projection for list views — no polyline column.
class TripSummary {
  const TripSummary({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.direction,
    required this.timeMovingSeconds,
    required this.timeStuckSeconds,
    required this.isManualEntry,
  });

  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final double distanceMeters;
  final String direction;
  final int timeMovingSeconds;
  final int timeStuckSeconds;
  final bool isManualEntry;
}

@DriftAccessor(tables: [Trips])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(super.db);

  /// Stream all trip summaries (no polyline). UI binds to this.
  Stream<List<TripSummary>> watchAllSummaries() {
    final query = select(trips);
    return query.map(_toSummary).watch();
  }

  /// Full row including polyline — only called by the trip detail screen.
  Future<TripRow?> findById(String id) {
    return (select(trips)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertTrip(TripsCompanion companion) {
    return into(trips).insert(companion);
  }

  TripSummary _toSummary(TripRow r) => TripSummary(
        id: r.id,
        startTime: r.startTime,
        endTime: r.endTime,
        durationSeconds: r.durationSeconds,
        distanceMeters: r.distanceMeters,
        direction: r.direction,
        timeMovingSeconds: r.timeMovingSeconds,
        timeStuckSeconds: r.timeStuckSeconds,
        isManualEntry: r.isManualEntry,
      );
}
```

**Claude's discretion (D-03/sync queue payload):** For `SyncQueueDao`, the sync_queue table stores only `trip_id` (FK) — **not** a serialized JSON blob. Rationale: PITFALLS.md §Performance Traps warns that JSON-serializing the full trip payload means edits after enqueueing create stale sync data. Reading fresh from `trips` at sync time is cleaner. The `payload` column named in CLAUDE.md is retained as `text nullable` for the `"delete"` action case where the trip row has already been removed — on delete, capture `{trip_id, user_id}` into `payload`.

### Pattern 4: Riverpod 3.x Provider Scaffolding with Code Generation

**What:** All provider classes use `@riverpod`. No manual `StateNotifierProvider` or `Provider((ref) => ...)`.

```dart
// Source: riverpod.dev/docs/concepts/about_code_generation [CITED]
// database/providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'database.dart';
import 'daos/trips_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/user_preferences_dao.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@riverpod
TripsDao tripsDao(Ref ref) => ref.watch(appDatabaseProvider).tripsDao;

@riverpod
SyncQueueDao syncQueueDao(Ref ref) =>
    ref.watch(appDatabaseProvider).syncQueueDao;

@riverpod
UserPreferencesDao userPreferencesDao(Ref ref) =>
    ref.watch(appDatabaseProvider).userPreferencesDao;
```

**Riverpod 3.x breaking-change callouts for the planner:**
- The function-style `@riverpod` provider above takes a bare `Ref`, not `FutureProviderRef`/`StreamProviderRef`. Those subclasses were removed in 3.0. `[CITED: flutter_riverpod 3.0.0 changelog]`
- `keepAlive: true` on `appDatabase` is mandatory — without it, every widget disposal would close the DB. `[ASSUMED from Riverpod lifecycle docs]`
- `StreamProvider` auto-pauses when nothing is listening in 3.x. For Drift streams this is actually desirable (no point watching the DB when no UI is mounted). `[CITED: flutter_riverpod 3.0.0 changelog]`
- `AsyncValue.value` returns `null` on error in 3.x (was `throw`). Any widget code that reads AsyncValue from a provider must use `.valueOrNull` or pattern-matching. Not directly relevant to Phase 1 (no UI consumes providers yet) but add a note to the planner for Phase 2+.

### Pattern 5: Migration Test Scaffolding (D-10)

**What:** Generate the schema snapshot and migration-test harness at v1 even though no migrations exist yet. Future phases reuse this infrastructure when they add columns.

```bash
# Source: drift.simonbinder.eu/Migrations/tests/ [CITED]

# 1. Export v1 schema
dart run drift_dev schema dump \
  lib/database/database.dart \
  drift_schemas/

# 2. Generate test helpers
dart run drift_dev schema generate \
  drift_schemas/ \
  test/generated_migrations/
```

```dart
// test/unit/database/migration_scaffold_test.dart
// Source: drift.simonbinder.eu/Migrations/tests/ [CITED]
import 'package:drift_dev/api/migrations_native.dart';
import 'package:test/test.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('schema v1 opens cleanly', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    // With only one schema version, we just confirm it opens.
    await db.customSelect('SELECT 1').get();
    await db.close();
  });
}
```

**Why scaffold this at v1:** The test above passes trivially. Its value is that (a) the commands are documented and wired, (b) `drift_schemas/drift_schema_v1.json` exists as the reference point for future diffs, (c) when Phase 4 adds a column, the planner only needs to bump `schemaVersion`, write an `onUpgrade` branch, run `drift_dev schema dump`, and add a `migrateAndValidate` test — not set up the whole harness from scratch.

### Pattern 6: In-Memory DAO Unit Test (D-12)

```dart
// test/unit/database/trips_dao_test.dart
// Source: drift.simonbinder.eu/Testing/ [CITED]
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:traevy/database/database.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;

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

  test('inserted trip is returned by watchAllSummaries', () async {
    final id = const Uuid().v4();
    final now = DateTime.utc(2026, 1, 1, 8);
    await db.tripsDao.insertTrip(
      TripsCompanion.insert(
        id: id,
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        durationSeconds: 1800,
        distanceMeters: 12500,
        direction: 'to_office',
        timeMovingSeconds: 1500,
        timeStuckSeconds: 300,
      ),
    );

    final summaries = await db.tripsDao.watchAllSummaries().first;
    expect(summaries, hasLength(1));
    expect(summaries.single.id, id);
    expect(summaries.single.direction, 'to_office');
  });
}
```

**`closeStreamsSynchronously: true` is mandatory in Flutter test context** — otherwise `fake_async`-based widget tests leak timers and the test runner reports "Pending timers" at teardown. `[CITED: drift.simonbinder.eu/Testing]`

### Anti-Patterns to Avoid

- **SELECT * on the trips table** — loads polyline column into memory on every list query. Use explicit projections (see Pattern 3).
- **Manual `StateNotifierProvider`** — legacy in Riverpod 3.x. Use `@riverpod` codegen.
- **Seeding a user_preferences row in migration `onCreate`** — D-04 says code must handle missing row with defaults. Don't fight the locked decision.
- **Calling `driftDatabase(name: ...)` from inside a test** — it hits the real filesystem. Tests must use `NativeDatabase.memory()` via an injected executor.
- **Creating `features/` directories in Phase 1** — D-06 forbids it. Empty directories become dead code and confuse future phases.
- **Hard-coding the database filename anywhere but `database.dart`** — D-11 / CLAUDE.md constants rule means the filename `'traevy'` should be a constant.
- **Using `path_provider`'s `getApplicationDocumentsDirectory` instead of `getApplicationSupportDirectory`** — the docs directory is user-visible on iOS and leaks the DB into iCloud backup exposure. Support directory is the correct choice for on-device DBs. `[CITED: drift.simonbinder.eu/docs/getting-started]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SQLite connection, platform channels, native binary loading | A custom `openDatabase` using `sqflite` or raw FFI | `drift_flutter`'s `driftDatabase(name: ...)` | Handles Android/iOS/desktop/web in one call, tracks the Drift version compatibility, and is maintained by the Drift author. |
| Database path resolution | `Directory.systemTemp` or hand-computed paths | `path_provider.getApplicationSupportDirectory` | Respects platform conventions, survives app updates, avoids iCloud backup on iOS. |
| Migration tests | Hand-written SQL fixtures per version | `drift_dev schema dump` + `schema generate` + `SchemaVerifier` | Generated helpers track column diffs automatically. Writing migration tests by hand is the #1 way to ship broken migrations. |
| UUID generation | `Random().nextInt` concatenation | `Uuid().v4()` | Cryptographically proper RFC-4122 v4 IDs. |
| Provider disposal wiring | Manual `dispose` callbacks | `@riverpod` + `ref.onDispose` | Riverpod handles dependency graphs; manual dispose leaks DBs. |
| analysis_options.yaml from scratch | Copy/paste lint rules | `include: package:very_good_analysis/analysis_options.yaml` | Curated, maintained, updated with each Dart release. |

**Key insight:** Phase 1 is *entirely* a wiring exercise. Every line of hand-written code here is a liability. Lean on generators (`build_runner`, `drift_dev`, `riverpod_generator`) and `drift_flutter` so the human-authored surface area is: table definitions, DAO methods, config constants, and a handful of tests. Nothing else.

## Common Pitfalls

### Pitfall 1: Drift 2.22 → 2.32 setup drift (STACK.md staleness)

**What goes wrong:** Planner or executor references `sqlite3_flutter_libs` from STACK.md, hand-wires `NativeDatabase(File(...))`, and ends up with either a deprecation warning or an outright EOL package that stops receiving fixes.

**Why it happens:** STACK.md was researched 2026-04-11 against training data that predates Drift 2.25+ and `drift_flutter` 0.3. Between April 2026 and now (one day, but Drift moves fast), the blessed setup changed.

**How to avoid:** Use `drift_flutter` + `path_provider`. Do not add `sqlite3_flutter_libs` to `pubspec.yaml`.

**Warning signs:** `sqlite3_flutter_libs` appearing in `pubspec.lock`, `0.6.0+eol` in the resolved version.

### Pitfall 2: Riverpod 2.x → 3.x breaking changes

**What goes wrong:** Planner writes `StreamProvider((ref) => dao.watch...)` because STACK.md says `^2.6`. It compiles against `legacy.dart` but fails lint, or worse, plans Phase 2 UI code that reads `.value` from AsyncValue and surprises itself when errors return `null`.

**Why it happens:** Riverpod 3.0 shipped 2025-09-10; 3.3.1 is current. STACK.md is stale. Key behavioral deltas:
1. `StateProvider`/`StateNotifierProvider` moved to `flutter_riverpod/legacy.dart`.
2. `AsyncValue.value` now returns `null` on error. `AsyncValue.valueOrNull` was removed as redundant.
3. `StreamProvider` pauses its underlying `StreamSubscription` when no listeners are attached — good for Drift streams but surprising if you assume a stream is always hot.
4. `ProviderException` wraps rethrown errors from `ref.watch`/`ref.read`.
5. Notifiers are now recreated when providers rebuild (enables `Ref.mounted`).

**How to avoid:** Exclusively use `@riverpod` codegen. Read the 3.0 changelog once before Phase 2 planning.

**Warning signs:** Imports from `package:flutter_riverpod/legacy.dart`, manual `StreamProvider` constructors, use of `.valueOrNull`.

**Source:** `[CITED: pub.dev/packages/flutter_riverpod/changelog]`

### Pitfall 3: Polyline column in the trips table becomes a hidden performance landmine (PITFALLS.md §7)

**What goes wrong:** D-01 says polylines live in the trips table. That's fine *if* every query uses explicit column projection. If any DAO method does `SELECT * FROM trips`, it will load ~5-15 KB per trip into memory just to render a list card.

**Why it happens:** Drift's default `select(trips).get()` returns full `TripRow` objects. The generated `.watch()` variant does too. It's easy to reach for it.

**How to avoid:** (a) Never return `TripRow` from a list-oriented DAO method. Always project into a `TripSummary` value type as shown in Pattern 3. (b) Add a lint rule or code review checklist item. (c) `routePolyline` column declared `.nullable()` so that manual entries (`is_manual_entry = true`) don't allocate storage.

**Warning signs:** `TripRow` appearing in UI widget imports, `watchAllTrips()` style method names.

### Pitfall 4: Drift migrations break on first schema change (PITFALLS.md §3)

**What goes wrong:** Phase 4 adds a column to `trips`. Migration isn't written or isn't tested. Dev devices work (they're fresh); real users hit `SqliteException: no such column`.

**Why it happens:** Drift requires explicit migration code for every schema change. The 2.32 `drift_dev make-migrations` command helps, but you have to actually run it and commit the generated schema.

**How to avoid:** (a) Start schemaVersion at 1 and commit `drift_schemas/drift_schema_v1.json` in Phase 1. (b) Create `test/generated_migrations/schema.dart` so future `migrateAndValidate` tests have a place to live. (c) Add a CI step that runs `dart run drift_dev schema dump` and fails if the committed `drift_schemas/` is stale.

**Warning signs:** `schemaVersion` incremented without a new file in `drift_schemas/`, no `migrateAndValidate` test for the new version.

### Pitfall 5: build_runner watch stalls on generated-file conflicts

**What goes wrong:** Developer renames `Trips` table → re-runs build_runner → old `trips_dao.g.dart` still references the old name → build fails cryptically.

**Why it happens:** `build_runner build` does not delete stale outputs by default.

**How to avoid:** Always use `dart run build_runner build --delete-conflicting-outputs` in scripts and document it in the README. Prefer `dart run build_runner watch --delete-conflicting-outputs` during development.

**Warning signs:** "Conflicting outputs" in build_runner stdout; `.g.dart` files with stale class references.

### Pitfall 6: very_good_analysis 10.x lint surprises

**What goes wrong:** `very_good_analysis ^10` is stricter than `^6`. First `flutter analyze` run after install produces 100+ findings — mostly `avoid_positional_boolean_parameters`, `prefer_const_constructors`, `public_member_api_docs`, etc. Team gets discouraged, turns lint off, defeats the purpose of D-11.

**Why it happens:** Version jump from 6 → 10 across ~18 months of rule additions. Rules are opinionated by design.

**How to avoid:** (a) Enable lint **before** writing real code so the baseline is zero. (b) If specific rules are noise for this project (e.g., `public_member_api_docs` inside `lib/` for an internal app), disable them explicitly in `analysis_options.yaml`:
```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - lib/**/*.g.dart
    - test/generated_migrations/**
  errors:
    public_member_api_docs: ignore
```
Generated files must be excluded or every `.g.dart` re-generation produces lint noise.

**Warning signs:** `flutter analyze` output longer than one screen immediately after install; developers muttering about "that lint thing."

### Pitfall 7: minSdkVersion 34 shuts out older Android devices

**What goes wrong:** D-08 says "latest stable (API 34/Android 14)". Setting `minSdkVersion = 34` means anyone on Android 13 or below cannot install the app. Android 14 share of the active install base in 2026 is around 40-55%; setting `minSdkVersion` that high excludes >40% of potential users.

**Why it happens:** D-08 conflates `targetSdkVersion` (the API level the app is tested against — should be latest) with `minSdkVersion` (the lowest API level that can install — should be realistic).

**How to avoid:** Set `targetSdk = 34` (or higher if 35 is out) and `minSdkVersion = 26` (Android 8.0). API 26 is the minimum required by `flutter_background_service` (per STACK.md) which Phase 2 needs. Drift needs nothing lower. geolocator needs API 21+. **The binding constraint is flutter_background_service at API 26.**

**Recommended action for the planner:** Treat D-08 as "target latest; min set to the lowest value that supports all required phase 2+ packages" and flag this in the plan discussion so the user can confirm. If the user really wants `minSdk = 34`, that's their call, but they should make it knowingly.

**Status:** `[ASSUMED]` — Android install base percentages are training-data estimates. The *technical* minimum (API 26 for foreground services) is `[CITED: developer.android.com/about/versions/oreo/android-8.0-changes#back-all]`.

### Pitfall 8: `riverpod_lint` not wired → provider mistakes slip through

**What goes wrong:** Team adds `riverpod_lint` to dev_dependencies but forgets `custom_lint` in `analysis_options.yaml`. Lints don't run. Team only discovers stale-ref bugs at runtime.

**How to avoid:** After installing `custom_lint` and `riverpod_lint`, append to `analysis_options.yaml`:
```yaml
analyzer:
  plugins:
    - custom_lint
```
And run `dart run custom_lint` once to confirm the plugin reports findings. `[CITED: riverpod.dev/docs/introduction/getting_started]`

## Code Examples

See Pattern 1-6 above for full verified examples. Short index:

- **DB class + drift_flutter opening** → Pattern 1
- **Table with `@TableIndex`** → Pattern 2
- **DAO projection + non-SELECT-* streams** → Pattern 3
- **`@riverpod` providers for DB and DAOs** → Pattern 4
- **`drift_dev schema dump` + `SchemaVerifier` test** → Pattern 5
- **`NativeDatabase.memory()` DAO unit test** → Pattern 6

### Additional: `analysis_options.yaml` recommended starter

```yaml
# Source: very_good_analysis docs + riverpod_lint docs [CITED]
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - lib/**/*.g.dart
    - lib/**/*.freezed.dart
    - test/generated_migrations/**
    - drift_schemas/**
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  plugins:
    - custom_lint
  errors:
    # Internal app — not publishing a public API.
    public_member_api_docs: ignore
    # Drift companion constructors use positional booleans by design.
    avoid_positional_boolean_parameters: warning

linter:
  rules:
    # Enforce CLAUDE.md conventions
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    avoid_dynamic_calls: true
```

### Additional: `constants.dart` starter (per "no hardcoded values" rule)

```dart
// lib/config/constants.dart

/// Speed threshold (km/h) below which a trip sample counts as stuck in traffic.
/// See CLAUDE.md "Traffic Calculation".
const double kStuckSpeedThresholdKmh = 10;

/// Hour-of-day cutoff (local time) used for auto-labeling direction.
/// Trips starting strictly before this hour are "to_office"; at or after → "to_home".
const int kDefaultDirectionCutoffHour = 12;

/// Default placeholder user_id used until auth is introduced in Phase 8.
/// See D-02 in .planning/phases/01-foundation/01-CONTEXT.md.
const String kDefaultUserId = 'local_user';

/// Drift database filename (without extension).
const String kDatabaseName = 'traevy';

/// Maximum retries before a sync queue entry is marked failed (Phase 10 uses this).
const int kSyncQueueMaxRetries = 3;

/// Direction values — strings because Drift schema uses text. Keep in sync with
/// sealed TripDirection class that wraps them (introduced in Phase 3).
const String kDirectionToOffice = 'to_office';
const String kDirectionToHome = 'to_home';

/// Sync queue action values.
const String kSyncActionCreate = 'create';
const String kSyncActionUpdate = 'update';
const String kSyncActionDelete = 'delete';

/// Sync queue status values.
const String kSyncStatusPending = 'pending';
const String kSyncStatusSynced = 'synced';
const String kSyncStatusFailed = 'failed';
```

## Runtime State Inventory

**Phase type:** Greenfield scaffold. This section is included for completeness but all categories are trivially empty.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | **None** — no existing database, collection, or datastore. The Drift DB file does not exist yet; Phase 1 creates it from scratch. | N/A |
| Live service config | **None** — no external services touched in Phase 1. No n8n/Datadog/Tailscale/Cloudflare state. | N/A |
| OS-registered state | **None** — no Windows Task Scheduler, launchd, systemd, pm2 entries. The only OS touchpoint is the future APK install ID derived from `traevy.traevy`; creating this is the whole point of the phase. | N/A |
| Secrets/env vars | **None** — Phase 1 introduces no secrets. Google Cloud / Cognito credentials arrive in Phase 8. | N/A |
| Build artifacts | **None** — no existing `build/`, `.dart_tool/`, `pubspec.lock`, or `*.g.dart` files in the repo. | Normal `flutter create` + `build_runner build` generates them. |

**Canonical answer:** After Phase 1 completes, the runtime state that will exist is: (a) the generated Flutter project tree, (b) `android/` Gradle config with package id `traevy.traevy`, (c) generated `.g.dart` files, (d) eventually (after first run on a device) a `traevy.sqlite` file in the app-support directory. None of this exists before Phase 1.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Flutter SDK | Entire phase | ✓ | 3.41.6 stable | — |
| Dart SDK | Entire phase | ✓ | 3.11.4 | Ships with Flutter — no separate install |
| Android SDK / toolchain | `flutter create`, `flutter build apk` | ✓ | Android SDK 37.0.0 | — |
| Android device or emulator | Smoke-run verification | ✓ | 2 connected devices reported by `flutter doctor` | — |
| Xcode / CocoaPods | iOS builds | ✗ | — | **Not required for Phase 1.** Platform is Android-only per PROJECT.md constraints. Flag if the planner adds iOS tasks. |
| Git | Commit artifacts | ✓ | Already in use on this repo | — |
| Internet / pub.dev access | `flutter pub get`, `build_runner` first run | **Assumed ✓** | — | Required for first dependency resolution. Offline Phase 1 is not feasible. |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** Xcode/CocoaPods — irrelevant because Android-only is a PROJECT.md constraint.

**Environment verification commands run 2026-04-12:** `flutter --version`, `dart --version`, `flutter doctor`. Output captured in research session. `[VERIFIED: local machine]`

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` — this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (ships with Flutter 3.41.6) + `drift_dev`'s `SchemaVerifier` for migration tests |
| Config file | None yet — `test/` does not exist. **Wave 0 creates directories and the first test files.** |
| Quick run command | `flutter test test/unit/database/trips_dao_test.dart -r expanded` |
| Full suite command | `flutter test` |
| Static analysis | `flutter analyze` |
| Formatter check | `dart format --set-exit-if-changed .` |
| Generator check | `dart run build_runner build --delete-conflicting-outputs` (must succeed with zero errors) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SYNC-01 | `AppDatabase` opens via `drift_flutter` on Android | smoke (widget test that calls `AppDatabase()` and runs `SELECT 1`) | `flutter test test/widget/app_test.dart -r expanded` | ❌ Wave 0 |
| SYNC-01 | `TripsDao` round-trips a trip (insert → watchAllSummaries) using in-memory DB | unit | `flutter test test/unit/database/trips_dao_test.dart -r expanded` | ❌ Wave 0 |
| SYNC-01 | `SyncQueueDao` round-trips a pending entry | unit | `flutter test test/unit/database/sync_queue_dao_test.dart -r expanded` | ❌ Wave 0 |
| SYNC-01 | `UserPreferencesDao.getOrDefault()` returns defaults when no row exists (D-04) | unit | `flutter test test/unit/database/user_preferences_dao_test.dart -r expanded` | ❌ Wave 0 |
| SYNC-01 | Schema v1 migration harness opens cleanly | unit (scaffold) | `flutter test test/unit/database/migration_scaffold_test.dart -r expanded` | ❌ Wave 0 |
| SYNC-01 | Indexes on start_time and direction exist (D-03) | unit (query `sqlite_master` for `idx_trips_*`) | `flutter test test/unit/database/trips_indexes_test.dart -r expanded` | ❌ Wave 0 |
| D-11 lint compliance | `flutter analyze` returns zero errors/warnings | static | `flutter analyze` | ❌ Wave 0 (analysis_options.yaml must exist) |
| D-10 migration scaffolding | `drift_schemas/drift_schema_v1.json` exists and matches the live database | tooling | `dart run drift_dev schema dump lib/database/database.dart drift_schemas/ --check` (fails if stale) | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter analyze && flutter test test/unit/database/ -r expanded` (fast; runs in under 15 seconds in-memory).
- **Per wave merge:** `dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`.
- **Phase gate (before `/gsd-verify-work`):** full suite green, schema dump up to date, `flutter build apk --debug` completes (proves the scaffold is actually runnable on Android, not just in tests).

### Wave 0 Gaps

- [ ] `pubspec.yaml` — does not exist yet; created by `flutter create`.
- [ ] `analysis_options.yaml` — created with `very_good_analysis` include and `custom_lint` plugin.
- [ ] `test/unit/database/trips_dao_test.dart` — covers SYNC-01 (DAO round-trip).
- [ ] `test/unit/database/sync_queue_dao_test.dart` — covers SYNC-01.
- [ ] `test/unit/database/user_preferences_dao_test.dart` — covers D-04 missing-row-with-defaults.
- [ ] `test/unit/database/trips_indexes_test.dart` — covers D-03 (query `sqlite_master`).
- [ ] `test/unit/database/migration_scaffold_test.dart` — covers D-10.
- [ ] `test/widget/app_test.dart` — smoke-test that `TraevyApp` builds under `ProviderScope`.
- [ ] `test/generated_migrations/schema.dart` — generated by `drift_dev schema generate`.
- [ ] `drift_schemas/drift_schema_v1.json` — generated by `drift_dev schema dump`.
- [ ] Framework install: **none needed** — `flutter_test` ships with Flutter SDK.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `keepAlive: true` on the `appDatabase` provider is required to prevent disposal across widget rebuilds | Pattern 4 | Low — if wrong, DB closes too aggressively and tests / first-launch fail loudly. Easy to spot and fix. |
| A2 | Android 14 install base is ~40-55% in 2026 (used to argue against minSdk 34) | Pitfall 7 | Medium — if wrong, the recommendation to set minSdk 26 still stands technically (flutter_background_service API 26 floor is verified), only the user-facing framing changes. |
| A3 | `drift_flutter 0.3.0` supports the `DriftNativeOptions(databaseDirectory:)` parameter as shown | Pattern 1 | Medium — code signature was extracted from Drift docs but not compiled locally in this session. If the signature differs, the planner will catch it at `flutter pub get` / first build. |
| A4 | `riverpod_lint` wiring via `custom_lint` analysis plugin is still the 2026 approach | Pitfall 8 | Low — `custom_lint` is the stable host for Riverpod lints per riverpod.dev docs as of research date. |
| A5 | `drift_dev schema dump` accepts `drift_schemas/` as output directory and `lib/database/database.dart` as input (no extra flags needed for a single-DB project) | Pattern 5 | Low — command form is from official docs, but project-specific paths may need a `--help` check on first run. |
| A6 | The `payload` column in sync_queue should carry `{trip_id, user_id}` only for the "delete" action case; otherwise it's empty/null. | Pattern 3 Claude's-discretion note | Medium — this is a design call that conflicts with CLAUDE.md's implicit "JSON-serialized trip data" description. Planner should confirm with user during `/gsd-plan-phase` — either the discretion-area decision stands or CLAUDE.md wins. |
| A7 | `closeStreamsSynchronously: true` is required for Flutter test isolates | Pattern 6 | Low — sourced from Drift testing docs. |

**Planner action on A6:** Raise explicitly in the plan for user confirmation. The cleaner design (read fresh at sync time, payload only for deletes) was locked as "Claude's discretion" in CONTEXT.md — so this is allowed — but CLAUDE.md's schema table lists `payload text "JSON-serialized trip data"` which implies full blob. The user should confirm which wins. Default recommendation: **read fresh at sync time; payload nullable and only populated for deletes.** This prevents PITFALLS.md §Performance Traps row 5 ("JSON serializing entire trip payload for sync_queue").

## Open Questions

1. **Should `minSdkVersion` be 26 or 34?**
   - What we know: D-08 says "latest stable (API 34)". flutter_background_service needs API 26 (Phase 2). Drift has no minimum beyond what Flutter enforces (currently API 21).
   - What's unclear: whether D-08 was intended to set `minSdk` or `targetSdk`.
   - Recommendation: Planner raises this with the user in `/gsd-plan-phase`. Default to `minSdkVersion 26` and `targetSdkVersion 34`.

2. **Should sync_queue payload be a full JSON blob or only populated for deletes?**
   - What we know: CLAUDE.md schema says "JSON-serialized trip data". PITFALLS.md warns against this for edits. CONTEXT.md marks it as Claude's discretion.
   - What's unclear: which document wins.
   - Recommendation: Ask user. Default: nullable, populated only for the delete action (fresh-read-at-sync approach).

3. **Should `routePolyline` be `nullable()` or `withDefault(Constant(''))`?**
   - What we know: Manual-entry trips have no polyline. Phase 3 adds manual entry.
   - What's unclear: which storage pattern is cleaner for Drift queries.
   - Recommendation: `nullable()` — more honest, plays well with `null`-checks in Dart, and lets SQLite skip storage entirely for null values.

4. **Should the `AppDatabase` constructor also accept a `DriftFlutter` executor or keep it as `QueryExecutor`?**
   - What we know: The Pattern 1 constructor accepts `QueryExecutor?` which is the supertype — tests inject `NativeDatabase.memory()`, production injects `driftDatabase(...)`.
   - What's unclear: nothing — this is the idiomatic pattern. Flagged only to confirm the planner doesn't accidentally specialize the type.
   - Recommendation: Keep `QueryExecutor?` exactly as shown.

## State of the Art

| Old Approach (STACK.md) | Current Approach (2026-04-12) | When Changed | Impact |
|-------------------------|-------------------------------|--------------|--------|
| `sqlite3_flutter_libs` + `NativeDatabase(File(...))` + `path_provider` hand-wired | `drift_flutter` → `driftDatabase(name: ...)` one-liner | `drift_flutter` 0.1 ~2025, EOL of `sqlite3_flutter_libs` 2026-02-15 | Smaller pubspec, fewer platform-channel bugs, works on Android/iOS/desktop/web with zero code changes. |
| `flutter_riverpod ^2.6` | `flutter_riverpod ^3.3.1` | Riverpod 3.0 released 2025-09-10 | Breaking: `StateNotifierProvider` legacy, `AsyncValue.value` nullable on error, `StreamProvider` auto-pauses, ref subclasses removed. `@riverpod` codegen pattern unchanged. |
| `very_good_analysis ^6` (implicit) | `very_good_analysis ^10.2.0` | Multiple majors through 2025-2026 | Stricter rules; Wave 0 must set up `analysis_options.yaml` before writing code to keep the baseline clean. |
| `drift ^2.22` | `drift ^2.32.1` | Continuous point releases | Many DX improvements; `drift_dev make-migrations`; better type inference on `select().map(...)`. No breaking changes in table DSL. |
| `build_runner ^2.4` | `build_runner ^2.13.1` | Continuous | Faster incremental builds; `--delete-conflicting-outputs` behavior unchanged. |
| `intl ^0.19` | `intl ^0.20.2` | Jan 2025 | No breaking changes affecting Phase 1 (Phase 1 barely touches intl). |

**Deprecated / removed since STACK.md:**
- `sqlite3_flutter_libs` — **EOL** (0.6.0+eol) — replaced by Drift depending directly on `sqlite3 ^3.x`.
- Manual `StateNotifierProvider` / `StateProvider` — moved to `flutter_riverpod/legacy.dart` and should not be imported in new code.

## Sources

### Primary (HIGH confidence)

- `[VERIFIED: local]` `flutter --version` → Flutter 3.41.6 / Dart 3.11.4.
- `[VERIFIED: local]` `flutter doctor` → Android SDK 37, 2 devices, no Xcode.
- `[VERIFIED: pub.dev API]` `https://pub.dev/api/packages/<pkg>` for every version in Standard Stack. Queried 2026-04-12.
- `[CITED]` `https://pub.dev/packages/sqlite3_flutter_libs` — EOL notice on version 0.6.0+eol.
- `[CITED]` `https://drift.simonbinder.eu/docs/getting-started/` — current Drift + drift_flutter setup.
- `[CITED]` `https://drift.simonbinder.eu/Testing/` — in-memory DB test pattern with `closeStreamsSynchronously: true`.
- `[CITED]` `https://drift.simonbinder.eu/Migrations/tests/` — `SchemaVerifier` test pattern.
- `[CITED]` `https://pub.dev/packages/flutter_riverpod/changelog` — 3.0 breaking changes and 3.3.1 current version.
- `[CITED]` `https://pub.dev/packages/drift_flutter` — recommended Flutter setup replacing sqlite3_flutter_libs.
- `[CITED]` `CLAUDE.md` (project root) — coding conventions, schema table definitions, offline-first rules.
- `[CITED]` `.planning/research/PITFALLS.md` §3, §7, §Performance Traps — migration testing, polyline bloat, sync queue payload.
- `[CITED]` `.planning/research/ARCHITECTURE.md` — four-layer architecture diagram, DAO responsibility boundaries.

### Secondary (MEDIUM confidence)

- `[CITED]` `https://pub.dev/packages/very_good_analysis` — version 10.2.0 and `include:` line.
- `[CITED]` `https://riverpod.dev/docs/concepts/about_code_generation` — `@riverpod` codegen pattern in 3.x.

### Tertiary (LOW confidence / training data)

- Android 14 install base percentages in 2026 (Pitfall 7, A2) — training-data estimate, not live-verified. The *technical* `minSdk 26` recommendation stands regardless.

## Metadata

**Confidence breakdown:**
- Standard stack versions: **HIGH** — every package hit the live pub.dev API minutes before writing this.
- Architecture patterns: **HIGH** — drift_flutter + `@riverpod` patterns came directly from official docs.
- Pitfalls (Drift 2.32 deltas, Riverpod 3.x migration): **HIGH** — changelogs fetched in session.
- Pitfalls (Android minSdk recommendation framing): **MEDIUM** — rests partly on install-base assumption (A2).
- Migration test scaffolding commands: **MEDIUM** — documented pattern but not locally executed in this session.

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 for Drift/Riverpod/very_good_analysis (fast-moving); 2026-07-12 for Flutter SDK version (stable channel).

**Key delta the planner MUST absorb:** STACK.md versions are stale. Use the versions in this research's Standard Stack table, not STACK.md's versions. Specifically: **drop `sqlite3_flutter_libs` entirely and use `drift_flutter`; plan for Riverpod 3.x not 2.x; use `very_good_analysis ^10`.**
