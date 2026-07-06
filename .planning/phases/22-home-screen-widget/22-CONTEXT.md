# Phase 22 Context: Home-Screen Widget

## Goal
Users can add an Android home-screen widget that starts or stops a commute with one tap and always reflects the current tracking state.

## Dependencies
- Phase 2 (tracking service)
- Phase 18 (pause/resume state model, so widget state is accurate)

## Requirements
- **WIDGET-01**

## Success Criteria (what must be TRUE)
1. The user can add a Commute Tracker widget to the Android home screen from the widget picker.
2. Tapping the widget when idle starts a commute, and tapping it while tracking stops and saves the commute — the same trip pipeline as the in-app button.
3. The widget visually reflects the current tracking state (idle vs tracking) and updates when tracking starts or stops, including changes initiated from inside the app.
4. Starting tracking from the widget brings up the foreground GPS service and persistent notification exactly as the in-app Start does (no degraded background capture).

## Context Notes
- **CONCERN (Phase 22):** Home-screen widget is the highest platform-integration risk in v0.3 — native Android AppWidget + background trigger into the tracking service. Plan-phase should flag for deeper research.
- **Dependencies Check:** Phase 18 state model is required for accurate widget state, ensuring pause/resume logic is fully supported.

## Deferred
- iOS widget support (requested during UAT but out of scope for Android-only Phase 22)
