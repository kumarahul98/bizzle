# Commute Tracker

## What This Is

A consumer Android app that lets anyone track their daily commute with a simple start/stop button, then shows them exactly how much time they spend stuck in traffic and how their commute trends over weeks. Built with Flutter, backed by Firebase for cloud sync and restore.

## Core Value

Show people the reality of their commute — time wasted in traffic and how it changes over time. If nothing else works, this insight must.

## Current Milestone: v0.2 iOS Support

**Goal:** Make the full Commute Tracker app run on iOS with feature parity to Android, runnable on a real iPhone via Xcode.

**Target features:**
- iOS platform scaffolding (generate `ios/` folder, bundle ID, build config)
- Background GPS tracking on iOS (geolocator native background location mode)
- Google Sign-In + Firebase Auth on iOS (URL schemes, `GoogleService-Info.plist`)
- Local notifications on iOS (permission model, tracking + weekly summary)
- Secure token storage via iOS Keychain
- Maps / route display on iOS
- iOS permissions + `Info.plist` (location always/when-in-use, notifications)

**Scope notes:** Full feature parity including background GPS. Target = runs on a real iPhone via Xcode 26.5 (no TestFlight / App Store this milestone). No Apple Developer account — relies on 7-day free provisioning. Previous milestone v0.1 is left formally open (13 deferred Android device-UAT items) and remains resumable.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Google Sign-In with Firebase Auth for authentication
- [ ] Session persistence across app restarts
- [ ] Onboarding flow (sign-in, location permission, done)
- [ ] Manual start/stop commute recording with background GPS via Tracelet
- [ ] Auto-label direction (morning = to office, evening = to home, editable)
- [ ] Trip record with start/end time, duration, distance, route polyline
- [ ] Edit trip details (direction label, adjust times)
- [ ] Delete trip with confirmation
- [ ] Manual entry for forgotten trips (duration + date, no GPS)
- [ ] Daily log with list/calendar view of past commutes
- [ ] Tap trip to view route on map with details
- [ ] Weekly and monthly total commute time
- [ ] Average commute duration (separate for to-office vs to-home)
- [ ] Best and worst commute day of the week
- [ ] 4-week trend line
- [ ] Per-trip time moving vs time stuck (speed < 10 km/h threshold)
- [ ] Weekly "time wasted in traffic" total
- [ ] One-way sync: Drift to Firestore via sync queue and Cloud Functions
- [ ] One-time cloud restore from settings (reinstall/device switch recovery)
- [ ] Dashboard home screen with today's trips and weekly summary card
- [ ] Dark mode (system default + manual toggle)
- [ ] Persistent notification while tracking
- [ ] Weekly summary push notification
- [ ] Tracking reminder at usual departure time

### Out of Scope

- Real-time traffic data integration — use GPS speed as proxy for v0.1
- Multi-stop trip chaining — single A-to-B commute trips only
- Social/sharing features — personal utility first
- Server-side analytics or aggregation — client computes all stats locally

## Context

- Target audience is anyone with a regular commute who wants to understand their time spent traveling
- Offline-first architecture: app must work fully without network, sync is opportunistic
- Drift (SQLite) is source of truth; Firestore is backup for restore only
- Speed threshold of 10 km/h defines "stuck in traffic" vs "moving"
- Direction auto-labeling uses configurable morning/evening cutoff (default 12:00)
- Tech stack specified in CLAUDE.md but open to research-informed changes on specific packages

## Constraints

- **Platform**: Android only for v0.1 — ship fast, expand later
- **Timeline**: Ship fast — minimize scope creep, prioritize working features over polish
- **Architecture**: Offline-first, client-authoritative — never block UI on network
- **Auth**: Google Sign-In via Firebase Auth (FlutterFire)
- **Backend**: Firebase serverless (Firebase Auth, HTTPS Cloud Functions, Firestore) via Firebase CLI

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Backend vendor: Firebase over AWS | Greenfield cloud-layer choice (no backend code written yet). Firebase wins on auth simplicity (Google one-tap via FlutterFire), first-party Flutter SDK, lower build effort, and matches the 3-REST-endpoint scope. ML/analytics stays open via Firestore→BigQuery→Vertex AI. See `cloud-vendor-tradeoffs.pdf`. | ✓ Decided 2026-05-27 |
| Client-authoritative sync (one-way push) | Simplifies architecture, no conflict resolution needed | — Pending |
| Drift as single source of truth | Offline-first requires local DB to be authoritative | ✓ Validated in Phase 1 (foundation) |
| Speed-based traffic detection (10 km/h) | Simple proxy that works without external traffic APIs | ✓ Constant locked in Phase 1 (`kStuckSpeedThresholdKmh`) |
| Tech stack open to research input | CLAUDE.md stack is a starting point, not locked | ✓ Phase 1 swapped flutter_lints → very_good_analysis; deferred riverpod_generator (analyzer conflict with drift_dev) |
| Manual Riverpod 3.x providers (no codegen) | riverpod_generator/lint require analyzer ^9, drift_dev 2.32.1 requires analyzer ^10 | Phase 1 decision — revisit when ecosystem aligns |
| compileSdk 35, minSdk/targetSdk 34 | jni_flutter transitive dep needs API 35 headers; runtime targets Android 14 per D-08 | Phase 1 decision |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-02 — Started milestone v0.2 (iOS Support). iOS moved from Out of Scope to active milestone goal. v0.1 left formally open with deferred Android device-UAT items.*
