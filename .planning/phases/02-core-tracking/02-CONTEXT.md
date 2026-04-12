# Phase 2: Core Tracking - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

User can record a commute from start to stop with background GPS capture and a persistent foreground-service notification, producing a complete trip row in Drift with start/end time, duration, distance, polyline, and moving/stuck time breakdown. Direction auto-labeling, trip editing, trip list, manual entry, and stats are out of scope — those live in Phase 3+.

Requirements covered: TRACK-01, TRACK-02, TRACK-04, TRACK-05, UX-03.

</domain>

<decisions>
## Implementation Decisions

### GPS Stack
- **D-01:** Try the Tracelet package first. Researcher must verify in Task 1 whether it exists on pub.dev, is actively maintained, and can drive a foreground service on Android 14. If any of those checks fail, fall back to `geolocator ^13` + `flutter_background_service ^5` (the stack research's proven path). Do not spend more than 1 investigation task on Tracelet — ship with the fallback if in doubt.
- **D-02:** Process position stream client-side. Use each sample's `speed` field (from the selected stack) to drive moving/stuck classification — do not compute speed from `distance / time` deltas.

### Sampling & Metrics
- **D-03:** Compute `time_moving_seconds` and `time_stuck_seconds` using **streaming accumulators** during tracking. On each sample, add `(sample.time - prev.time)` to the moving counter if prev.speed ≥ `kStuckSpeedThresholdKmh`, otherwise to the stuck counter. Accumulators are maintained in the active tracking state (Riverpod notifier). On stop, counters are ready without a second pass.
- **D-04:** Distance is accumulated from sample-to-sample Haversine deltas into a single `distance_meters` counter during tracking, for the same reason as D-03.
- **D-05:** GPS sampling config (distance filter, accuracy filter, interval) is Claude's discretion. Researcher should land on values that keep battery reasonable for a 30-minute commute.

### App Kill Resilience
- **D-06:** Best-effort foreground service only. **Samples live in memory** (and the streaming accumulators) for the duration of a trip. No incremental persistence to a `live_trip_samples` table. If Android kills the process mid-trip, the in-progress samples are lost and the user restarts manually. Accepted tradeoff: simpler code, ships fast, the foreground service makes kills rare in practice on Android 14.

### Permission Flow
- **D-07:** Two-step permission request. On first app launch / onboarding, request `ACCESS_FINE_LOCATION` (while-using). On the first Start-tracking tap, upgrade to `ACCESS_BACKGROUND_LOCATION`. This matches Android 11+'s required dance for background location.
- **D-08:** If the user denies background, tracking still works but stops when the app is backgrounded. Show a dismissible banner on the tracking screen explaining the limitation and linking to system settings. Do NOT block Start.
- **D-09:** If foreground location is denied, Start is disabled and the UI shows a clear CTA to grant permission in settings.

### Trip Save Threshold
- **D-10:** A stopped trip is persisted only if BOTH conditions are met: duration ≥ **30 seconds** AND distance ≥ **100 meters**. Below the threshold, discard the in-memory trip and show a Material snackbar on the tracking screen: "Trip too short to save". Thresholds go in `lib/config/constants.dart` as `kMinTripDurationSeconds = 30` and `kMinTripDistanceMeters = 100`.
- **D-11:** Direction column gets a neutral Phase-2 default (empty string or a `kDirectionUnknown = 'unknown'` constant — Claude decides). Phase 3 (auto-labeling) backfills based on start_time.

### Active Tracking UI
- **D-12:** Phase 2 ships a single tracking screen with live stats. Layout: large **Stop** button, three live-updating tiles for **duration**, **distance**, and **current speed**. No map (map lives in Phase 4's trip detail screen — maps pkg is not added in Phase 2). Tiles tick on every GPS sample via Riverpod.
- **D-13:** Dashboard / home screen is NOT Phase 2. Phase 2 can land a minimal route entry — e.g., a placeholder home scaffold with a "Start commute" button that navigates to the tracking screen — but no dashboard summary card. The real dashboard is Phase 6.

### Foreground Notification (UX-03)
- **D-14:** Notification content is **static text** "Recording commute" + a **Stop action button**. Tapping the body opens the tracking screen. Tapping Stop finalizes the trip the same way the in-app Stop button does. Static text means the notification doesn't refresh per sample — cheaper on battery and avoids notification flicker.
- **D-15:** Use `flutter_local_notifications ^18` — already listed in the stack research. Android notification channel named "Active commute" with importance LOW (non-intrusive, non-dismissible while service is running).

### Claude's Discretion
- Tracelet verification details (exact pub.dev / repo checks)
- GPS sampling frequency and distance filter values
- Polyline encoding approach (Google polyline string via `flutter_polyline_points` expected)
- Haversine implementation (pull from existing lib or write a small helper)
- Riverpod provider graph for tracking state (notifier + state classes)
- File/folder layout within `lib/features/tracking/`
- Exact snackbar/banner copy for permission denial and short-trip cases
- Whether `time_moving + time_stuck` must equal `duration` exactly or can differ by sub-second drift — researcher to advise

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project spec
- `CLAUDE.md` — Full project spec, especially "Traffic Calculation", "Data Flow", "Speed threshold (10 km/h)" sections
- `.planning/PROJECT.md` — Core value, constraints (offline-first, client-authoritative)
- `.planning/REQUIREMENTS.md` — TRACK-01, TRACK-02, TRACK-04, TRACK-05, UX-03 acceptance criteria

### Stack research (from Phase 1)
- `.planning/research/STACK.md` — GPS stack recommendations, package versions, Tracelet risk note
- `.planning/research/ARCHITECTURE.md` — Four-layer architecture, how tracking fits
- `.planning/research/PITFALLS.md` — Android foreground service gotchas, permission pitfalls

### Phase 1 artifacts (what already exists in the codebase)
- `.planning/phases/01-foundation/01-CONTEXT.md` — Locked Phase 1 decisions (D-01..D-13)
- `lib/database/daos/trips_dao.dart` — The save destination for completed trips
- `lib/database/tables/trips_table.dart` — Schema this phase writes to
- `lib/config/constants.dart` — Where `kStuckSpeedThresholdKmh`, new `kMinTripDurationSeconds`, `kMinTripDistanceMeters`, `kDirectionUnknown` belong
- `android/app/src/main/AndroidManifest.xml` — Location + foreground service permissions already declared in Phase 1

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TripsDao.insertTrip(TripsCompanion)` — Phase 1 DAO inserts into `trips` table only. **Phase 2 must wrap `TripsDao.insertTrip` + `SyncQueueDao.enqueueCreate(tripId)` in an `appDatabase.transaction(() async { ... })` so the trip and its sync-queue entry land atomically.**
- `SyncQueueDao.enqueueCreate(String tripId)` — Phase 1 DAO. Payload is null; the sync engine (Phase 10) re-reads the fresh trip at sync time.
- `AppDatabase` + `appDatabaseProvider` (manual Riverpod Provider in `lib/database/providers.dart`) — access the DB from tracking code via `ref.read(appDatabaseProvider)`.
- `kStuckSpeedThresholdKmh = 10` in `lib/config/constants.dart` — the project's source-of-truth moving/stuck boundary in **km/h**. Phase 2 adds a derived `kStuckSpeedThresholdMs = kStuckSpeedThresholdKmh / 3.6` because `geolocator`'s `Position.speed` is in **m/s**, not km/h. Comparing raw `Position.speed` against `kStuckSpeedThresholdKmh` is a silent bug that classifies everything as stuck.
- `uuid` package is already in pubspec.yaml — use `const Uuid().v4()` for client-side trip IDs.

### Established Patterns
- **Manual Riverpod 3.x providers** — Phase 1 deferred `riverpod_generator` due to the analyzer ^9/^10 conflict with drift_dev 2.32.1. Phase 2 continues this: hand-written `Provider`, `NotifierProvider`, `StreamProvider` — no `@riverpod` annotation.
- **`very_good_analysis` strict linting** — doc comments on every public member, `package:traevy/...` absolute imports, no `dynamic`, no hardcoded values.
- **Constants in `lib/config/constants.dart`** — every new threshold / literal goes here, not inline.
- **Feature-first folder layout** — `lib/features/tracking/` owns its screens, services, and providers per CLAUDE.md.
- **Drift is the single source of truth** — the tracking UI reads its "saved trip" state via Drift streams after Stop, not from in-memory state.

### Integration Points
- **Drift database**: Tracking finalization wraps `TripsDao.insertTrip(companion)` + `SyncQueueDao.enqueueCreate(tripId)` in a single `appDatabase.transaction(() async { ... })`. Sync itself is Phase 10.
- **Riverpod providers**: A service-isolate-scoped `TripAccumulator` owns samples, distance, and moving/stuck counters during recording. A UI-side `TrackingNotifier` (manual Riverpod 3.x) exposes `TrackingState` to the tracking screen, ticking at 1 Hz from `service.invoke('tracking_state', ...)` snapshots. Samples never cross to the UI until finalization (D-06 — in-memory, service-isolate scoped). Database access via `appDatabaseProvider`.
- **AndroidManifest.xml**: **Currently contains ZERO location, background location, or foreground service permissions.** (Phase 1 plan 01-01 did NOT land them despite what the SUMMARY implied.) Phase 2 adds from scratch: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` (Android 14 subtype), plus `<service>` element with `android:foregroundServiceType="location"` and `tools:replace="android:foregroundServiceType"` (+ `xmlns:tools` namespace) to override `flutter_background_service`'s default service type.
- **Routes**: `lib/config/routes.dart` currently holds the placeholder route table. Phase 2 adds `/tracking` and wires a minimal navigation entry point.
- **Main app**: `lib/app.dart` currently renders `PlaceholderHome`. Phase 2 replaces that with a simple home that has a "Start commute" CTA.

</code_context>

<specifics>
## Specific Ideas

- Live tracking screen: three ticking tiles (duration / distance / current speed) + big Stop button. Feels satisfying during a commute.
- Notification should have a Stop button so the user can end a trip without opening the app.
- Short-trip rejection uses a Material snackbar, not a modal — less intrusive.
- Tracelet is worth a quick verification pass but not worth fighting. Fall back to geolocator without guilt.

</specifics>

<deferred>
## Deferred Ideas

- **Dashboard / home screen with today's trips + weekly summary** — Phase 6 (UX-01).
- **Trip detail screen with route map** — Phase 4 (HIST-03).
- **Direction auto-labeling** — Phase 3 (TRACK-03).
- **Trip edit / delete / manual entry** — Phase 3 (TRACK-06, 07, 08).
- **Stats dashboard** — Phase 5 (STAT-01..05).
- **Incremental sample persistence for crash recovery** — Deferred indefinitely unless real-world testing shows kills are common. Add to backlog if needed.
- **Weekly summary / reminder notifications** — Phase 7 (UX-04, UX-05).
- **Tracking reminder at usual departure time** — Phase 7 (UX-05).

</deferred>

---

*Phase: 02-core-tracking*
*Context gathered: 2026-04-12*
