# Phase 15: Notifications, Permissions & Onboarding UX on iOS — Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 11 new/modified Dart files + 4 native iOS files
**Analogs found:** 9 / 11 Dart files have analogs; 0 / 4 native iOS files have analogs

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/onboarding/screens/onboarding_location_priming_screen.dart` | component (screen) | request-response | `lib/features/onboarding/screens/onboarding_screen.dart` | exact |
| `lib/features/tracking/services/tracking_permission_service.dart` | service | request-response | self (modify) — pattern is already there | exact |
| `lib/features/tracking/services/tracking_notification_service.dart` | service | request-response | self (modify) — `showRecording()` and `_formatStuck()` | exact |
| `lib/features/tracking/services/tracking_service_controller.dart` | service | event-driven | self (modify) — `defaultTargetPlatform` branch already at line 104/119 | exact |
| `lib/features/tracking/services/live_activity_service.dart` | service | event-driven | `lib/features/tracking/services/tracking_notification_service.dart` (analogous lifecycle: init/show/update/dismiss) | role-match |
| `lib/features/tracking/providers/tracking_providers.dart` | provider | event-driven | self (modify) — wire `LiveActivityService` alongside `TrackingNotificationService` | exact |
| `lib/notifications/notification_service.dart` | service | event-driven | self (modify) — add `requestIOSNotificationPermission()` helper | exact |
| `lib/shared/utils/formatters.dart` | utility | transform | self (modify) — add `formatElapsed` + extract `formatStuck` | exact |
| `lib/config/constants.dart` | config | — | self (modify) — append Phase 15 block | exact |
| `lib/config/routes.dart` | config | — | self (modify) — add `kRouteLocationPriming` | exact |
| `lib/features/tracking/widgets/permission_banner.dart` | component (widget) | request-response | self (modify) — iOS copy-branch at call site | exact |
| `ios/TraevyLiveActivity/TraevyLiveActivityAttributes.swift` | native model | transform | NO ANALOG — first native ActivityKit struct | none |
| `ios/TraevyLiveActivity/TraevyLiveActivityWidget.swift` | native component | event-driven | NO ANALOG — first SwiftUI Widget Extension | none |
| `ios/TraevyLiveActivity/Localizable.strings` | native config | — | NO ANALOG — first native localization file | none |
| `ios/Runner/Info.plist` | native config | — | self (modify) — existing plist structure is the pattern | exact |

---

## Pattern Assignments

---

### `lib/features/onboarding/screens/onboarding_location_priming_screen.dart` (component, request-response)

**Analog:** `lib/features/onboarding/screens/onboarding_screen.dart`

**Imports pattern** (lines 1–11):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/onboarding/widgets/feature_tick.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
```
Note: this screen is a `ConsumerWidget` (needs `ref` for the permission service), not a plain `StatelessWidget` like the current `OnboardingScreen`.

**Scaffold / sticky-footer layout pattern** (lines 38–51):
```dart
return Scaffold(
  body: SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ...content...
                    const Spacer(),
                    // ...CTA pinned at bottom...
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  ),
);
```
Replicate exactly: same padding (`fromLTRB(32, 60, 32, 32)`), same `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox` + `IntrinsicHeight` stack — this is the established sticky-footer pattern.

**Heading + body copy text style** (lines 56–79):
```dart
Text(
  kIosLocationPrimingHeading,         // Phase 15 constant
  style: TraevyFonts.ui(
    size: 22,                         // smaller than onboarding 36px — priming is secondary
    weight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
    color: onSurface,
  ),
),
const SizedBox(height: 8),
ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 280),
  child: Text(
    kIosLocationPrimingBody,
    style: TraevyFonts.ui(
      size: 16,
      color: tokens.textDim,
      height: 1.5,
    ),
  ),
),
```
`TraevyFonts.ui(...)` with `size`/`weight`/`color` is the universal text pattern. `tokens.textDim` is always `Theme.of(context).extension<TraevyTokensExt>()!.textDim`.

**FeatureTick rows pattern** (lines 81–95):
```dart
const FeatureTick(
  title: kIosLocationPrimingTick1Title,
  subtitle: kIosLocationPrimingTick1Subtitle,
),
const SizedBox(height: 16),
const FeatureTick(
  title: kIosLocationPrimingTick2Title,
  subtitle: kIosLocationPrimingTick2Subtitle,
),
const SizedBox(height: 16),
const FeatureTick(
  title: kIosLocationPrimingTick3Title,
  subtitle: kIosLocationPrimingTick3Subtitle,
),
```
Gap between ticks is `16` (md token) per UI-SPEC — the analog uses `18`; Phase 15 uses `16` per UI-SPEC §Surface A.

**CTA button pattern** — copy the `GoogleContinueButton` shell exactly (lines 23–64 of `google_continue_button.dart`), but swap the Google G SVG for `Icon(Icons.location_on_outlined, size: 20)`. The button shape, colors, and padding come from `tokens.bgElev`, `tokens.borderStr`, `BorderRadius.circular(14)`, `EdgeInsets.symmetric(horizontal: 18, vertical: 16)`. Declare a local `_LocationCTAButton` widget inside the screen file (under ~100 lines so no separate file needed).

**Skip link + terms blurb pattern** (lines 149–186 of `onboarding_screen.dart`):
```dart
const SizedBox(height: 8),
Center(
  child: GestureDetector(
    onTap: () { /* navigate forward without requesting */ },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Text(
        kIosLocationPrimingSkip,
        style: TraevyFonts.ui(size: 14, weight: FontWeight.w400, color: tokens.textMuted),
      ),
    ),
  ),
),
const SizedBox(height: 16),
Center(
  child: Text(
    kIosLocationPrimingTerms,
    style: TraevyFonts.ui(size: 14, color: tokens.textMuted, height: 1.5),
    textAlign: TextAlign.center,
  ),
),
```
`tokens.textMuted` (not `tokens.textDim`) is the established pattern for captions/skip links on the onboarding screen.

**`context.mounted` guard after async** (line 107 of `onboarding_screen.dart`):
```dart
// after every await in an async callback:
if (!context.mounted) return;
```
This discipline is enforced throughout the codebase — every async tap handler checks `context.mounted` before using `Navigator` or `ScaffoldMessenger`.

---

### `lib/features/tracking/services/tracking_permission_service.dart` (service, request-response) — MODIFY

**Analog:** self — existing file at `/Users/coolman/Documents/Projects/bizzle/lib/features/tracking/services/tracking_permission_service.dart`

**Existing `defaultTargetPlatform` branch pattern** — already established in `tracking_service_controller.dart` lines 104 and 119. Replicate the same idiom here:
```dart
import 'package:flutter/foundation.dart';  // already imported (line 1)
// ...
if (defaultTargetPlatform == TargetPlatform.iOS) {
  // D-06: iOS tracking depends only on location; never probe notification.
  return backgroundGranted
      ? TrackingPermissionStatus.fullyGranted
      : TrackingPermissionStatus.foregroundOnly;
}
```

**Insertion point in `preflight()`** (after line 190, before line 198 of the existing file):
The iOS branch must be inserted immediately after `backgroundGranted` is resolved and BEFORE `final notifStatus = await _probe(Permission.notification)`. The ordering invariant comment block (lines 192–197) stays in place and applies only to the Android path.

**Insertion point in `currentStatus()`** (after line 234, before line 237 of the existing file):
```dart
// After: final locationStatus = bgStatus.isGranted ? ... : ...foregroundOnly;
if (defaultTargetPlatform == TargetPlatform.iOS) {
  return locationStatus;  // never probe notification on iOS
}
// Android-only: notification probe continues below
```

**Test-injection pattern** — the `TrackingPermissionService.forTesting(...)` constructor (lines 123–129) already uses `@visibleForTesting`. New tests will use `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` rather than injecting a new seam.

---

### `lib/features/tracking/services/tracking_notification_service.dart` (service, request-response) — MODIFY

**Analog:** self — existing file at `/Users/coolman/Documents/Projects/bizzle/lib/features/tracking/services/tracking_notification_service.dart`

**`Platform.isAndroid` gate pattern** — the controller already gates `showRecording()` at lines 119–125. The service-level guard adds a matching belt-and-suspenders guard inside `showRecording()` itself:
```dart
import 'dart:io' show Platform;   // add this import

Future<void> showRecording({...}) async {
  if (!Platform.isAndroid) return;   // D-11: iOS never posts this notification
  // ... rest of existing method unchanged
}
```
Note: `dart:io Platform` (not `defaultTargetPlatform`) is appropriate here because `showRecording()` is never unit-tested in isolation — it is always guarded by the controller. The controller uses `defaultTargetPlatform` (testable); the service adds a runtime defense.

**`_formatStuck` extraction pattern** — the private method at lines 269–275 moves to `formatters.dart` as the top-level function `formatStuck(int seconds)`. Then update the usage in `_renderBody()` (line 259):
```dart
// Before:
final stuck = _formatStuck(timeStuckSeconds);
// After (once formatStuck is in formatters.dart):
final stuck = formatStuck(timeStuckSeconds);
```
The `formatters.dart` import is already present (line 65 of the notification service).

**Android enrichment — two-line body** — replace `_renderBody()` (lines 252–264) to produce a two-line string using the new `kTrackingNotificationBodyLine1Template` and `kTrackingNotificationBodyLine2Template` constants, plus the new `formatElapsed()` formatter:
```dart
static String _renderBody({
  required int elapsedSeconds,
  required double distanceMeters,
  required int timeMovingSeconds,
  required int timeStuckSeconds,
}) {
  final elapsed = formatElapsed(elapsedSeconds);    // NEW formatter
  final km = (distanceMeters / 1000).toStringAsFixed(1);
  final moving = formatStuck(timeMovingSeconds);    // extracted from private
  final stuck  = formatStuck(timeStuckSeconds);
  final line1 = kTrackingNotificationBodyLine1Template
      .replaceFirst('{elapsed}', elapsed)
      .replaceFirst('{km}', km);
  final line2 = kTrackingNotificationBodyLine2Template
      .replaceFirst('{moving}', moving)
      .replaceFirst('{stuck}', stuck);
  return '$line1\n$line2';
}
```
`BigTextStyleInformation(body)` at line 178 stays unchanged — it receives the two-line string.

**D-14 contract constants — unchanged** (verified at lines 162–195): `kTrackingNotificationChannelId`, `kTrackingNotificationId`, `ongoing: true`, `autoCancel: false`, `onlyAlertOnce: true`, `Importance.low`, `Priority.low`. These must survive the enrichment unchanged.

---

### `lib/features/tracking/services/live_activity_service.dart` (service, event-driven) — NEW

**Analog:** `lib/features/tracking/services/tracking_notification_service.dart`

This new service follows the same lifecycle structure as `TrackingNotificationService`: constructor-injected plugin, `init()` method, `start()` / `update()` / `end()` methods, and a `_contentState()` helper.

**Imports pattern** — model on `tracking_notification_service.dart` lines 61–66 but replace the `flutter_local_notifications` import with the new packages:
```dart
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/url_scheme_data.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';
import 'package:traevy/shared/utils/formatters.dart';
```

**Constructor-injection pattern** (from `tracking_notification_service.dart` lines 79–81):
```dart
class LiveActivityService {
  LiveActivityService({LiveActivities? plugin})
      : _plugin = plugin ?? LiveActivities();

  final LiveActivities _plugin;
  String? _activityId;
```

**`init()` method with URL scheme stream** — mirrors `TrackingNotificationService.initialize()` structure but wires the plugin's URL scheme stream to stop-command routing:
```dart
Future<void> init(TrackingServiceController controller) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  await _plugin.init(
    appGroupId: kLiveActivityAppGroupId,
    urlScheme: kLiveActivityUrlScheme,
    requestAndroidNotificationPermission: false,
  );
  _plugin.urlSchemeStream().listen((UrlSchemeData data) {
    if (data.host == 'stop') {
      unawaited(controller.stop());
    }
  });
}
```
`unawaited(...)` from `dart:async` is the established pattern throughout `tracking_providers.dart` (e.g., lines 302–314) for fire-and-forget async calls.

**iOS 17 version gate** — use `device_info_plus`; follow the `defaultTargetPlatform` pattern from `tracking_service_controller.dart` line 104:
```dart
Future<bool> _isLiveActivitySupported() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return false;
  final supported = await _plugin.areActivitiesSupported();
  if (!supported) return false;
  final enabled = await _plugin.areActivitiesEnabled();
  if (!enabled) return false;
  final iosInfo = await DeviceInfoPlugin().iosInfo;
  final major = int.tryParse(iosInfo.systemVersion.split('.').first) ?? 0;
  return major >= 17;
}
```

**`_contentState()` helper** — produces the `Map<String, dynamic>` the plugin bridges to Swift. All four string fields use formatters from `formatters.dart`:
```dart
Map<String, dynamic> _contentState(TripSnapshot s, String direction) => {
  'elapsedFormatted': formatElapsed(s.elapsedSeconds),
  'distanceFormatted': formatDistance(s.distanceMeters),
  'movingFormatted': formatStuck(s.timeMovingSeconds),
  'stuckFormatted': formatStuck(s.timeStuckSeconds),
  'isMoving': s.currentSpeedMs >= kStuckSpeedThresholdMs,
  'direction': direction,
  'startDate': s.startedAt.millisecondsSinceEpoch,
};
```

**Error swallowing pattern** — from `tracking_service_controller.dart` lines 120–123 (Deviation Rule 4):
```dart
try {
  await _plugin.createActivity(kLiveActivityId, _contentState(s, direction));
} on Object {
  // Live Activity is additive; tracking continues without it.
}
```

**Orphan cleanup on idle** — `end()` is called when `TrackingState` returns to `TrackingIdle`. Follow the `dismiss()` pattern from `TrackingNotificationService` (line 222):
```dart
Future<void> end() async {
  final id = _activityId;
  if (id == null) return;
  try {
    await _plugin.endActivity(id);
  } on Object {
    // ignore — best effort
  }
  _activityId = null;
}

Future<void> endAll() async {
  try {
    await _plugin.endAllActivities();
  } on Object { /* ignore */ }
  _activityId = null;
}
```

---

### `lib/features/tracking/providers/tracking_providers.dart` (provider, event-driven) — MODIFY

**Analog:** self — existing file at `/Users/coolman/Documents/Projects/bizzle/lib/features/tracking/providers/tracking_providers.dart`

**Provider declaration pattern** (lines 52–70):
```dart
final Provider<LiveActivityService> liveActivityServiceProvider =
    Provider<LiveActivityService>(
      (ref) => LiveActivityService(),
      name: 'liveActivityServiceProvider',
    );
```
Copy the same `Provider<T>(...)` with named constructor pattern used for `trackingNotificationServiceProvider` (lines 66–70). No `autoDispose` — keep alive for the app lifetime, matching the comment at lines 29–37.

**`TrackingNotifier._maybeRefreshNotification()` modification** — add a parallel Live Activity update call alongside the existing notification refresh. Model on the `unawaited(...)` + `.catchError(...)` pattern at lines 302–316:
```dart
void _maybeRefreshNotification(TrackingActive active) {
  // ...existing throttle check unchanged...
  // ...existing notification refresh unchanged...
  // NEW: Live Activity update, same cadence as notification (5 s throttle)
  unawaited(
    ref
        .read(liveActivityServiceProvider)
        .update(
          TripSnapshot(
            startedAt: active.startedAt,
            elapsedSeconds: active.elapsedSeconds,
            distanceMeters: active.distanceMeters,
            timeMovingSeconds: active.timeMovingSeconds,
            timeStuckSeconds: active.timeStuckSeconds,
            currentSpeedMs: active.currentSpeedMs,
          ),
          direction,
        )
        .catchError((Object _) {}),
  );
}
```

**`TrackingNotifier.stop()` modification** — add `endActivity` call alongside the existing stop flow (after line 411):
```dart
Future<void> stop() async {
  if (state is! TrackingActive) return;
  state = const TrackingStopping();
  _lastNotificationUpdateAt = null;
  await ref.read(trackingServiceControllerProvider).stop();
  unawaited(ref.read(liveActivityServiceProvider).end().catchError((Object _) {}));
}
```

**`ref.onDispose` cleanup pattern** (lines 168–173):
```dart
ref.onDispose(() {
  unawaited(_stateSub?.cancel());
  // ... existing subscriptions ...
  // LiveActivityService has no stream subscription to cancel here;
  // endAll() is called when TrackingIdle is confirmed in the finalize listener.
});
```

---

### `lib/notifications/notification_service.dart` (service, event-driven) — MODIFY

**Analog:** self — existing file at `/Users/coolman/Documents/Projects/bizzle/lib/notifications/notification_service.dart`

**`resolvePlatformSpecificImplementation<T>()` pattern** — already used in `TrackingNotificationService._createChannel()` (lines 235–238) for `AndroidFlutterLocalNotificationsPlugin`. Mirror exactly for the iOS implementation:
```dart
Future<void> requestIOSNotificationPermission() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  final ios = _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();
  await ios?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );
}
```

**Method placement** — add as a public method after `cancelReminder()` (line 202) and before the private helpers block (`_createChannels()` at line 207). Public methods before private helpers is the established ordering in this file.

**Error handling pattern** — wrap in try/catch matching the `initialize()` pattern at lines 70–75:
```dart
} on Exception catch (e, s) {
  debugPrint('NotificationService.requestIOSNotificationPermission: $e\n$s');
}
```

---

### `lib/shared/utils/formatters.dart` (utility, transform) — MODIFY

**Analog:** self — existing file at `/Users/coolman/Documents/Projects/bizzle/lib/shared/utils/formatters.dart`

**Existing formatter signature pattern** (lines 7–14):
```dart
/// Format a duration in seconds to a human-readable string.
///
/// Under 60 minutes: 'N min'. 60 minutes or more: 'NhNNmin'.
String formatDuration(int seconds) {
  if (seconds < 3600) {
    return '${seconds ~/ 60} min';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
}
```
All formatters are top-level functions — no class wrapper. Add two new top-level functions following the same `/// doc comment\nString functionName(type param) {}` pattern.

**New `formatElapsed(int seconds)` function** (to add):
```dart
/// Format elapsed trip seconds for live tracking surfaces (notification,
/// Live Activity). Outputs [MM:SS] under 1 hour, [H:MM:SS] at/above 1 hour.
///
/// Distinct from [formatDuration] (which outputs 'N min') — use
/// [formatElapsed] only for active-tracking displays (IOS-13, IOS-14).
String formatElapsed(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h == 0) return '$mm:$ss';
  return '$h:$mm:$ss';
}
```

**New `formatStuck(int seconds)` function** (extracted from `tracking_notification_service.dart` lines 269–275):
```dart
/// Compact stuck-time formatter for live tracking surfaces. Outputs the
/// shortest readable form: [Xm] under one hour, [XhYm] over (or [Xh] on
/// the hour).
///
/// Extracted from [TrackingNotificationService._formatStuck] so the Android
/// notification and the Live Activity bridge share one implementation.
String formatStuck(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remMinutes = minutes % 60;
  return remMinutes == 0 ? '${hours}h' : '${hours}h${remMinutes}m';
}
```

---

### `lib/config/constants.dart` (config) — MODIFY

**Analog:** self — existing file; append a Phase 15 block following the exact same commenting style as Phase 2 (lines 88–90) through Phase 14 blocks.

**Phase 15 block to append** — following the separator comment pattern:
```dart
// ---------------------------------------------------------------------------
// Phase 15: Notifications, Permissions & Onboarding UX on iOS
// ---------------------------------------------------------------------------

/// Live Activity App Group identifier. Shared between Runner and the
/// TraevyLiveActivity Widget Extension via the `live_activities` plugin's
/// UserDefaults bridge. Must match the capability configured in Xcode.
///
/// See D-08 in `.planning/phases/15-.../15-CONTEXT.md`.
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
/// See D-05, Surface B in `.planning/phases/15-.../15-UI-SPEC.md`.
const String kIosPermissionBannerBody =
    'Enable Always to avoid gaps in your trip when the screen is off.';

/// Location priming screen heading (IOS-09, D-01, Surface A).
const String kIosLocationPrimingHeading =
    'Your location stays on your device';

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
/// See D-12 in `.planning/phases/15-.../15-CONTEXT.md`.
const String kTrackingNotificationBodyLine1Template =
    '● REC  {elapsed} · {km} km';

/// Enriched Android notification body line 2 template (IOS-14).
/// Shown in BigTextStyle expanded notification.
/// Tokens: {moving}, {stuck}.
const String kTrackingNotificationBodyLine2Template =
    'Moving {moving} · Stuck {stuck}';

/// Route name for the iOS-only location priming screen (IOS-09, D-01).
const String kRouteLocationPriming = '/location-priming';
```

Note: `—` is em-dash, `●` is `●`, `·` is `·`. These avoid raw Unicode in the file consistent with Dart style.

---

### `lib/config/routes.dart` (config) — MODIFY

**Analog:** self — existing file at `/Users/coolman/Documents/Projects/bizzle/lib/config/routes.dart`

**Route registration pattern** (lines 53–62):
```dart
// In kAppRoutes map — add alongside the existing entries:
kRouteLocationPriming: (BuildContext context) =>
    const OnboardingLocationPrimingScreen(),
```
Also add the import at the top of `routes.dart`:
```dart
import 'package:traevy/features/onboarding/screens/onboarding_location_priming_screen.dart';
```

---

### `lib/features/tracking/widgets/permission_banner.dart` (component, request-response) — MODIFY

**Analog:** self — existing file at `/Users/coolman/Documents/Projects/bizzle/lib/features/tracking/widgets/permission_banner.dart`

The banner widget `content` text is currently hardcoded (line 27–30). The Platform-branch belongs at the **call site** (the tracking status layout, not the widget), passing the copy as a parameter. However, the simplest additive change that avoids a widget API break is to accept an optional `body` parameter:

```dart
class PermissionBanner extends StatelessWidget {
  const PermissionBanner({
    required this.onOpenSettings,
    this.body,                        // ADD — defaults to existing Android copy
    super.key,
  });

  final VoidCallback onOpenSettings;
  final String? body;                 // ADD

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      leading: const Icon(Icons.warning_amber_rounded),
      content: Text(
        body ??                       // iOS-branched copy if provided
        'Tracking will stop when the app is backgrounded. '
        'Enable always-on for full tracking.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: onOpenSettings,
          child: const Text('Open settings'),
        ),
      ],
    );
  }
}
```

At the call site (tracking screen), platform-branch:
```dart
PermissionBanner(
  onOpenSettings: ...,
  body: defaultTargetPlatform == TargetPlatform.iOS
      ? kIosPermissionBannerBody
      : null,  // null → widget uses its existing Android default
),
```

---

## Shared Patterns

### `defaultTargetPlatform` Platform Branching
**Source:** `lib/features/tracking/services/tracking_service_controller.dart` lines 104 and 119
**Apply to:** `tracking_permission_service.dart`, `tracking_service_controller.dart`, `live_activity_service.dart`, `tracking_providers.dart`
```dart
import 'package:flutter/foundation.dart';
// ...
if (defaultTargetPlatform == TargetPlatform.iOS) {
  // iOS-specific path
}
if (defaultTargetPlatform != TargetPlatform.iOS) {
  // Android-only path
}
```
Use `defaultTargetPlatform` (not `dart:io Platform.isIOS`) in ALL service and provider code. `dart:io Platform` is only acceptable in code paths that will never be unit-tested.

### Service Constructor Injection Pattern
**Source:** `lib/features/tracking/services/tracking_notification_service.dart` lines 79–81; `lib/notifications/notification_service.dart` lines 23–24
**Apply to:** `live_activity_service.dart`
```dart
ClassName({PluginType? plugin}) : _plugin = plugin ?? PluginType();
final PluginType _plugin;
```
Every service that wraps a plugin accepts an optional injected instance for testing.

### `unawaited(...)` + `.catchError(...)` Fire-and-Forget
**Source:** `lib/features/tracking/providers/tracking_providers.dart` lines 302–316
**Apply to:** `tracking_providers.dart` (Live Activity update and end calls)
```dart
unawaited(
  someAsyncCall()
      .catchError((Object _) {
        // non-fatal — tracking continues
      }),
);
```
Never `await` a non-critical async call (notification, Live Activity update) inside a synchronous state update path.

### `context.mounted` Guard After Await
**Source:** `lib/features/onboarding/screens/onboarding_screen.dart` line 107; `lib/features/trips/services/trip_actions.dart` lines 42, 48
**Apply to:** `onboarding_location_priming_screen.dart`
```dart
final result = await someAsyncCall();
if (!context.mounted) return;
// safe to use context below
```

### Error Swallowing (Deviation Rule 4)
**Source:** `lib/features/tracking/services/tracking_service_controller.dart` lines 120–124
**Apply to:** `live_activity_service.dart`, `tracking_providers.dart`
```dart
try {
  await nonCriticalAsyncCall();
} on Object {
  // intentionally swallowed — see Deviation Rule 4
}
```
Live Activity operations are additive; any failure must be swallowed and tracking must continue.

### `TraevyFonts.ui(...)` Text Styling
**Source:** `lib/features/onboarding/screens/onboarding_screen.dart` lines 56–79
**Apply to:** `onboarding_location_priming_screen.dart`
```dart
TraevyFonts.ui(
  size: <double>,
  weight: FontWeight.w700,   // or w400 / w500 / w600
  color: onSurface,          // or tokens.textDim / tokens.textMuted
  height: 1.5,               // optional
  letterSpacing: -0.6,       // optional, for headings only
)
```
Never use `TextStyle(...)` directly — always go through `TraevyFonts.ui(...)` for UI text.

### Riverpod Provider Declaration (Manual, No Code-Gen)
**Source:** `lib/features/tracking/providers/tracking_providers.dart` lines 52–56
**Apply to:** new `liveActivityServiceProvider` in `tracking_providers.dart`
```dart
final Provider<T> someProvider = Provider<T>(
  (ref) => T(...),
  name: 'someProvider',     // always include name for debug tooling
);
```
No `@riverpod` annotation — the Phase 1 D-12 constraint (analyzer version conflict) means ALL providers in this project are manual declarations. Do not introduce `@Riverpod` annotation until the ecosystem constraint is resolved.

---

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns + UI-SPEC.md contract instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `ios/TraevyLiveActivity/TraevyLiveActivityAttributes.swift` | native model | transform | First native ActivityKit `ActivityAttributes` struct in the project. No Swift analog exists. Use RESEARCH.md §3 `TraevyLiveActivityAttributes.swift pattern` code block as the starting point. |
| `ios/TraevyLiveActivity/TraevyLiveActivityWidget.swift` | native component | event-driven | First SwiftUI Widget Extension in the project. No SwiftUI source exists. Use UI-SPEC.md §Surface C/D layout spec + RESEARCH.md §Code Examples `SwiftUI Lock Screen Layout Structure` as the authoritative pattern. Closest structural context is `ios/Runner/AppDelegate.swift` (the Swift import/class declaration style). |
| `ios/TraevyLiveActivity/Localizable.strings` | native config | — | First native localization file. No analog. Use the SwiftUI `NSLocalizedString("key", comment: "")` convention; keys are defined in UI-SPEC.md §Copywriting Contract §Live Activity. |
| `ios/Runner/Info.plist` (two new keys) | native config | — | File exists; modification only. Pattern: insert two new `<key>/<true/>` pairs alongside the existing `NSSupportsLiveActivities`-absent block. Add after the `UIBackgroundModes` array. Also add a second `CFBundleURLSchemes` dict entry for `traevy` alongside the existing OAuth entry — keep both dicts inside the `CFBundleURLTypes` array. |

### Native iOS Integration Context

The Widget Extension target is a **new Xcode target** (not a Flutter file). The integration context is:
- `ios/Runner/AppDelegate.swift` — shows the Swift class declaration style: `import Flutter`, `import UIKit`, `@objc class Name: FlutterAppDelegate`
- `ios/Runner/Info.plist` — the existing plist shows the `<dict>` nesting pattern for `CFBundleURLTypes` that the new `traevy` URL scheme entry must match
- There is NO existing `ios/Runner.xcworkspace` modification to reference — the Widget Extension target addition is entirely Xcode UI work that modifies `project.pbxproj` automatically

---

## Metadata

**Analog search scope:** `lib/` (all Dart files), `ios/Runner/` (Swift/plist files)
**Files scanned:** 11 Dart analog files read in full; 2 Swift files; 1 plist; 1 routes file; 1 constants file
**Pattern extraction date:** 2026-06-03
