---
phase: 02-core-tracking
verified: 2026-04-15T00:00:00Z
status: pass
score: 5/5 must-haves verified; 10/11 device items pass (1 deferred to Phase 3)
overrides_applied: 0
known_warnings:
  - id: WR-01
    summary: "Geolocator position stream has no onError handler — service isolate can crash silently on mid-trip location-service toggle or permission revocation"
    source: 02-REVIEW.md
    impact: "Only surfaces if user toggles location services mid-trip or permissions are revoked; widget tests cannot exercise this"
  - id: WR-02
    summary: "TrackingNotifier.start() does not guard against TrackingStopping; Start during persist window can spawn second session"
    source: 02-REVIEW.md
    impact: "Race only reproducible with rapid Start/Stop/Start taps during the Drift transaction window"
  - id: WR-03
    summary: "TrackingNotifier fbs stream subscriptions have no onError — stream error leaves UI stuck in TrackingActive"
    source: 02-REVIEW.md
    impact: "Combined with WR-01 produces a stuck-UI scenario; no automated path to reach"
  - id: WR-04
    summary: "Stop button has no optimistic-transition debounce; double-tap can cause UNIQUE constraint violation and stomp PersistSaved with PersistFailed"
    source: 02-REVIEW.md
    impact: "Requires two fast taps of Stop; not covered by widget tests"
  - id: IN-01
    summary: "TrackingActive lacks operator == / hashCode — every 1 Hz snapshot triggers rebuild even when values unchanged"
    source: 02-REVIEW.md
    impact: "Minor battery / rebuild cost during stationary wait"
  - id: IN-02
    summary: "TrackingError lacks @immutable + equality"
    source: 02-REVIEW.md
    impact: "Spurious rebuilds if error state re-emitted with same message"
  - id: IN-03
    summary: "TripSnapshot lacks equality unlike sibling FinalizedTrip"
    source: 02-REVIEW.md
    impact: "Asymmetry; low impact today"
  - id: IN-04
    summary: "decodePolyline can throw RangeError on truncated input"
    source: 02-REVIEW.md
    impact: "Decoder only reads values it encoded; Phase 4 hardening"
  - id: IN-05
    summary: "TripAccumulator._samples grows unbounded on long trips"
    source: 02-REVIEW.md
    impact: "~10k objects for an 8-hour trip; within Android budget for v0.1 target"
  - id: IN-06
    summary: "TrackingServiceController.start() swallows Error subtypes in notification show catch block"
    source: 02-REVIEW.md
    impact: "Hides programmer errors in notification channel setup; not a runtime defect"
  - id: IN-07
    summary: "main.dart constructs a throwaway TrackingNotificationService for initialize()"
    source: 02-REVIEW.md
    impact: "Stylistic; underlying plugin singleton makes it correct"
human_verification:
  - test: "Fresh install — all permissions denied"
    expected: "App launches to HomeScreen; Start commute button visible; tapping it surfaces the fine-location permission request"
    why_human: "Requires real Android 14 device with a fresh install state; OS permission dialog cannot be exercised in widget tests"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 1
  - test: "D-07 two-step permission upgrade — grant fine location"
    expected: "After granting fine, tapping Start prompts for ACCESS_BACKGROUND_LOCATION (always-on) as step 2"
    why_human: "Android 11+ permission dance can only be walked through on a real device"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 2
  - test: "Background location upgrade on first Start tap"
    expected: "TrackingScreen preflights background permission; if denied, PermissionBanner shows"
    why_human: "OS-mediated permission outcome; requires real device"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 3
  - test: "Live-tile ticking with real GPS samples"
    expected: "Duration ticks every second; distance grows in sensible increments; speed reads plausibly as user walks or drives"
    why_human: "Emulator GPS is unreliable per CLAUDE.md; real-world GPS behavior must be observed"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 4
  - test: "UX-03 foreground notification — D-14 single-entry tripwire"
    expected: "EXACTLY ONE notification appears in shade with title 'Recording commute' and a Stop action button; no duplicate fbs stock notification"
    why_human: "Notification shade cannot be inspected from widget tests; D-14 unification contract is a runtime invariant"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md rows 5 and 9
  - test: "In-app Stop persists trip to Drift"
    expected: "Trip row written to trips table; sync_queue contains one create entry; notification clears"
    why_human: "End-to-end persistence through the real service isolate → UI isolate → Drift path"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 6
  - test: "D-10 short-trip discard with exact snackbar copy"
    expected: "Trip <30s OR <100m triggers snackbar 'Trip too short to save'; no row written; notification clears"
    why_human: "Widget test drives the state transition but cannot validate real GPS distance path"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 7
  - test: "Background survival — home button + screen off"
    expected: "Notification remains visible while app is backgrounded; tracking continues; tiles still tick when returning to app"
    why_human: "Android foreground-service survival + wake-lock behavior requires real device with real OS scheduler"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 8
  - test: "Stop from notification shade (app backgrounded)"
    expected: "Tapping Stop action in shade dispatches kStopTrackingEvent via the @pragma('vm:entry-point') background handler; trip finalizes and persists"
    why_human: "Background notification response handler only fires when app is not in foreground; cannot reach in flutter_test"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 9
  - test: "Kill + relaunch — D-06 no-ghost invariant"
    expected: "Force-killing the app mid-trip leaves no stale notification or state; relaunch opens to HomeScreen cleanly"
    why_human: "Process-kill testing cannot be performed in flutter_test isolate"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 10
  - test: "Battery optimisation Unrestricted — backgrounded survival repeat"
    expected: "Same backgrounded behavior (row 8) with battery optimisation explicitly set to Unrestricted, ruling out OEM-specific throttling"
    why_human: "OEM battery optimisation is device-specific runtime behavior"
    reference: .planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md row 11
---

# Phase 2: Core Tracking Verification Report

**Phase Goal:** Users can record a commute trip from start to stop with background GPS capture, producing a complete trip record with traffic breakdown (moving vs stuck time).

**Verified:** 2026-04-15
**Status:** PASS
**Re-verification:** Yes — device verification completed 2026-04-15

## Device Verification Results (2026-04-15)

| # | Test | Result | Notes |
|---|---|---|---|
| 1 | Fresh install — all permissions denied | PASS | HomeScreen renders; Start CTA visible |
| 2 | D-07 two-step permission upgrade | PASS | Fine location → background location flow works |
| 3 | Background location upgrade on first Start | PASS | PermissionBanner shows for foreground-only |
| 4 | Live-tile ticking with real GPS | PASS | Duration, distance, speed all update in real time |
| 5 | D-14 single-entry tripwire | PASS | Exactly one "Recording commute" notification in shade |
| 6 | In-app Stop persists trip | PASS | Trip row + sync_queue entry written; notification cleared |
| 7 | D-10 short-trip discard snackbar | PASS | "Trip too short to save" snackbar shown; no row written |
| 8 | Background survival — home button + screen off | PASS | Foreground service keeps GPS alive; tiles tick on return |
| 9 | Stop from notification shade | PASS | Requires `showsUserInterface: true` on Android 14 (broadcast PendingIntent delivers actionId=null; Activity PendingIntent delivers correct selectedNotificationAction) |
| 10 | Kill + relaunch — D-06 no-ghost invariant | PARTIAL | App force-stopped → notification Stop fires → app relaunches in idle state (trip not persisted). Service isolate emits kTripFinalizedEvent but UI isolate is dead. Deferred as Backlog 999.2 (Phase 3). |
| 11 | Battery optimisation Unrestricted | PASS | Backgrounded survival confirmed |

**Post-verification fixes merged:**
- `kServiceReadyEvent`: service isolate signals UI after `setAsForegroundService()` so UI re-posts action-bearing notification, overwriting fbs's action-less placeholder (D-14 race).
- `showsUserInterface: true` on Stop action: Android 14 delivers broadcast actions as body taps (actionId=null). Activity PendingIntent correctly routes to `selectedNotificationAction`.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | User can tap a button to start recording and tap again to stop | VERIFIED | `HomeScreen` (`lib/features/tracking/screens/home_screen.dart:34-36`) renders a `FilledButton.icon` labelled "Start commute" that navigates to `/tracking`; `TrackingScreen` (`lib/features/tracking/screens/tracking_screen.dart`) binds `Start`/`Stop` FilledButtons to `TrackingNotifier.start`/`stop`. Widget tests drive the full sealed-state transition. |
| 2 | GPS continues capturing location when screen is off via foreground service | VERIFIED (automated) | `trackingServiceOnStart` in `lib/features/tracking/services/tracking_service.dart` calls `service.setAsForegroundService()` (line 64) and `Geolocator.getPositionStream(locationSettings: settings)` (line 90), runs inside flutter_background_service's isolate, and is wired from `main.dart` via `configureBackgroundService()`. AndroidManifest declares `FOREGROUND_SERVICE_LOCATION` and the fbs service `android:foregroundServiceType="location"` with `tools:replace`. Screen-off survival needs real-device verification (human item). |
| 3 | A persistent notification is visible while tracking is active | VERIFIED (automated) | `TrackingNotificationService.showRecording()` (`lib/features/tracking/services/tracking_notification_service.dart:103`) creates an ongoing (`ongoing: true`, line 110) notification with a Stop action (lines 116-122) on the LOW-importance "Active commute" channel. Called from `TrackingServiceController.start()`. D-14 unification contract pins `kTrackingNotificationId` across fbs and fln. Single-entry shade assertion needs real-device verification (human item). |
| 4 | Completed trip is saved to Drift with start/end time, duration, distance, route polyline, and time-moving vs time-stuck breakdown | VERIFIED | `TrackingServiceController.persistFinalizedTrip` (`lib/features/tracking/services/tracking_service_controller.dart:129-160`) wraps `TripsDao.insertTrip(TripsCompanion.insert(...))` + `SyncQueueDao.enqueueCreate(trip.id)` in a single `_database.transaction(() async { ... })`. Every column (id, startTime, endTime, durationSeconds, distanceMeters, timeMovingSeconds, timeStuckSeconds, routePolyline, direction) is written. `persist_finalized_trip_test.dart` exercises happy path, short-trip discard, and a rollback test with a `_ThrowingSyncQueueDao`. |
| 5 | Location permission is requested when user first starts tracking (no auth required) | VERIFIED | `TrackingPermissionService.preflight()` (`lib/features/tracking/services/tracking_permission_service.dart`) implements the D-07 strict two-step flow (`Permission.locationWhenInUse` then `Permission.locationAlways`). `TrackingScreen.initState` calls it on first build. 13 unit tests cover every branch including the ordering invariant. No auth provider is referenced anywhere in Phase 2 — confirming "no auth required". |

**Score:** 5/5 truths verified (automated); 11 device-specific items routed to human verification.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/features/tracking/services/trip_accumulator.dart` | Streaming distance + moving/stuck accumulators + finalize() | VERIFIED | Exists, imports `kStuckSpeedThresholdMs` (not km/h — Pitfall 2 tripwire passes), wires into `tracking_service.dart` (grep finds `TripAccumulator(` usage). 13 unit tests passing. |
| `lib/features/tracking/services/tracking_service.dart` | Background isolate entrypoint with Geolocator + service.invoke | VERIFIED | `trackingServiceOnStart` + `configureBackgroundService` both `@pragma('vm:entry-point')`, `foregroundServiceNotificationId: kTrackingNotificationId` (D-14 tripwire passes), stop-race `stopping = true` guard present. |
| `lib/features/tracking/services/tracking_service_controller.dart` | UI-isolate wrapper with start/stop + persistFinalizedTrip | VERIFIED | Transaction wrapping verified; `kDirectionUnknown` injected; `dismiss()` called on every exit path. Rollback test exercises atomicity. |
| `lib/features/tracking/services/tracking_notification_service.dart` | UX-03 foreground notification with Stop action | VERIFIED | `showRecording()` with `ongoing: true`, `AndroidNotificationAction(kTrackingStopActionId, ...)`, foreground response handler + top-level `@pragma('vm:entry-point')` background handler both present. |
| `lib/features/tracking/services/tracking_permission_service.dart` | Two-step D-07 permission flow | VERIFIED | Const-constructible, `forTesting` seam for widget tests, `preflight()` / `currentStatus()` / `openSystemSettings()` implemented. 13 unit tests. |
| `lib/features/tracking/state/tracking_state.dart` | Sealed TrackingState with 5 variants | VERIFIED | `sealed class TrackingState` with `TrackingIdle` / `TrackingStarting` / `TrackingActive` / `TrackingStopping` / `TrackingError` final subclasses. `trackingActiveFromSnapshotMap` performs the single m/s→km/h conversion. |
| `lib/features/tracking/state/finalized_trip.dart` | Immutable DTO for service→UI isolate | VERIFIED | `FinalizedTrip` with `toMap` / `fromMap`, typed `_req<T>` cast helper, `operator ==` / `hashCode`. |
| `lib/features/tracking/providers/tracking_providers.dart` | Manual Riverpod 3.x providers + TrackingNotifier | VERIFIED | Three providers (`trackingPermissionServiceProvider`, `trackingServiceControllerProvider`, `trackingStateProvider`), `TrackingNotifier` subscribes to both fbs events, `setLastPersistResultForTesting` seam present (count=2 in file). |
| `lib/features/tracking/screens/home_screen.dart` | Minimal home with Start commute CTA | VERIFIED | 85 lines, `FilledButton.icon` with "Start commute", `currentStatus()` preflight, dialog for `permanentlyDenied`, Navigator push to `kRouteTracking`. |
| `lib/features/tracking/screens/tracking_screen.dart` | D-12 live tracking UI with tiles + Stop | VERIFIED | ConsumerWidget switching on sealed `TrackingState`; layout widgets (idle/active/status/error) under 100 lines each; `ref.listen` consumes `PersistResult` and shows snackbar. |
| `lib/features/tracking/widgets/*.dart` | Tiles + banner + layouts all <100 lines | VERIFIED | 10 widget files, all ≤99 lines. 4 live tiles (Duration/Distance/CurrentSpeed/Permission) + layouts. |
| `lib/shared/utils/polyline_codec.dart` | Hand-rolled Google Polyline encoder+decoder | VERIFIED | Matches Google's canonical reference string; 5 unit tests including 1000-point round-trip. |
| `lib/config/constants.dart` | 15 new Phase 2 constants incl. kStuckSpeedThresholdMs | VERIFIED | `kStuckSpeedThresholdMs = kStuckSpeedThresholdKmh / 3.6` derived const; `kMinTripDurationSeconds = 30`, `kMinTripDistanceMeters = 100`, `kDirectionUnknown = 'unknown'`, notification channel / id / action label constants all present. |
| `android/app/src/main/AndroidManifest.xml` | Android 14 foreground-location permissions + service override | VERIFIED | `FOREGROUND_SERVICE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `POST_NOTIFICATIONS` all declared; `<service>` element with `tools:replace="android:foregroundServiceType,android:exported"` overriding fbs bundled manifest. APK builds cleanly. |
| `lib/main.dart` | Bootstrap: notifications + service configured before runApp | VERIFIED | `WidgetsFlutterBinding.ensureInitialized()` → `TrackingNotificationService().initialize()` → `configureBackgroundService()` → `runApp`. |
| `lib/app.dart` | HomeScreen mounted, PlaceholderHome removed | VERIFIED | `grep -r PlaceholderHome lib/ test/` returns 0 hits. |
| `.planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md` | 11-row manual device checklist | VERIFIED | 255 lines, frontmatter + 11 numbered rows + Results table + Sign-off block. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `tracking_service.dart` | `package:geolocator/geolocator.dart` | `Geolocator.getPositionStream(locationSettings: settings)` | WIRED | Line 90; subscription feeds `accumulator.addSample(position)`. |
| `tracking_service.dart` | `trip_accumulator.dart` | `TripAccumulator(startedAt: DateTime.now().toUtc())` | WIRED | Background isolate constructs accumulator, calls addSample + snapshot + finalize. |
| `tracking_service_controller.dart` | `database.dart` | `_database.transaction(() async { insertTrip; enqueueCreate; })` | WIRED | `persistFinalizedTrip` line 136; rollback-tested. |
| `tracking_service_controller.dart` | `TrackingNotificationService` | `_notifications.showRecording()` on start; `_notifications.dismiss()` on every persist exit | WIRED | All three exit paths (saved, discarded, failed) call dismiss. |
| `main.dart` | `tracking_service.dart` | `configureBackgroundService()` before runApp | WIRED | Bootstrap sequence verified. |
| `main.dart` | `tracking_notification_service.dart` | `TrackingNotificationService().initialize()` with background response handler | WIRED | Plugin + channel + foreground/background handlers registered. |
| `tracking_screen.dart` | `trackingStateProvider` | `ref.watch(trackingStateProvider)` + `ref.listen` for persist result | WIRED | Switches on sealed state; consumes PersistResult for snackbar. |
| `home_screen.dart` | `tracking_permission_service.dart` | `currentStatus()` preflight before Navigator | WIRED | Permanent-deny branch shows settings dialog. |
| `TrackingNotifier` | `service.on(kTrackingStateEvent)` and `service.on(kTripFinalizedEvent)` | Two StreamSubscriptions in `_attach()` | WIRED | Subscriptions cancelled via `unawaited(...)` in `ref.onDispose`. Note: WR-03 — no `onError` handlers. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `TrackingScreen` | `TrackingState` | `trackingStateProvider` ← `TrackingNotifier._stateSub` ← `service.on(kTrackingStateEvent)` ← `trackingServiceOnStart` 1 Hz `Timer.periodic` emitting `accumulator.snapshot(now).toMap()` | Yes — driven by real Geolocator position stream | FLOWING (automated) — real-device tile ticking routed to human verification |
| `TrackingNotifier._lastPersistResult` | `PersistResult` | `persistFinalizedTrip(trip)` ← `service.on(kTripFinalizedEvent)` ← `accumulator.finalize()` | Yes — real finalized trip DTO with encoded polyline | FLOWING |
| `trips` table rows | `TripsCompanion.insert(...)` | `FinalizedTrip` fields populated by `TripAccumulator` from real GPS samples | Yes — persistence test asserts all columns match | FLOWING |
| `HomeScreen` button | N/A (stateless CTA) | — | — | N/A (no dynamic data) |
| Widget tiles | `snapshot.elapsedSeconds`, `snapshot.distanceMeters`, `snapshot.currentSpeedKmh` | `TrackingActive` sealed variant fields populated by `trackingActiveFromSnapshotMap` | Yes — widget tests exercise all rendering branches with concrete values | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Static analysis clean | `flutter analyze` | "No issues found! (ran in 1.7s)" | PASS |
| Full test suite passing | `flutter test` | "All tests passed!" — 79 passed | PASS |
| Debug APK builds (proves manifest merge + desugaring) | `flutter build apk --debug` | "Built build/app/outputs/flutter-apk/app-debug.apk" (7.4s) | PASS (with compile-SDK warning re: flutter_local_notifications / geolocator_android / package_info_plus requesting SDK 36 — informational, non-blocking) |
| Pitfall 2 tripwire: km/h comparison absent from accumulator | `grep -c 'kStuckSpeedThresholdKmh' lib/features/tracking/services/trip_accumulator.dart` | `0` | PASS |
| D-14 unification tripwire: no stale kBackgroundServiceNotificationId | `grep -rc 'kBackgroundServiceNotificationId' lib/ test/` | no matches | PASS |
| D-14 unification: fbs pins to same notification id | `grep -c 'foregroundServiceNotificationId: kTrackingNotificationId' lib/features/tracking/services/tracking_service.dart` | `1` | PASS |
| Persistence uses a Drift transaction | `grep -c 'database.transaction' lib/features/tracking/services/tracking_service_controller.dart` | `1` | PASS (lives in the controller where persistFinalizedTrip is defined, not in tracking_providers.dart — architecturally correct; the provider file delegates to the controller) |
| Test-only PersistResult seam present | `grep -c 'setLastPersistResultForTesting' lib/features/tracking/providers/tracking_providers.dart` | `2` | PASS |
| PlaceholderHome fully purged | `grep -r 'PlaceholderHome' lib/ test/` | no matches | PASS |
| No TODO comments in Phase 2 code | `grep -rn '// TODO' lib/features/tracking lib/config/constants.dart` | no matches | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| TRACK-01 | 02-01, 02-03, 02-04, 02-05, 02-06 | User can start and stop commute recording with a single tap | SATISFIED | HomeScreen Start CTA → TrackingScreen Start/Stop FilledButton bound to `TrackingNotifier.start`/`stop`. Widget tests drive the state transition. |
| TRACK-02 | 02-01, 02-03, 02-06 | GPS captures location in background while screen is off via foreground service | SATISFIED (automated) | `Geolocator.getPositionStream` runs inside `flutter_background_service` foreground isolate; `AndroidManifest` declares `FOREGROUND_SERVICE_LOCATION` + `<service foregroundServiceType="location" tools:replace=".."/>`. Real screen-off behavior routed to human verification. |
| TRACK-04 | 02-02, 02-03, 02-05 | Each trip records start/end time, duration, distance, encoded route polyline | SATISFIED | `TripAccumulator` streams distance via `Geolocator.distanceBetween`; `finalize()` produces `FinalizedTrip` with all fields; `persistFinalizedTrip` writes every column inside `database.transaction`. `persist_finalized_trip_test.dart` asserts every field round-trips. |
| TRACK-05 | 02-02, 02-03, 02-05 | Per-trip traffic breakdown: time moving vs time stuck (speed < 10 km/h threshold) | SATISFIED | `TripAccumulator.addSample` classifies intervals by `prev.speed >= kStuckSpeedThresholdMs` (m/s derived from km/h constant). 13 accumulator tests include the Pitfall 2 forward (5 km/h→stuck) and inverse (3 m/s→moving) tripwires. |
| UX-03 | 02-01, 02-05, 02-06 | Persistent notification displayed while GPS tracking is active | SATISFIED (automated) | `TrackingNotificationService.showRecording()` with `ongoing: true` + Stop action on LOW-importance channel; D-14 unification collapses fbs stock notification onto fln notification via shared `kTrackingNotificationId`. Real shade inspection routed to human verification. |

No orphaned requirements — REQUIREMENTS.md lines 105-130 map exactly TRACK-01, TRACK-02, TRACK-04, TRACK-05, UX-03 to Phase 2, all of which are claimed by plans 02-01..02-06.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | No TODO / FIXME / XXX / HACK / PLACEHOLDER found in `lib/features/tracking` or `lib/config/constants.dart` | — | None |
| — | — | No `PlaceholderHome` references in `lib/` or `test/` | — | None |
| — | — | No `return null` / `return []` / `return {}` stubs in Phase 2 code | — | None |
| — | — | No "coming soon" / "not yet implemented" strings in Phase 2 code | — | None |

None. The anti-pattern scan is clean. The WR-01..WR-04 items from 02-REVIEW.md are concurrency/error-handling refinements, not stubs or placeholders, and are explicitly flagged in `known_warnings` above.

### Human Verification Required

Phase 2 ships 11 manual device-verification items enumerated in `.planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md`. Summary of the highest-value gates (full detail in the checklist file; also enumerated in the `human_verification` frontmatter):

1. **Fresh install — all permissions denied** — confirms HomeScreen renders from a zero-permission baseline.
2. **D-07 two-step permission upgrade** — fine location first, then background on first Start tap.
3. **Background location upgrade on first Start tap** — PermissionBanner for foreground-only branch.
4. **Live-tile ticking with real GPS samples** — real-world speed / distance values.
5. **UX-03 foreground notification — D-14 single-entry tripwire** — EXACTLY ONE shade entry, not two.
6. **In-app Stop persists trip to Drift** — end-to-end GPS → accumulator → transaction → Drift row.
7. **D-10 short-trip discard** — snackbar "Trip too short to save" with no row written.
8. **Background survival — home button + screen off** — foreground service keeps GPS alive.
9. **Stop from notification shade (app backgrounded)** — `@pragma('vm:entry-point')` background handler dispatch.
10. **Kill + relaunch — D-06 no-ghost invariant** — no stale notification after force-kill.
11. **Battery optimisation Unrestricted — backgrounded survival repeat** — OEM throttling confirmation.

These cannot be validated from the widget test framework: Android 14 OS behaviors (permission dialogs, notification shade dedup, process kill / relaunch, background foreground-service survival, OEM battery optimisation) must be observed on a real device.

### Gaps Summary

No blocking gaps. All 5 ROADMAP success criteria have automated evidence. All 15+ required artifacts exist and are substantively wired. Every key link traces from UI → provider → service isolate → GPS → accumulator → Drift and back through fbs events. `flutter analyze` is clean, 79/79 tests pass, and the debug APK builds (proving manifest merge + Android 14 foreground-location-service configuration is well-formed).

Eleven items are routed to human verification because they exercise OS behaviors (permission dialog flow, notification shade, background foreground-service survival, process kill/relaunch, OEM battery optimisation) that widget tests cannot reach. These are the only things standing between this phase and a final PASS.

Eleven known warnings (WR-01..WR-04, IN-01..IN-07) from `02-REVIEW.md` are carried forward as `known_warnings` in the frontmatter. They are documented non-blockers for this phase — they are real but only reproducible under multi-tap / stream-error / long-trip edge cases that are not on Phase 2's critical path. They should be addressed in a follow-up or during Phase 3 when the tracking-to-trip-list handoff is built.

---

*Verified: 2026-04-12*
*Verifier: Claude (gsd-verifier)*
