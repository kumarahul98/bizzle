---
phase: quick-260802-itr
plan: 01
subsystem: tracking / android-manifest / permissions
tags: [android, permissions, gps, foreground-service, play-store]
requires: []
provides:
  - "Manifest without ACCESS_BACKGROUND_LOCATION"
  - "TrackingPermissionStatus (4-way) + two-step locationWhenInUse -> notification dance"
  - "locationAlways-never-touched regression guard"
  - "Source-manifest regression guard"
affects:
  - lib/features/tracking/services/tracking_permission_service.dart
  - lib/features/tracking/services/tracking_service_controller.dart
  - lib/config/constants.dart
  - android/app/src/main/AndroidManifest.xml
tech-stack:
  added: []
  patterns:
    - "Structural (early-return) ordering invariants instead of runtime asserts"
key-files:
  created:
    - test/unit/android_manifest_permissions_test.dart
  modified:
    - android/app/src/main/AndroidManifest.xml
    - lib/features/tracking/services/tracking_permission_service.dart
    - lib/features/tracking/services/tracking_service_controller.dart
    - lib/config/constants.dart
    - test/unit/features/tracking/tracking_permission_service_test.dart
    - test/widget/features/dashboard/dashboard_screen_test.dart
decisions:
  - "DEC-A: deleted TrackingPermissionStatus.foregroundOnly (unreachable dead variant once locationAlways is never probed)"
  - "DEC-B: kept the name fullyGranted, redefined to locationWhenInUse+notification granted"
  - "DEC-C: iOS branch collapses to fullyGranted after locationWhenInUse resolves; iOS background-location strategy deferred to v0.2 resume"
  - "DEC-D: preflight() ordering invariant (notification never touched before location resolves) enforced by early-return control flow, not an assert"
metrics:
  duration: "~55 minutes"
  completed: 2026-08-02
---

# Phase quick-260802-itr Plan 01: Drop ACCESS_BACKGROUND_LOCATION; rely on the location foreground service Summary

Dropped `android.permission.ACCESS_BACKGROUND_LOCATION` from the Android manifest and
`Permission.locationAlways` from the tracking permission dance, replacing the four-step
`locationWhenInUse -> locationAlways -> notification` flow with a two-step
`locationWhenInUse -> notification` flow, so the app never triggers Google Play's
background-location declaration requirement.

**Commit:** `8009e46` — `[tracking] Drop ACCESS_BACKGROUND_LOCATION; rely on the location foreground service`
(Tasks 1 and 2 landed together, as required — the tree does not compile between them since
removing the enum variant breaks `dashboard_screen_test.dart`.)

## Scope Executed

**Task 1 (manifest + permission contract) and Task 2 (tests + guards) — both DONE.**
**Task 3 (real-device background-recording verification) — NOT executed. See "Task 3 — OPEN" below.**

## What Changed

### AndroidManifest.xml
- Removed the `ACCESS_BACKGROUND_LOCATION` `<uses-permission>` line and its D-07 comment.
- Added a comment above `FOREGROUND_SERVICE_LOCATION` explaining why no background-location
  permission is declared.
- Untouched: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `WAKE_LOCK`, `INTERNET`,
  `USE_EXACT_ALARM`, and the `foregroundServiceType="location"` service declaration.

### TrackingPermissionStatus — final shape (4 variants, down from 5)
```dart
enum TrackingPermissionStatus {
  fullyGranted,       // locationWhenInUse + notification both granted
  denied,             // fine denied (soft)
  permanentlyDenied,  // fine permanently denied
  notificationDenied, // location OK, notification denied
}
```
`foregroundOnly` is gone (DEC-A). `fullyGranted` keeps its name (DEC-B) but its dartdoc no
longer claims background location — it now means "every permission this app requires is
granted," which is `locationWhenInUse` + `notification`.

### `TrackingPermissionService.preflight()` / `currentStatus()`
- Neither method probes or requests `Permission.locationAlways` in any reachable state, on
  either platform.
- `preflight()`'s "notification is never touched before location resolves granted" invariant
  is now structural: every non-granted location outcome (`denied`, `permanentlyDenied`)
  returns early, so there is no local flag or `assert` to keep in sync (DEC-D). The old
  `assert(fineGranted, 'locationAlways must never be touched...')` was deleted along with the
  `locationAlways` probe/request block it guarded.
- iOS branch (DEC-C, D-2 unconditional): after `locationWhenInUse` resolves granted, iOS
  returns `fullyGranted` directly — no `locationAlways` probe, no `foregroundOnly` outcome.
  Both `preflight()` and `currentStatus()` carry a `TODO(v0.2-resume)` comment stating iOS
  background-location strategy must be re-decided at the v0.2 resume, since iOS has no
  foreground-service equivalent and this change's Android-specific reasoning does not
  transfer.
- Class dartdoc, `preflight()`'s own dartdoc, `LocationWhenInUseStatus`'s dartdoc, and
  `requestWhenInUse()`'s dartdoc were all rewritten to describe the two-step contract and to
  state explicitly that `Permission.locationAlways` is never touched by this class, and why.

### `tracking_service_controller.dart`
- The `start()` precondition doc no longer says tracking "ideally" wants `locationAlways`
  with a D-08 fallback banner. It now states the accurate precondition: `locationWhenInUse`
  alone is sufficient because tracking always runs inside the location-typed foreground
  service, started only while the app is foregrounded.

### `constants.dart`
- `kIosPermissionBannerBody` was **not deleted** (still parked, unused Phase 15 iOS copy).
  Its dartdoc was reworded to state it describes a When-In-Use-only degraded state the
  current Android-only enum no longer models, and that it remains unused pending the v0.2
  iOS resume.

## Regression Guards — Adversarial Red-Check (mandatory, both observed)

**Guard 1 — `Permission.locationAlways` never touched**
(`test/unit/features/tracking/tracking_permission_service_test.dart`, group
`ACCESS_BACKGROUND_LOCATION regression guard (Permission.locationAlways is never touched)`,
12 tests: 7 covering `preflight()`, 5 covering `currentStatus()`, including one iOS case
each).

- **RED observed:** temporarily inserted `await _probe(Permission.locationAlways);` into
  `preflight()` right after the location step resolves. Re-ran the guard group:
  ```
  00:00 +3 -1: ...fine denied on probe, granted on request, notification granted [E]
    Bad state: Unexpected probe call: Permission.locationAlways
  00:00 +3 -2: ...fine granted, notification denied on probe and on request [E]
    Bad state: Unexpected probe call: Permission.locationAlways
  00:00 +3 -3: ...fine granted, notification granted [E]
    Bad state: Unexpected probe call: Permission.locationAlways
  00:00 +3 -4: ...iOS: fine granted resolves fullyGranted [E]
    Bad state: Unexpected probe call: Permission.locationAlways
  Some tests failed.
  ```
  All 4 tests whose control flow reaches past the location step failed loudly (the 3 early-return
  `preflight()` cases and all 5 `currentStatus()` cases correctly did not fail, since that code
  path is never reached by them — `currentStatus()` was untouched in this red-check).
- **Reverted**, re-ran: `+12: All tests passed!` — GREEN confirmed.

**Guard 2 — source manifest has no `ACCESS_BACKGROUND_LOCATION`**
(`test/unit/android_manifest_permissions_test.dart`, new file).

- **RED observed:** temporarily re-added `<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>` to the manifest. Re-ran:
  ```
  Expected: false
    Actual: <true>
  ACCESS_BACKGROUND_LOCATION must not be declared in the source manifest — it re-triggers
  the Play Store background-location declaration (and its mandatory demo video) that
  quick-260802-itr deliberately removed. Background GPS is covered by the location-typed
  foreground service instead.
  Some tests failed.
  ```
- **Reverted**, re-ran: `+1: All tests passed!` — GREEN confirmed.

A guard never seen red is not a guard — both were.

## Test Count Delta

| File | Before | After | Delta |
|---|---|---|---|
| `tracking_permission_service_test.dart` | 28 tests | 35 tests | **+7** (net: +12 new regression-guard tests, −5 from deleting/folding tests whose unique coverage was superseded — the `foregroundOnly`-specific preflight test, the explicit locationAlways-ordering test, one `currentStatus` `foregroundOnly` test, and folding two duplicate `notificationDenied` pairs into one each) |
| `android_manifest_permissions_test.dart` (new) | 0 | 1 test | +1 |
| `dashboard_screen_test.dart` | 12 tests | 12 tests | 0 (only probe-map contents changed, no test added/removed) |

Full suite: `flutter test` → **1012 tests passed, 10 skipped (pre-existing skip baseline,
unchanged), 0 failed.**

## Verification Observed

- `dart format .` — clean, 0 files needed changes on the final pass.
- `flutter analyze` — **0 errors, 0 warnings, 292 info-level issues** (identical to the
  292-issue baseline recorded before this change — no drift either way).
- `flutter test` — fully green, no skips beyond the pre-existing 10.
- `grep -c ACCESS_BACKGROUND_LOCATION android/app/src/main/AndroidManifest.xml` → `0`.
- `grep -n 'foregroundServiceType="location"'` and `grep -n FOREGROUND_SERVICE_LOCATION` on
  the manifest both still match (lines present, untouched).
- `test/widget/features/settings/location_picker_screen_test.dart` — confirmed unmodified
  (not present in `git diff --stat` for this commit); quick task 260802-dgp's
  `requestWhenInUse()` work is untouched.
- `git status --short` post-commit — no unexpected files; `git diff --diff-filter=D --name-only HEAD~1 HEAD` — empty (no accidental deletions).

## Deviations from Plan

### Clarified (not auto-fixed) — internal plan inconsistency on `locationAlways`/`foregroundOnly` grep scope

The plan's Task 1 action text explicitly required adding documentation stating
`Permission.locationAlways` is never touched by the class, and why (item 2e), and the
top-level `<verification>` block separately states `grep -rn "locationAlways" lib` should
return nothing. These two requirements are mutually exclusive if taken literally, since
writing the required explanatory dartdoc text necessarily makes that grep match. I resolved
this by following the more specific, task-scoped done criteria (Task 2's `<done>`: "matches
ONLY inside the new regression-guard group and its explanatory comments"), which is
consistent with the explicit content the plan asked to be written. All current matches for
`locationAlways`/`foregroundOnly` in `lib/` are confined to dartdoc/comments in
`tracking_permission_service.dart` and `constants.dart` explaining the guard and the parked
iOS copy — none are functional calls (`Permission.locationAlways` is never invoked anywhere
in `lib/`), and `tracking_service_controller.dart` has zero matches. This is a documentation
clarification, not a rule-1/2/3 code fix, and no architectural decision was involved (Rule 4
not applicable) — flagging it here per the instruction to document deviations.

### No other deviations

Every other action item in Task 1 and Task 2 was implemented exactly as specified: enum
shape, dartdoc rewrites, `preflight()`/`currentStatus()` restructuring, the two new
regression guards, and the test re-pointing/deletion/folding per the plan's explicit
per-test instructions.

## Known Stubs

None. No hardcoded empty values, placeholder text, or unwired data were introduced.

## Threat Flags

None. This change only narrows permission scope (removes a permission and a request path);
it introduces no new network endpoints, auth paths, file access patterns, or schema changes.

---

## Task 3 — OPEN (not performed, cannot be performed by this agent)

**Task 3 (`checkpoint:human-verify`, gate="blocking") — real-device background-recording
verification — was intentionally NOT attempted.** There is no physical Android device
attached to this environment, and CLAUDE.md explicitly forbids trusting emulator GPS
simulation for traffic/background-recording calculations ("Test on real Android devices for
GPS and background service behavior. Emulator GPS simulation is unreliable for traffic
calculations."). This was not simulated, faked, or marked complete.

### RISK R-01 — background recording now has NO automated safety net

Background GPS recording depends **entirely** on the location-typed foreground service
(`android:foregroundServiceType="location"`) staying alive and receiving location updates
while the screen is locked or the app is backgrounded. There is no longer an
`ACCESS_BACKGROUND_LOCATION` fallback.

**If the foreground service fails to sustain GPS on some device or OEM battery-management
skin, the app's core feature breaks SILENTLY:** the user taps Start, locks the screen,
drives, and gets a trip with a truncated route and a frozen elapsed-time display — **no
crash, no error, no exception.** `flutter analyze` reporting 0 errors/warnings and
`flutter test` reporting fully green **prove nothing about this risk.** No automated test in
this repository, and none that could reasonably be written, can catch it.

**The only verification that exists for this risk is Task 3's real-device checklist**
(fresh install → grant "While using the app" only → Start → lock screen 5+ min while
moving → confirm continuous elapsed time/distance/polyline across the locked period →
repeat with an app-switch → repeat with battery optimisation at device default → inspect the
merged/built manifest via `aapt2 dump permissions` or the `merged_manifests` intermediate
for a reintroduced `ACCESS_BACKGROUND_LOCATION`, which the automated Guard 2 above cannot
detect since it only reads the source manifest, not plugin manifest-merging output).

**Do not ship this change to production until Task 3 has been run on a real device and
passed.** See `.planning/quick/260802-itr-drop-access-background-location-and-rely/260802-itr-PLAN.md`,
Task 3, for the full step-by-step checklist and resume signal.

## Self-Check: PASSED

- FOUND: `android/app/src/main/AndroidManifest.xml` (modified, verified via grep)
- FOUND: `lib/features/tracking/services/tracking_permission_service.dart` (modified)
- FOUND: `lib/features/tracking/services/tracking_service_controller.dart` (modified)
- FOUND: `lib/config/constants.dart` (modified)
- FOUND: `test/unit/features/tracking/tracking_permission_service_test.dart` (modified)
- FOUND: `test/unit/android_manifest_permissions_test.dart` (created)
- FOUND: `test/widget/features/dashboard/dashboard_screen_test.dart` (modified)
- FOUND commit `8009e46` in `git log --oneline -3`
- Verified `flutter test` full-suite green and `flutter analyze` 0 errors/0 warnings at the
  final commit state (post-adversarial-revert).
