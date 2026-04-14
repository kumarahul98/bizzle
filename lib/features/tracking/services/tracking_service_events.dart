// Service ↔ UI isolate event-name constants for the Phase 2 tracking
// feature.
//
// These three constants are deliberately NOT in `lib/config/constants.dart`.
// They are the private coupling contract between three files inside the
// tracking feature:
//
//   * `tracking_service.dart` — the background-isolate producer of
//     `kTrackingStateEvent` / `kTripFinalizedEvent` and the consumer of
//     `kStopTrackingEvent`;
//   * `tracking_service_controller.dart` — the UI-isolate wrapper that
//     invokes `kStopTrackingEvent` on the service;
//   * `tracking_notification_service.dart` — the UX-03 notification wrapper
//     whose Stop action button also invokes `kStopTrackingEvent`;
//   * `tracking_providers.dart` — the `TrackingNotifier` that subscribes
//     to `kTrackingStateEvent` and `kTripFinalizedEvent`.
//
// Surfacing these strings in the global `constants.dart` would invite
// unrelated features to reuse them, which is architecturally wrong — the
// service isolate's invoke channel is a local protocol, not a cross-feature
// concept. Keeping them in a feature-local file preserves that intent
// while still giving every producer and consumer a single source of truth.
//
// Plan 02-03 originally defined these constants inside `tracking_service.dart`.
// Plan 02-05 lifted them into this file so `tracking_notification_service.dart`
// can import `kStopTrackingEvent` without creating a file-level dependency on
// `tracking_service.dart`'s isolate entrypoint.

/// Event name for the 1 Hz snapshot stream from service → UI isolate.
const String kTrackingStateEvent = 'tracking_state';

/// Event name for the finalised trip payload from service → UI isolate.
const String kTripFinalizedEvent = 'trip_finalized';

/// Event name for the stop command from UI → service isolate.
const String kStopTrackingEvent = 'stop_tracking';

/// Event name for an unrecoverable service-isolate failure (e.g. the
/// Geolocator position stream emits an error mid-trip). The service
/// isolate invokes this channel with a `{'reason': <string>}` payload —
/// the reason is deliberately a stable short string so `TrackingNotifier`
/// can map it to a user-facing `TrackingError` message without ever
/// logging raw platform error text (which may contain PII such as
/// lat/lng coordinates per T-02-07).
const String kTrackingErrorEvent = 'tracking_error';

/// Event name for the service-ready signal from service → UI isolate.
///
/// The service isolate emits this immediately after
/// `setAsForegroundService()` completes on Android. The UI isolate uses
/// it as the trigger to re-post the UX-03 notification with the Stop
/// action button, overwriting the action-less placeholder that
/// `startForeground()` posted internally (D-14 race resolution — see
/// `tracking_notification_service.dart` file comment).
const String kServiceReadyEvent = 'service_ready';
