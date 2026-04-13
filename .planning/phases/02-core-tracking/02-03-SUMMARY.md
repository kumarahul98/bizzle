---
phase: 02-core-tracking
plan: 03
subsystem: tracking
tags: [flutter, flutter_background_service, geolocator, riverpod, sealed-class, two-isolate, stop-race, d-14-unification]

# Dependency graph
requires:
  - phase: 02-core-tracking
    provides: "TrackingPermissionService (02-01), TripAccumulator + TripSnapshot + FinalizedTrip + Phase 2 constants including kTrackingNotificationChannelId / kTrackingNotificationId / kTrackingSampleInterval / kTrackingUiUpdateInterval (02-02)"
  - phase: 01-foundation
    provides: "manual Riverpod 3.x provider pattern (lib/database/providers.dart), very_good_analysis ^10 strict lint profile with strict-casts/strict-inference/strict-raw-types"
provides:
  - "Sealed TrackingState with five final variants (idle/starting/active/stopping/error) for exhaustive UI switches"
  - "trackingActiveFromSnapshotMap — single m/s → km/h conversion site at the service→UI isolate boundary"
  - "tracking_service.dart — @pragma('vm:entry-point') trackingServiceOnStart with TripAccumulator lifecycle, 1 Hz snapshot loop, stop-race guard"
  - "configureBackgroundService — AndroidConfiguration wired with D-14 unified notificationChannelId + foregroundServiceNotificationId"
  - "Local event-name constants kTrackingStateEvent / kTripFinalizedEvent / kStopTrackingEvent as the private service↔controller coupling contract"
  - "TrackingServiceController — thin UI-isolate wrapper with Location-Services pre-flight and kStopTrackingEvent invoke"
  - "Manual Riverpod 3.x trackingPermissionServiceProvider / trackingServiceControllerProvider / trackingStateProvider"
  - "TrackingNotifier — Notifier<TrackingState> subscribing to kTrackingStateEvent and kTripFinalizedEvent with ref.onDispose cancellation"
affects: [02-04-home-and-tracking-screen, 02-05-notification-and-persistence, 02-06-widget-tests]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-isolate architecture: TripAccumulator constructed EXCLUSIVELY inside the background isolate — the UI side only ever sees primitive-map snapshots (Pitfall 7 defused from day one)"
    - "Service↔UI isolate protocol as file-local constants (not in constants.dart) — prevents cross-feature leakage of an internal coupling"
    - "Stop-race guard: boolean flag set BEFORE stream cancel, checked as the first statement in the position listener (02-RESEARCH §8)"
    - "Unit conversion exactly once at the isolate boundary: accumulator keeps m/s for Pitfall-2-safe classification, trackingActiveFromSnapshotMap multiplies by 3.6 for UI display"
    - "Manual Riverpod 3.x Notifier with ref.onDispose-managed StreamSubscriptions matching the established lib/database/providers.dart pattern"
    - "Plan-handoff comments (not TODO markers) for documented cross-plan insertion points"

key-files:
  created:
    - lib/features/tracking/state/tracking_state.dart
    - lib/features/tracking/services/tracking_service.dart
    - lib/features/tracking/services/tracking_service_controller.dart
    - lib/features/tracking/providers/tracking_providers.dart
    - test/unit/features/tracking/tracking_state_map_test.dart
  modified: []

key-decisions:
  - "trackingActiveFromSnapshotMap is the one and only m/s → km/h conversion site in Phase 2 — the accumulator stays in m/s for Pitfall 2 safety, the UI gets km/h on demand"
  - "Event-name constants kTrackingStateEvent / kTripFinalizedEvent / kStopTrackingEvent live at the top of tracking_service.dart (not constants.dart) — they are a private coupling contract between two files and surfacing them globally would invite wrong reuse"
  - "TrackingError is NOT const — the constructor throws ArgumentError on empty message, which precludes a const constructor. Tests use `final TrackingError(...)` for construction instead of `const`"
  - "geolocator_android sub-package import dropped — AndroidSettings is re-exported by the top-level geolocator 14.0.2 package (unnecessary_import + depend_on_referenced_packages)"
  - "distanceFilter: 0 omitted from AndroidSettings — matches the LocationSettings default and would otherwise trigger avoid_redundant_argument_values under very_good_analysis"
  - "TrackingNotifier._attach wraps StreamSubscription.cancel in unawaited(...) inside ref.onDispose to satisfy discarded_futures — the subscriptions are per-provider-lifetime and cannot be re-entered"
  - "TrackingNotifier.start / stop guard against re-entry: start no-ops when state is Active/Starting; stop no-ops unless state is Active — defensive because the fbs invoke channel is async and the UI could plausibly fire both buttons rapidly"
  - "Plan 02-05 persistence hook is documented as a comment in the trip_finalized listener with an explicit state = const TrackingIdle() fallback so Phase 2 can be smoke-tested without persistence"

patterns-established:
  - "Sealed class state + helper adapter at an isolate boundary: sealed types live in lib/features/{feature}/state/, map-serde helpers sit next to them, and the single conversion site is the only place a unit changes"
  - "@pragma('vm:entry-point') on every top-level fbs entrypoint function (not just onStart) — documented in a file-level comment so future maintainers cannot accidentally remove one"
  - "File-local event-name constants for isolate protocols — prevents accidental global reuse while still giving both producer and consumer a single-source string"

requirements-completed: [TRACK-01, TRACK-02, TRACK-04, TRACK-05]

# Metrics
duration: ~25min
completed: 2026-04-12
---

# Phase 02 Plan 03: Service Isolate and Providers Summary

**Two-isolate machinery for Phase 2: sealed TrackingState, background-isolate trackingServiceOnStart with 1 Hz snapshot loop and stop-race guard, D-14 unified AndroidConfiguration, and a manual Riverpod 3.x provider graph binding TrackingNotifier to the service.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-12 (wave 2 of Phase 2)
- **Completed:** 2026-04-12
- **Tasks:** 3 (1 TDD RED→GREEN pair + 2 feat)
- **Files created:** 5 (4 lib + 1 test)
- **Files modified:** 0
- **Lines added:** ~650

## Accomplishments

- Landed the sealed `TrackingState` hierarchy (`TrackingIdle`, `TrackingStarting`, `TrackingActive`, `TrackingStopping`, `TrackingError`) with const singletons for the three empty variants and a non-const `TrackingError` that rejects an empty message via a constructor-body `ArgumentError`. Exhaustive `switch` with no `default` branch is now a compile-enforced property at every call site.
- `trackingActiveFromSnapshotMap` lives in the same file and is the single place in Phase 2 where m/s → km/h conversion happens for UI display. The accumulator (plan 02-02) still stores and compares speeds in m/s, so Pitfall 2 (comparing raw `Position.speed` against the km/h threshold) remains impossible by construction.
- Shipped `lib/features/tracking/services/tracking_service.dart`: a two-function background-isolate module with `trackingServiceOnStart` (subscribes to `Geolocator.getPositionStream` with `LocationAccuracy.high` + `intervalDuration: kTrackingSampleInterval`, pushes samples to `TripAccumulator`, emits 1 Hz snapshots via `service.invoke(kTrackingStateEvent, ...)`, applies a stop-race guard on the position listener) and `configureBackgroundService` (pins both `notificationChannelId: kTrackingNotificationChannelId` AND `foregroundServiceNotificationId: kTrackingNotificationId` per the D-14 unification contract so plan 02-05's real UX-03 notification collapses onto the fbs stock one).
- Both top-level functions carry `@pragma('vm:entry-point')` (Pitfall 4 release-mode tree-shake guard).
- Three local event-name constants (`kTrackingStateEvent`, `kTripFinalizedEvent`, `kStopTrackingEvent`) at the top of the service file define the private isolate-protocol coupling contract with the controller/notifier. They are deliberately not in `constants.dart` — surfacing them globally would invite unrelated features to reuse them.
- Shipped `TrackingServiceController`: thin UI-side wrapper that pre-flights `Geolocator.isLocationServiceEnabled()` before calling `FlutterBackgroundService().startService()`, and sends the stop command via `service.invoke(kStopTrackingEvent)`. Plan 02-05 will add `persistFinalizedTrip` to this class (documented in both file-level doc comments).
- Shipped `TrackingNotifier` + three manual Riverpod 3.x providers (`trackingPermissionServiceProvider`, `trackingServiceControllerProvider`, `trackingStateProvider`) following the exact pattern in `lib/database/providers.dart` — no `@riverpod` annotation, keepAlive-by-default via bare `Provider(...)` / `NotifierProvider(...)`. The notifier subscribes to both service events, cancels its two `StreamSubscription`s inside `ref.onDispose` via `unawaited(...)`, and guards `start` / `stop` against re-entry.
- Plan 02-05 persistence hook is marked with an explicit "Plan 02-05 hook" comment on the `trip_finalized` branch — the notifier currently transitions `TrackingStopping → TrackingIdle` without persistence so Phase 2 can be smoke-tested before plan 02-05 lands.
- Nine unit tests in `test/unit/features/tracking/tracking_state_map_test.dart` covering: const singletons, `TrackingError` empty-message rejection, `trackingActiveFromSnapshotMap` m/s → km/h conversion (27.777 → 100.0, int → double coercion, missing-key ArgumentError), and an exhaustive-switch compile gate.
- Full project `flutter analyze` clean. Full `flutter test` suite green (60 tests total across Phase 1 + Phase 2 wave 1 + this plan).

## Task Commits

| # | Task | Commit | Type |
|---|------|--------|------|
| 1a | Task 1 RED: failing tests for tracking state | `069af4f` | test |
| 1b | Task 1 GREEN: sealed TrackingState + adapter | `ae953d4` | feat |
| 2 | Task 2: background isolate entrypoint | `1b07dc9` | feat |
| 3 | Task 3: controller + Riverpod providers | `785b38c` | feat |

Each commit is atomic and signs off on a single concern. Commit messages use the `feat(02-03): ...` / `test(02-03): ...` prefix convention from CLAUDE.md's "One concern per commit" rule.

## Files Created/Modified

### Created

- `lib/features/tracking/state/tracking_state.dart` — Sealed `TrackingState` with five `final class` variants, `trackingActiveFromSnapshotMap` adapter, and a strict-casts-safe `_req<T>` helper matching the pattern in `TripSnapshot` / `FinalizedTrip`. 165 lines.
- `lib/features/tracking/services/tracking_service.dart` — Two-function background-isolate module: `trackingServiceOnStart` (Geolocator stream + accumulator + 1 Hz snapshot loop + stop-race guard) and `configureBackgroundService` (D-14 unified `AndroidConfiguration`). Three file-local event-name constants at the bottom. File-level doc comment explicitly warns against Flutter UI imports, `Position` logging, and removing `@pragma('vm:entry-point')`. 191 lines.
- `lib/features/tracking/services/tracking_service_controller.dart` — `TrackingServiceController` with `start()` (Location-Services pre-flight + `startService`) and `stop()` (`kStopTrackingEvent` invoke). Plan 02-05 persistence hook documented in class-level doc. 66 lines.
- `lib/features/tracking/providers/tracking_providers.dart` — Three manual Riverpod 3.x providers and `TrackingNotifier`. Subscribes to both service events, cancels subs via `unawaited(...)` inside `ref.onDispose`. Plan 02-05 persistence hook documented inline. 160 lines.
- `test/unit/features/tracking/tracking_state_map_test.dart` — Nine tests across four `group()` blocks. 133 lines.

### Modified

None — this plan is purely additive. No existing files were touched.

## Decisions Made

- **`TrackingError` is non-const.** The constructor throws `ArgumentError` on an empty message to enforce the "non-empty user-facing message" invariant the UI relies on. A non-const constructor is the cost; tests instantiate `TrackingError` with `final` / bare constructor instead of `const`. The other four variants stay const because they carry no payload.
- **`trackingActiveFromSnapshotMap` multiplies by 3.6 at exactly one site.** This is the hinge of the "m/s inside, km/h outside" contract. The alternative (converting inside `TripAccumulator.snapshot`) would leak km/h into the service isolate and force a round-trip conversion every time the accumulator needs to classify a sample against `kStuckSpeedThresholdMs`. Centralising at the boundary gives one grep target (`* 3.6`) for the unit change and keeps the service isolate unit-pure.
- **Event-name constants live in `tracking_service.dart`, not `constants.dart`.** They are the private coupling contract between the service and its wrapper/notifier. Surfacing them globally would invite feature code elsewhere to send `service.invoke('tracking_state', ...)` directly, which would bypass the controller and break the abstraction. File-level comment documents this rule explicitly.
- **Dropped the `package:geolocator_android/geolocator_android.dart` import.** `AndroidSettings` is re-exported by the top-level `geolocator` package in 14.0.2 (verified by grep on the pub-cache copy), so importing the sub-package directly triggered `unnecessary_import` + `depend_on_referenced_packages`. The single top-level import is enough.
- **Omitted `distanceFilter: 0` from `AndroidSettings`.** The parent `LocationSettings` default is `0`, so the explicit argument triggered `avoid_redundant_argument_values` under very_good_analysis. Added an inline comment stating that time-throttling via `intervalDuration` is deliberate and distance-throttling is disabled.
- **`unawaited(...)` for StreamSubscription cancellation in `ref.onDispose`.** The `discarded_futures` lint flags `_stateSub?.cancel()` inside a non-async callback. `unawaited` is the canonical fix and accurately captures the intent (the subscription is per-provider-lifetime, the cancel cannot be re-entered, and there is no failure path to handle).
- **`start` / `stop` re-entry guards in `TrackingNotifier`.** `start()` no-ops if state is `Active` or `Starting`; `stop()` no-ops unless state is `Active`. The fbs invoke channel is async and the UI could plausibly fire both buttons rapidly — this is a defensive guard, not a correctness requirement, but it makes the notifier trivially testable in isolation.
- **Plan 02-05 handoff is a comment, not a TODO.** CLAUDE.md forbids `// TODO` / stub placeholders. The `trip_finalized` listener currently transitions `TrackingStopping → TrackingIdle` without persistence, with an inline comment block labelled "Plan 02-05 hook" describing exactly what will go there. Phase 2 is smoke-testable without persistence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Lint] `unnecessary_import` + `depend_on_referenced_packages` on `package:geolocator_android/geolocator_android.dart`**
- **Found during:** Task 2 `flutter analyze`
- **Issue:** The plan's code block imported `package:geolocator_android/geolocator_android.dart` explicitly for `AndroidSettings`, but the top-level `geolocator` package re-exports that class (verified: `grep AndroidSettings /Users/coolman/.pub-cache/hosted/pub.dev/geolocator-14.0.2/lib/geolocator.dart`). Keeping both imports triggered two lint errors.
- **Fix:** Removed the `geolocator_android` import and rely on the `geolocator` package re-export. Zero functional change.
- **Files modified:** `lib/features/tracking/services/tracking_service.dart`
- **Commit:** `1b07dc9`

**2. [Rule 1 — Lint] `avoid_redundant_argument_values` on `distanceFilter: 0`**
- **Found during:** Task 2 `flutter analyze`
- **Issue:** `LocationSettings.distanceFilter` defaults to `0`. The plan's code block passed `distanceFilter: 0` explicitly for documentation, but very_good_analysis flagged it.
- **Fix:** Removed the argument and added an inline comment block explaining that time-throttling via `intervalDuration` is intentional and distance-throttling is deliberately disabled. Zero functional change.
- **Files modified:** `lib/features/tracking/services/tracking_service.dart`
- **Commit:** `1b07dc9`

**3. [Rule 1 — Lint] `discarded_futures` on StreamSubscription.cancel in ref.onDispose**
- **Found during:** Task 3 `flutter analyze`
- **Issue:** `_stateSub?.cancel()` and `_finalizeSub?.cancel()` inside the `ref.onDispose` callback returned `Future<void>`, which very_good_analysis flags as `discarded_futures` in a non-async function.
- **Fix:** Wrapped both calls in `unawaited(...)` from `dart:async`. Added `import 'dart:async';` to the top of the file. Accurately expresses "fire-and-forget cleanup" intent.
- **Files modified:** `lib/features/tracking/providers/tracking_providers.dart`
- **Commit:** `785b38c`

**4. [Rule 1 — Lint] `comment_references` + `lines_longer_than_80_chars` in `tracking_service_controller.dart`**
- **Found during:** Task 3 `flutter analyze`
- **Issue:** Two `[TrackingPermissionService.preflight]` doc references in the class-level and `start` doc could not be resolved because the controller does not import the permission service (and should not — it's a layering concern). Also the reference triggered a long-line lint.
- **Fix:** Rewrote both references in backtick form (`` `TrackingPermissionService.preflight` ``) and split the second reference across two lines. Semantic meaning preserved.
- **Files modified:** `lib/features/tracking/services/tracking_service_controller.dart`
- **Commit:** `785b38c`

**5. [Rule 1 — Lint] `missing_code_block_language_in_doc_comment` on TripSnapshot shape doc**
- **Found during:** Task 1 GREEN `flutter analyze`
- **Issue:** A triple-backtick code block in the `trackingActiveFromSnapshotMap` doc comment was missing a language tag.
- **Fix:** Added `` ```dart `` language tag. Zero content change.
- **Files modified:** `lib/features/tracking/state/tracking_state.dart`
- **Commit:** `ae953d4`

**6. [Rule 1 — Test Fix] `TrackingError` tests used `const`**
- **Found during:** Task 1 GREEN test run (after implementation)
- **Issue:** The initial RED test file constructed `const TrackingError('oops')` and `const TrackingError('x')`, but the final implementation's constructor throws `ArgumentError` on an empty message, which precludes a const constructor. The RED test had passed compile-check only because the symbol didn't exist yet.
- **Fix:** Replaced `const TrackingError(...)` with `final TrackingError(...)` / bare `TrackingError(...)` in both test sites. The "rejects empty message" test still passes unchanged (runtime assertion).
- **Files modified:** `test/unit/features/tracking/tracking_state_map_test.dart`
- **Commit:** `ae953d4`

---

**Total deviations:** 6 auto-fixed, all Rule 1 (lint / test adaptation). No architectural deviations. No scope changes. Every fix preserved the plan's semantic intent.

## Issues Encountered

- **None blocking.** All verification commands ran locally without sandbox interference (unlike plans 02-01 and 02-02 where the parallel-executor sandbox blocked `flutter pub get` / `flutter analyze` / `flutter test`). This executor's worktree allowed the full verification loop.
- **RED-then-GREEN tooling nuance.** The RED test I initially wrote used `const TrackingError(...)` in two places. This compiled (and failed) at RED because the symbol did not exist — the compiler never evaluated the const-ness of the non-existent constructor. GREEN then revealed the throwing constructor could not be const, and I fixed the test. The fix is documented in Deviation #6. Lesson captured for future TDD of classes with validating constructors: the RED test should not rely on `const` unless const-ness is itself the thing being locked in.

## User Setup Required

None. No external service configuration required. The plan is purely code.

## Next Phase Readiness

**Plan 02-04 (home + tracking screen) is unblocked.** It can now:
- Read `ref.watch(trackingStateProvider)` to drive the three live tiles (duration / distance / current speed in km/h via `TrackingActive`).
- Call `ref.read(trackingStateProvider.notifier).start()` / `.stop()` from the Start and Stop buttons.
- Call `ref.read(trackingPermissionServiceProvider).preflight()` from the Start button's pre-flight before `.start()`.
- Switch exhaustively on `TrackingState` to render idle / spinner / tiles / error banners — no default branch required.

**Plan 02-05 (notification + persistence) is unblocked.** It can now:
- Add `persistFinalizedTrip(FinalizedTrip trip)` to `TrackingServiceController` (file-level doc already documents this as the next addition).
- Call that method from the existing `trip_finalized` listener in `TrackingNotifier._attach` (the insertion point is already commented).
- Show its `flutter_local_notifications` notification with `kTrackingNotificationId` on `kTrackingNotificationChannelId` and Android will collapse it onto the fbs stock notification (D-14 contract already wired).
- Dismiss the notification from the `configureBackgroundService` / `trackingServiceOnStart` insertion points already commented.

**Plan 02-06 (widget tests)** can mock the notifier state directly by overriding `trackingStateProvider` in a `ProviderScope`.

## Self-Check

Verification of claims in this SUMMARY.

**Files created:**
- `lib/features/tracking/state/tracking_state.dart` — FOUND
- `lib/features/tracking/services/tracking_service.dart` — FOUND
- `lib/features/tracking/services/tracking_service_controller.dart` — FOUND
- `lib/features/tracking/providers/tracking_providers.dart` — FOUND
- `test/unit/features/tracking/tracking_state_map_test.dart` — FOUND

**Commits in git log:**
- `069af4f` test(02-03): add failing tests for tracking state sealed class — FOUND
- `ae953d4` feat(02-03): tracking state sealed class and snapshot adapter — FOUND
- `1b07dc9` feat(02-03): background isolate entrypoint with accumulator lifecycle — FOUND
- `785b38c` feat(02-03): tracking service controller and manual Riverpod 3.x providers — FOUND

**Tripwire greps (executed against the worktree):**
- `grep -c "@pragma('vm:entry-point')" lib/features/tracking/services/tracking_service.dart` → `3` (≥ 2 required, the third is a mention in a doc comment)
- `grep -c 'stopping = true' lib/features/tracking/services/tracking_service.dart` → `1` (race guard)
- `grep -c 'foregroundServiceNotificationId: kTrackingNotificationId' lib/features/tracking/services/tracking_service.dart` → `1` (D-14)
- `grep -c 'kBackgroundServiceNotificationId' lib/features/tracking/services/tracking_service.dart` → `0` (D-14 negative)
- `grep -rc '@riverpod' lib/features/tracking/providers/` → no annotated matches (manual providers only)
- `grep -c 'NotifierProvider<TrackingNotifier' lib/features/tracking/providers/tracking_providers.dart` → `2` (type parameter + constructor call on the same declaration)

**Verification commands:**
- `flutter analyze` → clean across the whole project
- `flutter test` → 60 tests passed (Phase 1 + Phase 2 wave 1 + 9 new Phase 2 wave 2 tests)
- `flutter test test/unit/features/tracking/tracking_state_map_test.dart` → 9 tests passed

## Self-Check: PASSED

---
*Phase: 02-core-tracking*
*Plan: 02-03 — service-isolate-and-providers*
*Completed: 2026-04-12*
