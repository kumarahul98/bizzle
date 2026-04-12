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
