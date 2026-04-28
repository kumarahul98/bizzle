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
