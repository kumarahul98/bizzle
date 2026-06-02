# Roadmap: Commute Tracker v0.1

## Overview

Deliver an offline-first Android commute tracker that records GPS trips, computes traffic breakdowns, surfaces commute insights through stats and a dashboard, then adds cloud backup via auth and sync as the final layer. The build order is local-first: database foundation, then GPS tracking, trip management, history, stats, dashboard, and polish -- all working without any authentication. Auth, backend, and sync are added last so the core experience is fully usable before any cloud dependency.

## Milestones

- ✅ **v0.1 Android MVP** - Phases 1-11 (formally open — 13 device-UAT items deferred, resumable)
- 🚧 **v0.2 iOS Support** - Phases 12-16 (in progress)

## Phases

<details>
<summary>✅ v0.1 Android MVP (Phases 1-11) — formally open, 13 device-UAT items deferred</summary>

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Drift database schema, project scaffold, and config constants
- [x] **Phase 2: Core Tracking** - GPS recording with background service and trip processing
- [x] **Phase 3: Trip Management** - Edit, delete, manual entry, and direction labeling
- [x] **Phase 4: Trip History** - Daily log, calendar view, and route map detail
- [x] **Phase 5: Stats & Analytics** - Commute stats, traffic totals, trends, and charts
- [x] **Phase 6: Dashboard** - Home screen with today's trips and weekly summary ✓ 2026-04-28
- [x] **Phase 7: Polish & Notifications** - Dark mode, tracking reminders, and summary notifications ✓ 2026-04-28
- [x] **Phase 8: UI Overhaul** - Full visual redesign to Traevy design system (Inter + JetBrains Mono, oklch colour tokens, calm & spacious layout) (completed 2026-05-15)
- [x] **Phase 9: Authentication** - Google Sign-In via Firebase Auth and onboarding flow (completed 2026-05-29)
- [x] **Phase 10: Backend Infrastructure** - Firebase Cloud Functions (HTTPS) and Firestore (completed 2026-05-31)
- [x] **Phase 11: Sync Engine** - One-way sync queue and cloud restore flow (completed 2026-06-01)

### Phase 1: Foundation
**Goal**: A runnable Flutter project with complete Drift database schema and app-wide configuration ready for all features to build on
**Depends on**: Nothing (first phase)
**Requirements**: SYNC-01
**Success Criteria** (what must be TRUE):
  1. Flutter project builds and runs on an Android device showing a placeholder screen
  2. Drift database initializes with trips, sync_queue, and user_preferences tables
  3. A trip can be inserted into and queried from the Drift database via DAO
  4. All config constants (speed threshold, cutoff hours, retry limits) are defined in constants.dart
  5. Riverpod is wired up and a basic provider resolves correctly
**Plans**: 4 plans

Plans:
- [x] 01-01-PLAN.md — Flutter project scaffold, core dependencies, Android Gradle config
- [x] 01-02-PLAN.md — Config constants, theme, routes, main.dart ProviderScope wiring, analysis_options
- [x] 01-03-PLAN.md — Drift database: 3 tables, 3 DAOs, AppDatabase, Riverpod providers, build_runner codegen
- [x] 01-04-PLAN.md — DAO/index/preferences/migration tests, schema v1 snapshot, widget smoke test

### Phase 2: Core Tracking
**Goal**: Users can record a commute trip from start to stop with background GPS capture, producing a complete trip record with traffic breakdown
**Depends on**: Phase 1
**Requirements**: TRACK-01, TRACK-02, TRACK-04, TRACK-05, UX-03
**Success Criteria** (what must be TRUE):
  1. User can tap a button to start recording and tap again to stop
  2. GPS continues capturing location when screen is off via foreground service
  3. A persistent notification is visible while tracking is active
  4. Completed trip is saved to Drift with start/end time, duration, distance, route polyline, and time-moving vs time-stuck breakdown
  5. Location permission is requested when user first starts tracking (no auth required)
**Plans**: TBD
**UI hint**: yes

Plans:
- [x] 02-01: TBD
- [x] 02-02: TBD
- [x] 02-03: TBD

### Phase 3: Trip Management
**Goal**: Users can manage their trips -- edit details, delete trips, enter forgotten trips manually, and have direction auto-labeled
**Depends on**: Phase 2
**Requirements**: TRACK-03, TRACK-06, TRACK-07, TRACK-08
**Success Criteria** (what must be TRUE):
  1. Trips are auto-labeled as "to_office" or "to_home" based on start time and configurable cutoff
  2. User can edit a trip's direction label and adjust start/end times
  3. User can delete a trip after confirming via dialog
  4. User can manually enter a forgotten trip with date, duration, and direction (no GPS data)
**Plans**: 5 plans
**UI hint**: yes

Plans:
- [x] 03-01-PLAN.md — DAO extensions (updateTrip, deleteTrip), DirectionLabelService, Wave 0 test stubs
- [x] 03-02-PLAN.md — TripManagementNotifier (edit + delete), wire DirectionLabelService into tracking controller
- [x] 03-03-PLAN.md — insertManualTrip, parseHhMm, DirectionBackfillProvider, app startup wiring
- [x] 03-04-PLAN.md — EditTripSheet widget, delete confirmation on home screen
- [x] 03-05-PLAN.md — ManualEntrySheet widget, [+] FAB on home screen

### Phase 4: Trip History
**Goal**: Users can browse and review all past commutes through list, calendar, and map views
**Depends on**: Phase 3
**Requirements**: HIST-01, HIST-02, HIST-03
**Success Criteria** (what must be TRUE):
  1. User can scroll through past commutes organized by day in a list view
  2. User can switch to a calendar view and tap a date to see that day's trips
  3. User can tap any trip to see its route drawn on a map with full details (duration, distance, traffic breakdown)
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [x] 04-01-PLAN.md — Wave 0 test stubs (history_grouping_test, formatters_test, history_screen_test, trip_detail_screen_test)
- [x] 04-02-PLAN.md — Packages + constants + routes + formatters.dart + history_providers.dart + trip_actions.dart + home screen "View history" button
- [x] 04-03-PLAN.md — HistoryScreen (list + calendar toggle), TripCard widget, HIST-01/HIST-02 tests
- [x] 04-04-PLAN.md — TripDetailScreen (map + stats), HIST-03 and formatters tests

### Phase 5: Stats & Analytics
**Goal**: Users can see the reality of their commute through weekly/monthly totals, direction-split averages, best/worst days, trends, and traffic waste
**Depends on**: Phase 4
**Requirements**: STAT-01, STAT-02, STAT-03, STAT-04, STAT-05
**Success Criteria** (what must be TRUE):
  1. User can view total commute time for the current week and current month
  2. User can see average commute duration split by to-office vs to-home
  3. User can identify their best and worst commute day of the week
  4. User can view a 4-week trend line chart showing commute duration over time
  5. User can see a weekly total of time wasted stuck in traffic
**Plans**: 5 plans
**UI hint**: yes

Plans:
- [x] 05-01-PLAN.md — pubspec fl_chart 1.2.0, Phase 5 constants, kRouteStats constant, StatsSummary class + computeStatsSummary stub, RED unit tests for STAT-01..05 + D-10 + Pitfall 1/4
- [x] 05-02-PLAN.md — Implement computeStatsSummary single-pass body (GREEN), create derived statsSummaryProvider via whenData
- [x] 05-03-PLAN.md — StatsCard wrapper + WeekMonthTotalsCard + DirectionAveragesCard + TrafficWasteCard (4 simple cards)
- [x] 05-04-PLAN.md — BestWorstDayCard (chips with locale-derived labels + a11y) + TrendChartCard (fl_chart 1.x LineChart with 4 week labels)
- [x] 05-05-PLAN.md — StatsScreen + register kRouteStats in kAppRoutes + 'View stats' OutlinedButton on home + widget tests

### Phase 6: Dashboard
**Goal**: Users land on a home screen that immediately shows today's commutes and a weekly summary at a glance
**Depends on**: Phase 5
**Requirements**: UX-01
**Success Criteria** (what must be TRUE):
  1. Dashboard is the first screen when opening the app, showing today's recorded trips
  2. A weekly summary card displays total commute time and traffic time for the current week
  3. User can start a new trip directly from the dashboard (FAB or prominent button)
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [x] 06-01-PLAN.md — Wave 0 test scaffolding: dashboard_providers_test.dart (unit) + dashboard_screen_test.dart (widget, migrated from home_screen_test.dart)
- [x] 06-02-PLAN.md — Phase 6 constants block in constants.dart + todaysTripSummariesProvider in dashboard_providers.dart
- [x] 06-03-PLAN.md — WeeklySummaryCard + InProgressCard + TodayTripsSection widget files
- [x] 06-04-PLAN.md — DashboardScreen + app.dart wiring + HomeScreen deletion + app_test/app_bootstrap_test migration + full suite GREEN

### Phase 7: Polish & Notifications
**Goal**: App feels complete with dark mode support and proactive notifications for summaries and reminders
**Depends on**: Phase 6
**Requirements**: UX-02, UX-04, UX-05
**Success Criteria** (what must be TRUE):
  1. User can toggle between light mode, dark mode, and system default in settings
  2. User receives a weekly push notification summarizing their commute totals
  3. User can enable a tracking reminder notification at their usual departure time
  4. Theme preference persists across app restarts via user_preferences table
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [x] 07-01-PLAN.md — Phase 7 constants (kDarkModeLight, kDarkModeDark, all notification constants) + Drift schema v2 migration (weeklyNotificationEnabled) + AndroidManifest USE_EXACT_ALARM + timezone dep
- [x] 07-02-PLAN.md — Wave 0 test scaffold: settings_screen_test.dart (RadioListTile rows, gear icon navigation, reminder visibility)
- [x] 07-03-PLAN.md — UserPreferencesDao.watch() + userPreferenceProvider StreamProvider + NotificationService (zonedSchedule) + TraevyApp dynamic themeMode + main.dart bootstrap
- [x] 07-04-PLAN.md — SettingsScreen (Appearance + Notifications sections) + Dashboard gear icon + routes wiring + ManualEntrySheet bug fix (traffic/distance fields) + stats_service exclusion fix

### Phase 8: UI Overhaul
**Goal**: Every screen is redesigned to the Traevy design system — new colour tokens, Inter + JetBrains Mono typography, calm spacious layout, and pointed traffic-loss copy — while leaving all business logic untouched
**Depends on**: Phase 7
**Requirements**: UX-01, UX-02, UX-04, UX-05
**Success Criteria** (what must be TRUE):
  1. All screens use the Traevy oklch colour tokens (light and dark variants) with no hardcoded legacy colours remaining
  2. JetBrains Mono is used for all numeric/tabular data; Inter for all UI copy
  3. Home screen shows the hero circular START button, today's trips list, and "You lost Xh Xm to traffic this week" card
  4. Active recording screen shows elapsed timer, distance/speed/stuck stat cards, and mini map with a "Stop and save" button
  5. History screen has "Trips" title, List/Calendar pill toggle, and date-grouped TripRow cards
  6. Stats screen shows the hero traffic-loss number, donut chart, 28-day TrendBars, and WeekdayChart
  7. Settings screen uses grouped section rows (Account, Recording, Notifications, Appearance) with consistent toggle and chevron components
  8. All screens pass flutter analyze with zero warnings
**Plans**: 7 plans
**UI hint**: yes

Plans:
**Wave 1**
- [x] 08-01-PLAN.md — Pubspec + Inter/JetBrainsMono font assets + Phase 8 constants + flutter_test_config + Wave 0 RED tests

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 08-02-PLAN.md — TraevyTokens + TraevyTokensExt + TraevyFonts + buildLightTheme/buildDarkTheme + main.dart fetch-disable + app.dart wire

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 08-03-PLAN.md — Six shared Traevy widgets (StuckBar, TripRowCard, SectionLabel, TraevyToggle, StatMiniCard, TraevyLogoMark)

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 08-04-PLAN.md — MainShell + Riverpod tab index + app.dart home → MainShell + Dashboard restyle (HomeHeader, HeroRecordCard, TodaySection, WeekLossCard) + Pitfall 7 test updates
- [x] 08-05-PLAN.md — Tracking Variant A restyle + History screen (HistoryViewToggle, TripSectionCard) + trip_card.dart deletion + table_calendar token colours
- [x] 08-06-PLAN.md — Trip Detail restyle (TrafficInsightCard, TripTimeline) + Stats screen (TrafficLossHero, DonutCard, TrendBarsCard, WeekdayChartCard) + delete 5 legacy stats cards

**Wave 5** *(blocked on Wave 4 completion)*
- [x] 08-07-PLAN.md — Settings restyle (SettingsSection, SettingsRow, AccountRow, TraevyToggle wiring) + Onboarding scaffold + kRouteOnboarding registration

### Phase 9: Authentication
**Goal**: Users can sign in with Google via Firebase Auth and have their identity linked to existing local trip data
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03, BACK-01
**Success Criteria** (what must be TRUE):
  1. User can sign in with their Google account and receive a Firebase ID token
  2. User's session survives app restart without re-authentication
  3. User completes onboarding flow (Google sign-in confirmation) and existing trips are tagged with the Firebase uid
  4. Auth tokens are stored in flutter_secure_storage, never in plain text
**Plans**: 5 plans
**UI hint**: yes

Plans:
**Wave 1**
- [x] 09-01-PLAN.md — FlutterFire deps + Phase 9 constants/route + Wave 0 RED tests + google_sign_in 7.x API probe

**Wave 2** *(blocked on Wave 1)*
- [x] 09-02-PLAN.md — Sealed AuthState model + backfillUserId on both DAOs

**Wave 3** *(blocked on Wave 2)*
- [x] 09-03-PLAN.md — Auth provider graph (AuthStateNotifier) + AuthService (sign-in/token-cache/backfill) + main.dart Firebase init

**Wave 4** *(blocked on Wave 3)*
- [x] 09-04-PLAN.md — app.dart auth gate + static splash + one-time confirmation screen
- [x] 09-05-PLAN.md — Sign-in bottom sheet + onboarding wiring + state-aware Settings Account section + widget tests

### Phase 10: Backend Infrastructure
**Goal**: Firebase backend is deployed with three working HTTPS Cloud Function endpoints protected by Firebase Auth token verification, writing to Firestore
**Depends on**: Phase 9
**Requirements**: BACK-02, BACK-03, BACK-04
**Success Criteria** (what must be TRUE):
  1. POST /trips/sync Cloud Function accepts a batch of trips and writes them to Firestore
  2. DELETE /trips/{tripId} Cloud Function soft-deletes a trip in Firestore
  3. GET /trips/restore Cloud Function returns all non-deleted trips for the authenticated user
  4. All endpoints reject requests without a valid Firebase ID token
  5. Firestore Security Rules deny all direct client access — only the Admin SDK (Cloud Functions) can read/write trip data
**Plans**: 3 plans

Plans:
- [x] 10-01-PLAN.md — Backend scaffold & shared infrastructure (firebase.json, deny-all rules, Trip/TripDoc contract, auth/firestore/validation/response utils, GET /health)
- [x] 10-02-PLAN.md — Three HTTPS handlers (sync/delete/restore) + Express routing
- [x] 10-03-PLAN.md — Emulator-backed integration test suite (proves all 5 success criteria)

### Phase 11: Sync Engine
**Goal**: Trips automatically sync from Drift to Firestore (via Cloud Functions) in the background, and users can restore from cloud backup
**Depends on**: Phase 10
**Requirements**: SYNC-02, SYNC-03
**Success Criteria** (what must be TRUE):
  1. After saving a trip, a sync queue entry is created and processed in the background when online
  2. Sync retries up to 3 times with exponential backoff on failure
  3. User can trigger cloud restore from settings, which downloads all trips and inserts them into Drift (skipping duplicates)
  4. Sync never blocks the UI -- all network operations are background-only
**Plans**: 3 plans

Plans:
- [x] 11-01-PLAN.md — Sync foundation: transport (ApiClient), serializer, SyncStatus model, DAO markFailed/resetFailed
- [x] 11-02-PLAN.md — Sync engine: queue processor (batch + backoff + in-flight guard), D-07 triggers, eager mount, unit tests
- [x] 11-03-PLAN.md — Restore-from-cloud (RestoreController + insertOrIgnore dedupe-by-UUID) + Settings signed-in cloud-sync-status & Restore rows (SYNC-03)

**Status**: COMPLETE (verified PASS, 4/4 criteria) — flutter analyze clean (no new issues over 96 baseline); full suite 377 passed / 0 failed / 0 new skips; Gemini cross-AI plan review converged 0 HIGH (2 iters); code review 0 Critical / 1 High (fixed). REST-only client (no cloud_firestore); targets the deployed backend at https://us-central1-travey-298a7.cloudfunctions.net/api. Live signed-in-device E2E is the only wake-up item. See 11-SUMMARY/11-VERIFICATION.

</details>

---

## v0.2 iOS Support

**Milestone Goal:** Make the full Commute Tracker app run on iOS with feature parity to Android, runnable on a real iPhone via Xcode free (7-day) provisioning. No TestFlight or App Store this milestone.

### Milestone Preconditions (Human-Only Gates)

These must be addressed by the user before or during Phase 12 — they cannot be automated:

1. **Xcode license acceptance** — run `sudo xcodebuild -license accept` on the Mac. This also unblocks git on this machine.
2. **Apple ID signing in Xcode** — use free provisioning (no paid developer account needed). Note: free provisioning certificates expire every 7 days and must be re-signed for continued device runs.
3. **Enable Developer Mode on the test iPhone** — iOS 16+ requires `Settings > Privacy & Security > Developer Mode` to be turned on (and the device restarted) before any locally-signed app will launch. Blocks all real-device testing if missed.
4. **Real-device testing** — Phases 13, 14, 15, and 16 all require a physical iPhone. iOS Simulator cannot reliably test background GPS continuation, speed-based traffic accuracy, or the Google OAuth redirect flow.

---

### v0.2 Phase Checklist

- [ ] **Phase 12: iOS Scaffolding & Configuration** - Generate ios/ project, configure Podfile, Info.plist, entitlements, and bundle ID; app launches on Simulator and real iPhone
- [ ] **Phase 13: Auth on iOS** - Google Sign-In working on a real device; session persists via Keychain (device-install required)
- [ ] **Phase 14: Background GPS Platform Branch** - Platform-branched CoreLocation tracking; GPS continues during backgrounded commute; traffic stats accurate on real iPhone (HIGHEST RISK — real-device validation required; flag for deeper research at plan time)
- [ ] **Phase 15: Notifications, Permissions & Onboarding UX on iOS** - iOS location two-step flow, notification permission, tracking-notification gate, onboarding copy (real-device required for permission flows)
- [ ] **Phase 16: End-to-End Real-Device Parity Validation** - All features verified on a real iPhone; milestone acceptance gate (real-device required)

---

### Phase 12: iOS Scaffolding & Configuration
**Goal**: The app builds and runs on iOS — Simulator and real iPhone — with all platform prerequisites correctly configured so every subsequent phase starts from a clean foundation
**Depends on**: Phase 11
**Requirements**: IOS-01, IOS-02, IOS-03
**Success Criteria** (what must be TRUE):
  1. `flutter build ios --simulator` completes without error and the app launches on the iOS Simulator
  2. The app installs and launches on a real iPhone via Xcode free provisioning (human-gated: requires Xcode license acceptance and Apple ID signing)
  3. `Info.plist` contains all required keys: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes: location`, notification usage description, and the reversed-client-ID `CFBundleURLTypes` entry
  4. Keychain Sharing entitlement is present in `Runner.entitlements` (absence causes silent `-34018` token failure on real devices)
  5. `GoogleService-Info.plist` is added to the Xcode project as a resource and `Podfile` targets iOS 14.0 with the required `post_install` hook; `pod install` completes successfully in `ios/` (run explicitly or via `flutter build ios`)
  6. `Info.plist` contains an `NSAppTransportSecurity` configuration that permits the HTTPS calls the app makes (Google OAuth endpoints + the Cloud Functions sync backend) so network requests are not blocked by ATS
  7. iOS app icons (all required sizes) and a launch screen storyboard are present so the installed app shows a proper icon and launch screen, not placeholder assets
**Plans**: TBD
**UI hint**: yes

### Phase 13: Auth on iOS
**Goal**: Users can sign in with Google on iOS and stay signed in across app restarts, with tokens stored securely in the iOS Keychain
**Depends on**: Phase 12
**Requirements**: IOS-04, IOS-05
**Success Criteria** (what must be TRUE):
  1. User can tap "Sign in with Google" on an iPhone, complete the OAuth flow in Safari, and return to the app authenticated (reversed-client-ID URL scheme routes the redirect correctly)
  2. User remains signed in after force-quitting and relaunching the app on a real iPhone — no re-authentication prompt (human-gated: requires real-device install)
  3. No `-34018` Keychain error appears in device logs — Keychain Sharing entitlement is confirmed working on a physical device
  4. `google_sign_in` is initialized with `clientId: DefaultFirebaseOptions.currentPlatform.iosClientId` in Dart
**Plans**: TBD

### Phase 14: Background GPS Platform Branch
**Goal**: Users can record a full commute on iOS with GPS continuing uninterrupted while the app is backgrounded or the screen is off, and moving/stuck traffic stats remain accurate
**Depends on**: Phase 13
**Requirements**: IOS-06, IOS-07, IOS-08
**Success Criteria** (what must be TRUE):
  1. User starts a trip on iPhone, locks the screen for the duration of a commute, stops the trip — GPS track is complete with no gaps (human-gated: requires real-device commute validation)
  2. Moving/stuck time breakdown for a stop-and-go commute is accurate — GPS does not pause silently during slow traffic (`pauseLocationUpdatesAutomatically: false` confirmed working on device)
  3. When iOS location accuracy is set to "Approximate" in Settings, the app detects reduced accuracy (`getLocationAccuracy()`) and surfaces a warning or blocks recording rather than silently computing garbage speed stats
  4. `tracking_service.dart` contains a `defaultTargetPlatform` branch that selects `AppleSettings(allowBackgroundLocationUpdates: true, pauseLocationUpdatesAutomatically: false, activityType: ActivityType.automotiveNavigation)` on iOS
**Plans**: TBD

**Research flag**: Deeper planning required before execution. Open decision: keep `flutter_background_service.onForeground` driving the geolocator stream on iOS, or bypass `flutter_background_service` entirely and run the geolocator stream on the main isolate. Both are viable; bypass is the fallback. Resolve during plan-phase.

**Sequencing note** (Gemini peer review challenged placing this highest-risk phase after Auth): Auth is kept first because the app gates the tracking UI behind sign-in (onboarding = sign-in → location permission → tracking), so reaching the tracking screen on a real device to validate background GPS requires working auth. Phase 12 already de-risks the toolchain (IOS-02: installs + launches on a real iPhone), so toolchain risk is retired before this phase regardless. If Phase 13 reveals auth is slow to stabilize, a throwaway GPS spike behind a temporary dev bypass can be pulled forward — but the default order is 12 → 13 → 14.

### Phase 15: Notifications, Permissions & Onboarding UX on iOS
**Goal**: The iOS-specific permission flows are correct, notifications work, and the tracking notification is properly suppressed on iOS so there is no phantom foreground-service badge
**Depends on**: Phase 14
**Requirements**: IOS-09, IOS-10, IOS-11
**Success Criteria** (what must be TRUE):
  1. During onboarding on iPhone, the user is prompted for "When In Use" location permission first; the app then requests "Always" at the appropriate moment and continues to function (in a degraded state) if the user grants only "When In Use" (human-gated: real-device permission flow)
  2. User receives a notification permission prompt on iOS and, after granting, the weekly summary notification and departure-reminder notification fire as scheduled
  3. The persistent tracking notification that appears on Android does NOT appear on iOS — the system blue location indicator is the only tracking signal shown to the user
  4. `startTrackingNotification()` (or equivalent) is gated behind `Platform.isAndroid` so no phantom notification is posted on iOS
**Plans**: TBD
**UI hint**: yes

### Phase 16: End-to-End Real-Device Parity Validation
**Goal**: Every feature that works on Android is confirmed working on a real iPhone — this is the milestone acceptance gate
**Depends on**: Phase 15
**Requirements**: IOS-12
**Success Criteria** (what must be TRUE):
  1. User records a complete commute on iPhone (start, background, stop), and the trip appears in the daily log with correct duration, distance, and moving/stuck breakdown (human-gated: real-device commute)
  2. Trip CRUD (create, edit direction/time, delete with confirmation) and manual entry all work on iOS
  3. Daily log list view, calendar view, and route map (flutter_map/OpenStreetMap) render on iPhone with no RenderFlex overflow errors in the logs and no visual regressions versus the Android layout (cards, calendar markers, and polyline all display)
  4. All stats screens (weekly total, direction averages, best/worst day, 4-week trend, traffic waste) show correct data derived from iOS-recorded trips
  5. Sync (Drift → Cloud Functions) and cloud restore both complete successfully on iOS — same REST path as Android, confirmed with a live trip round-trip
**Plans**: TBD

---

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> 15 -> 16

Note: Phases 1-7 deliver the complete local-first experience without any authentication or cloud dependency. Phase 8 redesigns the UI to the Traevy design system. Phases 9-11 layer on auth, backend, and sync after the core app is fully functional and polished. Phases 12-16 port the app to iOS with full feature parity.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v0.1 | 0/4 | Not started | - |
| 2. Core Tracking | v0.1 | 0/3 | Not started | - |
| 3. Trip Management | v0.1 | 0/5 | Not started | - |
| 4. Trip History | v0.1 | 0/4 | Not started | - |
| 5. Stats & Analytics | v0.1 | 0/5 | Not started | - |
| 6. Dashboard | v0.1 | 0/4 | Not started | - |
| 7. Polish & Notifications | v0.1 | 0/4 | Not started | - |
| 8. UI Overhaul | v0.1 | 0/4 | Not started | - |
| 9. Authentication | v0.1 | 5/5 | Complete | 2026-05-29 |
| 10. Backend Infrastructure | v0.1 | 3/3 | Complete | 2026-05-31 |
| 11. Sync Engine | v0.1 | 3/3 | Complete | 2026-06-01 |
| 12. iOS Scaffolding & Configuration | v0.2 | 0/TBD | Not started | - |
| 13. Auth on iOS | v0.2 | 0/TBD | Not started | - |
| 14. Background GPS Platform Branch | v0.2 | 0/TBD | Not started | - |
| 15. Notifications, Permissions & Onboarding UX on iOS | v0.2 | 0/TBD | Not started | - |
| 16. End-to-End Real-Device Parity Validation | v0.2 | 0/TBD | Not started | - |
