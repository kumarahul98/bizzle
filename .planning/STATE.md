---
gsd_state_version: 1.0
milestone: v0.3
milestone_name: App Improvements
status: executing
stopped_at: Phase 29 backend DEPLOYED + verified live; client branch unmerged pending Play Data Safety declaration. Phase 30 blocked on device spike.
last_updated: "2026-07-20T00:00:00.000Z"
last_activity: 2026-07-20
progress:
  total_phases: 18
  completed_phases: 13
  total_plans: 47
  completed_plans: 43
  percent: 76
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-06)

**Core value:** Show people the reality of their commute -- time wasted in traffic and how it changes over time.
**Current focus:** Phase 29 waves are built; two human gates (backend deploy, Play Data Safety) stand between it and release

## Current Position

Phase: 29 code-complete (branch `phase-29-sync-home-office`, unmerged)
Plan: all 3 waves done
Status: Blocked on two human gates — see below
Last activity: 2026-07-20

**Session 2026-07-19/20 (manual GSD — tooling uninstalled, process honoured by hand):**

**Merged to main this session:**
- `a5fffce` — targetSdk 34 → 35 for Play compliance. Verified in the built APK via aapt2 (`minSdkVersion:'34' targetSdkVersion:'35'`), not just source. minSdk unchanged, so Phase 1 D-08 stands. **On-device edge-to-edge NOT verified** (Phase 23 queue).
- `ef4d03e` — WR-05 had **never once executed**. `tracking_service.dart` called a MethodChannel with no registered native handler, throwing MissingPluginException into a swallowing catch on every stop. Since `finalize()` clears `active_trip.json` immediately before that call, both safety nets were down at once. Replaced with a file-based `PendingTripStore`. **A `MainActivity.configureFlutterEngine` handler would NOT have fixed it** — the call originates in the background service isolate, which has its own FlutterEngine. Device repro still outstanding (Phase 23 queue).
- `548b82a` — retired the dead MethodChannel from BACKLOG 999.2 + ARCHITECTURE.md, which still documented it as the design.
- `5844864` — Phase 28 status corrected to code_complete (its code had been on main since 07-18); Phase 23 gained SC#5 + the device-only queue table.

**Phase 29 — code-complete, UNMERGED, branch `phase-29-sync-home-office`:**
- `5733236` Wave 1 backend — `POST /preferences/sync`, `GET /preferences/restore`, zod schema with lat/lng range + `.finite()` + pair-consistency rules, typed converter, `users/*` deny-all proven. Backend suite 89 → 103.
- `9843204` Wave 2 client — `SavedLocations`, two `ApiClient` methods, `PreferencesSyncService` with the D-03 null-only merge, and the D-01 dartdoc rewrite on the four coord columns (they said "no sync field carries it", which this phase makes false).
- `bf96bbb` Wave 3 triggers — push on picker-confirm (unawaited), restore-THEN-push on sign-in. That order is load-bearing: push-first would upload a fresh install's empty state and null out the user's real cloud pins before restore ever read them.
- Flutter 677 → 709 green, analyze 0/0, debug APK builds.

**✅ Backend DEPLOYED 2026-07-20** to `travey-298a7`; `api(us-central1)` updated. Verified live: `/health` 200, `/preferences/{sync,restore}` 401 unauthenticated (route registered + auth-first), and critically **`/trips/{sync,restore}` still 401** — all five routes share ONE `onRequest(app)` function, so the deploy replaced the one already serving trip sync. It came through clean. Also confirmed the live 401 does not echo submitted coordinates (T-29-02).

**⛔ ONE GATE REMAINS — do not merge the client branch until it clears:**
- **Update the Play Data Safety declaration** from *no location data collected* to *precise location collected and stored, linked to the account* (D-01). User-visible on the store page.
- Note the distinction that made the deploy safe to do first: the declaration blocks shipping the CLIENT, not the backend. Endpoints no released app calls collect nothing.

**Two pre-existing infra items surfaced by the deploy (neither introduced by Phase 29):** Artifact Registry in `us-central1` has no cleanup policy, so images from every deploy since Phase 10 accumulate and bill slowly (`firebase functions:artifacts:setpolicy`); and Node.js 20 is deprecated, decommissioning **2026-10-30** — the runtime needs bumping before then.

**Phase 30** — still BLOCKED on the 30-00 latency spike, which needs a real drive with logcat attached. Not started, deliberately: kill criteria are fixed in advance so the phase gets cancelled on numbers rather than argued about. Building its permission flow or settings toggle first would be trim on a car whose engine may not start.

**v0.3 progress:** 9/11 phases complete (17,18,19,20,21,22,24,25 done and merged to main 2026-07-06 in PR #2; 25.1 completed 2026-07-12 on main). Phase 23 rescoped 2026-07-11 (UAT audit found it never really executed — stalled at 1 thin plan; now Android-only, its one iOS criterion removed). Phase 25.1 (inserted 2026-07-11) fixed the broken auto-retry throttle and fake Merge conflict resolution; one visual UAT item remains tracked in 25.1-HUMAN-UAT.md (Merge sheet "Local" pre-selected on device).

**v0.3 verification reconciliation (2026-07-14):** VERIFICATION.md now exists for Phases 21/22/25; Phase 24 re-verified off its stale gaps_found → human_needed (6/6 static truths after 25.1's fixes). Results: Phase 24 → SYNC-04/SYNC-05 Complete; Phase 22 → WIDGET-01 code-complete but held Pending on device UAT (owned by Phase 23); Phase 21 → LOC-01 Complete. **Two real production bugs surfaced (both CI-invisible, both contradicting the milestone audit's "no broken wiring" claim), neither fixed yet:** (1) **TRACK-13 BLOCKED** — `TripStatePersister` is never injected into `TripAccumulator` at any of the 4 production construction sites (`main_isolate_tracking_engine.dart:119,121`, `tracking_service.dart:85,88`), so `_persistState()` always early-returns and `active_trip.json` is never written during a real trip; interrupted-trip recovery cannot fire. (2) **LOC-02 backfill dead** — `geofenceBackfillProvider` is only `ref.invalidate`d (`location_picker_screen.dart:119`), never watched, so the historical re-label of pre-existing trips never runs (new-trip labeling is fine). Fixes to be routed through GSD (`/gsd-debug` or `/gsd-quick`).

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
| 26 | 6 | - | - |

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
| Phase 26 P01 | 25min | 3 tasks | 11 files |
| Phase 26 P02 | 25min | 2 tasks | 25 files |
| Phase 26 P03 | ~30min | 3 tasks | 11 files |
| Phase 26 P05 | ~20min | 3 tasks | 4 files |
| Phase 26 P06 | ~10min | 2 tasks | 4 files |

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
- [Phase 26-01]: kMaxBreaksPerTrip=50 DoS cap on the embedded breaks array; directionSource enum locked to literal 'manual'/'geofence'/'time' matching client kDirectionSource* constants byte-for-byte; read-side defaulting lives ONLY in tripConverter.fromFirestore (?? 0/false/'time'/[]) — no zod parse on the restore path
- [Phase 26-01]: nodejs20 runtime decommissions 2026-10-30 (deploy warning) — bump to nodejs22 before then or future deploys are blocked
- [Quick 2026-07-20]: CLOSES the 26-01 note above, but landed on **nodejs24, not nodejs22**. Both are GA and both decommission 2028-10-31, so nodejs22 buys no extra runway — nodejs24 just deprecates a year later (2028-04-30 vs 2027-04-30), making it one fewer forced bump. nodejs26 exists but is BETA and was rejected. Branch `chore/functions-nodejs24-runtime`, NOT deployed.
- [Phase 26-02]: backfillMarkerVersion made a required UserPreferencesValue field (not optional-with-default), forcing compile-time propagation to every existing call site (14 files beyond declared plan scope) to guarantee the marker is never silently dropped
- [Phase 26-02]: migration_v3/v5/v6_test.dart bumped their migrateAndValidate() target to the new terminal version 7 -- Drift's compiled row mapper reads every currently-defined column regardless of physical DDL, so a test that stops migration at an older version and then calls a DAO getOrDefault() crashes; matches the pre-existing convention documented in migration_v5_test.dart
- [Phase 26-03]: Client-side take(kMaxBreaksPerTrip) truncation (oldest-first) at serialization time mirrors the backend zod .max(50) so a >50-break trip can never become a non-retryable 400 poison pill in the sync queue
- [Phase 26-03]: RestoreController maps ParsedTrip.trip through and discards parsed breaks for now -- persisting restored break companions into trip_breaks is Plan 05's explicit scope; ParsedTrip.breaks (fresh UUIDs, correct tripIds) is ready at the exact call site
- [Phase 26-05]: D-07 shipped: _isDifferent excludes totalPausedSeconds/directionSource/isEdited; restore() splits bulk vs per-trip transactional insert by breaks-presence; D-10/D-11 enrichment adopts cloud metadata per-field only when local is default
- [Phase 26-06]: resolveMerge's D-04 ride-along fields reuse the SAME resolved booleans as the pre-existing startTime/direction ternaries -- no new/independent selection keys introduced
- [Phase 26-06]: Use Cloud (bulk and per-trip) now also replaces local trip_breaks with cloud's breaks and both Use-Cloud and Merge writes are wrapped in one database.transaction, closing SC5 and T-26-17

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

Last session: 2026-07-13T02:28:33.359Z
Stopped at: Phase 26 plan 26-06 complete (phase 26 done, all 6 plans shipped)
Resume file: None

[2026-07-20 quick task] Cloud Functions Node runtime 20 → 24 (`chore/functions-nodejs24-runtime`, off main @ 47269b1). Driven by the deploy warning: nodejs20 deprecated 2026-04-30, **decommissioned 2026-10-30** — after that date no deploy succeeds without this change, so it is a hard ~3-month deadline, not housekeeping. Target chosen from live data, not memory: `gcloud functions runtimes list --region=us-central1` (nodejs22 GA, nodejs24 GA 2nd-gen, nodejs26 BETA) cross-checked against firebase-tools 15.19.0's own `runtimes/supported/types.js` (nodejs24 status GA, decommission 2028-10-31). Changed only `engines.node`, `@types/node` ^20→^24, and the lockfile. `tsconfig` target/lib left at es2021 deliberately — raising it changes emitted JS with zero benefit here, and the runtime bump is meant to be behaviour-neutral. **NOT DEPLOYED** — the live backend is untouched; a human must run the deploy.

Two things a future session should know. (1) The backend test suite on main is **60 tests / 7 suites**, not the 103 you may see quoted — 103 is the `phase-29-sync-home-office` branch, which adds `preferences-validation.test.ts` + `preferences.test.ts`. Verified by running the suite on the unmodified tree first: also 60. (2) ~~That phase-29 branch carries its own `engines.node: "20"`; whichever merges second must not clobber the 24.~~ **Checked and withdrawn 2026-07-20 — not a hazard.** phase-29 never modifies `package.json` at all, so a 3-way merge sees no change on its side and keeps main's 24. Rehearsed both merge orders on a throwaway branch: `engines.node` reads 24 afterwards either way, no conflict. (3) `npm install` now warns EBADENGINE because the local machine runs node v25 against an `engines` pin of 24 — cosmetic, no `engine-strict`, and CI/deploy build on the pinned runtime.

Separate finding, deliberately NOT fixed here (one concern per commit): the same deploy flagged `firebase-functions` as outdated — 7.2.5 installed vs 7.3.0 latest. It is a **minor** bump already inside the existing `^7.2.5` range, held back only by the lockfile, and it did not block the Node upgrade. `firebase-admin` is further behind at 13.10.0 vs 14.2.0, which IS a major bump and needs its own review. Both want their own task.

[2026-07-18 overnight] Phase 27 (UX Tour + Tracking Accuracy) built autonomously with subagents (2 Sonnet waves + 1 Opus). All 3 items done + committed, full suite 664 green, APK built: (1) TRACK-14 GPS stationary-drift fix — 5m min-move floor gating the distance total only (commit 675fec1); (2) UX-08 auto-pause/"break" ON by default via table+DAO defaults + v7→v8 TableMigration backfilling existing rows, plus seen_tours column (commit 26b017b); (3) UX-07 per-page once-only guided tour with Skip — custom Overlay coach-mark, PageTourHost triggers on tab-visible not initState (IndexedStack builds all pages up front), persisted via seen_tours (commit 5f75640). On-device UAT of all 3 pending. See .planning/phases/27-ux-tour-tracking-accuracy/27-PLAN.md.
[2026-07-18] Fixed both reconciliation bugs (2 parallel single-module agents, central verification, full suite 653 green). PERSIST-INJECT-FIX (TRACK-13): TripStatePersister injected at all 4 production TripAccumulator sites + production-shaped persistence regression test — commit 452afd8. GEO-BACKFILL-FIX (LOC-02): confirm path awaits geofenceBackfillProvider.future instead of dead invalidate + widget regression test — commit c22a2aa. Traceability: TRACK-13 → Complete, LOC-02 caveat dropped. No open v0.3 code gaps remain; sole remaining blocker is the Phase 23 device session (WIDGET-01 + the two fixes' end-to-end device confirmation).
[2026-07-14] Verification reconciliation of Phases 21/22/24/25 run (4 gsd-verifier passes). Wrote VERIFICATION.md for 21 (gaps_found, 5/6), 22 (human_needed, 4/4 code), 25 (gaps_found, 1/5 — real bug); re-verified 24 (human_needed, 6/6, off stale gaps_found). REQUIREMENTS.md traceability reconciled: LOC-01/SYNC-04/SYNC-05 → Complete; WIDGET-01 held Pending; TRACK-13 → Blocked. Two production bugs found (TRACK-13 persister injection; LOC-02 dead backfill trigger) — logged, not fixed.
[2026-07-11] Completed 25.1-02-PLAN.md (D-05 merge default flip to local at both leak points + D-08 two-differing-field merge test — all Phase 25.1 plans done)
[2026-07-11] Completed 25.1-01-PLAN.md (D-07 gate regression tests + D-04 autoRetryWindowElapsed rename/consolidation)

[2026-06-16] Phase 25 Planning complete: generated and verified 3 PLAN.md files. 3 PLAN.md files.
[2026-06-16] Completed 24-02-PLAN.md
[2026-06-16] Completed 25-01-PLAN.md
