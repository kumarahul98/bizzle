# Project Research Summary

**Project:** Commute Tracker — v0.2 iOS Support
**Domain:** Cross-platform mobile (Flutter) — porting an existing Android-only app to iOS
**Researched:** 2026-06-02
**Confidence:** HIGH

## Executive Summary

This milestone ports the fully-built Commute Tracker Android app to iOS with full feature parity, including background GPS commute tracking. Four parallel research streams (stack, features, architecture, pitfalls) converged on a single dominant finding: **the existing background-tracking mechanism does not work on iOS and must be replaced with Apple's native CoreLocation path** — but the change is small and well-understood, so the milestone is low-risk apart from that one phase.

`flutter_background_service` (the Android keep-alive) cannot sustain continuous GPS on iOS: its `onBackground` callback fires at most ~15–30 seconds every 15 minutes via `BGTaskScheduler`, which is architecturally useless for a 30–60 minute commute recording. The correct iOS mechanism is already in the dependency graph: `geolocator`'s `AppleSettings(allowBackgroundLocationUpdates: true, pauseLocationUpdatesAutomatically: false, activityType: ActivityType.automotiveNavigation)` combined with `UIBackgroundModes: location` in `Info.plist`. CoreLocation then keeps the process alive for the trip's duration. The code change is a single `defaultTargetPlatform` branch (~10 lines) in `tracking_service.dart`; `TripAccumulator`, the Riverpod providers, Drift, and the sync engine are all untouched.

Research also confirmed several facts that **shrink the milestone**: zero package version changes are needed (everything is iOS-compatible at current versions); the iOS Firebase app (`com.travey.app`) is already registered and `firebase_options.dart` already carries the iOS client config; `TrackingNotificationService` already has `DarwinInitializationSettings` wired; and the app uses `flutter_map` (OpenStreetMap), **not** `google_maps_flutter` — so the Google Maps iOS SDK setup mentioned in CLAUDE.md is a red herring and must not be added. The bulk of the work outside the GPS phase is Xcode/Info.plist configuration, not Dart.

## Key Findings

### Recommended Stack

No new packages and no version bumps. The port is configuration plus one platform branch. The only `pubspec.yaml` change is enabling `flutter_launcher_icons.ios: true`.

**Core technologies (unchanged, now iOS-configured):**
- `geolocator ^14.0.2`: GPS — on iOS use `AppleSettings` (native CoreLocation background updates). This replaces `flutter_background_service` for the iOS location stream.
- `firebase_auth ^6.5.1` + `google_sign_in ^7.2.0`: auth — iOS needs `clientId: DefaultFirebaseOptions.currentPlatform.iosClientId` in Dart + the reversed-client-ID URL scheme in `Info.plist`.
- `flutter_local_notifications ^21.0.0`: notifications — `DarwinInitializationSettings`, runtime permission request; **no** iOS foreground-service notification (gate `startTrackingNotification()` behind `Platform.isAndroid`).
- `flutter_secure_storage ^10.3.1`: token storage — requires the **Keychain Sharing** entitlement on real devices (omission = silent `-34018`).
- `flutter_map` (OSM): maps — pure Dart, works on iOS with zero native setup.
- Drift (SQLite): source of truth — platform-agnostic, no change.

**Minimum iOS deployment target:** `platform :ios, '14.0'` in `Podfile` + matching `IPHONEOS_DEPLOYMENT_TARGET`, with a `post_install` hook for transitive pods. (Firebase floor is iOS 13; 14.0 gives margin and covers all deps.)

### Expected Features

All 17 existing features must reach parity. Research split them by porting effort:

**Needs iOS-specific handling (the real work):**
- Background GPS commute tracking — platform branch to `AppleSettings` (HIGH risk, real-device validation required)
- Location permission flow — two-step "When In Use" → "Always" (iOS defers the Always prompt; app must treat "When In Use only" as a valid degraded state)
- iOS-14 Reduced Accuracy handling — detect via `getLocationAccuracy()`; block/flag recording when reduced (otherwise speed ≈ 0 silently corrupts traffic stats)
- Google Sign-In — reversed-client-ID URL scheme
- Tracking notification — gate behind `Platform.isAndroid` (no iOS equivalent; the system blue indicator is the iOS signal)
- Notification permission — iOS runtime prompt

**Works identically (validate, don't build):**
- Trip CRUD, manual entry, daily log/calendar, route map (flutter_map), all stats, dark mode, sync (Drift→Cloud Functions over REST), cloud restore.

**Defer (out of this milestone):**
- Sign in with Apple — App Store Guideline 4.8 requires it *alongside* Google Sign-In, but **only at App Store submission**. Sideloading via free provisioning does not need it.
- TestFlight / App Store distribution.

### Architecture Approach

Minimal-change integration. The abstraction seam is a single platform branch in the tracking service that selects `AppleSettings` vs `AndroidSettings` for the geolocator location stream. The existing service-isolate structure can stay; on iOS the geolocator stream runs and CoreLocation (via `allowBackgroundLocationUpdates`) keeps the process alive. Fallback if the `flutter_background_service` `onForeground` lifecycle misbehaves on iOS: bypass `flutter_background_service` entirely on iOS and run the geolocator stream on the main isolate.

**Major components touched:**
1. `tracking_service.dart` — platform branch for `LocationSettings` (the one non-trivial Dart change).
2. `ios/Runner/Info.plist` — `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes: location`, notification usage, reversed-client-ID `CFBundleURLTypes`.
3. Xcode project — Background Modes → Location Updates capability, Keychain Sharing entitlement, signing team, bundle ID `com.travey.app`, `GoogleService-Info.plist` added as a resource.
4. `Podfile` — `platform :ios, '14.0'` + `post_install`.

### Critical Pitfalls

1. **`pauseLocationUpdatesAutomatically` defaults to `true`** — silently pauses GPS during stop-and-go traffic (the exact thing the app measures). Must explicitly set `false`.
2. **Keychain Sharing entitlement omission** — silent `-34018` auth-token failure on real devices (works in Simulator, so easy to miss).
3. **iOS-14 Reduced Accuracy** — "Approximate Location" returns coarse, low-rate fixes with `speed ≈ 0` and no error; detect and handle, or traffic stats are garbage.
4. **Reversed-client-ID URL scheme missing/mis-ordered** — Google Sign-In hangs in Safari with no surfaced error.
5. **Using `flutter_background_service` as the iOS GPS engine** — silent failure mid-commute; use `AppleSettings` instead.
6. **Posting the tracking notification on iOS** — phantom/confusing; gate behind `Platform.isAndroid`.

## Implications for Roadmap

Convergent phase structure agreed by all four researchers:

### Phase 1: iOS Scaffolding & Configuration
**Rationale:** Nothing builds without the `ios/` folder, Podfile, Info.plist keys, entitlements, signing, and bundle ID. Pure foundation.
**Delivers:** Generated `ios/` project; Podfile (iOS 14, post_install); all Info.plist keys; Background Modes + Keychain Sharing capabilities; `GoogleService-Info.plist` added; app launches on Simulator and (via free provisioning) on a real iPhone.
**Avoids:** Pitfalls 2, 4, 5 (entitlements/plist set up correctly up front).

### Phase 2: Auth on iOS
**Rationale:** Auth gates the rest of the app; small, isolated, verifiable early.
**Delivers:** Google Sign-In working on a real device (`clientId` param + URL scheme), session persistence via Keychain, token round-trip.
**Uses:** firebase_auth, google_sign_in, flutter_secure_storage.

### Phase 3: Background GPS Platform Branch
**Rationale:** The milestone's central risk; must be validated on a real commute before anything depends on it.
**Delivers:** Platform-branched `AppleSettings` tracking; `pauseLocationUpdatesAutomatically: false`; reduced-accuracy guard; background continuation verified on a real iPhone; traffic (moving/stuck) stats correct from real GPS.
**Avoids:** Pitfalls 1, 3, 5. **Research flag: deep-research / careful planning warranted.**

### Phase 4: Notifications, Permissions & Onboarding UX
**Rationale:** Depends on permissions plumbing; finishes the iOS-specific UX.
**Delivers:** `Platform.isAndroid` gating of the tracking notification; iOS notification permission request; two-step "Always" location flow in onboarding/settings; blue-indicator copy.

### Phase 5: End-to-End Real-Device Validation
**Rationale:** All remaining features work identically and can be validated together.
**Delivers:** Full commute recorded on a real iPhone; trips, maps, stats, dark mode, sync, and restore confirmed on iOS. Milestone acceptance gate.

### Phase Ordering Rationale
- Scaffolding first — hard dependency for every other phase.
- Auth before GPS — smaller, de-risks the toolchain/signing before tackling the hard phase.
- GPS isolated in its own phase — highest risk, real-device-only, must not be entangled with other work.
- Notifications/permissions after GPS — share the permission infrastructure.
- Validation last — everything else is "verify identical behavior."

### Research Flags
- **Phase 3 (Background GPS):** deeper planning warranted — platform-conditional isolate behavior + real-device validation; one open question (keep `flutter_background_service.onForeground` wrapper vs bypass on iOS).

Standard-pattern phases (skip deep research): Phases 1, 2, 4, 5 — config and well-documented APIs.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Versions verified iOS-compatible; firebase_options.dart read directly |
| Features | HIGH | Each feature mapped; permission flows from Apple/geolocator docs |
| Architecture | HIGH | tracking_service.dart read line-by-line; seam is concrete |
| Pitfalls | MEDIUM-HIGH | Most from official docs; a few from corroborated GitHub issues |

**Overall confidence:** HIGH

### Gaps to Address
- **iOS background-service wrapper choice (Phase 3):** keep `flutter_background_service.onForeground` driving the geolocator stream, or bypass it on iOS — decide during Phase 3 planning; both are viable, bypass is the fallback.
- **`flutter_map_tile_caching` iOS minimum/stability (LOW confidence):** validate on device during Phase 1/5.
- **Provisional notification authorization bug (single source):** confirm during Phase 4.

## Human-Only Gates (cannot be automated)
- **Xcode license acceptance** (`sudo xcodebuild -license accept`) — blocks all `flutter build ios` and git until done.
- **Apple ID signing** in Xcode — free 7-day provisioning (no paid account needed this milestone); re-sign weekly for device runs.
- **Real-device testing** — background GPS continuation, speed/traffic accuracy, and Google OAuth redirect all require a physical iPhone (Simulator GPS is unreliable for speed).

## Sources

### Primary (HIGH confidence)
- Context7: `geolocator` / `geolocator_apple` (AppleSettings, background updates), `flutter_background_service` (iOS BGTaskScheduler limits), `flutter_local_notifications` (Darwin init), `flutter_secure_storage` (Keychain), `google_sign_in_ios`.
- Firebase official iOS setup docs; Apple CoreLocation & App Store Review Guideline 4.8.
- Project files read directly: `pubspec.yaml`, `lib/firebase_options.dart`, `tracking_service.dart`, `CLAUDE.md`.

### Secondary (MEDIUM confidence)
- GitHub issues corroborating `-34018` Keychain entitlement, `pauseLocationUpdatesAutomatically` default, reduced-accuracy behavior, provisional-auth bug.

### Tertiary (LOW confidence)
- `flutter_map_tile_caching` iOS minimum version — pub.dev states compatibility; exact floor unpublished; validate on device.

---
*Research completed: 2026-06-02*
*Ready for roadmap: yes*
*Note: not git-committed — Xcode license unaccepted blocks git on this machine.*
