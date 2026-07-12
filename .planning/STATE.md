---
gsd_state_version: 1.0
milestone: v0.3
milestone_name: App Improvements
status: Ready to discuss/plan
stopped_at: Phase 26 context gathered
last_updated: "2026-07-12T05:13:31.145Z"
last_activity: 2026-07-12 -- Phase 25.1 verified (3/3 must-haves) and marked complete
progress:
  total_phases: 16
  completed_phases: 11
  total_plans: 34
  completed_plans: 31
  percent: 69
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-06)

**Core value:** Show people the reality of their commute -- time wasted in traffic and how it changes over time.
**Current focus:** Phase 26 — Sync Breaks & Edit Metadata to Cloud (v0.3 App Improvements)

## Current Position

Phase: 26 — Sync Breaks & Edit Metadata to Cloud (next up; Phase 25.1 dependency now satisfied)
Plan: not yet planned
Status: Ready to discuss/plan
Last activity: 2026-07-12 -- Phase 25.1 verified (3/3 must-haves) and marked complete

**v0.3 progress:** 9/11 phases complete (17,18,19,20,21,22,24,25 done and merged to main 2026-07-06 in PR #2; 25.1 completed 2026-07-12 on main). Phase 23 rescoped 2026-07-11 (UAT audit found it never really executed — stalled at 1 thin plan; now Android-only, its one iOS criterion removed). Phase 25.1 (inserted 2026-07-11) fixed the broken auto-retry throttle and fake Merge conflict resolution; one visual UAT item remains tracked in 25.1-HUMAN-UAT.md (Merge sheet "Local" pre-selected on device).

**Recommended execution order for the remaining work:** 26 (sync schema, no device needed) → 23 (one consolidated Android device session covering the v0.1 checklist + stalled 21/22 UAT sessions).

## Platform Focus (as of 2026-07-11)

**All active work is Android-only.** v0.2 (iOS Support) is formally PAUSED — full resume-point summary lives in `ROADMAP.md`'s v0.2 section ("🚧 PAUSED — iOS Development Summary"). Quick version:

- **Done, device-confirmed:** Phase 12 (scaffolding), Phase 13 (auth), Phase 15-trimmed (permissions/notifications, merged PR #3 2026-07-06)
- **Code-complete, device-unverified:** Phase 14 (background GPS) — 3 real-device drive scenarios never run, unblocked and ready whenever iOS resumes
- **Abandoned:** Live Activity (IOS-13) — never rendered on device; archived at git tag `archive/live-activity-wip`, not on `main`
- **Not started:** Phase 16 (end-to-end parity validation, the milestone's acceptance gate)

Phases 25.1 and 26 are platform-agnostic (Dart/backend, shared by both platforms) so they don't reopen iOS scope. Phase 23 was rescoped this session specifically to drop its one iOS success criterion (Phase 14's device items), keeping it pure Android. When iOS resumes: run Phase 14's leftover scenarios together with Phase 16's full sweep in one real-iPhone session, then decide whether to revive Live Activity from the archive tag or drop IOS-13 permanently.

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

**v0.3 Phases:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 17 | TBD | - | - |
| 18 | TBD | - | - |
| 19 | TBD | - | - |
| 20 | TBD | - | - |
| 21 | TBD | - | - |
| 22 | TBD | - | - |
| 23 | 1 | - | - |

*Updated after each plan completion*
| Phase 12-ios-scaffolding-configuration P02 | 45min | 4 tasks | 9 files |
| Phase 12 P03 | human-gated | 2 tasks | 3 files |
| Phase 14 P02 | 30 | 3 tasks | 9 files |
| Phase 14 P03 | 9min | - tasks | - files |
| Phase 18 P02 | 52min | 2 tasks | 8 files |
| Phase 21 P03 | 5 min | 3 tasks | 6 files |
| Phase 24 P02 | 15min | 1 task | 3 files |
| Phase 25 P01 | 15min | 3 tasks | 4 files |
| Phase 25.1 P01 | 10min | 2 tasks | 3 files |
| Phase 25.1 P02 | 7min | 2 tasks | 2 files |

## Accumulated Context

### Roadmap Evolution

- Phase 26 added (2026-07-11): Sync Breaks & Edit Metadata to Cloud — extend the Firestore trip payload/zod schema with totalPausedSeconds, isEdited, directionSource, and an embedded breaks array; restore writes trip_breaks; one-time backfill re-sync for trips with breaks/edits; backend deploys before client
- Phase 25.1 inserted (2026-07-11), urgent, before Phase 26: Fix Sync Conflict & Auto-Retry Bugs — Phase 24's own verification (2026-06-16, gaps_found) caught `SyncEngine._lastAutoRetry` never being assigned (auto-retry throttle permanently open) and the conflict-sheet "Merge" option being a no-op alias for "Use Cloud"; neither was fixed before the branch merged to main. Phase 26 now depends on 25.1 since both touch `sync_engine.dart` / `conflict_resolution_sheet.dart`.
- Phase 23 rescoped (2026-07-11): a `/gsd-audit-uat` run found Phase 23 ("Resolve Deferred UAT Items") had only ever gotten one thin plan (a home_widget unit test) despite STATE.md previously claiming it complete. Rewrote its Goal/Success Criteria to the real backlog: the v0.1 device checklist (48 items, 0 checked, `.planning/v0.1-DEVICE-CHECKLIST.md`), Phase 14's 3 iOS items (deferred pending Phase 15, now unblocked), and Phase 21/22's UAT sessions (both stalled at test 1, "awaiting user response" since June).
- Roadmap structure bug fixed (2026-07-11): the `## v0.3 Progress` heading sat BEFORE phases 23–26's `### Phase N:` detail sections instead of after them (pre-existing drift from the original overnight GSD session, not introduced this session). This silently broke every GSD tool that scans "current milestone" phases — `audit-uat`, `roadmap analyze`, `phase insert` — they all stopped at Phase 22 and couldn't see 23–26. Moved the Progress block to the end of the v0.3 section, matching the v0.2 section's pattern. Worth checking other milestone sections if similar tooling gaps show up.

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v0.3 Roadmap]: Phase 18 introduces the break/pause data model (schema migration); Phase 19 (full editing) depends on it
- [Phase 18-02]: Frozen elapsed subtracts only CLOSED paused segments; the open break is excluded by freezing refNow at the pause instant — snapshot.pausedSeconds DOES include the open span (UI), but elapsedSeconds does NOT (frozen timer)
- [Phase 18-02]: Break-list value equality uses per-element mapEquals (flutter/foundation) instead of package:collection DeepCollectionEquality — avoids a non-transitive depend_on_referenced_packages lint, no pubspec change
- [Phase 18-02]: Break segments cross the service→UI isolate boundary as List<Map<String,Object?>> of UTC microseconds (startUs/endUs); breaks persist to trip_breaks + total_paused_seconds inside the existing atomic transaction — sync contract unchanged (breaks stay local this phase)
- [v0.3 Roadmap]: Phase 22 (home-screen widget) sequenced last — highest platform-integration risk, and depends on Phase 18 state model for accurate widget state
- [v0.3 Roadmap]: Phase 21 geofence labeling takes precedence over time-of-day heuristic only on a confident proximity match; purely additive (falls back to existing behavior with no Home/Office set)
- [Phase 24-02]: Pause uploads during auto-restore so that guest trips do not upload until cloud trips are properly restored and reconciled
- [Phase 25.1-01]: Auto-retry gate condition consolidated into single getter autoRetryWindowElapsed (renamed from isAutoRetryExhausted, same polarity: true = window elapsed, safe to auto-retry); minimal-diff form kept at both trigger call sites, no shared trigger-dispatch extraction
- [Phase 25.1-01]: D-07 gate contract test-pinned BEFORE the D-04 rename — 3 regression tests committed passing against the pre-rename code, so the rename was verified by an already-pinned contract
- [Phase 25.1-02]: Merge default flipped to 'local' at BOTH leak points in one commit (displayed SegmentedButton default + all 5 _applyAll fallback ternaries) so display and apply never diverge; 'Merge All' with no per-field selections now equals 'Keep All Local' (accepted D-06 consequence, no UI signal added)
- [Phase 25.1-02]: D-08 merge widget test uses an enlarged 800x1600 test viewport — the default 600px surface clips the distanceMeters row's Cloud segment under the bottom sheet and silently drops the tap; conflict-sheet tests assert on the Drift row (findById), never widget internals
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

### Pending Todos

- Phase 3 backlog: Backlog 999.1 (velocity-jump gate in TripAccumulator)
- Phase 3 backlog: Backlog 999.2 (app kill + relaunch trip recovery via dart:io file write)

### Blockers/Concerns

- CONCERN (Phase 22): Home-screen widget is the highest platform-integration risk in v0.3 — native Android AppWidget + background trigger into the tracking service. Plan-phase should flag for deeper research.
- NOTE (v0.2 paused): Xcode/device-gated v0.2 work (Phases 13/15/16 open) remains resumable; not a v0.3 blocker.

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

Last session: 2026-07-12T05:13:31.131Z
Stopped at: Phase 26 context gathered
Resume file: .planning/phases/26-sync-breaks-edit-metadata-to-cloud/26-CONTEXT.md

[2026-07-11] Completed 25.1-02-PLAN.md (D-05 merge default flip to local at both leak points + D-08 two-differing-field merge test — all Phase 25.1 plans done)
[2026-07-11] Completed 25.1-01-PLAN.md (D-07 gate regression tests + D-04 autoRetryWindowElapsed rename/consolidation)

[2026-06-16] Phase 25 Planning complete: generated and verified 3 PLAN.md files. 3 PLAN.md files.
[2026-06-16] Completed 24-02-PLAN.md
[2026-06-16] Completed 25-01-PLAN.md
