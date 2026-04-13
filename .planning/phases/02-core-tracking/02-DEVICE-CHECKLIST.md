---
phase: 02-core-tracking
plan: 02-06
artifact: device-checklist
target_platform: Android 14 (API 34) on a real device — emulator is NOT acceptable
requires:
  - debug APK built from the tip of phase 2 (`flutter build apk --debug`)
  - Android device with Developer Options + USB debugging enabled
  - `adb` available on the host for optional Drift sqlite inspection
tripwires:
  - D-14 unification contract (a single notification in the shade, never two)
  - UX-03 foreground notification survives backgrounding and screen-off
  - D-10 short-trip discard (snackbar + no Drift row)
  - Foreground service type = location (Android 14 requirement)
  - No ghost trip in progress after app kill + relaunch
---

# Phase 2 — Core Tracking: Manual Device Verification Checklist

This checklist exists because the Flutter widget test framework cannot
exercise the Android 14 runtime behaviours that Phase 2 is built on:
actual GPS fixes, foreground-service survival across backgrounding and
screen-off, notification shade interactions, the D-14 single-entry
unification guarantee, and battery-optimisation edge cases.

The unit and widget test suites (64 tests + 15 widget tests as of plan
02-06) cover everything else. **The phase is not complete until every
row in the Results table below reads `PASS`.** If any row fails, stop
and open a gap-closure plan — do not ship Phase 2 with a failing row.

## Prerequisites

1. Real Android 14 device (API level 34). Emulator GPS simulation is
   unreliable for traffic calculations per CLAUDE.md.
2. Device paired over USB with `adb devices` confirming it is `device`
   (not `unauthorized`).
3. Fresh install from a debug APK built at the tip of phase 2:
   ```bash
   flutter build apk --debug
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```
4. All Traevy permissions revoked before starting. If the app was
   installed previously, clear its data first:
   ```bash
   adb shell pm clear com.example.traevy
   ```
5. Device location services (system toggle, NOT just the app grant) are
   ON.

## Checklist

Each row is independently verifiable. Walk them in order; a failure in
an earlier row usually blocks later rows.

### 1. Fresh install — permissions all denied

- [ ] Launch app after `pm clear`. HomeScreen renders with the
      "Start commute" CTA visible.
- [ ] Tap "Start commute". Permission dialog appears requesting
      location (fine / "while using app").
- [ ] **Tap Deny (without the "don't ask again" checkbox).** You return
      to HomeScreen.

**Objective:** The first prompt surfaces correctly and a soft deny does
not crash or silently succeed.

### 2. Grant fine location from the tracking screen CTA

- [ ] Tap "Start commute" again. The system prompts for location
      again (soft-deny is re-askable).
- [ ] Tap **Allow / While using the app**. TrackingScreen renders.
- [ ] The screen shows the `foregroundOnly` banner at the top
      (background permission is not yet granted).

**Objective:** D-07 two-step flow upgrades cleanly from denied →
foreground, and the D-08 banner appears for users who do not grant
background location.

### 3. Upgrade to background location on first Start

- [ ] From the foregroundOnly banner, tap Open settings. Switch the
      Traevy app's location permission to "Allow all the time" in
      system settings. Return to the app.
- [ ] Re-enter TrackingScreen. The banner is now gone.
- [ ] Tap the big Start button. The tracking service spins up.

**Objective:** Background location upgrade works, and the banner
disappears after the upgrade.

### 4. Live tiles tick with real GPS samples

- [ ] After Start, the three tiles begin ticking:
  - **Duration** advances by roughly 1 second every second.
  - **Distance** stays at `0 m` initially, then grows once the device
    accumulates ≥ `kTrackingMaxAcceptableAccuracyMeters` worth of
    displacement.
  - **Speed** reflects movement when walking or driving (not pinned to
    `0 km/h` and not garbage like `500 km/h`).
- [ ] Walk or drive for **at least one minute** with the phone in hand
      so the GPS is warm.

**Objective:** TRACK-01 and TRACK-02 — live, sensible values. The
`kTrackingMaxAcceptableAccuracyMeters = 30` filter means tiles may
initially show `0 m` for several seconds until a good fix is acquired;
this is intentional.

### 5. UX-03 foreground notification appears with a Stop action

- [ ] Within ~1 second of Start, the notification shade shows **exactly
      one** Traevy entry titled "Recording commute".
- [ ] The entry is **non-dismissible** (swipe leaves it in place) and
      shows a visible **Stop** action button.
- [ ] **Tripwire — D-14 unification:** There is **never a second**
      Traevy notification (e.g. the `flutter_background_service` stock
      "Recording commute" entry sitting alongside the UX-03 one).
      If you see two, the `channelId` or `notificationId` constants
      drifted.

**Objective:** UX-03 and D-14. A single shade entry proves the
unification contract holds at runtime.

### 6. Stop from inside the app persists the trip

- [ ] While tracking is active and the tiles show ≥ 30 s and ≥ 100 m,
      tap the in-app Stop button.
- [ ] A transient "Saving trip..." state appears, then HomeScreen
      returns to `TrackingIdle`.
- [ ] The notification disappears from the shade.
- [ ] Optional Drift inspection via adb — a new row exists in `trips`
      with non-zero moving/stuck seconds and a non-empty
      `route_polyline`:
  ```bash
  adb shell "run-as com.example.traevy cat databases/traevy.sqlite" \
    > /tmp/traevy.sqlite
  sqlite3 /tmp/traevy.sqlite \
    'SELECT id, duration_seconds, distance_meters, time_moving_seconds,
            time_stuck_seconds FROM trips ORDER BY created_at DESC LIMIT 1;'
  ```
  (Skip the Drift dump if `run-as` is not available; confirm indirectly
  by checking that the next trip also persists.)

**Objective:** TRACK-04 + TRACK-05 atomic persistence. The
`sync_queue` table should also contain a matching `create` row with
`status='pending'`.

### 7. Short-trip discard shows snackbar and writes nothing

- [ ] Start a second trip. **Immediately** stop it (< 30 s elapsed,
      < 100 m walked). Staying seated works — the duration threshold
      is checked first.
- [ ] A Material snackbar appears at the bottom of the tracking screen
      reading exactly `Trip too short to save`.
- [ ] No new row is added to `trips` (verify via the adb dump above or
      indirectly by confirming the trip count from step 6 is unchanged).
- [ ] The notification is dismissed regardless.

**Objective:** D-10 short-trip discard. The snackbar string is an
exact-match contract; if it reads anything else the UX regresses.

### 8. Background survival — home button + screen off

- [ ] Start a third trip. Walk for ~15 seconds with the app foregrounded
      so GPS is warm.
- [ ] Press the **Home** button to background the app. The notification
      remains in the shade with the Stop action still visible.
- [ ] **Lock the screen.** Walk for another minute.
- [ ] Unlock the screen, re-open the app. The Duration tile shows the
      full elapsed time (~ 1 min 15 s), not a value that pauses while
      backgrounded.
- [ ] The notification is still in the shade.

**Objective:** UX-03 background survival. If Duration reset while
backgrounded, the foreground-service promotion is broken.

### 9. Stop from the notification shade (app still backgrounded)

- [ ] Continue from step 8 without foregrounding the app. Tap the
      **Stop** action button in the notification shade.
- [ ] The notification disappears within ~1 second.
- [ ] Foreground the app. HomeScreen is showing (the tracking screen
      is gone because state returned to `TrackingIdle`).
- [ ] A new trip row exists in `trips` with end_time matching the
      moment you tapped Stop in the shade.

**Objective:** D-14 Stop action handler routes through the
`@pragma('vm:entry-point')` background handler when the foreground
`_onForegroundResponse` is not available.

### 10. Kill + relaunch — no ghost trip in progress

- [ ] Start a fourth trip. Confirm tiles are ticking.
- [ ] Force-kill the app from the system recents screen (swipe away)
      while tracking is active.
- [ ] The foreground-service notification will typically disappear
      because the isolate is gone. That is acceptable per D-06
      (in-memory samples, best-effort only).
- [ ] Relaunch the app. HomeScreen shows `TrackingIdle` (no ghost
      `TrackingActive` state, no stale "Saving trip..." spinner, no
      orphaned notification).
- [ ] No partial row exists in `trips` for the killed trip (D-06
      accepts sample loss; what is NOT acceptable is a half-written
      row).

**Objective:** D-06 accepted-tradeoff surface area. The app must come
back clean after a kill, even though the in-progress samples are
legitimately lost.

### 11. Repeat the backgrounded flow with battery optimisation unrestricted

- [ ] In system Settings → Apps → Traevy → Battery, set the app to
      **Unrestricted** (Android 14 label may vary by OEM).
- [ ] Repeat steps 8 and 9 end-to-end.
- [ ] Same pass criteria apply: live tiles keep advancing, notification
      persists, Stop from shade finalises the trip.

**Objective:** Known OEM battery-kill risk. Stock Android 14 should
pass; aggressive OEMs (Samsung, Xiaomi, Huawei) may not — if this row
fails only on a specific OEM, document the device and defer the fix to
a later polish phase per RESEARCH §17 #3.

## Results

Fill in `PASS` or `FAIL <reason>` for each row. Do **NOT** mark a row
`PASS` without actually performing the step on a real device.

| # | Row | Result |
|---|-----|--------|
| 1 | Fresh install — permissions all denied | _(TBD by human verifier)_ |
| 2 | Grant fine location from the tracking screen CTA | _(TBD by human verifier)_ |
| 3 | Upgrade to background location on first Start | _(TBD by human verifier)_ |
| 4 | Live tiles tick with real GPS samples | _(TBD by human verifier)_ |
| 5 | UX-03 foreground notification appears with a Stop action | _(TBD by human verifier)_ |
| 6 | Stop from inside the app persists the trip | _(TBD by human verifier)_ |
| 7 | Short-trip discard shows snackbar and writes nothing | _(TBD by human verifier)_ |
| 8 | Background survival — home button + screen off | _(TBD by human verifier)_ |
| 9 | Stop from the notification shade (app backgrounded) | _(TBD by human verifier)_ |
| 10 | Kill + relaunch — no ghost trip in progress | _(TBD by human verifier)_ |
| 11 | Repeat backgrounded flow with battery optimisation unrestricted | _(TBD by human verifier)_ |

## Sign-off

- **Device model:** _(TBD)_
- **Android version + build number:** _(TBD)_
- **APK commit SHA (first 8 chars):** _(TBD — `git rev-parse --short HEAD`
  at the time of the `flutter build apk --debug` invocation)_
- **Date of verification:** _(TBD)_
- **Verifier:** _(TBD)_

Resume signal for the orchestrator:

- Reply `approved` if every row reads `PASS`.
- Reply `failed: <row number>: <explanation>` if any row failed.
- Reply `skipped: <reason>` if a real device is unavailable. This is a
  phase-gate deviation and should be recorded in STATE.md with a
  follow-up task.
