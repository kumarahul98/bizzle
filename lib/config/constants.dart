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

/// The minimum duration that must elapse before auto-retry triggers
/// (connectivity, resume) will fire `retryFailed()` again.
const Duration kFailedAutoRetryWindow = Duration(hours: 4);

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

/// Banner message shown when sync items are genuinely stuck (Phase 24, UI-SPEC).
const String kSyncStuckBannerMessage = 'Some trips couldn\'t sync';

/// Action label for the stuck-item banner to open Settings (Phase 24, UI-SPEC).
const String kSyncStuckBannerAction = 'Review in Settings';

/// Action label to dismiss the stuck-item banner (Phase 24, UI-SPEC).
const String kSyncStuckBannerDismiss = 'Dismiss';

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
/// **`_v2` suffix (2026-07-21) is deliberate — do not "clean it up".** The
/// original `traevy_active_commute` channel was created at `Importance.low`,
/// which parks the recording notification in the shade's silent section at the
/// bottom. Channel importance is IMMUTABLE on Android once the channel exists,
/// so the only way to raise an already-shipped channel is to publish a new id.
/// Reverting this string would silently restore the low-importance channel for
/// every existing install while looking correct on a fresh one.
///
/// Referenced in TWO places that must never diverge (the D-14 dedup contract):
/// `AndroidConfiguration.notificationChannelId` in `tracking_service.dart`, and
/// the `show()` call in `tracking_notification_service.dart`. Both read THIS
/// constant, so changing the value here updates them together — never hardcode
/// the string in either site.
///
/// See D-14, D-15 in `.planning/phases/02-core-tracking/02-CONTEXT.md`.
const String kTrackingNotificationChannelId = 'traevy_active_commute_v2';

/// The pre-2026-07-21 channel id, kept ONLY so it can be deleted.
///
/// Without an explicit delete, existing installs keep a dead "Active commute"
/// entry in Android's per-app notification settings alongside the new one —
/// two identically named channels, one of which does nothing. Removed in
/// `TrackingNotificationService._createChannels()`.
const String kLegacyTrackingNotificationChannelId = 'traevy_active_commute';

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

/// User-facing label for the active-hero Pause button (Phase 18, D-09). Shown
/// while a trip is running; tapping it suspends recording.
const String kTrackingPauseLabel = 'Pause';

/// User-facing label for the active-hero Resume button (Phase 18, D-09). Shown
/// while a trip is paused; tapping it continues the same trip.
const String kTrackingResumeLabel = 'Resume';

/// Badge text shown on the hero while a trip is paused (Phase 18, D-09). The
/// distinct PAUSED visual state pairs this badge with a dimmed, frozen timer.
const String kTrackingPausedBadgeLabel = 'PAUSED';

/// Break-count indicator text when exactly one break has been taken (Phase 18,
/// D-09). Kept separate from [kTrackingBreakCountPluralTemplate] so the
/// singular/plural choice is data, not a string concatenation in the widget.
const String kTrackingBreakCountSingularLabel = '1 break';

/// Break-count indicator template for two-or-more breaks (Phase 18, D-09).
/// `{n}` is replaced with the break count, e.g. `'2 breaks'`.
const String kTrackingBreakCountPluralTemplate = '{n} breaks';

// --- Phase 18 (Plan 04): opt-in auto-pause prompt (TRACK-10, D-10/11/12) ---

/// Continuous STUCK seconds the active trip must accumulate — uninterrupted by
/// any moving interval — before the app prompts the user to pause (Phase 18,
/// D-10/D-11). Default 15 minutes.
///
/// Detection keys off the accumulator's OWN stuck classification
/// (`prev.speed < kStuckSpeedThresholdMs`), never raw `Position.speed`: any
/// moving interval resets the streak, so stop-and-go micro-movement cannot
/// false-trigger and the core stuck-time metric stays intact (D-11). No second
/// speed threshold is introduced — `AutoPauseDetector` consumes the same
/// classification the accumulator already computes.
const int kAutoPauseStationaryThresholdSeconds = 15 * 60;

/// flutter_local_notifications id for the auto-pause prompt (Phase 18, D-12).
///
/// DISTINCT from [kTrackingNotificationId] (1001 — the ongoing foreground
/// notification) so the prompt is a SEPARATE, dismissible shade entry that
/// never collides with or replaces the recording notification.
const int kAutoPauseNotificationId = 1002;

/// Notification channel for the auto-pause prompt (2026-07-21, D-01).
///
/// SEPARATE from [kTrackingNotificationChannelId] and this is load-bearing, not
/// tidiness. On Android 8+ importance lives on the CHANNEL, and a channel's
/// importance is IMMUTABLE once created. The tracking channel is deliberately
/// `Importance.low` (its ongoing notification refreshes every ~5 s and would
/// buzz constantly otherwise), so the prompt could never be raised to a
/// heads-up while it shared that channel — setting `importance:` on the
/// notification would silently do nothing on every existing install.
const String kAutoPauseChannelId = 'traevy_auto_pause_prompt';

/// User-visible channel name (2026-07-21). Appears in Android's per-app
/// notification settings, so the user can independently silence the prompt
/// without touching the ongoing recording notification.
const String kAutoPauseChannelName = 'Auto-pause prompts';

/// Channel description shown under [kAutoPauseChannelName] in system settings.
const String kAutoPauseChannelDescription =
    'Asks whether to pause when you have been stationary for a while during a '
    'commute.';

/// Action id for the Pause button on the auto-pause prompt (Phase 18, D-12).
/// Both notification response handlers match this exact id (V5 validation,
/// T-18-12) before routing to [kAutoPauseConfirmCommand]; everything else is
/// ignored, so a spoofed/stale action id cannot toggle pause.
const String kTrackingAutoPauseActionId = 'auto_pause';

/// User-facing label for the Pause action button on the auto-pause prompt
/// (Phase 18, D-12). As of 2026-07-21 (D-02) tapping it no longer pauses
/// silently — it opens the app and asks for confirmation, matching the
/// home-screen widget's Pause button.
const String kTrackingAutoPauseActionLabel = 'Pause';

/// Title of the in-app confirmation dialog opened by the prompt's Pause action
/// (2026-07-21, D-03).
const String kAutoPauseConfirmTitle = 'Still stopped?';

/// Body of that dialog. Auto-pause specific rather than the widget's generic
/// wording, because the user needs to know WHY the app is asking.
const String kAutoPauseConfirmBody =
    "You've been stationary for 15 minutes. Pause this trip? Time paused is "
    'excluded from your stats.';

/// Dismiss label — the safe, trip-preserving choice, so it reads as an action
/// rather than "Cancel".
const String kAutoPauseConfirmDismissLabel = 'Keep recording';

/// Confirm label on the auto-pause confirmation dialog.
const String kAutoPauseConfirmAcceptLabel = 'Pause';

/// Title for the auto-pause prompt notification (Phase 18, D-12).
const String kAutoPauseNotificationTitle = "You've been stopped a while";

/// Body for the auto-pause prompt notification (Phase 18, D-12). Plain copy —
/// the user taps Pause to suspend recording, or ignores it to keep recording.
const String kAutoPauseNotificationBody =
    'Pause this commute? Time stopped here will be excluded from your stats.';

/// SettingsRow title for the opt-in auto-pause toggle (Phase 18, D-10).
const String kSettingsAutoPauseLabel = 'Auto-pause when stationary';

/// SettingsRow subtitle copy when auto-pause is enabled (Phase 18, D-10).
const String kSettingsAutoPauseOnSubtitle = 'ON';

/// SettingsRow subtitle copy when auto-pause is disabled (Phase 18, D-10).
const String kSettingsAutoPauseOffSubtitle = 'OFF';

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

/// Minimum segment length (meters) a `TripAccumulator.addSample` distance
/// delta must clear before it is added to the running distance total.
/// Below this floor, the delta is GPS noise rather than real movement — a
/// stationary device still emits fixes that drift by roughly 0.79 m per
/// sample at `kTrackingSampleInterval` (3 s), which silently accumulates
/// into hundreds of meters over a long stationary period. This floor
/// applies ONLY to the distance total; it does not affect the polyline
/// (every sample is still recorded) or moving/stuck time attribution.
///
/// See `.planning/phases/27-ux-tour-tracking-accuracy/27-PLAN.md`.
const double kTrackingMinMoveMeters = 5.0;

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

/// Minimum gap between successive home-screen-widget refreshes. Mirrors
/// [kTrackingNotificationRefreshInterval]: the 1 Hz uiTimer would otherwise
/// fire two `HomeWidget.saveWidgetData` writes plus an `updateWidget`
/// RemoteViews rebuild every second (~2700 broadcasts on a 45-min trip).
const Duration kTrackingWidgetRefreshInterval = Duration(seconds: 5);

/// Home-screen widget (WIDGET-01) — shared identifiers for the native
/// `CommuteWidgetProvider` and the SharedPreferences keys it reads in
/// `onUpdate`. Centralized so the background-isolate writes
/// (`tracking_service.dart`) and the app-launch reconciliation
/// (`widget_state_writer.dart`) never drift on a magic string.
const String kWidgetProviderName = 'CommuteWidgetProvider';
const String kWidgetKeyTitle = 'widget_title';
const String kWidgetKeyShowStats = 'widget_show_stats';
const String kWidgetKeyDistance = 'widget_distance';
const String kWidgetKeyDuration = 'widget_duration';
const String kWidgetTitleIdle = 'Start Commute';
const String kWidgetTitleActive = 'Stop Commute';

/// Phase 28 — richer widget content for the larger (full-width) layout.
///
/// Values are PRE-FORMATTED display strings written from Dart; the native
/// `CommuteWidgetProvider` never computes. Unknown values are written as
/// [kWidgetValueUnknown] (never blank) so the layout can't collapse.
///
/// Active-state keys ride the existing 5 s throttled write in
/// `tracking_service.dart`; idle-state keys are pushed from the MAIN isolate
/// (Drift lives there) on launch, app-resume, and post-trip-save.
const String kWidgetKeySpeed = 'widget_speed';
const String kWidgetKeyMoving = 'widget_moving';
const String kWidgetKeyStuck = 'widget_stuck';
const String kWidgetKeyPaused = 'widget_paused';
const String kWidgetKeyTodayTrips = 'widget_today_trips';
const String kWidgetKeyTodayTraffic = 'widget_today_traffic';
const String kWidgetKeyWeekTotal = 'widget_week_total';
const String kWidgetKeyWeekStuck = 'widget_week_stuck';

/// Placeholder written whenever a widget value is unknown/unavailable.
const String kWidgetValueUnknown = '--';

/// Minimum gap between successive active-trip state persists (Phase 25
/// interrupted-trip recovery). `TripAccumulator` snapshots its FULL state —
/// including the growing sample list — to disk, so per-sample (~3 s) writes
/// make total bytes written grow quadratically with trip length. Pause/resume
/// transitions bypass the throttle so a recovered trip never resurrects a
/// stale paused/running flag; the worst case is losing the last few seconds
/// of samples on force-kill, which recovery tolerates.
const Duration kTripStatePersistMinInterval = Duration(seconds: 10);

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
// ---------------------------------------------------------------------------
// Phase 17 — Tracking UI fixes & quick direction label (TRACK-12)
// ---------------------------------------------------------------------------

/// Display label for the to-office segment of the [DirectionSegmentedToggle]
/// quick direction selector (TRACK-12, D-04). Mirrors the wording used by the
/// edit-trip sheet's SegmentedButton so the two surfaces read identically.
const String kDirectionToOfficeLabel = 'To office';

/// Display label for the to-home segment of the [DirectionSegmentedToggle]
/// quick direction selector (TRACK-12, D-04).
const String kDirectionToHomeLabel = 'To home';

// ---------------------------------------------------------------------------
// Phase 9 — Authentication (Firebase Auth + Google Sign-In) continued
// ---------------------------------------------------------------------------

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

/// Tooltip / semantics label for the guest "not connected" indicator on the
/// dashboard header (Phase 20, AUTH-04, SC#3, D-06).
///
/// The indicator is a passive `cloud_off` IconButton shown ONLY in guest
/// mode; tapping it opens the sign-in sheet. The copy is calm (states the
/// fact + the remedy) and non-nagging — there is no auto-shown snackbar.
const String kCopyGuestNotConnectedTooltip =
    'Not connected — sign in to back up';

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

/// Skip action label on the first-run [LoginScreen] (Phase 20, D-04/D-05).
///
/// Tapping it sets `has_seen_onboarding = true` and lets the root gate route
/// the guest straight into the app without signing in.
const String kCopyLoginSkip = 'Skip — use without an account';

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

/// Path for `POST /preferences/sync` — upsert the caller's saved Home/Office
/// locations (Phase 29, LOC-03).
const String kSyncPreferencesPath = '/preferences/sync';

/// Path for `GET /preferences/restore` — download the caller's saved
/// Home/Office locations (Phase 29, LOC-03).
const String kRestorePreferencesPath = '/preferences/restore';

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

// Phase 19 — Full Trip Editing (TRACK-11)
//
// Validation messages (D-08): surfaced inline by the Plan 02 edit sheet
// when `TripEditRecompute.validate` rejects an edit. The service maps each
// failing rule to one of these constants — never to hardcoded English — so
// the copy lives in one place and the service stays UI-agnostic.

/// Shown when the edited end time is at or before the edited start time.
const String kEditValidationEndBeforeStart =
    'End time must be after start time.';

/// Shown when a break falls outside the (edited) trip window (D-05).
const String kEditValidationBreakOutsideWindow =
    'A break falls outside the trip times.';

/// Shown when a break's end is at or before its start (D-06).
const String kEditValidationBreakZeroLength =
    'A break must end after it starts.';

/// Shown when two breaks overlap OR merely touch (D-07).
const String kEditValidationBreakOverlap =
    'Breaks cannot overlap or touch — merge them into one.';

/// Snackbar shown after a save where breaks were clamped/dropped to fit the
/// new, shorter trip window (D-10).
const String kEditBreaksAdjustedSnackbar =
    'Some breaks were adjusted to fit the new trip times.';

/// Inline label on moving/stuck figures of an edited trip (D-04). Edited
/// traffic stats are derived via proportional rescale, not measured.
const String kEditEstimatedHintLabel = '~ estimated';

/// Tooltip expanding on [kEditEstimatedHintLabel].
const String kEditEstimatedHintTooltip =
    'These figures were re-estimated after you edited the trip, not measured '
    'from GPS.';

/// Section header for the breaks list in the Plan 02 edit sheet.
const String kEditBreaksSectionLabel = 'Breaks';

/// Add-break action label in the Plan 02 edit sheet.
const String kEditAddBreakLabel = 'Add break';

/// Start date/time field label in the Plan 02 edit sheet.
const String kEditStartDateTimeLabel = 'Start';

/// End date/time field label in the Plan 02 edit sheet.
const String kEditEndDateTimeLabel = 'End';

// ---------------------------------------------------------------------------
// Phase 21 — Home & Office Locations + Geofence Auto-Label (LOC-01, LOC-02)
// ---------------------------------------------------------------------------

/// Confident-match radius (meters) for the geofence direction resolver (D-05).
///
/// The trip's END coordinate must lie strictly within this distance of a saved
/// Home/Office anchor (`Geolocator.distanceBetween(...) < kGeofenceRadiusMeters`)
/// to label the trip by that anchor. A point exactly at the radius is OUTSIDE
/// (D-06). 250 m balances GPS endpoint jitter and parking-lot drift against the
/// risk of a Home and Office that sit close together overlapping.
const double kGeofenceRadiusMeters = 250;

/// `trips.direction_source` literal: the user explicitly set this direction
/// (Phase 17 quick toggle or the Phase 19 edit sheet) — D-02/D-03.
///
/// This is the durable "who set this" record. A manual choice is
/// authoritative: the Plan 03 backfill re-labels ONLY rows whose source is NOT
/// this value, so a user's pick is never clobbered (SC#4).
const String kDirectionSourceManual = 'manual';

/// `trips.direction_source` literal: the direction was derived from the
/// geofence resolver at finalize (END coord matched a saved anchor) — D-02/D-10.
const String kDirectionSourceGeofence = 'geofence';

/// `trips.direction_source` literal: the direction fell back to the time-of-day
/// heuristic (no manual override and no confident geofence match) — D-02/D-09.
///
/// This is the DB default for `trips.direction_source`, so every pre-Phase-21
/// row reads `time` after the additive v6 migration — they were all
/// time-labeled (SC#5).
const String kDirectionSourceTime = 'time';

// --- LOC-01 location picker (Plan 02) -------------------------------------

/// Subtitle shown on a Home/Office settings row when no coordinate is saved
/// yet (D-13: a never-set slot reads "Not set", never Null Island).
const String kCopyLocationNotSet = 'Not set';

/// Label for the Home location settings row (LOC-01).
const String kSettingsHomeLocationLabel = 'Home location';

/// Label for the Office location settings row (LOC-01).
const String kSettingsOfficeLocationLabel = 'Office location';

/// Title of the "Commute" settings section that groups the Home/Office rows.
const String kSettingsLocationsSectionTitle = 'Commute';

/// App-bar / confirm-button copy for the Home picker (LOC-01).
const String kLocationPickerHomeTitle = 'Set home';

/// App-bar / confirm-button copy for the Office picker (LOC-01).
const String kLocationPickerOfficeTitle = 'Set office';

/// Confirm-button label for the Home picker.
const String kLocationPickerSetHomeButton = 'Set home here';

/// Confirm-button label for the Office picker.
const String kLocationPickerSetOfficeButton = 'Set office here';

/// SnackBar copy shown after a Home location is saved.
const String kLocationPickerHomeSavedSnack = 'Home location saved';

/// SnackBar copy shown after an Office location is saved.
const String kLocationPickerOfficeSavedSnack = 'Office location saved';

/// Default map-camera latitude when no saved coord, no device location, and no
/// recent trip exist (D-13: a sane non-(0,0) start, NOT Null Island). Centred
/// on Bengaluru, India — the project's primary locale.
const double kMapDefaultCenterLat = 12.9716;

/// Default map-camera longitude (see [kMapDefaultCenterLat]).
const double kMapDefaultCenterLng = 77.5946;

/// Initial zoom level for the location picker map (street-level so the user can
/// place the crosshair precisely).
const double kLocationPickerInitialZoom = 15;

/// Size (logical pixels) of the fixed centre crosshair icon on the picker.
const double kLocationPickerCrosshairSize = 40;

// ---------------------------------------------------------------------------
// Phase 24 — Automatic Cloud Sync & Restore
// ---------------------------------------------------------------------------

/// Auto-restore in-progress message
const String kAutoRestoreInProgress = 'Restoring your trips…';

/// Auto-restore error message
const String kAutoRestoreError =
    'Could not restore — tap Restore in Settings to retry';

/// Auto-restore success message template
const String kAutoRestoreResultTemplate = 'Restored {n} trips';

/// Auto-restore up-to-date message
const String kAutoRestoreUpToDate = kSettingsRestoreUpToDate;

// ---------------------------------------------------------------------------
// Phase 24 — Automatic Cloud Sync & Restore
// ---------------------------------------------------------------------------

const String kConflictResolutionTitle = 'Resolve Sync Conflicts';
const String kConflictKeepLocal = 'Keep local';
const String kConflictUseCloud = 'Use cloud';
const String kConflictMerge = 'Merge';

// ---------------------------------------------------------------------------
// Phase 25: Interrupted-Trip Recovery
// ---------------------------------------------------------------------------

/// Title for the interrupted-trip recovery prompt dialog.
const String kRecoveryDialogTitle = 'Interrupted Commute';

/// Body text for the interrupted-trip recovery prompt dialog.
const String kRecoveryDialogBody =
    'Traevy stopped unexpectedly during your last commute. '
    'Do you want to resume recording or discard it?';

/// Action label for resuming the interrupted trip.
const String kRecoveryResumeAction = 'Resume';

/// Action label for discarding the interrupted trip.
const String kRecoveryDiscardAction = 'Discard';

// ---------------------------------------------------------------------------
// Phase 26 — Sync Breaks & Edit Metadata to Cloud
// ---------------------------------------------------------------------------

/// Maximum number of break segments embedded in a single trip's sync
/// payload. Must numerically match the backend's `kMaxBreaksPerTrip` DoS cap
/// in `backend/functions/src/utils/validation.ts` — a payload with more
/// breaks than this is rejected server-side (400). ALSO enforced
/// client-side at serialization time: `TripSerializer.toJson` (Plan 03)
/// truncates to this cap, oldest-first, so sync never emits a payload the
/// backend would reject.
const int kMaxBreaksPerTrip = 50;

/// Target backfill schema version (Phase 26, D-03): "backfill done for
/// payload schema v2". Compared against
/// `UserPreferencesDao.getBackfillMarkerVersion()` — when the stored marker
/// is less than this value, the one-time re-sync for trips with breaks or
/// edits has not yet run for the current payload shape and should trigger.
const int kBackfillMarkerVersion = 2;

/// D-05 read-only conflict-sheet indicator shown only when the local and
/// cloud break counts differ for a trip. `{local}`/`{cloud}` are replaced
/// via `.replaceAll`, mirroring [kAutoRestoreResultTemplate]'s `{n}`
/// placeholder convention.
const String kConflictBreaksDifferTemplate =
    'Local: {local} breaks · Cloud: {cloud} breaks';

// ---------------------------------------------------------------------------
// Phase 27 — Per-page guided tour (UX-07)
// ---------------------------------------------------------------------------
//
// The first time a MainShell tab becomes visible, a lightweight coach-mark
// tour spotlights 2 key elements with a Skip button, then never shows again
// for that page. Persistence is the `seen_tours` CSV on user_preferences
// (Phase 27 Concern 2 scaffold): each page key below is appended once the
// page's tour is finished OR skipped (skip marks THIS page seen only).

/// `seen_tours` CSV token identifying the Dashboard (Today) tab's tour.
const String kTourKeyDashboard = 'dashboard';

/// `seen_tours` CSV token identifying the History (Trips) tab's tour.
const String kTourKeyTrips = 'trips';

/// `seen_tours` CSV token identifying the Stats tab's tour.
const String kTourKeyStats = 'stats';

/// `seen_tours` CSV token identifying the Settings tab's tour.
const String kTourKeySettings = 'settings';

/// Coach-mark button label to skip (and permanently dismiss) the current
/// page's tour. Skip marks only THIS page's tour seen (D: per-page skip).
const String kTourSkipLabel = 'Skip';

/// Coach-mark button label advancing to the next step within a page's tour.
const String kTourNextLabel = 'Next';

/// Coach-mark button label on the final step of a page's tour — dismisses it.
const String kTourDoneLabel = 'Got it';

/// Coach-mark step counter template. `{current}`/`{total}` are replaced via
/// `.replaceAll`, mirroring [kAutoRestoreResultTemplate]'s `{n}` convention.
const String kTourStepCounterTemplate = '{current} of {total}';

// --- Dashboard (Today) tour copy ------------------------------------------

/// Dashboard step 1 title — the START / record hero.
const String kTourDashboardRecordTitle = 'Record your commute';

/// Dashboard step 1 body — the START / record hero.
const String kTourDashboardRecordBody =
    'Tap START to track a trip. Traevy captures your route and the time you '
    'spend stuck in traffic automatically.';

/// Dashboard step 2 title — today's summary.
const String kTourDashboardTodayTitle = 'Today at a glance';

/// Dashboard step 2 body — today's summary.
const String kTourDashboardTodayBody =
    'Your commutes for today show up here, each with its time, distance and '
    'traffic breakdown.';

// --- History (Trips) tour copy --------------------------------------------

/// History step 1 title — the list / calendar view toggle.
const String kTourTripsViewTitle = 'List or calendar';

/// History step 1 body — the list / calendar view toggle.
const String kTourTripsViewBody =
    'Switch between a running list of your trips and a calendar to browse '
    'them by day.';

/// History step 2 title — the add-trip button.
const String kTourTripsAddTitle = 'Add a trip by hand';

/// History step 2 body — the add-trip button.
const String kTourTripsAddBody =
    'Forgot to hit record? Tap here to enter a commute manually — then open '
    'any trip to view or edit it.';

// --- Stats tour copy -------------------------------------------------------

/// Stats step 1 title — the traffic-loss hero.
const String kTourStatsTrafficTitle = 'Time lost to traffic';

/// Stats step 1 body — the traffic-loss hero.
const String kTourStatsTrafficBody =
    'See how much of your week disappeared while you were stuck in traffic.';

/// Stats step 2 title — the moving-vs-stuck breakdown chart.
const String kTourStatsBreakdownTitle = 'Your traffic breakdown';

/// Stats step 2 body — the moving-vs-stuck breakdown chart.
const String kTourStatsBreakdownBody =
    'This chart splits your commute into time moving versus time stuck, so '
    'you can see the balance at a glance.';

// --- Settings tour copy ----------------------------------------------------

/// Settings step 1 title — the auto-pause toggle.
const String kTourSettingsAutoPauseTitle = 'Auto-pause when stopped';

/// Settings step 1 body — the auto-pause toggle.
const String kTourSettingsAutoPauseBody =
    "When you've been stationary a while, Traevy can pause recording so long "
    "stops never inflate your trip. It's on by default.";

/// Settings step 2 title — the Home / Office location rows.
const String kTourSettingsLocationsTitle = 'Set home & office';

/// Settings step 2 body — the Home / Office location rows.
const String kTourSettingsLocationsBody =
    'Save your home and office and Traevy labels each trip by direction '
    'automatically — to office or to home.';
