# Phase 15: Notifications, Permissions & Onboarding UX on iOS - Context

**Gathered:** 2026-06-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Make iOS's permission, notification, and active-commute surfaces correct and first-class. Three threads:

1. **iOS permission flows** — the two-step When-In-Use → Always location dance (requested at the right moments, with a valid degraded state) and notification permission, decoupled so notifications never gate tracking.
2. **Notification correctness** — the phantom Android foreground-service tracking notification is suppressed on iOS; the scheduled weekly-summary + departure-reminder notifications fire after permission is granted.
3. **Active-commute surface (SCOPE EXPANSION)** — on iOS 17+, an **interactive Live Activity** (lock screen + Dynamic Island) becomes the iOS tracking signal, and the existing Android ongoing notification is **enriched to match** it for cross-platform parity.

**In scope:**
- iOS location priming screen + When-In-Use prompt in onboarding (IOS-09)
- "Always" upgrade requested at first trip Start; degraded best-effort-background mode when only When-In-Use is granted (IOS-09)
- Platform-branched `preflight()` so notification permission is iOS-decoupled and never blocks Start (IOS-09/IOS-10)
- iOS notification permission requested ~1 week into usage (weekly-summary-timed); scheduled notifications fire (IOS-10)
- Suppress the Android persistent tracking notification on iOS — gate `startTrackingNotification()` behind `Platform.isAndroid` (IOS-11)
- **iOS 17+ Live Activity** for active commute: live stats + in-place Stop, fed by `TripAccumulator` stream (IOS-13) — native ActivityKit Widget Extension + Flutter bridge
- **Android notification parity**: enrich the existing "Active commute" foreground notification with the same live stats layout (IOS-14)

**Out of scope:**
- iOS < 17 Live Activity variants — below 17 degrades to blue-indicator-only with in-app Stop (no 16.x display-only middle tier)
- The real-device validation drives (background gaps, Live Activity behavior, permission prompts) — **human-gated**, run by the user; Phase 14's deferred device UAT folds into the same combined device pass
- Any Android tracking/notification behavior beyond the additive stats enrichment (foreground-service binding must not regress)
- Android 16 "Live Updates" API — deferred (would raise the Android floor; its own future phase)
- Auth (Phase 13, closed), the background-GPS engine itself (Phase 14), parity validation (Phase 16)

</domain>

<decisions>
## Implementation Decisions

### Location Permission Timing & Onboarding (IOS-09)
- **D-01:** Request **When-In-Use during onboarding**, preceded by **one location priming screen** ("We use your location to record commutes — your data stays on your device"). Do NOT prime Always or notifications.
- **D-02:** Request **"Always" at the first trip Start** (Apple's recommended contextual pattern — highest grant rate, and Start is exactly the moment background recording is needed). Not back-to-back in onboarding.
- **D-03:** When the user is still **When-In-Use-only** on a later Start (iOS only shows the Always system prompt once and won't re-prompt): **proceed in degraded mode** + show a one-line **dismissible hint with an "Open Settings" deep-link**. Never block recording.

### When-In-Use Degraded Mode (IOS-09)
- **D-04:** Degraded = **best-effort background recording**: still start the geolocator stream with `allowBackgroundLocationUpdates: true` (blue bar shows); iOS often allows provisional background updates under When-In-Use but may suspend on long screen-off stretches. **Warn the track may have gaps** until Always is enabled. (Matches Phase 14's HUMAN-UAT note: background gaps under When-In-Use are expected, not a defect.)
- **D-05:** Surface the degraded state by **reusing the existing `permission_banner` / `TrackingPermissionStatus.foregroundOnly`** path, branching copy by platform — iOS: "Enable Always for gap-free tracking" + Open-Settings CTA. One surface, no new widget.

### Notification Decoupling & Timing (IOS-10)
- **D-06:** **Platform-branch `preflight()`**: on iOS the dance ends after location — it never probes/requests `Permission.notification` and never returns `notificationDenied`. **Tracking Start depends only on location** (+ Live Activity). Android's four-step dance stays byte-for-byte unchanged.
- **D-07:** Request iOS notification permission **~1 week into usage**, timed to when the **first weekly summary** becomes meaningful — not up front, not per-reminder. **Edge:** if the user enables a **departure reminder** before the 1-week mark, request at that point too (otherwise it can't fire). [Claude's discretion on exact "1 week" anchor — first launch vs first trip — confirm in planning.]

### iOS Active-Commute Surface — Live Activity (IOS-13) [SCOPE EXPANSION]
- **D-08:** On **iOS 17+**, an active commute shows an **interactive Live Activity** (lock screen + Dynamic Island) with **live elapsed time, distance, moving/stuck status, and direction (to_office/to_home)**, plus an **in-place Stop button**. The Stop button requires **App Intents (iOS 17+ floor)** wired to the tracking controller's stop path.
- **D-09:** **iOS 17+ is the floor** for the Live Activity (older iOS is <10% of the userbase). iOS < 17 → **blue-location-indicator-only, Stop stays in-app** (the original SC #3 behavior). No 16.1–16.x display-only middle tier.
- **D-10:** The Live Activity is driven by **local ActivityKit updates** from the existing `TripAccumulator` snapshot stream (the same 1 Hz shapes `TrackingNotifier` consumes) — **no push server**. It is **dismissed when the trip stops**. [Bridge mechanism is Claude's-discretion + research — see below.]

### Tracking-Notification Suppression (IOS-11)
- **D-11:** Gate `startTrackingNotification()` (and the `TrackingNotificationService.show()` path) behind **`Platform.isAndroid`** so no phantom notification is posted on iOS. This confirms Phase 14 D-07. The iOS active surface is the Live Activity (17+) / blue bar (<17), never a UNNotification.

### Android Notification Parity (IOS-14)
- **D-12:** **Enrich the existing Android "Active commute" foreground notification** to show the same live stats layout (elapsed / distance / moving-stuck) as the iOS Live Activity, for visual parity. **Hard constraint: no regression to the foreground-service binding** (`AndroidConfiguration.foregroundServiceNotificationId`, the single-shade-entry id/channel behavior, stop-race guards). Additive only.

### Claude's Discretion
- **Live Activity bridge:** `live_activities` pub plugin vs a custom platform channel + native ActivityKit Widget Extension. Decide in research per maintenance/fit; either way a native Swift/SwiftUI Widget Extension is required, with `NSSupportsLiveActivities: YES` in Info.plist.
- Dynamic Island compact/minimal/expanded layouts (what each presentation shows) — design in UI-SPEC / planning.
- Exact "1 week of usage" anchor for the notification prompt (D-07).
- Whether the Stop App Intent ends the trip directly or deep-links + ends — wire to the existing `TrackingServiceController.stop()` either way.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### This phase / requirements
- `.planning/ROADMAP.md` §Phase 15 — goal + 6 success criteria (rewritten 2026-06-03; SC #3 now Live-Activity-based, SC #5/#6 added)
- `.planning/REQUIREMENTS.md` §Permissions, Notifications & UX on iOS — IOS-09, IOS-10, IOS-11, IOS-13 (Live Activity), IOS-14 (Android parity)

### Prior context (READ before touching these areas)
- `.planning/phases/14-background-gps-platform-branch/14-CONTEXT.md` — D-07 (iOS = CoreLocation indicator, no foreground notification; Phase 15 implements the actual gate), the `Platform.isIOS` engine selection, `AppleSettings` params, the `TripAccumulator` reuse seam
- `.planning/phases/02-core-tracking/02-CONTEXT.md` — original Android tracking permission dance (D-07 two-step, D-08 banner, D-09 open-settings) + UX-03 foreground notification that IOS-14 enriches

### Existing code (READ before modifying)
- `lib/features/tracking/services/tracking_permission_service.dart` — the `preflight()` / `currentStatus()` four-step dance + `TrackingPermissionStatus` enum; D-06 platform-branch goes here (the `notificationDenied` coupling must NOT apply on iOS)
- `lib/features/tracking/widgets/permission_banner.dart` + `permission_gate.dart` — the `foregroundOnly` banner reused for the iOS degraded state (D-05)
- `lib/features/tracking/services/tracking_notification_service.dart` — UX-03 Android foreground notification; gate behind `Platform.isAndroid` (D-11) AND enrich its stats layout (D-12); has `DarwinNotificationDetails` today (would post on iOS — must be suppressed)
- `lib/notifications/notification_service.dart` — scheduled weekly-summary + departure-reminder; Darwin init has `requestAlertPermission: false` (defers iOS notif permission to our flow, D-07)
- `lib/features/tracking/services/trip_accumulator.dart` — pure-Dart snapshot stream feeding the Live Activity (D-10) and the enriched Android notification (D-12)
- `lib/features/tracking/services/tracking_service_controller.dart` — `stop()` path the Live Activity Stop App Intent wires to (D-08)
- `lib/features/onboarding/screens/onboarding_screen.dart` — auth-only today; add the location priming screen (D-01)
- `ios/Runner/Info.plist` — add `NSSupportsLiveActivities: YES` (D-08/Claude's discretion); already has `UIBackgroundModes: location`

### External docs to gather during research
- Apple ActivityKit / Live Activities + Dynamic Island + WidgetKit (App Intents for the iOS 17+ interactive Stop button) — backgrounded local-update model, runtime/duration limits over a 30–60 min commute

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TrackingPermissionService.preflight()` / `currentStatus()` — the When-In-Use → Always dance already exists; iOS branch is additive (strip the notification step). The strict ordering invariants (Always never touched before When-In-Use resolves) carry over.
- `TrackingPermissionStatus.foregroundOnly` + `permission_banner.dart` — directly reused for the iOS degraded state with platform-branched copy (D-05).
- `TripAccumulator` snapshot stream — the single source feeding BOTH new surfaces (iOS Live Activity D-10 + enriched Android notification D-12), no new data plumbing.
- `TrackingServiceController.stop()` — the existing stop path the Live Activity Stop button wires into.

### Established Patterns
- Sealed-class state + Riverpod `Notifier` (`TrackingState`, `TrackingPermissionStatus`); the iOS branches extend these, not new state systems.
- The Android foreground notification's single-shade-entry id/channel unification (Phase 2 D-14) and stop-race guard — must survive IOS-14 enrichment unchanged.

### Integration Points
- `tracking_permission_service.dart` — `Platform`/`defaultTargetPlatform` branch in `preflight()`/`currentStatus()` (D-06).
- `tracking_notification_service.dart` — `Platform.isAndroid` gate (D-11) + stats enrichment (D-12).
- New native iOS: ActivityKit Widget Extension target + Flutter bridge (plugin or platform channel) ↔ `TripAccumulator` stream and `TrackingServiceController.stop()`.
- `onboarding_screen.dart` — new location priming screen (D-01).

</code_context>

<specifics>
## Specific Ideas
- The Live Activity is the iOS premium analog of Android's ongoing foreground notification — the user explicitly wants both surfaces to show the same live stats (elapsed / distance / moving-stuck) for parity.
- iOS 17+ floor is a deliberate product call (older iOS <10% of users) — the interactive Stop button (App Intents) justifies it; below 17 falls back cleanly to blue-bar + in-app Stop.
- Notification permission is intentionally a LATE, contextual ask (~1 week), not an onboarding gate — keep the onboarding permission footprint to location-only.

</specifics>

<deferred>
## Deferred Ideas
- **Android 16 "Live Updates"** (promoted progress-style ongoing notifications) as a true Live-Activity analog — new API, raises Android floor, not in current stack. Future phase if Android parity is later pushed beyond the enriched notification.
- **iOS 16.1–16.x display-only Live Activity** middle tier — explicitly cut; iOS < 17 degrades straight to blue-bar.

None — discussion stayed within phase scope (the Live Activity expansion was a deliberate, user-approved scope change captured above, not creep left unaddressed).

</deferred>

---

*Phase: 15-notifications-permissions-onboarding-ux-on-ios*
*Context gathered: 2026-06-03*
