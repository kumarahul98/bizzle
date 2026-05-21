---
status: diagnosed
trigger: "Tapping dashboard hero START button navigates to TrackingScreen but lands in IDLE state, forcing user to tap twice to actually start recording"
created: 2026-05-15T18:43:53Z
updated: 2026-05-15T18:49:00Z
---

## Current Focus

hypothesis: CONFIRMED. _handleStart only performs permission preflight + Navigator.pushNamed(kRouteTracking). It never invokes ref.read(trackingStateProvider.notifier).start(). The TrackingScreen mounts in TrackingIdle (notifier's initial state) and TrackingIdleLayout renders a second "Start" pill that the user must tap to trigger start().
test: (done) Read hero_record_card.dart, dashboard_screen.dart, tracking_screen.dart, tracking_idle_layout.dart, tracking_active_layout.dart, tracking_service.dart, tracking_providers.dart, 08-04-PLAN.md, 08-UI-SPEC.md §3/§4.
expecting: (matched) Navigation occurs without state transition. Plan 04 acceptance criteria explicitly said: "Tapping the hero record card START button still runs the existing permission-check flow and pushes the tracking route" — which preserved the OLD FAB behavior verbatim. UI-SPEC §3 vs §4 makes clear the START button is the start-of-recording action, not a navigation-to-an-idle-recorder action.
next_action: Report root cause and recommend fix path (a) — start before navigate.

## Symptoms

expected: Single tap on dashboard hero START -> trip starts, TrackingScreen displays active layout (pulsing dot, elapsed timer, Stop button).
actual: Tap navigates to TrackingScreen but trip has not started; TrackingScreen shows IDLE layout with its own Start pill; user must tap again.
errors: None reported; UX redundancy bug (no exception/crash).
reproduction: From dashboard, tap hero START; observe arrival on TrackingScreen with idle layout instead of active recording state.
started: After Phase 8 Plan 04 UI overhaul (hero record card replaced the pre-Phase 8 FAB).

## Eliminated

(none yet)

## Evidence

- timestamp: 2026-05-15T18:46:00Z
  checked: lib/features/dashboard/screens/dashboard_screen.dart _handleStart (lines 58-82)
  found: Method body runs (1) permission status check via TrackingPermissionService, (2) early-returns with settings dialog on permanentlyDenied or notificationDenied, and (3) on the happy path calls only `Navigator.pushNamed(context, kRouteTracking)` at line 81. NO call to ref.read(trackingStateProvider.notifier).start(); NO call to the tracking service controller's start().
  implication: The hero card's onStart callback never transitions the tracking state machine out of TrackingIdle. The next screen will mount with the notifier still in TrackingIdle.

- timestamp: 2026-05-15T18:46:30Z
  checked: lib/features/dashboard/widgets/hero_record_card.dart (lines 65-66)
  found: `GestureDetector(onTap: isTracking ? null : onStart, ...)` — the widget simply delegates the tap to the `onStart` callback passed by DashboardScreen. The widget itself has no awareness of the tracking service; it cannot start a trip on its own.
  implication: Behavior is entirely controlled by DashboardScreen._handleStart. The fix lives there (or in a new tracking-aware orchestrator), not in HeroRecordCard.

- timestamp: 2026-05-15T18:47:00Z
  checked: lib/features/tracking/providers/tracking_providers.dart (TrackingNotifier.build line 127-136, TrackingNotifier.start line 292-308)
  found: build() returns `const TrackingIdle()` as the initial state. start() is what runs the TrackingIdle/TrackingError -> TrackingStarting -> (controller.start()) -> TrackingActive transition. Nothing on TrackingScreen mount invokes start() automatically — TrackingScreen's _runPreflight only sets `_permissionStatus`, never calls notifier.start().
  implication: Without an explicit start() call before navigation (or from within TrackingScreen on first mount), the screen lands in TrackingIdle and renders TrackingIdleLayout.

- timestamp: 2026-05-15T18:47:30Z
  checked: lib/features/tracking/screens/tracking_screen.dart _buildBody (lines 51-79) and lib/features/tracking/widgets/tracking_idle_layout.dart
  found: For TrackingIdle, _buildBody returns `TrackingIdleLayout(onStart: () => ref.read(trackingStateProvider.notifier).start())`. TrackingIdleLayout renders three zero-valued tiles plus a `FilledButton.icon(onPressed: onStart, icon: play_arrow_rounded, label: Text('Start'))`. This is the second tap the user must perform.
  implication: The idle layout exists as the historical entry surface for the screen — before Phase 8 the FAB navigated here, then the user pressed Start. Phase 8 kept this fallback path intact while adding a much more prominent hero entry point upstream.

- timestamp: 2026-05-15T18:48:00Z
  checked: .planning/phases/08-ui-overhaul/08-04-PLAN.md acceptance criteria (line 40) and key_links (lines 77-80)
  found: The plan explicitly preserved the legacy behavior: "Tapping the hero record card START button still runs the existing permission-check flow and pushes the tracking route." key_link from `HeroRecordCard onStart` -> `DashboardScreen _handleStart` was the entire wiring requirement.
  implication: The bug is preserved-by-design from a strict refactor standpoint (Phase 8 was a UI overhaul, not a behavior change). But the design now has two competing START affordances — the prominent dashboard hero and the secondary idle-layout pill — and Plan 04 did not account for the new UX redundancy.

- timestamp: 2026-05-15T18:48:30Z
  checked: .planning/phases/08-ui-overhaul/08-UI-SPEC.md §3 (Home/Dashboard) and §4 (Active Recording Screen)
  found: §3 shows the 124dp START button as the dashboard hero CTA. §4 shows the active recording screen with `● RECORDING` header + ELAPSED 76sp timer + tile row + StopButton — there is NO "Start" pill in §4. The spec depicts no intermediate idle state on the tracking screen; the user moves directly from §3 (dashboard) to §4 (active recording) via a single tap.
  implication: The intended UX per spec is: dashboard START tap -> immediately recording on the active layout. The current implementation diverges by routing through TrackingIdle.

## Resolution

root_cause: |
  DashboardScreen._handleStart (lib/features/dashboard/screens/dashboard_screen.dart lines 58-82)
  performs permission preflight then calls only `Navigator.pushNamed(context, kRouteTracking)`. It
  never invokes `ref.read(trackingStateProvider.notifier).start()`. Because TrackingNotifier.build()
  initializes to TrackingIdle and TrackingScreen has no auto-start logic on mount, the user lands on
  TrackingIdleLayout — which renders its own FilledButton "Start" pill that the user must tap to
  actually transition through TrackingStarting -> TrackingActive.

  This was preserved-by-design by Phase 8 Plan 04: the acceptance criterion "Tapping the hero record
  card START button still runs the existing permission-check flow and pushes the tracking route"
  copied the pre-Phase 8 FAB semantics verbatim. The redundancy is only visible now because the new
  hero card is much more prominent than the old FAB and visually promises that tap = start.

fix: |
  Recommended path (a): Make _handleStart kick off recording before navigating.

  In lib/features/dashboard/screens/dashboard_screen.dart _handleStart, after the permission checks
  pass (just before the Navigator.pushNamed call on line 81), invoke:

      ref.read(trackingStateProvider.notifier).start();
      if (!context.mounted) return;
      await Navigator.pushNamed(context, kRouteTracking);

  Notes:
    * Do NOT await start() — start() is fire-and-forget; awaiting it would block the navigation on
      the controller's foreground-service spin-up and the user would see a frozen dashboard for the
      ~500ms-1s it takes for the service isolate to come up.
    * The notifier's start() already guards re-entry via the sealed-state switch (TrackingNotifier.start
      lines 292-302), so calling it from the dashboard is safe even if the user double-taps.
    * The TrackingNotifier transitions Idle -> TrackingStarting synchronously inside start(); by the
      time TrackingScreen rebuilds after Navigator.pushNamed it will already render
      TrackingStatusLayout('Starting GPS...') instead of TrackingIdleLayout — eliminating the second
      "Start" pill.
    * On controller.start() failure the notifier sets TrackingError and TrackingScreen renders
      TrackingErrorLayout with Retry — same recovery surface as today.

  Complementary cleanup (path b can be done alongside (a)):
  Once (a) lands, TrackingIdle is no longer reachable via the dashboard entry path. The remaining
  callers of TrackingIdleLayout are:
    1. The post-trip return (TrackingStopping -> TrackingIdle in TrackingNotifier line 209-211) when
       a user finishes a trip and stays on the screen — but the screen pops on Stop in normal flow,
       so this is mostly a defensive landing state.
    2. TrackingError -> Retry -> back to TrackingStarting (so idle isn't visited).
    3. Future surfaces (deep links, notifications routing direct to /tracking) — these would still
       need the idle pill.
  Recommendation: KEEP TrackingIdleLayout as a defensive fallback (do not delete) but treat (a) as
  the canonical fix. Removing the idle pill (path b) would leave deep-link / direct-route surfaces
  with a screen that cannot start a trip, which is worse than the redundancy.

verification: (pending — fix not yet applied; this is a diagnose-only run)
files_changed: []
