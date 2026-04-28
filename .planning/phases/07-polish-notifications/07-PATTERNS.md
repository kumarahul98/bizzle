# Phase 7: Polish & Notifications - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 13 new/modified files
**Analogs found:** 13 / 13

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/features/settings/screens/settings_screen.dart` | screen (widget) | request-response | `lib/features/stats/screens/stats_screen.dart` | role-match |
| `lib/features/settings/providers/settings_providers.dart` | provider | CRUD stream | `lib/features/trips/providers/history_providers.dart` | exact |
| `lib/notifications/notification_service.dart` | service | event-driven | `lib/features/tracking/services/tracking_notification_service.dart` | role-match |
| `lib/config/constants.dart` | config | — | `lib/config/constants.dart` (self) | self-modify |
| `lib/config/routes.dart` | config | — | `lib/config/routes.dart` (self) | self-modify |
| `lib/features/dashboard/screens/dashboard_screen.dart` | screen (widget) | request-response | `lib/features/dashboard/screens/dashboard_screen.dart` (self) | self-modify |
| `lib/app.dart` | root widget | request-response | `lib/app.dart` (self) | self-modify |
| `lib/database/database.dart` | database config | CRUD | `lib/database/database.dart` (self) | self-modify |
| `lib/database/tables/user_preferences_table.dart` | model/table | CRUD | `lib/database/tables/user_preferences_table.dart` (self) | self-modify |
| `lib/database/daos/user_preferences_dao.dart` | DAO | CRUD stream | `lib/database/daos/user_preferences_dao.dart` (self) | self-modify |
| `lib/main.dart` | entry point | event-driven | `lib/main.dart` (self) | self-modify |
| `android/app/src/main/AndroidManifest.xml` | config | — | `android/app/src/main/AndroidManifest.xml` (self) | self-modify |
| `test/widget/features/settings/settings_screen_test.dart` | test | request-response | `test/widget/features/dashboard/dashboard_screen_test.dart` | exact |

---

## Pattern Assignments

### `lib/features/settings/screens/settings_screen.dart` (screen, request-response)

**Analog:** `lib/features/stats/screens/stats_screen.dart`

**Imports pattern** (stats_screen.dart lines 1–9):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
// settings_screen.dart will replace with:
// import 'package:traevy/features/settings/providers/settings_providers.dart';
// import 'package:traevy/database/daos/user_preferences_dao.dart';
// import 'package:traevy/database/providers.dart';
// import 'package:intl/intl.dart';   // for time picker formatting
```

**ConsumerWidget scaffold pattern** (stats_screen.dart lines 30–79):
```dart
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(statsSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(kStatsAppBarTitle)),
      body: asyncStats.when(
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _kHorizontalPadding,
            _kHorizontalPadding,
            _kHorizontalPadding,
            _kBottomSafeArea,
          ),
          child: Column(
            children: <Widget>[/* ... */],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(child: Text(kStatsErrorMessage)),
      ),
    );
  }
}
```

**Key adaptations for SettingsScreen:**
- Replace `asyncStats.when(...)` with `asyncPrefs.when(data: (prefs) => _buildBody(context, ref, prefs), ...)` — same `AsyncValue.when` tristate pattern.
- SettingsScreen body will NOT use `SingleChildScrollView` + stat cards; instead use a `ListView` with `ListTile`/`SwitchListTile`/`RadioListTile` rows grouped under section headers.
- SettingsScreen will exceed 100 lines — per CLAUDE.md, extract `_AppearanceSection` and `_NotificationsSection` as separate `StatelessWidget` subclasses in the same `lib/features/settings/screens/` directory.
- AppBar title comes from a constant added to `constants.dart` (e.g., `kSettingsAppBarTitle`).

**Navigator.pushNamed source pattern** (dashboard_screen.dart lines 54–64):
```dart
// Pattern for the gear icon added to DashboardScreen AppBar — mirrors
// the existing history and stats buttons:
IconButton(
  icon: const Icon(Icons.settings),
  tooltip: kSettingsTooltip,   // add to constants.dart
  onPressed: () => Navigator.pushNamed(context, kRouteSettings),
),
```

**Drift upsert write pattern** (user_preferences_dao.dart lines 107–120):
```dart
// After each RadioListTile / SwitchListTile change call:
await ref.read(userPreferencesDaoProvider).upsert(
  UserPreferencesValue(
    userId: prefs.userId,
    darkMode: newDarkMode,       // changed field
    morningCutoffHour: prefs.morningCutoffHour,
    eveningCutoffHour: prefs.eveningCutoffHour,
    reminderEnabled: prefs.reminderEnabled,
    reminderTime: prefs.reminderTime,
    weekendReminder: prefs.weekendReminder,
    weeklyNotificationEnabled: prefs.weeklyNotificationEnabled,
  ),
);
```

---

### `lib/features/settings/providers/settings_providers.dart` (provider, CRUD stream)

**Analog:** `lib/features/trips/providers/history_providers.dart`

**StreamProvider declaration pattern** (history_providers.dart lines 1–16):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/providers.dart';

/// Reactive stream of all trips as summaries, newest-first.
///
/// Manual provider — no @riverpod annotation per lib/database/providers.dart
/// constraint (analyzer version conflict documented there).
final StreamProvider<List<TripSummary>> allTripSummariesProvider =
    StreamProvider<List<TripSummary>>(
      (ref) => ref.watch(tripsDaoProvider).watchAllSummaries(),
      name: 'allTripSummariesProvider',
    );
```

**Adaptation for userPreferenceProvider:**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/providers.dart';

/// Reactive stream of the user's preferences row (single row, id = 1).
///
/// Manual provider — no @riverpod annotation per lib/database/providers.dart
/// constraint (analyzer version conflict documented there).
/// Emits [UserPreferencesValue.defaults()] when no row exists (first launch).
final StreamProvider<UserPreferencesValue> userPreferenceProvider =
    StreamProvider<UserPreferencesValue>(
      (ref) => ref.watch(userPreferencesDaoProvider).watch(),
      name: 'userPreferenceProvider',
    );
```

**Important:** `userPreferencesDaoProvider` already exists in `lib/database/providers.dart` (line 60–64). The new `watch()` method must be added to `UserPreferencesDao` before this provider can compile.

**Existing DAO providers pattern** (database/providers.dart lines 59–64):
```dart
/// `UserPreferencesDao` sourced from the keepAlive'd `appDatabaseProvider`.
final Provider<UserPreferencesDao> userPreferencesDaoProvider =
    Provider<UserPreferencesDao>(
  (ref) => ref.watch(appDatabaseProvider).userPreferencesDao,
  name: 'userPreferencesDaoProvider',
);
```

---

### `lib/notifications/notification_service.dart` (service, event-driven)

**Analog:** `lib/features/tracking/services/tracking_notification_service.dart`

**Plugin injection + initialize() pattern** (tracking_notification_service.dart lines 70–96):
```dart
class TrackingNotificationService {
  TrackingNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          trackingNotificationBackgroundHandler,
    );
    await _createChannel();
  }
```

**Channel creation pattern** (tracking_notification_service.dart lines 155–168):
```dart
Future<void> _createChannel() async {
  const channel = AndroidNotificationChannel(
    kTrackingNotificationChannelId,
    kTrackingNotificationChannelName,
    description: kTrackingNotificationChannelDescription,
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(channel);
}
```

**Adaptation for NotificationService — two channels in one `_createChannels()` call:**
```dart
Future<void> _createChannels() async {
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  const weeklySummaryChannel = AndroidNotificationChannel(
    kWeeklySummaryChannelId,
    kWeeklySummaryChannelName,
    description: kWeeklySummaryChannelDescription,
    importance: Importance.defaultImportance,
  );
  const reminderChannel = AndroidNotificationChannel(
    kReminderChannelId,
    kReminderChannelName,
    description: kReminderChannelDescription,
    importance: Importance.defaultImportance,
  );
  await android?.createNotificationChannel(weeklySummaryChannel);
  await android?.createNotificationChannel(reminderChannel);
}
```

**cancel() before zonedSchedule pattern** (RESEARCH.md Pattern 5 — verified against flutter_local_notifications API):
```dart
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
```

**D-14 contract note:** Do NOT reuse `kTrackingNotificationChannelId` or `kTrackingNotificationId`. The tracking channel is pinned to `flutter_background_service`'s foreground service notification. New channels must use new IDs defined in `constants.dart`.

---

### `lib/config/constants.dart` (config, self-modify)

**Analog:** `lib/config/constants.dart` — append new phase section following the established sectioned comment pattern.

**Existing phase-section comment style** (constants.dart lines 87–88, 193–194, 243–244, 310–312):
```dart
// ---------------------------------------------------------------------------
// Phase N: [Phase Name]
// ---------------------------------------------------------------------------
```

**Existing notification constant shape** (constants.dart lines 118–161):
```dart
/// Android notification channel id for the active-commute foreground
/// notification shown while Traevy is recording a commute.
///
/// See D-14, D-15 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const String kTrackingNotificationChannelId = 'traevy_active_commute';
const String kTrackingNotificationChannelName = 'Active commute';
const String kTrackingNotificationChannelDescription =
    'Shown while Traevy is recording a commute.';
const String kTrackingNotificationTitle = 'Recording commute';
const int kTrackingNotificationId = 1001;
```

**New constants needed (Phase 7 section to append):**
- `kDarkModeLight = 'light'` and `kDarkModeDark = 'dark'` — the only two missing dark-mode string literals (confirmed by grep: `kDarkModeSystem` at line 85 is the sole existing one)
- `kRouteSettings = '/settings'` — new named route constant
- `kSettingsAppBarTitle` — settings screen AppBar title string
- `kSettingsTooltip` — tooltip for gear icon in DashboardScreen AppBar
- `kWeeklySummaryChannelId`, `kWeeklySummaryChannelName`, `kWeeklySummaryChannelDescription`
- `kWeeklySummaryNotificationId` (int, pick a value that does not collide with `kTrackingNotificationId = 1001`)
- `kWeeklySummaryNotificationTitle`, `kWeeklySummaryNotificationBody`
- `kReminderChannelId`, `kReminderChannelName`, `kReminderChannelDescription`
- `kReminderNotificationId` (int block; reserve `kReminderNotificationId` through `kReminderNotificationId + 4` for weekday slots per RESEARCH.md Pitfall 6)
- `kReminderNotificationTitle`, `kReminderNotificationBody`

**Existing constants.dart doc comment style** — every constant has a `///` doc comment referencing the decision that locked it (e.g. "See D-07 in ..."). Phase 7 constants must follow this pattern (required by `very_good_analysis public_member_api_docs`).

---

### `lib/config/routes.dart` (config, self-modify)

**Analog:** `lib/config/routes.dart` — extend the existing map.

**Existing route constant + map entry pattern** (routes.dart lines 10–37):
```dart
/// Stats screen route (Phase 5, D-02). Argument: none.
const String kRouteStats = '/stats';

final Map<String, WidgetBuilder> kAppRoutes = <String, WidgetBuilder>{
  kRouteTracking: (BuildContext context) => const TrackingScreen(),
  kRouteHistory: (BuildContext context) => const HistoryScreen(),
  kRouteStats: (BuildContext context) => const StatsScreen(),
  kRouteTripDetail: (BuildContext context) {
    final tripId = ModalRoute.of(context)!.settings.arguments! as String;
    return TripDetailScreen(tripId: tripId);
  },
};
```

**Addition:**
1. Add `const String kRouteSettings = '/settings';` constant in `constants.dart` (not here — routes.dart only references constants defined there)
2. Import `SettingsScreen` at top of routes.dart
3. Add `kRouteSettings: (BuildContext context) => const SettingsScreen(),` to `kAppRoutes`

---

### `lib/features/dashboard/screens/dashboard_screen.dart` (screen, self-modify)

**Analog:** self — existing AppBar actions pattern (lines 47–65).

**Existing 3-icon AppBar pattern** (dashboard_screen.dart lines 47–65):
```dart
appBar: AppBar(
  title: Text(DateFormat('EEE, d MMM').format(DateTime.now())),
  actions: <Widget>[
    IconButton(
      icon: const Icon(Icons.add),
      tooltip: kDashboardAddTripTooltip,
      onPressed: () => _handleAddManualTrip(context, ref),
    ),
    IconButton(
      icon: const Icon(Icons.history),
      tooltip: 'History',
      onPressed: () => Navigator.pushNamed(context, kRouteHistory),
    ),
    IconButton(
      icon: const Icon(Icons.bar_chart),
      tooltip: 'Stats',
      onPressed: () => Navigator.pushNamed(context, kRouteStats),
    ),
  ],
),
```

**Add 4th gear button as a trailing entry in the actions list:**
```dart
IconButton(
  icon: const Icon(Icons.settings),
  tooltip: kSettingsTooltip,
  onPressed: () => Navigator.pushNamed(context, kRouteSettings),
),
```

Note: the existing `tooltip: 'History'` and `tooltip: 'Stats'` strings are inline string literals — Phase 7 adds a tooltip constant for settings in `constants.dart` but need not change the existing hardcoded tooltips (that is a separate concern).

---

### `lib/app.dart` (root widget, self-modify)

**Analog:** self — current `ConsumerWidget` + `ref.watch` pattern.

**Existing ConsumerWidget + MaterialApp pattern** (app.dart lines 19–44):
```dart
class TraevyApp extends ConsumerWidget {
  const TraevyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(directionBackfillProvider);

    return MaterialApp(
      title: 'Traevy',
      theme: lightTheme,
      darkTheme: darkTheme,
      // ignore: avoid_redundant_argument_values
      themeMode: ThemeMode.system,
      routes: kAppRoutes,
      home: const DashboardScreen(),
    );
  }
}
```

**Phase 7 change — replace hardcoded `themeMode` with reactive watch:**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.watch(directionBackfillProvider);
  // NEW: watch user preferences for dynamic theme
  final themeMode = ref.watch(userPreferenceProvider).when(
    data: (prefs) => _toThemeMode(prefs.darkMode),
    loading: () => ThemeMode.system,
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

**New imports needed in app.dart:**
```dart
import 'package:traevy/features/settings/providers/settings_providers.dart';
// (kDarkModeLight, kDarkModeDark already imported via constants.dart)
```

Remove the `// ignore: avoid_redundant_argument_values` comment when `themeMode` becomes dynamic (no longer redundant).

---

### `lib/database/database.dart` (database config, self-modify)

**Analog:** self — existing `MigrationStrategy` shape.

**Existing migration pattern** (database.dart lines 39–61):
```dart
@override
int get schemaVersion => 1;

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        // D-04: Do NOT seed user_preferences here. ...
      },
      onUpgrade: (m, from, to) async {
        // No upgrades yet at schemaVersion 1. Every future schema
        // bump MUST add a branch here AND a dart run drift_dev schema
        // dump snapshot under drift_schemas/.
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
```

**Phase 7 change — bump schemaVersion and add migration branch:**
```dart
@override
int get schemaVersion => 2;  // bumped from 1

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // D-13: adds weeklyNotificationEnabled column to user_preferences
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

**Required ceremony after this change** (run in order before tests):
1. `dart run drift_dev schema dump lib/database/database.dart drift_schemas/drift_schema_v2.json`
2. `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`
3. `dart run build_runner build --delete-conflicting-outputs`

---

### `lib/database/tables/user_preferences_table.dart` (model/table, self-modify)

**Analog:** self — existing `BoolColumn` pattern.

**Existing boolean column pattern** (user_preferences_table.dart lines 41–44, 47–49):
```dart
/// True if the user has opted into the daily tracking reminder.
BoolColumn get reminderEnabled =>
    boolean().withDefault(const Constant(false))();

/// True if the reminder should also fire on Saturday and Sunday.
BoolColumn get weekendReminder =>
    boolean().withDefault(const Constant(false))();
```

**Phase 7 addition — append after `weekendReminder`:**
```dart
/// True if the user has opted into the weekly commute summary notification.
/// Default false so no notification fires until user enables it (D-07).
BoolColumn get weeklyNotificationEnabled =>
    boolean().withDefault(const Constant(false))();
```

The column uses `withDefault(const Constant(false))` matching the existing boolean column convention. This default value is what the `m.addColumn` migration uses for existing rows.

---

### `lib/database/daos/user_preferences_dao.dart` (DAO, self-modify)

**Analog:** self — `getOrDefault()` is the pattern `watch()` must mirror.

**Existing getOrDefault() query pattern** (user_preferences_dao.dart lines 85–101):
```dart
Future<UserPreferencesValue> getOrDefault() async {
  final row = await (select(userPreferences)
        ..where((p) => p.id.equals(_kUserPreferencesId)))
      .getSingleOrNull();
  if (row == null) {
    return const UserPreferencesValue.defaults();
  }
  return UserPreferencesValue(
    userId: row.userId,
    darkMode: row.darkMode,
    morningCutoffHour: row.morningCutoffHour,
    eveningCutoffHour: row.eveningCutoffHour,
    reminderEnabled: row.reminderEnabled,
    reminderTime: row.reminderTime,
    weekendReminder: row.weekendReminder,
  );
}
```

**New `watch()` method — mirror `getOrDefault()` but reactive:**
```dart
/// Reactive stream of the user's preferences. Emits
/// [UserPreferencesValue.defaults()] when the row is absent (first launch).
///
/// Uses [watchSingleOrNull] (not [watchSingle]) because the row is absent
/// until the user first changes a setting (D-04 "no seed row" contract).
/// [watchSingle] would emit an error for a missing row; [watchSingleOrNull]
/// emits null which maps cleanly to defaults.
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

**`UserPreferencesValue` additions — new required field + defaults update:**
```dart
// In the constructor parameter list — add:
required this.weeklyNotificationEnabled,

// In UserPreferencesValue.defaults() — add:
weeklyNotificationEnabled = false,

// In getOrDefault() return — add the field to the existing UserPreferencesValue constructor call:
weeklyNotificationEnabled: row.weeklyNotificationEnabled,

// In upsert() companion — add:
weeklyNotificationEnabled: Value<bool>(value.weeklyNotificationEnabled),
```

---

### `lib/main.dart` (entry point, self-modify)

**Analog:** self — existing sequential bootstrap pattern.

**Existing bootstrap pattern** (main.dart lines 30–37):
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TrackingNotificationService().initialize();
  await configureBackgroundService();
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapTiles').manage.create(maxLength: 2000);
  runApp(const ProviderScope(child: TraevyApp()));
}
```

**Phase 7 changes — add timezone init + NotificationService init + scheduling:**
```dart
import 'package:timezone/data/latest_all.dart' as tz;
// plus existing imports + new NotificationService import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();                           // MUST be before any TZDateTime use
  await TrackingNotificationService().initialize();
  await NotificationService().initialize();           // registers weekly + reminder channels
  await configureBackgroundService();
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapTiles').manage.create(maxLength: 2000);
  runApp(const ProviderScope(child: TraevyApp()));
}
```

`NotificationService.initialize()` is responsible for reading the database preferences (via a temporary `AppDatabase` instance — NOT through Riverpod which is not yet available) and scheduling any already-enabled notifications.

**Note on ordering:** `tz.initializeTimeZones()` is synchronous and must come before `NotificationService().initialize()`. It does not need `await`. The existing `TrackingNotificationService().initialize()` call is kept unchanged — the two services share the `FlutterLocalNotificationsPlugin` singleton but initialize independently (idempotent).

---

### `android/app/src/main/AndroidManifest.xml` (config, self-modify)

**Analog:** self — existing `<uses-permission>` block pattern.

**Existing permission block style** (AndroidManifest.xml lines 44–60):
```xml
<!-- Phase 2 location + foreground-service permissions (RESEARCH §4). -->
<!-- Fine-grained GPS — required for TRACK-02 GPS capture. -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- ... -->
<!-- Android 13+ runtime permission for the foreground notification (UX-03). -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

**Phase 7 addition — append after POST_NOTIFICATIONS:**
```xml
<!-- Phase 7: required for flutter_local_notifications zonedSchedule with     -->
<!-- AndroidScheduleMode.exactAllowWhileIdle on Android 12+ (API 31+).         -->
<!-- USE_EXACT_ALARM (not SCHEDULE_EXACT_ALARM) is appropriate for minSdk 34:  -->
<!-- no user permission dialog required; subject to Play Store review (D-08).  -->
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
```

Place this between the existing `POST_NOTIFICATIONS` line and the `<queries>` block, maintaining the existing comment style.

---

### `test/widget/features/settings/settings_screen_test.dart` (test, request-response)

**Analog:** `test/widget/features/dashboard/dashboard_screen_test.dart`

**File header / import pattern** (dashboard_screen_test.dart lines 1–29):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
// ...
```

**ProviderScope override + pumpWidget helper pattern** (dashboard_screen_test.dart lines 175–209):
```dart
Future<void> _pumpDashboardScreen(
  WidgetTester tester, {
  required TrackingPermissionService permissionService,
  List<TripSummary> todayTrips = const <TripSummary>[],
  TrackingNotifier Function()? trackingNotifierFactory,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allTripSummariesProvider.overrideWith(
          (ref) => Stream<List<TripSummary>>.value(todayTrips),
        ),
        statsSummaryProvider.overrideWith(
          (ref) => AsyncValue<StatsSummary>.data(_makeStatsSummary()),
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

**Adaptation for `_pumpSettingsScreen`:**
```dart
Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  UserPreferencesValue prefs = const UserPreferencesValue.defaults(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userPreferenceProvider.overrideWith(
          (ref) => Stream<UserPreferencesValue>.value(prefs),
        ),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    ),
  );
  await tester.pump();
}
```

**testWidgets assertion pattern** (dashboard_screen_test.dart lines 211–219):
```dart
void main() {
  group('DashboardScreen', () {
    testWidgets('renders DashboardScreen as app root', (tester) async {
      // ...
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
    // ...
  });
}
```

**Settings screen tests to implement (Wave 0):**
- `renders SettingsScreen` — `findsOneWidget`
- `renders 3 RadioListTile rows in Appearance section` — `findsNWidgets(3)`
- `renders weekly summary SwitchListTile` — `find.byType(SwitchListTile)`
- `renders reminder SwitchListTile` — `find.byType(SwitchListTile)`
- `hides reminder time row when reminder disabled` — `find.text(...)` returns `findsNothing`
- Navigation from DashboardScreen: pump DashboardScreen with `kAppRoutes`, tap gear icon, verify `SettingsScreen` appears (same `pumpAndSettle` pattern as the tracking navigation test at lines 357–377)

---

## Shared Patterns

### Manual Riverpod Providers (no @riverpod)
**Source:** `lib/database/providers.dart` lines 1–64
**Apply to:** `lib/features/settings/providers/settings_providers.dart`
```dart
// Manual provider shape (NOT @Riverpod annotation):
final StreamProvider<T> myProvider = StreamProvider<T>(
  (ref) => ref.watch(someDaoProvider).watchSomething(),
  name: 'myProvider',    // named for debugging
);
```
The `name:` parameter is present on every existing manual provider in this codebase. Include it on the new `userPreferenceProvider`.

### AsyncValue.when tristate
**Source:** `lib/features/stats/screens/stats_screen.dart` lines 38–78
**Apply to:** `lib/features/settings/screens/settings_screen.dart`
```dart
asyncPrefs.when(
  data: (prefs) => _buildBody(...),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (_, __) => const Center(child: Text(kSettingsErrorMessage)),
)
```
All screens watching a `StreamProvider` or `FutureProvider` use this tristate pattern. Never access `.value` directly without handling loading/error states.

### Constants Section Header Comment
**Source:** `lib/config/constants.dart` lines 87–88
**Apply to:** Phase 7 additions to `constants.dart`
```dart
// ---------------------------------------------------------------------------
// Phase 7: Polish & Notifications
// ---------------------------------------------------------------------------
```

### Doc Comments on Public Members
**Source:** All existing constant declarations in `constants.dart` (every constant has `///` block)
**Apply to:** Every new public constant, method, class, and field in Phase 7
Required by `very_good_analysis public_member_api_docs`. Format:
```dart
/// Short description. Longer description if needed.
///
/// See D-XX in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kWeeklySummaryChannelId = 'traevy_weekly_summary';
```

### Notification Plugin Singleton
**Source:** `lib/features/tracking/services/tracking_notification_service.dart` lines 70–78
**Apply to:** `lib/notifications/notification_service.dart`
```dart
// FlutterLocalNotificationsPlugin() is a singleton under the hood.
// Multiple instances across TrackingNotificationService and NotificationService
// both share the same registered channels and state.
// Constructor injection pattern allows test fakes:
NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
```

### Navigator.pushNamed Route Navigation
**Source:** `lib/features/dashboard/screens/dashboard_screen.dart` lines 57–64
**Apply to:** Gear icon in DashboardScreen AppBar, back navigation from SettingsScreen
```dart
onPressed: () => Navigator.pushNamed(context, kRouteSettings),
```

---

## No Analog Found

All files in this phase have strong analogs in the existing codebase. No new architectural patterns are required.

---

## Metadata

**Analog search scope:** `lib/`, `test/`, `android/`
**Files read:** 13 source files
**Pattern extraction date:** 2026-04-28

**Critical pitfalls captured from RESEARCH.md:**
- `tz.initializeTimeZones()` must be called in `main()` before `NotificationService().initialize()`, not inside the service class
- `watchSingleOrNull()` not `watchSingle()` — the preferences row is absent on first launch
- `kDarkModeLight` and `kDarkModeDark` do not yet exist in `constants.dart` — must be added before `settings_screen.dart` can compile
- Schema migration requires the 3-command ceremony (schema dump → generate → build_runner) before migration tests pass
- `UserPreferencesValue.defaults()` must include `weeklyNotificationEnabled = false` — omitting it is a compile error (non-nullable bool)
- `USE_EXACT_ALARM` manifest permission required for `zonedSchedule` with `exactAllowWhileIdle` on Android 12+ (API 31+)
- Weekday-only reminder requires 5 notification IDs (block `kReminderNotificationId` through `kReminderNotificationId + 4`)
