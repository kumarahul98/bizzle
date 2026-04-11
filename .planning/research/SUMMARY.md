# Project Research Summary

**Project:** Commute Tracker v0.1
**Domain:** Offline-first GPS commute tracking mobile app (Flutter/Android + AWS serverless)
**Researched:** 2026-04-11
**Confidence:** MEDIUM

## Executive Summary

Commute Tracker is a consumer Android app whose core value is surfacing personal commute time and traffic insights no existing app delivers. The architecture is offline-first with client-authoritative sync: Drift SQLite is the single source of truth, the server is a passive backup, and the sync engine operates as an independent background queue processor. The stack is mature — Flutter 3.41.6, Drift, Riverpod with codegen, AWS SAM — with one critical unresolved dependency: the "Tracelet" GPS package must be validated before implementation.

The biggest technical risks cluster in Phase 1 and 3. Android OEM battery optimization silently kills background location services. GPS speed data below 10 km/h is inherently noisy, and the core traffic-time differentiator depends on accurate speed classification.

## Recommended Stack

- Flutter 3.41.6 / Dart 3.11.4 (verified locally)
- Drift ^2.22 — reactive SQLite streams, type-safe DAOs, migration support
- Riverpod ^2.6 + riverpod_generator — compile-safe state management
- geolocator ^13.0 (or Tracelet if verified) — GPS with native Doppler speed
- flutter_background_service ^5.0 — Android foreground service for background GPS
- google_sign_in ^6.2 + amazon_cognito_identity_dart_2 ^3.7 — Google auth without Amplify
- flutter_secure_storage ^9.2 — Android Keystore for tokens
- fl_chart ^0.69 — charts for stats
- AWS SAM + TypeScript Lambda + DynamoDB + Cognito — 3-endpoint serverless backend
- zod ^3.23 — Lambda input validation
- http ^1.2 — sufficient for 3 JSON endpoints

## Feature Landscape

**Competitive gap:** No consumer app focuses on "how much time did I waste in traffic this week?" Google Maps Timeline, Waze, MileIQ, Strava all serve adjacent use cases.

**Table stakes:** Start/stop GPS recording, background survival, trip history with route maps, duration/distance, editing/deletion, offline functionality, cloud backup, Google Sign-In, dark mode, foreground notification during tracking.

**Differentiators:** Traffic time breakdown per trip (moving vs stuck at 10 km/h), weekly traffic totals, direction auto-labeling, best/worst commute day, 4-week trend line, manual trip entry, direction-split averages.

**Defer to v0.2+:** Weekly summary push notification, tracking reminder, home screen widget, trip export.

**Defer to v2+:** Automatic trip detection, iOS, two-way sync, route comparison.

## Architecture

Four-layer architecture: Presentation -> State (Riverpod) -> Services -> Data (Drift DAOs). Strict unidirectional data flow. Drift reactive streams eliminate stale-state bugs. Sealed state machines for tracking lifecycle and sync status.

**Build order (dependency-driven):** Database -> Auth -> Tracking -> Trip Management -> Stats -> Sync/Backend -> Polish.

## Critical Pitfalls

1. **Android OEM battery kill** — foreground service mandatory, battery exemption onboarding, START_STICKY. Phase 1/3.
2. **GPS speed noise below 10 km/h** — use Doppler speed, 3 km/h floor, sliding window smoothing. Phase 3.
3. **Drift migration breakage** — design schema upfront, write migration tests from v1, polylines in separate table. Phase 1.
4. **Cognito token refresh races** — centralize behind mutex, proactive refresh. Phase 2.
5. **Sync queue unbounded growth** — chunk in 5-10 trip batches from day one. Phase 6.

## Suggested Phase Structure

1. **Foundation** — Database schema, config, scaffold
2. **Auth** — Google Sign-In + Cognito (user_id needed before trips)
3. **Core Tracking** — GPS + TripProcessor + foreground service (highest risk)
4. **Trip Management** — History, detail, edit, delete, manual entry
5. **Stats and Dashboard** — Core value proposition
6. **Sync and Backend** — AWS infrastructure, sync engine, restore
7. **Polish** — Dark mode, reminders, edge cases

## Research Flags

**Needs validation:** Tracelet package existence (blocks Phase 3), GPS smoothing parameters (empirical tuning), DynamoDB key design (Phase 6), Cognito IdP setup.

**Standard patterns (skip research):** Drift setup, google_sign_in, CRUD with Riverpod, SQL aggregates, dark mode, flutter_local_notifications.

## Sources

- CLAUDE.md + MVP-features-0.1.md (project context)
- Flutter 3.41.6/Dart 3.11.4 (verified local installation)
- Training data knowledge of Android background processing, GPS accuracy, competitor features
- Tracelet: UNVERIFIED — highest-priority validation item

---
*Synthesized: 2026-04-11 from STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md*
