# Pitfalls Research

**Domain:** Commute/GPS tracking mobile app (Flutter, Android, offline-first)
**Researched:** 2026-04-11
**Confidence:** MEDIUM (based on training data and established domain knowledge; no live web verification available)

## Critical Pitfalls

### Pitfall 1: Android OEM Battery Killers Silently Terminate Background GPS

**What goes wrong:**
The app works perfectly during development and testing, then users on Samsung, Xiaomi, Huawei, OnePlus, and Oppo devices report that tracking stops mid-commute. The OS aggressively kills background services to save battery. This is the single most common failure mode for GPS tracking apps on Android and it affects the majority of the Android install base.

**Why it happens:**
Android OEMs layer proprietary battery optimization on top of stock Android Doze mode. Samsung has "Sleeping apps" and "Deep sleeping apps." Xiaomi has "Battery saver" that kills background processes after screen-off. Huawei has "App launch management." These are enabled by default and cannot be bypassed programmatically. Stock Android's Doze mode alone throttles location updates when the screen is off, but OEM skins are far more aggressive -- they outright kill the process.

**How to avoid:**
1. Use a foreground service with a persistent notification (mandatory -- this is the only reliable approach). The CLAUDE.md already plans for this ("Persistent notification while tracking").
2. Request the user to exempt the app from battery optimization during onboarding. Use `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission and guide users to the setting.
3. Build a device-specific onboarding flow: detect the OEM and show manufacturer-specific instructions for disabling battery kill. The dontkillmyapp.com database catalogs these per-manufacturer.
4. Use `START_STICKY` or equivalent restart mechanism so the service restarts if killed.
5. Test on real Samsung, Xiaomi, and Pixel devices. These three cover the majority of failure modes.

**Warning signs:**
- Trip polylines that abruptly end mid-route
- GPS point gaps of 30+ seconds during what should be continuous recording
- Users reporting "tracking stopped" but the app still shows as running
- Discrepancy between trip duration (start-to-stop time) and the sum of GPS sample intervals

**Phase to address:**
Phase 1 (Tracking foundation) -- this must be solved before any tracking feature is usable. Build the foreground service and battery optimization exemption flow as part of the initial tracking implementation, not as a later fix.

---

### Pitfall 2: GPS Speed Data Is Unreliable Below 5-10 km/h

**What goes wrong:**
The traffic detection feature (speed < 10 km/h = stuck) produces wildly inaccurate results. Users sitting in a parked car show as "moving." Users stopped at a traffic light show speeds of 3-8 km/h. The "time stuck in traffic" stat becomes meaningless because GPS-derived speed at low velocities has an error margin that overlaps with the stuck/moving threshold.

**Why it happens:**
GPS position accuracy is typically 3-10 meters in urban areas, and much worse near tall buildings (urban canyon effect). When stationary, GPS positions "wander" by several meters per fix. If fixes are 1 second apart, a 5-meter wander produces a calculated speed of 18 km/h despite being stationary. GPS chipsets provide a speed field derived from Doppler shift which is more accurate than position-derived speed, but it still has 1-3 km/h error at low speeds. The 10 km/h threshold sits right in the noise floor.

**How to avoid:**
1. Use the GPS chipset's native speed field (from `Location.speed` on Android), not distance-between-points divided by time. Native speed uses Doppler and is significantly more accurate.
2. Check `Location.speedAccuracy` -- if the accuracy estimate exceeds the speed value, treat it as stationary.
3. Apply a minimum speed floor: speeds below 3 km/h should be treated as zero (stationary). Nobody commutes at walking speed in a vehicle.
4. Use a sliding window average (3-5 samples) to smooth GPS noise rather than classifying each individual fix.
5. Consider using accelerometer data as a secondary signal -- if the accelerometer shows no movement, the vehicle is stationary regardless of GPS readings.
6. Document to users that traffic time is an estimate, not exact.

**Warning signs:**
- "Time stuck" percentages above 80% on trips that the user reports as "mostly moving"
- Non-zero speed readings when the app is tested while stationary indoors
- Traffic stats that don't match user perception consistently
- Speed values jumping erratically between 0 and 15 km/h while stopped

**Phase to address:**
Phase 1 (Tracking/trip processing) -- the speed classification algorithm must be tuned with real GPS data from real commutes before shipping. Build the trip processor with configurable smoothing and test on actual recorded data.

---

### Pitfall 3: Drift Database Migrations Break Existing User Data

**What goes wrong:**
After shipping v0.1 and getting real users, any schema change to the Drift database risks destroying existing trip data. Developers add a column, change a type, or rename a table, and existing users' databases fail to migrate. The app crashes on startup or silently loses data.

**Why it happens:**
Drift (like all SQLite wrappers) requires explicit migration code for every schema change. Unlike server-side databases where you control the migration, mobile apps have users on every possible previous schema version. If you miss a migration step, or if a migration fails partway through, the database is in an inconsistent state. Drift's code generation makes it easy to change the schema in Dart and forget that existing databases need migration logic.

**How to avoid:**
1. Design the v0.1 schema carefully with future columns in mind. Add nullable columns for features you know are coming soon.
2. Write migration tests from day one: create a database with the old schema, run the migration, verify data integrity.
3. Use Drift's `schemaVersion` and `MigrationStrategy` properly. Increment version for every change. Never skip versions.
4. Always use `ALTER TABLE ADD COLUMN` for new fields (nullable with defaults). Never rename or remove columns in early versions.
5. Keep a migration log file that documents every schema version and what changed.
6. Implement a database backup before migration: copy the .db file before attempting any schema change so recovery is possible.

**Warning signs:**
- Schema changes made without corresponding migration code
- Migration tests missing from the test suite
- `schemaVersion` not incremented when tables change
- Columns added as non-nullable without defaults

**Phase to address:**
Phase 1 (Database setup) -- establish the migration strategy and testing pattern from the first schema definition. This is cheap to set up initially and extremely expensive to retrofit.

---

### Pitfall 4: Sync Queue Grows Unbounded While Offline

**What goes wrong:**
Users who are offline for extended periods (subway commuters, rural areas, airplane mode users) accumulate hundreds of sync queue entries. When connectivity returns, the app tries to sync everything at once, causing battery drain, UI freezes, API throttling, and Lambda timeouts from oversized batch payloads.

**Why it happens:**
The sync engine is designed for the happy path (sync after each trip, usually 1-2 pending items). Nobody tests what happens after 2 weeks offline with 40+ pending trips. The batch sync endpoint receives a massive payload. DynamoDB write capacity gets exhausted. The sync process blocks other operations.

**How to avoid:**
1. Implement chunked sync: process the queue in batches of 5-10 trips, not all at once.
2. Add backpressure: if the queue has more than N items, sync in the background with delays between batches.
3. Set a reasonable max payload size for the POST /trips/sync endpoint (e.g., 10 trips per request).
4. Use DynamoDB `BatchWriteItem` with its built-in 25-item limit, and handle `UnprocessedItems` for retries.
5. Show sync progress to the user when catching up ("Syncing 15 of 42 trips...") so they know it's working.
6. Never block the UI during bulk sync. Use isolates or background processing.

**Warning signs:**
- No upper bound on the sync batch size in the API client
- Sync triggered as a single fire-and-forget call regardless of queue size
- No progress indicator for sync status
- API Gateway 429 or Lambda timeout errors in CloudWatch

**Phase to address:**
Phase 2 (Sync engine) -- must be designed with chunking from the start, not added as a fix after users experience the problem.

---

### Pitfall 5: Foreground Service Notification Annoys Users Into Uninstalling

**What goes wrong:**
The persistent notification required for reliable background GPS tracking is visible the entire time a commute is being recorded. If it's poorly designed -- ugly, non-informative, or undismissable even after tracking stops -- users find it annoying. Worse, if the notification persists after tracking ends due to a bug, users uninstall the app.

**Why it happens:**
Android requires a foreground service notification for background location access. Developers treat it as a technical requirement and put minimal effort into the notification UX. The notification becomes a constant reminder that the app is "watching" them, triggering privacy anxiety.

**How to avoid:**
1. Make the notification useful: show elapsed time, current trip status, and a "Stop tracking" action button.
2. Immediately dismiss the notification when tracking stops. Test this thoroughly -- notification lifecycle bugs are common.
3. Use a low-priority notification channel so it doesn't appear at the top of the notification shade.
4. Style the notification to match the app's brand so it feels intentional, not like a system warning.
5. Never leave a stale notification. If the app process is killed, the notification must also disappear. Use `Service.stopForeground(true)` in the `onDestroy` callback.

**Warning signs:**
- Notification visible after tracking has stopped
- No action buttons on the notification (just static text)
- Notification uses default Android styling
- User reviews mentioning "annoying notification"

**Phase to address:**
Phase 1 (Tracking) -- the notification is integral to the tracking foreground service and must be designed alongside it.

---

### Pitfall 6: Cognito Token Refresh Race Conditions Break Sync

**What goes wrong:**
The Cognito JWT expires (typically after 1 hour). The sync engine fires a request with an expired token, gets a 401, tries to refresh, but another sync request is already refreshing the token. Both requests fail or one overwrites the other's refresh token. The user gets silently logged out or sync permanently fails.

**Why it happens:**
JWT refresh is a stateful operation (the refresh token can only be used once with some Cognito configurations). If multiple concurrent requests detect an expired token simultaneously and each tries to refresh independently, you get a race condition. This is especially common with the sync queue processing multiple items.

**How to avoid:**
1. Centralize token refresh in a single class with a mutex/lock. All HTTP requests go through this class.
2. When a 401 is received, queue the retry and trigger a single refresh. Do not let each failed request independently refresh.
3. Store tokens atomically: access token, refresh token, and expiry time must be written together, not separately.
4. Proactively refresh the token before it expires (e.g., refresh when less than 5 minutes remain) rather than waiting for a 401.
5. Handle the "refresh token expired" case gracefully: re-authenticate with Google Sign-In silently, or prompt the user to sign in again.

**Warning signs:**
- Intermittent 401 errors in sync logs despite the user being logged in
- Sync failures that resolve after force-quitting and reopening the app
- Multiple simultaneous token refresh calls visible in logs
- User reports of being "logged out" randomly

**Phase to address:**
Phase 1 (Auth) -- token management must be built with concurrency in mind from the start. Retrofitting a token refresh mutex is painful.

---

### Pitfall 7: Route Polyline Storage Bloats the SQLite Database

**What goes wrong:**
Each trip stores a route polyline (encoded GPS points). A 30-minute commute with GPS fixes every second produces 1,800 points. Even with Google's polyline encoding, each trip's polyline is 5-15 KB. After a year of daily commuting (~500 trips), the polylines alone consume 5-7 MB. This isn't catastrophic for SQLite, but it slows down queries that scan the trips table if not handled carefully.

**Why it happens:**
Developers store the polyline in the same table as trip metadata. Every query that touches the trips table (dashboard, stats, trip list) loads polyline data into memory even when it's not needed. A "show me my weekly stats" query doesn't need polylines, but if the column is in the table, Drift/SQLite loads it.

**How to avoid:**
1. Store polylines in a separate table (`trip_routes`) with a foreign key to `trips.id`. Only join when the route map is actually displayed.
2. Alternatively, use Drift's lazy loading or explicit column selection to exclude the polyline from default queries.
3. Downsample the polyline before storage: a commute route doesn't need sub-meter precision. Reduce to one point every 5-10 seconds using the Ramer-Douglas-Peucker algorithm. This cuts storage by 5-10x.
4. Set a max points limit per trip (e.g., 500 points) to prevent edge cases with very long trips.

**Warning signs:**
- Dashboard or stats screens getting slower over months of usage
- SQLite database file growing larger than expected
- Drift queries that `SELECT *` from the trips table

**Phase to address:**
Phase 1 (Database schema design) -- separate the polyline into its own table from the initial schema. Migrating this later requires moving data between tables.

---

### Pitfall 8: GPS Permission Flow Breaks on Android 12+ (API 31+)

**What goes wrong:**
The app requests location permission and gets denied, or gets only "approximate" (coarse) location instead of precise GPS. On Android 12+, the permission dialog splits "precise" and "approximate" location into separate toggles. Users who grant "approximate only" get GPS data with 1-2 km accuracy, making trip tracking and speed calculations useless.

**Why it happens:**
Android 12 introduced a two-toggle permission dialog: "Precise" vs "Approximate." Many users instinctively choose "Approximate" because it feels more private. Android 10+ added "While using the app" vs "All the time" for foreground/background location. Android 14 further restricts background location. Each API level adds new constraints, and the permission flow must handle all combinations gracefully.

**How to avoid:**
1. Request `ACCESS_FINE_LOCATION` and explicitly check for precise location grant. If only approximate is granted, show an explanation screen and guide to settings.
2. Request background location (`ACCESS_BACKGROUND_LOCATION`) as a separate step after foreground is granted. Android requires this to be a separate request.
3. Build a permission status checker that verifies: (a) fine location granted, (b) background location granted, (c) battery optimization exempted. Show status on a settings/debug screen.
4. Handle the "Don't ask again" case: detect permanently denied permission and deep-link to app settings.
5. Explain WHY precise location is needed before requesting it. Show a pre-permission rationale screen: "We need precise GPS to track your exact route and calculate traffic time."

**Warning signs:**
- Trip distances wildly inaccurate (off by kilometers)
- Speed always showing 0 or very low values
- Permission request dialogs not appearing (already permanently denied)
- Working on Pixel but broken on Samsung (different default permission behaviors)

**Phase to address:**
Phase 1 (Onboarding) -- the permission flow is part of onboarding and must be rock-solid before tracking can work.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Storing polylines in the trips table | Simpler schema, one table | Slow queries as data grows, painful migration later | Never -- separate from the start |
| Hardcoding the 10 km/h threshold without smoothing | Faster to implement | Inaccurate traffic stats, user complaints | MVP only, but add smoothing before public launch |
| Skipping migration tests | Faster initial development | Data loss on first schema change, emergency hotfix | Never -- write migration tests from schema v1 |
| Using `SELECT *` in Drift DAOs | Quick to write | Loads polylines and large fields unnecessarily | Never -- always select specific columns |
| Single retry with no backoff for sync | Simpler sync code | Hammers API when it's down, wastes battery | Never -- exponential backoff from day one |
| Testing only on emulator | No physical device needed | Misses OEM battery kill, real GPS behavior, notification bugs | Early prototyping only, must test on real devices before any release |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| AWS Cognito + Google Sign-In | Storing Google access token instead of exchanging for Cognito tokens | Exchange Google ID token for Cognito credentials via `GetId` + `GetCredentialsForIdentity` or Cognito Hosted UI. Use Cognito tokens for all API calls. |
| Drift code generation | Forgetting to run `build_runner` after schema changes, leading to runtime errors | Add `build_runner build` to a pre-commit hook or CI step. Never commit schema changes without regenerated code. |
| DynamoDB batch writes | Exceeding the 25-item limit on `BatchWriteItem` | Chunk client-side before calling DynamoDB. Handle `UnprocessedItems` in the response with retry. |
| Flutter foreground service | Using a Dart isolate for the service without proper communication channel | Use `flutter_foreground_task` or platform channels with a proper MethodChannel for communication between the service isolate and the main UI isolate. |
| API Gateway + Cognito authorizer | Using the wrong token type (access token vs ID token) in the Authorization header | Cognito authorizer expects the ID token by default. If using access token, configure the authorizer with token scopes. Verify which token type your authorizer expects. |
| connectivity_plus | Treating "connected to WiFi" as "has internet" | `connectivity_plus` only reports network interface status, not actual internet connectivity. Make a lightweight health check request to confirm real connectivity before syncing. |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading all trips for stats calculation | Stats screen takes seconds to render after months of use | Pre-aggregate weekly/monthly stats in a summary table, updated on trip save | 200+ trips (~3-4 months of daily use) |
| Unindexed Drift queries on `start_time` | Calendar view and daily log slow down | Add database indexes on `start_time`, `direction`, and `user_id` from the initial schema | 100+ trips |
| Rendering full polyline on trip list | Trip list scroll janks because each card decodes and renders a map | Only render map on trip detail screen. Show a static thumbnail or no map on list cards | 20+ trips visible in a scrollable list |
| Rebuilding Riverpod providers on every GPS fix | UI rebuilds every second during tracking, causing battery drain and jank | Throttle provider updates to every 3-5 seconds for UI display. Store all GPS fixes for processing but don't push each to the UI | Immediately during active tracking |
| JSON serializing entire trip payload for sync_queue | Sync queue entries duplicate all trip data as JSON text | Store only the trip_id in the sync queue and read fresh trip data at sync time. Reduces storage and keeps sync data current after edits | 50+ pending sync items |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing Cognito tokens in SharedPreferences | Tokens readable by other apps on rooted devices, or extractable from device backups | Use `flutter_secure_storage` which uses Android Keystore. Already planned in CLAUDE.md. |
| Sending GPS coordinates to the server without user consent transparency | Privacy violation, potential regulatory issues (GDPR if expanding to EU) | Be transparent in privacy policy. Store location data locally by default. Only sync trip metadata; consider whether polylines need to be synced at all. |
| No server-side validation of `user_id` in trip data | User A could push trips with User B's user_id, corrupting their data | Extract user_id from the Cognito JWT on the server side. Never trust the client-provided user_id. |
| Cognito refresh tokens with no rotation | Stolen refresh token grants indefinite access | Enable refresh token rotation in Cognito User Pool settings. Set reasonable token expiry (30 days, not infinite). |
| API Gateway without rate limiting | A compromised client or malicious user could spam the sync endpoint | Add API Gateway throttling (e.g., 10 requests/second per user). Use Cognito authorizer claims for per-user rate limiting. |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No feedback during active tracking | User doesn't know if tracking is working, anxiously checks the app | Show elapsed time, distance, and a pulsing indicator on the tracking screen. The foreground notification should also update periodically. |
| Requiring sign-in before allowing any tracking | Users bounce at the login screen before seeing value | Allow tracking without auth. Require sign-in only for sync/restore. Let users experience the core value (tracking a commute) immediately. |
| "Time stuck in traffic" without context | Raw number means nothing -- "42 minutes stuck" lacks meaning | Show percentage of trip time stuck AND comparison to average. "42 min stuck (68% of trip, vs your average 55%)." |
| Calendar view defaulting to month view | Monthly view is cluttered and hard to read for daily commuters | Default to week view. Daily commuters think in weeks, not months. |
| No way to discard a bad trip | User accidentally starts tracking while not commuting, trip pollutes stats | Add a "Discard trip" option immediately after stopping, and on the trip detail screen. Don't just delete -- confirm and explain it won't count toward stats. |

## "Looks Done But Isn't" Checklist

- [ ] **Background tracking:** Works on Pixel but test on Samsung with Adaptive Battery enabled -- it will likely be killed within 5 minutes of screen-off
- [ ] **Trip completion:** User stops tracking but trip processor hasn't finished computing distance/polyline -- handle async processing completion before showing trip summary
- [ ] **Offline sync:** App works offline, but verify: does the sync engine actually retry when connectivity returns, or does it only trigger on app resume?
- [ ] **Stats calculations:** Weekly averages look correct with 7 days of data but produce division-by-zero or misleading results with 1-2 days of data
- [ ] **Direction auto-labeling:** Works for a 9-5 schedule but breaks for night shift workers, weekend trips, or midday errands
- [ ] **Restore from cloud:** Restoring 500 trips works, but does it handle duplicate UUIDs correctly? Does it merge or overwrite? What about trips that were deleted locally?
- [ ] **Token refresh:** Auth works for 55 minutes after login, then silently fails. Test a sync that occurs 90 minutes after the last sign-in.
- [ ] **Polyline encoding:** Encodes and decodes correctly for straight routes, but verify with U-turns, loops, and GPS jumps that produce self-intersecting paths
- [ ] **Manual trip entry:** User can add a manual trip, but does it correctly set `is_manual_entry = true` and skip polyline/distance fields without crashing?
- [ ] **Database migration:** v0.1 schema works, but add one column and verify the migration runs cleanly on a database with 100+ existing trips

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| OEM battery kill during tracking | LOW | Detect tracking interruption (gap in GPS timestamps), warn user, allow them to manually set the end time/location |
| Corrupted database after failed migration | HIGH | Restore from DynamoDB backup (the restore endpoint). Requires user to have synced at least once. Without sync, data is lost. |
| Inaccurate traffic stats from GPS noise | MEDIUM | Retroactively reprocess trips with improved algorithm. Store raw GPS data (or enough detail) to allow recomputation. |
| Sync queue permanently stuck in "failed" | LOW | Add a "Retry all failed" button in settings. Allow manual intervention. Show which trips failed and why. |
| Token refresh deadlock | LOW | Detect auth failure state, force sign-out, prompt re-authentication. Clear stored tokens and start fresh. |
| Polyline bloat slowing queries | HIGH | Requires schema migration to move polylines to a separate table. Must be done carefully with migration tests. Much cheaper to prevent than fix. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| OEM battery kill | Phase 1: Tracking | Test on 3+ OEM devices with screen off for 30 minutes during active tracking |
| GPS speed inaccuracy | Phase 1: Trip Processing | Record a test commute, compare "stuck time" to perceived reality. Test with stationary phone for 10 min -- stuck time should be near zero |
| Database migration breakage | Phase 1: Database Setup | Write migration test scaffolding from v1. Run migration test in CI. |
| Sync queue unbounded growth | Phase 2: Sync Engine | Test with 50+ pending items. Verify chunked processing and progress indication. |
| Notification UX | Phase 1: Tracking | User test: start tracking, lock phone for 20 min, unlock. Is notification informative? Does it disappear after stop? |
| Cognito token race condition | Phase 1: Auth | Simulate expired token with 3 concurrent sync requests. Verify single refresh. |
| Polyline storage bloat | Phase 1: Database Schema | Schema review: polylines in separate table. Query audit: no SELECT * on trips. |
| Android 12+ permission flow | Phase 1: Onboarding | Test permission grant/deny/approximate on Android 12, 13, 14 devices. Test "Don't ask again" flow. |

## Sources

- Training data knowledge of Android background processing restrictions (Doze mode, App Standby, OEM-specific battery optimization) -- MEDIUM confidence
- Training data knowledge of GPS accuracy characteristics and speed measurement limitations -- HIGH confidence (well-established physics/engineering)
- Training data knowledge of Drift/SQLite migration patterns -- MEDIUM confidence
- Training data knowledge of AWS Cognito JWT lifecycle and token refresh -- MEDIUM confidence
- Training data knowledge of Android location permission model evolution (API 29-34) -- MEDIUM confidence
- dontkillmyapp.com referenced for OEM battery kill documentation -- HIGH confidence (well-known resource, stable over years)
- No live web verification was possible for this research session

---
*Pitfalls research for: Commute Tracker (Flutter/Android GPS tracking with offline-first sync)*
*Researched: 2026-04-11*
