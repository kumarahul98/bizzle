# Phase 14: Background GPS Platform Branch - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Source:** Autonomous discuss-phase with Gemini CLI as decision proxy (user away). Architecture rationale: `14-GEMINI-CONSULT.md`.

<domain>
## Phase Boundary

Make iOS record a full commute with GPS continuing uninterrupted while the app is backgrounded / screen off, and keep moving-vs-stuck traffic stats accurate. The Android tracking stack (flutter_background_service background isolate + geolocator + `TripAccumulator`) already ships on v0.1 and must stay behaviorally unchanged. This phase adds an **iOS execution path** plus reduced-accuracy handling.

**In scope:**
- iOS background-GPS execution model (the open ROADMAP decision — resolved below)
- Platform-branched `LocationSettings` (`AppleSettings` on iOS) — ROADMAP SC #4
- Sharing the pure-Dart `TripAccumulator`/finalize logic across both platform paths
- Reduced-accuracy ("Approximate Location") detection + handling — IOS-08
- `NSLocationTemporaryUsageDescriptionDictionary` Info.plist addition
- Android regression check (the engine refactor must not change Android behavior)
- Requirements: **IOS-06** (background GPS), **IOS-07** (no silent pause in stop-and-go), **IOS-08** (reduced-accuracy handling)

**Out of scope:**
- iOS "Always" permission two-step upgrade flow + notification permission + onboarding copy → **Phase 15** (IOS-09/10)
- Any change to Android tracking behavior beyond the minimal seam needed to share code
- Auth (Phase 13, closed), map rendering, stats UI
- The real-device commute validation itself is **human-gated** (the user runs it) — see Human-Gated Validation below

</domain>

<decisions>
## Implementation Decisions

### iOS Background Execution Model (the open ROADMAP decision)
- **D-01:** On iOS, **bypass `flutter_background_service`**. Run the `Geolocator.getPositionStream` on the **main isolate**, relying on CoreLocation's `location` background mode (`UIBackgroundModes: location`, already in Info.plist from Phase 12 + `AppleSettings.allowBackgroundLocationUpdates: true`) to keep the Flutter engine alive during a backgrounded drive. Android keeps the **existing fbs background-isolate path unchanged**. *(Gemini-proxied; the ROADMAP's "bypass" fallback is chosen as the default because fbs on iOS is `BGTaskScheduler`-based — periodic, not continuous — and would risk OS termination over a 30–60 min commute. See `14-GEMINI-CONSULT.md`.)*

### LocationSettings Platform Branch (ROADMAP SC #4)
- **D-02:** Select `LocationSettings` by `defaultTargetPlatform`:
  - **iOS:** `AppleSettings(accuracy: LocationAccuracy.high, allowBackgroundLocationUpdates: true, pauseLocationUpdatesAutomatically: false, activityType: ActivityType.automotiveNavigation, showBackgroundLocationIndicator: true)`. `pauseLocationUpdatesAutomatically: false` is the IOS-07 guarantee (CoreLocation must not auto-pause in slow traffic).
  - **Android:** existing `AndroidSettings(accuracy: high, intervalDuration: kTrackingSampleInterval)` — unchanged.
  - Note: `AppleSettings` has no `intervalDuration` time-throttle; iOS cadence is governed by `distanceFilter`/CoreLocation. `TripAccumulator` is cadence-agnostic, so this is safe — confirm exact `distanceFilter` during planning.

### Code-Sharing Architecture
- **D-03:** Introduce a minimal platform seam so both paths reuse the existing pure-Dart `TripAccumulator` (`addSample`/`snapshot`/`finalize` — already fbs-free and UI-free, directly reusable). The iOS path creates a `TripAccumulator` on the main isolate, subscribes to the geolocator stream, runs the 1 Hz snapshot timer, and delivers snapshots/finalized-trip to `TrackingNotifier` **directly** (callback/StreamController) instead of via `service.invoke`. **Right-size the abstraction** — extract a seam + add the iOS implementation; do NOT rewrite the working Android isolate path.
- **D-04:** `TrackingServiceController` selects the path via `Platform.isIOS`. On iOS, `start()`/`stop()` drive the main-isolate engine; the existing `persistFinalizedTrip` transaction is shared unchanged.

### Reduced Accuracy — IOS-08
- **D-05:** At trip start on iOS, check `Geolocator.getLocationAccuracy()`. If `reduced`, call `Geolocator.requestTemporaryFullAccuracy(purposeKey: 'PreciseCommute')`. If accuracy is still `reduced` after the prompt (user declined), **block recording** with a clear message — never record garbage speed stats. (request → block fallback; satisfies ROADMAP SC #3 "surfaces a warning or blocks recording rather than silently computing garbage speed stats".)
- **D-06:** Add `NSLocationTemporaryUsageDescriptionDictionary` to `ios/Runner/Info.plist` with key `PreciseCommute` → a usage string explaining precise location is needed to compute time-moving vs time-stuck.

### iOS Recording UX / Notification
- **D-07:** iOS does **not** use the Android foreground-service notification. CoreLocation shows its own system background-location indicator (`showBackgroundLocationIndicator: true`); the Stop control stays in-app. Richer iOS notification/permission UX is **Phase 15** — keep Phase 14 minimal.

### Scope Guard
- **D-08:** Android tracking behavior must remain unchanged. Phase 14 acceptance includes a **regression check** that Android recording (fbs isolate, foreground notification, stop-race guards) still works after the engine seam is introduced.

### Claude's Discretion
- Exact iOS `distanceFilter` / sample cadence (accumulator is cadence-agnostic).
- Whether the seam is a full abstract `TrackingEngine` interface or a lighter platform branch — planner right-sizes per D-03.
- Exact placement of the reduced-accuracy gate (`controller.start()` preflight vs engine start).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### This phase
- `.planning/phases/14-background-gps-platform-branch/14-GEMINI-CONSULT.md` — architecture rationale for Option B (bypass fbs on iOS) and IOS-08 strategy
- `.planning/ROADMAP.md` §Phase 14 — goal + 4 success criteria (note: SC #4 names the exact `AppleSettings(...)` params)
- `.planning/REQUIREMENTS.md` §Background GPS on iOS — IOS-06, IOS-07, IOS-08

### Prior tracking architecture (READ before touching tracking code)
- `lib/features/tracking/services/tracking_service.dart` — fbs background-isolate entrypoint, `AndroidSettings`, the `defaultTargetPlatform` branch lives here (SC #4); `IosConfiguration(autoStart:false)` stub
- `lib/features/tracking/services/tracking_service_controller.dart` — UI-isolate wrapper; `start()`/`stop()`/`persistFinalizedTrip`; the `Platform.isIOS` engine selection goes here (D-04)
- `lib/features/tracking/services/trip_accumulator.dart` — pure-Dart `addSample`/`snapshot`/`finalize`; reused by both paths unchanged
- `lib/features/tracking/services/tracking_service_events.dart` — service↔UI event-name constants (Android path)
- `lib/features/tracking/providers/tracking_providers.dart` — Riverpod wiring (`TrackingNotifier` consumes events)
- `lib/features/tracking/services/tracking_notification_service.dart` — Android foreground notification (iOS path skips it, D-07)
- `lib/config/constants.dart` — `kTrackingSampleInterval` (3s), `kTrackingUiUpdateInterval` (1s)
- `.planning/phases/02-core-tracking/02-CONTEXT.md` + `02-RESEARCH.md` — original Android tracking decisions (D-14 notification unification, stop-race guard) that must survive the refactor

### iOS config
- `ios/Runner/Info.plist` — already has `UIBackgroundModes: location`; add `NSLocationTemporaryUsageDescriptionDictionary` (D-06)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TripAccumulator` — pure Dart, no fbs/UI deps; reused unchanged on both paths.
- `TrackingServiceController.persistFinalizedTrip` — the atomic Drift insert + sync-queue enqueue; platform-agnostic, reused unchanged.
- `TrackingNotifier` (providers) — already consumes snapshot + finalized-trip events; the iOS engine feeds it via the same shapes.

### Established Patterns
- Sealed-class state (`TrackingState`, `PersistResult`) + Riverpod `Notifier`.
- Stop-race guard (`stopping` flag before subscription cancel) — must be preserved in the iOS main-isolate path too.

### Integration Points
- `tracking_service.dart` — `defaultTargetPlatform` LocationSettings branch (SC #4).
- `tracking_service_controller.dart` — `Platform.isIOS` engine selection.
- `ios/Runner/Info.plist` — temporary-full-accuracy purpose string.

</code_context>

<specifics>
## Specific Ideas
- The iOS path is "stream on main isolate → TripAccumulator → notifier", with the SAME stop-race ordering (set stopping flag, cancel sub, finalize) as the Android isolate.
- `purposeKey` literal: `PreciseCommute` (must match Info.plist dictionary key exactly).
- Keep the Android fbs path byte-for-byte behaviorally identical; the seam is additive.

</specifics>

<deferred>
## Deferred Ideas
- iOS "Always" location two-step upgrade + notification permission + onboarding copy → Phase 15 (IOS-09/10).
- Any iOS-specific recording notification beyond CoreLocation's system indicator → Phase 15.

</deferred>

## Human-Gated Validation (user runs these on a real iPhone)
- **SC #1:** Start a trip, lock the screen for a full commute, stop — GPS track complete with no gaps.
- **SC #2:** Stop-and-go commute → moving/stuck breakdown accurate (GPS didn't silently pause).
These require a real-device drive and cannot be validated in code/Simulator. Phase 14 delivers the code + automated/Simulator checks; the user performs the drive validation (free-provisioning cert: re-run `flutter run -d <device>` if last install >7 days — see signing memory).

---

*Phase: 14-background-gps-platform-branch*
*Context gathered: 2026-06-02 via autonomous discuss-phase (Gemini CLI decision proxy)*
