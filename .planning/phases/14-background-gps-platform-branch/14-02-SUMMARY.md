---
phase: 14-background-gps-platform-branch
plan: "02"
subsystem: tracking/iOS-GPS
tags: [ios, gps, background, platform-branch, wave-1, IOS-06, IOS-07, IOS-08, seam, accuracy-gate]
dependency_graph:
  requires:
    - phase: 14-01
      provides: "buildLocationSettings(), kPreciseCommutePurposeKey, kIosTrackingDistanceFilterMeters"
  provides:
    - TrackingEventSource interface (onState/onFinalized/onError/onReady + start/stop)
    - FbsTrackingEventSource Android wrapper (1:1 passthrough to FlutterBackgroundService)
    - MainIsolateTrackingEngine — iOS GPS on main isolate via TripAccumulator + 1Hz timer
    - LocationAccuracyGate.ensurePrecise() — IOS-08 three-outcome gate (blocked/proceed)
    - TrackingServiceController iOS preflight branch (defaultTargetPlatform == iOS)
    - ios/Runner/Info.plist NSLocationTemporaryUsageDescriptionDictionary/PreciseCommute
    - tracking_service.dart now uses buildLocationSettings() (SC#4 single branch)
    - reduced_accuracy_gate_test.dart (3 GREEN outcomes: blocked/proceed-after/proceed-direct)
    - ios_engine_stop_race_test.dart (3 GREEN tests: late-drop, flag-before-cancel, N-pre-M-post)
  affects:
    - Plan 14-03: TrackingNotifier rewire to TrackingEventSource (FbsTrackingEventSource on
      Android, MainIsolateTrackingEngine on iOS)
tech_stack:
  added: []
  patterns:
    - TrackingEventSource seam — platform-uniform Map<String,dynamic>? streams enabling
      Plan 03 notifier reuse across Android/iOS without branching in TrackingNotifier
    - Injectable stream factory in MainIsolateTrackingEngine for synchronous stop-race tests
      (StreamController<Position> as a substitute for Geolocator.getPositionStream)
    - Injectable accuracy functions in LocationAccuracyGate for three-outcome unit testing
      without real CoreLocation APIs
    - defaultTargetPlatform (not dart:io Platform.isIOS) for all platform branches so they
      remain unit-testable via debugDefaultTargetPlatformOverride
key_files:
  created:
    - lib/features/tracking/services/tracking_event_source.dart
    - lib/features/tracking/services/main_isolate_tracking_engine.dart
    - lib/features/tracking/services/location_accuracy_gate.dart
  modified:
    - lib/features/tracking/services/tracking_service_controller.dart (iOS gate + injectable)
    - lib/features/tracking/services/tracking_service.dart (buildLocationSettings() call)
    - ios/Runner/Info.plist (NSLocationTemporaryUsageDescriptionDictionary/PreciseCommute)
    - test/unit/features/tracking/reduced_accuracy_gate_test.dart (un-skipped, 3 tests green)
    - test/unit/features/tracking/ios_engine_stop_race_test.dart (un-skipped, 3 tests green)
key_decisions:
  - "MainIsolateTrackingEngine uses injectable positionStreamFactory (default Geolocator.getPositionStream)
     so stop-race tests drive a synchronous StreamController without real GPS — keeps tests fast and device-free"
  - "FbsTrackingEventSource.stop() is async void wrapping a synchronous invoke() — matches the interface
     contract without changing the fire-and-forget semantics"
  - "LocationAccuracyGate uses injectable function types (not an interface) — simpler DI pattern for two
     functions vs defining an AccuracyService interface for single-use"
  - "defaultTargetPlatform used consistently in both the gate branch and buildLocationSettings() so the
     full iOS path is unit-testable without a real device"
requirements-completed: [IOS-06, IOS-07, IOS-08]
duration: 30min
completed: "2026-06-02"
---

# Phase 14 Plan 02: iOS Main-Isolate GPS Engine and Accuracy Gate Summary

**iOS GPS recording engine (main-isolate + TripAccumulator + 1Hz timer) behind a TrackingEventSource seam, IOS-08 three-outcome reduced-accuracy gate, Info.plist purpose dictionary, and both Wave 0 scaffolds satisfied GREEN.**

---

## Performance

- **Duration:** ~30 min
- **Started:** 2026-06-02
- **Completed:** 2026-06-02
- **Tasks:** 3
- **Files modified/created:** 9

---

## Accomplishments

- `TrackingEventSource` abstract interface + `FbsTrackingEventSource` Android wrapper provide platform-uniform `Map<String,dynamic>?` streams; Android path byte-for-byte unchanged (D-08)
- `MainIsolateTrackingEngine` records GPS on the main isolate with correct stop-race ordering (stopping=true before await sub.cancel()) and PII guard (no Position fields or error.toString() in source)
- `LocationAccuracyGate.ensurePrecise()` with all three IOS-08 outcomes tested: blocked (still-reduced after prompt), proceed (precise after prompt), proceed-direct (already precise, no prompt)
- `tracking_service_controller.dart` iOS preflight branch wired via `defaultTargetPlatform == TargetPlatform.iOS`; Android branch unchanged
- `tracking_service.dart` now calls `buildLocationSettings()` — SC#4 single platform branch
- `ios/Runner/Info.plist` has `NSLocationTemporaryUsageDescriptionDictionary` / `PreciseCommute`; plutil -lint OK
- Both Wave 0 scaffolds un-skipped and GREEN: 3+3=6 new tests, all pass; 71/71 tracking tests total

---

## Task Commits

1. **Task 1: Define TrackingEventSource seam + FbsTrackingEventSource Android wrapper** — `62e4af4` (feat)
2. **Task 2: Build MainIsolateTrackingEngine + satisfy stop-race scaffold** — `5b30c75` (feat)
3. **Task 3: IOS-08 accuracy gate, controller iOS preflight, Info.plist, gate tests; rewire Android settings** — `afa390d` (feat)

---

## Files Created/Modified

- `lib/features/tracking/services/tracking_event_source.dart` — TrackingEventSource interface + FbsTrackingEventSource (Android wrapper); five channel constants delegated 1:1
- `lib/features/tracking/services/main_isolate_tracking_engine.dart` — iOS main-isolate engine; injectable stream factory; stop-race guard; PII guard (grep verified)
- `lib/features/tracking/services/location_accuracy_gate.dart` — IOS-08 three-outcome gate; uses kPreciseCommutePurposeKey (no hardcoded literal)
- `lib/features/tracking/services/tracking_service_controller.dart` — added LocationAccuracyGate injectable; iOS preflight branch behind defaultTargetPlatform
- `lib/features/tracking/services/tracking_service.dart` — replaced inline AndroidSettings with buildLocationSettings()
- `ios/Runner/Info.plist` — NSLocationTemporaryUsageDescriptionDictionary + PreciseCommute key
- `test/unit/features/tracking/reduced_accuracy_gate_test.dart` — @Skip removed; 3 outcome tests GREEN
- `test/unit/features/tracking/ios_engine_stop_race_test.dart` — @Skip removed; 3 stop-race tests GREEN

---

## Decisions Made

- **Injectable positionStreamFactory** over real GPS in tests: synchronous `StreamController<Position>` lets the stop-race test deliver exactly one pre-stop and one post-stop sample without timing dependencies.
- **Injectable function types** for `LocationAccuracyGate` instead of a full `AccuracyService` abstract interface: two simple functions are sufficient for single-use testability; avoids speculative abstraction (CLAUDE.md).
- **`defaultTargetPlatform` throughout**: both the gate check in `start()` and `buildLocationSettings()` use `defaultTargetPlatform` (not `dart:io Platform.isIOS`) so the entire iOS branch is exercisable in unit tests.
- **`const Stream<Map<String, dynamic>?>.empty()` for onReady**: iOS has no fbs service-ready signal; onReady is statically empty. The TrackingNotifier (Plan 03) subscribes to it the same way — the subscription just never fires.

---

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria satisfied on first attempt.

---

## Issues Encountered

None.

---

## Known Stubs

None — all new code is fully functional. The iOS engine wires to the real `Geolocator.getPositionStream` and real `buildLocationSettings()` in production. Plan 03 wires `TrackingNotifier` to `TrackingEventSource`; until then the notifier still reads from `FlutterBackgroundService()` directly (existing behavior, unchanged).

---

## Threat Flags

No new threat surface beyond what was modeled in the plan's threat register:

| Flag | File | Description |
|------|------|-------------|
| T-02-07 (mitigated) | main_isolate_tracking_engine.dart | PII guard verified by grep: no `.latitude`, no `.longitude`, no `error.toString()`, no `print()` in source |
| T-14-02 (mitigated) | location_accuracy_gate.dart | Blocked outcome returns false (stable boolean), no raw platform text forwarded |
| T-14-03 (mitigated) | location_accuracy_gate.dart | All three gate outcomes proven by automated test; stream never opened with coarse accuracy |

## Self-Check: PASSED

- `lib/features/tracking/services/tracking_event_source.dart` — exists, no analyze issues
- `lib/features/tracking/services/main_isolate_tracking_engine.dart` — exists, no analyze issues
- `lib/features/tracking/services/location_accuracy_gate.dart` — exists, no analyze issues
- `ios/Runner/Info.plist` — plutil -lint OK; NSLocationTemporaryUsageDescriptionDictionary + PreciseCommute present
- Commits 62e4af4, 5b30c75, afa390d — verified in git log
- `flutter test test/unit/features/tracking/` — 71/71 PASS, 0 skipped
