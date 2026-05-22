---
status: complete
phase: 08-ui-overhaul
source: [08-08-SUMMARY.md, 08-09-SUMMARY.md, 08-10-SUMMARY.md]
started: 2026-05-15T11:00:00Z
updated: 2026-05-15T11:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Notification — title shows direction
expected: While a trip is recording, pull down the notification shade. The notification title reads "Recording your commute to office" (or "to home" if evening), not the old "Recording commute".
result: pass

### 2. Notification — body shows live stats with REC marker
expected: The notification body shows "● REC  MM:SS elapsed · X.X km · Xm stuck" and refreshes ~once per second matching the in-app ELAPSED counter. No empty body.
result: pass

### 3. Notification — OPEN and STOP action buttons present
expected: Two action buttons visible on the notification: OPEN (left) and STOP (right). Previously only STOP existed.
result: pass

### 4. Notification — STOP from notification while app backgrounded
expected: Tap STOP on the notification while the app is in background. The trip ends, the notification disappears, and the app does NOT come to foreground.
result: pass
note: |
  User observation (2026-05-15): tapping STOP stops the trip AND brings the app to the foreground. This is the documented Android 14+ trade-off — `showsUserInterface: true` is required on minSdk 34 so the action handler's `actionId` is delivered (broadcast PendingIntents arrive as `selectedNotification` with a null actionId on Android 14, and the STOP guard never fires). The brief foreground bring-to-front is the accepted cost. User confirmed behavior is acceptable.

### 5. Notification — OPEN from notification brings app to foreground
expected: Tap OPEN. The app comes to the foreground on whichever MainShell tab was last open (Today / Trips / Stats / Settings). Recording continues.
result: pass

### 6. Notification — silent refresh (no flicker, no sound)
expected: While recording, the notification body updates each second without flashing, sound, or vibration. The notification stays in the same position in the shade.
result: pass

### 7. Notification — auto-dismisses on Stop
expected: After tapping STOP (either in-app or from the notification), the notification disappears from the shade automatically. It never lingers after the trip ends.
result: pass

### 8. SPEED tile decays to 0 when stationary
expected: While recording, drive then come to a complete stop (or just stand still if testing on foot). Within ~6 seconds of stopping, the in-app SPEED tile drops to 0 km/h. Pre-fix it was stuck at the last in-motion value (e.g., 42 km/h).
result: pass

### 9. Hero card — single tap starts recording in place
expected: From the dashboard, tap the big red START button once. Recording begins immediately. The hero card transforms in place to show the RECORDING header + ELAPSED timer + DISTANCE/SPEED/STUCK tiles + Stop button. NO navigation to a separate tracking screen.
result: pass

### 10. Hero card — dashboard scroll stays usable while recording
expected: With a trip recording in the hero card, scroll down on the dashboard. TodaySection and WeekLossCard scroll smoothly underneath the hero. Tap a trip in TodaySection — it opens normally.
result: pass

### 11. Hero card — MainShell tabs stay usable while recording
expected: With a trip recording, tap Trips, Stats, and Settings tabs in MainShell's NavigationBar. Each tab switches successfully and the recording continues uninterrupted. Returning to Today still shows the active hero.
result: pass

## Summary

total: 11
passed: 11
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
