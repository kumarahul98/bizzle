# Commute Tracker v0.1 — Task List

## Project Setup
- [ ] Initialize Flutter project with Android target
- [ ] Set up project folder structure (features-first architecture)
- [ ] Add core dependencies: drift, tracelet, google_sign_in, flutter_secure_storage, http, fl_chart, flutter_local_notifications, flutter_riverpod, riverpod_annotation
- [ ] Configure Android permissions: ACCESS_FINE_LOCATION, ACCESS_BACKGROUND_LOCATION, FOREGROUND_SERVICE, INTERNET
- [ ] Set up environment config (dev/prod) for API Gateway URLs and Cognito pool IDs
- [ ] Set up linting rules and analysis_options.yaml
- [ ] Set up Riverpod as state management solution, add flutter_riverpod and riverpod_annotation dependencies

---

## Auth & Onboarding
### AWS Cognito Setup
- [ ] Create Cognito User Pool with Google as federated identity provider
- [ ] Configure app client settings (OAuth scopes, callback URLs)
- [ ] Set up Cognito domain for hosted UI (if using) or native SDK flow

### Flutter Auth
- [ ] Integrate google_sign_in package
- [ ] Implement Cognito token exchange (Google ID token → Cognito tokens)
- [ ] Store tokens securely using flutter_secure_storage
- [ ] Implement session persistence — auto-refresh tokens on app restart
- [ ] Implement sign-out flow (clear local tokens + Cognito session)
- [ ] Build onboarding screen: Google sign-in button → location permission request → navigate to dashboard

---

## Local Database (Drift)
### Schema Design
- [ ] Define `trips` table: id (UUID), user_id, start_time, end_time, duration_seconds, distance_meters, route_polyline (encoded string), direction (to_office / to_home), time_moving_seconds (integer), time_stuck_seconds (integer), is_manual_entry, created_at, updated_at
- [ ] Define `sync_queue` table: id, trip_id, action (create / update / delete), payload (JSON), status (pending / synced / failed), created_at, synced_at
- [ ] Define `user_preferences` table: id, user_id, dark_mode (system / light / dark), morning_cutoff_hour, evening_cutoff_hour, reminder_enabled, reminder_time, weekend_reminder
- [ ] Generate Drift database class and DAO files
- [ ] Write migration strategy for future schema changes

### Data Access Layer
- [ ] CRUD operations for trips (insert, update, delete, get by id, get by date range)
- [ ] Query: trips for a specific day
- [ ] Query: trips for current week / current month
- [ ] Query: average duration grouped by direction
- [ ] Query: average duration grouped by day of week
- [ ] Query: weekly/monthly totals
- [ ] Query: 4-week trend data (weekly averages)
- [ ] Query: traffic stats — sum of time_stuck and time_moving per trip / per week
- [ ] Sync queue operations: enqueue, mark synced, mark failed, get pending items
- [ ] User preferences: get, update

---

## GPS Tracking (Tracelet)
- [ ] Initialize Tracelet with required config
- [ ] Implement start tracking — begin GPS capture on button press
- [ ] Implement stop tracking — end GPS capture, collect route data
- [ ] Configure background location tracking with foreground service
- [ ] Build persistent notification for active tracking ("Tracking your commute...")
- [ ] Process raw GPS data from Tracelet into: total distance, route polyline (encoded), speed samples
- [ ] Calculate time_moving vs time_stuck from speed samples (threshold: 10 km/h)
- [ ] Auto-label trip direction based on time of day (configurable morning/evening cutoff)
- [ ] Handle edge cases: user kills app mid-tracking, GPS signal loss, location permission revoked
- [ ] Battery optimization — request exemption from Android battery saver for tracking accuracy

---

## Trip Management
- [ ] Save completed trip to Drift + enqueue to sync_queue
- [ ] Edit trip: update direction label, adjust start/end times, recalculate duration
- [ ] Delete trip: soft delete locally, enqueue delete action to sync_queue
- [ ] Manual trip entry form: date picker, start time, end time, direction selector (no GPS data)
- [ ] Validate manual entry (end time > start time, reasonable duration)

---

## Dashboard (Home Screen)
- [ ] Design dashboard layout
- [ ] Today's trips section: list of trips taken today with duration and direction badges
- [ ] Weekly summary card: total commute time this week, number of trips, avg duration
- [ ] "Time wasted in traffic this week" highlight stat
- [ ] Start/Stop commute FAB (floating action button) — prominent and always accessible
- [ ] Active tracking state: show elapsed time, current trip info
- [ ] Empty state: no trips today message with prompt to start tracking

---

## Daily Log Screen
- [ ] Calendar view (month view with dots on days that have trips)
- [ ] Tap a date → show list of trips for that day
- [ ] List view alternative: scrollable list grouped by date
- [ ] Tap a trip → navigate to trip detail screen
- [ ] Trip detail screen: map with route polyline, start/end markers, duration, distance, direction, time moving vs stuck breakdown
- [ ] Edit and delete actions on trip detail screen
- [ ] FAB or button to add manual trip entry

---

## Stats Screen
- [ ] Weekly total commute time (current week vs previous week comparison)
- [ ] Monthly total commute time
- [ ] Average commute duration — to office vs to home (bar chart or simple comparison)
- [ ] Best and worst day of the week (e.g., "Fridays avg 32 min, Tuesdays avg 58 min")
- [ ] 4-week trend line chart (weekly avg commute duration over last 4 weeks)
- [ ] Weekly "time wasted in traffic" total with week-over-week change
- [ ] Per-trip traffic breakdown: time moving vs time stuck (shown on trip detail, summarized here)
- [ ] Handle insufficient data state (less than 1 week of data — show what's available with note)

---

## Backend — AWS Infrastructure
### Cognito
- [ ] Deploy Cognito User Pool via SAM/CloudFormation
- [ ] Configure Google as identity provider
- [ ] Set up app client with appropriate OAuth settings

### DynamoDB
- [ ] Design DynamoDB single-table schema using NoSQL Workbench / DynamoDB skill designer — define PK/SK, GSIs, and access patterns based on app features (sync, restore, soft deletes)
- [ ] Deploy table via SAM/CloudFormation
- [ ] Set up TTL if applicable

### API Gateway + Lambda
- [ ] Set up API Gateway REST API with Cognito authorizer
- [ ] POST /trips/sync — batch upsert trips from client sync_queue
- [ ] DELETE /trips/{tripId} — mark trip as deleted in DynamoDB
- [ ] GET /trips/restore — dump all trips for authenticated user (restore endpoint)
- [ ] Lambda handlers in TypeScript with proper error handling and validation
- [ ] Input validation on all endpoints (trip schema validation)
- [ ] Deploy via SAM template
- [ ] Set up API Gateway stages (dev/prod)

---

## Sync Engine
- [ ] Background sync job: check sync_queue for pending items on app resume / connectivity change
- [ ] Batch pending sync items and POST to /trips/sync
- [ ] On success: mark items as synced in sync_queue
- [ ] On failure: mark as failed, implement retry with backoff (max 3 retries)
- [ ] Listen for connectivity changes (connectivity_plus package)
- [ ] Trigger sync when device comes back online
- [ ] Sync status indicator on dashboard (subtle — e.g., small icon or last synced timestamp)
- [ ] Handle auth token expiry during sync — refresh and retry

---

## Cloud Restore
- [ ] Settings screen: "Restore from cloud" button
- [ ] Confirmation dialog: "This will merge cloud data with your local data. Continue?"
- [ ] Call GET /trips/restore → receive all trips as JSON
- [ ] Write restored trips into Drift (skip duplicates by trip ID)
- [ ] Show restore progress and success/failure message

---

## Dark Mode
- [ ] Define light and dark color themes
- [ ] Store preference in user_preferences table (system / light / dark)
- [ ] Settings screen toggle: System Default / Light / Dark
- [ ] Apply theme dynamically using ThemeMode

---

## Notifications
### Weekly Summary
- [ ] Schedule local notification every Sunday evening (or Monday morning)
- [ ] Content: "You spent Xh Ym commuting this week across N trips"
- [ ] Pull stats from Drift to compose notification content

### Tracking Reminder
- [ ] Store usual departure time in user_preferences (auto-detect after 1 week of data, or manual set)
- [ ] Schedule daily reminder at configured time: "Time to head out? Start tracking your commute"
- [ ] Allow user to enable/disable from settings
- [ ] Do not fire reminder on weekends (configurable)

### Foreground Service Notification
- [ ] Persistent notification while tracking is active
- [ ] Show elapsed time in notification
- [ ] Quick action: "Stop Tracking" button in notification

---

## Settings Screen
- [ ] User profile section: Google account name/email, sign-out button
- [ ] Appearance: dark mode toggle (System / Light / Dark)
- [ ] Commute preferences: morning/evening cutoff hours for auto-labeling direction
- [ ] Notifications: toggle weekly summary, toggle tracking reminder, set reminder time
- [ ] Data: "Restore from cloud" button
- [ ] Sync status: last synced timestamp
- [ ] About: app version

---

## Polish & Edge Cases
- [ ] App icon and splash screen
- [ ] Loading states for all async operations
- [ ] Error handling: network failures, GPS failures, storage full
- [ ] Empty states for dashboard, daily log, stats (first-time user experience)
- [ ] Graceful handling of location permission denied / revoked
- [ ] Handle app being killed during active tracking (resume or discard partial trip)
- [ ] Test on Android 12+ (background location restrictions)
- [ ] Test on aggressive OEMs (Samsung, Xiaomi, OnePlus) for background service survival

---

## Testing
- [ ] Unit tests: Drift DAOs, stats calculations, sync queue logic, traffic speed threshold logic
- [ ] Widget tests: dashboard, trip detail, stats charts
- [ ] Integration tests: full trip lifecycle (start → track → stop → save → sync)
- [ ] Test restore flow end-to-end
- [ ] Test offline-first behavior: create trips offline → come online → verify sync
- [ ] Test auth flow: sign in, session persist, token refresh, sign out