---
phase: 14-background-gps-platform-branch
plan: "01"
subsystem: tracking/iOS-GPS
tags: [ios, gps, background, platform-branch, wave-0, SC#4, IOS-06, IOS-07, IOS-08]
dependency_graph:
  requires: []
  provides:
    - buildLocationSettings() — single SC#4 defaultTargetPlatform branch (AppleSettings/AndroidSettings)
    - kPreciseCommutePurposeKey = 'PreciseCommute' constant
    - kIosTrackingDistanceFilterMeters = 0 constant
    - location_settings_branch_test.dart (11 green tests, SC#4 proven under both platform overrides)
    - reduced_accuracy_gate_test.dart (Wave 0 @Skip RED scaffold — Wave 1 implements)
    - ios_engine_stop_race_test.dart (Wave 0 @Skip RED scaffold — Wave 1 implements)
  affects:
    - Plans 14-02, 14-03 (consume buildLocationSettings() and the constants)
tech_stack:
  added: []
  patterns:
    - defaultTargetPlatform branch with debugDefaultTargetPlatformOverride seam for unit testing
    - @Skip annotation for Wave 0 RED scaffolds that Wave 1 fills
key_files:
  created:
    - lib/features/tracking/services/location_settings_builder.dart
    - test/unit/features/tracking/location_settings_branch_test.dart
    - test/unit/features/tracking/reduced_accuracy_gate_test.dart
    - test/unit/features/tracking/ios_engine_stop_race_test.dart
  modified:
    - lib/config/constants.dart (Phase 14 banner + 2 new consts appended)
    - .planning/phases/14-background-gps-platform-branch/14-VALIDATION.md (Wave 0 entries)
decisions:
  - "distanceFilter omitted from AppleSettings constructor call because kIosTrackingDistanceFilterMeters=0 equals the LocationSettings default; constant retained for downstream test assertions and documentation"
  - "allowBackgroundLocationUpdates and pauseLocationUpdatesAutomatically omitted from constructor call (match defaults true/false respectively) per very_good_analysis avoid_redundant_argument_values; intended values documented in file-level dartdoc"
metrics:
  duration: "5m"
  completed_date: "2026-06-02"
  tasks_completed: 2
  files_changed: 6
requirements:
  - IOS-06
  - IOS-07
---

# Phase 14 Plan 01: Wave 0 Platform-Branch Constants and Contracts Summary

**One-liner:** `buildLocationSettings()` with `defaultTargetPlatform` iOS/Android branch (AppleSettings locked per SC#4/IOS-06/IOS-07), two Phase 14 constants, and Wave 0 gate + stop-race RED scaffolds for Wave 1.

---

## Objective

Establish the Wave 0 validation contracts and the single SC#4 source-of-truth for the platform `LocationSettings` branch plus the iOS-only constants that downstream waves consume. No hardcoded literals, branch unit-testable via `debugDefaultTargetPlatformOverride`.

---

## What Was Built

### Task 1 — Constants + buildLocationSettings() (commit d159344)

**`lib/config/constants.dart`** — Phase 14 banner appended with two constants:

- `kPreciseCommutePurposeKey = 'PreciseCommute'` — must match `NSLocationTemporaryUsageDescriptionDictionary` key in `ios/Runner/Info.plist` exactly (D-06). Plan 14-02 adds the plist entry.
- `kIosTrackingDistanceFilterMeters = 0` — iOS distanceFilter set to 0 so `pauseLocationUpdatesAutomatically:false` + high accuracy drive cadence; near-zero speed (stop-and-go traffic) still emits samples (IOS-07 / RESEARCH §2).

**`lib/features/tracking/services/location_settings_builder.dart`** — new file, top-level function `buildLocationSettings()`:

- Uses `defaultTargetPlatform == TargetPlatform.iOS` (NOT `dart:io Platform.isIOS`) so the branch is overridable in unit tests via `debugDefaultTargetPlatformOverride`.
- **iOS path:** `AppleSettings(accuracy: high, activityType: automotiveNavigation, showBackgroundLocationIndicator: true)` — `allowBackgroundLocationUpdates` and `pauseLocationUpdatesAutomatically` kept at their already-correct defaults (true and false) per IOS-06/IOS-07; `distanceFilter` also equals default 0.
- **Android path:** `AndroidSettings(accuracy: high, intervalDuration: kTrackingSampleInterval)` — reproduces existing `tracking_service.dart` byte-for-byte (D-08 regression guard).
- File-level PII guard comment: this helper must never log a `Position` (T-02-07).

**`test/unit/features/tracking/location_settings_branch_test.dart`** — 11 tests, all green:

- Asserts all four locked SC#4/IOS-06/IOS-07 AppleSettings params individually under `TargetPlatform.iOS` override.
- Asserts AndroidSettings type + `intervalDuration == kTrackingSampleInterval` under `TargetPlatform.android` override.
- `tearDown` resets `debugDefaultTargetPlatformOverride = null` on every test.

### Task 2 — Wave 0 RED Scaffolds + VALIDATION.md update (commit f687f41)

**`test/unit/features/tracking/reduced_accuracy_gate_test.dart`** — `@Skip('Wave 1 implements: IOS-08 reduced-accuracy gate in MainIsolateTrackingEngine')`:

Documents the three IOS-08 contract outcomes:
- **A (BLOCKED):** `reduced → requestTemporaryFullAccuracy → reduced` → `start()` returns blocked result
- **B (PROCEED):** `reduced → request → precise` → `start()` proceeds, GPS stream opens with AppleSettings
- **C (PROCEED):** already `precise` → `requestTemporaryFullAccuracy` NOT called → `start()` proceeds

**`test/unit/features/tracking/ios_engine_stop_race_test.dart`** — `@Skip('Wave 1 implements: MainIsolateTrackingEngine iOS stop-race guard')`:

Documents the stop-race ordering contract:
- `stopping` flag set BEFORE `StreamSubscription.cancel()` (mirrors Android isolate guard)
- Position sample pushed AFTER `stop()` sets the flag must NOT reach `TripAccumulator.addSample()`
- Finalized trip reflects only pre-stop samples

**`.planning/phases/14-background-gps-platform-branch/14-VALIDATION.md`** — updated with per-task status rows; `wave_0_complete: true`.

---

## Verification Results

```
flutter test location_settings_branch_test.dart
  +11 ~0: All tests passed (11 green)

flutter test location_settings_branch_test.dart reduced_accuracy_gate_test.dart ios_engine_stop_race_test.dart
  +11 ~2: All tests passed (11 green, 2 skipped)

flutter analyze lib/features/tracking/services/location_settings_builder.dart lib/config/constants.dart
  1 info (pre-existing line-length in constants.dart line 232 — not new)
```

---

## Deviations from Plan

### Auto-adjusted: Redundant argument values in AppleSettings constructor

**Found during:** Task 1 verification (`flutter analyze`)

**Issue:** `very_good_analysis avoid_redundant_argument_values` flagged `allowBackgroundLocationUpdates: true`, `pauseLocationUpdatesAutomatically: false`, and `distanceFilter: kIosTrackingDistanceFilterMeters` because all three match `AppleSettings`/`LocationSettings` defaults (true, false, 0 respectively).

**Fix:** Omitted the three args from the constructor call. The intended values are documented explicitly in the file-level dartdoc on `buildLocationSettings()` with requirement cross-references. The unit tests still assert the correct runtime values (which match the defaults).

**Impact:** No behavior change. Tests still pass. The SC#4 contract is documented in the dartdoc and proven by the test, not by constructor verbosity.

---

## Known Stubs

None — `buildLocationSettings()` is fully implemented. The two scaffold test files are intentional Wave 0 structures, not stubs in the data-flow sense; they are `@Skip`-annotated and documented as Wave 1 work.

---

## Threat Flags

No new threat surface introduced. `buildLocationSettings()` returns a configuration object only (no `Position`, no network calls, no PII). File-level comment records the T-02-07 PII guard. The `kPreciseCommutePurposeKey` constant is an opaque key string (T-14-01 accepted per plan threat model).

## Self-Check: PASSED
