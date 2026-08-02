import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/config/constants.dart';

/// Four-way classification of the device's tracking permission state as
/// it relates to Phase 2 tracking requirements.
///
/// Mapped from Phase 2 context decisions D-09 (permanent-deny "open
/// settings" CTA) and UX-03 (persistent foreground notification while
/// recording). Since quick-260802-itr, this is a `locationWhenInUse` +
/// `notification` classification only — the app never requests
/// `Permission.locationAlways` (see the class dartdoc). Consumers — the
/// home screen pre-flight (plan 02-04) and the service-isolate starter
/// (plan 02-03) — switch on this enum to decide whether Start is enabled
/// and whether to deep-link into system settings.
enum TrackingPermissionStatus {
  /// `locationWhenInUse` granted AND `notification` granted. Full feature
  /// set; no banner. Background GPS is covered entirely by the
  /// location-typed foreground service, not by a background-location
  /// permission.
  fullyGranted,

  /// Fine denied (first-time or after a soft "Deny"). Start button
  /// disabled. UI must show the "Grant location" CTA.
  denied,

  /// Fine permanently denied ("Deny & don't ask again" or Android 12
  /// auto-lock). UI must show the D-09 "Open settings" CTA.
  permanentlyDenied,

  /// `locationWhenInUse` is resolved granted, but the POST_NOTIFICATIONS
  /// runtime permission is denied. Required for UX-03 (persistent
  /// notification while GPS tracking is active). On Android 13+ (minSdk
  /// 34 for this app, so every device) the system silently drops every
  /// notification posted by `flutter_local_notifications` until this
  /// permission is granted — `numEnqueuedByApp` increases but
  /// `numPostedByApp` stays at 0. The UI must show the "Grant
  /// notifications" CTA with an Open-settings deep-link, and Start must
  /// be disabled until the user grants it.
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

/// Three-way outcome of [TrackingPermissionService.requestWhenInUse].
///
/// Deliberately NOT [TrackingPermissionStatus]: that enum's granted variant
/// encodes notification state too — `fullyGranted` means `locationWhenInUse`
/// AND `notification` are both granted, and `notificationDenied` is only
/// meaningful after the full [TrackingPermissionService.preflight] dance. A
/// when-in-use-only caller has exactly three outcomes and must not be
/// handed an enum whose variants it can neither produce nor honestly
/// interpret. CLAUDE.md requires an enum (never a bool/String) for finite
/// state, so this is a new 3-way enum rather than a nullable bool.
enum LocationWhenInUseStatus {
  /// `Permission.locationWhenInUse` is granted (already, or just now).
  granted,

  /// `Permission.locationWhenInUse` was denied (soft — the user can be
  /// asked again).
  denied,

  /// `Permission.locationWhenInUse` is permanently denied ("Deny & don't
  /// ask again" or an OS auto-lock). Only a deep-link to system settings
  /// can recover from this state.
  permanentlyDenied,
}

/// Opens the system settings page where this app's permissions live.
/// Injection seam so unit tests can observe
/// [TrackingPermissionService.openSystemSettings] without touching the
/// platform channel. Production default is [openAppPermissionSettings].
typedef SettingsOpener = Future<bool> Function();

/// The platform channel used to reach [kOpenAppPermissionsMethod].
///
/// Package-visible so tests can install a mock handler on the same channel
/// the production opener talks to.
@visibleForTesting
const MethodChannel platformChannel = MethodChannel(kPlatformChannelName);

/// Open this app's PERMISSION LIST in system settings (Phase 36, D-03).
///
/// Routes through [platformChannel] to `MainActivity.openAppPermissions()`,
/// which fires `Settings.ACTION_APP_PERMISSIONS` and — mandatorily (T-36-01) —
/// falls back to `ACTION_APPLICATION_DETAILS_SETTINGS` if that does not resolve
/// on the device's OEM skin.
///
/// This replaces a direct call to `openAppSettings()` from
/// `permission_handler`, which lands on **App Info**: one level short of the
/// page the "Open settings" CTA claims to open, leaving the user to hunt for
/// "Permissions" themselves.
///
/// `openAppSettings()` survives as the fallback for the two cases where the
/// channel cannot answer — iOS (no `MainActivity`) and any test host without a
/// registered handler, both of which raise [MissingPluginException]. On iOS
/// that call opens the app's settings page, where permissions live anyway, so
/// the fallback is the correct destination there rather than a degraded one.
///
/// Returns `true` if a settings screen was shown.
Future<bool> openAppPermissionSettings() async {
  try {
    final shown = await platformChannel.invokeMethod<bool>(
      kOpenAppPermissionsMethod,
    );
    return shown ?? false;
  } on MissingPluginException {
    return openAppSettings();
  } on PlatformException {
    return openAppSettings();
  }
}

/// Wraps `permission_handler` for Phase 2's tracking permission dance, now a
/// two-step `locationWhenInUse` → `notification` flow (D-07, revised by
/// quick-260802-itr / UX-03 gap-closure). Since quick-260802-dgp, the class
/// is also the app's single permission entry point for non-tracking callers
/// that need a narrow when-in-use-only request (the location picker) — see
/// [requestWhenInUse].
///
/// **`Permission.locationAlways` is NEVER touched by this class**, on
/// either platform. Background GPS during tracking is covered entirely by
/// the app's location-typed foreground service
/// (`android:foregroundServiceType="location"`, started only while the app
/// is in the foreground when the user taps Start): Android 10+ keeps
/// delivering location updates to a running foreground service with only
/// `ACCESS_FINE_LOCATION` granted "while using the app". Requesting
/// `locationAlways` would additionally trigger the Google Play
/// background-location declaration requirement (a separate, strictly
/// reviewed listing step with a mandatory demo video) for a permission the
/// app does not need. See the source-manifest regression guard in
/// `test/unit/android_manifest_permissions_test.dart` and the
/// `locationAlways`-never-touched guard in this class's own test file.
///
/// Instances are stateless — safe to share via a Riverpod `Provider`.
///
/// The public contract is:
///
///   * [preflight] — run the ordered two-step request
///     (`locationWhenInUse` → `notification`) and return the resolved
///     status. Callers MUST await this before starting the foreground
///     service.
///   * [currentStatus] — classify the current state WITHOUT prompting.
///     Used on first build to decide whether Start is enabled.
///   * [requestWhenInUse] — the narrow when-in-use-only request used by
///     non-tracking callers that need to centre a map and have no business
///     asking for notifications.
///   * [openSystemSettings] — deep-link into the system app-settings page
///     for this app. Used by the [TrackingPermissionStatus.permanentlyDenied]
///     CTA (D-09) and by the [TrackingPermissionStatus.notificationDenied]
///     UX-03 CTA.
///
/// Ordering invariants:
///
///   1. `notification` is NEVER probed or requested until
///      `locationWhenInUse` has resolved granted. This is enforced
///      structurally: [preflight] returns early on every non-granted
///      location outcome (denied / permanentlyDenied), so control flow
///      never reaches the notification step unless location has already
///      resolved granted — there is no local flag or assert to keep in
///      sync. This invariant governs the [preflight] dance.
///   2. [requestWhenInUse] is NOT part of that dance; it touches
///      `Permission.locationWhenInUse` and nothing else, so it cannot
///      violate invariant 1, and it must never grow a notification (or
///      background-location) step.
///
/// Invariant 1 is enforced by [preflight]'s control flow and asserted in
/// the unit tests. Invariant 2 is enforced by [requestWhenInUse] and
/// asserted in its own unit tests.
class TrackingPermissionService {
  /// Production constructor — wires the real `permission_handler` APIs.
  ///
  /// `const` because every field is a compile-time-constant function
  /// reference (static tear-off or top-level function), so callers can use
  /// `const TrackingPermissionService()` in provider graphs.
  const TrackingPermissionService()
    : _probe = _defaultProbe,
      _request = _defaultRequest,
      _openSettings = openAppPermissionSettings;

  /// Test-only constructor. Accepts closures so unit tests can inject
  /// deterministic permission states without implementing an interface.
  @visibleForTesting
  TrackingPermissionService.forTesting({
    required PermissionStatusProbe probe,
    required PermissionRequester requester,
    SettingsOpener? opener,
  }) : _probe = probe,
       _request = requester,
       _openSettings = opener ?? openAppPermissionSettings;

  final PermissionStatusProbe _probe;
  final PermissionRequester _request;
  final SettingsOpener _openSettings;

  /// Runs the two-step permission dance and returns the resolved
  /// [TrackingPermissionStatus].
  ///
  /// Step order (strictly enforced):
  ///
  ///   1. Probe / request `locationWhenInUse`. Short-circuits to
  ///      [TrackingPermissionStatus.permanentlyDenied] or
  ///      [TrackingPermissionStatus.denied] WITHOUT touching `notification`
  ///      if fine is not granted.
  ///   2. Probe / request `notification` (UX-03 gap-closure). Never
  ///      touched until `locationWhenInUse` has resolved granted; required
  ///      on Android 13+ for the UX-03 foreground notification to be
  ///      visible at all. If denied, returns
  ///      [TrackingPermissionStatus.notificationDenied].
  ///
  /// `Permission.locationAlways` is NEVER probed or requested — see the
  /// class dartdoc for why.
  ///
  /// Short-circuit cases that return WITHOUT touching `notification`:
  ///
  ///   a. Fine is already permanently denied on initial probe.
  ///   b. Fine request resolves permanently denied.
  ///   c. Fine request resolves denied (non-permanent).
  ///
  /// Every one of those is an early `return`, so by the time control flow
  /// reaches the notification step, `locationWhenInUse` is granted by
  /// construction — that ordering is structural, not asserted.
  Future<TrackingPermissionStatus> preflight() async {
    final fineStatus = await _probe(Permission.locationWhenInUse);
    if (fineStatus.isPermanentlyDenied) {
      return TrackingPermissionStatus.permanentlyDenied;
    }
    if (!fineStatus.isGranted) {
      final requested = await _request(Permission.locationWhenInUse);
      if (requested.isPermanentlyDenied) {
        return TrackingPermissionStatus.permanentlyDenied;
      }
      if (!requested.isGranted) {
        return TrackingPermissionStatus.denied;
      }
    }
    // From here on, locationWhenInUse is granted by control flow: every
    // non-granted outcome above already returned.
    // D-06: On iOS, tracking depends only on location. The notification
    // permission dance is Android-only (UX-03 requires POST_NOTIFICATIONS on
    // Android 13+, but iOS never gates tracking on notification permission).
    // Return here without touching Permission.notification so the iOS
    // Start button is never permanently disabled by a denied notification.
    // TODO(v0.2-resume): iOS background-location strategy must be
    // re-decided when the iOS platform resumes (DEC-C) — iOS has no
    // foreground-service equivalent, so the reasoning that justifies
    // dropping locationAlways on Android does NOT transfer to iOS.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return TrackingPermissionStatus.fullyGranted;
    }
    // UX-03: notifications are a hard requirement. Fine location resolved
    // means location is OK; we still must ensure POST_NOTIFICATIONS so the
    // foreground notification (D-14) is actually visible on Android 13+.
    // Ordering guard: we only reach this point after locationWhenInUse has
    // resolved granted — the user is never asked for notifications before
    // location.
    final notifStatus = await _probe(Permission.notification);
    if (!notifStatus.isGranted) {
      final notifRequested = await _request(Permission.notification);
      if (!notifRequested.isGranted) {
        return TrackingPermissionStatus.notificationDenied;
      }
    }
    return TrackingPermissionStatus.fullyGranted;
  }

  /// Requests `Permission.locationWhenInUse` ONLY and returns the resolved
  /// [LocationWhenInUseStatus].
  ///
  /// Probes first and only requests when not already granted; touches ONLY
  /// `Permission.locationWhenInUse` and NEVER `notification` (and, like the
  /// rest of this class, never `locationAlways` — see the class dartdoc).
  /// Exists for callers (the location picker) that need to centre a map and
  /// have no business asking for notifications. Uses the same injected
  /// probe/requester seams as [preflight], so it is unit testable with no
  /// platform channel.
  Future<LocationWhenInUseStatus> requestWhenInUse() async {
    final status = await _probe(Permission.locationWhenInUse);
    if (status.isPermanentlyDenied) {
      return LocationWhenInUseStatus.permanentlyDenied;
    }
    if (status.isGranted) return LocationWhenInUseStatus.granted;
    final requested = await _request(Permission.locationWhenInUse);
    if (requested.isPermanentlyDenied) {
      return LocationWhenInUseStatus.permanentlyDenied;
    }
    return requested.isGranted
        ? LocationWhenInUseStatus.granted
        : LocationWhenInUseStatus.denied;
  }

  /// Returns the current [TrackingPermissionStatus] without prompting the
  /// user. Used by the home screen to decide whether Start is enabled on
  /// first build.
  ///
  /// Only calls the probe — never the requester — so it is safe to invoke
  /// in build-time code paths without risking a permission dialog. This
  /// is a hard invariant: even when `notification` is denied, this method
  /// returns [TrackingPermissionStatus.notificationDenied] based on the
  /// probe alone and does NOT trigger a system prompt. `locationAlways` is
  /// never probed (see the class dartdoc).
  ///
  /// Mirrors [preflight]'s ordering: location is classified first, and the
  /// notification probe only runs once `locationWhenInUse` has probed
  /// granted.
  Future<TrackingPermissionStatus> currentStatus() async {
    final fineStatus = await _probe(Permission.locationWhenInUse);
    if (fineStatus.isPermanentlyDenied) {
      return TrackingPermissionStatus.permanentlyDenied;
    }
    if (!fineStatus.isGranted) {
      return TrackingPermissionStatus.denied;
    }
    // D-06: iOS resolves on location alone — never probe notification.
    // On iOS, returning here means notificationDenied is never reachable,
    // so the Start button cannot be permanently disabled by a notification
    // permission state (RESEARCH Pitfall 5).
    // TODO(v0.2-resume): iOS background-location strategy must be
    // re-decided when the iOS platform resumes (DEC-C) — iOS has no
    // foreground-service equivalent, so the reasoning that justifies
    // dropping locationAlways on Android does NOT transfer to iOS.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return TrackingPermissionStatus.fullyGranted;
    }
    // UX-03: location is OK; now classify notifications. Probe-only —
    // never call the requester from currentStatus (build-time safety).
    final notifStatus = await _probe(Permission.notification);
    if (!notifStatus.isGranted) {
      return TrackingPermissionStatus.notificationDenied;
    }
    return TrackingPermissionStatus.fullyGranted;
  }

  /// Deep-links into this app's PERMISSION LIST in system settings (D-09,
  /// and Phase 36 D-03).
  ///
  /// The single destination for every permission-denied path in the app. Before
  /// Phase 36 there were three, all reachable from the same "permission
  /// denied" situation and all landing somewhere different: this method went
  /// to App Info, the tracking-error layout went to the **device-wide**
  /// location screen via `Geolocator.openLocationSettings`, and the shell's
  /// start-blocked message went nowhere at all. They now all call this.
  ///
  /// Returns `true` if a settings screen was shown, `false` otherwise (e.g. no
  /// activity on the device resolved either intent). Wraps
  /// [openAppPermissionSettings] in production; test instances can inject a
  /// [SettingsOpener] fake.
  Future<bool> openSystemSettings() => _openSettings();

  static Future<PermissionStatus> _defaultProbe(Permission permission) =>
      permission.status;

  static Future<PermissionStatus> _defaultRequest(Permission permission) =>
      permission.request();
}
