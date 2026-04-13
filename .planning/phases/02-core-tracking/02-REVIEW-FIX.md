---
phase: 02-core-tracking
fixed_at: 2026-04-12T00:00:00Z
review_path: .planning/phases/02-core-tracking/02-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 2: Code Review Fix Report

**Fixed at:** 2026-04-12
**Source review:** `.planning/phases/02-core-tracking/02-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (WR-01, WR-02, WR-03, WR-04)
- Fixed: 4
- Skipped: 0

Info-level findings IN-01 through IN-07 were out of scope per the
`critical_warning` fix profile and remain unaddressed.

## Fixed Issues

### WR-01: Geolocator position stream has no `onError` handler

**Files modified:**
- `lib/features/tracking/services/tracking_service.dart`
- `lib/features/tracking/services/tracking_service_events.dart`
- `lib/features/tracking/providers/tracking_providers.dart`

**Commit:** `9809a24`

**Applied fix:**
- Added an `onError` handler to `Geolocator.getPositionStream().listen(...)`
  in the service isolate. On error the handler sets the `stopping` flag,
  cancels the UI timer and the position subscription, invokes the new
  `kTrackingErrorEvent` channel with a stable short `{'reason':
  'position_stream_error'}` payload (PII guard per T-02-07 — raw
  `error.toString()` is NEVER forwarded because it may contain lat/lng
  coordinates), and calls `service.stopSelf()` to tear down the
  foreground service cleanly. `cancelOnError: true` ensures the
  subscription does not continue to emit after an error.
- Added the `kTrackingErrorEvent = 'tracking_error'` constant to
  `tracking_service_events.dart` alongside the existing three event
  constants, with a documenting comment covering the PII contract.
- Wired a third listener `_errorSub` in `TrackingNotifier._attach` that
  maps the `reason` tag to a user-facing string (`'position_stream_error'
  → 'Location unavailable. Tracking stopped.'`, default → `'Tracking
  stopped unexpectedly'`) and transitions state to `TrackingError`. The
  subscription is cancelled alongside the other two in `ref.onDispose`.

**Verification:**
- `flutter analyze lib/features/tracking/` — clean.
- Existing test `tracking_state_map_test.dart` still passes (no
  regression in `TrackingError` construction).

---

### WR-02: Notifier allows Start re-entry during the persist window

**Files modified:**
- `lib/features/tracking/providers/tracking_providers.dart`
- `test/unit/features/tracking/tracking_notifier_test.dart` (new file)

**Commit:** `900e8f8`

**Applied fix:**
- Replaced the boolean `start()` guard
  (`if (state is TrackingActive || state is TrackingStarting) return;`)
  with an exhaustive `switch` over every `TrackingState` variant. Only
  `TrackingIdle` and `TrackingError` (retry path) fall through to the
  start sequence; `TrackingStarting`, `TrackingActive`, and
  `TrackingStopping` all early-return. This closes the WR-02 re-entry
  window where a tap (or programmatic retry) during the post-
  `trip_finalized` persist await could bypass the guard and spawn a
  second tracking session over the first.
- Added a defense-in-depth check in the `_finalizeSub` listener: after
  `persistFinalizedTrip` resolves, `state = const TrackingIdle()` only
  fires if the state is still `TrackingStopping`. This prevents the
  listener from clobbering a concurrent `TrackingError` / `TrackingStarting`
  state transition driven by another handler.
- Created `test/unit/features/tracking/tracking_notifier_test.dart`
  with five behavioural tests exercising the guard:
  1. `start()` while state is `TrackingStopping` → controller never
     invoked, state unchanged. **This is the test the review explicitly
     asked for.**
  2. `start()` while state is `TrackingStarting` → no-op.
  3. `start()` while state is `TrackingActive` → no-op.
  4. `start()` from `TrackingIdle` → controller invoked, transitions
     through `TrackingStarting`.
  5. `start()` from `TrackingError` → retry path, controller invoked.
  The tests use a `_NoopNotifier` subclass that short-circuits `build()`
  to avoid the fbs `MissingPluginException`, plus a `_RecordingController`
  subclass of `TrackingServiceController` (with an in-memory Drift
  database, matching the `persist_finalized_trip_test.dart` pattern) to
  count `start`/`stop` calls.

**Verification:**
- `flutter analyze` — clean.
- `flutter test test/unit/features/tracking/tracking_notifier_test.dart`
  — 5/5 passing.

---

### WR-03: Notifier fbs subscriptions have no `onError`

**Files modified:**
- `lib/features/tracking/providers/tracking_providers.dart`

**Commit:** `3fcb82e`

**Applied fix:**
- Added `onError` callbacks to all three `service.on(...)` subscriptions
  (`_stateSub`, `_finalizeSub`, and the WR-01-introduced `_errorSub`).
  Each error handler:
  1. Calls a new private `_cancelSiblingSubs(except: ...)` helper that
     cancels every sibling subscription — once one fbs channel has
     errored we cannot trust the others to reflect reality, so we
     prevent zombie subscriptions from emitting further inconsistent
     events.
  2. Clears `_lastPersistResult` so the tracking screen's consume-once
     snackbar never surfaces a stale result after an error transition.
  3. Transitions state to `TrackingError` with a stable user-facing
     message (`'Tracking stream failed'` for `_stateSub`, `'Unable to
     finalize trip'` for `_finalizeSub`, and the same 'stream failed'
     message for `_errorSub`). PII guard: `error.toString()` is never
     forwarded.
- The `_cancelSiblingSubs` helper nulls the cancelled subscription
  fields so the `ref.onDispose` cleanup callback becomes a no-op on
  already-cancelled subs.

**Verification:**
- `flutter analyze lib/features/tracking/` — clean.
- Full tracking test suite still passes.

---

### WR-04: Stop button has no debounce — double-tap race

**Files modified:**
- `lib/features/tracking/providers/tracking_providers.dart`
- `test/widget/features/tracking/tracking_screen_test.dart`

**Commit:** `7ac406a`

**Applied fix:**
- `TrackingNotifier.stop()` now performs the state transition to
  `const TrackingStopping()` SYNCHRONOUSLY at the top of the method,
  BEFORE the `await` on the controller's `stop()`. The guard
  `if (state is! TrackingActive) return;` remains at the top. A
  double-tap lands both handlers in the same frame; the first tap
  passes the guard and flips state; the second tap hits the guard and
  short-circuits because the state is no longer `TrackingActive`. This
  guarantees `kStopTrackingEvent` reaches the service isolate exactly
  once per Stop click.
- Added a widget test
  (`Double-tapping Stop only fires a single persist cycle (WR-04 guard)`)
  in `tracking_screen_test.dart` that renders `TrackingActive`, taps
  Stop twice in rapid succession with NO `await tester.pumpAndSettle`
  between the taps (to simulate the same-frame double-tap), and asserts
  `notifier.persistFinalizedTripCallCount == 1`. The test's
  `_TestTrackingNotifier.stop()` override mirrors the production
  contract (guard, then synchronous transition, then counter
  increment) so it exercises the exact WR-04 pattern.

**Verification:**
- `flutter analyze` — clean.
- `flutter test test/widget/features/tracking/` — all tracking widget
  tests passing, including the new WR-04 double-tap test.

---

## Test Evidence

All four required test commands executed after the final commit:

- `flutter analyze` → **"No issues found!"** (2 s).
- `flutter test test/unit/features/tracking/` → **43/43 passing** —
  includes the 5 new `tracking_notifier_test.dart` WR-02 tests, plus
  `persist_finalized_trip_test`, `tracking_state_map_test`,
  `tracking_permission_service_test`, and `trip_accumulator_test`.
- `flutter test test/widget/features/tracking/` → **16/16 passing** —
  includes the new WR-04 double-tap widget test and the pre-existing
  `home_screen_test` and `tracking_screen_test` suites.
- `flutter test` (full suite) → **85/85 passing**.

## Commits

| Finding | Commit | Files |
|---|---|---|
| WR-01 | `9809a24` | `tracking_service.dart`, `tracking_service_events.dart`, `tracking_providers.dart` |
| WR-02 | `900e8f8` | `tracking_providers.dart`, `tracking_notifier_test.dart` (new) |
| WR-03 | `3fcb82e` | `tracking_providers.dart` |
| WR-04 | `7ac406a` | `tracking_providers.dart`, `tracking_screen_test.dart` |

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
