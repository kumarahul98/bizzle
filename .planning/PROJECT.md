# Commute Tracker

## What This Is

A consumer Android app that lets anyone track their daily commute with a simple start/stop button, then shows them exactly how much time they spend stuck in traffic and how their commute trends over weeks. Built with Flutter, backed by Firebase for cloud sync and restore.

## Core Value

Show people the reality of their commute — time wasted in traffic and how it changes over time. If nothing else works, this insight must.

## Current Milestone: v0.3 App Improvements

**Goal:** Ship a batch of Android-facing UX fixes and features that make daily trip capture more flexible and accurate — pausing for breaks, full trip editing, smarter labeling, a friendlier first run, and one-tap start/stop from the home screen.

**Target features:**
- Fix: tracking timer never overflows/wraps on screen (any duration)
- Pause/resume an active trip for breaks, with optional auto-pause notification
- Fully editable trip details (start time, end time, break segments)
- Quick to-home / to-office label selector
- First-install login screen with a Skip (use-without-account) option
- Set Home & Office locations to geofence auto-label trips
- Home-screen widget to start/stop a commute with one tap

**Scope notes:** Android-focused (Android-only surfaces like the home-screen widget are Android-first; iOS parity for these features is deferred). Built on branch `gsd/v0.3-app-improvements`. Previous milestone v0.2 (iOS Support, Phases 12–16) is **paused** — Phase 14 code-complete awaiting physical-device UAT, Phase 15 context gathered — and remains fully resumable (artifacts untouched). v0.1 also remains formally open (deferred Android device-UAT items).

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
- [ ] (v0.3) Tracking timer renders without overflow/wrap at any duration
- [ ] (v0.3) Pause/resume an active trip for breaks (paused time excluded from stats)
- [ ] (v0.3) Optional auto-pause notification when a trip looks stationary
- [ ] (v0.3) Fully editable trip details — start time, end time, break segments
- [ ] (v0.3) Quick to-home / to-office label selector
- [ ] (v0.3) First-install login screen with a Skip (use-without-account) option
- [ ] (v0.3) Set Home & Office locations to geofence auto-label trips
- [ ] (v0.3) Home-screen widget to start/stop a commute with one tap

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
| Pause v0.2 (iOS) to build v0.3 app improvements | v0.2 blocked on physical-device UAT (can't progress autonomously); user requested a batch of Android UX features/fixes built overnight | ✓ Decided 2026-06-06 — branch gsd/v0.3-app-improvements |

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
*Last updated: 2026-07-12 — Phase 25.1 complete: fixed the broken sync auto-retry throttle and the fake Merge conflict resolution found by Phase 24 verification. v0.3 at 9/11 phases; remaining: 26 (sync breaks/edit metadata), 23 (consolidated Android device UAT). v0.2 (iOS) remains paused and resumable.*
