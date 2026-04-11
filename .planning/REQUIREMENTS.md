# Requirements: Commute Tracker

**Defined:** 2026-04-11
**Core Value:** Show people the reality of their commute — time wasted in traffic and how it changes over time.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Authentication

- [ ] **AUTH-01**: User can sign in with Google account via AWS Cognito federation
- [ ] **AUTH-02**: User session persists across app restarts via secure token storage
- [ ] **AUTH-03**: User completes onboarding flow (Google sign-in, location permission grant, done)

### Tracking

- [ ] **TRACK-01**: User can start and stop commute recording with a single tap
- [ ] **TRACK-02**: GPS captures location in background while screen is off via foreground service
- [ ] **TRACK-03**: Trip direction auto-labeled (morning = to_office, evening = to_home) with editable override
- [ ] **TRACK-04**: Each trip records start/end time, duration, distance, and encoded route polyline
- [ ] **TRACK-05**: Per-trip traffic breakdown: time moving vs time stuck (speed < 10 km/h threshold)
- [ ] **TRACK-06**: User can edit trip details (direction label, adjust times)
- [ ] **TRACK-07**: User can delete a trip with confirmation dialog
- [ ] **TRACK-08**: User can manually enter a forgotten trip (date, duration, direction — no GPS data)

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
- [ ] **SYNC-02**: Trips sync one-way from Drift to DynamoDB via background sync queue
- [ ] **SYNC-03**: User can restore trips from cloud backup via settings (reinstall/device switch)

### Backend

- [ ] **BACK-01**: AWS Cognito user pool with Google federation handles authentication
- [ ] **BACK-02**: POST /trips/sync endpoint batch-upserts trips from client
- [ ] **BACK-03**: DELETE /trips/{tripId} endpoint soft-deletes a trip
- [ ] **BACK-04**: GET /trips/restore endpoint returns all trips for authenticated user

### UX

- [ ] **UX-01**: Dashboard home screen shows today's trips and weekly summary card
- [ ] **UX-02**: Dark mode support (system default + manual toggle in settings)
- [ ] **UX-03**: Persistent notification displayed while GPS tracking is active
- [ ] **UX-04**: Weekly summary push notification with commute totals
- [ ] **UX-05**: Tracking reminder notification at user's usual departure time

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Automation

- **AUTO-01**: Automatic trip detection without manual start/stop
- **AUTO-02**: Geofence-based trip triggers

### Platform

- **PLAT-01**: iOS support
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
| AUTH-01 | — | Pending |
| AUTH-02 | — | Pending |
| AUTH-03 | — | Pending |
| TRACK-01 | — | Pending |
| TRACK-02 | — | Pending |
| TRACK-03 | — | Pending |
| TRACK-04 | — | Pending |
| TRACK-05 | — | Pending |
| TRACK-06 | — | Pending |
| TRACK-07 | — | Pending |
| TRACK-08 | — | Pending |
| HIST-01 | — | Pending |
| HIST-02 | — | Pending |
| HIST-03 | — | Pending |
| STAT-01 | — | Pending |
| STAT-02 | — | Pending |
| STAT-03 | — | Pending |
| STAT-04 | — | Pending |
| STAT-05 | — | Pending |
| SYNC-01 | — | Pending |
| SYNC-02 | — | Pending |
| SYNC-03 | — | Pending |
| BACK-01 | — | Pending |
| BACK-02 | — | Pending |
| BACK-03 | — | Pending |
| BACK-04 | — | Pending |
| UX-01 | — | Pending |
| UX-02 | — | Pending |
| UX-03 | — | Pending |
| UX-04 | — | Pending |
| UX-05 | — | Pending |

**Coverage:**
- v1 requirements: 31 total
- Mapped to phases: 0
- Unmapped: 31

---
*Requirements defined: 2026-04-11*
*Last updated: 2026-04-11 after initial definition*
