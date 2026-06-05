---
phase: 15
plan: "04"
subsystem: ios-native
tags: [activitykit, live-activity, dynamic-island, widget-extension, swift, swiftui, ios-13, ios]
dependency_graph:
  requires: ["15-01"]
  provides: ["TraevyLiveActivity Widget Extension", "ActivityAttributes struct", "traevy:// URL scheme", "NSSupportsLiveActivities"]
  affects: ["ios/Runner/Info.plist", "ios/Runner.xcodeproj/project.pbxproj"]
tech_stack:
  added: []
  patterns:
    - "ActivityKit ActivityConfiguration with DynamicIsland builder"
    - "SwiftUI Text(timerInterval:) for client-side elapsed ticking"
    - "SwiftUI Link(destination:) traevy://stop for free-provisioning-safe Stop button"
    - "PBXFileSystemSynchronizedRootGroup — all files in ios/TraevyLiveActivity/ auto-compiled"
    - "Embed Foundation Extensions moved before Thin Binary to fix ExtractAppIntentsMetadata cycle"
key_files:
  created:
    - ios/TraevyLiveActivity/TraevyLiveActivityAttributes.swift
    - ios/TraevyLiveActivity/TraevyLiveActivityWidget.swift
    - ios/TraevyLiveActivity/Localizable.strings
    - ios/TraevyLiveActivity/TraevyLiveActivityBundle.swift
    - ios/TraevyLiveActivity/Info.plist
    - ios/TraevyLiveActivityExtension.entitlements
  modified:
    - ios/Runner/Info.plist
    - ios/Runner.xcodeproj/project.pbxproj
    - ios/Runner/DebugProfile.entitlements
    - ios/Runner/Release.entitlements
    - ios/Podfile.lock
decisions:
  - "startDate typed as Double (ms epoch) not Swift Date — live_activities UserDefaults/Codable bridge cannot decode int as Date"
  - "Stop button is SwiftUI Link(traevy://stop) not AppIntent — free-provisioning safe (no com.apple.developer.live-activity entitlement)"
  - "Build cycle fix: Embed Foundation Extensions moved before Thin Binary in Runner build phases"
  - "Wizard files removed: AppIntent.swift, TraevyLiveActivityControl.swift, TraevyLiveActivity.swift, TraevyLiveActivityLiveActivity.swift"
metrics:
  duration: "~40 min"
  completed: "2026-06-06"
  tasks_completed: 2
  files_changed: 14
---

# Phase 15 Plan 04: ActivityKit Live Activity Widget Extension Summary

Native iOS TraevyLiveActivity Widget Extension with lock-screen + Dynamic Island SwiftUI views, Text(timerInterval:) client-side elapsed ticker, and traevy://stop URL-scheme Stop button — free-provisioning safe, no AppIntent entitlement required.

## What Was Built

### Task 1: ActivityAttributes Struct + Localizable.strings

**TraevyLiveActivityAttributes.swift** declares the `ActivityAttributes` struct with `public typealias LiveDeliveryData = ContentState` (required by the `live_activities` plugin's UserDefaults bridge). The `ContentState` contains the 7 fields exactly matching the Plan 05 Dart bridge contract:

- `elapsedFormatted: String` — pre-formatted elapsed (e.g. "38:22")
- `distanceFormatted: String` — pre-formatted distance (e.g. "2.4 km")
- `movingFormatted: String` — moving time (e.g. "34m")
- `stuckFormatted: String` — stuck time (e.g. "4m")
- `isMoving: Bool` — speed >= kStuckSpeedThresholdKmh
- `direction: String` — "to_office" or "to_home"
- `startDate: Double` — milliseconds since epoch (NOT Swift Date — the UserDefaults/Codable bridge cannot decode a Dart int as a Swift Date)

**Localizable.strings** contains the 7 UI-SPEC copywriting keys: `live_activity_to_office`, `live_activity_to_home`, `live_activity_moving`, `live_activity_stuck`, `live_activity_elapsed`, `live_activity_distance`, `live_activity_stop`.

### Task 2: Widget + Info.plist Keys + URL Scheme

**TraevyLiveActivityWidget.swift** implements `ActivityConfiguration(for: TraevyLiveActivityAttributes.self)` with:

**Lock-screen view (Surface C):**
- Direction badge (accent-bg) + moving/stuck chip (color-coded) in top HStack
- Elapsed time via `Text(timerInterval: Date(timeIntervalSince1970: startDate / 1000.0)...Date.distantFuture, countsDown: false)` — 28pt semibold monospaced, ticks client-side
- Distance: 22pt semibold mono
- "elapsed" / "distance" 11pt secondary labels
- Full-width Stop button: `Link(destination: URL(string: "traevy://stop")!)` — system red, white label, 44pt min height, 12pt radius

**Dynamic Island:**
- `compactLeading`: car.fill icon + elapsed timer mono
- `compactTrailing`: colored dot (moving/stuck) + distance
- `minimal`: car.fill in accent color
- `expanded`: full field set (leading=elapsed, trailing=distance, center=direction badge + status chip, bottom=Stop button)

**Runner/Info.plist additions:**
- `NSSupportsLiveActivities: YES`
- `NSSupportsLiveActivitiesFrequentUpdates: YES`
- Second `CFBundleURLTypes` dict with `traevy` scheme (OAuth scheme `com.googleusercontent.apps.*` preserved unchanged — Pitfall 6)

**Extension Info.plist:** Added `NSSupportsLiveActivities: YES`.

### Build Cycle Fix

**Root cause:** The Xcode wizard added `AppIntent.swift` and `TraevyLiveActivityControl.swift` which triggered Xcode's implicit `ExtractAppIntentsMetadata` build phase on the Runner target. This phase needed the embedded `.appex` (Embed Foundation Extensions phase) to run first, but `Embed Foundation Extensions` was positioned after `Thin Binary` → creating a cycle.

**Fix applied (two-part):**
1. Deleted the four wizard files (`AppIntent.swift`, `TraevyLiveActivityControl.swift`, `TraevyLiveActivity.swift`, `TraevyLiveActivityLiveActivity.swift`) — eliminates the AppIntents source.
2. Moved `Embed Foundation Extensions` build phase **before** `Thin Binary` in Runner's build phases list in `project.pbxproj` — breaks the ordering dependency that caused the remaining `AppIntentsSSUTraining` failure.

**Build result:** `flutter build ios --no-codesign` succeeds: `✓ Built build/ios/iphoneos/Runner.app (42.6 MB)` with `TraevyLiveActivityExtension.appex` embedded.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DynamicIsland closure return expression**
- **Found during:** Task 2 (first build attempt)
- **Issue:** Swift compiler error "Missing return in closure expected to return 'DynamicIsland'" — the `dynamicIsland:` closure requires an explicit `return DynamicIsland { ... }` when using multiple statements (let bindings) before the result builder call
- **Fix:** Added explicit `return` keyword before the `DynamicIsland { ... }` result builder expression
- **Files modified:** `ios/TraevyLiveActivity/TraevyLiveActivityWidget.swift`

**2. [Rule 3 - Blocking] AppIntentsSSUTraining failure after phase reorder**
- **Found during:** Task 2 (second build attempt after phase reorder)
- **Issue:** After reordering `Embed Foundation Extensions` before `Thin Binary`, `AppIntentsSSUTraining` on the Runner target failed with "Missing required '--extracted-metadata-path' file path" when `APP_INTENTS_METADATA_PATH = ""` was set
- **Root cause:** The empty `APP_INTENTS_METADATA_PATH` string suppressed metadata file generation, but `AppIntentsSSUTraining` still ran and expected the file
- **Fix:** Reverted `APP_INTENTS_METADATA_PATH = ""` from all three Runner build configs. The phase reorder alone was sufficient to break the cycle
- **Files modified:** `ios/Runner.xcodeproj/project.pbxproj`

## Known Stubs

None. The widget renders fully-functional SwiftUI views that display all 7 ContentState fields.

Note: On-device Live Activity rendering validation (lock screen appearance, Dynamic Island behavior, Stop button tap triggering `traevy://stop` URL scheme callback) is human-gated UAT per the plan — cannot be validated in Simulator (ActivityKit limitation). Deferred to device validation in 15-VALIDATION.md.

## Threat Flags

No new threat surface beyond what the plan's threat model already covers (T-15-08 through T-15-10 — URL scheme, pre-formatted ContentState only, App Group sandbox).

## Self-Check

**Files exist:**
- [x] `ios/TraevyLiveActivity/TraevyLiveActivityAttributes.swift` — FOUND
- [x] `ios/TraevyLiveActivity/TraevyLiveActivityWidget.swift` — FOUND
- [x] `ios/TraevyLiveActivity/Localizable.strings` — FOUND
- [x] `ios/Runner/Info.plist` contains `NSSupportsLiveActivities` — FOUND
- [x] `ios/Runner/Info.plist` contains `NSSupportsLiveActivitiesFrequentUpdates` — FOUND
- [x] `ios/Runner/Info.plist` contains `traevy` scheme — FOUND
- [x] `ios/Runner/Info.plist` contains `googleusercontent` (OAuth preserved) — FOUND
- [x] `TraevyLiveActivityWidget.swift` contains `DynamicIsland` — FOUND
- [x] `TraevyLiveActivityWidget.swift` contains `traevy://stop` — FOUND

**Build verified:**
- [x] `flutter build ios --no-codesign` succeeds: `✓ Built build/ios/iphoneos/Runner.app (42.6MB)`
- [x] No "Cycle inside Runner" error
- [x] `TraevyLiveActivityExtension.appex` embedded in app bundle

**Commits:**
- [x] `f65d51b` — feat(15-04): ActivityKit Live Activity Widget Extension (IOS-13)
- [x] `f57abe0` — chore(15-04): remove wizard-generated Control Widget + AppIntent files

## Self-Check: PASSED
