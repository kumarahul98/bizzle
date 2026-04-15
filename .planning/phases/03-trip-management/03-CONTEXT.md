# Phase 3: Trip Management - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can manage their trips: edit direction label and start/end times, delete trips with a confirmation dialog, manually enter forgotten trips, and have newly-saved trips auto-labeled by direction. Phase 3 also backfills all existing `kDirectionUnknown` rows saved in Phase 2.

Requirements covered: TRACK-03, TRACK-06, TRACK-07, TRACK-08.

Out of scope: trip list / history screen (Phase 4), route map (Phase 4), stats (Phase 5), dashboard (Phase 6).

</domain>

<decisions>
## Implementation Decisions

### Edit Surface
- **D-01:** Trip editing uses a **modal bottom sheet** — not a full-screen route. It slides up over the current context so the user retains visual reference to the trip they're editing. Swipe-to-dismiss closes without saving. Contains: direction toggle (SegmentedButton "To office" / "To home"), start time picker, end time picker, Cancel and Save buttons.
- **D-02:** No new named route for editing. The bottom sheet is invoked directly from wherever the trip is shown (home screen trip card, future trip list). This is the edit pattern for all trip interactions in Phase 3.

### Direction Auto-Labeling
- **D-03:** Auto-label logic reads `morning_cutoff_hour` from the `user_preferences` table (via `UserPreferencesDao`). If no preferences row exists, fall back to `kDefaultDirectionCutoffHour = 12`. This wires up the schema the table was designed for — when Phase 7 ships the settings UI, the cutoff will be user-configurable with no changes needed here.
- **D-04:** Labeling rule: `startTime.hour < morning_cutoff_hour → kDirectionToOffice`, `startTime.hour >= morning_cutoff_hour → kDirectionToHome`. Uses local time (convert from UTC at label time).

### Auto-Label Backfill
- **D-05:** On app start, Phase 3 runs a one-shot background backfill: query all trips where `direction == kDirectionUnknown`, apply the cutoff-based label, and batch-update them. Runs asynchronously after the UI is visible — must not block the home screen render. Enqueues a `kSyncActionUpdate` entry in `sync_queue` for each trip updated.
- **D-06:** New trips are labeled at save time inside the tracking finalization flow (the same transaction that calls `TripsDao.insertTrip`). Phase 2's `kDirectionUnknown` default is replaced — new trips always land with a real direction.

### Delete Flow
- **D-07:** Delete shows a Material `AlertDialog` with "Delete trip?" confirmation. Two actions: "Cancel" (text button, dismisses) and "Delete" (filled/destructive button, proceeds). After delete: remove from `trips` table, enqueue `kSyncActionDelete` in `sync_queue`. Show a `SnackBar` "Trip deleted" (no undo in Phase 3).
- **D-08:** Both the DAO calls (`TripsDao.deleteTrip` + `SyncQueueDao.enqueueDelete`) are wrapped in a single `appDatabase.transaction()` for atomicity — same pattern as trip save in Phase 2.

### Manual Entry
- **D-09:** A **[+] FAB** on the home screen invokes manual entry. Opens the same modal bottom sheet pattern (consistent with D-01). Form fields: date picker (shows today's date, user can change), duration text field (HH:MM format, e.g. "0:45"), direction toggle (To office / To home — defaults based on current time and cutoff, user can change).
- **D-10:** Manual trip is saved with `isManualEntry = true`, `routePolyline = ''` (empty string, not null — polyline column is non-nullable), `distanceMeters = 0.0`, `timeMovingSeconds = 0`, `timeStuckSeconds = 0`. Duration in seconds is computed from the HH:MM input. Start time is set to midnight of the chosen date; end time is `startTime + duration`.
- **D-11:** HH:MM input validation: max 23:59. If the field is empty or malformed, show inline field error — do not allow save. This is the only validation gate before saving.

### DAO Extensions (Phase 3 additions)
- **D-12:** `TripsDao` gains two new methods: `updateTrip(TripsCompanion companion)` and `deleteTrip(String id)`. These are the only new DAO methods Phase 3 adds — no `watchAllSummaries` changes needed yet (Phase 4 owns the list screen).
- **D-13:** `SyncQueueDao` gains `enqueueUpdate(String tripId)` and `enqueueDelete(String tripId)`. Consistent with existing `enqueueCreate` — payload is null for update (sync engine re-reads fresh trip), populated JSON for delete.

### Claude's Discretion
- Exact SegmentedButton vs ToggleButtons vs two-chip approach for direction selector (choose whichever is cleanest with Material 3)
- Time picker implementation (showTimePicker with MaterialTimePickerTheme)
- Date picker implementation (showDatePicker with reasonable past-only constraint)
- Exact bottom sheet height and drag handle styling
- SnackBar copy
- File/folder layout within `lib/features/trips/` and backfill service location
- Whether backfill runs via a dedicated Riverpod provider or as a side-effect in the app's init flow

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project spec
- `CLAUDE.md` — Full project spec: schema, folder structure, Riverpod conventions, coding rules
- `.planning/PROJECT.md` — Core value, offline-first constraint, direction auto-labeling rules
- `.planning/REQUIREMENTS.md` — TRACK-03, TRACK-06, TRACK-07, TRACK-08 acceptance criteria

### Prior phase artifacts
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-01..D-13: schema decisions, `kDefaultDirectionCutoffHour`, `kDefaultUserId`, Riverpod setup
- `.planning/phases/02-core-tracking/02-CONTEXT.md` — D-11: `kDirectionUnknown` default, D-06: in-memory samples, direction backfill deferred to Phase 3

### Existing code (what Phase 3 builds on)
- `lib/config/constants.dart` — `kDirectionUnknown`, `kDirectionToOffice`, `kDirectionToHome`, `kDefaultDirectionCutoffHour`, `kSyncActionUpdate`, `kSyncActionDelete`
- `lib/database/daos/trips_dao.dart` — Current DAO (insert/read only); Phase 3 adds `updateTrip` + `deleteTrip`
- `lib/database/daos/sync_queue_dao.dart` — Current DAO; Phase 3 adds `enqueueUpdate` + `enqueueDelete`
- `lib/database/daos/user_preferences_dao.dart` — Read `morning_cutoff_hour` for auto-labeling
- `lib/features/tracking/screens/home_screen.dart` — Phase 3 adds the [+] FAB here
- `lib/config/routes.dart` — Phase 3 does NOT add new routes (modal bottom sheets, not pushed routes)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TripsDao.watchAllSummaries()` — reactive stream of all trips; Phase 3 does not change this, but after edit/delete the stream automatically reflects the update
- `AppDatabase` + `appDatabaseProvider` — access via `ref.read(appDatabaseProvider)` in Riverpod notifiers
- `kDirectionToOffice`, `kDirectionToHome`, `kDirectionUnknown` — direction string constants in `constants.dart`
- `kDefaultDirectionCutoffHour = 12` — fallback if no user_preferences row
- `SyncQueueDao.enqueueCreate()` — pattern to follow for the new `enqueueUpdate` / `enqueueDelete`
- `appDatabase.transaction()` — established pattern for atomic multi-DAO operations (used in Phase 2 finalization)

### Established Patterns
- **Manual Riverpod 3.x providers** — no `@riverpod` codegen; hand-written `NotifierProvider` for all state
- **Sealed classes for finite state** — tracking state uses sealed classes; trip management state (idle/saving/error) should follow this pattern
- **`very_good_analysis` strict linting** — doc comments on public API, `package:traevy/...` absolute imports, no dynamic
- **Feature-first folder layout** — Phase 3 creates `lib/features/trips/` with its own screens/, widgets/, services/, providers/
- **Constants in `lib/config/constants.dart`** — any new thresholds or literals go here
- **Modal bottom sheet for edit** — decided in D-01; this sets the pattern for Phase 4+ interactions

### Integration Points
- **Home screen** (`lib/features/tracking/screens/home_screen.dart`): Phase 3 adds the [+] FAB. Consider whether to create a new `lib/features/trips/screens/home_screen.dart` that replaces the tracking-feature home, or extend the existing one in-place — Claude's discretion.
- **Trip save flow** (tracking finalization): direction auto-labeling at save time hooks into the existing `TripsDao.insertTrip` transaction in the tracking service
- **App init**: backfill service runs once after app startup; likely wired into the app-level Riverpod init or a dedicated `AppLifecycleProvider`

</code_context>

<specifics>
## Specific Ideas

- Edit bottom sheet: direction as segmented buttons + time pickers side-by-side, Cancel/Save at the bottom — clean, no excess chrome
- Manual entry sheet: "Add missed commute" title, date first, then HH:MM duration field, then direction toggle — mirrors the edit sheet's layout language
- FAB placement: bottom-right of home screen, [+] icon — standard Material 3 position

</specifics>

<deferred>
## Deferred Ideas

- **Trip list / daily log** — Phase 4 (HIST-01)
- **Trip detail with route map** — Phase 4 (HIST-03)
- **Undo delete** — not in scope for Phase 3; add to Phase 7 polish backlog if desired
- **Evening cutoff (`evening_cutoff_hour`)** — the user_preferences table has this column but the labeling rule is simpler (one cutoff, morning = office / evening = home). Phase 7 settings UI can expose it; auto-label code uses only `morning_cutoff_hour` for now.

</deferred>

---

*Phase: 03-trip-management*
*Context gathered: 2026-04-15*
