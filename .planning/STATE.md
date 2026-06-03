---
gsd_state_version: 1.0
milestone: v0.2
milestone_name: iOS Support
status: verifying
stopped_at: "Checkpoint: BLOCKING App-Group device-provisioning probe (Plan 15-01 Task 3)"
last_updated: "2026-06-03T17:51:22.398Z"
last_activity: 2026-06-03
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 11
  completed_plans: 9
  percent: 40
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-02)

**Core value:** Show people the reality of their commute -- time wasted in traffic and how it changes over time.
**Current focus:** Phase 14 — background-gps-platform-branch

## Current Position

Phase: 14 (background-gps-platform-branch) — CODE COMPLETE, awaiting device UAT
Plan: 3 of 3
Status: Phase complete — ready for verification
Last activity: 2026-06-03

Progress: [████████░░] 82%

## Performance Metrics

**Velocity (v0.1 reference):**

- Total plans completed (v0.1): 29
- Average duration: ~15 min/plan
- Total execution time: ~7 hours

**v0.2 Phases:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 12 | 3 | - | - |
| 13 | TBD | - | - |
| 14 | TBD | - | - |
| 15 | TBD | - | - |
| 16 | TBD | - | - |

*Updated after each plan completion*
| Phase 12-ios-scaffolding-configuration P02 | 45min | 4 tasks | 9 files |
| Phase 12 P03 | human-gated | 2 tasks | 3 files |
| Phase 14 P02 | 30 | 3 tasks | 9 files |
| Phase 14 P03 | 9min | - tasks | - files |
| Phase 15 P01 | 25min | 2 tasks | 3 files |
| Phase 15 P02 | 7 | 3 tasks | 8 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v0.2 Research]: No new packages needed — port is configuration + one platform branch
- [v0.2 Research]: flutter_map (OSM) already in use — google_maps_flutter iOS setup is NOT needed
- [v0.2 Research]: firebase_options.dart already carries iOS client config — iOS Firebase app pre-registered
- [v0.2 Research]: flutter_background_service cannot sustain iOS GPS — use AppleSettings + CoreLocation instead
- [v0.2 Roadmap]: Phase 14 open decision — keep flutter_background_service.onForeground wrapper on iOS or bypass; resolve at plan time
- [Phase ?]: iOS 15.0 deployment target (firebase_auth/firebase_core floor, user-approved)
- [Phase ?]: flutter precache --ios required before pod install when Flutter.xcframework cache is absent (one-time machine setup)
- [Phase 12]: No NSAppTransportSecurity exception required — all endpoints HTTPS; default ATS posture (TLS-required) retained (T-12-04 mitigated)
- [Phase 12]: GoogleService-Info.plist committed to git (standard FlutterFire workflow — client config, not a secret; Firestore deny-all rules enforce real access boundary)
- [Phase 12]: REVERSED_CLIENT_ID in GoogleService-Info.plist matches Info.plist CFBundleURLSchemes exactly: com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64
- [Phase 12]: DarwinInitializationSettings requestAlertPermission/requestSoundPermission/requestBadgePermission all false — permission deferred to Phase 15 iOS flow
- [Phase ?]: Removed aps-environment from entitlements — free Apple ID teams cannot provision Push Notifications; app uses only local notifications (flutter_local_notifications) which require no aps-environment
- [Phase ?]: DEVELOPMENT_TEAM 2DG5SFXZ5Z (Personal Team, Rahul kumar) committed to project.pbxproj — standard practice, non-secret; free provisioning install 2026-06-02, expires 2026-06-09
- [Phase ?]: TrackingNotifier rewired to TrackingEventSource seam; trackingEventSourceProvider selects MainIsolateTrackingEngine (iOS) vs FbsTrackingEventSource (Android) — D-04 single runtime switch
- [Phase ?]: IOS-08 accuracy-blocked start surfaces kTrackingReducedAccuracyBlockedMessage (distinct stable string) vs generic message on Android (T-02-07 preserved)
- [Phase ?]: Wave 0 RED scaffolds committed for all 5 test files before any Plan 02-05 implementation begins
- [Phase ?]: IOS-11 test seam: forTesting(platformIsAndroid:) pattern chosen to avoid dart:io Platform in tests (RESEARCH.md Pitfall 2)
- [Phase ?]: App-Group device-provisioning probe is a BLOCKING gate for Plan 04 — must report PASS or FAIL before Swift is written

### Pending Todos

- Phase 3 backlog: Backlog 999.1 (velocity-jump gate in TripAccumulator)
- Phase 3 backlog: Backlog 999.2 (app kill + relaunch trip recovery via dart:io file write)

### Blockers/Concerns

- BLOCKER (human): Xcode license not accepted on this machine — blocks `flutter build ios`, git operations. User must run `sudo xcodebuild -license accept` before Phase 12 can execute.
- CONCERN (Phase 14): Background GPS is highest-risk phase — requires real-device commute validation. Plan-phase should flag for deeper research.

## Deferred Items (carried from v0.1)

| Category | Phase | Item | Status | Checklist group |
|----------|-------|------|--------|-----------------|
| verification | 03 | 03-VERIFICATION.md | human_needed | B |
| verification | 04 | 04-VERIFICATION.md | human_needed | C |
| verification | 05 | 05-VERIFICATION.md | human_needed | D |
| verification | 06 | 06-VERIFICATION.md (spec partly superseded by Phase 8) | human_needed | E |
| verification | 07 | 07-VERIFICATION.md | human_needed | F |
| verification | 09 | 09-VERIFICATION.md | human_needed | G |
| verification | 10 | 10-VERIFICATION.md (live token round-trip) | human_needed | H |
| verification | 11 | 11-VERIFICATION.md (live backend sync) | human_needed | I |
| uat | 02 | 02-HUMAN-UAT.md (11 open scenarios) | partial | A |
| uat | 04 | 04-HUMAN-UAT.md (5 open scenarios) | partial | C |
| uat | 09 | 09-HUMAN-UAT.md (3 open) + 09-UAT.md (8 open) | partial/testing | G |

Full checklist: `.planning/v0.1-DEVICE-CHECKLIST.md` (Groups A-I). Resume v0.1 close via `/gsd-complete-milestone` after device session.

## Session Continuity

Last session: 2026-06-03T17:51:22.389Z
Stopped at: Checkpoint: BLOCKING App-Group device-provisioning probe (Plan 15-01 Task 3)
Resume file: None
