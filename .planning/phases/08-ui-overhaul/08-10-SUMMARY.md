---
plan_id: 08-10
phase: 08
gap_closure: true
status: complete
completed: 2026-05-15
commits:
  - f3ee8e4
---

## Plan 08-10 — Live-updating recording notification (cross-platform)

Closes Phase 8 UAT gap 3: the active-commute notification didn't reflect the Traevy design (basic Phase-7 foreground-service text only). Now shows direction-aware title + live-updated stat row + OPEN/STOP actions, on both Android and iOS.

### Strategy decision (deviation from original plan)

The original 08-10 plan called for **custom Android RemoteViews + 6 XML layout/drawable files + Kotlin platform-channel work**. That path is Android-only and would force a parallel iOS Live-Activity rewrite later when iPhone support arrives.

Per user direction ("build it in such a way that we can also add iphone support in future"), switched to **`flutter_local_notifications` cross-platform features only**:

| Aspect | Original plan | Shipped |
|--------|--------------|---------|
| Title | "Recording your commute to office" | ✅ Same — direction substituted at render time |
| Body / live stats | Custom RemoteViews TextView (mono font) | `BigTextStyle` body (Android) + plain body (iOS) — system font |
| REC pill | Custom drawable in XML | `● REC` prefix in body |
| Avatar | Custom rounded drawable | App icon (already Traevy-branded) |
| OPEN/STOP buttons | Custom RemoteViews + PendingIntents | `AndroidNotificationAction` + `DarwinNotificationAction` (both wired today) |
| Live updates | RemoteViews `setTextViewText` | Re-call `_plugin.show(id, ...)` (idempotent on shared channel+id) |
| iOS support | Would need full Live-Activity rewrite | **Wired today** via `DarwinInitializationSettings` + `DarwinNotificationCategory` |
| Kotlin / XML | 6 new files | None |

**Trade-off:** Notification isn't pixel-perfect to the design screenshot (no rounded badge drawable, no bordered REC pill, system font in stats instead of JetBrains Mono). All structural elements (title + live stats + 2 actions) and behavior preserved.

**Future "design v2"** can layer custom RemoteViews on Android and Live Activities on iOS as additive platform code behind the same `TrackingNotificationService` Dart interface — no Dart contract churn required.

### What changed

**`lib/config/constants.dart`** — added 5 constants:
- `kTrackingOpenActionId = 'open_app'`
- `kTrackingOpenActionLabel = 'Open'`
- `kTrackingNotificationCategoryId = 'traevy_recording'` (iOS)
- `kTrackingNotificationTitleTemplate = 'Recording your commute to {direction}'`
- `kTrackingNotificationBodyTemplate = '● REC  {elapsed} elapsed · {km} km · {stuck} stuck'`

**`lib/features/tracking/services/tracking_notification_service.dart`** — major refactor:
- `initialize()` adds `DarwinInitializationSettings` with a `DarwinNotificationCategory` registering OPEN+STOP — these surface as action buttons when the notification is expanded on iOS.
- `showRecording()` signature changed from no-args to optional named args (`elapsedSeconds`, `distanceMeters`, `timeStuckSeconds`, `direction`). The placeholder ready-event call (no args) still works thanks to defaults.
- Title rendered from template with `{direction}` replaced by 'office'/'home' (resolved from `kDirectionToHome`/`kDirectionToOffice`).
- Body rendered with `formatDuration()` for elapsed, `(meters/1000).toStringAsFixed(1)` for km, and a new compact `_formatStuck()` helper (`Xm` under an hour, `XhYm` over).
- Body uses `BigTextStyleInformation` on Android so the long stat row wraps when the notification is expanded.
- OPEN action button added alongside STOP — flagged `showsUserInterface: true` (Android) and `DarwinNotificationActionOption.foreground` (iOS) so tapping resumes the app.
- Foreground + background response handlers ignore the OPEN action id (platform handles resume); only STOP routes through `kStopTrackingEvent`.

**`lib/features/tracking/providers/tracking_providers.dart`**
- `_stateSub` listener now refreshes the notification on every `TrackingActive` snapshot. The plugin's `show()` is idempotent on the shared `(channelId, notificationId)` — calling it again overwrites the existing notification's title/body without re-triggering sound/vibration (`onlyAlertOnce: true`).
- Wrapped in `unawaited(...).catchError(...)` so a `POST_NOTIFICATIONS` denial doesn't crash the snapshot pipeline.

**Test stubs** updated:
- `_NoopNotifications` (`tracking_notifier_test.dart`) — `showRecording()` signature widened to match.
- `_RecordingNotifications` (`persist_finalized_trip_test.dart`) — same.

### iOS scaffolding (live but inert)

The Darwin init settings and `DarwinNotificationCategory` are wired today, but iOS support is dormant until `ios/Runner` is added to the project. When iOS is added later:
1. Create `ios/Runner` via `flutter create --platforms=ios .`
2. Add `iOSFlutterLocalNotificationsPlugin` permission flow to the existing `TrackingPermissionService`
3. Set up iOS-specific `BGTaskScheduler` for background tracking (separate concern)
4. The notification code itself needs **zero changes** — `DarwinNotificationDetails` and `DarwinNotificationCategory` will activate automatically.

### Verification

- `flutter analyze lib/` — no errors (4 info-level `prefer_const_constructors` lints, all in the new file)
- `flutter test` — **273/273 pass**

### Manual smoke test (deferred to user)

- Start a trip → notification appears with "Recording your commute to office" + live stats + OPEN+STOP buttons
- Stats refresh on every 1Hz tick (matches in-app `ElapsedDisplay`)
- Tap STOP from the notification → trip ends without app foreground (D-14 unification)
- Tap OPEN → app comes to foreground on whichever tab the user was last on (MainShell preserves tab state)
- After Stop, notification dismisses automatically (existing `dismiss()` path unchanged)

### Execution path

Originally launched as a parallel `gsd-executor` agent in a worktree but stalled on the Anthropic stream watchdog (4th stall today). Executed inline using the plan as the spec, with the strategy revision noted above.

### Key files modified

- `lib/config/constants.dart`
- `lib/features/tracking/services/tracking_notification_service.dart`
- `lib/features/tracking/providers/tracking_providers.dart`
- `test/unit/features/tracking/persist_finalized_trip_test.dart`
- `test/unit/features/tracking/tracking_notifier_test.dart`
