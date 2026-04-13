import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Four-way classification of the device's location permission state as it
/// relates to Phase 2 tracking requirements.
///
/// Mapped from Phase 2 context decisions D-07 (two-step permission flow),
/// D-08 (background-denied banner), and D-09 (permanent-deny "open
/// settings" CTA). Consumers — the home screen pre-flight (plan 02-04) and
/// the service-isolate starter (plan 02-03) — switch on this enum to decide
/// whether Start is enabled, whether to show the limitation banner, and
/// whether to deep-link into system settings.
enum TrackingPermissionStatus {
  /// Fine + background both granted. Full feature set; no banner.
  fullyGranted,

  /// Fine granted, background denied. Tracking works only while the app is
  /// foregrounded. UI must show the D-08 dismissible banner.
  foregroundOnly,

  /// Fine denied (first-time or after a soft "Deny"). Start button
  /// disabled. UI must show the "Grant location" CTA.
  denied,

  /// Fine permanently denied ("Deny & don't ask again" or Android 12
  /// auto-lock). UI must show the D-09 "Open settings" CTA.
  permanentlyDenied,
}

/// Reads a [Permission]'s current status without prompting the user.
///
/// Injection seam so unit tests can drive [TrackingPermissionService]
/// without touching the real plugin. Production default wraps
/// `Permission.status` from `permission_handler`.
typedef PermissionStatusProbe = Future<PermissionStatus> Function(
  Permission permission,
);

/// Prompts the user for a [Permission] and returns the resolved status.
///
/// Injection seam so unit tests can drive [TrackingPermissionService]
/// without touching the real plugin. Production default wraps
/// `Permission.request()` from `permission_handler`.
typedef PermissionRequester = Future<PermissionStatus> Function(
  Permission permission,
);

/// Opens the system's app-settings page. Injection seam so unit tests can
/// observe [TrackingPermissionService.openSystemSettings] without touching
/// the platform channel. Production default is the top-level
/// [openAppSettings] from `permission_handler`.
typedef SettingsOpener = Future<bool> Function();

/// Wraps `permission_handler` for Phase 2's strict two-step location
/// permission dance (D-07 / RESEARCH Pitfall 5).
///
/// Instances are stateless — safe to share via a Riverpod `Provider`.
///
/// The public contract is:
///
///   * [preflight] — run the two-step request and return the resolved
///     status. Callers MUST await this before starting the foreground
///     service.
///   * [currentStatus] — classify the current state WITHOUT prompting.
///     Used on first build to decide whether Start is enabled.
///   * [openSystemSettings] — deep-link into the system app-settings page
///     for this app. Used by the [TrackingPermissionStatus.permanentlyDenied]
///     CTA (D-09).
///
/// The strict ordering invariant — `locationAlways` is NEVER probed or
/// requested until `locationWhenInUse` has resolved granted — is enforced
/// by [preflight] and asserted in the unit tests (RESEARCH Pitfall 5).
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
  })  : _probe = probe,
        _request = requester,
        _openSettings = opener ?? openAppSettings;

  final PermissionStatusProbe _probe;
  final PermissionRequester _request;
  final SettingsOpener _openSettings;

  /// Runs the D-07 two-step permission dance: fine first, background
  /// second. Returns the resolved [TrackingPermissionStatus].
  ///
  /// Short-circuits in four cases without touching `locationAlways`:
  ///
  ///   1. Fine is already permanently denied on initial probe.
  ///   2. Fine request resolves permanently denied.
  ///   3. Fine request resolves denied (non-permanent).
  ///   4. Fine is already granted — in which case the background step
  ///      still runs, starting from its current probe.
  ///
  /// These short-circuits together enforce the RESEARCH Pitfall 5
  /// ordering invariant: `locationAlways` is only touched after
  /// `locationWhenInUse` is fully resolved granted.
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
    if (bgStatus.isGranted) return TrackingPermissionStatus.fullyGranted;
    final bgRequested = await _request(Permission.locationAlways);
    return bgRequested.isGranted
        ? TrackingPermissionStatus.fullyGranted
        : TrackingPermissionStatus.foregroundOnly;
  }

  /// Returns the current [TrackingPermissionStatus] without prompting the
  /// user. Used by the home screen to decide whether Start is enabled on
  /// first build.
  ///
  /// Only calls the probe — never the requester — so it is safe to invoke
  /// in build-time code paths without risking a permission dialog.
  Future<TrackingPermissionStatus> currentStatus() async {
    final fineStatus = await _probe(Permission.locationWhenInUse);
    if (fineStatus.isPermanentlyDenied) {
      return TrackingPermissionStatus.permanentlyDenied;
    }
    if (!fineStatus.isGranted) {
      return TrackingPermissionStatus.denied;
    }
    final bgStatus = await _probe(Permission.locationAlways);
    return bgStatus.isGranted
        ? TrackingPermissionStatus.fullyGranted
        : TrackingPermissionStatus.foregroundOnly;
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
