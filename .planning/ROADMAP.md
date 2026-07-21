# Roadmap: Commute Tracker v0.1

## Overview

Deliver an offline-first Android commute tracker that records GPS trips, computes traffic breakdowns, surfaces commute insights through stats and a dashboard, then adds cloud backup via auth and sync as the final layer. The build order is local-first: database foundation, then GPS tracking, trip management, history, stats, dashboard, and polish -- all working without any authentication. Auth, backend, and sync are added last so the core experience is fully usable before any cloud dependency.

## Milestones

- ✅ **v0.1 Android MVP** - Phases 1-11 (formally open — 13 device-UAT items deferred, resumable)
- ⏸️ **v0.2 iOS Support** - Phases 12-16 (PAUSED as of 2026-07-11 — see summary in the v0.2 section; 12/13 complete, 14 code-complete/device-unverified, 15 trimmed & merged (Live Activity dropped), 16 not started)
- 🚧 **v0.3 App Improvements** - Phases 17-26 (9/11 complete; remaining Phases 23, 26 are Android-only)

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

> ## 🚧 PAUSED — iOS Development Summary (as of 2026-07-11)
>
> **Decision:** All active roadmap work (Phases 25.1, 23, 26, and anything added going forward) is Android-only until explicitly resumed. This section is the resume point — read it before picking iOS back up.
>
> **Done and device-confirmed:**
> - **Phase 12 — iOS Scaffolding & Configuration** ✅ App builds and runs on Simulator and a real iPhone; Podfile, Info.plist, entitlements, icons all in place. (IOS-01, IOS-02, IOS-03)
> - **Phase 13 — Auth on iOS** ✅ Google Sign-In confirmed working on a real device via Phases 9+12's existing code; closed without needing new execution. (IOS-04, IOS-05)
> - **Phase 15 (trimmed) — Notifications, Permissions & Onboarding UX** ✅ Location priming + two-step permission flow, contextual notification permission, phantom-notification suppression, enriched Android notification body — all merged to `main` in PR #3 (2026-07-06), device-verified on iPhone 13 / iOS 26.5. (IOS-09, IOS-10, IOS-11, IOS-14)
>
> **Done in code, NOT device-verified:**
> - **Phase 14 — Background GPS Platform Branch** ⚠️ CoreLocation platform branch, main-isolate tracking engine, and the reduced-accuracy gate are all implemented and unit-tested, but the 3 real-device drive scenarios were deferred pending Phase 15 and never run: locked-screen commute (no GPS gaps), stop-and-go traffic accuracy, and Approximate Location handling. Phase 15 has since shipped, so these are unblocked — they're the first thing to run when iOS resumes. (IOS-06, IOS-07, IOS-08 — marked complete in REQUIREMENTS.md at the code level, but not human-verified)
>
> **Abandoned, not on `main`:**
> - **Live Activity (IOS-13)** ❌ Never rendered on a real device despite two real fixes landing (Swift widget → plugin contract, App-Group probe). Investigation paused at "`LiveActivityService.init()` appears never to run." All code — the widget extension, the Dart bridge, the `[la-diag]` diagnostics — lives only on the git tag **`archive/live-activity-wip`**, not on `main`. Resume point: `.planning/debug/live-activity-not-rendering.md` on that tag, "PAUSE / RESUME HERE" section.
>
> **Not started:**
> - **Phase 16 — End-to-End Real-Device Parity Validation** — the milestone's acceptance gate (IOS-12). 0 plans. When iOS resumes, this is where Phase 14's 3 deferred device scenarios should be re-run alongside the rest of Phase 16's full-parity sweep, since both need the same real-iPhone session.
>
> **Net:** iOS scaffolding, auth, and permissions/notifications are solid and confirmed on-device. Background GPS is implemented but its 3 hardest scenarios (the whole reason Phase 14 was flagged highest-risk) were never actually driven on a real iPhone. Live Activity is the one dropped feature. Resuming v0.2 means: one real-device session for Phase 14's leftover scenarios + Phase 16's full sweep, then a decision on whether to revive Live Activity from the archive tag or drop IOS-13 from scope permanently.

### Milestone Preconditions (Human-Only Gates)

These must be addressed by the user before or during Phase 12 — they cannot be automated:

1. **Xcode license acceptance** — run `sudo xcodebuild -license accept` on the Mac. This also unblocks git on this machine.
2. **Apple ID signing in Xcode** — use free provisioning (no paid developer account needed). Note: free provisioning certificates expire every 7 days and must be re-signed for continued device runs.
3. **Enable Developer Mode on the test iPhone** — iOS 16+ requires `Settings > Privacy & Security > Developer Mode` to be turned on (and the device restarted) before any locally-signed app will launch. Blocks all real-device testing if missed.
4. **Real-device testing** — Phases 13, 14, 15, and 16 all require a physical iPhone. iOS Simulator cannot reliably test background GPS continuation, speed-based traffic accuracy, or the Google OAuth redirect flow.

---

### v0.2 Phase Checklist

- [x] **Phase 12: iOS Scaffolding & Configuration** - Generate ios/ project, configure Podfile, Info.plist, entitlements, and bundle ID; app launches on Simulator and real iPhone (completed 2026-06-02)
- [x] **Phase 13: Auth on iOS** - Google Sign-In working on a real device; session persists via Keychain (closed 2026-06-02 — requirements pre-satisfied by Phases 9+12, confirmed on-device by user; no execution needed)
- [x] **Phase 14: Background GPS Platform Branch (code complete, device-unverified)** - Platform-branched CoreLocation tracking implemented and unit-tested (completed 2026-06-02); 3 real-device drive scenarios still deferred — see PAUSED summary above
- [x] **Phase 15: Notifications, Permissions & Onboarding UX on iOS (trimmed)** - iOS location two-step flow, contextual notification permission, tracking-notification gate all merged to main (PR #3, 2026-07-06), device-verified; Live Activity (IOS-13) abandoned, archived at tag `archive/live-activity-wip`
- [ ] **Phase 16: End-to-End Real-Device Parity Validation** - All features verified on a real iPhone; milestone acceptance gate (real-device required) — NOT STARTED, paused

---

### Phase 12: iOS Scaffolding & Configuration

**Goal**: The app builds and runs on iOS — Simulator and real iPhone — with all platform prerequisites correctly configured so every subsequent phase starts from a clean foundation
**Depends on**: Phase 11
**Requirements**: IOS-01, IOS-02, IOS-03
**Success Criteria** (what must be TRUE):

  1. `flutter build ios --simulator` completes without error and the app launches on the iOS Simulator
  2. The app installs and launches on a real iPhone via Xcode free provisioning (human-gated: requires Xcode license acceptance and Apple ID signing)
  3. `Info.plist` contains all required keys: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes: location`, and the reversed-client-ID `CFBundleURLTypes` entry (note: iOS local-notification permission is requested at runtime via `DarwinInitializationSettings` — there is no notification usage-description plist key)
  4. Keychain Sharing entitlement is present in `Runner.entitlements` (absence causes silent `-34018` token failure on real devices)
  5. `GoogleService-Info.plist` is added to the Xcode project as a resource and `Podfile` targets iOS 15.0 (raised from 14.0 to satisfy the firebase_auth/firebase_core podspec floor) with the required `post_install` hook; `pod install` completes successfully in `ios/` (run explicitly or via `flutter build ios`)
  6. `Info.plist` contains an `NSAppTransportSecurity` configuration that permits the HTTPS calls the app makes (Google OAuth endpoints + the Cloud Functions sync backend) so network requests are not blocked by ATS
  7. iOS app icons (all required sizes) and a launch screen storyboard are present so the installed app shows a proper icon and launch screen, not placeholder assets

**Plans**: 3 plans
**UI hint**: yes

Plans:
**Wave 1**

- [x] 12-01-PLAN.md — Scaffold ios/ project (flutter create), Podfile iOS 15.0 + post_install, pod install, Simulator build + launch (IOS-01)

**Wave 2** *(blocked on Wave 1)*

- [x] 12-02-PLAN.md — Info.plist keys + both entitlements (keychain) + GoogleService-Info.plist target + app icons + notification_service Darwin init (IOS-03)

**Wave 3** *(blocked on Wave 2)*

- [x] 12-03-PLAN.md — Real-device signing + Developer Mode + install/launch on physical iPhone (IOS-02)

### Phase 13: Auth on iOS

**Goal**: Users can sign in with Google on iOS and stay signed in across app restarts, with tokens stored securely in the iOS Keychain
**Depends on**: Phase 12
**Requirements**: IOS-04, IOS-05
**Success Criteria** (what must be TRUE):

  1. User can tap "Sign in with Google" on an iPhone, complete the OAuth flow in Safari, and return to the app authenticated (reversed-client-ID URL scheme routes the redirect correctly)
  2. User remains signed in after force-quitting and relaunching the app on a real iPhone — no re-authentication prompt (human-gated: requires real-device install)
  3. No `-34018` Keychain error appears in device logs — Keychain Sharing entitlement is confirmed working on a physical device
  4. `google_sign_in` is initialized with `clientId: DefaultFirebaseOptions.currentPlatform.iosClientId` in Dart

**Plans**: None — closed 2026-06-02 without execution
**Status**: COMPLETE (no execution). Requirements IOS-04/IOS-05 were already satisfied by existing code/config: sign-in confirmed working on a real iPhone by the user; the iOS client ID is supplied to `google_sign_in` via `ios/Runner/GoogleService-Info.plist` (so SC#4's intent is met via the plist rather than the literal `clientId:` arg); Keychain Sharing entitlement shipped in Phase 12. See `13-CONTEXT.md` Resolution note.

### Phase 14: Background GPS Platform Branch

**Goal**: Users can record a full commute on iOS with GPS continuing uninterrupted while the app is backgrounded or the screen is off, and moving/stuck traffic stats remain accurate
**Depends on**: Phase 13
**Requirements**: IOS-06, IOS-07, IOS-08
**Success Criteria** (what must be TRUE):

  1. User starts a trip on iPhone, locks the screen for the duration of a commute, stops the trip — GPS track is complete with no gaps (human-gated: requires real-device commute validation)
  2. Moving/stuck time breakdown for a stop-and-go commute is accurate — GPS does not pause silently during slow traffic (`pauseLocationUpdatesAutomatically: false` confirmed working on device)
  3. When iOS location accuracy is set to "Approximate" in Settings, the app detects reduced accuracy (`getLocationAccuracy()`) and surfaces a warning or blocks recording rather than silently computing garbage speed stats
  4. `tracking_service.dart` contains a `defaultTargetPlatform` branch that selects `AppleSettings(allowBackgroundLocationUpdates: true, pauseLocationUpdatesAutomatically: false, activityType: ActivityType.automotiveNavigation)` on iOS

**Plans**: 3 plans
Plans:
**Wave 1**

- [x] 14-01-PLAN.md — Wave 0: buildLocationSettings() defaultTargetPlatform branch (SC#4) + iOS constants + validation test scaffolds
- [x] 14-02-PLAN.md — iOS main-isolate engine + TrackingEventSource seam + IOS-08 reduced-accuracy gate + Info.plist

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 14-03-PLAN.md — Wire notifier to the seam, platform-select the source, Android regression guard (full suite green)

**Research flag**: Deeper planning required before execution. Open decision: keep `flutter_background_service.onForeground` driving the geolocator stream on iOS, or bypass `flutter_background_service` entirely and run the geolocator stream on the main isolate. Both are viable; bypass is the fallback. Resolve during plan-phase.

**Sequencing note** (Gemini peer review challenged placing this highest-risk phase after Auth): Auth is kept first because the app gates the tracking UI behind sign-in (onboarding = sign-in → location permission → tracking), so reaching the tracking screen on a real device to validate background GPS requires working auth. Phase 12 already de-risks the toolchain (IOS-02: installs + launches on a real iPhone), so toolchain risk is retired before this phase regardless. If Phase 13 reveals auth is slow to stabilize, a throwaway GPS spike behind a temporary dev bypass can be pulled forward — but the default order is 12 → 13 → 14.

### Phase 15: Notifications, Permissions & Onboarding UX on iOS

**Goal**: The iOS-specific permission flows are correct, notifications work, the phantom Android tracking notification is suppressed on iOS, and the active commute is surfaced on iOS via a Live Activity (lock screen + Dynamic Island) with the Android ongoing notification enriched to match
**Depends on**: Phase 14
**Requirements**: IOS-09, IOS-10, IOS-11, IOS-13, IOS-14
**Success Criteria** (what must be TRUE):

  1. During onboarding on iPhone, the user is prompted for "When In Use" location permission first (preceded by one priming screen); the app then requests "Always" at the first trip Start and continues to function in a degraded best-effort-background state if the user grants only "When In Use" (human-gated: real-device permission flow)
  2. iOS notification permission is requested contextually (~1 week into usage, when the first weekly summary is due, or earlier if a departure reminder is enabled); after granting, the weekly summary and departure-reminder notifications fire as scheduled. Notification permission NEVER gates tracking Start on iOS
  3. The persistent Android foreground-service tracking notification does NOT appear on iOS. On **iOS 17+** the active-commute surface is a **Live Activity** (lock screen + Dynamic Island) showing live elapsed time, distance, and moving/stuck status with an **in-place Stop button**; on iOS < 17 the system blue location indicator is the only tracking signal and Stop stays in-app
  4. `startTrackingNotification()` (or equivalent) is gated behind `Platform.isAndroid` so no phantom notification is posted on iOS
  5. The Live Activity updates live from the `TripAccumulator` snapshot stream throughout a backgrounded commute and is dismissed when the trip stops (human-gated: real-device Live Activity behavior)
  6. The Android ongoing "Active commute" notification is enriched to show the same live stats (elapsed / distance / moving-stuck) for cross-platform parity, with no regression to the existing foreground-service binding

**Plans**: 5 plans

- [x] 15-01-PLAN.md — Wave 0: BLOCKING App-Group device-provisioning probe + test scaffolds
- [x] 15-02-PLAN.md — iOS permission branch + location priming screen + degraded banner + shared formatters (IOS-09)
- [x] 15-03-PLAN.md — Contextual iOS notification permission + Platform.isAndroid gate + Android stats enrichment (IOS-10/11/14)
- [~] 15-04-PLAN.md — Native TraevyLiveActivity Widget Extension (lock screen + Dynamic Island) + Info.plist (IOS-13) — ABANDONED, never rendered on device; code archived at tag `archive/live-activity-wip`, not on main
- [~] 15-05-PLAN.md — Dart Live Activity bridge + provider lifecycle wiring (IOS-13) — ABANDONED, same as above

**UI hint**: yes
**Note**: Scope expanded 2026-06-03 during discuss-phase — Live Activity (IOS-13) + Android notification parity (IOS-14) pulled in; original SC #3 ("blue indicator is the only signal") rewritten. iOS 17+ floor for the interactive Live Activity.

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
| 12. iOS Scaffolding & Configuration | v0.2 | 3/3 | Complete | 2026-06-02 |
| 13. Auth on iOS | v0.2 | 0/0 | Complete (closed, no execution needed) | 2026-06-02 |
| 14. Background GPS Platform Branch | v0.2 | 3/3 | Complete (code); 3 device-drive scenarios unverified | 2026-06-02 |
| 15. Notifications, Permissions & Onboarding UX on iOS | v0.2 | 3/5 | Trimmed & merged (PR #3, 2026-07-06); Live Activity (15-04/15-05) abandoned, archived at tag `archive/live-activity-wip` | 2026-07-06 |
| 16. End-to-End Real-Device Parity Validation | v0.2 | 0/TBD | Not started — milestone acceptance gate | - |

**Milestone status: PAUSED as of 2026-07-11.** See the iOS Development Summary below.

---

## v0.3 App Improvements

**Milestone Goal:** Ship a batch of Android-facing UX fixes and features that make daily trip capture more flexible and accurate — pausing for breaks, full trip editing, smarter geofence labeling, a friendlier first run, and one-tap start/stop from the home screen. Built on branch `gsd/v0.3-app-improvements`. Realizes **AUTO-02** (geofence labeling) and **PLAT-02** (start/stop widget), scoped down from their v2 definitions.

**Scope notes:** Android-focused. The home-screen widget (WIDGET-01) is an Android-first surface; iOS parity for these features is deferred. All phases build on the existing v0.1 Android app (Flutter + Drift source-of-truth + manual Riverpod providers + flutter_background_service foreground GPS + geolocator + flutter_local_notifications + Firebase auth/sync + Traevy design system). Previous milestone v0.2 (iOS Support, Phases 12–16) is **paused** and fully resumable — its phases above are untouched; see the PAUSED summary in the v0.2 section for exactly where it left off. **As of 2026-07-11, all remaining v0.3 phases (23, 25.1, 26, and anything added going forward) are Android-only** — Phases 25.1 and 26 are platform-agnostic Dart/backend code shared by both platforms, and Phase 23 was explicitly rescoped to drop its one iOS success criterion.

---

### v0.3 Phase Checklist

- [x] **Phase 17: Tracking UI Fixes & Quick Label** - Fix the elapsed-timer overflow and add a quick to-home/to-office label selector during and after tracking ✓ 2026-06-06
- [x] **Phase 18: Trip Pause & Breaks** - Pause/resume an active trip for breaks (paused time excluded from stats) with an optional auto-pause prompt ✓ 2026-06-06
- [x] **Phase 19: Full Trip Editing** - Edit start time, end time, and individual break segments with duration and traffic stats recomputed ✓ 2026-06-06
- [x] **Phase 20: First-Run Login with Skip** - First-install login screen with a Skip (use-without-account) option; sync stays disabled until later sign-in ✓ 2026-06-06
- [x] **Phase 21: Home & Office Locations + Geofence Auto-Label** - Set Home & Office locations and auto-label trip direction by proximity, taking precedence over the time-of-day heuristic (completed 2026-06-06)
- [x] **Phase 22: Home-Screen Widget** - Android home-screen widget that starts/stops a commute with one tap and reflects the current tracking state ✓ 2026-06-09
- [ ] **Phase 23: Resolve Deferred UAT Items (Android)** - Triage the v0.1 device checklist and complete the stalled Phase 21/22 UAT sessions on a real Android device
- [x] **Phase 24: Automatic Cloud Sync & Restore** - Auto-restore cloud trips on sign-in, immediate sync on trip finish, and automatic re-attempt of previously-failed sync items (merged to main in PR #2, 2026-07-06)
- [x] **Phase 25: Interrupted-Trip Recovery** - Detect a mid-trip force-quit / app-clear / OS interruption, log it, and offer to resume or discard the interrupted trip on next launch (merged to main in PR #2, 2026-07-06)
- [x] **Phase 25.1: Fix Sync Conflict & Auto-Retry Bugs (INSERTED)** - Fix the broken auto-retry throttle and the fake Merge conflict resolution found by Phase 24 verification, before Phase 26 extends the same files ✓ 2026-07-12
- [x] **Phase 26: Sync Breaks & Edit Metadata to Cloud** - Extend the Firestore trip payload with totalPausedSeconds, isEdited, directionSource, and an embedded breaks array; restore writes trip_breaks; one-time backfill re-sync; backend deploys before client (completed 2026-07-13)

---

### Phase 17: Tracking UI Fixes & Quick Label

**Goal**: The active-tracking screen renders correctly at any duration and lets the user set a trip's direction quickly, without any schema change
**Depends on**: Phase 8 (Traevy tracking UI), Phase 3 (direction labeling)
**Requirements**: UX-06, TRACK-12
**Success Criteria** (what must be TRUE):

  1. The active-tracking elapsed timer always renders fully on screen — no digit wraps to a new line and no clipping — at short durations and at durations exceeding an hour (and many hours)
  2. During an active trip, the user can tap a quick selector to set the trip's direction to "to-home" or "to-office", and the choice is reflected immediately on the tracking screen
  3. From the trip view (detail/edit), the user can change a trip's direction via the same quick selector and the change persists in Drift
  4. The quick label selector visually indicates the current direction (including the auto-labeled default) so the user can confirm or override it

**Plans**: 2 plans
**UI hint**: yes

Plans:

- [ ] 17-01-PLAN.md — Fix the active-tracking elapsed timer (ElapsedDisplay) so the HH:MM:SS mono timer never wraps/clips at 2-digit hours or large text-scale (UX-06)
- [ ] 17-02-PLAN.md — Quick to-office/to-home direction selector: active-screen segmented toggle with manual override (live + at finalize) and a 1-tap trip-detail toggle reusing the edit DAO path (TRACK-12)

### Phase 18: Trip Pause & Breaks

**Goal**: Users can pause an active commute for a break and resume it without ending the trip, with paused time excluded from duration and moving/stuck stats, plus an optional auto-pause prompt when the trip looks stationary
**Depends on**: Phase 17 (active-tracking UI), Phase 2 (core tracking service)
**Requirements**: TRACK-09, TRACK-10
**Success Criteria** (what must be TRUE):

  1. During an active trip, the user can tap Pause to suspend recording and tap Resume to continue the same trip — the trip is not ended and resumes as one continuous record
  2. Paused intervals are stored as break segments on the trip, and the saved trip's total duration and moving/stuck breakdown exclude all paused time
  3. The active-tracking UI clearly shows when a trip is paused (distinct paused state) and how many breaks have been taken
  4. With auto-pause enabled in settings, when an active trip appears stationary beyond the configured threshold the app posts a notification offering to pause the trip
  5. The auto-pause prompt is opt-in (off by default) and dismissing it leaves the trip recording normally

**Plans**: 4 plans

- [x] 18-01-PLAN.md — Schema v2→v3: trip_breaks table + total_paused_seconds + auto_pause_enabled + DAO + migration test
- [x] 18-02-PLAN.md — Accumulator pause model (excludes paused distance/time, frozen elapsed) + finalize breaks + persist
- [ ] 18-03-PLAN.md — Cross-isolate pause/resume commands + active-tracking PAUSED UI + break count
- [ ] 18-04-PLAN.md — Opt-in auto-pause: settings toggle + stuck-streak detector + Pause-action notification

**UI hint**: yes

### Phase 19: Full Trip Editing

**Goal**: Users can edit every time-based detail of a trip — start time, end time, and individual break segments — and the trip's duration and traffic stats are recomputed from the edits
**Depends on**: Phase 18 (break segments must exist), Phase 3 (existing trip edit screen)
**Requirements**: TRACK-11
**Success Criteria** (what must be TRUE):

  1. The user can edit a trip's start time and end time from the trip edit screen, and the saved trip reflects the new times
  2. The user can edit, add, or remove individual break/pause segments on a trip
  3. After any edit, the trip's total duration and moving/stuck traffic breakdown are recomputed and displayed consistently with the new times and breaks
  4. Invalid edits (e.g., end before start, breaks outside the trip window, overlapping breaks) are rejected with clear feedback and never persisted
  5. An edited trip re-enters the sync queue so the cloud backup reflects the corrected values

**Plans**: 2 plans (19-01 schema v4 + recompute/validation, 19-02 edit-sheet UI)
**UI hint**: yes

### Phase 20: First-Run Login with Skip

**Goal**: On first install the user sees a login screen they can skip to use the app locally without an account, and can sign in later from settings to enable sync
**Depends on**: Phase 9 (auth/onboarding), Phase 11 (sync engine)
**Requirements**: AUTH-04
**Success Criteria** (what must be TRUE):

  1. On first launch the user sees a login screen offering Google sign-in and a clearly visible "Skip" / use-without-account option
  2. Choosing Skip drops the user into the fully working app (tracking, history, stats) with no account, and this choice persists across app restarts (the login screen is not shown again on every launch)
  3. While in skipped/local-only mode, cloud sync is disabled — no sync attempts are made and the UI indicates the account is not connected
  4. The user can sign in later from settings, after which sync becomes enabled and existing local trips are tagged with the Firebase uid and queued for sync

**Plans**: TBD
**UI hint**: yes

### Phase 21: Home & Office Locations + Geofence Auto-Label

**Goal**: Users can save their Home and Office locations and have trip direction auto-labeled by proximity of trip start/end to those locations, taking precedence over the time-of-day heuristic when there is a confident match
**Depends on**: Phase 7 (settings/preferences), Phase 3 (direction labeling logic)
**Requirements**: LOC-01, LOC-02
**Success Criteria** (what must be TRUE):

  1. From settings, the user can set and later change their Home and Office locations via a map/coordinate picker, and the locations persist in preferences across restarts
  2. When a trip's start is near Home and its end is near Office (or vice versa), the trip is auto-labeled to-office / to-home based on that proximity
  3. Geofence-based labeling takes precedence over the time-of-day cutoff heuristic when a confident proximity match exists; with no confident match, the existing time-of-day heuristic is used as fallback
  4. The user can still manually override the auto-applied direction via the quick label selector, and the override sticks
  5. With no Home/Office set, labeling behaves exactly as it did before (time-of-day heuristic), so the feature is purely additive

**Plans**: TBD
**UI hint**: yes

### Phase 22: Home-Screen Widget

**Goal**: Users can add an Android home-screen widget that starts or stops a commute with one tap and always reflects the current tracking state
**Depends on**: Phase 2 (tracking service), Phase 18 (pause/resume state model, so widget state is accurate)
**Requirements**: WIDGET-01
**Success Criteria** (what must be TRUE):

  1. The user can add a Commute Tracker widget to the Android home screen from the widget picker
  2. Tapping the widget when idle starts a commute, and tapping it while tracking stops and saves the commute — the same trip pipeline as the in-app button
  3. The widget visually reflects the current tracking state (idle vs tracking) and updates when tracking starts or stops, including changes initiated from inside the app
  4. Starting tracking from the widget brings up the foreground GPS service and persistent notification exactly as the in-app Start does (no degraded background capture)

**Plans**: TBD
**UI hint**: yes

### Phase 23: Resolve Deferred UAT Items (Android)

> ## ⏭️ CLOSED EARLY — 2026-07-21
> **Not executed as a formal GSD phase.** No PLAN.md was ever written for the
> rescoped version; the work happened as an ad-hoc device session instead.
>
> **48 of 60 scenarios PASSED** and are recorded in
> `TRAEVY-DEVICE-CHECKS.xlsx` + back-ported into `v0.1-DEVICE-CHECKLIST.md`.
> That includes the entire v0.1 backlog (40/45) and the WR-05 force-stop repro
> — the single check that could prove the PendingTripStore fix works.
>
> **Remainder SKIPPED by priority decision, not by failure:**
> * 3 open — N05 (GPS drift), N08 + N15 (widget, one session closes both)
> * 8 deferred — N09-N11, N13, V42-V45, all needing the live backend
> * 1 N-A — V15
>
> Deliberately recorded as "closed early with results" rather than a bare
> "skipped": this phase was itself rescoped on 2026-07-11 after an audit found
> STATE.md claiming it complete when it never ran. Writing "skipped" over 48
> real passes would recreate that same phantom-status bug in the opposite
> direction. Nothing here is blocked or broken — it is deprioritised.


**Goal**: Close out the backlog of deferred human/device verification on Android — triaging what's stale, running what's still relevant, and completing the UAT sessions that were started and abandoned mid-run — so no Android phase is left with a phantom "pending" verification status
**Depends on**: Phase 22
**Requirements**: UAT-01
**Success Criteria** (what must be TRUE):

  1. The v0.1 device checklist (`.planning/v0.1-DEVICE-CHECKLIST.md`, 48 items across 9 groups, all Android) is triaged: items still relevant are run on a real Android device and checked off; items superseded by later phases (e.g. Group E dashboard, already flagged stale against Phase 8's UI overhaul) are marked superseded with a one-line reason instead of silently left pending
  2. Phase 21's UAT session (`21-UAT.md`, stalled at test 1 of 5, "awaiting user response" since 2026-06-08) is completed — all 5 geofence auto-label scenarios are run and recorded
  3. Phase 22's UAT session (`22-UAT.md`, stalled at test 1 of 3, "awaiting user response" since 2026-06-09) is completed — all 3 home-screen-widget scenarios are run and recorded
  4. No Android phase has a dangling `testing` / `partial` / `pending` UAT or verification status when this phase closes — each is resolved to pass, marked superseded, or explicitly logged as a known gap with a follow-up phase or todo
  5. The device-only items accumulated since this phase was written (added 2026-07-20) are run and recorded — see the table below. Each is invisible to `flutter analyze` and the full test suite by nature, so none of them can be closed from CI

**Device-only queue (added 2026-07-20).** Every item here was code-verified but is *behaviourally* unverifiable without hardware:

| Source | Test | Why CI cannot cover it |
|---|---|---|
| targetSdk 35 (`a5fffce`) | Edge-to-edge rendering: bottom nav in `main_shell`, the `flutter_map` screens (trip detail route, location picker), and bottom sheets | Android 15 forces edge-to-edge; it is a runtime rendering behaviour, not a code path a widget test can drive |
| WR-05 (`ef4d03e`) | `adb shell am force-stop traevy.traevy` while tracking → tap Stop from the notification → relaunch → the trip must appear in history instead of a fresh idle state | A force-stop race across an isolate boundary; the 2026-04-15 repro in BACKLOG 999.2 is the acceptance test |
| Phase 27 | Stand still ~15 min → distance stays ~0 (TRACK-14); Settings shows Auto-pause ON and existing installs backfilled (UX-08); each tab tours exactly once with Skip (UX-07) | GPS jitter, migration-on-real-install, and first-run overlay placement |
| Phase 28 | Resize widget wide → rich stats appear; shrink to 2×2 → compact layout returns; idle numbers match the in-app Stats screen | `RemoteViews(Map<SizeF, …>)` selection happens in the launcher process |
| Phase 25.1 | Conflict "Merge" sheet — confirm "Local" is pre-selected | Visual state of a sheet, tracked in `25.1-HUMAN-UAT.md` |
| Phase 29 (`bf96bbb`) | **Backend is live as of 2026-07-20, so this is now runnable:** sign in on a fresh install → Home/Office pins restore → the first trip labels by geofence, not time. Then set a pin while signed out, sign in, and confirm it reaches Firestore | Needs a live backend, a real Google account, and a reinstall — no emulator or test double covers the end-to-end path |

**Scope note**: Phase 14's 3 deferred iOS device-UAT items are explicitly OUT of scope here — iOS work is paused (see the PAUSED summary in the v0.2 section above). They resume together with Phase 16's full parity sweep when iOS picks back up.

**Plans**: TBD
**UI hint**: no

### Phase 24: Automatic Cloud Sync & Restore

**Goal**: Cloud sync and restore become hands-off — signing in restores cloud trips automatically, finished trips sync immediately, and sync items that previously failed are retried automatically instead of getting stuck
**Depends on**: Phase 11 (sync engine, ApiClient, RestoreController, sync_queue), Phase 20 (sign-in-later flow that triggers restore)
**Requirements**: SYNC-04, SYNC-05
**Success Criteria** (what must be TRUE):

  1. When the user signs in (fresh install, new device, or sign-in-later from settings), their cloud trips are restored into Drift automatically without any manual "Restore" tap, deduplicating by trip UUID so existing local trips are never duplicated
  2. A finished trip is enqueued and synced to the cloud immediately on save when online (no waiting for the next app resume / connectivity event)
  3. Sync items that previously exhausted their retries (status failed) are automatically re-attempted on a later trigger, and recover to synced once the backend is reachable
  4. All of the above remain background-only and never block the UI; the manual Restore action still works as a fallback
  5. Auto-restore runs once per sign-in (not on every launch) and surfaces clear progress/outcome to the user

**Plans**: TBD
**UI hint**: yes

### Phase 25: Interrupted-Trip Recovery

**Goal**: A commute that is interrupted by a force-quit, app-clear, or OS-level kill is never silently lost — its state is persisted continuously, and on next launch the user is told about the interrupted trip and can resume or discard it
**Depends on**: Phase 2 (core tracking service), Phase 18 (pause/resume + break-segment state model that must be persisted/restored accurately)
**Requirements**: TRACK-13
**Success Criteria** (what must be TRUE):

  1. While a trip is active, its state (accumulated route, timing, breaks, direction) is persisted durably so it survives a force-quit, app-swipe-away, app-data-not-cleared kill, or OS-level termination of the process
  2. On next launch, if an active trip was interrupted (no clean stop was recorded), the app detects this and logs the interruption
  3. The user is presented with a clear prompt offering to resume the interrupted trip (continuing the same record) or discard it
  4. Resuming restores the trip's accumulated state and continues recording as one continuous trip; discarding cleans up the persisted state with no orphan trip
  5. A normal clean stop leaves no interrupted-trip state behind, so the recovery prompt never appears after an ordinary finish

**Plans**: 3 plans
**UI hint**: yes

Plans:

- [ ] 25-01-PLAN.md — Persistence Foundation
- [ ] 25-02-PLAN.md — Engine Recovery
- [ ] 25-03-PLAN.md — UI & Notifier Wiring

### Phase 25.1: Fix Sync Conflict & Auto-Retry Bugs (INSERTED)

**Goal**: The two correctness defects found by Phase 24's verification — a broken auto-retry throttle and a fake Merge conflict resolution — are fixed before Phase 26 extends the same files with breaks/edit-metadata sync
**Depends on**: Phase 24 (sync engine, conflict resolution sheet)
**Requirements**: TBD
**Success Criteria** (what must be TRUE):

  1. `SyncEngine._lastAutoRetry` is assigned when a retry occurs, so `kFailedAutoRetryWindow` actually throttles auto-retry triggers (connectivity restore, app resume) instead of firing on every trigger
  2. Selecting "Merge" in the conflict resolution sheet no longer silently runs the same code path as "Use Cloud" — it either performs a real field-by-field merge, or (if field-by-field is descoped) the option is removed/relabeled so the UI doesn't promise something it doesn't do
  3. A regression test exists for the auto-retry time gate (asserting a second trigger within the window does not re-fire) and for the Merge path (asserting merged output differs from pure Use Cloud when local/cloud fields differ)

**Plans**: 2 plans
**UI hint**: yes

Plans:

- [x] 25.1-01-PLAN.md — D-07 auto-retry gate regression tests (3 new assertions) + D-04 predicate consolidation/rename (autoRetryWindowElapsed) across sync_engine.dart and the dashboard banner (2026-07-11)
- [x] 25.1-02-PLAN.md — D-05 merge default flip to 'local' at both leak points (display + _applyAll fallbacks) + D-08 strengthened two-differing-field merge widget test (2026-07-11)

### Phase 26: Sync Breaks & Edit Metadata to Cloud

**Goal**: The cloud copy of a trip carries everything the local copy knows — break segments, paused total, edited flag, and direction source — so a restore to a new device reproduces the trip exactly instead of silently dropping v0.3 metadata
**Depends on**: Phase 18 (trip_breaks + total_paused_seconds model), Phase 19 (is_edited), Phase 21 (direction_source), Phase 24 (auto-restore + conflict reconciliation paths that must round-trip the new fields), Phase 25.1 (fix the conflict-sheet Merge stub before extending it with break fields)
**Requirements**: TBD
**Success Criteria** (what must be TRUE):

  1. The sync payload and Firestore document include `totalPausedSeconds`, `isEdited`, `directionSource`, and an embedded `breaks` array of `{startTime, endTime}` ISO-string segments (bounded, e.g. max 50 per trip); the zod schema accepts all four as optional with defaults so older clients keep syncing
  2. The backend deploys BEFORE any client that emits the new fields (the non-strict zod schema would silently strip unknown keys, losing data without an error)
  3. Restore writes the breaks into `trip_breaks` in the same transaction as the trip insert, and a restored trip with breaks survives a subsequent edit without its paused time recomputing to zero
  4. Trips already in Firestore without the new fields restore cleanly with defaults (no parse failures), and a one-time backfill re-enqueues local trips that have breaks or edits so their cloud copies gain the metadata
  5. Conflict resolution treats breaks as riding along with whichever side wins (no per-break field merge UI)

**Plans**: 6 plans

Plans:
**Wave 1**

- [x] 26-01-PLAN.md — Backend: extend zod tripSchema/Trip/TripDoc/Firestore converter/both handlers + tests, deploy live (SC1, SC2, SC4 legacy-doc defaults)
- [x] 26-02-PLAN.md — Client: schema v6->v7 backfill marker migration, TripBreaksDao batch lookup, UserPreferencesDao marker, Phase 26 constants

**Wave 2** *(blocked on Wave 1)*

- [x] 26-03-PLAN.md — Client wire contract: TripSerializer/ApiClient/SyncEngine emit breaks + metadata (depends on live backend deploy, SC2 gate)
- [x] 26-04-PLAN.md — One-time backfill trigger: TripsDao query + MainShell sign-in seam wiring (D-01/D-02/D-03, SC4)

**Wave 3** *(blocked on Wave 2)*

- [x] 26-05-PLAN.md — RestoreController: D-07 metadata-excluded conflicts, atomic trip+breaks insert, D-10/D-11 enrichment (SC3, SC4)

**Wave 4** *(blocked on Wave 3)*

- [x] 26-06-PLAN.md — Merge resolution extraction (D-06) + D-04 ride-along + Use-Cloud breaks carry-along + D-05 indicator (SC5)

**UI hint**: no

### Phase 29: Sync Home & Office Locations to Cloud

**Goal**: A user who reinstalls or signs in on a new device gets their saved Home and Office locations back automatically, so geofence auto-labeling keeps working without re-picking two map pins
**Depends on**: Phase 21 (coord columns + geofence resolver), Phase 24 (auto-restore-on-sign-in seam), Phase 26 (sync/restore wire-contract patterns this mirrors)
**Requirements**: LOC-03
**Success Criteria** (what must be TRUE):

  1. Setting Home or Office pushes both pairs to Firestore within one sync cycle
  2. The backend deploys BEFORE any client emits preference payloads (non-strict zod would strip unknown keys and lose data silently — the Phase 26 SC#2 lesson)
  3. A fresh install that signs in receives its saved Home/Office; geofence auto-labeling works on the first trip with no map interaction
  4. A device with Home already set locally is NOT changed by restore (D-03 null-only merge — client stays authoritative)
  5. A user who never set Home/Office syncs and restores cleanly (all-null is valid, not an error)
  6. No coordinate appears in any log, on device or in Cloud Functions logs
  7. The Play Data Safety declaration is updated before release (process gate, not code)

**⚠ This phase deliberately reverses a mitigated threat decision.** Phase 21's T-21-02 / T-21-02-01 recorded that Home/Office coords "live only in local Drift […] not sent to any backend", and the constraint is written into the column dartdocs themselves. Phase 29 overturns that on purpose — see D-01 in `29-PLAN.md` for the rationale and the mandatory costs. The Play listing changes from *no location collected* to *precise location collected*. `T-21-03` ("NEVER log") is upheld, not reversed.

**Plans**: 3 waves — ALL CODE COMPLETE 2026-07-20; branch `phase-29-sync-home-office` **merged to `main` at `13ffec9`** (2026-07-20) and the backend is **deployed and live**. The Data Safety gate below is now enforced by `.planning/RELEASE-GATES.md` rather than by the branch staying off `main`.

Plans:
**Wave 1**
- [x] Backend: zod schema, both handlers, Firestore converter, tests (`5733236`) — **DEPLOYED + verified live 2026-07-20** (SC#2 satisfied)

**Wave 2**
- [x] Client wire: ApiClient methods, PreferencesSyncService, D-01 dartdoc rewrite (`9843204`)

**Wave 3**
- [x] Triggers: push on picker-confirm, restore-then-push on sign-in, D-03 null-only merge (`bf96bbb`)

**Backend is deployed and live** (2026-07-20) — SC#2 satisfied; all five routes verified, including that the pre-existing trip routes survived the shared-function replacement. **ONE gate remains:** the Play Data Safety declaration must change from *no location collected* to *precise location collected* (D-01) before the CLIENT ships. Deploying endpoints nothing calls collects no data, which is why the deploy went first. The branch merged to `main` at `13ffec9` on 2026-07-20; the declaration gate is now tracked in `.planning/RELEASE-GATES.md` as a 🔴 BLOCKING release item, since the structural guard of an unmerged branch no longer exists.

**UI hint**: no

### Phase 30: Geofence Departure Detection

**Goal**: The app notices the user has left Home (or Office) and offers to start tracking, so a commute is captured even when the user forgets to press Start
**Depends on**: Phase 21 (Home/Office coords already exist — this phase adds *detection*, not storage)
**Requirements**: AUTO-03
**Status**: BLOCKED on the 30-00 spike

**⚠ Blocked by a P0 measurement spike that needs a real drive.** The whole feature rests on whether Android's `GEOFENCE_TRANSITION_EXIT` fires soon enough to be useful — unverified for the user's device and OEM, and unanswerable from docs. Task 30-00 is a throwaway spike (≥5 drives, logcat attached) with kill criteria fixed *in advance*: median > 180 s, or ≤ 2/5 firing, cancels the phase. A geofence that fires minutes late would start a trip partway down the road with a mangled distance and a corrupted stuck-vs-moving ratio — attacking the app's core value. Building the permission flow or settings toggle before the spike is trim on a car whose engine may not start.

**Success Criteria** (what must be TRUE):

  0. The 30-00 spike has run and passed its kill criteria — no other criterion is assessable first
  1. Driving away from Home produces the D-02 notification within the spike-measured latency budget
  2. Tapping it starts tracking; ignoring it leaves no trace (no partial trip, no orphaned service)
  3. The toggle is OFF by default; no background-location permission is requested until it is turned on
  4. Feature off ⇒ behavior identical to the existing app (purely additive)
  5. No coordinate appears in any log

**Plans**: TBD (spike first)

Plans:
- [ ] 30-00 — SPIKE: measure EXIT trigger latency on a real drive (throwaway, blocking, P0)

**UI hint**: yes (settings toggle + permission rationale screen)

### Phase 31: Trip Detail — Breaks, Stuck Transparency, Edit Gating

**Goal**: Opening a trip shows what actually happened on that drive — real breaks, real stuck locations on the map, an honest explanation of the stuck metric — while direction edits move behind the Edit button
**Depends on**: Phase 18 (the `trip_breaks` table this surfaces), Phase 19 (`EditTripSheet`, the sole direction write path), Phase 27 (the accuracy work in `TripAccumulator` this extends)
**Requirements**: UX-09, TRACK-15

**Head of the post-UAT batch.** Introduces schema **v9** and the shared `InfoSheet` widget that Phases 32 and 33 both consume, so it blocks both. Also removes a fabrication: `TripTimeline` currently places a "Stuck in traffic" marker at a hardcoded 40% of trip duration (`trip_timeline.dart:44-46`), derived from nothing.

**Success Criteria** (what must be TRUE):

  1. Direction cannot be changed from the trip detail view — only inside `EditTripSheet`
  2. A trip recorded after this phase paints red stuck stretches where the user was actually below 10 km/h for ≥60 continuous seconds
  3. Painted segment durations never sum to more than the trip's `timeStuckSeconds`
  4. A GPS gap longer than `kTrackingMaxAttributableGapSeconds` never appears as a painted stuck stretch
  5. A trip recorded *before* this phase renders a plain polyline with no error and no empty state
  6. The timeline shows real breaks and real stuck stretches in time order; the 40% marker exists nowhere in the codebase
  7. An info icon beside the stuck figure explains it in plain language (no m/s, no "sample", no "threshold")
  8. The Phase 26 trip-payload key-set test passes unchanged — trip sync gained no field
  9. `schemaVersion` is 9 and v8 → v9 preserves every existing trip

**Plans**: 3 plans across 2 waves

Plans:
**Wave 1**
- [ ] 31-01 — interval classification + `trip_stuck_segments` table + migration v9 (SC2, SC3, SC4, SC9) — owns all Drift work
- [ ] 31-02 — shared `InfoSheet` widget + constants (SC7) — independent, parallel with 31-01

**Wave 2** *(blocked on Wave 1)*
- [ ] 31-03 — remove direction toggle, extract map section + paint segments, rewrite timeline (SC1, SC5, SC6)

**UI hint**: yes (trip detail map, timeline, info sheet)

### Phase 32: Identity & Dashboard Personalization

**Goal**: The app greets the user by their actual name, the avatar is theirs, and account controls live behind it instead of buried at the top of Settings
**Depends on**: Phase 20 (first-run login with skip — the guest state), Phase 24 (auto-restore, surfaced by `CloudSyncRow`/`RestoreRow`), Phase 31 (`InfoSheet`)
**Requirements**: UX-10

**Must land before Phase 33** — this phase deletes `_AccountSection` from `settings_screen.dart` while Phase 33 restructures the remaining sections of the same file. No schema change.

**Success Criteria** (what must be TRUE):

  1. A signed-in user sees "Hi, {first name}" and their initial in the avatar
  2. A guest — and a user whose account has no display name, or a whitespace-only one — sees "Hi, Traveller" / "T", with no blank avatar and no crash
  3. Tapping the avatar opens an account sheet matching what Settings showed before, for both signed-in and guest states
  4. Settings contains no Account section and no second sign-out or restore control
  5. Signing in or out while the dashboard is visible updates greeting and avatar without a manual refresh
  6. An info icon beside the weekly summary explains the Mon–Sun window, what "lost to traffic" measures, and that breaks are excluded
  7. The avatar's touch target is ≥48×48 while its painted size is unchanged

**Plans**: 2 plans, 1 wave (parallel)

Plans:
**Wave 1**
- [ ] 32-01 — header identity wiring + account sheet + remove `_AccountSection` (SC1–SC5, SC7) — owns the settings file
- [ ] 32-02 — weekly summary info icon (SC6)

**UI hint**: yes (dashboard header, account sheet)

### Phase 33: Settings & Smart Reminders

**Goal**: Reminders work the moment the app is installed, adapt to when the user actually commutes, run only on the days they choose, and Settings stops showing a control that does nothing
**Depends on**: Phase 7 (the reminder scheduling this rewrites), Phase 31 (`InfoSheet`), Phase 32 (which removes `_AccountSection` from the same file)
**Requirements**: NOTIF-04, UX-11

**Schema v10** — after Phase 31 (v9), before Phase 35 (v11). The highest-risk item in the batch is the migration itself: changing the `reminderEnabled` default must **not** re-enable notifications for users who deliberately turned them off (T-33-02).

**Success Criteria** (what must be TRUE):

  1. A fresh install has the daily reminder enabled at 07:00 on weekdays with no visit to Settings
  2. An existing user who had explicitly disabled the reminder still has it disabled after upgrade
  3. An existing user with `weekendReminder = true` has all seven days selected after upgrade
  4. An arbitrary day subset schedules reminders on exactly those days — including stopping Saturday and Sunday when deselected
  5. Selecting zero days means no reminders, and does not silently revert to weekdays
  6. After 5+ `to_office` GPS trips in 28 days, Settings shows a suggested time from the median start, 15 min earlier, rounded down to 5 min
  7. Dismissing the suggestion prevents it reappearing until the computed value moves by >20 minutes
  8. Manual entries do not influence the suggestion
  9. The cutoff row no longer exists; direction labelling behaviour is unchanged
  10. An info icon beside auto-pause explains that the app *asks* rather than pauses
  11. `schemaVersion` is 10 and v9 → v10 preserves all existing preferences

**Plans**: 3 plans across 3 waves

Plans:
**Wave 1**
- [ ] 33-01 — schema v10 + prefs DAO 6 touch points + `scheduleReminder` rewrite incl. widened 20–26 cancel sweep (SC1–SC5, SC11) — owns all Drift and notification work

**Wave 2** *(blocked on Wave 1)*
- [ ] 33-02 — `ReminderSuggestionService`: median, 5-trip/28-day gate, 15-min offset, >20-min re-offer rule (SC6, SC7, SC8)

**Wave 3** *(blocked on Waves 1 and 2)*
- [ ] 33-03 — day-of-week picker, remove cutoff row, auto-pause info sheet, suggestion card (SC9, SC10)

**UI hint**: yes (settings restructure, day picker, suggestion card)

### Phase 34: Multi-Period Stats (RnD First)

**Goal**: Stats answer "how is my commute trending?" across weeks, months and years, with a daily average comparable between periods of different length
**Depends on**: Phase 5 (the stats feature and `computeStatsSummary` this extends), Phase 31 (`InfoSheet`, if the RnD recommends explainers)
**Requirements**: STATS-03

**⚠ Wave 1 is a review gate.** The RnD document must be read and accepted before any code. The daily-average denominator is the decisive question: dividing by calendar days makes a commute look like it improved when the user merely took leave — a metric that attacks the app's stated core value. No schema change.

**Success Criteria** (what must be TRUE):

  1. `34-RESEARCH.md` exists, answers all six questions with a recommendation each, and is accepted before any code
  2. The stats screen offers weekly, monthly and yearly periods
  3. Each period shows a daily average whose label states its denominator unambiguously
  4. The RnD's worked examples are encoded as unit tests and pass
  5. Dashboard and stats agree on "this week", and match their pre-phase values for the same trips
  6. `monthTotalSeconds` is either rendered or removed along with its unused constants
  7. Switching periods is not perceived as a stall on a database holding a year of trips

**Plans**: 3 plans across 3 waves (spike first)

Plans:
**Wave 1** *(review gate — stop here)*
- [ ] 34-01 — write `34-RESEARCH.md`: period semantics, daily-average denominator, metric set, partial periods, aggregation strategy with a measured row count, UI shape (SC1). No code.

**Wave 2** *(blocked on Wave 1 acceptance)*
- [ ] 34-02 — aggregation layer + tests encoding the worked examples (SC3, SC4, SC5)

**Wave 3** *(blocked on Wave 2)*
- [ ] 34-03 — period selector + card updates + `monthTotalSeconds` resolution (SC2, SC6, SC7)

**UI hint**: yes (period selector, period-aware cards)

### Phase 35: Deleted Trips (Trash)

**Goal**: Deleting a trip is recoverable for 30 days instead of instantly permanent, and deleting a trip that has breaks stops being a coin flip
**Depends on**: Phase 24 (restore, whose conflict detection must keep seeing deleted rows), Phase 26 (the sync wire contract this leaves untouched), Phase 31 (stuck segments that must cascade), Phase 33 (schema ordering)
**Requirements**: TRIP-07

**Schema v11** — last migration of the batch. **Fixes a pre-existing bug not raised in the original request**: `TripBreaks.tripId` has no `onDelete` action while `PRAGMA foreign_keys = ON`, so deleting a trip with breaks may currently fail and surface as a generic snackbar. Also corrects a documented-but-false claim — CLAUDE.md says "soft deletes everywhere" while `trips_dao.dart:199` issues a real `DELETE`.

**Success Criteria** (what must be TRUE):

  1. Deleting a trip removes it from history, dashboard and stats simultaneously, and it appears under Settings → Deleted trips
  2. Restoring returns it to all three surfaces with breaks and metadata intact
  3. Deleting a trip *that has breaks* succeeds — the pre-existing FK path is fixed
  4. A soft-deleted trip is NOT resurrected by a cloud restore
  5. Trips soft-deleted >30 days ago are purged on app start with their breaks and segments; the purge enqueues nothing
  6. Each Trash row shows how long ago it was deleted and how long remains
  7. "Delete permanently" confirms first, and is thereafter unrecoverable locally
  8. The sync wire format is unchanged — the Phase 26 payload key-set test passes untouched
  9. `schemaVersion` is 11 and v10 → v11 preserves every existing trip and break

**Plans**: 2 plans across 2 waves

Plans:
**Wave 1**
- [ ] 35-01 — schema v11 (`trips.deletedAt`, `trip_breaks` FK cascade rebuild), DAO filter + the three reader decisions, soft delete/restore, startup purge (SC1–SC5, SC8, SC9) — owns all Drift work

**Wave 2** *(blocked on Wave 1)*
- [ ] 35-02 — Trash screen, Settings entry, restore + permanent delete, retention countdown (SC6, SC7)

**UI hint**: yes (Trash screen under Settings)

### Phase 36: Widget & Platform Fixes

**Goal**: The home-screen widget fits where it should and its stop button reads as stop; "Open settings" lands on the location permission itself; the notification's Stop button visibly stops the trip instead of appearing to merely open the app
**Depends on**: Phase 22 (the widget), Phase 27 (the auto-pause confirm pattern this mirrors), Phase 28 (the responsive two-layout sizing this adjusts)
**Requirements**: WIDGET-03, UX-12, TRACK-16

No schema change; independent of Phases 31–35 and may run in parallel with any of them. Two root causes are already identified: the widget stop button uses `@android:drawable/ic_media_ff` — the platform *fast-forward* glyph, which is exactly why it reads as play — and the notification Stop action carries `showsUserInterface: true`, bringing the app forward with no confirmation, giving the impression it only opened the app. The auto-pause action was already fixed the same way on 2026-07-21 (`tracking_notification_service.dart:433`).

**Success Criteria** (what must be TRUE):

  1. The widget can be placed and resized to a single cell tall on a real launcher without clipped text or unreachable buttons
  2. The stop button is unmistakably a stop control on its own background, not the fast-forward icon
  3. `ic_media_ff` appears nowhere in the project
  4. Denying location on a fresh install and tapping "Open settings" lands on the app's permission list, not App Info
  5. Where `ACTION_APP_PERMISSIONS` does not resolve, the fallback opens App Info and the app does not crash
  6. All three permission-denial paths lead to the same destination; `permission_gate.dart` is deleted
  7. Tapping Stop on the notification brings the app forward AND shows a "Stop this trip?" confirmation; cancelling leaves the trip recording
  8. The notification stop path works in a **release** build with the app backgrounded
  9. Notification and widget stop confirmations use the same dialog and wording

**Plans**: 3 plans, 1 wave (parallel — disjoint file sets)

Plans:
**Wave 1**
- [ ] 36-01 — Android resources: `widget_info.xml`, both layouts, two new drawables (SC1, SC2, SC3). No Dart.
- [ ] 36-02 — permission deep-link channel + unify the three denial paths + delete `permission_gate.dart` (SC4, SC5, SC6)
- [ ] 36-03 — stop-confirm relay mirroring the auto-pause pattern (SC7, SC8, SC9) — merges after 36-02, both touch `main_shell.dart` in distinct regions

**UI hint**: yes (widget layout, confirm dialog)

## v0.3 Progress

**Execution Order:**
v0.3 phases execute in numeric order after the (paused) v0.2 phases: 17 -> 18 -> 19 -> 20 -> 21 -> 22 -> 23 -> 24 -> 25 -> 25.1 -> 26 -> 27 -> 28 -> 29 -> 30 -> 31 -> 32 -> 33 -> 34 -> 35 -> 36

Phases 31-36 are the post-UAT bug/feature batch (17 reported items), split so that no two phases contend for the same files. Their ordering is load-bearing for two reasons. **Migrations must land in sequence** — 31 (v9) -> 33 (v10) -> 35 (v11) — because each branch is guarded `if (from < N && to >= N)`. And **Phase 31 must precede 32 and 33**, which both consume the shared `InfoSheet` it introduces, while **Phase 32 must precede 33**, because 32 deletes `_AccountSection` from `settings_screen.dart` and 33 restructures the rest of that same file. Phases 34 and 36 are independent of the others and may run any time after 31.

Note: Phase 17 is a small, independent UI fix + quick-label and is the safe first phase. Phase 18 introduces the break/pause data model (schema migration) that Phase 19 (full editing) depends on. Phases 20 and 21 are largely independent of the tracking-data work and build on existing auth/onboarding and settings/preferences. Phase 22 (home-screen widget) has the highest platform-integration risk and lands last, after the pause/resume state model exists so the widget can reflect accurate state.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 17. Tracking UI Fixes & Quick Label | v0.3 | 2/2 | Complete | 2026-06-06 |
| 18. Trip Pause & Breaks | v0.3 | 4/4 | Complete | 2026-06-06 |
| 19. Full Trip Editing | v0.3 | 2/2 | Complete | 2026-06-06 |
| 20. First-Run Login with Skip | v0.3 | 1/1 | Complete | 2026-06-06 |
| 21. Home & Office Locations + Geofence Auto-Label | v0.3 | 3/3 | Complete | 2026-06-06 |
| 22. Home-Screen Widget | v0.3 | 1/1 | Complete | 2026-06-09 |
| 23. Resolve Deferred UAT Items (Android) | v0.3 | 48/60 | CLOSED EARLY 2026-07-21 — 48 passed ad-hoc; remainder SKIPPED by priority | 2026-07-21 |
| 24. Automatic Cloud Sync & Restore | v0.3 | 3/3 | Complete | 2026-06-16 |
| 25. Interrupted-Trip Recovery | v0.3 | 3/3 | Complete | 2026-06-28 |
| 25.1. Fix Sync Conflict & Auto-Retry Bugs (INSERTED) | v0.3 | 2/2 | Complete | 2026-07-12 |
| 26. Sync Breaks & Edit Metadata to Cloud | v0.3 | 6/6 | Complete    | 2026-07-13 |
| 27. UX Tour + Tracking Accuracy | v0.3 | 3/3 | Code complete (on-device UAT pending) | 2026-07-18 |
| 28. Widget Content + Responsive Sizing | v0.3 | 3/3 | Code complete (on-device UAT pending) | 2026-07-18 |
| 29. Sync Home & Office Locations to Cloud | v0.3 | 3/3 | Backend LIVE; client blocked on Data Safety declaration | 2026-07-20 |
| 30. Geofence Departure Detection | v0.3 | 0/TBD | Blocked on 30-00 spike (needs real drive) | - |
| 31. Trip Detail — Breaks, Stuck Transparency, Edit Gating | v0.3 | 0/3 | Not started (schema v9; head of the 31-36 batch) | - |
| 32. Identity & Dashboard Personalization | v0.3 | 0/2 | Not started (must precede 33) | - |
| 33. Settings & Smart Reminders | v0.3 | 0/3 | Not started (schema v10) | - |
| 34. Multi-Period Stats (RnD First) | v0.3 | 0/3 | Not started (Wave 1 is a review gate) | - |
| 35. Deleted Trips (Trash) | v0.3 | 0/2 | Not started (schema v11; fixes pre-existing FK cascade bug) | - |
| 36. Widget & Platform Fixes | v0.3 | 0/3 | Not started (independent; parallelisable) | - |
