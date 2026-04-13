---
phase: 02-core-tracking
plan: 06
subsystem: tracking
tags: [flutter, widget-test, flutter_test, riverpod-override, sealed-class, device-checklist, phase-gate, d-10-snackbar, d-14-unification]

# Dependency graph
requires:
  - phase: 02-core-tracking
    provides: "TrackingScreen + HomeScreen + tracking layout widgets (02-04), sealed TrackingState (02-03), TrackingPermissionService.forTesting closure-injection seam (02-01), TrackingNotifier.setLastPersistResultForTesting @visibleForTesting seam + sealed PersistResult (02-05)"
  - phase: 01-foundation
    provides: "very_good_analysis ^10 strict lint profile, flutter_test bundled, manual Riverpod 3.x provider pattern"
provides:
  - "test/widget/features/tracking/tracking_screen_test.dart — 11 widget tests covering every TrackingState sealed variant, duration/distance/speed formatting edge cases, Start tap transition, and the D-10 short-trip snackbar end-to-end through ref.listen"
  - "test/widget/features/tracking/home_screen_test.dart — 4 widget tests covering Start CTA visibility, happy-path navigation to /tracking, permanentlyDenied settings dialog, and Open settings dispatch"
  - ".planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md — 11-row manual verification checklist for the phase-gate human verifier, covering every Android 14 runtime behaviour the widget test framework cannot exercise"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Test-only Notifier subclass that overrides `build()` to skip plugin-touching subscriptions — the production notifier's `_attach` wires `FlutterBackgroundService().on(...)` streams which crash widget tests with MissingPluginException. Subclassing + overriding `build` is the cleanest way to get a Riverpod Notifier that can be driven synchronously from a widget test without touching the plugin surface."
    - "Closure-based permission fake via `TrackingPermissionService.forTesting(...)` — the plan 02-01 seam accepts raw `PermissionStatus` probe/requester closures, so widget tests do not need mocktail/mockito and the per-test harness is a single record-returning function."
    - "ProviderScope override with `trackingStateProvider.overrideWith(_TestNotifier.new)` — Riverpod 3.x NotifierProvider override semantics accept a notifier constructor tear-off, which keeps the test's provider graph identical to production apart from the notifier implementation."
    - "Manual device checklist as a committed markdown artefact (not a prose paragraph) — every row has an objective + steps + expected result + explicit result cell, so the human verifier is an executor, not an interpreter."

key-files:
  created:
    - test/widget/features/tracking/tracking_screen_test.dart
    - test/widget/features/tracking/home_screen_test.dart
    - .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md
  modified: []

key-decisions:
  - "Scoped `_TestTrackingNotifier.initialState` as a public mutable field instead of a setter-and-method pair. very_good_analysis rejects both `set initialState` without a getter (`avoid_setters_without_getters`) AND `void seedInitialState(...)` as `use_setters_to_change_properties`. A public final-less field is the only lint-clean seeding mechanism Riverpod's notifier override pattern supports."
  - "The `_IdleTrackingNotifier` in home_screen_test.dart is a separate subclass from `_TestTrackingNotifier` in tracking_screen_test.dart. The navigation test only needs a notifier that does not crash on build; reusing the full-featured test notifier would have tied the two files together for no testing benefit."
  - "Test (f) and (g) in the plan body were merged into two parallel `testWidgets` because the analyzer does not allow a single test to drive two non-const `TrackingActive` instances with reseat via notifier.state without pumping between — the cleaner split is one test per rounding boundary case, pumping between for the 0.3 → '0 km/h' clamp inside the same test case to exercise state reuse."
  - "`textContaining('km')` as a negative assertion in the distance-formatting test produced a false positive because the speed tile legitimately contains 'km/h'. Switched to asserting the exact km-formatted value (`find.text('0.45 km')`) is absent, which is the correct contract."
  - "Device checklist is 11 rows rather than the 8 in RESEARCH §14 because the plan's `<important_constraints>` explicitly enumerated additional Android 14 behaviours (Stop from notification shade, kill + relaunch no-ghost invariant, single-notification tripwire) that §14 did not call out individually. Splitting them makes each row independently verifiable by the human, which is the point of a checklist artefact."
  - "The `setLastPersistResultForTesting` seam is used via `class _TestTrackingNotifier extends TrackingNotifier` — the subclass inherits the public `@visibleForTesting` method without any production code mutation. `lib/features/tracking/providers/tracking_providers.dart` is unmodified by this plan (0 lines of diff vs base)."
  - "Two `await tester.pump()` calls are used in the snackbar test rather than `pumpAndSettle`: the first flushes the simulated state transitions and the `ref.listen` callback that schedules the SnackBar entry, and the second lets the ScaffoldMessenger build the SnackBar widget. `pumpAndSettle` would also work but hides the two-step nature of the listener + frame schedule."

patterns-established:
  - "Widget-test harness convention for the tracking feature: per-test ProviderScope overrides + a minimal MaterialApp or MaterialApp.routes + a hand-rolled Notifier subclass where the production notifier touches platform channels. Future phase plans that test Notifier-backed screens should follow this pattern instead of reaching for mockito."
  - "Device checklist markdown template: frontmatter with tripwires, prerequisites section, one numbered row per objective, explicit Results table, sign-off block, resume-signal instructions. Any future phase that needs a manual verification gate should copy this layout."

requirements-completed: [TRACK-01, TRACK-02, UX-03]

# Metrics
duration: ~35min
completed: 2026-04-12
---

# Phase 02 Plan 06: Widget Tests and Device Checklist Summary

**Widget-level coverage for every sealed TrackingState variant rendered through TrackingScreen, the HomeScreen permission-dialog path driven by `TrackingPermissionService.forTesting`, the D-10 short-trip snackbar exercised end-to-end through `ref.listen`, and an 11-row manual device verification checklist that is the phase gate for Phase 2. Zero production code changes.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-12 (wave 5 of Phase 2)
- **Completed:** 2026-04-12
- **Tasks:** 3 (2 test tasks + 1 checklist artefact task)
- **Files created:** 3 (2 widget test files + 1 markdown checklist)
- **Files modified:** 0 (production code entirely untouched)
- **Lines added:** ~730 (292 + 183 + 255)

## Accomplishments

- Landed `test/widget/features/tracking/tracking_screen_test.dart` with
  **11 widget tests** covering:
  - **TrackingIdle** — asserts the three tile labels render, the three
    zero-valued tile values render (`00:00`, `0 m`, `0 km/h`), the
    Start FilledButton is present, and the Stop FilledButton is
    absent.
  - **TrackingStarting** — asserts a `CircularProgressIndicator`, the
    "Starting GPS..." status label, and the absence of the Stop
    button.
  - **TrackingActive** — asserts the elapsed-seconds → `MM:SS`
    formatting at 125 seconds rendering as `02:05`, the
    distance-meters → km formatting at 2340 m rendering as
    `2.34 km`, the speed rendering as `27 km/h`, and the Stop
    FilledButton presence.
  - **Elapsed ≥ 3600 formats as `HH:MM:SS`** — 3725 seconds renders as
    `01:02:05`.
  - **Distance < 1000 m as integer meters** — 450 m renders as `450 m`
    and a negative assertion rules out the alternate `0.45 km` form.
    (The initial negative assertion used `textContaining('km')`, which
    matches the speed tile's `km/h` substring and failed; switched to
    asserting `find.text('0.45 km')` is absent.)
  - **Speed rounds correctly at the 9.4 / 9.6 boundary and clamps to 0
    below 0.5** — two testWidgets covering `9.4 → '9 km/h'`,
    `9.6 → '10 km/h'`, and a state-reseat `0.3 → '0 km/h'`.
  - **TrackingStopping** — asserts `Saving trip...` + a spinner + no
    Stop button.
  - **TrackingError** — asserts the custom message renders and a Retry
    FilledButton is present.
  - **Start tap transitions `TrackingIdle` → `TrackingStarting`** —
    uses `_TestTrackingNotifier.startCallCount` and asserts the
    `CircularProgressIndicator` appears after a single
    `tester.pump()` frame.
  - **Short-trip snackbar** — drives the exact state sequence a real
    `trip_finalized` listener produces on a short trip (Active →
    Stopping → Idle), injects `PersistDiscardedTooShort` via the
    `setLastPersistResultForTesting` seam inherited from plan 02-05,
    and asserts `find.text('Trip too short to save')` resolves after
    two `pump` frames.

- Landed `test/widget/features/tracking/home_screen_test.dart` with
  **4 widget tests** covering:
  - **Start CTA visibility** — asserts the FilledButton with
    'Start commute' is present after a fullyGranted pump.
  - **fullyGranted → /tracking navigation** — pumps with
    `MaterialApp.routes: kAppRoutes`, taps Start commute, pumps three
    times (two explicit + one `pumpAndSettle`) to flush the async
    currentStatus microtask + Navigator.pushNamed transition, and
    asserts `TrackingScreen` is now in the widget tree while
    `HomeScreen` is not.
  - **permanentlyDenied → dialog instead of navigation** — asserts
    the `Location permission denied` dialog title, the `Open settings`
    FilledButton in the dialog, the absence of `TrackingScreen`, and
    zero calls to the fake's open-settings counter.
  - **Dialog Open settings → `openSystemSettings()` dispatch** — taps
    the dialog button and asserts exactly one recorded call to the
    fake's `opener` closure while the dialog is dismissed and
    navigation did NOT happen.

- Landed `.planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md` with
  **11 rows** covering every Android 14 runtime behaviour the widget
  test framework cannot exercise: fresh-install permission denial, D-07
  two-step permission upgrade, background location upgrade on first
  Start, live-tile ticking with real GPS samples, UX-03 foreground
  notification with Stop action and the D-14 single-entry tripwire,
  in-app Stop persistence with optional Drift verification via
  `adb shell run-as`, D-10 short-trip discard with exact snackbar
  copy, background survival through home-button and screen-off,
  Stop-from-notification-shade dispatch through the
  `@pragma('vm:entry-point')` background handler, kill-and-relaunch
  no-ghost invariant per D-06, and a repeat of the backgrounded flow
  with battery optimisation set to Unrestricted. Each row is
  independently verifiable with an explicit objective. The trailing
  Results table and Sign-off block are the artefact the human verifier
  fills in before the phase can be declared complete.

- `flutter analyze` — clean across the entire project. **No issues
  found.**
- `flutter test` — **all 79 tests green** (60 prior Phase 1 / Phase 2
  waves 1-3 + 4 plan 02-05 persist tests + 15 new plan 02-06 widget
  tests).

## Task Commits

| # | Task | Commit | Type |
|---|------|--------|------|
| 1 | Task 1: TrackingScreen widget tests | `367d860` | test |
| 2 | Task 2: HomeScreen widget tests | `d375baf` | test |
| 3 | Task 3: Device checklist artefact | `1477667` | docs |

Each commit is atomic and addresses a single artefact. Commit messages
use the `test(02-06): ...` / `docs(02-06): ...` prefix convention from
CLAUDE.md's "One concern per commit" rule.

## Files Created/Modified

### Created

- `test/widget/features/tracking/tracking_screen_test.dart` (292
  lines) — 11 widget tests + a private `_TestTrackingNotifier`
  subclass + a `_grantedPermissionService()` helper + a
  `_pumpTrackingScreen` harness. The notifier subclass overrides
  `build()` to skip the production `_attach` call (which would
  subscribe to `FlutterBackgroundService().on(...)` streams and crash
  the test isolate), and uses `TrackingState initialState` as a
  public mutable field to seed the initial state per test. `start`
  is overridden to increment a counter and transition to
  `TrackingStarting` without reaching the controller.
  `simulateDiscard` uses the inherited `setLastPersistResultForTesting`
  seam from plan 02-05 to drive the exact state sequence a real
  `trip_finalized` listener produces on a short trip, then flushes
  two frames for the `ref.listen` callback and the ScaffoldMessenger.

- `test/widget/features/tracking/home_screen_test.dart` (183 lines) —
  4 widget tests + a private `_IdleTrackingNotifier` subclass + a
  `_buildFakePermissionService` harness that maps a
  `TrackingPermissionStatus` back to a `permission_handler`
  `PermissionStatus` and records open-settings calls via a closure
  counter. The harness returns a record type
  `({TrackingPermissionService service, int Function() openSettingsCalls})`
  so tests can both override the provider and later assert call
  counts on the same instance. Uses `MaterialApp.routes: kAppRoutes`
  so the navigation test goes through the real named-route table
  while overriding `trackingStateProvider` with the no-op notifier
  (which prevents TrackingScreen's `initState` from crashing the
  test isolate when it runs the preflight and subscribes to fbs
  streams).

- `.planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md` (255
  lines) — frontmatter with phase/plan/artifact/tripwires, a
  Prerequisites section with exact `adb install` / `pm clear`
  commands, 11 numbered checklist rows with steps + objectives, a
  Results table (11 rows, values `TBD by human verifier`), a
  Sign-off block (device model, Android version, APK commit SHA,
  date, verifier name), and a Resume-signal block with exact
  approved / failed / skipped response shapes.

### Modified

**None.** `lib/features/tracking/providers/tracking_providers.dart` is
the file the plan explicitly forbade touching, and
`git diff b684b25f7150d2180d222f7342c99904bf897db3..HEAD -- lib/features/tracking/providers/tracking_providers.dart`
is empty at the tip of this plan. The `setLastPersistResultForTesting`
seam and the `PersistResult` sealed class are both inherited unchanged
from plan 02-05.

## Decisions Made

- **Public mutable field for test-notifier seeding.**
  `_TestTrackingNotifier` needs a way to set the "initial state this
  build call should return". very_good_analysis rejects both
  `void seedInitialState(TrackingState initial)` (fires
  `use_setters_to_change_properties`) AND `set initialState(...)`
  without a getter (fires `avoid_setters_without_getters`). The
  third option — a public mutable field `TrackingState initialState`
  — is lint-clean and the simplest thing that could work. The field
  is only written from the test file's private harness function, so
  the mutability does not leak beyond the test scope.

- **`_IdleTrackingNotifier` is a separate class from
  `_TestTrackingNotifier`.** The navigation test in
  `home_screen_test.dart` only needs a notifier whose `build()` does
  not crash — it never drives state transitions. Sharing
  `_TestTrackingNotifier` across both files would couple the tests and
  force the home-screen test to import through the tracking-screen
  test file or hoist the helper into a `test/support/` folder that
  does not yet exist. A 6-line `class _IdleTrackingNotifier extends
  TrackingNotifier { @override TrackingState build() => const
  TrackingIdle(); }` is cheaper and keeps the two test files
  independently runnable.

- **Distance-formatting test uses an exact-match negative
  assertion.** The initial draft used
  `find.textContaining('km')` to assert the km-formatted variant was
  absent; this matched the speed tile's `18 km/h` and failed. The
  contract is "the distance tile renders `450 m` and NOT the
  alternate `0.45 km` form" — so the negative assertion is
  `find.text('0.45 km')` is absent plus a regex-based sanity check
  on the distance-in-km pattern. This matches the actual formatting
  rule in `distance_tile.dart` exactly.

- **Two explicit `pump` frames instead of `pumpAndSettle` in the
  snackbar test.** The D-10 snackbar test drives three state
  transitions synchronously (`TrackingActive → TrackingStopping →
  TrackingIdle`) and expects the `ref.listen` callback to fire on the
  `Stopping → Idle` edge, consume the persist result, and show the
  SnackBar via `ScaffoldMessenger`. Two explicit `pump`s document
  the two-step schedule (listener + ScaffoldMessenger frame)
  precisely; `pumpAndSettle` would also work but hides the ordering
  contract that is the actual thing being tested.

- **11 checklist rows, not 8.** RESEARCH §14 lists 8 high-level
  manual steps. The plan's `<important_constraints>` enumerated
  additional Android 14 behaviours that are not individually called
  out in §14 — the D-14 single-notification tripwire (explicit
  assertion that there is NEVER a second entry), the Stop-from-shade
  handler (separate from the in-app Stop), the kill-and-relaunch
  no-ghost invariant (D-06 acceptance test), and the OEM-battery
  optimisation repeat. Splitting these into their own rows makes
  each of them independently pass/fail-able by the human verifier,
  which is the whole point of a checklist artefact.

- **Named `currentStatus` in HomeScreen's flow, not `preflight`.**
  HomeScreen uses `service.currentStatus()` (not `preflight()`) from
  its Start-tap handler — this is important for the test fake because
  `currentStatus` only calls the probe closure, never the requester.
  The fake's `requester` closure is therefore unreachable in the
  HomeScreen tests even though the harness builds one; this matches
  HomeScreen's real-world behaviour of not prompting from the home
  screen (the prompt happens inside TrackingScreen's `initState`
  preflight).

- **`setLastPersistResultForTesting` is inherited, not duplicated.**
  The plan was unambiguous that the seam is added by plan 02-05 and
  MUST NOT be re-added here. Verified via
  `git diff b684b25f7150d2180d222f7342c99904bf897db3..HEAD --
  lib/features/tracking/providers/tracking_providers.dart` returning
  empty, and `grep -c 'setLastPersistResultForTesting'
  lib/features/tracking/providers/tracking_providers.dart` returning
  2 (one doc comment reference + one method declaration), both from
  plan 02-05's commit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Lint] `<Override>[...]` explicit type annotation is not a Dart type**
- **Found during:** Task 1 first `flutter test` run
- **Issue:** The initial draft annotated the overrides list as
  `overrides: <Override>[...]` — `Override` is not a Riverpod 3.x
  type name. The compiler rejected it with `'Override' isn't a type`.
- **Fix:** Dropped the explicit type annotation; Dart's inference
  produces `List<Override>` (the Riverpod 3.x private type) from the
  override function return types. Zero semantic change.
- **Files modified:** `test/widget/features/tracking/tracking_screen_test.dart`
- **Commit:** `367d860`

**2. [Rule 1 — Test Fix] `textContaining('km')` negative assertion hit the speed tile**
- **Found during:** Task 1 first `flutter test` run
- **Issue:** The "Distance < 1000 m formats as integer meters" test
  used `find.textContaining('km')` as a negative assertion, which
  matched the speed tile's `18 km/h` value and failed the test with
  "one was found but none were expected".
- **Fix:** Replaced the broad negative assertion with two narrow
  ones: `find.textContaining(RegExp(r'\d \.\d+ km$'))` (distance-in-km
  pattern) and `find.text('0.45 km')` (the exact value the distance
  tile would have rendered for this test's fixture if the formatting
  rule were wrong). Both are absent, proving the distance tile chose
  the integer-meters branch.
- **Files modified:** `test/widget/features/tracking/tracking_screen_test.dart`
- **Commit:** `367d860`

**3. [Rule 1 — Lint] `comment_references` + `use_setters_to_change_properties` + `avoid_setters_without_getters` on the test-notifier seeding API**
- **Found during:** Task 1 first `flutter analyze` run
- **Issue:** Initial draft used `void seedInitialState(...)` plus a
  `_initialState` private field. `comment_references` flagged the
  `[seedInitialState]` docstring link (the brackets didn't resolve
  to a visible symbol); `use_setters_to_change_properties` flagged
  the method as "converts a single field → should be a setter". I
  tried converting to `set initialState(...)` without a getter, which
  then fired `avoid_setters_without_getters`. Solution: make the
  field itself public and mutable — `TrackingState initialState =
  const TrackingIdle();`. Tests seed via `_TestTrackingNotifier()
  ..initialState = state`. All three lints are satisfied, the field
  is only written from the test-file-private `_pumpTrackingScreen`
  helper so mutability does not leak, and the doc comment references
  it in backtick form.
- **Files modified:** `test/widget/features/tracking/tracking_screen_test.dart`
- **Commit:** `367d860`

**4. [Rule 1 — Lint] `lines_longer_than_80_chars` on two `expect` statements in the HomeScreen test**
- **Found during:** Task 2 first `flutter analyze` run
- **Issue:** Two `expect(find.widgetWithText(FilledButton, 'Open
  settings'), findsOneWidget);` lines exceeded 80 characters.
- **Fix:** Split each statement across three lines using the standard
  `expect(\n  finder,\n  matcher,\n);` form. Zero semantic change.
- **Files modified:** `test/widget/features/tracking/home_screen_test.dart`
- **Commit:** `d375baf`

---

**Total deviations:** 4 auto-fixed (1 Rule 1 compile fix + 3 Rule 1
lint fixes). Zero architectural deviations. Zero scope drift. Every
fix preserved the plan's semantic intent and the test contracts
written in the task bodies.

## Issues Encountered

- **None blocking.** All verification commands ran locally in the
  worktree without sandbox interference. The full `flutter analyze`
  is clean and the full `flutter test` suite (79 tests) is green.
- **Lint-harness iteration on the test-notifier seeding mechanism.**
  very_good_analysis rejected three separate attempts at a seeding
  API (method, setter, then finally a public mutable field).
  Documented in Deviation #3. Lesson captured: when writing a
  Riverpod notifier subclass that needs to accept configuration
  before `build()` runs, prefer a public mutable field over a method
  or a setter — the combination of `use_setters_to_change_properties`
  and `avoid_setters_without_getters` leaves the field as the only
  lint-clean option.

## User Setup Required

**None for the test code.** For the device checklist row execution,
the human verifier needs:

- A real Android 14 device (API 34) with Developer Options and USB
  debugging enabled.
- `adb` on the host (bundled with Android Studio / SDK Platform Tools).
- Optional: `sqlite3` on the host if performing the Drift dump in
  step 6. If the DAO dump path is unavailable, step 6 can be verified
  indirectly by confirming step 7's short-trip-discard tripwire: if
  the "too short" row does not appear and the next normal trip does
  appear, persistence is working.

## Next Phase Readiness

**Phase 2 is code-complete.** Every plan in the phase (02-01 through
02-06) has landed its artefacts, all unit and widget tests are green,
and the manual device checklist is committed as a reviewable
markdown artefact.

**The phase is NOT yet phase-complete.** Task 3 of this plan is a
`checkpoint:human-verify` gate — the phase cannot be declared done
until the human verifier walks through
`02-DEVICE-CHECKLIST.md` on a real Android 14 device and marks every
row `PASS`. The orchestrator is expected to surface the checkpoint to
the user for manual execution.

**If the checkpoint fails** (any row is `FAIL`), the orchestrator
should route the specific failure into a gap-closure plan. Common
failure modes and the plans they would route to:

- GPS tiles never tick → plan 02-02 or 02-03 (accumulator or service
  isolate wiring).
- Notification does not appear or is dismissible → plan 02-05
  (notification wrapper / D-14 unification).
- Two notifications appear → `kTrackingNotificationChannelId` /
  `kTrackingNotificationId` constant drift between plan 02-03's
  `configureBackgroundService` and plan 02-05's
  `TrackingNotificationService`.
- Short-trip discard fails → plan 02-05's `persistFinalizedTrip`
  threshold guard.
- Kill + relaunch shows a ghost state → plan 02-03's `TrackingNotifier`
  `build` initial state.

**If the checkpoint is skipped** (device unavailable), record the
skip as a deviation in STATE.md and schedule a follow-up verification
task for when a device becomes available. Shipping Phase 2 with only
emulator + unit test coverage is NOT recommended per CLAUDE.md's
"Test on real Android devices for GPS and background service
behavior" rule.

## Self-Check

Verification of claims in this SUMMARY.

**Files created:**
- `test/widget/features/tracking/tracking_screen_test.dart` — FOUND
- `test/widget/features/tracking/home_screen_test.dart` — FOUND
- `.planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md` — FOUND

**Files NOT modified (tripwire check):**
- `lib/features/tracking/providers/tracking_providers.dart` — UNMODIFIED vs base (`git diff b684b25f7150d2180d222f7342c99904bf897db3..HEAD -- lib/features/tracking/providers/tracking_providers.dart` returns empty)

**Commits in git log:**
- `367d860` test(02-06): add TrackingScreen widget tests for every sealed state — FOUND
- `d375baf` test(02-06): add HomeScreen widget tests for permission-dialog path — FOUND
- `1477667` docs(02-06): add manual device verification checklist for Phase 2 — FOUND

**Tripwire greps (executed against the worktree):**
- `grep -c 'setLastPersistResultForTesting' lib/features/tracking/providers/tracking_providers.dart` → `2` (doc + method decl, both inherited from plan 02-05)
- `git diff ... -- lib/features/tracking/providers/tracking_providers.dart | wc -l` → `0` (providers file untouched by this plan)

**Verification commands:**
- `flutter analyze` → clean across the whole project. **No issues found.**
- `flutter test` → **79 tests passed** (60 prior + 4 persist + 15 new widget tests).
- `flutter test test/widget/features/tracking/` → 15 tests passed (11 TrackingScreen + 4 HomeScreen).

## Self-Check: PASSED

---
*Phase: 02-core-tracking*
*Plan: 02-06 — widget-tests-and-device-checklist*
*Completed: 2026-04-12*
