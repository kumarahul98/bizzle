# 🎫 IOS-13 — Live Activity does not render on device

**Status:** OPEN — investigation paused (user request)
**Priority:** High (blocks Phase 15 acceptance + Phase 16 milestone gate)
**Branch:** `gsd/phase-15-ios-notifications-live-activity` (all work retained here, not merged)
**Created:** 2026-06-06
**Area:** iOS / Live Activity / `[tracking]`
**Requirement:** IOS-13 (active-commute Live Activity — lock screen + Dynamic Island)

---

## Summary

On Phase 15 device UAT, the iOS **Live Activity never appears on the lock screen** when a trip starts on a real iPhone. The app builds cleanly, installs, runs, tracks GPS, and all 442 Dart tests pass — but the active-commute Live Activity surface (IOS-13) does not render. Everything else in Phase 15 is device-verified working.

## Environment

- Device: **iPhone 13, iOS 26.5**, free/personal-team provisioning (team `2DG5SFXZ5Z`).
- App: `com.travey.app`; Widget Extension: `TraevyLiveActivity` (product `TraevyLiveActivityExtension`).
- Bridge plugin: `live_activities ^5.x` (pub) → `LiveActivitiesAppAttributes` + App-Group `UserDefaults` mechanism. App Group: `group.com.travey.app`. URL scheme: `traevy`.
- Signing cert (free provisioning) installed 2026-06-02, **expires 2026-06-09** — re-test before then or re-sign.

## What IS working (device-verified)

- IOS-09: iOS permission two-step + location priming screen + degraded banner.
- IOS-10: contextual notification permission + **Daily reminder fires at correct local time** (after a timezone fix).
- IOS-11: phantom Android tracking-notification suppressed on iOS.
- App launch, ~20s white-screen (was debug-JIT only), drift double-DB warning, and reminder UTC-timezone bug — all fixed and verified.
- GPS tracking works (system blue location indicator shows during a trip).

## The bug

Starting a trip produces **no Live Activity** on the lock screen (iPhone 13 has no Dynamic Island, so lock screen is the surface under test).

## Fixes already landed (correct — keep)

1. **App-Group provisioning probe: PASS.** `group.com.travey.app` DOES provision on the free personal team once a **trailing-space typo** in the group id was removed in Xcode → Signing & Capabilities. (Earlier "provisioning profile doesn't support the App Group" errors were caused by `'group.com.travey.app '` with a trailing space, not a free-provisioning limit.)
2. **Swift widget reworked to the plugin contract — commit `52cab39`.** The widget was originally `ActivityConfiguration(for: TraevyLiveActivityAttributes.self)` (custom typed attributes), but the `live_activities` plugin creates activities using its own `LiveActivitiesAppAttributes` type and writes dynamic data to the shared App-Group `UserDefaults`. Plugin README: *"create an ActivityAttributes named EXACTLY `LiveActivitiesAppAttributes` (if you rename, activity will be created but not appear!)"*. Fixed: struct renamed to `LiveActivitiesAppAttributes`, empty `ContentState`, `prefixedKey("\(id)_\(key)")`, widget reads each field from `UserDefaults(suiteName: "group.com.travey.app")`.
3. **Build cycle fix** ("Cycle inside Runner" / `ExtractAppIntentsMetadata`): the Xcode wizard's Control Widget + AppIntent caused it; removed them (plan is Live-Activity-only) and moved **Embed Foundation Extensions before Thin Binary** in the Runner build phases. iOS build now clean (`flutter build ios --no-codesign` → ✓, `.appex` embedded).

## Current open finding (the real blocker)

A temporary **on-screen diagnostic banner** (top of every screen, reads a `liveActivityDiag` `ValueNotifier`) shows **`LA: (not started)`** and **never changes — even when tapping Start on the dashboard.**

This means `LiveActivityService.init()` is **never executing** — its first line (before any `await`) sets the banner, and it never does. But this contradicts the wiring:

- `DashboardScreen.build()` does `ref.watch(trackingStateProvider)`.
- `trackingStateProvider` is a `NotifierProvider<TrackingNotifier, …>`; watching it runs `TrackingNotifier.build()`.
- `TrackingNotifier.build()` calls `ref.read(liveActivityServiceProvider).init(...)` → which sets the banner synchronously.
- `MainShell` keeps all tabs (incl. DashboardScreen) mounted via `IndexedStack`.

So `init()` *should* run the moment the home screen renders — yet the banner proves it doesn't. **Either (a) stale build artifacts**, or **(b) a genuine wiring break** (the active trip is driven by a path that never constructs `trackingStateProvider`, or the rendered "home" isn't DashboardScreen — e.g. auth/onboarding state).

A **clean release build was just installed** (`flutter clean` + cleared DerivedData + `flutter build ios --release` + `devicectl install`) to test the staleness hypothesis — **the user has not yet re-read the banner on that clean build.**

## EXACT next steps to resume

1. **Re-read the yellow banner on the freshly-installed clean build.**
   - If it now shows `LA init…` / `LA start…` → it was **stale artifacts**; read the full line to learn the support-gate + `createActivity` result (and the Live Activity may now work).
   - If still `LA: (not started)` → go to step 2.
2. **Add a marker at the very top of `main()`**: `liveActivityDiag.value = 'LA: main() ran';` rebuild + install.
   - Marker shows → installed Dart is current and `init()` genuinely isn't called → **trace why `trackingStateProvider` isn't constructed during a trip** (check auth/`MainShell` state, and whether trip-start goes through `trackingStateProvider.notifier.start()` vs a direct `trackingServiceController` path that bypasses the notifier with the LA wiring).
   - Marker does NOT show → builds aren't reflecting source → deeper toolchain/caching problem.
3. Once `init()`/`start()` are confirmed running, read the gate/`createActivity` outcome from the banner: `gate=FALSE | support: supported=… enabled=… iOS=…` (gate blocks) vs `gate=ok | createTHREW: <error>` (plugin throws) vs `gate=ok | create=<id>` (Dart OK → bug is purely Swift-side widget/UserDefaults keys).

## Cleanup owed once fixed

Temporary diagnostics are intentionally left in the tree to aid resumption — **remove them when the bug is fixed** (all marked `// TEMP la-diag`):
- `[la-diag]` `debugPrint`s in `lib/features/tracking/services/live_activity_service.dart` and `lib/features/tracking/providers/tracking_providers.dart`.
- `liveActivityDiag` `ValueNotifier` + `_LaDiagBanner` overlay in `lib/app.dart`.

## Tooling notes (iOS 26 — learned the hard way)

- **Device install that works:** clean `flutter build ios --release` → `xcrun devicectl device install app --device FEC345D4-825D-51B4-A052-54C7378F615D build/ios/iphoneos/Runner.app`. `flutter install` / `flutter run` device deploy/launch is flaky on iOS 26 (hangs / "Could not run … Try Xcode Product > Run").
- **Mixing `--no-codesign` and `--release` builds** in the same `build/` dir left an **unsigned `objective_c.framework`** → `ApplicationVerificationFailed (0xe8008014)` on install. Fix: `flutter clean` before a signed build.
- **Capturing Flutter Dart logs in release is effectively impossible** on iOS 26: `flutter logs` needs the VM service (absent in release); debug builds won't launch standalone (black "waiting for debugger" screen); `devicectl --console` only captures raw stdout (Flutter routes via os_log); `idevicesyslog` captures system subsystems (CoreLocation, ActivityKit) but **not** Flutter `debugPrint`. → Use the **on-screen banner** pattern for release diagnostics. `idevicesyslog` IS useful for reading native **`Runner(ActivityKit)`** logs.

## Related artifacts

- Debug session (full timeline + resume section): `.planning/debug/live-activity-not-rendering.md`
- Plans: `.planning/phases/15-notifications-permissions-onboarding-ux-on-ios/15-04-PLAN.md` (native), `15-05-PLAN.md` (Dart bridge)
- Research (plugin contract): `15-RESEARCH.md` lines ~320–400 (UserDefaults bridge, `prefixedKey`)
- Memory: `ios-device-testing-gotchas.md`, `ios-device-signing.md`

## Key commits

- `52cab39` widget → plugin contract (fix) · `f65d51b`/`f57abe0` native extension + cycle fix
- `d917bd8`/`abd1bc4` Dart bridge + wiring (15-05)
- `90f630b` on-screen diagnostic banner (temp) · `abd60de` `[la-diag]` diagnostics (temp)
