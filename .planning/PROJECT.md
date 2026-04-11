# Commute Tracker

## What This Is

A consumer Android app that lets anyone track their daily commute with a simple start/stop button, then shows them exactly how much time they spend stuck in traffic and how their commute trends over weeks. Built with Flutter, backed by AWS for cloud sync and restore.

## Core Value

Show people the reality of their commute — time wasted in traffic and how it changes over time. If nothing else works, this insight must.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Google Sign-In with AWS Cognito for authentication
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
- [ ] One-way sync: Drift to DynamoDB via sync queue and Lambda
- [ ] One-time cloud restore from settings (reinstall/device switch recovery)
- [ ] Dashboard home screen with today's trips and weekly summary card
- [ ] Dark mode (system default + manual toggle)
- [ ] Persistent notification while tracking
- [ ] Weekly summary push notification
- [ ] Tracking reminder at usual departure time

### Out of Scope

- iOS support — Android-first for speed, iOS planned for later
- Real-time traffic data integration — use GPS speed as proxy for v0.1
- Multi-stop trip chaining — single A-to-B commute trips only
- Social/sharing features — personal utility first
- Server-side analytics or aggregation — client computes all stats locally

## Context

- Target audience is anyone with a regular commute who wants to understand their time spent traveling
- Offline-first architecture: app must work fully without network, sync is opportunistic
- Drift (SQLite) is source of truth; DynamoDB is backup for restore only
- Speed threshold of 10 km/h defines "stuck in traffic" vs "moving"
- Direction auto-labeling uses configurable morning/evening cutoff (default 12:00)
- Tech stack specified in CLAUDE.md but open to research-informed changes on specific packages

## Constraints

- **Platform**: Android only for v0.1 — ship fast, expand later
- **Timeline**: Ship fast — minimize scope creep, prioritize working features over polish
- **Architecture**: Offline-first, client-authoritative — never block UI on network
- **Auth**: Google Sign-In federated through AWS Cognito
- **Backend**: AWS serverless (Cognito, API Gateway, Lambda, DynamoDB) via SAM

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Client-authoritative sync (one-way push) | Simplifies architecture, no conflict resolution needed | — Pending |
| Drift as single source of truth | Offline-first requires local DB to be authoritative | — Pending |
| Speed-based traffic detection (10 km/h) | Simple proxy that works without external traffic APIs | — Pending |
| Tech stack open to research input | CLAUDE.md stack is a starting point, not locked | — Pending |

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
*Last updated: 2026-04-11 after initialization*
