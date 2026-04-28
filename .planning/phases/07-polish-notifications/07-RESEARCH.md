# Phase 7: Polish & Notifications - Research

**Researched:** 2026-04-28
**Domain:** Flutter dark mode theming, flutter_local_notifications scheduled notifications, Drift schema migration
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Settings screen via 4th gear `IconButton` in Dashboard AppBar → `lib/features/settings/screens/settings_screen.dart`; new `lib/features/settings/` folder with `screens/` and `providers/` subdirectories.
- **D-02:** Two sections on settings screen: Appearance (dark mode) + Notifications (weekly summary + reminder).
- **D-03:** Dark mode = 3 `RadioListTile` rows: "System default" / "Light" / "Dark". Maps to `kDarkModeSystem` / `kDarkModeLight` / `kDarkModeDark`.
- **D-04:** Theme change instant via Riverpod — `userPreferenceProvider` (`StreamProvider<UserPreferencesValue>`) watches `UserPreferencesDao.watch()` → `MaterialApp.themeMode:` dynamic in `TraevyApp`.
- **D-05:** Weekly notification fires Sunday at 6pm local time using `zonedSchedule` with `DateTimeComponents.dayOfWeekAndTime`.
- **D-06:** Weekly notification content: Title = `kWeeklySummaryNotificationTitle`; Body = formatted `weekTotalSeconds` + `weekStuckSeconds`. If no trips: "No commutes recorded this week".
- **D-07:** Weekly notification user-toggleable via `SwitchListTile`. Requires new `weeklyNotificationEnabled` boolean column in `UserPreferences` (default `false`). Schema migration required.
- **D-08:** Schedule on app start if enabled; cancel when disabled.
- **D-09:** Reminder uses existing schema: `reminderEnabled`, `reminderTime` (HH:mm), `weekendReminder`.
- **D-10:** Reminder UI: `SwitchListTile` + `ListTile` (tap → `showTimePicker`) + weekend `SwitchListTile`; time row + weekend toggle hidden when reminder off.
- **D-11:** Reminder notification text: Title = `kReminderNotificationTitle`; Body = `kReminderNotificationBody`. Fixed text.
- **D-12:** Reminder scheduling: `zonedSchedule` with `DateTimeComponents.time` (daily) or `DateTimeComponents.dayOfWeekAndTime` (weekdays only when `weekendReminder = false`).
- **D-13:** Drift schema version bumped to 2. Migration adds `weeklyNotificationEnabled` via `m.addColumn(userPreferences, userPreferences.weeklyNotificationEnabled)`.
- **D-14:** Two new notification channels (distinct from `kTrackingNotificationChannelId`): one for weekly summary, one for reminder. Initialized alongside the tracking channel.

### Claude's Discretion

- Exact channel IDs, channel names, channel descriptions for the two new channels
- Whether to create a new `NotificationService` or extend `TrackingNotificationService`
- Settings screen AppBar title
- Section header styling (color, weight, padding)
- Exact empty-week text in weekly notification body
- How the time picker result formats in the `ListTile` subtitle
- Whether weekend toggle uses `enabled:` property or `Visibility` widget
- File naming within `lib/features/settings/`
- Provider naming for user preferences stream

### Deferred Ideas (OUT OF SCOPE)

- Weekly notification user-configurable day/time (always Sunday 6pm in v0.1)
- Notification deep-link to Stats screen on tap
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UX-02 | Dark mode support (system default + manual toggle in settings) | D-03/D-04: RadioListTile + StreamProvider → MaterialApp.themeMode. Theme assets (`lightTheme`, `darkTheme`) already defined in `lib/config/theme.dart`. |
| UX-04 | Weekly summary push notification with commute totals | D-05/D-06/D-07: `zonedSchedule` + `DateTimeComponents.dayOfWeekAndTime`, `weeklyNotificationEnabled` migration, `statsSummaryProvider` data. |
| UX-05 | Tracking reminder notification at user's usual departure time | D-09/D-10/D-11/D-12: existing schema fields, `showTimePicker`, `zonedSchedule` with conditional `DateTimeComponents`. |
</phase_requirements>

---

## Summary

Phase 7 wires three independent capabilities into a single Settings screen. The dark mode implementation is a straightforward Riverpod reactive wiring: `UserPreferencesDao` gains a `watch()` method returning `Stream<UserPreferencesValue>`, a `StreamProvider<UserPreferencesValue>` wraps it, and `TraevyApp.build()` maps the stream's `darkMode` string to `ThemeMode` for `MaterialApp`. The existing `lightTheme` / `darkTheme` definitions in `lib/config/theme.dart` require no changes.

The two notification types share the same scheduling mechanism — `flutter_local_notifications` `zonedSchedule` with a `TZDateTime` anchor and `DateTimeComponents` repeat — but have different channel IDs (D-14) and different scheduling conditions. The `timezone` package (version 0.11.0) is already a transitive dependency; it requires one-time initialization (`tz.initializeTimeZones()`) before `zonedSchedule` is called. The weekly notification requires `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM` in `AndroidManifest.xml`. Since the app targets API 34 (minSdk 34), `USE_EXACT_ALARM` is appropriate (no user permission prompt; subject to Play Store review). The reminder needs the same manifest entry.

The schema migration is the most procedurally complex part: `schemaVersion` bumps from 1 to 2, a new JSON snapshot must be dumped to `drift_schemas/drift_schema_v2.json`, and a second version file (`test/generated_migrations/schema_v2.dart`) must be generated before the migration test can verify the upgrade path. The existing `schema_v1.dart` and `GeneratedHelper` in `test/generated_migrations/schema.dart` are the model for what v2 requires.

**Primary recommendation:** Implement as three sequential sub-problems — (1) schema migration + DAO extension, (2) Settings screen + dark mode wiring, (3) notification service + scheduling — in that order, because (2) and (3) both depend on the new `weeklyNotificationEnabled` field added in (1).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dark mode persistence | Database (Drift) | — | `darkMode` column in `user_preferences`; DAO reads/writes it |
| Dark mode reactivity | Frontend (Riverpod) | — | `StreamProvider` bridges DAO stream to `MaterialApp.themeMode` |
| Settings screen UI | Browser / UI layer | — | Feature screen, reads from Riverpod, writes to DAO |
| Notification scheduling | App startup (main.dart) | Settings screen | Schedule on start; reschedule on preference change |
| Notification channel registration | App startup (main.dart) | — | Initialize once before `runApp`, same as tracking channel |
| Weekly summary content | Frontend (Riverpod) | — | Reads `statsSummaryProvider` at schedule time for body text |
| Schema migration | Database (Drift) | — | `schemaVersion` bump, `m.addColumn`, snapshot dump |

---

## Standard Stack

### Core (already in pubspec.yaml)

| Library | Version | Purpose | Confidence |
|---------|---------|---------|------------|
| flutter_local_notifications | 21.0.0 | Scheduled notifications (zonedSchedule) | HIGH — confirmed in pubspec.lock |
| timezone | 0.11.0 | TZDateTime for zonedSchedule | HIGH — confirmed in pubspec.lock (transitive) |
| flutter_riverpod | ^3.3.1 | StreamProvider for theme reactivity | HIGH — confirmed in pubspec.yaml |
| drift / drift_flutter | ^2.32.1 | Schema migration, DAO watch() stream | HIGH — confirmed in pubspec.yaml |
| intl | ^0.20.2 | `DateFormat.jm()` for time picker display | HIGH — confirmed in pubspec.yaml |

**No new packages required.** `timezone` is already a transitive dependency of `flutter_local_notifications`. It must be added to pubspec.yaml as a direct dependency to allow `import 'package:timezone/timezone.dart' as tz'` in app code.

```bash
flutter pub add timezone
```

[VERIFIED: pubspec.lock — timezone 0.11.0 is already resolved as transitive]

### New Direct Dependency

| Library | Version | Purpose | Action |
|---------|---------|---------|--------|
| timezone | ^0.11.0 | `tz.initializeTimeZones()`, `tz.TZDateTime`, `tz.local` | `flutter pub add timezone` |

---

## Architecture Patterns

### System Architecture Diagram

```
[app start: main.dart]
        │
        ├─→ TrackingNotificationService.initialize()
        │         └─ registers tracking channel (existing)
        │
        ├─→ SchedulingService.initialize()  [NEW]
        │         ├─ registers weekly summary channel
        │         ├─ registers reminder channel
        │         ├─ reads UserPreferencesDao.getOrDefault()
        │         ├─ if weeklyEnabled → scheduleWeeklySummary()
        │         └─ if reminderEnabled + reminderTime set → scheduleReminder()
        │
        └─→ runApp(ProviderScope(TraevyApp))
                  │
                  └─ TraevyApp (ConsumerWidget)
                            │
                            ├─ ref.watch(userPreferenceProvider)  [NEW StreamProvider]
                            │       └─ UserPreferencesDao.watch()  [NEW]
                            │
                            └─ MaterialApp(themeMode: _toThemeMode(prefs.darkMode))

[DashboardScreen AppBar]
        └─→ IconButton(Icons.settings) → Navigator.pushNamed(kRouteSettings)

[SettingsScreen]
        ├─ Appearance section
        │     └─ RadioListTile × 3 → dao.upsert(prefs.copyWith(darkMode: value))
        │           └─ themeMode update propagates via StreamProvider to MaterialApp
        │
        └─ Notifications section
              ├─ Weekly summary SwitchListTile
              │     └─ dao.upsert() → reschedule or cancel weekly notification
              ├─ Reminder SwitchListTile
              ├─ Reminder time ListTile → showTimePicker → dao.upsert()
              └─ Weekend toggle SwitchListTile → dao.upsert() → reschedule reminder
```

### Recommended Project Structure (new files this phase)

```
lib/
├── config/
│   └── constants.dart          # ADD: kDarkModeLight, kDarkModeDark,
│                               #      kWeeklySummaryChannelId, kReminderChannelId,
│                               #      kWeeklySummaryNotificationId, kReminderNotificationId,
│                               #      kWeeklySummaryNotificationTitle, kWeeklySummaryNotificationBody,
│                               #      kReminderNotificationTitle, kReminderNotificationBody,
│                               #      kRouteSettings
├── config/
│   └── routes.dart             # ADD: kRouteSettings constant + route entry
├── database/
│   ├── tables/
│   │   └── user_preferences_table.dart    # ADD: weeklyNotificationEnabled column
│   ├── daos/
│   │   └── user_preferences_dao.dart      # ADD: watch() method; ADD weeklyNotificationEnabled
│   │                                      #      to UserPreferencesValue; bump upsert()
│   └── database.dart                      # BUMP: schemaVersion 1 → 2; ADD migration step
├── features/
│   └── settings/
│       ├── screens/
│       │   └── settings_screen.dart       # NEW
│       └── providers/
│           └── settings_providers.dart    # NEW (or in database/providers.dart)
├── notifications/
│   └── notification_service.dart          # NEW (separate from TrackingNotificationService)
├── app.dart                               # MODIFY: dynamic themeMode via userPreferenceProvider
└── main.dart                              # MODIFY: initialize new notification channels + schedule
```

### Pattern 1: Drift watch() on single-row table

The `UserPreferencesDao` currently has `getOrDefault()` (Future) and `upsert()`. It needs a reactive `watch()` returning `Stream<UserPreferencesValue>`:

```dart
// Source: lib/database/daos/trips_dao.dart (existing watch pattern)
Stream<UserPreferencesValue> watch() {
  return (select(userPreferences)
        ..where((p) => p.id.equals(_kUserPreferencesId)))
      .watchSingleOrNull()
      .map((row) => row == null
          ? const UserPreferencesValue.defaults()
          : UserPreferencesValue(
              userId: row.userId,
              darkMode: row.darkMode,
              morningCutoffHour: row.morningCutoffHour,
              eveningCutoffHour: row.eveningCutoffHour,
              reminderEnabled: row.reminderEnabled,
              reminderTime: row.reminderTime,
              weekendReminder: row.weekendReminder,
              weeklyNotificationEnabled: row.weeklyNotificationEnabled,
            ));
}
```

Key: `watchSingleOrNull()` (not `watchSingle()`) — returns null stream events when the row is absent, matching the `getOrDefault()` contract. Map null → defaults.
[VERIFIED: drift watchAllSummaries pattern in trips_dao.dart]

### Pattern 2: StreamProvider for user preferences

```dart
// In lib/database/providers.dart or lib/features/settings/providers/settings_providers.dart
// Source: history_providers.dart existing StreamProvider pattern
final StreamProvider<UserPreferencesValue> userPreferenceProvider =
    StreamProvider<UserPreferencesValue>(
  (ref) => ref.watch(userPreferencesDaoProvider).watch(),
  name: 'userPreferenceProvider',
);
```

Manual provider (no `@riverpod`) per the analyzer-version constraint documented in `lib/database/providers.dart`.
[VERIFIED: history_providers.dart and database/providers.dart patterns]

### Pattern 3: Dynamic themeMode in TraevyApp

Current `app.dart` has hardcoded `themeMode: ThemeMode.system`. Phase 7 converts:

```dart
// Source: app.dart existing ConsumerWidget build() — ref.watch already in use
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.watch(directionBackfillProvider);
  // NEW: watch user preferences for dynamic theme
  final themeMode = ref.watch(userPreferenceProvider).when(
    data: (prefs) => _toThemeMode(prefs.darkMode),
    loading: () => ThemeMode.system,   // safe fallback while stream initializes
    error: (_, __) => ThemeMode.system,
  );

  return MaterialApp(
    title: 'Traevy',
    theme: lightTheme,
    darkTheme: darkTheme,
    themeMode: themeMode,
    routes: kAppRoutes,
    home: const DashboardScreen(),
  );
}

ThemeMode _toThemeMode(String darkMode) {
  switch (darkMode) {
    case kDarkModeLight:
      return ThemeMode.light;
    case kDarkModeDark:
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}
```

[VERIFIED: app.dart existing structure — ConsumerWidget, existing ref.watch pattern]

### Pattern 4: Drift schema migration (v1 → v2)

The existing pattern at `database.dart` uses `onUpgrade` with `from/to` guards. The established codebase uses the simple `if (from < N)` pattern (not `stepByStep`), matching what the existing `onUpgrade` comment documents:

```dart
// Source: drift migration docs + existing database.dart pattern
@override
int get schemaVersion => 2;  // was 1

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async {
    await m.createAll();
  },
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      // D-13: add weeklyNotificationEnabled column to user_preferences
      await m.addColumn(
        userPreferences,
        userPreferences.weeklyNotificationEnabled,
      );
    }
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

**Migration test ceremony** (required — existing migration scaffold in `test/unit/database/migration_scaffold_test.dart` verifies v1 but will need v2):

```bash
# Step 1: Dump the v2 schema snapshot AFTER bumping schemaVersion + adding column
dart run drift_dev schema dump lib/database/database.dart drift_schemas/drift_schema_v2.json

# Step 2: Regenerate test migration helpers
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/

# Step 3: Run build_runner to regenerate .g.dart files
dart run build_runner build --delete-conflicting-outputs
```

[CITED: drift.simonbinder.eu/migrations + drift.simonbinder.eu/migrations/tests]

### Pattern 5: zonedSchedule for weekly Sunday 6pm

```dart
// Source: Context7 flutter_local_notifications /maikub/flutter_local_notifications
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Initialize ONCE before runApp (in main.dart)
tz.initializeTimeZones();

// In notification service — schedule weekly Sunday 6pm
Future<void> scheduleWeeklySummary({
  required String title,
  required String body,
}) async {
  await _plugin.cancel(id: kWeeklySummaryNotificationId);
  await _plugin.zonedSchedule(
    id: kWeeklySummaryNotificationId,
    title: title,
    body: body,
    scheduledDate: _nextSunday6pm(),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        kWeeklySummaryChannelId,
        kWeeklySummaryChannelName,
        channelDescription: kWeeklySummaryChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

tz.TZDateTime _nextSunday6pm() {
  final now = tz.TZDateTime.now(tz.local);
  // Sunday = DateTime.sunday = 7
  var candidate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18);
  while (candidate.weekday != DateTime.sunday || candidate.isBefore(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}
```

[CITED: Context7 /maikub/flutter_local_notifications — Schedule weekly recurring notification]

### Pattern 6: zonedSchedule for daily/weekday reminder

```dart
// Daily (weekendReminder = true) — DateTimeComponents.time repeats every day
// Weekday-only (weekendReminder = false) — schedule Mon–Fri separately
//   OR use a simpler approach: always schedule daily with DateTimeComponents.time
//   and cancel on Sat/Sun at runtime. But the cleaner approach for weekday-only:
//   schedule the same notification 5 times with DateTimeComponents.dayOfWeekAndTime.

// Simpler approach (recommended): schedule once with DateTimeComponents.time (daily)
// and let the weekendReminder flag control behavior by rescheduling when toggled.
// If weekendReminder = false, schedule with DateTimeComponents.dayOfWeekAndTime for
// each weekday (Monday through Friday), using IDs kReminderNotificationId + 0..4.

Future<void> scheduleReminder({
  required String hhMm,
  required bool includeWeekends,
}) async {
  // Cancel all reminder slots first
  for (var i = 0; i < 7; i++) {
    await _plugin.cancel(id: kReminderNotificationId + i);
  }

  final parts = hhMm.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  if (includeWeekends) {
    // Single daily reminder — fires every day
    await _plugin.zonedSchedule(
      id: kReminderNotificationId,
      title: kReminderNotificationTitle,
      body: kReminderNotificationBody,
      scheduledDate: _nextTimeToday(hour, minute),
      notificationDetails: _reminderDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } else {
    // Mon–Fri only: schedule 5 separate notifications
    const weekdays = [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ];
    for (var i = 0; i < weekdays.length; i++) {
      await _plugin.zonedSchedule(
        id: kReminderNotificationId + i,
        title: kReminderNotificationTitle,
        body: kReminderNotificationBody,
        scheduledDate: _nextWeekday(weekdays[i], hour, minute),
        notificationDetails: _reminderDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }
}
```

[CITED: Context7 /maikub/flutter_local_notifications — Schedule Notification with Timezone]

### Pattern 7: Notification channel creation

Two new channels follow the same `_createChannel()` pattern in `TrackingNotificationService`:

```dart
// Source: lib/features/tracking/services/tracking_notification_service.dart
const AndroidNotificationChannel weeklyChannel = AndroidNotificationChannel(
  kWeeklySummaryChannelId,
  kWeeklySummaryChannelName,
  description: kWeeklySummaryChannelDescription,
  importance: Importance.defaultImportance,
);
const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
  kReminderChannelId,
  kReminderChannelName,
  description: kReminderChannelDescription,
  importance: Importance.defaultImportance,
);
```

Both registered via `android?.createNotificationChannel(channel)`.
[VERIFIED: tracking_notification_service.dart `_createChannel()` implementation]

### Anti-Patterns to Avoid

- **Reusing kTrackingNotificationChannelId for new channels:** The D-14 unification contract is explicit — that channel/ID pair is shared with `flutter_background_service`. New notifications on the same channel appear as `ongoing` service notifications (wrong behavior).
- **Calling `tz.initializeTimeZones()` inside the notification service:** Must be called in `main.dart` before `runApp`, not inside a service class. Zone initialization is global and synchronous.
- **Not canceling before rescheduling:** `zonedSchedule` with `matchDateTimeComponents` creates a persistent Android alarm. Toggling off without canceling leaves a stale alarm running.
- **Reading statsSummaryProvider at schedule time from main.dart:** `statsSummaryProvider` is a Riverpod `Provider` — it cannot be read outside a widget/provider context. The weekly notification body must be fetched via the DAO directly at schedule time (not through Riverpod) OR the notification body can be computed lazily when the alarm fires via an `onDidReceiveNotificationResponse` handler. Simplest approach: compute body at settings save time using a direct DAO query, store in the scheduled notification payload.
- **`watchSingle()` instead of `watchSingleOrNull()` on user_preferences:** The row is absent on first launch. `watchSingle()` emits an error for missing rows; `watchSingleOrNull()` emits null which maps to defaults.
- **Forgetting `kDarkModeLight` and `kDarkModeDark` constants:** Only `kDarkModeSystem = 'system'` exists in `constants.dart`. The `'light'` and `'dark'` string literals are used in `user_preferences_dao_test.dart` but not yet as named constants. These must be added to `constants.dart` before `settings_screen.dart` can reference them.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Recurring weekly alarm | Custom timer / WorkManager | `zonedSchedule` + `DateTimeComponents.dayOfWeekAndTime` | Android alarm manager handles wake-from-idle; WorkManager has complex Kotlin setup |
| Time zone awareness for scheduled notifications | Manual UTC offset math | `tz.TZDateTime` + `tz.local` from `timezone` package | DST transitions are subtle; the package handles them |
| "Next Sunday" calculation | Complex DateTime arithmetic | Simple `while (candidate.weekday != DateTime.sunday)` loop on `TZDateTime` | TZDateTime.weekday is reliable; manual UTC math drifts |
| Drift reactive stream | Polling timer | `watchSingleOrNull().map(...)` | Built-in Drift reactive stream; no polling needed |
| Schema migration test | Manual SQL assertions | `drift_dev schema generate` + `SchemaVerifier.migrateAndValidate()` | SchemaVerifier validates the actual DDL diff automatically |

---

## Common Pitfalls

### Pitfall 1: Missing `tz.initializeTimeZones()` before `zonedSchedule`

**What goes wrong:** `zonedSchedule` throws `LocationNotFoundException` or silently falls back to UTC. Scheduled times are wrong for non-UTC device timezones.
**Why it happens:** The `timezone` package requires a one-time call to load timezone data from its bundled asset before any `TZDateTime` is constructed.
**How to avoid:** Call `tz.initializeTimeZones()` in `main()` before `runApp`, right after `WidgetsFlutterBinding.ensureInitialized()`.
**Warning signs:** Notifications fire at unexpected times; `tz.local` is `UTC` on an Android device set to a local timezone.
[CITED: Context7 flutter_local_notifications — Schedule Notifications with Timezone]

### Pitfall 2: Missing `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` in AndroidManifest

**What goes wrong:** `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle` silently fails on Android 12+ (API 31+). The plugin logs an error and recurring notifications are never scheduled.
**Why it happens:** Android 12+ restricts exact alarms by default. Apps must declare intent.
**How to avoid:** Add `<uses-permission android:name="android.permission.USE_EXACT_ALARM" />` to `AndroidManifest.xml`. This app targets API 34 (minSdk 34), so `USE_EXACT_ALARM` is appropriate — it does NOT require user permission prompt but is subject to Play Store review. `SCHEDULE_EXACT_ALARM` would require a runtime permission request.
**Warning signs:** No notification appears on device at scheduled time; no crash; debug log shows "Exact alarm permission not granted".
[CITED: Context7 flutter_local_notifications README — AndroidManifest.xml setup / Exact timings; app targets API 34 confirmed from STATE.md and existing AndroidManifest]

### Pitfall 3: Drift migration without schema snapshot dump → migration test fails

**What goes wrong:** `migration_scaffold_test.dart` runs `SchemaVerifier.migrateAndValidate(db, 2)` but `GeneratedHelper` only knows v1 — compile error.
**Why it happens:** The generated `schema.dart` and `schema_v2.dart` files must be regenerated after bumping `schemaVersion`. The test infrastructure in `test/generated_migrations/` mirrors the schema at each version.
**How to avoid:** After bumping `schemaVersion` to 2 and adding the column to the table definition, run in order:
  1. `dart run drift_dev schema dump lib/database/database.dart drift_schemas/drift_schema_v2.json`
  2. `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`
  3. `dart run build_runner build --delete-conflicting-outputs`
**Warning signs:** `GeneratedHelper.databaseForVersion(db, 2)` throws `MissingSchemaException`.
[CITED: drift.simonbinder.eu/migrations/tests; VERIFIED: existing drift_schemas/drift_schema_v1.json and test/generated_migrations/ structure]

### Pitfall 4: `UserPreferencesValue.defaults()` not updated for new field

**What goes wrong:** `getOrDefault()` constructs `UserPreferencesValue.defaults()` when the row is absent (first launch). If `weeklyNotificationEnabled` is not added to the `defaults()` constructor, it defaults to whatever Dart assigns (null for non-nullable bool → compile error, or wrong default).
**Why it happens:** `UserPreferencesValue` has a `const UserPreferencesValue.defaults()` named constructor. Every new field must be explicitly set there.
**How to avoid:** When adding `weeklyNotificationEnabled` to `UserPreferencesValue`, add it to the required fields list and set `weeklyNotificationEnabled = false` in `defaults()`.
[VERIFIED: user_preferences_dao.dart — `const UserPreferencesValue.defaults()` pattern]

### Pitfall 5: `kDarkModeLight` and `kDarkModeDark` constants not yet defined

**What goes wrong:** `settings_screen.dart` cannot reference `kDarkModeLight` or `kDarkModeDark` because only `kDarkModeSystem = 'system'` exists in `constants.dart`. The `user_preferences_dao_test.dart` uses `'dark'` and `'light'` as raw string literals.
**Why it happens:** These constants were deferred — they were noted in `01-CONTEXT.md` (D-04) but only `kDarkModeSystem` was added.
**How to avoid:** Add `kDarkModeLight = 'light'` and `kDarkModeDark = 'dark'` to `constants.dart` in the first task of this phase.
[VERIFIED: constants.dart grep — only `kDarkModeSystem` present; user_preferences_dao_test.dart uses string literals `'dark'` and `'light'`]

### Pitfall 6: Reminder weekday-only scheduling requires 5 notification IDs

**What goes wrong:** Attempting to schedule Mon–Fri reminder with a single notification ID using `DateTimeComponents.dayOfWeekAndTime` means the "next occurrence" is always one specific weekday. Scheduling Monday-only at ID 2000 and then scheduling Friday-only at the same ID 2000 replaces the Monday alarm.
**Why it happens:** Android's alarm manager keys alarms by notification ID. Each `dayOfWeekAndTime` alarm fires only on its specific weekday.
**How to avoid:** Allocate a block of 5 IDs (e.g., `kReminderNotificationId` through `kReminderNotificationId + 4`) for Mon–Fri. When `weekendReminder = true`, use a single ID with `DateTimeComponents.time`. Cancel the entire block on disable or toggle.
[ASSUMED — based on Android alarm manager semantics and flutter_local_notifications behavior]

### Pitfall 7: `statsSummaryProvider` not readable at notification schedule time

**What goes wrong:** Calling `ref.read(statsSummaryProvider)` in `main()` before providers are initialized, or in a service class that has no Riverpod ref, causes `ProviderNotFoundException`.
**Why it happens:** `statsSummaryProvider` is a Riverpod `Provider` — it requires a `ProviderContainer` or `WidgetRef` context.
**How to avoid:** The weekly notification body must be built either: (a) by directly querying the DAO from the notification service (no Riverpod needed), or (b) by reading `statsSummaryProvider` from the settings screen when the user enables the toggle, then passing the computed string to the service. Option (a) is simpler and keeps the notification service self-contained — compute `weekTotalSeconds` and `weekStuckSeconds` via a direct `db.tripsDao.watchAllSummaries()` single read.
[ASSUMED — based on Riverpod provider lifecycle constraints]

---

## Code Examples

### Verified Pattern: Initialize timezone + schedule in main.dart

```dart
// Source: Context7 /maikub/flutter_local_notifications + existing main.dart pattern
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();                        // NEW: before any TZDateTime use
  await TrackingNotificationService().initialize();
  await SchedulingService().initialize();          // NEW: registers channels + schedules
  await configureBackgroundService();
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapTiles').manage.create(maxLength: 2000);
  runApp(const ProviderScope(child: TraevyApp()));
}
```

### Verified Pattern: Drift onUpgrade migration with addColumn

```dart
// Source: drift.simonbinder.eu/migrations
onUpgrade: (m, from, to) async {
  if (from < 2) {
    await m.addColumn(
      userPreferences,
      userPreferences.weeklyNotificationEnabled,
    );
  }
},
```

### Verified Pattern: cancel() then zonedSchedule() to reschedule

```dart
// Source: Context7 /maikub/flutter_local_notifications — cancel + reschedule
await _plugin.cancel(id: kWeeklySummaryNotificationId);
// then call zonedSchedule again with updated parameters
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual exact alarm permission (SCHEDULE_EXACT_ALARM) | `USE_EXACT_ALARM` for apps targeting API 33+ | Android 12 (API 31) | No user permission prompt; Play Store may audit use |
| Polling-based theme change (require restart) | `MaterialApp.themeMode` dynamic via StreamProvider | Flutter 2+ | Instant theme change without restart |
| Per-step migration helper (stepByStep codegen) | Simple `if (from < N)` guard in `onUpgrade` | Drift 2.x | Both are valid; this codebase uses the simpler `if` guard pattern (existing `onUpgrade` comment) |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Weekday-only reminder requires 5 separate notification IDs (Mon–Fri), one per day | Pitfall 6 / Pattern 6 | Could use a different approach (e.g., cancel Sat/Sun at runtime); medium risk — test on device |
| A2 | `statsSummaryProvider` cannot be read from `main()` directly; must use direct DAO query for weekly notification body | Pitfall 7 / Pattern 5 | Could use a standalone `ProviderContainer` in `main()` — low risk either way; DAO direct approach is simpler |
| A3 | `USE_EXACT_ALARM` (vs `SCHEDULE_EXACT_ALARM`) is the correct permission for an app targeting API 34 | Pitfall 2 | App Store review policy may restrict `USE_EXACT_ALARM`; if rejected, `SCHEDULE_EXACT_ALARM` + runtime request needed |

---

## Open Questions

1. **Weekly notification body: live data vs fixed text**
   - What we know: `statsSummaryProvider` computes `weekTotalSeconds` and `weekStuckSeconds` from Drift. `formatDuration()` is available.
   - What's unclear: The notification body is composed at schedule time (app start / settings toggle). The body becomes stale as trips accumulate during the week. The notification fires Sunday 6pm with Monday-morning data.
   - Recommendation: Accept staleness — schedule with best-effort data at enable time. This is standard behavior for summary notifications. The user sees "approximately correct" totals. If D-06 staleness is unacceptable, the notification body must be dynamically generated at fire time (requires `onDidReceiveNotificationResponse` or a background task — out of scope per D-08 simplicity).

2. **`SchedulingService` vs extending `TrackingNotificationService`**
   - What we know: D-14 says "initialize new channels alongside the tracking channel" with no restriction on class structure.
   - What's unclear: CONTEXT.md leaves this as Claude's discretion.
   - Recommendation: Create a new `lib/notifications/notification_service.dart` (`NotificationService` class) for the two Phase 7 channels. Reasons: (1) `TrackingNotificationService` has a complex D-14 unification comment that must not be disturbed; (2) the new service has different responsibilities (scheduled alarms vs. ongoing foreground); (3) CLAUDE.md mandates single-concern modules.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| flutter_local_notifications | Scheduled notifications | Yes | 21.0.0 | — |
| timezone (transitive) | zonedSchedule TZDateTime | Yes (transitive) | 0.11.0 | Promote to direct dep |
| drift_dev | Schema dump + migration generation | Yes | ^2.32.1 | — |
| Android device (API 34) | Exact alarm verification | — | — | Emulator (unreliable for GPS; ok for notifications) |

**Missing dependencies with no fallback:** None.

**Action required:** Add `timezone` as a direct dependency in `pubspec.yaml` (`flutter pub add timezone`) so it can be imported explicitly in app code.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter 3.41.6) |
| Config file | None — standard Flutter test discovery |
| Quick run command | `flutter test test/unit/ -x slow` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-02 | `_toThemeMode('dark')` returns `ThemeMode.dark` | unit | `flutter test test/unit/config/constants_test.dart -x slow` | ✅ |
| UX-02 | `userPreferenceProvider` emits dark mode change after upsert | unit | `flutter test test/unit/database/user_preferences_dao_test.dart -x slow` | ✅ (extend) |
| UX-02 | Settings screen renders 3 RadioListTile rows | widget | `flutter test test/widget/features/settings/settings_screen_test.dart` | ❌ Wave 0 |
| UX-04 | Schema migration v1 → v2 adds `weekly_notification_enabled` | unit | `flutter test test/unit/database/migration_scaffold_test.dart -x slow` | ✅ (extend) |
| UX-04 | `UserPreferencesValue.defaults()` sets `weeklyNotificationEnabled = false` | unit | `flutter test test/unit/database/user_preferences_dao_test.dart -x slow` | ✅ (extend) |
| UX-05 | Reminder scheduling cancels + reschedules on preference change | unit | Manual / plugin test — `flutter_local_notifications` requires platform channels | ❌ manual-only |

**Manual-only justification (UX-05 scheduling):** `flutter_local_notifications` uses platform channels that are unavailable in widget test isolates (`MissingPluginException`). Scheduling behavior must be verified on a real Android device.

### Wave 0 Gaps

- [ ] `test/widget/features/settings/settings_screen_test.dart` — covers UX-02 RadioListTile rendering, gear icon navigation from dashboard, notification section visibility
- [ ] No new framework install required

### Sampling Rate

- **Per task commit:** `flutter test test/unit/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | Yes (time picker) | `showTimePicker` returns validated `TimeOfDay`; parse `HH:mm` before storing |
| V6 Cryptography | No | — |

**Input validation note:** The time picker result from `showTimePicker` is a `TimeOfDay` — already validated by Flutter. Converting to `HH:mm` string via `TimeOfDay.format()` or manual zero-padding is safe. No additional validation needed beyond null check.

---

## Project Constraints (from CLAUDE.md)

- No hardcoded strings — all new title/body/channel text goes in `constants.dart`
- No `setState` / `ChangeNotifier` — all state through Riverpod `StreamProvider` / `Provider`
- Widgets under 100 lines — `SettingsScreen` will exceed 100 lines given two sections; extract appearance section and notification section as sub-widgets
- Sealed classes / enums for finite state — `ThemeMode` (Flutter built-in enum) covers dark mode state; no custom sealed class needed
- `dart format` + `flutter analyze` after every file change
- Feature-first folder: `lib/features/settings/screens/`, `lib/features/settings/providers/`
- Public doc comments on all public members (very_good_analysis `public_member_api_docs` is set to `warning` in `analysis_options.yaml`, not `ignore` — add `///` doc comments to all new public APIs)
- Manual Riverpod providers (no `@riverpod` annotation) — analyzer version constraint still applies in Phase 7

---

## Sources

### Primary (HIGH confidence)
- Context7 `/maikub/flutter_local_notifications` — `zonedSchedule`, `DateTimeComponents`, `cancel()`, channel creation, Android permissions
- Context7 `/websites/drift_simonbinder_eu` — `MigrationStrategy.onUpgrade`, `m.addColumn`, schema dump, `SchemaVerifier.migrateAndValidate`
- Codebase: `lib/features/tracking/services/tracking_notification_service.dart` — verified channel creation pattern, plugin singleton, D-14 contract
- Codebase: `lib/database/database.dart` — verified current `schemaVersion = 1`, existing `onUpgrade` comment template
- Codebase: `lib/database/daos/user_preferences_dao.dart` — verified `UserPreferencesValue`, `defaults()`, `upsert()` patterns
- Codebase: `lib/database/providers.dart` — verified manual Riverpod provider pattern
- Codebase: `lib/app.dart` — verified `ConsumerWidget` + `ref.watch` in `build()`, hardcoded `ThemeMode.system`
- Codebase: `lib/config/constants.dart` — verified only `kDarkModeSystem` exists; `kDarkModeLight`/`kDarkModeDark` absent
- Codebase: `pubspec.yaml` + `pubspec.lock` — verified `flutter_local_notifications 21.0.0`, `timezone 0.11.0` transitive
- Codebase: `drift_schemas/drift_schema_v1.json` — verified v1 schema; `user_preferences` columns confirmed
- Codebase: `android/app/src/main/AndroidManifest.xml` — verified existing permissions; `USE_EXACT_ALARM` not yet declared

### Secondary (MEDIUM confidence)
- Context7 `/maikub/flutter_local_notifications` README — `USE_EXACT_ALARM` vs `SCHEDULE_EXACT_ALARM` for API 33/34

### Tertiary (LOW confidence — marked [ASSUMED])
- A1: 5 notification IDs for weekday-only reminder scheduling
- A2: DAO direct query preferred over standalone ProviderContainer in main.dart
- A3: `USE_EXACT_ALARM` Play Store review policy

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already in pubspec.lock; verified versions
- Architecture: HIGH — all patterns verified from existing codebase files
- Drift migration: HIGH — cited from drift docs + verified existing test scaffold
- Notification scheduling: HIGH — cited from Context7 flutter_local_notifications docs
- Reminder weekday ID allocation (A1): LOW — assumed from Android alarm semantics

**Research date:** 2026-04-28
**Valid until:** 2026-05-28 (flutter_local_notifications API is stable)
