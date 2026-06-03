// Phase 1 top-level constants for the Traevy app.
//
// Every value here is locked by CLAUDE.md or the Phase 1 CONTEXT document.
// Future phases append new constants to this file — they never replace
// the values below.

/// Speed threshold (km/h) below which a trip sample counts as stuck in
/// traffic. Samples at or above this speed are counted as "moving".
///
/// See CLAUDE.md "Traffic Calculation".
const double kStuckSpeedThresholdKmh = 10;

/// Default hour-of-day (0–23) used to auto-label a trip direction.
/// Trips starting before this hour default to `to_office`, trips starting
/// at or after it default to `to_home`. User can override per trip.
///
/// See CLAUDE.md "Direction Auto-Labeling".
const int kDefaultDirectionCutoffHour = 12;

/// Placeholder `user_id` used for every row until authentication ships
/// in Phase 8. At that point the Cognito `sub` replaces this value.
///
/// See D-02 in `.planning/phases/01-foundation/01-CONTEXT.md`.
const String kDefaultUserId = 'local_user';

/// Filename (without extension) of the on-device Drift SQLite database.
/// Used by the Drift database opener in Phase 1 plan 03.
///
/// See D-04 in `.planning/phases/01-foundation/01-CONTEXT.md`.
const String kDatabaseName = 'traevy';

/// Maximum number of times the sync engine will retry a single sync queue
/// entry before marking it as `failed`. Matches CLAUDE.md's cap of three.
///
/// See CLAUDE.md "sync_queue retries max 3".
const int kSyncQueueMaxRetries = 3;

/// Direction literal for commutes heading to the office (morning trips).
///
/// See CLAUDE.md "Direction Auto-Labeling".
const String kDirectionToOffice = 'to_office';

/// Direction literal for commutes heading home (evening trips).
///
/// See CLAUDE.md "Direction Auto-Labeling".
const String kDirectionToHome = 'to_home';

/// `sync_queue.action` literal for a newly-created trip that needs to be
/// pushed to the backend.
///
/// See CLAUDE.md "sync_queue" table schema.
const String kSyncActionCreate = 'create';

/// `sync_queue.action` literal for an edited trip that needs to be
/// pushed to the backend.
///
/// See CLAUDE.md "sync_queue" table schema.
const String kSyncActionUpdate = 'update';

/// `sync_queue.action` literal for a soft-deleted trip that needs to be
/// pushed to the backend.
///
/// See CLAUDE.md "sync_queue" table schema.
const String kSyncActionDelete = 'delete';

/// `sync_queue.status` literal for an entry that has not yet been pushed.
///
/// See CLAUDE.md "sync_queue" table schema.
const String kSyncStatusPending = 'pending';

/// `sync_queue.status` literal for an entry that was successfully pushed.
///
/// See CLAUDE.md "sync_queue" table schema.
const String kSyncStatusSynced = 'synced';

/// `sync_queue.status` literal for an entry that exhausted its retry
/// budget without succeeding.
///
/// See CLAUDE.md "sync_queue" table schema and `kSyncQueueMaxRetries`.
const String kSyncStatusFailed = 'failed';

/// `user_preferences.dark_mode` literal: follow the device-wide theme.
///
/// See CLAUDE.md "user_preferences" table schema.
const String kDarkModeSystem = 'system';

// ---------------------------------------------------------------------------
// Phase 2: Core Tracking (GPS, accumulators, notification)
// ---------------------------------------------------------------------------

/// Minimum trip duration (seconds) for a stopped trip to be persisted.
/// Trips below this threshold are discarded on Stop with a snackbar.
///
/// See D-10 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const int kMinTripDurationSeconds = 30;

/// Minimum trip distance (meters) for a stopped trip to be persisted.
/// Trips below this threshold are discarded on Stop with a snackbar.
///
/// See D-10 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const int kMinTripDistanceMeters = 100;

/// Phase 2 placeholder for the `direction` column until Phase 3 auto-labels
/// trips from `start_time`. Distinct from `kDirectionToOffice` /
/// `kDirectionToHome` so Phase 3 can identify rows that still need labeling.
///
/// See D-11 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const String kDirectionUnknown = 'unknown';

/// Stuck-speed threshold in meters per second. Derived from
/// `kStuckSpeedThresholdKmh` so `Position.speed` from `geolocator` (which
/// reports m/s) can be compared directly without per-sample unit conversion.
///
/// Guards Pitfall 2 (`Position.speed` is m/s, not km/h). See
/// `.planning/phases/02-core-tracking/02-RESEARCH.md` §10.
const double kStuckSpeedThresholdMs = kStuckSpeedThresholdKmh / 3.6;

/// Android notification channel id for the active-commute foreground
/// notification shown while Traevy is recording a commute.
///
/// See D-14, D-15 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const String kTrackingNotificationChannelId = 'traevy_active_commute';

/// User-facing notification channel name shown in Android system settings.
///
/// See D-15 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const String kTrackingNotificationChannelName = 'Active commute';

/// Notification channel description shown in Android system settings.
///
/// See D-15 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const String kTrackingNotificationChannelDescription =
    'Shown while Traevy is recording a commute.';

/// Static body text for the active-commute foreground notification. Static
/// (not per-sample) to avoid notification flicker and battery cost (D-14).
///
/// See D-14 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const String kTrackingNotificationTitle = 'Recording commute';

/// Stable notification id for the UX-03 foreground notification.
///
/// D-14 unification: this ID is used for BOTH the
/// `flutter_background_service` stock foreground-service notification AND
/// the `flutter_local_notifications` 'Recording commute' notification we
/// actually show. Android dedupes by `(channelId, notificationId)`, so
/// reusing the same id on the same channel collapses them into a single
/// shade entry. Plans 02-03 and 02-05 both reference this constant; they
/// MUST stay in sync, or the user will see two notifications.
const int kTrackingNotificationId = 1001;

/// Action id for the Stop button on the foreground notification.
///
/// See D-14 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const String kTrackingStopActionId = 'stop_tracking';

/// User-facing label for the Stop action button on the foreground
/// notification.
///
/// See D-14 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const String kTrackingStopActionLabel = 'Stop';

/// Action id for the Open button on the recording notification (08-10).
/// Tapping OPEN brings the app to the foreground via an Activity
/// PendingIntent — same effect as tapping the notification body.
const String kTrackingOpenActionId = 'open_app';

/// User-facing label for the Open action button (08-10).
const String kTrackingOpenActionLabel = 'Open';

/// iOS notification category id for the active-commute notification (08-10).
/// Categories define which actions appear when the notification is expanded
/// on iOS. Matches the Android action set (Open + Stop) so the cross-platform
/// `flutter_local_notifications` API surfaces the same UX on both platforms.
const String kTrackingNotificationCategoryId = 'traevy_recording';

/// Title template for the active-commute notification (08-10). The
/// `{direction}` token is substituted with the auto-labelled direction
/// ('To office' / 'To home') at show/update time.
const String kTrackingNotificationTitleTemplate =
    'Recording your commute to {direction}';

/// Body template for the active-commute notification (08-10). Tokens are
/// substituted with formatted live values on every snapshot:
///   - {elapsed} → '22:14'
///   - {km}      → '4.1'
///   - {stuck}   → '4m'
const String kTrackingNotificationBodyTemplate =
    '● REC  {elapsed} elapsed · {km} km · {stuck} stuck';

/// GPS sampling interval — balances battery vs fidelity for a typical
/// 30-minute commute. Passed to the geolocator position stream settings.
///
/// See `.planning/phases/02-core-tracking/02-RESEARCH.md` §3.
const Duration kTrackingSampleInterval = Duration(seconds: 3);

/// UI refresh throttle — the service isolate emits `TripSnapshot` state at
/// this cadence so the tracking screen ticks smoothly without rebuilding
/// on every GPS fix.
///
/// See `.planning/phases/02-core-tracking/02-RESEARCH.md` §8.
const Duration kTrackingUiUpdateInterval = Duration(seconds: 1);

/// Maximum position accuracy (meters) the `TripAccumulator` will accept.
/// Samples with worse (larger) accuracy are dropped to protect the
/// distance / speed math from GPS noise.
///
/// Pitfall 2 mitigation extension. See
/// `.planning/phases/02-core-tracking/02-RESEARCH.md` §6.
const double kTrackingMaxAcceptableAccuracyMeters = 30;

/// Maximum time gap (seconds) between two accepted samples before their
/// interval is excluded from moving/stuck time attribution. Longer gaps
/// (tunnels, GPS dropouts) still contribute to the encoded polyline, but
/// do not move the time buckets.
///
/// See `.planning/phases/02-core-tracking/02-RESEARCH.md` §6.
const int kTrackingMaxAttributableGapSeconds = 30;

/// How fresh `_lastAccepted.speed` must be for `TripAccumulator.snapshot`
/// to surface it as `currentSpeedMs`. Older than this and the snapshot
/// reports 0 so the SPEED tile decays correctly when the device stops
/// emitting fresh GPS samples (Android throttles emissions when stationary
/// and the 30m accuracy gate drops stationary low-accuracy samples).
///
/// 6s = 2× `kTrackingSampleInterval` so a single dropped sample does not
/// flip the tile to 0 prematurely, but two consecutive dropped samples
/// (or stationary throttling) will. See
/// `.planning/debug/active-speed-tile-stale.md` for full diagnosis.
const Duration kTrackingSpeedFreshnessWindow = Duration(seconds: 6);

/// Minimum gap between successive notification refreshes (08-10 review HIGH #5).
/// The 1Hz snapshot rate would call `showRecording()` ~2700 times on a 45-min
/// trip — every call round-trips through the platform channel. Throttling to
/// once per 5 s drops a 45-min trip to ~540 platform calls (5x reduction)
/// while keeping the visible refresh cadence well under user-perceivable
/// staleness. `onlyAlertOnce: true` already mutes sound/vibration on every
/// refresh, but does not eliminate the IPC cost.
const Duration kTrackingNotificationRefreshInterval = Duration(seconds: 5);

// ---------------------------------------------------------------------------
// Phase 4: Trip History
// ---------------------------------------------------------------------------

/// Date header label for today's date group in the history list (D-03).
const String kHistoryDateToday = 'Today';

/// Date header label for yesterday's date group in the history list (D-03).
const String kHistoryDateYesterday = 'Yesterday';

/// Empty-state heading shown when the user has no trips (HIST-01).
const String kHistoryEmptyHeading = 'No trips yet';

/// Empty-state body shown when the user has no trips (HIST-01).
const String kHistoryEmptyBody = 'Start a commute to see your history here.';

/// Empty-state body shown when calendar date has no trips (HIST-02).
const String kHistoryCalendarEmptyDate = 'No trips on this day.';

/// Placeholder shown in calendar sub-list when no date is selected (HIST-02).
const String kHistoryCalendarNoSelection = 'Tap a date to see trips.';

/// Badge text on the trip detail screen for manually-entered trips (D-05).
const String kManualEntryBadge = 'Manually entered — no route recorded';

/// Error message on the trip detail screen when findById returns null
/// (HIST-03).
const String kTripDetailNotFound = 'Trip not found.';

/// Height (logical pixels) of the map widget on the trip detail screen (D-06).
const double kTripDetailMapHeight = 256;

/// CARTO Dark Matter tile URL (used when app/phone theme is dark).
/// CARTO tiles are free for non-commercial use and require no API key.
/// OSM public tiles are blocked for unregistered apps.
const String kMapTileUrlDark =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

/// CARTO Positron tile URL (used when app/phone theme is light).
const String kMapTileUrlLight =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

/// Subdomains for the CARTO tile server.
const List<String> kMapTileSubdomains = <String>['a', 'b', 'c', 'd'];

/// User-agent package name sent with tile requests.
const String kMapUserAgentPackageName = 'traevy.traevy';

// ---------------------------------------------------------------------------
// Phase 5: Stats & Analytics
// ---------------------------------------------------------------------------

/// Number of calendar days covered by the trend chart (D-07).
const int kStatsTrendWindowDays = 28;

/// Number of week labels shown on the trend chart x-axis (D-08).
const int kStatsTrendWeekCount = 4;

/// Height (logical pixels) of the trend chart plot area (UI-SPEC spacing
/// exception). Multiple of 4.
const double kStatsTrendChartHeight = 192;

/// AppBar title for the stats screen (UI-SPEC §Copywriting Contract).
const String kStatsAppBarTitle = 'Stats';

/// Label for the weekly total row on the totals card (STAT-01).
const String kStatsCardWeekLabel = 'This week';

/// Label for the monthly total row on the totals card (STAT-01).
const String kStatsCardMonthLabel = 'This month';

/// Helper text under the weekly total clarifying D-03 week boundary.
const String kStatsCardWeekHelper = 'Mon–Sun';

/// Heading for the direction averages card (STAT-02).
const String kStatsCardDirectionTitle = 'Average commute';

/// Label for the to-office average row (STAT-02).
const String kStatsCardToOfficeLabel = 'To office';

/// Label for the to-home average row (STAT-02).
const String kStatsCardToHomeLabel = 'To home';

/// Heading for the best/worst day card (STAT-03).
const String kStatsCardBestWorstTitle = 'Day of the week';

/// Tooltip / a11y label on the best-day chip (STAT-03).
const String kStatsCardBestLabel = 'Best';

/// Tooltip / a11y label on the worst-day chip (STAT-03).
const String kStatsCardWorstLabel = 'Worst';

/// Heading for the trend chart card (STAT-04).
const String kStatsCardTrendTitle = '4-week trend';

/// Label for the trailing x-axis tick (current week, D-08).
const String kStatsCardTrendXAxisCurrent = 'This week';

/// Prefix for the first three x-axis ticks ("Week 1", "Week 2", "Week 3";
/// D-08).
const String kStatsCardTrendXAxisPrefix = 'Week ';

/// Heading for the traffic waste card (STAT-05).
const String kStatsCardTrafficTitle = 'Stuck in traffic';

/// Helper text under the traffic waste duration (STAT-05, this-week scope).
const String kStatsCardTrafficHelper = 'This week';

/// Em-dash placeholder rendered in card value slots when no trips qualify
/// (D-10). Single character U+2014.
const String kStatsEmptyPlaceholder = '—';

/// User-facing message rendered when the stats StreamProvider is in an
/// error state. RESEARCH.md §"Open question 2" Option A — no retry hint
/// because there is no RefreshIndicator in Phase 5.
const String kStatsErrorMessage = 'Could not load stats.';

// ---------------------------------------------------------------------------
// Phase 6: Dashboard
// ---------------------------------------------------------------------------

/// FAB label when tracking is idle (D-03).
const String kDashboardFabIdleLabel = 'Start commute';

/// FAB label when tracking is active (D-03).
const String kDashboardFabActiveLabel = 'Go to tracking';

/// Section heading above today's trip list (D-02).
const String kDashboardTodaySectionLabel = 'Today';

/// Empty-state label shown when no trips exist today (D-05).
const String kDashboardEmptyStateLabel = 'No commutes yet today';

/// Error-state label shown when the trips provider is in an error state.
const String kDashboardErrorMessage = 'Could not load trips.';

/// In-progress card title label (D-04).
const String kDashboardInProgressLabel = 'In progress';

/// Weekly summary card title label (D-06).
const String kDashboardWeeklySummaryTitle = 'This week';

/// Weekly summary traffic row label (D-06, Claude's discretion).
const String kDashboardInTrafficLabel = 'In traffic';

/// Trip count label when today has exactly one trip (D-06 pluralization).
const String kDashboardTripCountSingular = '1 trip';

/// Trip count label template when today has multiple trips.
/// Build the full string at call site: '$count trips'
/// using [kDashboardTripCountPlural] as the suffix.
const String kDashboardTripCountPlural = 'trips';

/// Tooltip for the manual-entry icon button in the dashboard AppBar (D-07).
const String kDashboardAddTripTooltip = 'Add trip manually';

/// Dialog title shown when location permission is permanently denied (D-03).
const String kDashboardPermDeniedTitle = 'Location permission denied';

/// Dialog body shown when location permission is permanently denied (D-03).
const String kDashboardPermDeniedBody =
    'Location permission is permanently denied. Open system '
    'settings to enable it?';

/// Dialog title shown when notification permission is denied (D-03).
const String kDashboardNotifDeniedTitle = 'Notifications required';

/// Dialog body shown when notification permission is denied (D-03).
const String kDashboardNotifDeniedBody =
    'Notifications are required to track commutes in the '
    'background. Open system settings to enable them?';

/// Generic cancel action label used in confirmation dialogs.
const String kDialogCancel = 'Cancel';

/// Open-settings action label used in permission dialogs (D-03).
const String kDialogOpenSettings = 'Open settings';

/// Delete-trip confirmation dialog title (T-03-14).
const String kTripDeleteDialogTitle = 'Delete trip?';

/// Delete-trip confirmation dialog body (T-03-14).
const String kTripDeleteDialogBody = 'This trip will be permanently removed.';

/// Destructive confirm label on the delete-trip dialog (T-03-14).
const String kTripDeleteConfirm = 'Delete';

/// Snackbar message shown after a trip is successfully deleted (D-08).
const String kTripDeletedSnackbar = 'Trip deleted';

/// Snackbar message shown when a trip deletion fails (D-08).
const String kTripDeleteErrorSnackbar = "Couldn't delete the trip. Try again.";

// ---------------------------------------------------------------------------
// Phase 7: Polish & Notifications
// ---------------------------------------------------------------------------

/// `user_preferences.dark_mode` literal: force light mode.
///
/// See D-03 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kDarkModeLight = 'light';

/// `user_preferences.dark_mode` literal: force dark mode.
///
/// See D-03 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kDarkModeDark = 'dark';

/// AppBar title for the Settings screen.
///
/// See D-01 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kSettingsAppBarTitle = 'Settings';

/// Tooltip for the gear IconButton in the Dashboard AppBar (D-01).
///
/// See D-01 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kSettingsTooltip = 'Settings';

/// Settings screen Appearance section header.
const String kSettingsAppearanceSectionTitle = 'Appearance';

/// Settings screen Notifications section header.
const String kSettingsNotificationsSectionTitle = 'Notifications';

/// RadioListTile label for the System-default dark mode option.
const String kSettingsDarkModeSystemLabel = 'System default';

/// RadioListTile label for the forced-light dark mode option.
const String kSettingsDarkModeLightLabel = 'Light';

/// RadioListTile label for the forced-dark dark mode option.
const String kSettingsDarkModeDarkLabel = 'Dark';

/// SwitchListTile title for the weekly summary notification toggle.
///
/// See D-07 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kSettingsWeeklySummaryLabel = 'Weekly summary';

/// SwitchListTile subtitle clarifying when the weekly summary fires.
///
/// See D-05 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kSettingsWeeklySummarySubtitle = 'Every Sunday at 6 PM';

/// SwitchListTile title for the daily tracking reminder toggle.
///
/// See D-09 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kSettingsReminderLabel = 'Daily reminder';

/// ListTile title for the reminder time picker row.
///
/// See D-10 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kSettingsReminderTimeLabel = 'Reminder time';

/// SwitchListTile title for the weekend reminder toggle.
///
/// See D-10 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kSettingsWeekendReminderLabel = 'Include weekends';

/// Error state body text shown when the userPreferenceProvider is in error.
const String kSettingsErrorMessage = 'Could not load settings.';

/// Android notification channel ID for the weekly commute summary.
///
/// See D-14 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kWeeklySummaryChannelId = 'weekly_summary';

/// Android notification channel display name for the weekly summary.
const String kWeeklySummaryChannelName = 'Weekly Summary';

/// Android notification channel description for the weekly summary.
const String kWeeklySummaryChannelDescription =
    'Weekly commute summary delivered every Sunday evening';

/// Android notification channel ID for the daily commute reminder.
///
/// See D-14 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kReminderChannelId = 'commute_reminder';

/// Android notification channel display name for the daily reminder.
const String kReminderChannelName = 'Commute Reminder';

/// Android notification channel description for the daily reminder.
const String kReminderChannelDescription =
    'Daily reminder to start recording your commute';

/// flutter_local_notifications ID for the weekly summary notification.
///
/// See D-05, D-06 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const int kWeeklySummaryNotificationId = 10;

/// Base flutter_local_notifications ID for the daily reminder.
///
/// Weekday-only mode uses IDs [kReminderNotificationId] through
/// [kReminderNotificationId] + 4 (Mon=20, Tue=21, Wed=22, Thu=23, Fri=24).
/// Cancel the full range 20–24 before rescheduling.
///
/// See D-12 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const int kReminderNotificationId = 20;

/// Weekly summary notification title.
///
/// See D-06 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kWeeklySummaryNotificationTitle = 'Your week in commute';

/// Weekly summary notification body template.
///
/// Replace both %s tokens at schedule time:
/// `String.fromEnvironment` is NOT used — substitute via explicit
/// string interpolation: `'$total total, $stuck in traffic'`.
///
/// See D-06 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kWeeklySummaryNotificationBodyTemplate = '%s total, %s in traffic';

/// Weekly summary notification body when no trips were recorded.
///
/// See D-06 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kWeeklySummaryNotificationBodyEmpty =
    'No commutes recorded this week';

/// Daily reminder notification title.
///
/// See D-11 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kReminderNotificationTitle = 'Time to track your commute';

/// Daily reminder notification body.
///
/// See D-11 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
const String kReminderNotificationBody = 'Tap to start recording your commute';

// ---------------------------------------------------------------------------
// Phase 8 — UI Overhaul (Traevy design system)
// ---------------------------------------------------------------------------

/// Font family name for all UI text (body copy, labels, buttons, headings).
/// Resolved via the `google_fonts` package — see pubspec.yaml.
///
/// Design token source: Typography block in
/// `.planning/phases/08-ui-overhaul/08-CONTEXT.md`.
const String kFontUI = 'Inter';

/// Font family name for all numeric / monospace data displays (duration,
/// distance, speed, time, percentages).
/// Resolved via the `google_fonts` package — see pubspec.yaml.
///
/// Design token source: Typography block in
/// `.planning/phases/08-ui-overhaul/08-CONTEXT.md`.
const String kFontMono = 'JetBrainsMono';

/// Placeholder display name shown in the header before the user signs in
/// (Phase 9 populates this from Cognito profile).
///
/// Design token source: Specifics block in
/// `.planning/phases/08-ui-overhaul/08-CONTEXT.md`.
const String kPlaceholderUserName = 'Traveller';

/// Single-character placeholder initial for the user avatar before sign-in.
///
/// Design token source: Specifics block in
/// `.planning/phases/08-ui-overhaul/08-CONTEXT.md`.
const String kPlaceholderUserInitial = 'T';

/// Short brand mark rendered in the `TraevyLogoMark` widget header — "tv" in
/// JetBrains Mono 700. Never use this as the canonical app name; use
/// `kBrandFullName` for that.
///
/// Design token source: Specifics block in
/// `.planning/phases/08-ui-overhaul/08-CONTEXT.md`.
const String kBrandShortName = 'tv';

/// Full brand name used in headings and accessibility labels.
///
/// Design token source: Specifics block in
/// `.planning/phases/08-ui-overhaul/08-CONTEXT.md`.
const String kBrandFullName = 'Traevy';

// ---------------------------------------------------------------------------
// Phase 9 — Authentication (Firebase Auth + Google Sign-In)
// ---------------------------------------------------------------------------

/// Web OAuth 2.0 client ID for the Firebase project.
///
/// This is the **Web** client ID auto-created by Firebase (found in GCP Console
/// → APIs & Services → Credentials → "Web client (auto created by Google
/// Service)"). It is required on Android so that `google_sign_in` can mint an
/// ID token that Firebase will accept — omitting it causes sign-in
/// to fail even though the account picker succeeds (RESEARCH Pitfall 2).
///
/// This is a **public client identifier** — not a secret. It is safe to commit
/// to source control (RESEARCH Runtime State Inventory, D-14).
///
/// Replace the placeholder below with the real value after running
/// `flutterfire configure` and locating the web client in GCP Credentials.
///
/// See D-10/D-10a in `.planning/phases/09-authentication/09-RESEARCH.md`.
const String kGoogleServerClientId =
    '1076279794226-lfbgqa0td7dtal7ch6s5l6928huo5ij7.apps.googleusercontent.com';

/// Secure-storage key under which the cached Firebase ID token is written
/// by `AuthService.signIn()` for the Phase 11 sync layer.
///
/// Token is stored in Android Keystore via `flutter_secure_storage` — never
/// in SharedPreferences (CLAUDE.md mandate, D-10).
///
/// See D-10 in `.planning/phases/09-authentication/09-RESEARCH.md`.
const String kFirebaseIdTokenKey = 'firebase_id_token';

/// Opacity applied to the Google sign-in button when Firebase is not
/// configured (D-15 degrade path — dev/CI builds without `google-services.json`).
///
/// Material M3 disabled-state opacity is 0.38. The button renders at this
/// opacity and shows the [kCopySignInDisabledTooltip] on long-press.
///
/// See D-15 in `.planning/phases/09-authentication/09-CONTEXT.md`,
/// UI-SPEC §D note.
const double kDisabledSignInOpacity = 0.38;

/// Headline copy for the sign-in bottom sheet (D-08, UI-SPEC §B).
///
/// Displayed at 22 px / w700 (Inter) above the Google sign-in button.
const String kCopySignInSheetHeadline = 'Back up your commutes';

/// Sub-text copy for the sign-in bottom sheet (D-08, UI-SPEC §B).
///
/// Displayed at 16 px / w400 (Inter) below the headline.
const String kCopySignInSheetSubtext =
    'Your trips sync automatically when you sign in.';

/// Settings screen guest-state account row label (D-07, UI-SPEC §B).
///
/// Shown in the Account section when the user is in the guest auth state.
const String kCopySettingsGuestSignIn = 'Sign in to back up';

/// Settings screen signed-in account "Sign out" row label.
///
/// Shown in the Account section only when the user is signed in. Tapping it
/// runs `AuthService.signOut()`, which flips auth state back to guest.
const String kCopySettingsSignOut = 'Sign out';

/// Headline on the post-sign-in confirmation screen (D-12, UI-SPEC §C).
///
/// Displayed at 36 px / w700 (Inter, letter-spacing –1.2) after
/// successful sign-in.
const String kCopyConfirmHeadline = "You're signed in.";

/// Body copy on the post-sign-in confirmation screen (D-12, UI-SPEC §C).
///
/// Displayed at 16 px / w400 (Inter) below the headline.
const String kCopyConfirmBody = 'Your commutes will back up automatically.';

/// CTA label on the post-sign-in confirmation screen (D-12, UI-SPEC §C).
///
/// Button navigates to the main shell.
const String kCopyConfirmCta = "Let's go";

/// Tooltip text shown on the disabled Google sign-in button when Firebase
/// is not configured (D-15, UI-SPEC §D note).
const String kCopySignInDisabledTooltip = 'Sign-in not configured';

/// Headline for the sign-in error state shown in the sheet when
/// `AuthService.signIn()` throws a non-cancel exception (UI-SPEC §E).
const String kCopySignInFailedHeadline = "Couldn't sign in.";

/// Body copy for the sign-in error state (UI-SPEC §E).
const String kCopySignInFailedBody = 'Check your connection and try again.';

// ---------------------------------------------------------------------------
// Phase 11 — Sync Engine (transport, serializer, status, Settings copy)
// ---------------------------------------------------------------------------

/// Base URL for the deployed Phase 10 HTTPS Cloud Functions API.
///
/// D-02: the VERIFIED stable Cloud Functions v2 alias
/// (`us-central1-travey-298a7.cloudfunctions.net/api`) — health 200, 401 auth
/// gate confirmed live. This is the canonical base URL; do NOT use the older
/// `api-rdj4i7kgmq-uc.a.run.app` run.app host. `ApiClient` takes this as an
/// INJECTABLE default so tests/emulator can override the host cheaply.
const String kApiBaseUrl =
    'https://us-central1-travey-298a7.cloudfunctions.net/api';

/// Path for `POST /trips/sync` — batch upsert of pending trips (D-02).
const String kSyncTripsPath = '/trips/sync';

/// Path for `GET /trips/restore` — download all of the caller's trips (D-02).
const String kRestoreTripsPath = '/trips/restore';

/// Path prefix for `DELETE /trips/{tripId}` (D-02). The trip id is appended:
/// `'$kDeleteTripPathPrefix$tripId'`.
const String kDeleteTripPathPrefix = '/trips/';

/// Base delay for exponential sync-retry backoff (D-06). The engine schedules
/// the next retry at `base × 2^retryCount`, capped at [kSyncRetryMaxDelay].
const Duration kSyncRetryBaseDelay = Duration(seconds: 2);

/// Upper bound for a single exponential-backoff delay (D-06). Caps the
/// `base × 2^retryCount` growth so a retry never sleeps longer than this.
const Duration kSyncRetryMaxDelay = Duration(seconds: 60);

/// Maximum number of trips the engine puts into a single `POST /trips/sync`
/// chunk (D-05/D-06). Mirrors the backend zod batch cap. When a drain has
/// more collapsed create/update upserts than this, the engine splits them
/// into successive `syncTrips` calls of at most this many trips each.
const int kMaxSyncBatchTrips = 1000;

/// Settings Account section header (D-09). Reused by Plan 03's signed-in
/// branch so the Phase 11 sync rows live under a stable, non-hardcoded title.
const String kSettingsAccountSectionTitle = 'Account';

/// Settings cloud-sync status row label (D-09).
const String kSettingsCloudSyncRowLabel = 'Cloud sync';

/// Cloud-sync status copy: everything is synced (D-09, SyncSynced/SyncIdle).
const String kSettingsSyncStatusAllSynced = 'All synced';

/// Cloud-sync status copy: a sync is in flight (D-09, SyncSyncing).
const String kSettingsSyncStatusSyncing = 'Syncing…';

/// Cloud-sync status copy suffix: N rows still pending (D-09). The caller
/// builds the full string as `'$n pending'`.
const String kSettingsSyncStatusPendingTemplate = 'pending';

/// Cloud-sync status copy: sync failed, tappable to retry (D-09, SyncFailed).
const String kSettingsSyncStatusFailed = 'Sync failed — tap to retry';

/// Cloud-sync status copy: device is offline (D-09, SyncOffline).
const String kSettingsSyncStatusOffline = 'Offline';

/// Settings restore-from-cloud row label (D-09).
const String kSettingsRestoreRowLabel = 'Restore from cloud';

/// Restore status copy: a restore is in progress (D-09).
const String kSettingsRestoreInProgress = 'Restoring…';

/// Restore status copy prefix: N trips restored (D-09). The caller builds the
/// full string as `'Restored $n trips'`.
const String kSettingsRestoreResultTemplate = 'Restored';

/// Trip noun for the restore-result copy when exactly one trip was restored
/// (D-09). The caller builds `'Restored 1 trip'`.
const String kRestoreTripNounSingular = 'trip';

/// Trip noun for the restore-result copy when more than one trip was restored
/// (D-09). The caller builds `'Restored $n trips'`.
const String kRestoreTripNounPlural = 'trips';

/// Restore status copy: nothing new to restore (D-09).
const String kSettingsRestoreUpToDate = 'Already up to date';

/// Restore status copy: the restore request failed (D-09).
const String kSettingsRestoreError = "Couldn't restore. Try again.";

// ---------------------------------------------------------------------------
// Phase 14: Background GPS platform branch (iOS CoreLocation path)
// ---------------------------------------------------------------------------

/// Purpose-key literal for `Geolocator.requestTemporaryFullAccuracy`.
///
/// **MUST match the `NSLocationTemporaryUsageDescriptionDictionary` key in
/// `ios/Runner/Info.plist` exactly.** If the key differs, iOS will silently
/// ignore the request and the precision-accuracy prompt will never appear.
///
/// See D-06 in `.planning/phases/14-background-gps-platform-branch/14-CONTEXT.md`
/// and RESEARCH §4.
const String kPreciseCommutePurposeKey = 'PreciseCommute';

/// iOS-only distance filter for `AppleSettings.distanceFilter` (meters).
///
/// Set to 0 so that `pauseLocationUpdatesAutomatically: false` and high
/// accuracy drive the sample cadence — a car in stop-and-go traffic (near
/// zero speed) still emits samples. A higher value would silently starve
/// the accumulator when the vehicle barely moves, breaking the IOS-07
/// moving/stuck time guarantee.
///
/// See IOS-07 and RESEARCH §2 in
/// `.planning/phases/14-background-gps-platform-branch/14-RESEARCH.md`.
const int kIosTrackingDistanceFilterMeters = 0;

/// IOS-08: message surfaced when the reduced-accuracy gate blocks a start.
///
/// Shown when `Geolocator.requestTemporaryFullAccuracy` is called but the
/// user declines to grant precise location, so recording is blocked rather
/// than starting with coarse 500-metre fixes that would produce garbage
/// speed stats.
///
/// This is a STABLE, user-facing string — it must NEVER contain raw
/// platform text or GPS coordinates (T-02-07). It is distinct from the
/// generic 'Unable to start tracking' message so the user understands the
/// cause is accuracy, not a generic failure.
///
/// See IOS-08, D-05 in
/// `.planning/phases/14-background-gps-platform-branch/14-CONTEXT.md`.
const String kTrackingReducedAccuracyBlockedMessage =
    'Precise location is required to track your commute. '
    'Enable it in Settings → Privacy → Location Services → Traevy.';

// ---------------------------------------------------------------------------
// Phase 15: Notifications, Permissions & Onboarding UX on iOS
// ---------------------------------------------------------------------------

/// Live Activity App Group identifier. Shared between Runner and the
/// TraevyLiveActivity Widget Extension via the `live_activities` plugin's
/// UserDefaults bridge. Must match the capability configured in Xcode.
///
/// See D-08 in `.planning/phases/15-notifications-permissions-onboarding-ux-on-ios/15-CONTEXT.md`.
const String kLiveActivityAppGroupId = 'group.com.travey.app';

/// URL scheme for Live Activity Stop button deep-links (D-08).
/// A second, short scheme added alongside the Google OAuth redirect scheme.
/// Do NOT reuse the OAuth `com.googleusercontent.apps.*` entry.
const String kLiveActivityUrlScheme = 'traevy';

/// Internal identifier for the single active-commute Live Activity instance.
const String kLiveActivityId = 'commute';

/// iOS permission banner body copy variant for the When-In-Use degraded state
/// (D-03/D-05). Shown on iOS when `TrackingPermissionStatus.foregroundOnly`
/// and the user has not granted Always. Platform-branched at the banner call
/// site — Android uses the existing banner copy.
///
/// See D-05, Surface B in `.planning/phases/15-notifications-permissions-onboarding-ux-on-ios/15-UI-SPEC.md`.
const String kIosPermissionBannerBody =
    'Enable Always to avoid gaps in your trip when the screen is off.';

/// Location priming screen heading (IOS-09, D-01, Surface A).
const String kIosLocationPrimingHeading = 'Your location stays on your device';

/// Location priming screen body copy (Surface A).
const String kIosLocationPrimingBody =
    'Traevy records your route to measure traffic time. All trip data is '
    'stored on your iPhone — never shared without your consent.';

/// Location priming screen primary CTA label (Surface A).
const String kIosLocationPrimingCta = 'Allow location access';

/// Location priming screen skip link label (Surface A).
const String kIosLocationPrimingSkip = 'Skip for now';

/// Location priming screen terms blurb (Surface A).
const String kIosLocationPrimingTerms =
    'You can change location access in Settings at any time.';

/// Location priming FeatureTick 1 title.
const String kIosLocationPrimingTick1Title = 'Route recording';

/// Location priming FeatureTick 1 subtitle.
const String kIosLocationPrimingTick1Subtitle =
    'Captures your GPS path in the background.';

/// Location priming FeatureTick 2 title.
const String kIosLocationPrimingTick2Title = 'Speed-based traffic';

/// Location priming FeatureTick 2 subtitle.
const String kIosLocationPrimingTick2Subtitle =
    'We detect stuck time using speed — no other data.';

/// Location priming FeatureTick 3 title.
const String kIosLocationPrimingTick3Title = 'Device-only storage';

/// Location priming FeatureTick 3 subtitle.
const String kIosLocationPrimingTick3Subtitle =
    'Trips never leave your iPhone unless you sign in.';

/// Enriched Android notification body line 1 template (IOS-14).
/// Replaces the Phase 8 single-line body template for the collapsed view.
/// Tokens: {elapsed}, {km}.
///
/// See D-12 in `.planning/phases/15-notifications-permissions-onboarding-ux-on-ios/15-CONTEXT.md`.
const String kTrackingNotificationBodyLine1Template =
    '● REC  {elapsed} · {km} km';

/// Enriched Android notification body line 2 template (IOS-14).
/// Shown in BigTextStyle expanded notification.
/// Tokens: {moving}, {stuck}.
const String kTrackingNotificationBodyLine2Template =
    'Moving {moving} · Stuck {stuck}';

/// Route name for the iOS-only location priming screen (IOS-09, D-01).
const String kRouteLocationPriming = '/location-priming';

/// Number of days since the oldest recorded trip after which the iOS
/// notification permission request is triggered contextually (IOS-10, D-07).
///
/// The 7-day anchor aligns with the weekly summary cadence — users who have
/// been commuting for a week are the natural audience for scheduled
/// notifications. Never set below 1 day.
const int kNotificationPermissionAnchorDays = 7;
