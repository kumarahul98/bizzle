---
phase: 22
plan: 1
subsystem: "home-screen-widget"
tags:
  - "android"
  - "widget"
  - "home_widget"
  - "riverpod"
requires:
  - "tracking service"
  - "pause/resume state model"
provides:
  - "Android home screen widget with toggle functionality and live stats"
affects:
  - "Tracking state and service initialization from background"
tech-stack:
  added: ["home_widget"]
  patterns: ["Android AppWidgetProvider", "Riverpod background ProviderContainer"]
key-files:
  created: []
  modified:
    - "android/app/src/main/res/layout/widget_layout.xml"
    - "android/app/src/main/kotlin/traevy/traevy/CommuteWidgetProvider.kt"
    - "android/app/src/main/AndroidManifest.xml"
    - "lib/main.dart"
    - "lib/features/tracking/providers/tracking_providers.dart"
key-decisions:
  - "Use HomeWidget plugin to sync stats to SharedPreferences on Android."
  - "Tapping widget toggles tracking by instantiating Riverpod ProviderContainer in the background callback."
  - "Widget dynamically shows distance and duration when tracking is active."
requirements-completed:
  - "WIDGET-01"
duration: "5 min"
completed: "2026-06-09T18:00:00Z"
---

# Phase 22 Plan 01: Home-Screen Widget Implementation Summary

Android home screen widget using `home_widget` plugin, complete with live stats (distance/duration) and proper Riverpod service invocation.

## Overview
- **Tasks**: 4
- **Files Modified**: 5

## Key Outcomes
- Implemented `widget_layout.xml` containing the toggle button and live stats `TextView`s.
- Created `CommuteWidgetProvider.kt` to apply visibility and values based on SharedPreferences state.
- Updated `TrackingNotifier` to periodically sync `widget_show_stats`, `widget_distance`, and `widget_duration` into `HomeWidget.saveWidgetData` and dispatch `updateWidget`.
- Corrected the `main.dart` background callback to safely instantiate a Riverpod `ProviderContainer` to interact with `trackingServiceControllerProvider`, allowing the widget to correctly boot up the background service exactly like the foreground app.

## Issues Encountered
None - Bug reported in UAT was successfully resolved and verified through compilation.

## Next Steps
Phase complete, ready for next step.
