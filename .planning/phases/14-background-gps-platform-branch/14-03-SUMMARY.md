---
phase: 14-background-gps-platform-branch
plan: "03"
subsystem: tracking/iOS-GPS
tags: [ios, android, riverpod, platform-branch, seam, IOS-06, IOS-07, IOS-08, regression-guard]
dependency_graph:
  requires:
    - phase: 14-02
      provides: "TrackingEventSource interface, FbsTrackingEventSource, MainIsolateTrackingEngine, LocationAccuracyGate"
  provides:
    - trackingEventSourceProvider (Provider<TrackingEventSource> — platform-selects iOS vs Android engine)
    - TrackingNotifier rewired to TrackingEventSource seam (4-channel subscription unchanged)
    - kTrackingReducedAccuracyBlockedMessage constant (IOS-08 stable user-facing message)
    - TrackingServiceController now accepts TrackingEventSource (source:) instead of FlutterBackgroundService
    - tracking_event_source_selection_test.dart (3 GREEN — both platform branches asserted)
    - Phase 14 validation signed off (nyquist_compliant: true)
  affects:
    - Phase 15 (iOS permission/notification UX — TrackingNotifier state machine is the shared entry point)
    - Any future engine substitution (trackingEventSourceProvider is the single swap point)
tech-stack:
  added: []
  patterns:
    - trackingEventSourceProvider as the single runtime platform switch (D-04) — one override point for both the notifier subscriptions and the controller start/stop
    - TrackingServiceController parameterised on TrackingEventSource instead of FlutterBackgroundService — decouples the controller from the fbs singleton and makes it engine-agnostic
    - FakeTrackingEventSource test double pattern — minimal TrackingEventSource impl with no-op streams/start/stop; used in both tracking_notifier_test and persist_finalized_trip_test to avoid MissingPluginException
key-files:
  created:
    - test/unit/features/tracking/tracking_event_source_selection_test.dart
  modified:
    - lib/features/tracking/providers/tracking_providers.dart
    - lib/features/tracking/services/tracking_service_controller.dart
    - lib/config/constants.dart
    - test/unit/features/tracking/tracking_notifier_test.dart
    - test/unit/features/tracking/persist_finalized_trip_test.dart
    - .planning/phases/14-background-gps-platform-branch/14-VALIDATION.md
key-decisions:
  - "IOS-08 distinct message: TrackingNotifier.start() branches on defaultTargetPlatform to choose kTrackingReducedAccuracyBlockedMessage (iOS gate blocked) vs 'Unable to start tracking' (generic Android/other) — keeps the T-02-07 PII guard and satisfies the stable-message requirement"
  - "TrackingServiceController.start() only posts the UX-03 notification on non-iOS — on iOS, CoreLocation shows its own indicator (D-07); calling showRecording() on iOS would be a no-op at runtime but is omitted for clarity"
  - "FakeTrackingEventSource pattern established as the canonical test double for TrackingEventSource — replaces FlutterBackgroundService() in every controller/notifier test"
requirements-completed: [IOS-06, IOS-07, IOS-08]
duration: 9min
completed: "2026-06-02"
---

# Phase 14 Plan 03: TrackingNotifier Seam Integration and Platform Selection Summary

**TrackingNotifier rewired from FlutterBackgroundService().on() to a platform-selected TrackingEventSource, with MainIsolateTrackingEngine on iOS and FbsTrackingEventSource on Android; IOS-08 stable accuracy-blocked message; 397/397 tests green.**

---

## Performance

- **Duration:** ~9 min
- **Started:** 2026-06-02
- **Completed:** 2026-06-02
- **Tasks:** 2
- **Files modified/created:** 7

---

## Accomplishments

- `trackingEventSourceProvider` (keepAlive `Provider<TrackingEventSource>`) platform-selects `MainIsolateTrackingEngine` on iOS and `FbsTrackingEventSource(FlutterBackgroundService())` on Android — the single runtime D-04 switch
- `TrackingNotifier._attach()` subscribes to `source.onState/onFinalized/onError/onReady` instead of four direct `FlutterBackgroundService().on(...)` calls; all four decode/persist/error-mapping bodies are byte-for-byte unchanged
- `TrackingServiceController` constructor now takes `source: TrackingEventSource` — `start()` calls `source.start()`, `stop()` calls `source.stop()`; shares the same instance as the notifier via the provider
- `kTrackingReducedAccuracyBlockedMessage` constant added to `constants.dart` with IOS-08 dartdoc; notifier's `start()` maps iOS gate-blocked false-return to this distinct message (T-02-07 preserved)
- `tracking_event_source_selection_test.dart` — 3 tests: iOS→MainIsolateTrackingEngine, Android→FbsTrackingEventSource, distinct instance types (T-14-06)
- Full suite: **397/397 tests GREEN** — D-08 Android regression guard satisfied
- 14-VALIDATION.md signed off: `nyquist_compliant: true`, all Wave 0/1/2 rows ✅

---

## Task Commits

1. **Task 1: Rewire TrackingNotifier to TrackingEventSource + platform-selection provider** — `7eba39d` (feat)
2. **Task 2: Platform-selection test + full-suite Android regression guard** — `dfe719b` (test)

---

## Files Created/Modified

- `lib/features/tracking/providers/tracking_providers.dart` — added `trackingEventSourceProvider`; rewired `_attach()` to `source.onState/onFinalized/onError/onReady`; updated `trackingServiceControllerProvider` to inject source; IOS-08 distinct error message in `start()`
- `lib/features/tracking/services/tracking_service_controller.dart` — constructor now takes `source: TrackingEventSource`; `start()` calls `source.start()`, posts notification only on non-iOS; `stop()` calls `source.stop()`; removed `FlutterBackgroundService` dependency and unused `tracking_service_events` import
- `lib/config/constants.dart` — added `kTrackingReducedAccuracyBlockedMessage` with IOS-08 dartdoc at Phase 14 section
- `test/unit/features/tracking/tracking_notifier_test.dart` — replaced `FlutterBackgroundService()` with `_FakeTrackingEventSource`; controller constructor updated to `source:`; added `trackingEventSourceProvider` override
- `test/unit/features/tracking/persist_finalized_trip_test.dart` — replaced `FlutterBackgroundService()` with `_FakeTrackingEventSource`; controller constructor updated to `source:`; added `_FakeTrackingEventSource` class
- `test/unit/features/tracking/tracking_event_source_selection_test.dart` — NEW: 3 tests asserting both platform branches and type distinctness
- `.planning/phases/14-background-gps-platform-branch/14-VALIDATION.md` — Wave 0 rows ✅, Wave 2 rows added, `nyquist_compliant: true`, approval signed off

---

## Decisions Made

- **IOS-08 distinct message via platform check in `start()`:** `TrackingNotifier.start()` checks `defaultTargetPlatform == TargetPlatform.iOS` when the controller returns `false` to surface `kTrackingReducedAccuracyBlockedMessage` vs the generic message. This is the minimal change — the controller's `false` return is already the gate result; the notifier owns the message mapping.
- **No notification on iOS in controller `start()`:** Added `if (defaultTargetPlatform != TargetPlatform.iOS)` guard around `showRecording()` in the controller, matching D-07 ("iOS does not use the Android foreground-service notification").
- **`_FakeTrackingEventSource` as canonical test double:** Both updated test files use an identical `implements TrackingEventSource` no-op class. This pattern replaces `FlutterBackgroundService()` in all controller/notifier tests and is now the established convention for this interface.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated persist_finalized_trip_test.dart controller construction**
- **Found during:** Task 1 (after changing TrackingServiceController constructor signature)
- **Issue:** `persist_finalized_trip_test.dart` passed `service: FlutterBackgroundService()` — no longer a valid parameter name after the refactor
- **Fix:** Added `_FakeTrackingEventSource` class; changed `service:` → `source: _FakeTrackingEventSource()` at both construction sites; removed `flutter_background_service` import; added `dart:async` import
- **Files modified:** `test/unit/features/tracking/persist_finalized_trip_test.dart`
- **Verification:** `flutter test test/unit/features/tracking/` — 71/71 GREEN
- **Committed in:** `7eba39d` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug introduced by constructor signature change)
**Impact on plan:** Necessary fix — the test file had the old constructor API. No scope creep; the fix applies the same `_FakeTrackingEventSource` pattern the plan called for in `tracking_notifier_test.dart`.

---

## Issues Encountered

None.

---

## Known Stubs

None — all new code is fully functional. `trackingEventSourceProvider` uses the real `MainIsolateTrackingEngine` and `FbsTrackingEventSource(FlutterBackgroundService())` in production. The iOS engine streams drive the existing `TrackingNotifier` state machine.

---

## Threat Flags

No new threat surface beyond what was modeled in the plan's threat register:

| Flag | File | Description |
|------|------|-------------|
| T-02-07 (preserved) | tracking_providers.dart | onError handlers still use stable strings only; no `error.toString()` forwarded through any path |
| T-14-05 (accepted) | constants.dart | `kTrackingReducedAccuracyBlockedMessage` is a static UI string — no PII or platform diagnostics |
| T-14-06 (mitigated) | tracking_providers.dart | Platform selection by `defaultTargetPlatform`; no external input can override; asserted by selection test |

## Self-Check: PASSED

- `lib/features/tracking/providers/tracking_providers.dart` — exists, `flutter analyze` 0 new issues
- `lib/features/tracking/services/tracking_service_controller.dart` — exists, `flutter analyze` 0 new issues
- `lib/config/constants.dart` — `kTrackingReducedAccuracyBlockedMessage` present
- `test/unit/features/tracking/tracking_event_source_selection_test.dart` — exists, 3 tests GREEN
- `grep -n "FlutterBackgroundService().on"` in providers → 0 results (notifier no longer subscribes to fbs directly)
- `flutter test test/unit/features/tracking/tracking_notifier_test.dart` → 5/5 PASS
- `flutter test` (full suite) → 397/397 PASS
- `flutter analyze` → 110 info issues (all pre-existing, 0 new)
- Commits 7eba39d, dfe719b — verified in git log
