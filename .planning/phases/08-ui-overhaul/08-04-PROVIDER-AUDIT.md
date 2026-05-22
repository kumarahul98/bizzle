# Provider Disposal Audit — Phase 8 MainShell (Review HIGH #1)

This audit was performed before any IndexedStack / MainShell changes to ensure every provider
consumed by the four tab screens (Dashboard, History/Trips, Stats, Settings) is safe to remain
mounted simultaneously when `IndexedStack` keeps all four children alive.

## Audit Methodology

1. Enumerated every `ref.watch(...)` / `ref.read(...)` / `ref.listen(...)` call inside:
   - `lib/features/dashboard/screens/dashboard_screen.dart`
   - `lib/features/trips/screens/history_screen.dart`
   - `lib/features/stats/screens/stats_screen.dart`
   - `lib/features/settings/screens/settings_screen.dart`
   - All widget subdirectories (`dashboard/widgets/`, `trips/widgets/`, `stats/widgets/`) for transitive providers.
2. For each provider found, traced it to its declaration file and noted the provider kind and whether `.autoDispose` is present.
3. Applied the decision matrix:
   - **Decision A** — Has `.autoDispose` AND opens a stream/listener → Remove `.autoDispose`.
   - **Decision B** — Has `.autoDispose` AND opens a stream/listener, prefer `ref.keepAlive()`.
   - **Decision C** — Has `.autoDispose` AND is a pure derived/cheap computation → Keep as-is.
   - **No-Change** — Does NOT have `.autoDispose` (default kept-alive) → Document, no code change.

## Audit Results

| Provider | File | Type | autoDispose? | Used by tabs | Stream/side-effect? | Decision | Rationale |
|----------|------|------|-------------|-------------|---------------------|----------|-----------|
| `trackingStateProvider` | `lib/features/tracking/providers/tracking_providers.dart` | `NotifierProvider<TrackingNotifier, TrackingState>` | No | Dashboard | Yes — wraps fbs stream subscription | No-Change | Already kept-alive (explicit project decision, documented in file: "Do NOT switch any of these to .autoDispose") |
| `todaysTripSummariesProvider` | `lib/features/dashboard/providers/dashboard_providers.dart` | `Provider<AsyncValue<List<TripSummary>>>` | No | Dashboard | No — derived computation over allTripSummariesProvider | No-Change | Pure derived provider; no `.autoDispose` present; safe for IndexedStack |
| `statsSummaryProvider` | `lib/features/stats/providers/stats_providers.dart` | `Provider<AsyncValue<StatsSummary>>` | No | Dashboard, Stats | No — derived computation over allTripSummariesProvider | No-Change | Pure derived provider; no `.autoDispose` present; safe for IndexedStack |
| `allTripSummariesProvider` | `lib/features/trips/providers/history_providers.dart` | `StreamProvider<List<TripSummary>>` | No | Trips (History), transitively Dashboard + Stats | Yes — opens Drift stream via `watchAllSummaries()` | No-Change | Already kept-alive; single Drift subscription shared by all consumers (D-06) |
| `userPreferenceProvider` | `lib/features/settings/providers/settings_providers.dart` | `StreamProvider<UserPreferencesValue>` | No | Settings, transitively TraevyApp (theme) | Yes — opens Drift stream via `userPreferencesDao.watch()` | No-Change | Already kept-alive; no `.autoDispose` present |
| `trackingPermissionServiceProvider` | `lib/features/tracking/providers/tracking_providers.dart` | `Provider<TrackingPermissionService>` | No | Dashboard (`ref.read`) | No — synchronous service object | No-Change | Already kept-alive; `ref.read`-only (no watch subscription) |
| `userPreferencesDaoProvider` | `lib/database/providers.dart` | `Provider<UserPreferencesDao>` | No | Settings (`ref.read`) | No — DAO object | No-Change | Already kept-alive |
| `appDatabaseProvider` | `lib/database/providers.dart` | `Provider<AppDatabase>` | No | Settings (`ref.read`) | No — database object | No-Change | Already kept-alive |
| `tripManagementProvider` | `lib/features/trips/providers/trip_management_providers.dart` | `NotifierProvider<TripManagementNotifier, TripManagementState>` | No | Trips widgets (edit_trip_sheet, manual_entry_sheet) | No — in-memory state notifier | No-Change | Already kept-alive |
| `directionBackfillProvider` | `lib/features/tracking/providers/backfill_provider.dart` | `FutureProvider<void>` | No | TraevyApp (startup only) | No — one-shot future | No-Change | Already kept-alive; explicitly documented "Must NOT be `.autoDispose`" |

## Reviewer-Called-Out Providers

The code review (Review HIGH #1) specifically called out four providers. Each is addressed here:

1. **`todaysTripSummariesProvider`** — Actual symbol name in codebase: `todaysTripSummariesProvider` (exact match).
   - Declaration: `lib/features/dashboard/providers/dashboard_providers.dart`
   - Decision: **No-Change** (Decision N/A — no `.autoDispose` modifier present)
   - Rationale: `Provider<AsyncValue<List<TripSummary>>>` (not a `StreamProvider`). It is a derived/computed provider that watches `allTripSummariesProvider` without opening its own stream. No disposal concern.

2. **`statsSummaryProvider`** — Actual symbol name in codebase: `statsSummaryProvider` (exact match).
   - Declaration: `lib/features/stats/providers/stats_providers.dart`
   - Decision: **No-Change** (Decision N/A — no `.autoDispose` modifier present)
   - Rationale: `Provider<AsyncValue<StatsSummary>>` (derived, not a `StreamProvider`). Computes from `allTripSummariesProvider`. No separate stream; no disposal concern.

3. **`historyGroupsProvider`** — Actual symbol name in codebase: **`allTripSummariesProvider`** (renamed from reviewer's name; the history groups utility is a free function `groupTripsByDate()`, not a provider).
   - Declaration: `lib/features/trips/providers/history_providers.dart`
   - Decision: **No-Change** (Decision N/A — no `.autoDispose` modifier present)
   - Rationale: `StreamProvider<List<TripSummary>>` with no `.autoDispose`. Already kept-alive; documented as the single shared Drift subscription (D-06 single source of truth).

4. **`userPreferenceProvider`** — Actual symbol name in codebase: `userPreferenceProvider` (exact match).
   - Declaration: `lib/features/settings/providers/settings_providers.dart`
   - Decision: **No-Change** (Decision N/A — no `.autoDispose` modifier present)
   - Rationale: `StreamProvider<UserPreferencesValue>` with no `.autoDispose`. Opens a Drift stream but is already kept-alive by default.

## Code Changes

**None required.** Every provider consumed by the four tab screens is already non-autoDispose (kept-alive by default in Riverpod 3.x). No provider declarations were modified in this audit.

The project's existing conventions (documented in `lib/features/tracking/providers/tracking_providers.dart` and `lib/features/tracking/providers/backfill_provider.dart`) already mandate that all providers remain non-autoDispose — this design decision predates Phase 8 and was applied consistently across the codebase.

The IndexedStack introduced in Plan 04's MainShell is therefore safe: simultaneously mounting all four tab screens will not cause unexpected provider disposal or stream reconnection.
