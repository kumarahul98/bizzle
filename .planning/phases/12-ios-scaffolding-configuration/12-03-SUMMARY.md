---
phase: 12-ios-scaffolding-configuration
plan: 03
subsystem: infra
tags: [ios, xcode, signing, free-provisioning, developer-mode, apple-id]

# Dependency graph
requires:
  - phase: 12-02
    provides: Info.plist keys, entitlements (Keychain Sharing), GoogleService-Info.plist, bundle ID com.travey.app
provides:
  - Physical iPhone install: app signed with DEVELOPMENT_TEAM 2DG5SFXZ5Z and launched on Rahul's iPhone
  - project.pbxproj with DEVELOPMENT_TEAM and com.travey.app in all 3 build configurations
  - IOS-02 milestone gate satisfied: real-device install and launch confirmed
affects: [phase-13-auth-ios, phase-14-background-gps, phase-15-notifications-permissions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Free-provisioning sign: Automatically manage signing in Xcode with free Apple ID (DEVELOPMENT_TEAM 2DG5SFXZ5Z); profile expires every 7 days and must be refreshed"
    - "aps-environment entitlement absent from personal-team builds: free/personal Apple IDs cannot provision Push Notifications; local notifications (flutter_local_notifications) require no plist entitlement"

key-files:
  created: []
  modified:
    - ios/Runner.xcodeproj/project.pbxproj
    - ios/Runner/DebugProfile.entitlements
    - ios/Runner/Release.entitlements

key-decisions:
  - "Removed aps-environment (Push Notifications) from both DebugProfile.entitlements and Release.entitlements — free/personal Apple teams cannot provision Push Notifications; the app uses only flutter_local_notifications (local, no aps-environment needed)"
  - "DEVELOPMENT_TEAM 2DG5SFXZ5Z (Personal Team, Rahul kumar) committed to project.pbxproj — standard practice, non-secret"
  - "On-device certificate trust was not separately required for this install (Xcode provisioned directly without a trust prompt)"
  - "Free provisioning install date 2026-06-02; certificate expires 2026-06-09 — must re-sign before next device run after that date"

patterns-established:
  - "Re-sign cadence: free provisioning certificates expire every 7 days; re-open ios/Runner.xcworkspace in Xcode, let it reprovision, then run flutter run again"

requirements-completed: [IOS-02]

# Metrics
duration: human-gated (wall-clock); automation <5min
completed: 2026-06-02
---

# Phase 12 Plan 03: Real-Device Signing and Install Summary

**App signed with Xcode free provisioning (DEVELOPMENT_TEAM 2DG5SFXZ5Z, bundle com.travey.app), installed on a physical iPhone (iOS 26.5), and confirmed launched — IOS-02 milestone gate satisfied**

## Performance

- **Duration:** human-gated (wall-clock); automated steps < 5 min
- **Started:** 2026-06-02
- **Completed:** 2026-06-02
- **Tasks:** 2 (both human-gated checkpoints, both satisfied)
- **Files modified:** 3 (project.pbxproj, DebugProfile.entitlements, Release.entitlements)

## Accomplishments

- Xcode free provisioning configured: Personal Team 2DG5SFXZ5Z selected, "Automatically manage signing" on, bundle ID com.travey.app.
- Developer Mode enabled on iPhone (iOS 26.5, device 00008110-00115119260A401E) and device restarted; device appeared in `flutter devices` as "Rahul's iPhone", available.
- `flutter run -d 00008110-00115119260A401E` completed (Xcode build 68.9 s), signed, installed, and launched on the device; user confirmed the app renders its first screen (debug banner visible, normal for debug build).
- On-device certificate trust was not separately required — Xcode install succeeded without a manual trust prompt.
- IOS-02 requirement satisfied: real-device install and launch confirmed on hardware.

## Task Commits

1. **Task 1: Select signing team and enable Developer Mode** — human-action checkpoint; Xcode signing selection and Developer Mode performed by user; `aps-environment` entitlement removal committed by orchestrator as `b261537`
2. **Task 2: Install and launch on physical iPhone** — human-verify checkpoint; `flutter run` build/install/launch confirmed; signing config committed `facc17b`

**Plan metadata:** (see final commit in this SUMMARY)

## Files Created/Modified

- `ios/Runner.xcodeproj/project.pbxproj` — DEVELOPMENT_TEAM = 2DG5SFXZ5Z added to Debug, Profile, and Release build configurations (3 occurrences); com.travey.app bundle ID confirmed in all 3 configs (commit `facc17b`)
- `ios/Runner/DebugProfile.entitlements` — `aps-environment` key removed; `keychain-access-groups` and `get-task-allow` retained (commit `b261537`)
- `ios/Runner/Release.entitlements` — `aps-environment` key removed; `keychain-access-groups` retained (commit `b261537`)

## Decisions Made

- Removed `aps-environment` (Push Notifications entitlement) from both entitlement files. Free/personal Apple ID teams cannot provision Push Notifications — Xcode rejects the profile if the entitlement is present. The app uses only `flutter_local_notifications` (local notifications), which do not require `aps-environment`. This unblocked profile creation without affecting any notification functionality.
- Committed DEVELOPMENT_TEAM identifier (2DG5SFXZ5Z) to git — this is the team ID from a free Apple ID, not a secret credential; Xcode and standard community practice commit it.
- On-device certificate trust step was not required this run; Xcode's signing profile was accepted by the device without a manual Settings > VPN & Device Management trust action.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Removed aps-environment from both entitlement files**
- **Found during:** Task 1 (Select signing team and enable Developer Mode)
- **Issue:** `DebugProfile.entitlements` and `Release.entitlements` both contained the `aps-environment` key (Push Notifications entitlement). Free/personal Apple ID teams cannot provision apps with Push Notifications — Xcode raised a provisioning error blocking profile creation and thus blocking the device install.
- **Fix:** Removed the `aps-environment` key from both entitlement files. The app only uses `flutter_local_notifications` (local notifications delivered on-device), which requires no server-push entitlement. `keychain-access-groups` and `get-task-allow` were preserved.
- **Files modified:** `ios/Runner/DebugProfile.entitlements`, `ios/Runner/Release.entitlements`
- **Verification:** Xcode provisioning profile created successfully; `flutter run` built and signed without error; app installed and launched on device.
- **Committed in:** `b261537` (orchestrator commit, pre-finalization)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical: entitlement incompatible with free provisioning)
**Impact on plan:** The fix was required for the plan's goal (device install) to succeed. No Push Notification functionality is affected — the app uses only local notifications, which require no server-push entitlement.

## Issues Encountered

- `aps-environment` entitlement incompatible with free/personal Apple ID provisioning — resolved by removing it (see Deviations above). Push Notification entitlements will need to be handled in a later phase if/when a paid Apple Developer account is used for distribution.

## Provisioning Expiry Record

| Item | Value |
|------|-------|
| Install date | 2026-06-02 |
| Free certificate expiry | 2026-06-09 (7 days from install) |
| Device | Rahul's iPhone (00008110-00115119260A401E, iOS 26.5) |
| Signing team | 2DG5SFXZ5Z (Personal Team — Rahul kumar) |
| Bundle ID | com.travey.app |
| On-device cert trust required | No (install succeeded without manual trust) |

**Re-sign procedure:** After 2026-06-09, open `ios/Runner.xcworkspace` in Xcode, select the Runner target, let Xcode reprovision the free profile, then run `flutter run -d <device-id>` again. Commit any project.pbxproj changes.

## Next Phase Readiness

- Phase 12 all 3 plans complete (IOS-01, IOS-03, IOS-02 all satisfied).
- Phase 13 (Auth on iOS) can begin: signing is configured, Developer Mode is on, app launches on device.
- Phase 13 requires real-device install for Google OAuth redirect flow validation; re-sign before device session if after 2026-06-09.
- The aps-environment removal has no impact on Phase 13–16 — none of those phases use remote Push Notifications.

## Known Stubs

None — this plan contains no code. The only artifacts are project configuration files (project.pbxproj, entitlements).

---
*Phase: 12-ios-scaffolding-configuration*
*Completed: 2026-06-02*
