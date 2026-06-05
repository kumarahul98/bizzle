---
phase: 15-notifications-permissions-onboarding-ux-on-ios
plan: "05"
subsystem: ios-tracking
tags: [live-activity, activitykit, ios-13, live_activities, device_info_plus, riverpod, tracking]
dependency_graph:
  requires:
    - phase: "15-04"
      provides: "TraevyLiveActivity Widget Extension — ContentState struct with 7 fields (startDate: Double ms epoch)"
    - phase: "15-02"
      provides: "formatElapsed/formatStuck/formatDistance in lib/shared/utils/formatters.dart"
    - phase: "15-01"
      provides: "RED scaffold test/unit/features/tracking/live_activity_service_test.dart"
  provides:
    - "LiveActivityService: init/start/update/end/endAll with iOS-17 gate and traevy://stop url-scheme routing"
    - "liveActivityServiceProvider in tracking_providers.dart (keep-alive Riverpod Provider)"
    - "TrackingNotifier lifecycle wiring: start on first TrackingActive, update on 5s cadence, end on stop, endAll on idle"
  affects:
    - "Phase 16 device validation pass — Live Activity lock-screen/Dynamic Island + Stop button tap (human-gated UAT)"
tech-stack:
  added:
    - "live_activities: 2.4.9 — iOS Live Activity create/update/end/endAll + urlSchemeStream"
    - "device_info_plus: 13.1.0 — iOS version check for the iOS 17+ gate"
  patterns:
    - "Constructor-injected plugin seam for testability (LiveActivities? plugin)"
    - "iOS 17 gate: defaultTargetPlatform == iOS + areActivitiesSupported() + areActivitiesEnabled() + device_info_plus major >= 17"
    - "url-scheme exact-match host guard: data.host == 'stop' (T-15-11 ASVS V5)"
    - "All Live Activity plugin calls wrapped try/on Object {} — additive surface never blocks tracking (T-15-13)"
    - "5s Live Activity update cadence reuses kTrackingNotificationRefreshInterval — no new throttle constant (Assumption A2)"
    - "currentSpeedKmh / 3.6 reconverts to m/s for TripSnapshot at the isolate-boundary seam"

key-files:
  created:
    - lib/features/tracking/services/live_activity_service.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - lib/features/tracking/providers/tracking_providers.dart

key-decisions:
  - "startDate sent as double (millisecondsSinceEpoch.toDouble()) — matches Swift ContentState.startDate: Double; Codable bridge cannot decode Dart int as Swift Date (carried from 15-04)"
  - "Live Activity start triggered on TrackingStarting → TrackingActive transition (wasStarting flag) not in start() itself — avoids starting on mid-trip provider rebuild"
  - "currentSpeedKmh / 3.6 reconverts at the TripSnapshot construction site in _startLiveActivity and _maybeRefreshNotification — isolate boundary converts m/s → km/h, we reverse it for kStuckSpeedThresholdMs comparison"
  - "liveActivityServiceProvider.init() called from TrackingNotifier.build() via unawaited — the controller is available there and the url-scheme listener wires once per app lifetime"

requirements-completed: [IOS-13]

duration: 8min
completed: "2026-06-06"
---

# Phase 15 Plan 05: Dart Live Activity Bridge + Provider Lifecycle Wiring Summary

**live_activities plugin bridge (iOS 17+) with start/update/end/endAll lifecycle wired into TrackingNotifier on the existing 5s notification cadence, completing IOS-13 Dart half.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-06T10:48:52Z
- **Completed:** 2026-06-06T10:57:00Z
- **Tasks:** 2
- **Files modified:** 4 (pubspec.yaml, pubspec.lock, live_activity_service.dart, tracking_providers.dart)

## Accomplishments

- Added `live_activities:^2.4.9` and `device_info_plus:^13.1.0` to pubspec; `flutter pub get` clean.
- Created `LiveActivityService` with the full iOS-17-gated lifecycle (init/start/update/end/endAll), url-scheme Stop routing (T-15-11 exact-match guard), and 7-key `_contentState` map matching the Swift `ContentState` struct exactly.
- Wired `liveActivityServiceProvider` + all lifecycle calls into `TrackingNotifier` — start on first active snapshot, update on the 5s notification cadence, end on stop, endAll on idle (Pitfall 4 orphan cleanup).
- 15-01 RED scaffold `live_activity_service_test.dart` now GREEN (9/9); full tracking suite 95/95; full Dart suite 442/442.

## Task Commits

1. **Task 1: Add packages + LiveActivityService bridge** — `d917bd8` (feat)
2. **Task 2: Wire LiveActivityService into tracking providers lifecycle** — `abd1bc4` (feat)

## Files Created/Modified

- `lib/features/tracking/services/live_activity_service.dart` — Dart bridge: init/start/update/end/endAll + iOS-17 gate + traevy://stop url-scheme routing + 7-key _contentState
- `lib/features/tracking/providers/tracking_providers.dart` — liveActivityServiceProvider declaration + TrackingNotifier lifecycle wiring (start/update/end/endAll)
- `pubspec.yaml` — live_activities:2.4.9, device_info_plus:13.1.0 added
- `pubspec.lock` — resolved transitive deps

## Decisions Made

- **start() triggered at TrackingStarting → TrackingActive transition** (not from `TrackingNotifier.start()`): The `wasStarting` flag in the `_stateSub` listener fires `_startLiveActivity` only on the first snapshot arrival, avoiding a spurious second `createActivity` call if the provider rebuilds mid-trip.
- **currentSpeedKmh / 3.6 reconversion at TripSnapshot construction**: `TrackingActive.currentSpeedKmh` is km/h (converted at the isolate boundary in `trackingActiveFromSnapshotMap`). `LiveActivityService._contentState` compares against `kStuckSpeedThresholdMs` (m/s), so we convert back at the two TripSnapshot construction sites inside TrackingNotifier. This keeps the converter at the boundary and avoids leaking m/s into `TrackingActive`.
- **init() called from TrackingNotifier.build() via unawaited**: The controller is needed for the url-scheme listener; `build()` is the earliest point where `ref.read(trackingServiceControllerProvider)` is available. The url-scheme listener is wired once per notifier lifetime.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TrackingActive.currentSpeedMs vs currentSpeedKmh field name**
- **Found during:** Task 2 (provider wiring — flutter analyze)
- **Issue:** Plan's interface comment referenced `active.currentSpeedMs` but `TrackingActive` has `currentSpeedKmh` — the isolate-boundary unit conversion in `trackingActiveFromSnapshotMap` produces km/h. Using the wrong field would have caused `isMoving` to be always-false (km/h values are ~3.6x higher than m/s; the stuck threshold comparison would fail).
- **Fix:** Used `active.currentSpeedKmh / 3.6` to reconstruct m/s for TripSnapshot at both `_startLiveActivity` and `_maybeRefreshNotification` call sites.
- **Files modified:** `lib/features/tracking/providers/tracking_providers.dart`
- **Committed in:** abd1bc4 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug, field name mismatch)
**Impact on plan:** Fix was essential for correct `isMoving` state in the Live Activity ContentState. No scope creep.

## Issues Encountered

None beyond the auto-fixed field name deviation above.

## Known Stubs

None. All Live Activity lifecycle calls are fully wired. The `_contentState` map is populated with real data from `TripSnapshot`. On-device Live Activity rendering (lock-screen appearance, Dynamic Island behavior, Stop button tap triggering `traevy://stop`) is human-gated UAT per 15-VALIDATION.md — cannot be validated in Simulator (ActivityKit limitation). Deferred to combined Phase 15/16 device validation pass.

## Threat Flags

No new threat surface beyond the plan's threat model:
- T-15-11 mitigated: `data.host == 'stop'` exact-match guard in urlSchemeStream listener.
- T-15-12 mitigated: only pre-formatted aggregate strings in `_contentState`; raw lat/lng never bridged.
- T-15-13 accepted: all plugin calls wrapped `try/on Object {}`.

## Next Phase Readiness

Phase 15 is now complete (all 5 plans executed). Phase 16 (combined device validation pass) can proceed:
- Live Activity Dart bridge wired — on-device UAT: lock-screen/Dynamic Island appearance, Stop button traevy://stop callback, 5s update cadence in background.
- No Dart-side blockers.

---

*Phase: 15-notifications-permissions-onboarding-ux-on-ios*
*Completed: 2026-06-06*

## Self-Check: PASSED

| Item | Result |
|------|--------|
| `lib/features/tracking/services/live_activity_service.dart` | FOUND |
| `lib/features/tracking/providers/tracking_providers.dart` | FOUND |
| `liveActivityServiceProvider` in tracking_providers.dart | FOUND |
| `live_activities` in pubspec.yaml | FOUND |
| `device_info_plus` in pubspec.yaml | FOUND |
| Commit d917bd8 (Task 1: packages + service) | FOUND |
| Commit abd1bc4 (Task 2: provider wiring) | FOUND |
| live_activity_service_test.dart GREEN (9/9) | VERIFIED |
| Full Dart suite GREEN (442/442) | VERIFIED |
| flutter analyze lib/ — 0 new issues | VERIFIED |
