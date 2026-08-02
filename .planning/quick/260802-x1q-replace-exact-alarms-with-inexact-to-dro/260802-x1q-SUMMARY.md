---
phase: quick-260802-x1q
plan: 01
subsystem: notifications, android-manifest
tags: [android, play-store, alarms, permissions, notifications]
dependency-graph:
  requires: []
  provides:
    - "AndroidScheduleMode.inexactAllowWhileIdle on both scheduling call sites"
    - "No exact-alarm permission of any kind in the source AndroidManifest.xml"
    - "Regression guards for both (manifest test + scheduling test)"
  affects:
    - lib/notifications/notification_service.dart
    - android/app/src/main/AndroidManifest.xml
tech-stack:
  added: []
  patterns:
    - "_RecordingPlugin.scheduleModes captures androidScheduleMode for assertion"
key-files:
  created: []
  modified:
    - lib/notifications/notification_service.dart
    - android/app/src/main/AndroidManifest.xml
    - test/unit/android_manifest_permissions_test.dart
    - test/unit/notifications/reminder_scheduling_test.dart
decisions:
  - "D-1/D-2/D-3 (product owner, locked): switch both call sites to inexactAllowWhileIdle, remove USE_EXACT_ALARM and its comment, do not add SCHEDULE_EXACT_ALARM as a substitute"
  - "Dartdoc explains the 'why' (Play eligibility) without using the literal string USE_EXACT_ALARM, since the plan's own verify grep checks that literal is absent from lib/android — the action text and verify command were in tension and the verify command took precedence"
metrics:
  duration: "~35 minutes"
  completed: "2026-08-03"
---

# Phase quick-260802-x1q Plan 01: Replace exact alarms with inexact to drop Play-restricted USE_EXACT_ALARM Summary

Switched both `zonedSchedule` call sites (weekly summary + per-weekday reminders) from `AndroidScheduleMode.exactAllowWhileIdle` to `AndroidScheduleMode.inexactAllowWhileIdle` and removed `android.permission.USE_EXACT_ALARM` from the manifest, so Traevy no longer declares a Play-restricted permission it is not eligible for as a commute tracker (not a calendar/alarm-clock app).

## What Changed

**`lib/notifications/notification_service.dart`**
- `scheduleWeeklySummary`: `androidScheduleMode` changed to `AndroidScheduleMode.inexactAllowWhileIdle`. Dartdoc gained a short note that delivery is now approximate (minutes of drift, Android batches inexact alarms) and why (Google Play restricts the exact-alarm permission to calendar/alarm-clock apps), plus a note that Doze wake-up is retained.
- `scheduleReminder`: same mode change and same dartdoc treatment, at the per-weekday `zonedSchedule` call inside the `for (final weekday in sortedDays)` loop.

**`android/app/src/main/AndroidManifest.xml`**
- Deleted the 5-line block (4-line comment + element) declaring `android.permission.USE_EXACT_ALARM`. No replacement comment was added — the two new test guards carry that explanation now. No replacement permission (`SCHEDULE_EXACT_ALARM` or otherwise) was added, per D-3.
- All other permissions and comments (including the `ACCESS_BACKGROUND_LOCATION` omission comment from quick-260802-itr) are byte-for-byte unchanged.

**`test/unit/android_manifest_permissions_test.dart`** (extended, not replaced)
- Header comment widened to describe the file as a general guard for Play-eligibility-critical permission *absences*, now covering both the background-location omission (260802-itr) and the exact-alarm omission (260802-x1q). The LIMIT paragraph about source-vs-merged manifests was preserved verbatim.
- Added a second `test(...)` inside the existing `group`, asserting the source manifest contains neither `USE_EXACT_ALARM` nor `SCHEDULE_EXACT_ALARM`, with the same `existsSync()` guard-first pattern and positive controls (`POST_NOTIFICATIONS`, `ACCESS_FINE_LOCATION`) as the existing test.
- The pre-existing `ACCESS_BACKGROUND_LOCATION` assertion and its three positive controls were left byte-for-byte unchanged, as required.

**`test/unit/notifications/reminder_scheduling_test.dart`**
- `_RecordingPlugin` gained a `scheduleModes` list that now captures the `androidScheduleMode` argument on every `zonedSchedule` call (previously declared but discarded).
- New test in the existing `scheduleReminder` group: scheduling `{1,2,3,4,5}` produces 5 recorded modes, all `inexactAllowWhileIdle`, and none `exactAllowWhileIdle` (explicit negative control).
- New group `scheduleWeeklySummary (quick-260802-x1q)`: constructs `AppDatabase(NativeDatabase.memory())`, calls `service.scheduleWeeklySummary(db)` against an empty DB (takes the `kWeeklySummaryNotificationBodyEmpty` branch, still schedules), and asserts exactly one schedule at `kWeeklySummaryNotificationId` with mode `inexactAllowWhileIdle`, not `exactAllowWhileIdle`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1/3 — resolved a contradiction between the plan's action text and its own verify command] Dartdoc phrasing avoids the literal string `USE_EXACT_ALARM`**
- **Found during:** Task 1, writing the dartdoc "why" sentence.
- **Issue:** The plan's action text explicitly instructs writing a dartdoc sentence naming `USE_EXACT_ALARM` as the reason exact scheduling isn't available. But the plan's own Task 1 `<verify>` command is `! grep -rn "AndroidScheduleMode\.exactAllowWhileIdle\|USE_EXACT_ALARM\|SCHEDULE_EXACT_ALARM" lib android` — which requires that literal string to be absent from the entire `lib` tree, including the dartdoc itself. Writing the literal identifier into the comment would make the plan's own verify command fail.
- **Fix:** Wrote the same explanation ("the exact-alarm permission is restricted by Google Play to apps whose core functionality is calendar or alarm clock...") without using the literal string `USE_EXACT_ALARM`. The intended reader-facing meaning is identical; only the exact substring is avoided.
- **Files modified:** `lib/notifications/notification_service.dart` (both dartdoc blocks).
- **Commit:** `31c5bbd`

No other deviations. Plan executed as written otherwise.

## Adversarial Verification (both guards observed RED, then GREEN)

**Guard 1 — `test/unit/notifications/reminder_scheduling_test.dart`**
- Temporarily reverted the `scheduleReminder` call site's `androidScheduleMode` from `inexactAllowWhileIdle` back to `AndroidScheduleMode.exactAllowWhileIdle`.
- Ran `flutter test test/unit/notifications/reminder_scheduling_test.dart`. Observed FAILURE:
  ```
  scheduleReminder (Phase 33, D-02) every scheduled reminder alarm uses inexactAllowWhileIdle, never exactAllowWhileIdle [E]
    Expected: every element(AndroidScheduleMode:<AndroidScheduleMode.inexactAllowWhileIdle>)
      Actual: [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.exactAllowWhileIdle]
       Which: has value AndroidScheduleMode:<AndroidScheduleMode.exactAllowWhileIdle> which doesn't match AndroidScheduleMode:<AndroidScheduleMode.inexactAllowWhileIdle> at index 0
    restoring exactAllowWhileIdle reintroduces the need for USE_EXACT_ALARM, which Google Play restricts to calendar and alarm-clock apps — this test is the only thing that would surface that regression before a Play submission fails
  ```
  Result: `+9 -1`, `Some tests failed.`
- Reverted the source change back to `inexactAllowWhileIdle`. Re-ran the same command. Observed: `+11: All tests passed!` (11 tests, all green, including the new `scheduleWeeklySummary` group).

**Guard 2 — `test/unit/android_manifest_permissions_test.dart`**
- Temporarily re-added `<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>` to `android/app/src/main/AndroidManifest.xml` (immediately after the `POST_NOTIFICATIONS` line).
- Ran `flutter test test/unit/android_manifest_permissions_test.dart`. Observed FAILURE:
  ```
  AndroidManifest.xml source permissions (quick-260802-itr guard) does not declare USE_EXACT_ALARM or SCHEDULE_EXACT_ALARM, and still declares permissions proving the block was not deleted wholesale [E]
    Expected: false
      Actual: <true>
    USE_EXACT_ALARM must not be declared in the source manifest — Google Play restricts this permission to apps whose core functionality is "calendar" or "alarm clock". Traevy is a commute tracker and is therefore ineligible; re-adding it fails the Play app-content declaration across all tracks.
  ```
  Result: `+1 -1`, `Some tests failed.`
- Reverted the manifest change (removed the re-added line). Re-ran the same command. Observed: `+2: All tests passed!`

Both reverts were confirmed restored in the working tree before the final commit — `git diff --stat` at commit time showed only the intended 4-file, 199-insertion/20-deletion diff.

## Full-Suite Verification

- `dart format .` — clean, 0 files changed on final run.
- `flutter analyze` — 0 errors, 0 warnings, 292 info-level issues (matches the stated baseline exactly).
- `flutter test` (targeted): `test/unit/android_manifest_permissions_test.dart` + `test/unit/notifications/` — all pass (23 tests).
- `flutter test` (full suite): `+1014 ~10 -1`. The single failure is `test/unit/features/stats/stats_soft_delete_test.dart` ("week total drops on soft delete and returns on restore", expected 1800 got 0). **Verified pre-existing and unrelated**: reproduced the identical failure by `git stash`-ing all four changed files and running the same test against unmodified `main` (commit `5772ee3`), then restored the stash. This failure is out of scope for this task per the deviation-rules scope boundary and was not touched.
- `grep -rn "AndroidScheduleMode\.exactAllowWhileIdle\|USE_EXACT_ALARM\|SCHEDULE_EXACT_ALARM" lib android` — no matches (exit 1).
- `grep -rn "TODO" lib/notifications/notification_service.dart test/unit/android_manifest_permissions_test.dart test/unit/notifications/reminder_scheduling_test.dart` — no matches (exit 1).

## CRITICAL — Required Follow-Up Before Play Re-Evaluates

**1. A new release build and upload is REQUIRED.** This source-level fix changes nothing on Google Play's side by itself. The content declaration will keep failing against whatever bundle is already uploaded. The most recent commit before this task (`5772ee3 [infra] Bump version code to 4 for Play upload`) indicates version `1.0.0+4` was likely already built/uploaded — if so, the version code MUST be bumped beyond `1.0.0+4` before a new AAB will be accepted by Play. **The pubspec version bump itself was intentionally left out of scope for this task** — flagging it here, not doing it.

**2. Re-check the MERGED manifest after building — do not trust the source manifest alone.** The source manifest being clean does not prove the shipped artifact is: `flutter_local_notifications` or any other transitive Gradle dependency can reintroduce an exact-alarm permission through Android manifest merging, and no test in this repo can catch that (see the LIMIT comment in `android_manifest_permissions_test.dart`). After the next release build, inspect:
   ```
   build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml
   ```
   and confirm neither `USE_EXACT_ALARM` nor `SCHEDULE_EXACT_ALARM` appears. An equivalent check is `aapt2 dump permissions` on the built artifact. If either permission shows up, it is coming from a dependency and needs a `tools:node="remove"` manifest-merger override — STOP and report rather than improvising a fix.

**3. Accepted behavioural trade-off — do not "fix" this later.** Reminders and the weekly summary now fire at *roughly* the chosen time rather than exactly (Android batches inexact alarms with other pending work; drift is typically a few minutes). Doze wake-up is RETAINED — the code uses `inexactAllowWhileIdle`, not plain `inexact` — so overnight and idle-device delivery is unaffected. This is a deliberate, permanent trade-off in exchange for Play eligibility. **Do not restore exact alarms to "fix" the drift** — doing so re-introduces `USE_EXACT_ALARM` and re-triggers the exact Play rejection this task exists to resolve.

## Known Stubs

None.

## Threat Flags

None — this change strictly reduces the app's declared permission surface and adds two regression guards; see the plan's `<threat_model>` (T-x1q-01, T-x1q-02), both already dispositioned as `mitigate`/`accept` with no new surface introduced.

## Self-Check: PASSED

- `lib/notifications/notification_service.dart` — FOUND, contains `AndroidScheduleMode.inexactAllowWhileIdle` exactly twice (verified via grep above).
- `android/app/src/main/AndroidManifest.xml` — FOUND, contains no `USE_EXACT_ALARM`/`SCHEDULE_EXACT_ALARM` (verified via grep above).
- `test/unit/android_manifest_permissions_test.dart` — FOUND, extended (not replaced); pre-existing `ACCESS_BACKGROUND_LOCATION` assertion untouched.
- `test/unit/notifications/reminder_scheduling_test.dart` — FOUND, extended with `scheduleModes` capture and two new tests.
- Commit `31c5bbd` — FOUND via `git log --oneline -1`.
