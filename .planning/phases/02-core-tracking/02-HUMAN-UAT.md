---
status: partial
phase: 02-core-tracking
source: [02-VERIFICATION.md, 02-DEVICE-CHECKLIST.md]
started: 2026-04-13
updated: 2026-04-13
---

## Current Test

[awaiting human testing on real Android 14 device]

## Tests

See `.planning/phases/02-core-tracking/02-DEVICE-CHECKLIST.md` for detailed steps, expected outcomes, and prerequisites. The checklist is the source of truth for these items — this UAT file is the tracking index.

### 1. Fresh install, soft-deny location permission
expected: HomeScreen renders; Start commute prompts for location; tapping Deny returns to HomeScreen without crash.
result: [pending]

### 2. Grant fine location from Start CTA
expected: Second Start tap succeeds after prior soft-deny; TrackingScreen renders with `foregroundOnly` banner (background permission not yet granted).
result: [pending]

### 3. Upgrade to background location
expected: Second Start tap (after fine granted) prompts to upgrade to ACCESS_BACKGROUND_LOCATION; accepting removes the banner.
result: [pending]

### 4. Record a normal trip (≥30s, ≥100m)
expected: Tiles tick with live values; Stop persists a row in Drift trips table with direction=unknown; snackbar "Trip saved"; shade returns to empty.
result: [pending]

### 5. Short-trip discard (D-10)
expected: A <30s or <100m trip shows "Trip too short to save" snackbar and does NOT persist to Drift.
result: [pending]

### 6. Background + screen off keeps recording
expected: Home button + screen lock does not stop recording. Returning to the app shows continued tile progression and the foreground notification stayed visible throughout.
result: [pending]

### 7. Notification Stop button
expected: Tapping the Stop action in the shade notification stops recording the same way as the in-app button.
result: [pending]

### 8. Single notification (D-14 unification tripwire)
expected: Throughout tracking there is exactly ONE notification in the Android shade with title "Recording commute". Never two.
result: [pending]

### 9. App kill + relaunch
expected: Force-stopping the app (via system settings) during tracking and relaunching → HomeScreen renders cleanly, no ghost trip in progress, no stale notification, no crash.
result: [pending]

### 10. Foreground service type = location
expected: `adb shell dumpsys activity services com.example.traevy | grep foregroundServiceType` shows `location`. Android 14 runtime rejects `startForeground()` without this.
result: [pending]

### 11. Permanent deny + settings CTA (D-09)
expected: Soft-denying then selecting "Don't ask again" → HomeScreen shows "Open settings" CTA when Start is tapped; tapping it opens the system app-settings page.
result: [pending]

## Summary

total: 11
passed: 0
issues: 0
pending: 11
skipped: 0
blocked: 0

## Gaps

None yet — awaiting human execution of the checklist.
