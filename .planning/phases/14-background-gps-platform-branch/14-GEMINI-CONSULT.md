# Phase 14 — Gemini CLI Consultation (decision proxy)

> **Audit trail.** The user was away and asked that Phase 14 discussions be run through the Gemini CLI as a decision proxy. This file records the consultation that grounds the `14-CONTEXT.md` decisions. Gemini CLI v0.22.5, 2026-06-02.

## Questions put to Gemini
1. iOS background-GPS execution model: keep `flutter_background_service` (Option A) vs bypass it and run the geolocator stream on the main isolate under CoreLocation's `location` background mode (Option B). The ROADMAP left this open ("both viable; bypass is the fallback").
2. If Option B, cleanest way to share the existing pure-Dart `TripAccumulator`/finalize logic between an Android fbs-isolate path and an iOS main-isolate path.
3. IOS-08 reduced-accuracy ("Approximate Location") strategy: (a) `requestTemporaryFullAccuracy`, (b) warn-and-record, (c) block recording.

## Gemini's response (verbatim)

### Verdict for Q1: Choose Option B. Bypass `flutter_background_service` on iOS entirely.

**1. The Decision (Option A vs. B)**
`flutter_background_service` on iOS is a wrapper around `BGTaskScheduler`, which is designed for *periodic* background fetches (e.g., waking up every 15+ minutes), not continuous execution. While it uses UI background modes under the hood, forcing it to act as a persistent daemon for a 60-minute drive fights the OS and risks sudden termination.

Conversely, iOS has a native, rock-solid mechanism for continuous background tracking: `UIBackgroundModes: location` combined with an active CoreLocation stream (`allowBackgroundLocationUpdates: true`). As long as the `Geolocator` stream is active on the main isolate, iOS will keep the Flutter engine (and thus the main isolate) alive in the background to process those events. Option B aligns with iOS platform behavior, ensuring reliable commute tracking without memory/process-killing issues.

**2. Architecture for Code Sharing (Option B)**
1. **Isolate the Accumulator:** Ensure `TripAccumulator` is purely reactive. It should take a `Stream<Position>` as input and expose a `Stream<TripSnapshot>` as output. Zero knowledge of `service.invoke`/`service.on`.
2. **Create a Platform-Agnostic Interface:** Define an abstract `TrackingEngine` with `start()`, `stop()`, and `Stream<TripSnapshot> snapshots`.
3. **Android Wrapper:** `AndroidTrackingEngine` configures fbs, manages the isolate, handles the `service.invoke`/`on` IPC bridge. The isolate instantiates `TripAccumulator` and pipes its output over the fbs bridge.
4. **iOS Wrapper:** `IosTrackingEngine` runs directly on the main isolate, creates the `Geolocator` stream, passes it to a local `TripAccumulator`, and bridges output straight to the UI controller.

`TrackingServiceController` instantiates the correct engine via a platform check (`Platform.isIOS ? IosTrackingEngine() : AndroidTrackingEngine()`).

**3. Handling Approximate Location (IOS-08)**
**Recommendation:** Strategy (A) — call `Geolocator.requestTemporaryFullAccuracy(purposeKey: "PreciseCommute")`. If denied, fall back to Strategy (C) (block recording). Speed-based traffic calculations are mathematically impossible with approximate location (sparse, massive distance jumps). Strategy (A) is the Apple-sanctioned UX: it explains *why* at the moment the user taps "Start Trip".

**Info.plist Implication:** add `NSLocationTemporaryUsageDescriptionDictionary` mapping the `purposeKey` to an explanation string:
```xml
<key>NSLocationTemporaryUsageDescriptionDictionary</key>
<dict>
  <key>PreciseCommute</key>
  <string>Traevy needs precise location during your trip to accurately calculate time moving versus time stuck in traffic.</string>
</dict>
```

## Claude's synthesis / adjustments
- **Adopt Option B** as the default — agrees with independent analysis.
- **Engine seam:** adopt the `TrackingEngine` direction, but the planner should **right-size** it — the Android fbs isolate path must remain behaviorally unchanged (it works and ships on v0.1), so the refactor is "extract a seam + add an iOS implementation," not "rewrite Android." `TripAccumulator` is already pure Dart and UI-agnostic, so the reactive-stream reshaping is low-risk.
- **IOS-08:** adopt A→C (request temporary full accuracy at trip start; block with a clear message if reduced accuracy persists). Matches ROADMAP success criterion #3 ("surfaces a warning or blocks recording rather than silently computing garbage speed stats").
