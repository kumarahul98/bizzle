---
phase: 02-core-tracking
plan: 05
subsystem: tracking
tags: [flutter, flutter_local_notifications, drift, transaction, d-14-unification, ux-03, sealed-class, persist-result, rule-4-auth-soft-fail]

# Dependency graph
requires:
  - phase: 02-core-tracking
    provides: "TrackingServiceController + TrackingNotifier + trackingStateProvider (02-03), FinalizedTrip + TripsCompanion wiring (02-02), Phase 2 constants (kMinTripDurationSeconds / kMinTripDistanceMeters / kDirectionUnknown / kTrackingNotificationId / kTrackingNotificationChannelId / kTrackingStopActionId) (02-02)"
  - phase: 02-core-tracking
    provides: "TrackingScreen state switch + ref.listen seam (02-04)"
  - phase: 01-foundation
    provides: "TripsDao.insertTrip, SyncQueueDao.enqueueCreate, AppDatabase.transaction, appDatabaseProvider + tripsDaoProvider + syncQueueDaoProvider"
provides:
  - "TrackingNotificationService — flutter_local_notifications 21.0 wrapper for the UX-03 ongoing 'Recording commute' notification with Stop action button"
  - "trackingNotificationBackgroundHandler — top-level @pragma('vm:entry-point') handler defusing Pitfall 4 (release-mode tree-shake)"
  - "TrackingServiceController.persistFinalizedTrip — appDatabase.transaction wrapping TripsDao.insertTrip + SyncQueueDao.enqueueCreate with D-10 short-trip discard and notification dismissal on every exit path"
  - "Sealed PersistResult (PersistSaved / PersistDiscardedTooShort / PersistFailed) as the typed handle on save outcomes"
  - "TrackingNotifier.consumeLastPersistResult + @visibleForTesting setLastPersistResultForTesting seam for plan 02-06 widget tests"
  - "TrackingScreen ref.listen snackbar consumer ('Trip saved' / 'Trip too short to save' / 'Unable to save trip: \${error}')"
  - "main.dart bootstrap sequence: WidgetsFlutterBinding → TrackingNotificationService.initialize → configureBackgroundService → runApp"
  - "tracking_service_events.dart — feature-local coupling file for the three service/UI isolate event name constants, extracted from tracking_service.dart"
affects: [02-06-widget-tests]

# Tech tracking
tech-stack:
  added:
    - "flutter_local_notifications ^21.0 wired at runtime (already in pubspec from plan 02-01 — first actual usage site lands here)"
  patterns:
    - "D-14 unification contract: same channelId + same notificationId across flutter_background_service (configureBackgroundService) and flutter_local_notifications (TrackingNotificationService.showRecording) so Android collapses to a single shade entry"
    - "Single transaction for trip insert + sync queue enqueue — rollback-tested against a deliberately failing _ThrowingSyncQueueDao so the atomicity claim is machine-verified, not just asserted in prose"
    - "Notification dismiss on every exit path of persistFinalizedTrip (success, short-trip discard, catch block) — T-02-20 mitigation, machine-verified by the fake _RecordingNotifications in every test"
    - "Sealed PersistResult with three final variants matching the TrackingState pattern from plan 02-03 — UI exhaustive switch with no default branch, compile error if a new variant lands"
    - "Test-only seam via @visibleForTesting named method (not a setter) so audits can grep call sites and the ignore: use_setters_to_change_properties documents the deliberate deviation"
    - "UI-isolate showRecording() call rather than service-isolate — keeps the foreground response handler bound to the same flutter_local_notifications plugin state that registered it (the service isolate has a separate plugin instance)"
    - "main() bootstrap order: WidgetsFlutterBinding.ensureInitialized → await TrackingNotificationService().initialize() → await configureBackgroundService() → runApp — each plugin touched only after binding is up"

key-files:
  created:
    - lib/features/tracking/services/tracking_notification_service.dart
    - lib/features/tracking/services/tracking_service_events.dart
    - test/unit/features/tracking/persist_finalized_trip_test.dart
  modified:
    - lib/features/tracking/services/tracking_service.dart
    - lib/features/tracking/services/tracking_service_controller.dart
    - lib/features/tracking/providers/tracking_providers.dart
    - lib/features/tracking/screens/tracking_screen.dart
    - lib/main.dart

key-decisions:
  - "Event-name constants moved to a new feature-local tracking_service_events.dart rather than staying file-private in tracking_service.dart. Rationale: tracking_notification_service.dart needs kStopTrackingEvent for its Stop action handlers, and importing tracking_service.dart would have pulled in that file's @pragma('vm:entry-point') isolate entrypoint. A tiny shared events file preserves plan 02-03's 'private coupling contract' intent (still not in lib/config/constants.dart) without creating a second copy of the strings."
  - "FinalizedTripCodec class added to tracking_providers.dart as the single audited Map<String, dynamic> → Map<String, Object?> cast site for the trip_finalized payload. Matches the pattern trackingActiveFromSnapshotMap established for kTrackingStateEvent in plan 02-03: one cast site per isolate-boundary payload."
  - "showRecording() is called FROM TrackingServiceController.start() (UI isolate) rather than from trackingServiceOnStart (service isolate). Reason: flutter_local_notifications plugin state in the service isolate is a separate instance from the UI-isolate plugin, so the foreground _onForegroundResponse handler would never fire if the notification were shown from the service isolate. The background pragma handler catches the Stop action when the app is backgrounded; the foreground method catches it when the app is focused."
  - "TrackingServiceController.start() wraps showRecording() in a bare try/catch (Deviation Rule 4). If POST_NOTIFICATIONS is not yet granted on Android 13+, tracking still works — the notification is simply absent until the user grants the permission. Phase 2 does not add a second permission flow; the manifest declares POST_NOTIFICATIONS and Android auto-prompts on first show()."
  - "setLastPersistResultForTesting is a named method with an explicit ignore: use_setters_to_change_properties rather than a Dart setter. Audits can grep setLastPersistResultForTesting and catch every production-code misuse; a setter (state = result) would be invisible."
  - "Rollback test instantiates a SyncQueueDao subclass (_ThrowingSyncQueueDao) whose enqueueCreate throws synchronously, then asserts trips table has length 0 after persistFinalizedTrip returns PersistFailed. This proves appDatabase.transaction rolls back both the trips insert and the attempted sync-queue insert — the single most important claim in this plan."
  - "ignore_for_file: unreachable_from_main on tracking_notification_service.dart. The lint does not trace Riverpod provider closures, so showRecording / dismiss / .new false-positive. Documented inline with the exact reachability chain (main → provider → controller → _notifications field → method)."
  - "service.setAsForegroundService() + service.setForegroundNotificationInfo(title, content: '') are called from trackingServiceOnStart for the Android isolate. Android requires foreground state promotion separately from the visible notification; the UI isolate's showRecording() then collapses onto the stock notification via the D-14 unification contract. Empty content avoids a flash of fbs's default body between service-start and the UI isolate's first show()."

patterns-established:
  - "Feature-local shared-constants file for isolate protocol event names — any new subsystem crossing the service ↔ UI boundary should follow the tracking_service_events.dart pattern: tiny file, no imports, only the string constants, imported by both producer and consumer, NOT in lib/config/constants.dart"
  - "Sealed {Feature}Result as the typed handle on async operation outcomes. PersistResult joins TrackingState as the second sealed-class in Phase 2; future features (sync engine, Cognito auth) should default to the same pattern instead of tuple returns or nullable success objects"
  - "Transaction-wrapped DAO writes for any operation that needs atomicity across multiple tables. appDatabase.transaction(() async { ... }) is the canonical form; rollback is exercised in a dedicated unit test with a deliberately failing DAO subclass"
  - "Fake service classes for Riverpod dependencies are hand-rolled inline in the test file (NOT mockito). Keeps the test's intent readable and avoids adding the mockito dev-dependency for a single recording-fake"

requirements-completed: [TRACK-01, TRACK-04, TRACK-05, UX-03]

# Metrics
duration: ~40min
completed: 2026-04-12
---

# Phase 02 Plan 05: Notification and Persistence Summary

**UX-03 foreground notification, D-10 short-trip discard, and atomic Drift persistence close Phase 2: TrackingServiceController.persistFinalizedTrip wraps TripsDao.insertTrip + SyncQueueDao.enqueueCreate in a single transaction (rollback-tested), the flutter_local_notifications wrapper collapses onto the fbs stock notification via the D-14 unification contract with a Stop action wired to both foreground and `@pragma('vm:entry-point')` background handlers, and main.dart bootstraps the plugin + service before runApp.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-04-12 (wave 4 of Phase 2)
- **Completed:** 2026-04-12
- **Tasks:** 4 (1 TDD RED→GREEN pair + 2 feat + 1 bootstrap)
- **Files created:** 3 (2 lib + 1 test)
- **Files modified:** 5 (tracking_service, tracking_service_controller, tracking_providers, tracking_screen, main)
- **Lines added:** ~780 (of which ~200 is the test file)

## Accomplishments

- Landed `lib/features/tracking/services/tracking_notification_service.dart` — a thin flutter_local_notifications 21.0 wrapper with `initialize()` / `showRecording()` / `dismiss()` and a v5-validated `_onForegroundResponse` that invokes `kStopTrackingEvent` only when the actionId matches `kTrackingStopActionId` exactly (T-02-17). The static "Recording commute" notification (D-14: no per-sample body, no flicker) uses Importance.low and category service, with `ongoing: true` / `autoCancel: false` so it cannot be swiped away while tracking.
- Top-level `trackingNotificationBackgroundHandler` with `@pragma('vm:entry-point')` catches Stop taps when the app is backgrounded. Documented as load-bearing: removing the pragma tree-shakes the function in release builds (Pitfall 4).
- File-level doc block on `tracking_notification_service.dart` locks in the D-14 unification contract: `kTrackingNotificationId` / `kTrackingNotificationChannelId` are the EXACT same constants `configureBackgroundService` pins `AndroidConfiguration.foregroundServiceNotificationId` / `notificationChannelId` to, so Android dedupes by `(channelId, notificationId)` and the UX-03 notification collapses onto the fbs stock notification instead of producing two shade entries. The warning is explicit: do not change either constant without updating both plans.
- Extracted the three service ↔ UI isolate event-name constants (`kTrackingStateEvent`, `kTripFinalizedEvent`, `kStopTrackingEvent`) from plan 02-03's `tracking_service.dart` into a new `tracking_service_events.dart`. Rationale documented both in the new file's header and in `tracking_service.dart`'s replacement comment: the notification service needs `kStopTrackingEvent` without pulling in the isolate entrypoint, and surfacing the constants in `lib/config/constants.dart` would leak a feature-private protocol globally. `tracking_service_controller.dart` and `tracking_providers.dart` now import from the shared file.
- `TrackingServiceController` expanded: now takes `AppDatabase database`, `TripsDao tripsDao`, `SyncQueueDao syncQueueDao`, `TrackingNotificationService notifications` as required named parameters. `start()` promotes the service, then calls `notifications.showRecording()` inside a defensive `try / on Object { }` (Deviation Rule 4 — POST_NOTIFICATIONS on Android 13+ may be denied).
- Added sealed `PersistResult` with three final variants: `PersistSaved(tripId)`, `PersistDiscardedTooShort()` (const singleton), and `PersistFailed(error)`. Matches the `TrackingState` sealed-class pattern from plan 02-03 — UI switches exhaustively without a default branch.
- Implemented `persistFinalizedTrip`:
  - Guards on `trip.durationSeconds < kMinTripDurationSeconds || trip.distanceMeters < kMinTripDistanceMeters` (D-10), returning `PersistDiscardedTooShort` after dismissing the notification.
  - Otherwise wraps `TripsDao.insertTrip(TripsCompanion.insert(...))` + `SyncQueueDao.enqueueCreate(trip.id)` in `_database.transaction(() async { ... })`. Direction is `kDirectionUnknown` (D-11); userId defaults to `kDefaultUserId` via the schema default (D-02); routePolyline is the encoded polyline wrapped in `Value<String?>`; sync_queue payload is null (D-13).
  - On success: dismiss + return `PersistSaved(trip.id)`.
  - On any `Object` caught: dismiss + return `PersistFailed(error)` (T-02-20: dismiss() runs on every exit path).
- `TrackingNotifier.trip_finalized` listener now decodes the payload via `FinalizedTripCodec.fromEventMap` (the single audited cast site for the trip_finalized boundary, matching `trackingActiveFromSnapshotMap` from plan 02-03), awaits `persistFinalizedTrip`, stashes the result in `_lastPersistResult`, then drops to `TrackingIdle`.
- Added `consumeLastPersistResult()` (read-and-clear) and the test-only `@visibleForTesting setLastPersistResultForTesting(PersistResult result)` seam the plan 02-06 widget tests will use. The method form with an inline `ignore: use_setters_to_change_properties` + explanatory comment is deliberate — a Dart setter would hide call sites from grep audits.
- `trackingNotificationServiceProvider` added. `trackingServiceControllerProvider` rewritten to resolve `appDatabase`, `tripsDao`, `syncQueueDao`, and the notification service via `ref.watch` from the already-present provider graph.
- `TrackingScreen` gained a `ref.listen<TrackingState>` inside `build()` that fires exactly once per `TrackingStopping → TrackingIdle` edge, consumes the last persist result, and shows the matching Material snackbar: `'Trip saved'` for `PersistSaved`, `'Trip too short to save'` for `PersistDiscardedTooShort`, `'Unable to save trip: ${error}'` for `PersistFailed`. `hideCurrentSnackBar()` fires before `showSnackBar()` so rapid cycles cannot queue duplicates.
- `tracking_service.dart`'s `trackingServiceOnStart` now calls `service.setAsForegroundService()` + `service.setForegroundNotificationInfo(title: kTrackingNotificationTitle, content: '')` for the Android isolate, so Android promotes the service to foreground state. The visible UX-03 notification is shown from the UI isolate; dismissal is handled by `persistFinalizedTrip` on the UI isolate (single plugin instance).
- `lib/main.dart` rewritten as `Future<void> main() async`. Calls `WidgetsFlutterBinding.ensureInitialized()` first, then `await TrackingNotificationService().initialize()` to register the Android channel and both tap handlers, then `await configureBackgroundService()` to register the fbs onStart entrypoint, then `runApp(const ProviderScope(child: TraevyApp()))`. Documented why the main-time instance and the Riverpod provider share state (FlutterLocalNotificationsPlugin is a singleton).
- Added 4 new unit tests in `test/unit/features/tracking/persist_finalized_trip_test.dart` (RED → GREEN):
  1. Duration below threshold (20s, 500m) → `PersistDiscardedTooShort`, empty trips table, empty sync_queue, one dismiss call.
  2. Distance below threshold (60s, 50m) → `PersistDiscardedTooShort`, empty tables, one dismiss call.
  3. Qualifying trip (120s, 800m) → `PersistSaved(id)`, exactly one row in `trips` with `direction='unknown'`, `userId='local_user'`, `routePolyline='polyline-value'`, exactly one row in `sync_queue` with `action='create'`, `status='pending'`, `payload=null`, one dismiss call.
  4. Rollback test — a `_ThrowingSyncQueueDao` subclass whose `enqueueCreate` throws — asserts `PersistFailed`, empty trips table (atomic rollback proven), empty sync_queue, one dismiss call (T-02-20 even on failure).
- Hand-rolled inline fakes (`_RecordingNotifications` implementing `TrackingNotificationService`, `_ThrowingSyncQueueDao` extending `SyncQueueDao`) keep the test file self-contained and avoid a mockito dev-dep.
- `flutter analyze` clean across the entire project — **No issues found**.
- `flutter test` — **all 64 tests green** (60 prior Phase 1 + Phase 2 waves 1–3 tests, plus the 4 new persist tests).

## Task Commits

| # | Task | Commit | Type |
|---|------|--------|------|
| 1 | Task 1: TrackingNotificationService + event constants extraction | `f301e4f` | feat |
| 2a | Task 2 RED: failing persist_finalized_trip tests | `b4e6efb` | test |
| 2b | Task 2 GREEN: persistFinalizedTrip + PersistResult + provider wiring | `8706abe` | feat |
| 3 | Task 3: notification show/dismiss hookup + tracking screen snackbar | `d659b26` | feat |
| 4 | Task 4: main.dart bootstrap | `2190093` | feat |

Each commit is atomic and addresses a single concern. Commit messages use the `feat(02-05): ...` / `test(02-05): ...` prefix convention from CLAUDE.md's "One concern per commit" rule.

## Files Created/Modified

### Created

- `lib/features/tracking/services/tracking_notification_service.dart` (188 lines) — UX-03 foreground notification wrapper with Stop action + top-level background handler. File-level `ignore_for_file: unreachable_from_main` with the reachability chain documented inline.
- `lib/features/tracking/services/tracking_service_events.dart` (36 lines) — feature-local shared-constants file for the three isolate protocol event names (`kTrackingStateEvent`, `kTripFinalizedEvent`, `kStopTrackingEvent`). File-level doc block explains why they are NOT in `lib/config/constants.dart`.
- `test/unit/features/tracking/persist_finalized_trip_test.dart` (199 lines) — 4 tests covering short-duration discard, short-distance discard, atomic save, and transaction rollback on sync-queue failure. Inline fakes.

### Modified

- `lib/features/tracking/services/tracking_service.dart` — imports event constants from the new `tracking_service_events.dart` instead of defining them locally. `trackingServiceOnStart` now promotes the Android service isolate to foreground state via `setAsForegroundService()` + `setForegroundNotificationInfo(title: ..., content: '')`, with the plan 02-05 placeholder block replaced by a concrete comment explaining the D-14 handoff. The stop-event handler's dismiss placeholder comment was rewritten to explain why dismissal belongs on the UI isolate.
- `lib/features/tracking/services/tracking_service_controller.dart` — constructor expanded with `AppDatabase` + `TripsDao` + `SyncQueueDao` + `TrackingNotificationService` required named parameters. `start()` now shows the notification on successful startService, guarded by try/catch (Deviation Rule 4). Added `persistFinalizedTrip` + sealed `PersistResult` hierarchy.
- `lib/features/tracking/providers/tracking_providers.dart` — `trackingNotificationServiceProvider` added; `trackingServiceControllerProvider` now resolves its four dependencies via `ref.watch`. `TrackingNotifier` gains `_lastPersistResult`, `consumeLastPersistResult`, and `setLastPersistResultForTesting`. The `trip_finalized` listener decodes via new `FinalizedTripCodec` helper, awaits `persistFinalizedTrip`, and drops to `TrackingIdle` regardless of outcome. Placeholder "Plan 02-05 hook" comments removed.
- `lib/features/tracking/screens/tracking_screen.dart` — added `ref.listen<TrackingState>` in `build()` that fires on the `TrackingStopping → TrackingIdle` edge and dispatches `_handlePersistResult`, which shows the matching snackbar via `ScaffoldMessenger.of(context)`.
- `lib/main.dart` — rewritten as `Future<void> main() async` with `WidgetsFlutterBinding.ensureInitialized()` → `TrackingNotificationService().initialize()` → `configureBackgroundService()` → `runApp`.

## Decisions Made

- **Event-name constants extracted to `tracking_service_events.dart`.** Plan 02-03 kept them file-private in `tracking_service.dart` so they could not leak globally. Plan 02-05 needs `kStopTrackingEvent` in the notification service without importing the isolate entrypoint, so the three constants moved into a tiny shared file that both producer and consumer import. The "feature-local, not in lib/config/constants.dart" rule is preserved — the new file is inside `lib/features/tracking/services/` and is only imported by tracking-feature files.
- **`showRecording()` called from the UI isolate, not the service isolate.** `flutter_local_notifications` plugin state in the service isolate is a separate instance from the UI-isolate plugin, so a notification shown from the service isolate would never fire the foreground `_onForegroundResponse` handler registered in the UI-isolate instance. The background `@pragma('vm:entry-point')` handler covers the backgrounded case. Documented explicitly in `tracking_notification_service.dart`'s file-level comment.
- **`persistFinalizedTrip` dismisses the notification on EVERY exit path.** Success, short-trip discard, and the catch block all call `_notifications.dismiss()`. This is the T-02-20 mitigation ("persistFinalizedTrip failure leaves notification visible"). The rollback test explicitly asserts `dismissCalls == 1` on failure, so any regression that forgets the dismiss in the catch block fails the suite.
- **Rollback is machine-verified.** The plan could have accepted "transaction wrapping is enough, Drift rolls back on exception" but plan 02-05's must-haves explicitly list transaction atomicity as a claim. The `_ThrowingSyncQueueDao` subclass pattern forces the sync-queue insert to throw after the trips insert lands, then asserts the trips table is empty — proving rollback rather than asserting it in prose.
- **`setLastPersistResultForTesting` is a named method, not a Dart setter.** `very_good_analysis`'s `use_setters_to_change_properties` lint flags it, but a setter (`state = result`) would be invisible to grep-based audits of test-only API usage. The `ignore: use_setters_to_change_properties` + the inline explanatory comment ("grep audits catch every call site") document the trade-off.
- **`@visibleForTesting` via `package:flutter/foundation.dart`** — not `package:meta/meta.dart`. Foundation re-exports `@visibleForTesting` and is already on Phase 2's transitive dependency tree (used by plans 02-02 and 02-03), so adding `meta` as an explicit dep would be redundant.
- **`FinalizedTripCodec` is a standalone helper class inside `tracking_providers.dart`.** One-function class rather than a top-level function because the `TrackingNotifier._finalizeSub` listener is the only caller, and the class gives the cast site a named identifier (`FinalizedTripCodec.fromEventMap`) that grep audits can trace. Matches the `trackingActiveFromSnapshotMap` adapter pattern from plan 02-03 but at the trip_finalized boundary rather than the tracking_state boundary.
- **`ignore_for_file: unreachable_from_main` on the notification service.** `unreachable_from_main` does not trace Riverpod provider closures; every instance method of `TrackingNotificationService` is reached transitively via `TrackingServiceController._notifications`, but the analyzer cannot prove it. Documented inline with the exact reachability chain; the alternative (marking every method `@pragma` or `@visibleForTesting`) would pollute the API surface for a false positive.
- **`try/catch` around `showRecording()` in `TrackingServiceController.start()`.** Android 13+ gates POST_NOTIFICATIONS behind a runtime permission. If the user has not yet granted it, `showRecording()` throws — but tracking itself should still work (the foreground service promotion via `setAsForegroundService()` does not need POST_NOTIFICATIONS). Deviation Rule 4 from the plan explicitly permits this soft-fail approach; the manifest declares POST_NOTIFICATIONS and Android will auto-prompt on first show().
- **`service.setForegroundNotificationInfo(title: kTrackingNotificationTitle, content: '')`.** Empty content avoids a flash of fbs's default body text between service-start and the UI isolate's first `show()`. The title matches so the D-14 unification replacement looks seamless to the user.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — API change] `FlutterLocalNotificationsPlugin.initialize / show / cancel` are fully-named-parameter in v21**
- **Found during:** Task 1 `flutter analyze`
- **Issue:** The plan's code block used the v17-style positional signature: `_plugin.initialize(initSettings, onDidReceiveNotificationResponse: ...)` and `_plugin.show(id, title, body, details)` and `_plugin.cancel(id)`. Version 21.0 (current in pubspec) moved to all named parameters: `initialize(settings: ..., onDidReceiveNotificationResponse: ...)`, `show(id: ..., title: ..., body: ..., notificationDetails: ...)`, `cancel(id: ..., tag: ...)`.
- **Fix:** Updated all three call sites to the v21 named-parameter form. Semantic meaning unchanged; behavior identical; just the parameter-passing style.
- **Files modified:** `lib/features/tracking/services/tracking_notification_service.dart`
- **Commit:** `f301e4f`

**2. [Rule 1 — Lint] `avoid_redundant_argument_values` on `showsUserInterface: false`**
- **Found during:** Task 1 `flutter analyze`
- **Issue:** `AndroidNotificationAction.showsUserInterface` defaults to `false`, which is the value the plan passes explicitly. very_good_analysis flagged it.
- **Fix:** Removed the explicit argument and added an inline comment documenting that the default-false is the desired behavior (Stop must not open the app). Zero functional change.
- **Files modified:** `lib/features/tracking/services/tracking_notification_service.dart`
- **Commit:** `f301e4f`

**3. [Rule 1 — Lint] `lines_longer_than_80_chars` in file-level doc comment and provider declaration**
- **Found during:** Task 1 + Task 2 + Task 4 `flutter analyze`
- **Issue:** Multiple doc-comment and declaration lines exceeded 80 characters (long-identifier provider names, long D-14 contract references, long configureBackgroundService reference in main).
- **Fix:** Wrapped each offending line, splitting at appropriate natural breakpoints (variable name / type, sentence boundary in doc comments). Zero semantic change.
- **Files modified:** `lib/features/tracking/services/tracking_notification_service.dart`, `lib/features/tracking/providers/tracking_providers.dart`, `lib/main.dart`
- **Commits:** `f301e4f`, `8706abe`, `2190093`

**4. [Rule 1 — Lint] `comment_references` on doc-comment brackets for private / not-in-scope members**
- **Found during:** Task 2 `flutter analyze`
- **Issue:** Doc comments used `[PersistResult]`, `[_lastPersistResult]`, `[consumeLastPersistResult]`, and `[persistFinalizedTrip]` in file-level and class-level doc blocks. `PersistResult` is defined in a different file; `_lastPersistResult` is private (leading-underscore names cannot be referenced from doc comments per very_good_analysis); `persistFinalizedTrip` is a cross-file reference without the qualifying class.
- **Fix:** Rewrote each reference in backtick form (`` `TrackingNotifier.consumeLastPersistResult` ``, `` `persistFinalizedTrip` ``, "private last-result slot"). `[PersistResult]` stayed because it IS imported into the file.
- **Files modified:** `lib/features/tracking/providers/tracking_providers.dart`
- **Commit:** `8706abe`

**5. [Rule 1 — Lint] `use_setters_to_change_properties` on `setLastPersistResultForTesting`**
- **Found during:** Task 2 `flutter analyze`
- **Issue:** The test-only seam writes a single field, which `use_setters_to_change_properties` wants converted to a Dart setter.
- **Fix:** Added an inline `// ignore: use_setters_to_change_properties` directive with a `document_ignores`-satisfying explanatory comment ("A named method (not a Dart setter) is deliberate so audits can grep for every call site"). The `@visibleForTesting` annotation sits above the ignore directive per analyzer rules.
- **Files modified:** `lib/features/tracking/providers/tracking_providers.dart`
- **Commit:** `8706abe`

**6. [Rule 1 — Lint false positive] `unreachable_from_main` on every instance method of TrackingNotificationService**
- **Found during:** Task 4 `flutter analyze`
- **Issue:** `unreachable_from_main` does not trace call sites through Riverpod provider closures. `showRecording` and `dismiss` are reached transitively from `main` via `trackingServiceControllerProvider → TrackingServiceController._notifications → showRecording()`, but the analyzer cannot prove it.
- **Fix:** Added `ignore_for_file: unreachable_from_main` with an inline comment documenting the exact reachability chain. This is preferable to either (a) marking every method with `@pragma` / `@visibleForTesting` (pollutes the public API surface for a false positive) or (b) moving the methods into `main.dart` (defeats the separation of concerns).
- **Files modified:** `lib/features/tracking/services/tracking_notification_service.dart`
- **Commit:** `2190093`

**7. [Rule 3 — Auth gate / POST_NOTIFICATIONS handling]**
- **Found during:** Task 3 plan review (not a real failure yet, but the plan's Deviation Rule 4 explicitly called out the risk)
- **Issue:** On Android 13+, `POST_NOTIFICATIONS` is a runtime permission. The first call to `FlutterLocalNotificationsPlugin.show()` before the user grants it throws. Tracking itself does not need the notification — the foreground service promotion via `setAsForegroundService()` is independent — so the notification absence should be a soft failure.
- **Fix:** Wrapped `showRecording()` in `start()` with `try / on Object { }`. Comment documents: "POST_NOTIFICATIONS denied on Android 13+ → tracking still works, the UX-03 notification is just absent until the user grants it. Do NOT rethrow (Deviation Rule 4)."
- **Files modified:** `lib/features/tracking/services/tracking_service_controller.dart`
- **Commit:** `8706abe`

---

**Total deviations:** 7 auto-fixed (6 Rule 1 lint adaptations, 1 Rule 3 / Rule 4 defensive auth gate per the plan's own Deviation Rule 4). Zero architectural deviations. Zero scope changes. Every fix preserved the plan's semantic intent; six were trivial API-change / lint adjustments.

## Issues Encountered

- **flutter_local_notifications 21.0 has a different API surface than the plan's code block assumed.** The plan used the v17 positional-parameter form (`show(id, title, body, details)`), but v21.0 moved to fully named parameters (`show(id: ..., title: ..., body: ..., notificationDetails: ...)`). Caught on the first `flutter analyze` of Task 1 and fixed inline — see Deviation #1. Lesson captured for future plans: when the pubspec.yaml has a newer major version than the stack-research document referenced, spot-check the API shape in pub-cache before coding against the old signature.
- **`unreachable_from_main` false-positives through Riverpod provider closures.** Even though `main()` calls `TrackingNotificationService().initialize()` directly AND the class instance methods are reached transitively through `TrackingServiceController._notifications`, the analyzer flagged every non-`initialize` method as unreachable. Solved with `ignore_for_file: unreachable_from_main` + inline chain documentation. A cleaner long-term fix would be to report this upstream to very_good_analysis or to migrate to `riverpod_lint` once the analyzer ^9/^10 conflict resolves, but neither is in scope for Phase 2.
- **No sandbox interference.** All verification commands (`flutter analyze`, `flutter test`, per-file analyze, individual test file runs) executed without the parallel-executor sandbox blocking `flutter pub get`. This worktree consistently allowed the full verification loop.

## User Setup Required

None for the code changes themselves. For live on-device testing in a future plan:
- Grant `POST_NOTIFICATIONS` permission on Android 13+ the first time the Start button is tapped (the manifest auto-prompts). Without it, tracking still works but the UX-03 notification is absent until the user grants it from system settings.

## Next Phase Readiness

**Plan 02-06 (widget tests)** is fully unblocked:
- `TrackingNotifier.setLastPersistResultForTesting(PersistResult result)` is the seam widget tests use to simulate any of the three PersistResult variants without driving a real service-isolate round trip.
- `trackingStateProvider` can be overridden in a `ProviderScope` with a test-double `TrackingNotifier` subclass.
- `trackingNotificationServiceProvider` can be overridden with a recording fake (the `_RecordingNotifications` pattern from `persist_finalized_trip_test.dart` is the canonical example).
- `trackingServiceControllerProvider` can be overridden with an in-memory AppDatabase wired to the real DAOs (the `persist_finalized_trip_test.dart` setUp shows the exact construction).

**Phase 3 (TRACK-03 direction auto-labeling)** can now safely backfill the `direction` column on rows currently stored as `kDirectionUnknown`. The Phase 2 contract guarantees every Phase 2 trip has `direction = 'unknown'`, so the Phase 3 backfill logic can filter on that value deterministically.

**Phase 9 (sync engine)** will find `sync_queue` rows with `action='create'`, `status='pending'`, `payload=null` ready to be drained. The Phase 1 D-13 contract — null payload for create rows, re-read from trips at sync time — is preserved.

## Self-Check

Verification of claims in this SUMMARY.

**Files created:**
- `lib/features/tracking/services/tracking_notification_service.dart` — FOUND
- `lib/features/tracking/services/tracking_service_events.dart` — FOUND
- `test/unit/features/tracking/persist_finalized_trip_test.dart` — FOUND

**Files modified (all in git log diff d7903e2..HEAD):**
- `lib/features/tracking/services/tracking_service.dart` — FOUND
- `lib/features/tracking/services/tracking_service_controller.dart` — FOUND
- `lib/features/tracking/providers/tracking_providers.dart` — FOUND
- `lib/features/tracking/screens/tracking_screen.dart` — FOUND
- `lib/main.dart` — FOUND

**Commits in git log (from `git log --oneline d7903e2..HEAD`):**
- `f301e4f` feat(02-05): add TrackingNotificationService with Stop action and extract event constants — FOUND
- `b4e6efb` test(02-05): add failing tests for persistFinalizedTrip transaction and short-trip discard — FOUND
- `8706abe` feat(02-05): persistFinalizedTrip with transaction and short-trip discard — FOUND
- `d659b26` feat(02-05): wire notification to service start and snackbar to tracking screen — FOUND
- `2190093` feat(02-05): initialise notification plugin and background service in main — FOUND

**Tripwire greps (executed against the worktree):**
- `grep -c 'appDatabase.transaction\|_database.transaction' lib/features/tracking/services/tracking_service_controller.dart` → `1` (≥ 1 required)
- `grep -c 'kTrackingNotificationId' lib/features/tracking/services/tracking_notification_service.dart` → `4` (≥ 2 required — show + dismiss + 2 doc references)
- `grep -rc 'kBackgroundServiceNotificationId' lib/ test/` → `0` (regression check — no stale references to the pre-D-14 constant)
- `grep -c 'setLastPersistResultForTesting' lib/features/tracking/providers/tracking_providers.dart` → `2` (method declaration + doc reference)
- `grep -c "@pragma('vm:entry-point')" lib/features/tracking/services/tracking_notification_service.dart` → `3` (1 annotation + 2 mentions in doc comments)
- `grep -c kDirectionUnknown lib/features/tracking/services/tracking_service_controller.dart` → `2` (1 usage + 1 doc reference)
- `grep -c 'Trip too short to save' lib/features/tracking/screens/tracking_screen.dart` → `1` (the snackbar string literal)
- `grep -c 'WidgetsFlutterBinding.ensureInitialized' lib/main.dart` → `2` (1 call + 1 doc reference)
- `grep -r 'TODO\|FIXME' lib/features/tracking/ lib/main.dart` → no matches

**Verification commands:**
- `flutter analyze` → **No issues found! (ran in 1.9s)**
- `flutter test` → **+64: All tests passed!** (60 prior + 4 new persist tests)
- `flutter test test/unit/features/tracking/persist_finalized_trip_test.dart` → **+4: All tests passed!**

## Self-Check: PASSED

---
*Phase: 02-core-tracking*
*Plan: 02-05 — notification-and-persistence*
*Completed: 2026-04-12*
