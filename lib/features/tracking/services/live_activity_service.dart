import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';
import 'package:traevy/shared/utils/formatters.dart';

/// Dart bridge for the iOS Live Activity (IOS-13, D-08/D-09/D-10).
///
/// Wraps the `live_activities` plugin to create, update, and dismiss the
/// lock-screen / Dynamic Island Live Activity that shows live trip stats
/// (elapsed time, distance, moving/stuck breakdown) during an active commute.
///
/// Lifecycle contract:
///   1. [init] once at app startup with the [TrackingServiceController] so the
///      URL-scheme Stop button can call [TrackingServiceController.stop].
///   2. [start] when a trip begins — creates the ActivityKit instance.
///   3. [update] on the same 5s cadence as the Android notification refresh
///      ([kTrackingNotificationRefreshInterval]) to push fresh stats.
///   4. [end] when the trip stops — dismisses the Activity immediately.
///   5. [endAll] when `TrackingIdle` is confirmed — clears any orphaned
///      Activities left running after an app-kill (Pitfall 4).
///
/// Design constraints:
///   - Only runs on iOS 17+ (`_isLiveActivitySupported` gate). On every other
///     platform or iOS < 17, every public method is a no-op.
///   - All plugin calls are wrapped in `try/on Object {}` — the Live Activity
///     is additive; a failure must never break the underlying trip recording
///     (Deviation Rule 4 / T-15-13).
///   - Uses [defaultTargetPlatform] (not `dart:io Platform.isIOS`) for the
///     iOS gate so unit tests can exercise the iOS path via
///     [debugDefaultTargetPlatformOverride] (RESEARCH Pitfall 2).
class LiveActivityService {
  /// Construct a [LiveActivityService].
  ///
  /// Accepts an optional [plugin] instance for test injection. Production code
  /// omits [plugin] and the default [LiveActivities] singleton is used.
  LiveActivityService({LiveActivities? plugin})
    : _plugin = plugin ?? LiveActivities();

  final LiveActivities _plugin;
  String? _activityId;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Initialise the Live Activity plugin and wire up the URL-scheme Stop
  /// button callback.
  ///
  /// Must be called once on app startup before [start]. Safe to call on
  /// non-iOS platforms — returns immediately as a no-op.
  ///
  /// [controller] is the [TrackingServiceController] whose `stop()` method is
  /// invoked when the SwiftUI Stop button fires `traevy://stop`.
  Future<void> init(TrackingServiceController controller) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    debugPrint('[la-diag] init() called platform=$defaultTargetPlatform'); // TEMP la-diag
    try {
      await _plugin.init(
        appGroupId: kLiveActivityAppGroupId,
        urlScheme: kLiveActivityUrlScheme,
        // We manage POST_NOTIFICATIONS permission ourselves in Plan 03.
        requestAndroidNotificationPermission: false,
      );
      debugPrint( // TEMP la-diag
        '[la-diag] init() plugin.init done appGroup=$kLiveActivityAppGroupId urlScheme=$kLiveActivityUrlScheme', // TEMP la-diag
      ); // TEMP la-diag
      _plugin.urlSchemeStream().listen((data) {
        // T-15-11: exact-match host guard — only 'stop' triggers the action.
        // Any other URL or host is silently ignored (ASVS V5 input validation).
        if (data.host == 'stop') {
          unawaited(controller.stop());
        }
      });
    } on Object catch (e) {
      debugPrint('[la-diag] init() FAILED: $e'); // TEMP la-diag
      // init failure is non-fatal: Live Activity is additive (T-15-13).
    }
  }

  /// Create a Live Activity for the given [snapshot] and [direction].
  ///
  /// No-op if the platform is not iOS 17+ or if `_isLiveActivitySupported`
  /// returns false. Stores the returned activity id in [_activityId] for
  /// subsequent [update] and [end] calls.
  Future<void> start(TripSnapshot snapshot, String direction) async {
    debugPrint('[la-diag] start() called'); // TEMP la-diag
    final supported = await _isLiveActivitySupported();
    debugPrint('[la-diag] start() supportGate=$supported'); // TEMP la-diag
    if (!supported) return;
    final content = _contentState(snapshot, direction);
    debugPrint( // TEMP la-diag
      '[la-diag] start() calling createActivity id=$kLiveActivityId keys=${content.entries.map((e) => "${e.key}=${e.value}").join(", ")}', // TEMP la-diag
    ); // TEMP la-diag
    try {
      final id = await _plugin.createActivity(
        kLiveActivityId,
        content,
      );
      _activityId = id;
      debugPrint('[la-diag] start() createActivity returned activityId=$id'); // TEMP la-diag
    } on Object catch (e) {
      debugPrint('[la-diag] start() createActivity THREW: $e'); // TEMP la-diag
      // createActivity failure is non-fatal (T-15-13).
    }
  }

  /// Push a fresh [snapshot] to the running Live Activity.
  ///
  /// No-op if [_activityId] is null (no Activity was created, or it already
  /// ended). Call this on the [kTrackingNotificationRefreshInterval] cadence —
  /// the same throttle as the Android notification refresh (A2).
  Future<void> update(TripSnapshot snapshot, String direction) async {
    final id = _activityId;
    if (id == null) return;
    debugPrint('[la-diag] update() activityId=$id'); // TEMP la-diag
    try {
      await _plugin.updateActivity(id, _contentState(snapshot, direction));
    } on Object {
      // updateActivity failure is non-fatal (T-15-13).
    }
  }

  /// End the running Live Activity and clear [_activityId].
  ///
  /// No-op if no Activity is active. Dismisses the lock-screen entry
  /// immediately via the plugin's `.immediate` dismissal policy.
  Future<void> end() async {
    final id = _activityId;
    if (id == null) return;
    debugPrint('[la-diag] end() activityId=$id'); // TEMP la-diag
    try {
      await _plugin.endActivity(id);
    } on Object {
      // endActivity failure is non-fatal (T-15-13).
    }
    _activityId = null;
  }

  /// End ALL Live Activities owned by this app and clear [_activityId].
  ///
  /// Call this when `TrackingIdle` is confirmed to sweep up any Activity
  /// orphaned by an app-kill mid-commute (Pitfall 4, RESEARCH §4).
  Future<void> endAll() async {
    try {
      await _plugin.endAllActivities();
    } on Object {
      // endAllActivities failure is non-fatal (T-15-13).
    }
    _activityId = null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns true only when ALL of the following hold:
  ///   - The current platform is iOS.
  ///   - `areActivitiesSupported()` is true (iOS 16.1+ and device has Dynamic
  ///     Island or lock-screen ActivityKit support).
  ///   - `areActivitiesEnabled()` is true (user has not disabled Live
  ///     Activities in Settings → Face ID & Passcode).
  ///   - The iOS major version is at least 17 (D-09 floor —
  ///     areActivitiesSupported alone returns true on 16.1+, which is
  ///     insufficient for our floor).
  ///
  /// Uses [defaultTargetPlatform] for testability (RESEARCH Pitfall 2).
  Future<bool> _isLiveActivitySupported() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      final supported = await _plugin.areActivitiesSupported();
      debugPrint('[la-diag] support: areActivitiesSupported=$supported'); // TEMP la-diag
      if (!supported) {
        debugPrint('[la-diag] support: RESULT=false (areActivitiesSupported=false)'); // TEMP la-diag
        return false;
      }
      final enabled = await _plugin.areActivitiesEnabled();
      debugPrint('[la-diag] support: areActivitiesEnabled=$enabled'); // TEMP la-diag
      if (!enabled) {
        debugPrint('[la-diag] support: RESULT=false (areActivitiesEnabled=false)'); // TEMP la-diag
        return false;
      }
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      final systemVersion = iosInfo.systemVersion;
      final major = int.tryParse(systemVersion.split('.').first) ?? 0;
      debugPrint('[la-diag] support: iOSMajor=$major (raw=$systemVersion)'); // TEMP la-diag
      final result = major >= 17;
      debugPrint('[la-diag] support: RESULT=$result'); // TEMP la-diag
      return result;
    } on Object catch (e) {
      debugPrint('[la-diag] support: EXCEPTION $e'); // TEMP la-diag
      // If the version check itself fails, default to unsupported — safe
      // degradation: tracking continues without Live Activity (T-15-13).
      return false;
    }
  }

  /// Build the ContentState map bridged to the SwiftUI Widget via the
  /// live_activities UserDefaults App Group container.
  ///
  /// The 7 keys MUST match `TraevyLiveActivityAttributes.ContentState` in
  /// `ios/TraevyLiveActivity/TraevyLiveActivityAttributes.swift` exactly.
  ///
  /// T-15-12: only pre-formatted aggregate strings are included — raw
  /// lat/lng coordinates are NEVER bridged (PII guard T-02-07 preserved).
  ///
  /// Note: `startDate` is sent as a `double` (ms epoch) to match the Swift
  /// `ContentState.startDate: Double` field. The live_activities plugin's
  /// UserDefaults/Codable bridge cannot decode a Dart `int` as a Swift `Date`;
  /// the SwiftUI view converts it via:
  ///   `Date(timeIntervalSince1970: Double(startDate) / 1000.0)`
  Map<String, dynamic> _contentState(TripSnapshot s, String direction) =>
      <String, dynamic>{
        'elapsedFormatted': formatElapsed(s.elapsedSeconds),
        'distanceFormatted': formatDistance(s.distanceMeters),
        'movingFormatted': formatStuck(s.timeMovingSeconds),
        'stuckFormatted': formatStuck(s.timeStuckSeconds),
        'isMoving': s.currentSpeedMs >= kStuckSpeedThresholdMs,
        'direction': direction,
        // Send as double so Swift decodes the ms epoch into a numeric Double.
        'startDate': s.startedAt.millisecondsSinceEpoch.toDouble(),
      };
}
