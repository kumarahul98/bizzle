import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Five-way classification of the device's tracking permission state as
/// it relates to Phase 2 tracking requirements.
///
/// Mapped from Phase 2 context decisions D-07 (two-step location flow),
/// D-08 (background-denied banner), D-09 (permanent-deny "open settings"
/// CTA), and UX-03 (persistent foreground notification while recording).
/// Consumers — the home screen pre-flight (plan 02-04) and the
/// service-isolate starter (plan 02-03) — switch on this enum to decide
/// whether Start is enabled, whether to show the limitation banner, and
/// whether to deep-link into system settings.
///
/// The four original variants keep their original semantics — they
/// describe LOCATION state only. The fifth variant, [notificationDenied],
/// is a strict superset-addition introduced by the gap-closure plan
/// 02-1: it means "location is resolved well enough to start tracking,
/// but POST_NOTIFICATIONS is denied" — which on Android 13+ silently
/// blocks the UX-03 foreground notification. Start MUST be disabled in
/// this state.
enum TrackingPermissionStatus {
  /// Fine + background location both granted, AND POST_NOTIFICATIONS
  /// granted. Full feature set; no banner.
  fullyGranted,

  /// Fine granted, background denied. POST_NOTIFICATIONS granted.
  /// Tracking works only while the app is foregrounded. UI must show
  /// the D-08 dismissible banner.
  foregroundOnly,

  /// Fine denied (first-time or after a soft "Deny"). Start button
  /// disabled. UI must show the "Grant location" CTA.
  denied,

  /// Fine permanently denied ("Deny & don't ask again" or Android 12
  /// auto-lock). UI must show the D-09 "Open settings" CTA.
  permanentlyDenied,

  /// Fine + background (or fine-only) location are resolved, but the
  /// POST_NOTIFICATIONS runtime permission is denied. Required for
  /// UX-03 (persistent notification while GPS tracking is active). On
  /// Android 13+ (minSdk 34 for this app, so every device) the system
  /// silently drops every notification posted by
  /// `flutter_local_notifications` until this permission is granted —
  /// `numEnqueuedByApp` increases but `numPostedByApp` stays at 0. The
  /// UI must show the "Grant notifications" CTA with an Open-settings
  /// deep-link, and Start must be disabled until the user grants it.
  notificationDenied,
}

/// Reads a [Permission]'s current status without prompting the user.
///
/// Injection seam so unit tests can drive [TrackingPermissionService]
/// without touching the real plugin. Production default wraps
/// `Permission.status` from `permission_handler`.
typedef PermissionStatusProbe =
    Future<PermissionStatus> Function(
      Permission permission,
    );

/// Prompts the user for a [Permission] and returns the resolved status.
///
/// Injection seam so unit tests can drive [TrackingPermissionService]
/// without touching the real plugin. Production default wraps
/// `Permission.request()` from `permission_handler`.
typedef PermissionRequester =
    Future<PermissionStatus> Function(
      Permission permission,
    );

/// Opens the system's app-settings page. Injection seam so unit tests can
/// observe [TrackingPermissionService.openSystemSettings] without touching
/// the platform channel. Production default is the top-level
/// [openAppSettings] from `permission_handler`.
typedef SettingsOpener = Future<bool> Function();

/// Wraps `permission_handler` for Phase 2's strict four-step tracking
/// permission dance (D-07 / RESEARCH Pitfall 5 + UX-03 gap-closure).
///
/// Instances are stateless — safe to share via a Riverpod `Provider`.
///
/// The public contract is:
///
///   * [preflight] — run the ordered four-step request
///     (`locationWhenInUse` → `locationAlways` → `notification`) and
///     return the resolved status. Callers MUST await this before
///     starting the foreground service.
///   * [currentStatus] — classify the current state WITHOUT prompting.
///     Used on first build to decide whether Start is enabled.
///   * [openSystemSettings] — deep-link into the system app-settings page
///     for this app. Used by the [TrackingPermissionStatus.permanentlyDenied]
///     CTA (D-09) and by the [TrackingPermissionStatus.notificationDenied]
///     UX-03 CTA.
///
/// Ordering invariants:
///
///   1. `locationAlways` is NEVER probed or requested until
///      `locationWhenInUse` has resolved granted (RESEARCH Pitfall 5).
///   2. `notification` is NEVER probed or requested until the location
///      dance has resolved to either `fullyGranted` or `foregroundOnly`.
///      If fine location is denied or permanently denied, the flow
///      short-circuits WITHOUT touching `notification`, so the user is
///      never asked for notifications before they have agreed to share
///      location.
///
/// Both invariants are enforced by [preflight] and asserted in the unit
/// tests.
class TrackingPermissionService {
  /// Production constructor — wires the real `permission_handler` APIs.
  ///
  /// `const` because every field is a compile-time-constant function
  /// reference (static tear-off or top-level function), so callers can use
  /// `const TrackingPermissionService()` in provider graphs.
  const TrackingPermissionService()
    : _probe = _defaultProbe,
      _request = _defaultRequest,
      _openSettings = openAppSettings;

  /// Test-only constructor. Accepts closures so unit tests can inject
  /// deterministic permission states without implementing an interface.
  @visibleForTesting
  TrackingPermissionService.forTesting({
    required PermissionStatusProbe probe,
    required PermissionRequester requester,
    SettingsOpener? opener,
  }) : _probe = probe,
       _request = requester,
       _openSettings = opener ?? openAppSettings;

  final PermissionStatusProbe _probe;
  final PermissionRequester _request;
  final SettingsOpener _openSettings;

  /// Runs the four-step permission dance and returns the resolved
  /// [TrackingPermissionStatus].
  ///
  /// Step order (strictly enforced):
  ///
  ///   1. Probe / request `locationWhenInUse`. Short-circuits to
  ///      [TrackingPermissionStatus.permanentlyDenied] or
  ///      [TrackingPermissionStatus.denied] WITHOUT touching
  ///      `locationAlways` or `notification` if fine is not granted.
  ///   2. Probe / request `locationAlways`. Never touched before fine
  ///      has resolved granted (RESEARCH Pitfall 5).
  ///   3. Probe / request `notification` (UX-03 gap-closure). Never
  ///      touched until the location dance has resolved; required on
  ///      Android 13+ for the UX-03 foreground notification to be
  ///      visible at all. If denied, returns
  ///      [TrackingPermissionStatus.notificationDenied].
  ///
  /// Short-circuit cases that return WITHOUT touching `locationAlways`
  /// or `notification`:
  ///
  ///   a. Fine is already permanently denied on initial probe.
  ///   b. Fine request resolves permanently denied.
  ///   c. Fine request resolves denied (non-permanent).
  ///
  /// If fine is already granted, step 2 still runs from its current
  /// probe. Step 3 runs whenever the location dance resolves to either
  /// [TrackingPermissionStatus.fullyGranted] or
  /// [TrackingPermissionStatus.foregroundOnly].
  Future<TrackingPermissionStatus> preflight() async {
    final fineStatus = await _probe(Permission.locationWhenInUse);
    if (fineStatus.isPermanentlyDenied) {
      return TrackingPermissionStatus.permanentlyDenied;
    }
    var fineGranted = fineStatus.isGranted;
    if (!fineGranted) {
      final requested = await _request(Permission.locationWhenInUse);
      if (requested.isPermanentlyDenied) {
        return TrackingPermissionStatus.permanentlyDenied;
      }
      if (!requested.isGranted) {
        return TrackingPermissionStatus.denied;
      }
      fineGranted = true;
    }
    // Strict ordering guard: locationAlways is only touched once
    // locationWhenInUse has fully resolved granted (Pitfall 5).
    assert(
      fineGranted,
      'locationAlways must never be touched before locationWhenInUse '
      'resolves granted.',
    );
    final bgStatus = await _probe(Permission.locationAlways);
    var backgroundGranted = bgStatus.isGranted;
    if (!backgroundGranted) {
      final bgRequested = await _request(Permission.locationAlways);
      backgroundGranted = bgRequested.isGranted;
    }
    // D-06: On iOS, tracking depends only on location. The notification
    // permission dance is Android-only (UX-03 requires POST_NOTIFICATIONS on
    // Android 13+, but iOS never gates tracking on notification permission).
    // Return here without touching Permission.notification so the iOS
    // Start button is never permanently disabled by a denied notification.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return backgroundGranted
          ? TrackingPermissionStatus.fullyGranted
          : TrackingPermissionStatus.foregroundOnly;
    }
    // UX-03: notifications are a hard requirement. Fine+background (or
    // fine-only) resolved means location is OK; we still must ensure
    // POST_NOTIFICATIONS so the foreground notification (D-14) is
    // actually visible on Android 13+. Ordering guard: we only reach
    // this point after the entire location dance has resolved — the
    // user is never asked for notifications before location.
    final notifStatus = await _probe(Permission.notification);
    if (!notifStatus.isGranted) {
      final notifRequested = await _request(Permission.notification);
      if (!notifRequested.isGranted) {
        return TrackingPermissionStatus.notificationDenied;
      }
    }
    return backgroundGranted
        ? TrackingPermissionStatus.fullyGranted
        : TrackingPermissionStatus.foregroundOnly;
  }

  /// Returns the current [TrackingPermissionStatus] without prompting the
  /// user. Used by the home screen to decide whether Start is enabled on
  /// first build.
  ///
  /// Only calls the probe — never the requester — so it is safe to invoke
  /// in build-time code paths without risking a permission dialog. This
  /// is a hard invariant: even when `notification` is denied, this method
  /// returns [TrackingPermissionStatus.notificationDenied] based on the
  /// probe alone and does NOT trigger a system prompt.
  ///
  /// Mirrors [preflight]'s ordering: location is classified first, and
  /// the notification probe only runs when the location state is either
  /// [TrackingPermissionStatus.fullyGranted] or
  /// [TrackingPermissionStatus.foregroundOnly].
  Future<TrackingPermissionStatus> currentStatus() async {
    final fineStatus = await _probe(Permission.locationWhenInUse);
    if (fineStatus.isPermanentlyDenied) {
      return TrackingPermissionStatus.permanentlyDenied;
    }
    if (!fineStatus.isGranted) {
      return TrackingPermissionStatus.denied;
    }
    final bgStatus = await _probe(Permission.locationAlways);
    final locationStatus = bgStatus.isGranted
        ? TrackingPermissionStatus.fullyGranted
        : TrackingPermissionStatus.foregroundOnly;
    // D-06: iOS resolves on location alone — never probe notification.
    // On iOS, returning here means notificationDenied is never reachable,
    // so the Start button cannot be permanently disabled by a notification
    // permission state (RESEARCH Pitfall 5).
    if (defaultTargetPlatform == TargetPlatform.iOS) return locationStatus;
    // UX-03: location is OK; now classify notifications. Probe-only —
    // never call the requester from currentStatus (build-time safety).
    final notifStatus = await _probe(Permission.notification);
    if (!notifStatus.isGranted) {
      return TrackingPermissionStatus.notificationDenied;
    }
    return locationStatus;
  }

  /// Deep-links into the system app-settings page for this app (D-09).
  ///
  /// Returns `true` if the settings screen was shown, `false` otherwise
  /// (e.g. the OS denied the launch). Wraps `openAppSettings()` from
  /// `permission_handler` in production; test instances can inject a
  /// [SettingsOpener] fake.
  Future<bool> openSystemSettings() => _openSettings();

  static Future<PermissionStatus> _defaultProbe(Permission permission) =>
      permission.status;

  static Future<PermissionStatus> _defaultRequest(Permission permission) =>
      permission.request();
}
