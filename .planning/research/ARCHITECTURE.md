# Architecture Research

**Domain:** Offline-first GPS commute tracking (Flutter mobile + AWS serverless backend)
**Researched:** 2026-04-11
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                          │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐       │
│  │ Dashboard │ │ Tracking  │ │   Trips   │ │   Stats   │       │
│  │  Screen   │ │  Screen   │ │  Screens  │ │  Screen   │       │
│  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘       │
│        │              │              │              │            │
├────────┴──────────────┴──────────────┴──────────────┴────────────┤
│                     STATE LAYER (Riverpod)                       │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐    │
│  │   Auth     │ │  Tracking  │ │   Trip     │ │   Stats    │    │
│  │ Providers  │ │ Providers  │ │ Providers  │ │ Providers  │    │
│  └─────┬──────┘ └──────┬─────┘ └──────┬─────┘ └──────┬─────┘    │
│        │               │              │               │          │
├────────┴───────────────┴──────────────┴───────────────┴──────────┤
│                     SERVICE LAYER                                │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐    │
│  │  Auth      │ │  Tracelet  │ │   Trip     │ │Notification│    │
│  │  Service   │ │  Wrapper   │ │ Processor  │ │  Service   │    │
│  └─────┬──────┘ └──────┬─────┘ └──────┬─────┘ └────────────┘    │
│        │               │              │                          │
├────────┴───────────────┴──────────────┴──────────────────────────┤
│                     DATA LAYER                                   │
│  ┌──────────────────────────────┐  ┌──────────────────────┐      │
│  │     Drift Database           │  │    Sync Engine        │      │
│  │  ┌────────┐ ┌────────────┐   │  │  ┌───────────────┐   │      │
│  │  │  DAOs  │ │   Tables   │   │  │  │  Sync Queue   │   │      │
│  │  └────────┘ └────────────┘   │  │  │  Processor    │   │      │
│  └──────────────────────────────┘  │  └───────┬───────┘   │      │
│                                    │          │           │      │
│                                    │  ┌───────┴───────┐   │      │
│                                    │  │  API Client   │   │      │
│                                    │  └───────────────┘   │      │
│                                    └──────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │   AWS BACKEND     │
                    │ ┌───────────────┐ │
                    │ │ API Gateway   │ │
                    │ │ + Cognito     │ │
                    │ └───────┬───────┘ │
                    │ ┌───────┴───────┐ │
                    │ │   Lambda      │ │
                    │ │  Handlers     │ │
                    │ └───────┬───────┘ │
                    │ ┌───────┴───────┐ │
                    │ │  DynamoDB     │ │
                    │ │ (backup)      │ │
                    │ └───────────────┘ │
                    └───────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| Presentation (Screens/Widgets) | Render UI, capture user input, display data from providers | State Layer (Riverpod providers) only |
| State Layer (Riverpod Providers) | Hold reactive state, orchestrate service calls, expose data streams to UI | Service Layer, Data Layer (DAOs) |
| Auth Service | Google Sign-In flow, Cognito token exchange, token refresh, secure token storage | flutter_secure_storage, Cognito |
| Tracelet Wrapper | Configure GPS tracking, start/stop recording, emit location streams | Android location services, Trip Processor |
| Trip Processor | Convert raw GPS points into trip records (duration, distance, polyline, traffic stats) | Tracelet Wrapper (input), Drift DAOs (output) |
| Notification Service | Tracking foreground notification, reminders, weekly summary | Android notification system |
| Drift Database (DAOs) | All CRUD operations on trips, sync_queue, user_preferences | SQLite (via Drift) |
| Sync Engine | Process sync queue, batch upload, retry logic, connectivity awareness | Drift (sync_queue table), API Client |
| API Client | HTTP calls to API Gateway with Cognito JWT auth headers | AWS API Gateway |
| API Gateway + Cognito | JWT validation, request routing | Lambda handlers |
| Lambda Handlers | Validate input, execute DynamoDB operations (upsert, soft-delete, query) | DynamoDB |
| DynamoDB | Store trip backup data (single-table design, keyed by userId + tripId) | Lambda (only) |

## Recommended Project Structure

```
lib/
├── main.dart                    # App entry, ProviderScope, init
├── app.dart                     # MaterialApp, router, theme
├── config/
│   ├── constants.dart           # Speed thresholds, cutoff hours, retry limits
│   ├── routes.dart              # Named route definitions
│   └── theme.dart               # Light/dark ThemeData
├── features/
│   ├── auth/
│   │   ├── screens/             # LoginScreen, OnboardingScreen
│   │   ├── services/            # AuthService (Google + Cognito)
│   │   └── providers/           # authStateProvider, userProvider
│   ├── tracking/
│   │   ├── screens/             # ActiveTrackingScreen
│   │   ├── services/            # TraceletWrapper, TripProcessor
│   │   └── providers/           # trackingStateProvider
│   ├── dashboard/
│   │   ├── screens/             # DashboardScreen
│   │   ├── widgets/             # SummaryCard, TodayTrips, TrackingFAB
│   │   └── providers/           # dashboardProvider
│   ├── trips/
│   │   ├── screens/             # DailyLogScreen, TripDetailScreen, ManualEntryScreen
│   │   ├── widgets/             # TripCard, RouteMapView, CalendarView
│   │   └── providers/           # tripsProvider, tripDetailProvider
│   ├── stats/
│   │   ├── screens/             # StatsScreen
│   │   ├── widgets/             # DurationChart, TrafficBreakdown, TrendLine
│   │   └── providers/           # statsProvider, trafficStatsProvider
│   └── settings/
│       ├── screens/             # SettingsScreen
│       └── providers/           # settingsProvider
├── database/
│   ├── database.dart            # AppDatabase class (Drift)
│   ├── database.g.dart          # Generated code (build_runner)
│   ├── tables/
│   │   ├── trips_table.dart
│   │   ├── sync_queue_table.dart
│   │   └── user_preferences_table.dart
│   └── daos/
│       ├── trips_dao.dart
│       ├── sync_queue_dao.dart
│       └── user_preferences_dao.dart
├── sync/
│   ├── sync_engine.dart         # Queue processor with retry + backoff
│   └── api_client.dart          # HTTP wrapper for API Gateway
├── notifications/
│   └── notification_service.dart
└── shared/
    ├── widgets/                 # Reusable UI (LoadingOverlay, ErrorBanner, etc.)
    ├── utils/                   # DateHelpers, Formatters, SpeedCalculations
    └── models/                  # DTOs for API serialization (not for UI state)
```

### Structure Rationale

- **features/:** Feature-first grouping keeps each vertical slice self-contained. A developer working on stats never needs to touch tracking code. Each feature owns its screens, widgets, providers, and services.
- **database/:** Centralized because Drift requires a single database class. DAOs are split per table for testability. Tables are separate files for readability.
- **sync/:** Separate from features because sync is a cross-cutting infrastructure concern, not a user-facing feature. It operates independently in the background.
- **shared/:** Minimal -- only truly reusable utilities and widgets. Resist moving feature-specific code here.
- **config/:** App-wide constants, theme, and routing. Single source for all magic numbers and configuration.

## Architectural Patterns

### Pattern 1: Offline-First with Client-Authoritative Sync

**What:** All data operations read/write to the local Drift database. The server is a passive backup. Sync is a one-way push from client to server via a persistent queue. The client never reads from the server during normal operation (only during explicit restore).

**When to use:** Single-user apps where one device is the primary writer and the server exists for backup/restore purposes only. This describes the Commute Tracker exactly.

**Trade-offs:**
- Pro: No conflict resolution, no merge logic, works fully offline, simple mental model
- Pro: UI is always fast -- no network latency in the read path
- Con: Multi-device support is limited (only one device can be authoritative at a time)
- Con: If local DB is lost before sync completes, data is gone

**Implementation approach:**
```
Write path:  UI -> Provider -> DAO.insert(trip) -> DAO.enqueueSyncAction("create", trip)
Read path:   UI -> Provider -> DAO.watchTrips() -> Stream<List<Trip>>
Sync path:   SyncEngine.processPending() -> API Client -> POST /trips/sync -> mark synced
Restore:     Settings -> API Client -> GET /trips/restore -> DAO.bulkInsert(skip duplicates)
```

### Pattern 2: Reactive Data Layer with Drift Streams

**What:** Drift DAOs expose `watch*()` methods that return `Stream<T>` instead of `Future<T>`. Riverpod providers wrap these streams with `StreamProvider`. UI rebuilds automatically when underlying data changes -- no manual refresh, no stale state.

**When to use:** Any time the UI needs to reflect data that can change (new trip saved, trip edited, sync status updated). This is the default read pattern for this app.

**Trade-offs:**
- Pro: UI is always in sync with database state. Save a trip and every screen showing trips updates automatically
- Pro: Eliminates entire classes of bugs (stale data, manual refresh, cache invalidation)
- Con: Must be careful with stream lifecycle -- close subscriptions on dispose
- Con: Complex queries (aggregates for stats) may need careful caching to avoid recomputation

**Example:**
```dart
// In DAO
Stream<List<Trip>> watchTodayTrips() {
  final today = DateTime.now().startOfDay;
  return (select(trips)..where((t) => t.startTime.isBiggerOrEqualValue(today)))
      .watch();
}

// In Provider
final todayTripsProvider = StreamProvider<List<Trip>>((ref) {
  final dao = ref.watch(tripsDaoProvider);
  return dao.watchTodayTrips();
});

// In Widget -- rebuilds automatically on changes
final trips = ref.watch(todayTripsProvider);
```

### Pattern 3: Sealed State Machines for Tracking

**What:** Use Dart sealed classes to model the tracking lifecycle as a finite state machine. The tracking state can only be in one of: Idle, Starting, Active(startTime, points), Stopping, Error. Transitions are explicit and exhaustive.

**When to use:** Any feature with a clear lifecycle (tracking session, sync status, auth state). Prevents impossible states.

**Trade-offs:**
- Pro: Compiler enforces exhaustive handling -- every screen that reads tracking state must handle all cases
- Pro: Impossible to accidentally show "active tracking" UI when tracking is idle
- Con: More boilerplate than a simple boolean flag (worth it for correctness)

**Example:**
```dart
sealed class TrackingState {
  const TrackingState();
}
class TrackingIdle extends TrackingState { const TrackingIdle(); }
class TrackingStarting extends TrackingState { const TrackingStarting(); }
class TrackingActive extends TrackingState {
  final DateTime startTime;
  final List<LatLng> points;
  const TrackingActive({required this.startTime, required this.points});
}
class TrackingStopping extends TrackingState { const TrackingStopping(); }
class TrackingError extends TrackingState {
  final String message;
  const TrackingError(this.message);
}
```

### Pattern 4: Background Sync Engine with Exponential Backoff

**What:** A dedicated sync engine processes the sync_queue table in the background. It runs on connectivity restore, app resume, and after trip save. Failed items retry with exponential backoff (e.g., 1s, 2s, 4s) up to 3 attempts, then are marked as failed.

**When to use:** Any offline-first app that needs to eventually push data to a server.

**Trade-offs:**
- Pro: Decouples data persistence from network availability entirely
- Pro: User never waits for sync -- the trip is saved locally instantly
- Con: Must handle the case where sync is permanently stuck (show indicator in settings)
- Con: Batch sync endpoint design matters -- sending one trip at a time is wasteful

## Data Flow

### Trip Recording Flow (Primary)

```
User taps START
    |
    v
TrackingProvider -> TraceletWrapper.startRecording()
    |
    v
Tracelet captures GPS points in background
(foreground notification shown)
    |
    v
User taps STOP
    |
    v
TrackingProvider -> TraceletWrapper.stopRecording()
    |                     |
    v                     v
Raw GPS points     TripProcessor.process(points)
                         |
                         v
                   Compute: duration, distance,
                   polyline, time_moving, time_stuck,
                   auto-label direction
                         |
                         v
                   TripsDAO.insertTrip(trip)
                         |
                    ┌─────┴─────┐
                    v           v
              trips table   sync_queue table
              (persisted)   (action: "create")
                    |
                    v
              Stream emits -> UI updates automatically
                    |
                    v
              SyncEngine.processPending() (async, non-blocking)
                    |
                    v
              API Client -> POST /trips/sync
                    |
                    v
              On success: mark sync_queue entry "synced"
              On failure: increment retry_count, backoff
```

### State Management Flow

```
Drift Database (source of truth)
    |
    v (watch streams)
Riverpod StreamProviders
    |
    v (ref.watch)
Widgets (rebuild on change)
    |
    v (user actions)
Riverpod StateNotifier / AsyncNotifier
    |
    v (service calls)
Services -> DAOs -> Drift -> SQLite
    |
    v (stream emits new data)
Cycle repeats automatically
```

### Auth Flow

```
User taps "Sign in with Google"
    |
    v
google_sign_in -> Google ID token
    |
    v
AuthService.exchangeToken(googleIdToken)
    |
    v
Cognito federated identity -> Cognito tokens (id, access, refresh)
    |
    v
flutter_secure_storage.write(tokens)
    |
    v
authStateProvider emits Authenticated(user)
    |
    v
Router navigates to Dashboard
    |
    v
On subsequent launches: read tokens from secure storage
    -> if expired: refresh with Cognito
    -> if refresh fails: re-prompt Google sign-in
```

### Sync Queue State Machine

```
Trip saved -> sync_queue entry (status: "pending")
    |
    v
SyncEngine picks up pending entries
    |
    ├── Network available?
    |     |
    |     ├── YES -> POST to API Gateway
    |     |     |
    |     |     ├── 200 OK -> status: "synced", set synced_at
    |     |     |
    |     |     └── Error -> retry_count++
    |     |           |
    |     |           ├── retry_count < 3 -> status: "pending" (backoff)
    |     |           |
    |     |           └── retry_count >= 3 -> status: "failed"
    |     |
    |     └── NO -> remain "pending", wait for connectivity
    |
    v
Failed items visible in Settings for user awareness
```

### Key Data Flows

1. **Trip Recording:** GPS points -> TripProcessor -> Drift insert -> auto-sync attempt. The write path never touches the network. Sync is fire-and-forget from the UI perspective.

2. **Stats Computation:** All stats are computed client-side from Drift queries. Weekly totals, averages, traffic breakdowns are all SQL aggregates or Dart computations over local data. No server roundtrip.

3. **Restore Flow:** User-initiated from Settings. GET /trips/restore returns all server-side trips. Client bulk-inserts into Drift, skipping duplicates by UUID. This is the only server-to-client data flow in v0.1.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-1k users | Current architecture is sufficient. DynamoDB on-demand handles this trivially. Lambda cold starts are acceptable for a backup-only API. |
| 1k-100k users | Add CloudWatch monitoring for Lambda errors and DynamoDB throttling. Consider provisioned DynamoDB capacity if restore queries spike. Batch sync endpoint should accept up to 25 trips per request (DynamoDB batch write limit). |
| 100k+ users | Add API Gateway throttling per-user. Consider S3 for route polyline storage if polylines are large. Add CloudFront in front of API Gateway for restore caching. Not needed for v0.1. |

### Scaling Priorities

1. **First bottleneck: Sync endpoint under burst load.** If many users sync simultaneously after regaining connectivity, Lambda concurrency could spike. Mitigation: API Gateway throttling + client-side jitter on sync timing.
2. **Second bottleneck: Restore queries on large trip histories.** A user with 2+ years of commutes could have 1000+ trips. Paginate the restore endpoint (return 100 trips per page) rather than loading all at once.

## Anti-Patterns

### Anti-Pattern 1: Reading from Server for UI Display

**What people do:** Fetch trip data from the API to display on dashboard or stats screens, treating the server as the primary data source.
**Why it's wrong:** Introduces network dependency into every screen load. Breaks offline-first. Creates latency on every navigation. Causes flicker between loading and loaded states.
**Do this instead:** All UI reads come from Drift streams. The server is invisible to the presentation and state layers. Only the sync engine and restore flow talk to the network.

### Anti-Pattern 2: Sync on Every Database Write

**What people do:** Trigger an immediate API call every time a trip is saved, blocking the save operation until sync completes or times out.
**Why it's wrong:** Couples local persistence to network availability. A failed sync could block trip saving. Rapid saves (edit, delete, edit) create race conditions with the server.
**Do this instead:** Write to Drift + enqueue to sync_queue. Sync engine processes the queue asynchronously. Batch multiple pending items into a single API call.

### Anti-Pattern 3: Putting Business Logic in Widgets

**What people do:** Compute traffic stats, format durations, or process GPS data directly in widget build methods.
**Why it's wrong:** Untestable (requires widget test harness). Recomputed on every rebuild. Duplicated across screens that show similar data.
**Do this instead:** Business logic goes in services (TripProcessor) or DAOs (aggregate queries). Providers expose computed results. Widgets are thin renderers.

### Anti-Pattern 4: God Provider

**What people do:** Create a single massive provider that manages auth state, tracking state, trip data, sync status, and settings.
**Why it's wrong:** Every state change triggers rebuilds in all watching widgets. Testing requires mocking the entire app state. Changes to one feature risk breaking another.
**Do this instead:** One provider per concern. Use `ref.watch` to compose providers when a feature needs data from multiple sources. Each provider is independently testable.

### Anti-Pattern 5: Ignoring GPS Battery Drain

**What people do:** Request high-accuracy GPS updates at maximum frequency (every 1 second) for the entire tracking duration.
**Why it's wrong:** Drains battery rapidly. Users will uninstall the app. Android may kill the background service.
**Do this instead:** Use balanced accuracy mode. Sample every 5-10 seconds during active tracking. Reduce frequency when speed is stable (not accelerating/decelerating). Let Tracelet handle this -- it's designed for power-efficient location tracking.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Google Sign-In | google_sign_in Flutter plugin -> ID token | Returns Google ID token; requires SHA-1 fingerprint in Google Cloud Console |
| AWS Cognito | Exchange Google token for Cognito tokens via federated identity | Configure Google as identity provider in Cognito User Pool; token refresh handled client-side |
| Tracelet | Flutter plugin API -> start/stop/stream | Handles background location permissions, foreground service, GPS sampling |
| API Gateway | REST calls with Cognito JWT in Authorization header | 3 endpoints only; Cognito authorizer validates JWT server-side |
| DynamoDB | Single-table design: PK=userId, SK=tripId | On-demand capacity; TTL not needed (soft deletes only) |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| UI <-> State | Riverpod providers (ref.watch / ref.read) | Widgets never call services directly |
| State <-> Data | DAO method calls, Drift streams | Providers hold DAO references via dependency injection |
| Data <-> Sync | Sync engine reads sync_queue table directly | Sync runs in isolate-safe manner; does not hold Drift connection across isolates |
| Tracking <-> GPS | Tracelet plugin API | Wrapper service abstracts Tracelet specifics from the rest of the app |
| App <-> Backend | HTTP via api_client.dart | Single point of contact with the network; all other code is network-unaware |

## Build Order (Dependency Chain)

The following build order reflects component dependencies -- each item depends on the items above it.

```
Phase 1: Foundation
  ├── Flutter project scaffold + config (constants, theme, routes)
  ├── Drift database setup (tables, generated code, DAOs)
  └── Riverpod provider scaffold

Phase 2: Auth
  ├── Google Sign-In integration
  ├── Cognito token exchange
  ├── Secure token storage
  └── Auth state provider + guarded routing

Phase 3: Core Tracking
  ├── Tracelet wrapper service
  ├── Trip processor (GPS points -> trip record)
  ├── Active tracking screen with start/stop
  ├── Foreground notification during tracking
  └── Trip persistence via TripsDAO

Phase 4: Trip Management
  ├── Daily log screen (list + calendar views)
  ├── Trip detail screen with route map
  ├── Edit trip (direction label, times)
  ├── Delete trip with confirmation
  └── Manual entry form

Phase 5: Stats & Dashboard
  ├── Dashboard home screen (today's trips, weekly summary)
  ├── Stats computation (averages, totals, trends, traffic)
  ├── Charts and visualizations (fl_chart)
  └── Weekly summary notification

Phase 6: Sync & Backend
  ├── AWS backend (SAM template, Lambda handlers, DynamoDB)
  ├── API client
  ├── Sync engine with queue processing
  ├── Connectivity-aware sync triggers
  └── Restore flow from settings

Phase 7: Polish
  ├── Dark mode toggle
  ├── Tracking reminders
  ├── Error states and edge cases
  └── Performance optimization
```

**Build order rationale:**
- **Database first** because every feature reads/writes to Drift. Cannot build anything without it.
- **Auth second** because user_id is required for trip records and sync. Backend auth (Cognito) is also needed before sync can work, but the auth UI flow is independent.
- **Tracking before trips** because you need trip data to exist before you can browse/edit it. Tracking produces the data that feeds everything else.
- **Trips before stats** because stats aggregate trip data. Without trips to query, stats screens have nothing to show.
- **Sync last** because the app must work fully offline. Sync is additive -- it does not change any existing behavior, only adds cloud backup. Building it last means the core app is complete and testable without any network dependency.
- **Polish last** because dark mode, reminders, and edge cases are important but do not block core functionality.

## Sources

- Drift documentation (drift.simonbinder.eu) -- reactive streams, DAO patterns, code generation
- Flutter Riverpod documentation (riverpod.dev) -- provider patterns, dependency injection, AsyncNotifier
- AWS SAM documentation (docs.aws.amazon.com/serverless-application-model) -- template structure, Lambda + API Gateway + DynamoDB
- AWS Cognito documentation (docs.aws.amazon.com/cognito) -- federated identity, Google sign-in integration
- Flutter background location best practices (developer.android.com/develop/sensors-and-location) -- battery optimization, foreground services

*Note: WebSearch was unavailable during research. Findings are based on established architectural patterns for offline-first mobile apps with GPS tracking. Confidence is HIGH because these are well-documented, stable patterns that have not changed significantly. The Flutter/Drift/Riverpod/AWS stack is mature and widely adopted.*

---
*Architecture research for: Commute Tracker (offline-first GPS tracking with AWS sync)*
*Researched: 2026-04-11*
