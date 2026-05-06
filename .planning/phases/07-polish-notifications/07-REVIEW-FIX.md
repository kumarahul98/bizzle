---
phase: 07-polish-notifications
fixed_at: 2026-05-05T00:00:00Z
review_path: .planning/phases/07-polish-notifications/07-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 07: Code Review Fix Report

**Fixed at:** 2026-05-05T00:00:00Z
**Source review:** .planning/phases/07-polish-notifications/07-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (CR-01, WR-01, WR-02, WR-03, WR-04, WR-05)
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: `int.parse` in `scheduleReminder` throws on malformed DB data

**Files modified:** `lib/notifications/notification_service.dart`
**Commit:** 2aac794
**Applied fix:** Replaced `int.parse(parts[0])` and `int.parse(parts[1])` with
`int.tryParse` plus a length guard (`parts.length != 2`) and a range validation
block (`hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 ||
minute > 59`). Either bad condition returns early instead of throwing. Added
`on Exception catch (e, s)` block in `initialize()` so a corrupt preferences row
logs via `debugPrint` and continues rather than propagating a crash to `main`.
Added `package:flutter/foundation.dart` import for `debugPrint`.

---

### WR-01: Weekly summary notification body is stale — reflects enable-time data

**Files modified:** `lib/notifications/notification_service.dart`
**Commit:** d649bea
**Applied fix:** Fixed as part of WR-05 (see below). The single canonical
scheduling path (`scheduleWeeklySummary`) is now called from `initialize()` on
every app start, which ensures the notification body is rebuilt from current DB
data each time the user opens the app. Added inline comment documenting this
behaviour.

---

### WR-02: `_toggleWeeklySummary` creates a second `AppDatabase()` instance

**Files modified:** `lib/features/settings/screens/settings_screen.dart`
**Commit:** fb8b5b7
**Applied fix:** Replaced `AppDatabase()` constructor call and its `try/finally`
close wrapper with `ref.read(appDatabaseProvider)` so the Riverpod-managed
connection is reused. Removed the now-unused `database.dart` import.

---

### WR-03: `context.mounted` guard fires before the async gap in `_pickTime`

**Files modified:** `lib/features/settings/screens/settings_screen.dart`
**Commit:** 225027e
**Applied fix:** Moved `if (!context.mounted) return;` from above
`await showTimePicker(...)` to immediately after it, where the actual async gap
occurs and the widget could have been disposed.

---

### WR-04: `_copyPrefs` cannot clear `reminderTime` to null

**Files modified:** `lib/features/settings/screens/settings_screen.dart`
**Commit:** b332624
**Applied fix:** Changed `reminderTime` parameter type from `String?` to
`Object?` with a default of `const _UnsetSentinel()`. Added private
`_UnsetSentinel` class with a `const` constructor. The assignment now uses an
`is _UnsetSentinel` type test: if the sentinel is detected the existing
`prefs.reminderTime` is kept; otherwise the passed value (including explicit
`null`) is cast to `String?` and stored. Updated doc comment to reference
`_UnsetSentinel` instead of the now-removed `_kUnset` variable.

---

### WR-05: `scheduleWeeklySummary` and `_scheduleWeeklySummaryFromDb` are identical

**Files modified:** `lib/notifications/notification_service.dart`
**Commit:** d649bea
**Applied fix:** Deleted `_scheduleWeeklySummaryFromDb` (22 lines, byte-for-byte
duplicate of the public method). Updated `initialize()` to call
`scheduleWeeklySummary(db)` directly. WR-01 and WR-05 were committed together
as a single atomic change because they share the same call-site modification in
`initialize()`.

---

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-05-05T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
