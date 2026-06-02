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
- [ ] **IOS-11**: The Android-only persistent tracking notification is suppressed on iOS (no phantom notification); tracking relies on the iOS system location indicator

### Parity Validation

- [ ] **IOS-12**: All identical-behavior features (trip CRUD, manual entry, daily log/calendar, route map via flutter_map, all stats, sync, cloud restore, dark mode) are verified working on a real iPhone

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Automation

- **AUTO-01**: Automatic trip detection without manual start/stop
- **AUTO-02**: Geofence-based trip triggers

### Platform

- **PLAT-01**: iOS support — *promoted to the v0.2 milestone (see IOS-01..IOS-12)*
- **PLAT-02**: Home screen widget with today's commute summary

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

**Coverage:**
- v1 requirements: 31 total — mapped to phases: 31 — unmapped: 0
- v0.2 requirements: 12 total — mapped to phases: 12 — unmapped: 0

---
*Requirements defined: 2026-04-11*
*Last updated: 2026-06-02 — added v0.2 (iOS Support) requirements IOS-01..IOS-12 (full Android→iOS parity); PLAT-01 promoted from v2. Traceability for IOS-* filled during v0.2 roadmap creation.*
