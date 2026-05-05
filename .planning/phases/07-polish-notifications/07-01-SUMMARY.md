---
phase: 07-polish-notifications
plan: 01
status: complete
wave: 1
tasks_completed: 2
tasks_total: 2
key_files:
  created:
    - drift_schemas/drift_schema_v2.json
    - test/generated_migrations/schema_v2.dart
  modified:
    - lib/config/constants.dart
    - lib/config/routes.dart
    - android/app/src/main/AndroidManifest.xml
    - pubspec.yaml
    - pubspec.lock
    - lib/database/tables/user_preferences_table.dart
    - lib/database/daos/user_preferences_dao.dart
    - lib/database/daos/user_preferences_dao.g.dart
    - lib/database/database.dart
    - lib/database/database.g.dart
    - test/unit/database/user_preferences_dao_test.dart
    - test/generated_migrations/schema.dart
    - test/generated_migrations/schema_v1.dart
---

# Plan 07-01 Summary: Phase 7 Constants + Drift Schema v2 Migration

## What Was Built

### Task 1 — Phase 7 Constants + Infrastructure
- Appended 28 Phase 7 constants to `lib/config/constants.dart`: `kDarkModeLight`, `kDarkModeDark`, all `kSettings*` labels, all notification channel/ID/content constants
- Added `kRouteSettings = '/settings'` to `lib/config/routes.dart` (route constants live here, following `kRouteStats` precedent)
- Added `USE_EXACT_ALARM` permission to `android/app/src/main/AndroidManifest.xml` — required for `flutter_local_notifications` `zonedSchedule` with `exactAllowWhileIdle` on Android 12+
- Added `timezone: ^0.11.0` as a direct dependency in `pubspec.yaml` (promoted from transitive)

### Task 2 — Drift Schema v2 Migration
- Added `weeklyNotificationEnabled` `BoolColumn` to `UserPreferences` table (`withDefault(false)`)
- Updated `UserPreferencesValue`: new `weeklyNotificationEnabled` required field; `defaults()` sets it to `false`
- Updated `UserPreferencesDao.getOrDefault()` and `upsert()` to include the new field
- Bumped `AppDatabase.schemaVersion` from 1 → 2
- Added `onUpgrade` migration: `if (from < 2) await m.addColumn(userPreferences, userPreferences.weeklyNotificationEnabled)`
- Ran `build_runner` to regenerate `.g.dart` files
- Generated `drift_schemas/drift_schema_v2.json` snapshot
- Generated `test/generated_migrations/schema_v2.dart` migration test helper
- Updated `user_preferences_dao_test.dart` to include `weeklyNotificationEnabled` in all `UserPreferencesValue` constructor calls

## Verification

- `flutter analyze lib/database/` — 0 issues
- `flutter test test/unit/database/` — 14/14 passed (including migration scaffold)
- `drift_schema_v2.json` exists ✓
- `test/generated_migrations/schema_v2.dart` exists ✓

## Self-Check: PASSED
