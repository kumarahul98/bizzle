---
slug: live-activity-not-rendering
status: investigating
trigger: "Phase 15 device UAT: Live Activity does not appear on the lock screen when a trip starts on iPhone 13 / iOS 26.5, despite app building and installing cleanly."
created: 2026-06-06T00:00:00Z
updated: 2026-06-06T00:00:00Z
---

# Debug Session: live-activity-not-rendering

## Symptom
On a real iPhone 13 / iOS 26.5, starting a trip produces NO Live Activity on the lock screen. App builds, installs, and runs; reminders/permissions all work.

## Root cause (CONFIRMED by code + research read)
Architectural mismatch between the two halves of IOS-13:
- **Dart bridge (15-05)** uses the `live_activities` pub plugin (v2.4.9): `LiveActivities().init(appGroupId: 'group.com.travey.app', urlScheme: 'traevy')` then `createActivity(kLiveActivityId, Map<String,dynamic>)`. The plugin starts an ActivityKit Live Activity using ITS OWN `LiveActivitiesAppAttributes` type and writes the dynamic map into the shared App Group `UserDefaults` (keys prefixed per activity id).
- **Swift widget (15-04)** is configured as `ActivityConfiguration(for: TraevyLiveActivityAttributes.self)` with a custom typed `ContentState` — the hand-written native ActivityKit pattern, which the plugin NEVER drives.
- Result: the plugin starts an activity of type `LiveActivitiesAppAttributes`, but the only widget UI registered is for `TraevyLiveActivityAttributes`. iOS has no matching widget → nothing renders.

15-RESEARCH.md (lines 327/371/394) explicitly specifies the plugin's UserDefaults bridge: the widget reads dynamic fields via `context.attributes.prefixedKey("elapsedFormatted")` from `UserDefaults(suiteName: appGroupId)`. 15-04 deviated from this contract.

Dart `_contentState` Map keys sent: `elapsedFormatted` (String), `distanceFormatted` (String), `movingFormatted` (String), `stuckFormatted` (String), `isMoving` (bool), `direction` (String), `startDate` (double, ms epoch). App Group: `group.com.travey.app`. URL scheme: `traevy`. Activity id constant: `kLiveActivityId`.

## Fix (approved)
Rework the Swift widget (ios/TraevyLiveActivity/) to the `live_activities` plugin contract:
1. Replace `TraevyLiveActivityAttributes` with the plugin-required `LiveActivitiesAppAttributes` struct (exact name) — `ActivityAttributes, Identifiable`, `typealias LiveDeliveryData = ContentState`, empty `ContentState`, `var id = UUID()`, plus the `prefixedKey(_:)` helper extension the plugin expects.
2. Rewrite the widget as `ActivityConfiguration(for: LiveActivitiesAppAttributes.self)` reading each field from `UserDefaults(suiteName: "group.com.travey.app")` via `context.attributes.prefixedKey("<key>")` (string/bool/double accessors matching the Dart types). Keep the lock-screen + Dynamic Island layouts and the `traevy://stop` Stop Link.
3. Keep the bundle exposing only this widget. Verify against the installed `live_activities` pod source for the exact prefix/storage format.
4. Rebuild (`flutter build ios --no-codesign`) clean; reinstall codesigned; device UAT.

## Current Focus
- hypothesis: widget registered for wrong ActivityAttributes type; plugin drives LiveActivitiesAppAttributes + UserDefaults, widget reads typed context.state → no match → no render.
- next_action: rework Swift widget to plugin contract; rebuild; reinstall; device UAT.

## Resolution

**Status:** Fix applied — awaiting device UAT to confirm.

**Root cause (confirmed):** `TraevyLiveActivityAttributes` was a hand-written custom struct. The `live_activities` plugin v2.4.9 creates ActivityKit activities using ITS OWN type `LiveActivitiesAppAttributes` — the plugin README states explicitly: "ensure you create an ActivityAttributes named EXACTLY `LiveActivitiesAppAttributes` (if you rename, activity will be created but not appear!)". Because the widget was registered for `TraevyLiveActivityAttributes` and the plugin launched activities of `LiveActivitiesAppAttributes`, iOS could not match any widget UI to the running activity → nothing rendered.

**Fix applied (commit 52cab39):**

1. `ios/TraevyLiveActivity/TraevyLiveActivityAttributes.swift` — renamed struct to `LiveActivitiesAppAttributes: ActivityAttributes, Identifiable`, emptied `ContentState` (dynamic data travels via UserDefaults, not Codable payload), kept `var id = UUID()`, added `prefixedKey(_:)` extension returning `"\(id)_\(key)"` (exact plugin format).

2. `ios/TraevyLiveActivity/TraevyLiveActivityWidget.swift` — switched `ActivityConfiguration(for:)` to `LiveActivitiesAppAttributes.self`. All 7 dynamic fields now read from `UserDefaults(suiteName: "group.com.travey.app")` via `context.attributes.prefixedKey("key")`:
   - `distanceFormatted` → `.string(forKey:)`, default `"0.0 km"`
   - `direction` → `.string(forKey:)`, default `"to_office"`
   - `isMoving` → `.bool(forKey:)`
   - `startDate` → `.double(forKey:)` → `Date(timeIntervalSince1970: ms/1000.0)`, default `Date()`
   Visual design preserved: lock-screen VStack layout, Dynamic Island expanded/compact/minimal regions, `StopButton` (`traevy://stop`), `widgetURL`, `keylineTint`, client-side `timerInterval` ticking.

3. `ios/TraevyLiveActivity/TraevyLiveActivityBundle.swift` — no change needed; it references `TraevyLiveActivityWidget` (the widget struct), not the attributes type.

4. `lib/features/tracking/services/live_activity_service.dart` — **untouched**. The Dart side was correct throughout.

**Build result:** `flutter build ios --no-codesign` → clean, 43.2 MB .app, 28.5 s.

**Device UAT required:** Reinstall the codesigned build on iPhone 13 / iOS 26.5, start a trip, and verify:
- Live Activity appears on the lock screen within ~2 s of trip start.
- Dynamic Island shows car icon + elapsed timer (compact) and full layout on long-press (expanded).
- Distance, direction badge, and moving/stuck chip update every ~5 s.
- Tapping Stop dismisses the Live Activity and stops the trip.

## PAUSE / RESUME HERE (2026-06-06)

**Status when paused:** Live Activity still does NOT render on device. Root-causing in progress.

**Two fixes already applied and committed (correct, keep them):**
- `52cab39` — Swift widget reworked to the `live_activities` plugin contract (struct renamed to `LiveActivitiesAppAttributes`, reads shared App-Group UserDefaults via `prefixedKey`). This was a real bug (plugin README: rename = "created but not appear").
- App-Group provisioning probe PASSED on the free personal team (after removing a trailing-space typo in the group id). App Groups DO provision here.

**Open finding (the current blocker):** An on-screen diagnostic banner (temp, committed `90f630b` + `abd60de`) shows `LA: (not started)` and NEVER changes — even when tapping Start on the dashboard. This means `LiveActivityService.init()` (called from `TrackingNotifier.build()` via `ref.watch(trackingStateProvider)` in DashboardScreen) is never executing its banner-set line. Contradiction: the dashboard watches `trackingStateProvider`, which should construct the notifier and run `init()` immediately. So either (a) stale build artifacts (a clean release rebuild was just installed via devicectl — **awaiting the user's re-test of the banner**), or (b) a genuine wiring break (the active trip is driven by a path that never constructs `trackingStateProvider`, or DashboardScreen isn't the rendered home).

**EXACT NEXT STEP on resume:**
1. Ask the user to open the freshly-installed clean build and read the yellow banner.
   - If it now shows `LA init…`/`LA start…` → it was stale artifacts; read the new line to learn the gate/create result.
   - If still `LA: (not started)` → add a marker at the TOP of `main()` (`liveActivityDiag.value = 'LA: main() ran <marker>'`) and rebuild. If THAT marker shows → installed Dart is current and `init()` genuinely isn't being called → trace why `trackingStateProvider` isn't constructed during a trip (check MainShell/auth state, whether trip start goes through `trackingStateProvider.notifier.start()` vs a direct controller path). If the marker does NOT show → builds are not reflecting source (deeper toolchain/caching problem).

**Temp diagnostics still in tree (REMOVE once fixed):** `[la-diag]` debugPrints + `liveActivityDiag` ValueNotifier + `_LaDiagBanner` overlay in app.dart. All marked `// TEMP la-diag`.

**Device install method that works on iOS 26:** clean `flutter build ios --release` then `xcrun devicectl device install app --device FEC345D4-825D-51B4-A052-54C7378F615D build/ios/iphoneos/Runner.app`. (`flutter install`/`flutter run` are flaky; `flutter logs`/idevicesyslog do NOT capture Flutter Dart logs in release — use the on-screen banner instead.)
