---
plan_id: 08-08
phase: 08
gap_closure: true
status: complete
completed: 2026-05-15
commits:
  - 8c0f3ce
---

## Plan 08-08 — Single-screen recording (HeroRecordCard absorbs active state)

Closes Phase 8 UAT gaps:
- **Gap 1:** Tapping START on the dashboard hero starts the commute IN PLACE — the hero card transforms to show the active recording UI (RECORDING badge + direction label + ELAPSED timer + DISTANCE/SPEED/STUCK tiles + Stop and save button) without navigating to a separate screen.
- **Gap 4:** App remains fully usable while a commute is recording — user can scroll the dashboard, swap to Trips/Stats/Settings tabs, and view trip history without interrupting the active recording.

### What changed

**`lib/features/dashboard/widgets/hero_record_card.dart`** — full rewrite
- Now a `ConsumerWidget` that watches `trackingStateProvider`.
- Switches over the sealed `TrackingState` (Idle / Starting / Active / Stopping / Error) and renders the appropriate layout in place inside the same Card chrome.
- Reuses the existing primitives: `RecordingHeader`, `ElapsedDisplay`, `TrackingTilesRow`, `StopButton`, `TrackingErrorLayout`, `TrackingStatusLayout`.
- Per-state layouts extracted as private subwidgets (`_HeroIdle`, `_HeroActive`, `_AutoLabelRow`) to keep the public widget surface clean.
- Lifted the persist-result snackbar (`PersistSaved` / `PersistDiscardedTooShort` / `PersistFailed`) from the deleted `TrackingScreen.build` via `ref.listen` on the `Stopping → Idle` edge.

**`lib/features/dashboard/screens/dashboard_screen.dart`**
- `_handleStart` now calls `ref.read(trackingStateProvider.notifier).start()` (fire-and-forget via `unawaited()`) instead of `Navigator.pushNamed(kRouteTracking)`. Permission preflight branches unchanged.
- Removed `kRouteTracking` import and the `isTracking` parameter passed to `HeroRecordCard` (the hero now derives state directly).

**`lib/features/dashboard/widgets/in_progress_card.dart`**
- Removed `Navigator.of(context).pushNamed(kRouteTracking)` `onTap` handler — there is no separate tracking screen to navigate to.
- Removed the `InkWell` wrapper entirely (with `onTap: null` it served no purpose). The card remains visually present as a redundant in-progress affordance below `TodaySection` for users scrolled past the hero.

**`lib/config/routes.dart`**
- Deleted `kRouteTracking` constant.
- Removed `TrackingScreen` import.
- Removed the `kRouteTracking → TrackingScreen` entry from `kAppRoutes`.

### Files deleted

- `lib/features/tracking/screens/tracking_screen.dart` — superseded by HeroRecordCard's stateful layout.
- `lib/features/tracking/widgets/tracking_idle_layout.dart` — historical "second tap to start" idle surface; the hero is now the only Idle entry surface.
- `test/widget/features/tracking/tracking_screen_test.dart` — tests for a deleted component.

### Tests updated

- `test/widget/features/dashboard/dashboard_screen_test.dart`:
  - Removed `TrackingScreen` import and the four `expect(find.byType(TrackingScreen), ...)` assertions.
  - Added `_StartCallNotifier` (a `TrackingNotifier` stub that records `.start()` invocations) and replaced the navigation-asserting test with one that confirms tapping START on `fullyGranted` invokes `notifier.start()` exactly once and the `DashboardScreen` stays mounted (no navigation).

### Verification

- `flutter analyze lib/ test/` — no errors (pre-existing info-level lint noise unchanged).
- `flutter test` — **273/273 pass**.
- `grep -rn "kRouteTracking\|TrackingScreen\|tracking_screen.dart\|TrackingIdleLayout" lib/ test/` — only doc-comment references to the deleted symbols remain (intentional historical context in `hero_record_card.dart` and `tracking_status_layout.dart`).

### Manual smoke test (deferred to user)

- Single tap on the dashboard hero START begins recording — no navigation animation.
- TodaySection / WeekLossCard scroll and Trips/Stats/Settings tabs remain interactive while recording.
- StopButton inside the hero ends the trip and surfaces the persist-result snackbar.

### Execution path

Originally launched as a parallel `gsd-executor` background agent in a worktree. Like 08-09, the agent stalled mid-stream (Anthropic stream watchdog timeout — recurring runtime issue today). The orchestrator executed the plan inline using the same primitives and the plan file as the spec. Net behavior matches what the worktree agent would have produced; only the execution path differs.

### Key files modified

- `lib/features/dashboard/widgets/hero_record_card.dart`
- `lib/features/dashboard/screens/dashboard_screen.dart`
- `lib/features/dashboard/widgets/in_progress_card.dart`
- `lib/config/routes.dart`
- `test/widget/features/dashboard/dashboard_screen_test.dart`

### Files deleted

- `lib/features/tracking/screens/tracking_screen.dart`
- `lib/features/tracking/widgets/tracking_idle_layout.dart`
- `test/widget/features/tracking/tracking_screen_test.dart`
