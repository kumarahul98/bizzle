---
plan_id: 02-04
phase: 02-core-tracking
name: ui-home-and-tracking-screen
status: complete
tasks_total: 2
tasks_completed: 2
started: 2026-04-13
completed: 2026-04-13
commits:
  - hash: de1951c
    message: "feat(02-04): add tracking tile widgets and permission banner"
  - hash: b6be876
    message: "feat(02-04): wire HomeScreen + TrackingScreen into app entry point"
key_files:
  created:
    - lib/features/tracking/screens/home_screen.dart
    - lib/features/tracking/screens/tracking_screen.dart
    - lib/features/tracking/widgets/duration_tile.dart
    - lib/features/tracking/widgets/distance_tile.dart
    - lib/features/tracking/widgets/current_speed_tile.dart
    - lib/features/tracking/widgets/permission_banner.dart
    - lib/features/tracking/widgets/permission_gate.dart
    - lib/features/tracking/widgets/tracking_tiles_row.dart
    - lib/features/tracking/widgets/tracking_idle_layout.dart
    - lib/features/tracking/widgets/tracking_active_layout.dart
    - lib/features/tracking/widgets/tracking_status_layout.dart
    - lib/features/tracking/widgets/tracking_error_layout.dart
  modified:
    - lib/config/routes.dart
    - lib/app.dart
    - test/unit/app_bootstrap_test.dart
    - test/widget/app_test.dart
---

# Plan 02-04: UI Home and Tracking Screen — Summary

## What Shipped

Phase 2 UI: HomeScreen with permission-aware Start commute CTA, TrackingScreen that
renders every variant of the sealed `TrackingState` (idle/starting/active/stopping/error),
three live tiles (duration, distance, current speed), a PermissionBanner for the
background-denied case, and the routes + app-entry swap so PlaceholderHome is gone.

## Files Created (12)

- `lib/features/tracking/screens/home_screen.dart` (85 lines) — FilledButton.icon Start CTA, preflights permissions via `TrackingPermissionService`, navigates to `/tracking` on grant or shows settings CTA on deny per D-09.
- `lib/features/tracking/screens/tracking_screen.dart` (99 lines) — ConsumerWidget reading `trackingStateProvider`, switches layouts by sealed variant.
- `lib/features/tracking/widgets/duration_tile.dart` (55 lines) — MM:SS from `snapshot.duration`.
- `lib/features/tracking/widgets/distance_tile.dart` (51 lines) — "X.XX km" / "X m" from `snapshot.distanceMeters`.
- `lib/features/tracking/widgets/current_speed_tile.dart` (49 lines) — "X km/h" from `snapshot.currentSpeedKmh` (m/s→km/h conversion already handled in the 02-03 map serde).
- `lib/features/tracking/widgets/permission_banner.dart` (38 lines) — dismissible banner with Open Settings CTA, shown when background permission denied but fine granted (D-08).
- `lib/features/tracking/widgets/permission_gate.dart` (59 lines) — extracted permission-check wrapper.
- `lib/features/tracking/widgets/tracking_tiles_row.dart` (44 lines) — row of three tiles.
- `lib/features/tracking/widgets/tracking_idle_layout.dart` (38 lines).
- `lib/features/tracking/widgets/tracking_active_layout.dart` (53 lines).
- `lib/features/tracking/widgets/tracking_status_layout.dart` (29 lines).
- `lib/features/tracking/widgets/tracking_error_layout.dart` (39 lines).

All files ≤ 100 lines per CLAUDE.md widget rule.

## Files Modified (4)

- `lib/config/routes.dart` — added `kRouteHome = '/'`, `kRouteTracking = '/tracking'`, both wired into `kAppRoutes` map.
- `lib/app.dart` — `PlaceholderHome` deleted entirely; `TraevyApp` now mounts `HomeScreen` via routes.
- `test/unit/app_bootstrap_test.dart` — updated to assert `HomeScreen` + "Start commute" instead of `PlaceholderHome`.
- `test/widget/app_test.dart` — same update.

## Verification

- `flutter analyze` — clean
- `flutter test` — 60/60 passing (including the two updated Phase 1 smoke tests)
- `grep -r 'PlaceholderHome' lib/ test/` — 0 hits (NH-4 from plan-checker honored)

## Deviations (all auto-fixed)

1. **Rule 1 — widget size extraction:** extracted 6 additional layout widgets (permission_gate, tracking_tiles_row, tracking_{idle,active,status,error}_layout) so `tracking_screen.dart` composes rather than inline-branching, keeping under the 100-line ceiling.
2. **Rule 3 blocking — comment_references lint:** fixed `[ConsumerWidget]` / `[TrackingScreen]` doc-comment references so `very_good_analysis` stays clean.
3. **Rule 3 blocking — second smoke test:** the Phase 1 smoke suite had an additional file at `test/widget/app_test.dart` that wasn't mentioned in the plan; updated it alongside the unit test so `grep -r 'PlaceholderHome' test/` returns 0.

## Note

This SUMMARY.md was reconstructed by the orchestrator from the executor's self-report
after the worktree was removed before the agent committed its own summary. Commits
`de1951c` and `b6be876` represent the full plan scope as verified on main.
