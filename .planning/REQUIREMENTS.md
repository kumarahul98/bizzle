# Requirements: Commute Tracker

**Defined:** 2026-04-11
**Core Value:** Show people the reality of their commute — time wasted in traffic and how it changes over time.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Authentication

- [x] **AUTH-01**: User can sign in with Google account via Firebase Auth (Google provider)
- [x] **AUTH-02**: User session persists across app restarts via secure token storage
- [x] **AUTH-03**: User completes onboarding flow (Google sign-in, location permission grant, done)

### Tracking

- [ ] **TRACK-01**: User can start and stop commute recording with a single tap
- [ ] **TRACK-02**: GPS captures location in background while screen is off via foreground service
- [x] **TRACK-03
**: Trip direction auto-labeled (morning = to_office, evening = to_home) with editable override
- [ ] **TRACK-04**: Each trip records start/end time, duration, distance, and encoded route polyline
- [ ] **TRACK-05**: Per-trip traffic breakdown: time moving vs time stuck (speed < 10 km/h threshold)
- [x] **TRACK-06
**: User can edit trip details (direction label, adjust times)
- [x] **TRACK-07
**: User can delete a trip with confirmation dialog
- [x] **TRACK-08
**: User can manually enter a forgotten trip (date, duration, direction — no GPS data)

### Trip History

- [ ] **HIST-01**: User can browse past commutes in a daily list view
- [ ] **HIST-02**: User can browse past commutes via calendar view
- [ ] **HIST-03**: User can tap a trip to view route on map with full details

### Stats

- [ ] **STAT-01**: User can view weekly and monthly total commute time
- [ ] **STAT-02**: User can view average commute duration split by direction (to-office vs to-home)
- [ ] **STAT-03**: User can see best and worst commute day of the week
- [ ] **STAT-04**: User can view 4-week commute trend line
- [ ] **STAT-05**: User can see weekly "time wasted in traffic" total

### Data & Sync

- [ ] **SYNC-01**: All trip data stored locally in Drift (offline-first, works without network)
- [x] **SYNC-02**: Trips sync one-way from Drift to Firestore (via Cloud Functions) through a background sync queue
- [x] **SYNC-03**: User can restore trips from cloud backup via settings (reinstall/device switch)

### Backend

- [x] **BACK-01**: Firebase Auth with Google provider handles authentication
- [x] **BACK-02**: POST /trips/sync Cloud Function batch-upserts trips from client
- [x] **BACK-03**: DELETE /trips/{tripId} Cloud Function soft-deletes a trip
- [x] **BACK-04**: GET /trips/restore Cloud Function returns all trips for authenticated user

### UX

- [ ] **UX-01**: Dashboard home screen shows today's trips and weekly summary card
- [ ] **UX-02**: Dark mode support (system default + manual toggle in settings)
- [ ] **UX-03**: Persistent notification displayed while GPS tracking is active
- [ ] **UX-04**: Weekly summary push notification with commute totals
- [ ] **UX-05**: Tracking reminder notification at user's usual departure time

## v0.2 (iOS Support) Requirements

iOS port of the existing Android app with full feature parity, runnable on a real iPhone via Xcode (no TestFlight/App Store this milestone). Realizes **PLAT-01** from v2. Derived from `.planning/research/SUMMARY.md` (2026-06-02).

### iOS Platform & Build

- [x] **IOS-01**: App builds and launches on the iOS Simulator from a generated `ios/` project
- [x] **IOS-02**: App installs and launches on a real iPhone via Xcode free (7-day) provisioning
- [x] **IOS-03**: `Info.plist` and Xcode entitlements are configured — location usage strings, `UIBackgroundModes: location`, Keychain Sharing, notification usage, reversed-client-ID URL scheme, bundle ID `com.travey.app`

### Auth on iOS

- [x] **IOS-04**: User can sign in with Google on iOS (reversed-client-ID URL scheme + `iosClientId`)
- [x] **IOS-05**: User session persists across app restarts on iOS via Keychain (no `-34018` failure)

### Background GPS on iOS

- [x] **IOS-06**: User can record a commute on iOS with GPS continuing while the app is backgrounded / screen off (CoreLocation `allowBackgroundLocationUpdates`)
- [x] **IOS-07**: GPS does not silently pause during stop-and-go traffic on iOS (`pauseLocationUpdatesAutomatically: false`), so moving/stuck traffic stats stay accurate
- [x] **IOS-08**: App detects iOS reduced-accuracy ("Approximate Location") and requests/handles full accuracy so speed-based traffic calculation remains valid

### Permissions, Notifications & UX on iOS

- [ ] **IOS-09**: User grants location via the iOS two-step When-In-Use → Always flow during onboarding, with "When In Use only" handled as a valid degraded state
- [ ] **IOS-10**: User grants notification permission on iOS; weekly summary and departure-reminder notifications fire
- [ ] **IOS-11**: The Android-only persistent tracking notification is suppressed on iOS (no phantom notification); the active-commute tracking signal on iOS is the Live Activity (iOS 17+) or, below 17, the system blue location indicator
- [ ] **IOS-13**: On iOS 17+, an active commute shows a Live Activity (lock screen + Dynamic Island) with live elapsed/distance/moving-stuck stats and an in-place Stop button, updating from the `TripAccumulator` stream and dismissed on trip stop; iOS < 17 degrades to blue-indicator-only with in-app Stop
- [ ] **IOS-14**: The Android ongoing "Active commute" foreground notification is enriched to show the same live stats (elapsed/distance/moving-stuck) as the iOS Live Activity, with no regression to the foreground-service binding

### Parity Validation

- [ ] **IOS-12**: All identical-behavior features (trip CRUD, manual entry, daily log/calendar, route map via flutter_map, all stats, sync, cloud restore, dark mode) are verified working on a real iPhone

## v0.3 (App Improvements) Requirements

Android-facing UX fixes and features requested 2026-06-06. Built on branch `gsd/v0.3-app-improvements`. Realizes **AUTO-02** (geofence triggers) and **PLAT-02** (home-screen widget) from v2, scoped to labeling and start/stop respectively.

### Tracking & Trips

- [x] **TRACK-09**: User can pause and resume an active commute (for a break — snack/meeting) without ending the trip; paused time is excluded from duration and moving/stuck stats
- [x] **TRACK-10**: User can enable an auto-pause prompt — when an active trip appears stationary beyond a threshold, a notification offers to pause the trip
- [x] **TRACK-11**: User can edit all details of a trip — start time, end time, and individual break/pause segments — with duration and traffic stats recomputed
- [x] **TRACK-12**: User can set or change a trip's direction (to-home / to-office) via a quick label selector during tracking and from the trip view
- [ ] **TRACK-13**: If the app is killed mid-trip (force-quit, app cleared/swiped away, or OS-level interruption), the active trip's state is persisted continuously so that on next launch the app detects the interrupted trip, logs it, informs the user, and offers to resume the trip or discard it

### Cloud Sync

- [ ] **SYNC-04**: When the user signs in (including on a fresh install or new device), their cloud trips are restored into Drift automatically — no manual "Restore" tap required — deduplicating by trip UUID against any local trips
- [ ] **SYNC-05**: A finished trip is synced to the cloud immediately on save, and sync items that previously exhausted their retries (marked failed) are automatically re-attempted later instead of remaining stuck until a manual action

### First-Run & Auth

- [x] **AUTH-04**: On first install the user sees a login screen with a "Skip" option that lets them use the app locally without signing in; sync stays disabled until they sign in later from settings

### Saved Locations

- [ ] **LOC-01**: User can set their Home and Office locations (map/coordinate picker) and persist them in preferences
- [x] **LOC-02**: Trips are auto-labeled to-home / to-office based on the proximity of trip start/end to the saved Home/Office locations, taking precedence over the time-of-day heuristic when a confident match exists

### Home-Screen Widget

- [ ] **WIDGET-01**: User can add an Android home-screen widget that starts or stops a commute with one tap and reflects the current tracking state

### Display Fixes

- [x] **UX-06**: The active-tracking elapsed timer always renders fully on screen — never wrapping the last digit to a new line or clipping — regardless of elapsed duration

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Automation

- **AUTO-01**: Automatic trip detection without manual start/stop
- **AUTO-02**: Geofence-based trip triggers — *partially realized in v0.3 as geofence auto-labeling (LOC-02); auto start/stop still deferred*

### Platform

- **PLAT-01**: iOS support — *promoted to the v0.2 milestone (see IOS-01..IOS-12)*
- **PLAT-02**: Home screen widget with today's commute summary — *start/stop widget realized in v0.3 (WIDGET-01); summary-content widget still deferred*

### Analytics

- **ANLYT-01**: Month-over-month comparison charts
- **ANLYT-02**: Route comparison (same commute, different routes)
- **ANLYT-03**: Trip export to CSV/JSON

### Sync

- **SYNC2-01**: Two-way sync between devices

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time traffic data integration | High complexity, GPS speed is sufficient proxy for v0.1 |
| Multi-stop trip chaining | Single A-to-B commute trips only for MVP simplicity |
| Social/sharing features | Personal utility first, social deferred indefinitely |
| Server-side analytics | Client computes all stats locally; server is backup only |
| Navigation/routing | Not a navigation app; records trips, doesn't plan them |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 9 | Complete |
| AUTH-02 | Phase 9 | Complete |
| AUTH-03 | Phase 9 | Complete |
| TRACK-01 | Phase 2 | Complete |
| TRACK-02 | Phase 2 | Complete |
| TRACK-03 | Phase 3 | Complete |
| TRACK-04 | Phase 2 | Complete |
| TRACK-05 | Phase 2 | Complete |
| TRACK-06 | Phase 3 | Complete |
| TRACK-07 | Phase 3 | Complete |
| TRACK-08 | Phase 3 | Complete |
| HIST-01 | Phase 4 | Complete |
| HIST-02 | Phase 4 | Complete |
| HIST-03 | Phase 4 | Complete |
| STAT-01 | Phase 5 | Complete |
| STAT-02 | Phase 5 | Complete |
| STAT-03 | Phase 5 | Complete |
| STAT-04 | Phase 5 | Complete |
| STAT-05 | Phase 5 | Complete |
| SYNC-01 | Phase 1 | Complete |
| SYNC-02 | Phase 11 | Complete |
| SYNC-03 | Phase 11 | Complete |
| BACK-01 | Phase 9 | Complete |
| BACK-02 | Phase 10 | Complete |
| BACK-03 | Phase 10 | Complete |
| BACK-04 | Phase 10 | Complete |
| UX-01 | Phase 6 | Complete |
| UX-02 | Phase 7 | Complete |
| UX-03 | Phase 2 | Complete |
| UX-04 | Phase 7 | Complete |
| UX-05 | Phase 7 | Complete |
| IOS-01 | Phase 12 | Complete |
| IOS-02 | Phase 12 | Complete |
| IOS-03 | Phase 12 | Complete |
| IOS-04 | Phase 13 | Complete |
| IOS-05 | Phase 13 | Complete |
| IOS-06 | Phase 14 | Complete |
| IOS-07 | Phase 14 | Complete |
| IOS-08 | Phase 14 | Complete |
| IOS-09 | Phase 15 | Pending |
| IOS-10 | Phase 15 | Pending |
| IOS-11 | Phase 15 | Pending |
| IOS-12 | Phase 16 | Pending |
| IOS-13 | Phase 15 | Pending |
| IOS-14 | Phase 15 | Pending |
| TRACK-09 | Phase 18 | Complete |
| TRACK-10 | Phase 18 | Complete |
| TRACK-11 | Phase 19 | Complete |
| TRACK-12 | Phase 17 | Complete |
| AUTH-04 | Phase 20 | Complete |
| LOC-01 | Phase 21 | Pending |
| LOC-02 | Phase 21 | Complete |
| WIDGET-01 | Phase 22 | Pending |
| SYNC-04 | Phase 24 | Pending |
| SYNC-05 | Phase 24 | Pending |
| TRACK-13 | Phase 25 | Pending |
| UX-06 | Phase 17 | Complete |

**Coverage:**
- v1 requirements: 31 total — mapped to phases: 31 — unmapped: 0
- v0.2 requirements: 14 total — mapped to phases: 14 — unmapped: 0
- v0.3 requirements: 9 total — mapped to phases: 9 — unmapped: 0

---
*Requirements defined: 2026-04-11*
*Last updated: 2026-06-02 — added v0.2 (iOS Support) requirements IOS-01..IOS-12 (full Android→iOS parity); PLAT-01 promoted from v2. Traceability for IOS-* filled during v0.2 roadmap creation.*
*Last updated: 2026-06-06 — v0.3 (App Improvements) roadmap created: TRACK-09..12, AUTH-04, LOC-01, LOC-02, WIDGET-01, UX-06 mapped to Phases 17-22. Added SYNC-04, SYNC-05 (Phase 24 — Automatic Cloud Sync & Restore) and TRACK-13 (Phase 25 — Interrupted-Trip Recovery).*
