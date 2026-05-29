# CLAUDE.md — Commute Tracker v0.1

## Project Overview
A Flutter-based Android app that tracks daily commutes via manual start/stop GPS recording, stores data locally with Drift, syncs to a Firebase backend, and generates stats like time spent in traffic, weekly totals, and commute trends.

**Current version:** v0.1 (MVP)
**Platform:** Android only (iOS planned for later)
**Task tracking:** See `tasks.md` in project root for full task list with checkboxes.

---

## Tech Stack

### Frontend
- **Framework:** Flutter (Dart)
- **Local DB:** Drift (SQLite wrapper) — source of truth for all app data
- **GPS:** Tracelet — handles raw GPS capture, background location, route recording
- **Auth:** firebase_auth + google_sign_in (FlutterFire — Google provider)
- **State Management:** Riverpod (flutter_riverpod + riverpod_annotation)
- **Charts:** fl_chart
- **Notifications:** flutter_local_notifications
- **Connectivity:** connectivity_plus
- **HTTP Client:** http (official Dart package — sufficient for 3 simple REST endpoints)
- **Secure Storage:** flutter_secure_storage (for auth tokens)

### Backend (Firebase)
- **Auth:** Firebase Auth with Google provider
- **API:** HTTPS Cloud Functions (REST-shaped) with Firebase ID-token verification
- **Compute:** Cloud Functions 2nd gen (TypeScript, Node.js runtime)
- **Database:** Firestore (document model — one document per trip)
- **IaC:** Firebase CLI (`firebase.json` + `functions/` in `/backend` directory)
- **Security:** Firestore Security Rules — deny-all to clients; only the Admin SDK (Cloud Functions) reads/writes trip data

---

## Project Structure

```
commute_tracker/
├── CLAUDE.md
├── tasks.md
├── android/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   ├── theme.dart              # Light and dark themes
│   │   ├── routes.dart             # Named routes
│   │   └── constants.dart          # Speed thresholds, cutoff hours, etc.
│   ├── features/
│   │   ├── auth/
│   │   │   ├── screens/            # Login, onboarding screens
│   │   │   ├── services/           # Google sign-in + Firebase Auth service
│   │   │   └── providers/          # Auth state
│   │   ├── tracking/
│   │   │   ├── screens/            # Active tracking UI
│   │   │   ├── services/           # Tracelet wrapper, trip processor
│   │   │   └── providers/          # Tracking state
│   │   ├── dashboard/
│   │   │   ├── screens/            # Home dashboard
│   │   │   ├── widgets/            # Summary card, today's trips, FAB
│   │   │   └── providers/
│   │   ├── trips/
│   │   │   ├── screens/            # Daily log, trip detail, manual entry form
│   │   │   ├── widgets/            # Trip card, route map, calendar
│   │   │   └── providers/
│   │   ├── stats/
│   │   │   ├── screens/            # Stats dashboard
│   │   │   ├── widgets/            # Charts, trend lines, traffic breakdown
│   │   │   └── providers/
│   │   └── settings/
│   │       ├── screens/            # Settings, restore from cloud
│   │       └── providers/
│   ├── database/
│   │   ├── database.dart           # Drift database class
│   │   ├── tables/                 # Table definitions (trips, sync_queue, user_preferences)
│   │   └── daos/                   # Data access objects
│   ├── sync/
│   │   ├── sync_engine.dart        # Sync queue processor
│   │   └── api_client.dart         # HTTP client for Cloud Functions
│   ├── notifications/
│   │   └── notification_service.dart
│   └── shared/
│       ├── widgets/                # Reusable UI components
│       ├── utils/                  # Date helpers, formatters, speed calculations
│       └── models/                 # Shared data models / DTOs
├── test/
│   ├── unit/                       # Drift DAOs, stats logic, sync logic
│   ├── widget/                     # Screen and component tests
│   └── integration/                # Full flow tests
└── backend/
    ├── firebase.json               # Firebase project config (functions, emulators)
    ├── firestore.rules             # Firestore Security Rules (deny-all to clients)
    ├── functions/
    │   ├── src/
    │   │   ├── handlers/
    │   │   │   ├── sync-trips.ts   # POST /trips/sync
    │   │   │   ├── delete-trip.ts  # DELETE /trips/{tripId}
    │   │   │   └── restore-trips.ts # GET /trips/restore
    │   │   ├── utils/
    │   │   │   ├── firestore.ts    # Firestore Admin SDK helpers
    │   │   │   ├── auth.ts         # Firebase ID-token verification
    │   │   │   └── validation.ts   # Input validation schemas (zod)
    │   │   └── types/
    │   │       └── trip.ts         # Shared TypeScript types
    │   ├── tsconfig.json
    │   └── package.json
```

---

## Architecture Decisions

### Data Flow
```
User taps Start → Tracelet captures GPS → User taps Stop
→ Trip processor computes duration, distance, polyline, traffic stats
→ Trip saved to Drift (trips table)
→ Sync queue entry created (sync_queue table)
→ Sync engine picks up pending entries when online
→ POST to HTTPS Cloud Function (Firebase ID token in header) → Firestore
→ On success: mark sync_queue entry as synced
```

### Sync Strategy: Client-Authoritative (One-Way Push)
- **Drift is the single source of truth.** All reads come from Drift, never from the server.
- **Firestore is a backup.** Server stores a copy for restore purposes only.
- **Never use the `cloud_firestore` SDK in the Flutter client.** The app talks to the backend only over REST (HTTPS Cloud Functions). This preserves offline-first (Drift = SOT) and keeps the backend swappable.
- **Sync is one-way:** client → server. No server → client sync in v0.1.
- **Restore flow:** User manually triggers from settings → GET /trips/restore → write into Drift (skip duplicates by trip UUID).
- **No conflict resolution needed.** Client always wins because it's the only writer.

### Offline-First
- The app must work fully without network. All features (tracking, stats, trip management) use Drift directly.
- Sync happens opportunistically: on app resume, on connectivity restored, after trip save.
- Never block UI on network calls. Sync is background-only.

### Traffic Calculation
- **Stuck threshold:** speed < 10 km/h = stuck in traffic
- **Moving:** speed >= 10 km/h
- Tracelet provides speed samples at GPS intervals. Process these into `time_moving_seconds` and `time_stuck_seconds` per trip.
- Store both values in the trips table for fast stats queries.

### Direction Auto-Labeling
- Morning cutoff: trips starting before configurable hour (default 12:00) = "to_office"
- Evening cutoff: trips starting after configurable hour (default 12:00) = "to_home"
- User can always manually change the label via edit.

---

## API Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | /trips/sync | Batch upsert trips from client sync queue | Firebase |
| DELETE | /trips/{tripId} | Soft-delete a trip in Firestore | Firebase |
| GET | /trips/restore | Return all trips for authenticated user | Firebase |

**All endpoints require a Firebase ID token in the Authorization header, verified server-side via the Firebase Admin SDK.**

---

## Drift Schema Summary

### trips
| Column | Type | Notes |
|--------|------|-------|
| id | text (UUID) | Primary key, generated client-side |
| user_id | text | Firebase uid |
| start_time | dateTime | |
| end_time | dateTime | |
| duration_seconds | integer | Computed from start/end |
| distance_meters | real | From Tracelet |
| route_polyline | text | Encoded polyline string |
| direction | text | "to_office" or "to_home" |
| time_moving_seconds | integer | Speed >= 10 km/h |
| time_stuck_seconds | integer | Speed < 10 km/h |
| is_manual_entry | boolean | True if user entered manually |
| created_at | dateTime | |
| updated_at | dateTime | |

### sync_queue
| Column | Type | Notes |
|--------|------|-------|
| id | integer | Auto-increment PK |
| trip_id | text | FK to trips.id |
| action | text | "create", "update", or "delete" |
| payload | text | JSON-serialized trip data |
| status | text | "pending", "synced", or "failed" |
| retry_count | integer | Max 3 retries |
| created_at | dateTime | |
| synced_at | dateTime | Nullable |

### user_preferences
| Column | Type | Notes |
|--------|------|-------|
| id | integer | Single row, PK = 1 |
| user_id | text | |
| dark_mode | text | "system", "light", or "dark" |
| morning_cutoff_hour | integer | Default 12 |
| evening_cutoff_hour | integer | Default 12 |
| reminder_enabled | boolean | Default false |
| reminder_time | text | HH:mm format |
| weekend_reminder | boolean | Default false |

---

## Coding Conventions

### Dart / Flutter
- Use Dart 3 with null safety throughout. No `dynamic` types unless absolutely necessary.
- Feature-first folder structure. Each feature owns its screens, widgets, services, and providers.
- Prefer `const` constructors wherever possible.
- Name files in `snake_case.dart`. Name classes in `PascalCase`.
- Keep widgets small. Extract into separate files if a widget exceeds ~100 lines.
- Use `sealed` classes or enums for finite state (tracking state, sync status, direction).
- Format all Dart code with `dart format`.

### TypeScript / Cloud Functions
- Strict TypeScript (`"strict": true` in tsconfig).
- Use the Firebase Admin SDK (`firebase-admin/firestore`, `firebase-admin/auth`) and `firebase-functions` v2 HTTPS triggers.
- Each HTTPS Cloud Function handler is a single file in `backend/functions/src/handlers/`.
- Verify the Firebase ID token at handler entry (Admin SDK `verifyIdToken`) before any work. Reject with 401 on failure.
- Validate all input at handler entry using a validation utility (zod). Never trust client data.
- Return consistent response shape: `{ statusCode, body: { data?, error? } }`.

### General
- UUIDs for all entity IDs, generated client-side (`uuid` package in Dart).
- All timestamps in ISO 8601 / UTC. Convert to local time only in the UI layer.
- No hardcoded strings for labels, thresholds, or config values. Use `constants.dart`.
- Meaningful commit messages. Prefix with feature area: `[tracking]`, `[sync]`, `[backend]`, `[stats]`, etc.

---

## Common Commands

```bash
# Flutter
flutter run                          # Run on connected device
flutter build apk --release          # Build release APK
flutter test                         # Run all tests
flutter test test/unit/              # Run unit tests only
dart run build_runner build          # Generate Drift code
dart format .                        # Format all Dart files
flutter analyze                      # Static analysis

# Backend
cd backend/functions
npm install                          # Install dependencies
npm run build                        # Compile TypeScript
firebase emulators:start             # Run Auth + Firestore + Functions locally
firebase deploy --only functions     # Deploy Cloud Functions
firebase deploy --only firestore:rules  # Deploy Firestore Security Rules
```

---

## Important Notes

- **Never read from the server for normal app operation.** Drift is the source of truth. Server is backup only.
- **Never block UI on network.** All sync is async and background.
- **Tracelet owns GPS.** Do not write custom location tracking code. Use Tracelet's API and process its output.
- **Speed threshold (10 km/h) is a constant.** Define it once in `constants.dart`, reference everywhere.
- **Auth tokens go in flutter_secure_storage.** Never store in shared preferences or plain text.
- **Sync queue retries max 3 times** with exponential backoff. After 3 failures, mark as failed and surface to user if needed.
- **Soft deletes everywhere.** Trips are never hard-deleted from Firestore. Mark `deleted: true`.
- **Test on real Android devices** for GPS and background service behavior. Emulator GPS simulation is unreliable for traffic calculations.

---

## Rules for Claude

### Behavior
- **Ask before assuming.** When requirements are ambiguous, a design decision has multiple valid options, or you're unsure about the user's intent — stop and ask clarifying questions. Never guess and build the wrong thing.
- **No shortcuts.** Do not skip steps, omit error handling, leave placeholder code (`// TODO`), stub out implementations, or simplify logic to save time. Every piece of code you write should be production-ready.
- **Read before writing.** Always read existing files before modifying them. Understand the surrounding code, patterns in use, and how the module fits into the larger system.
- **One module, one agent.** When working on multiple modules or features (e.g., auth + tracking + sync), spin up a separate agent for each module. Do not mix unrelated module work in a single agent.
- **Follow the existing patterns.** Match the conventions already in the codebase — naming, file structure, state management patterns, error handling style. Do not introduce new patterns without asking.
- **Verify after changes.** After writing or editing code, run the relevant linter, formatter, or tests to confirm nothing is broken. Don't assume it works.

### Backend / Cloud Functions Rules
- **TypeScript with full type safety.** All Cloud Function handlers must use strict TypeScript. Define explicit types for all request/response payloads, Firestore documents, and function parameters. No `any` types.
- **Use the Firebase Admin SDK with typed interfaces.** Define TypeScript interfaces for every Firestore document. Use `FirestoreDataConverter` (or typed wrappers) so reads/writes are mapped to interfaces.
- **Verify auth, then validate, then trust.** Verify the Firebase ID token (`verifyIdToken`) first, then validate the request body with zod at handler entry. After that, the data is trusted and typed — no redundant checks deeper in the code.
- **Lock Firestore down.** Security Rules deny all client access; only the Admin SDK (Cloud Functions) reads/writes trip data. Default-deny — keep it that way.
- **Each handler is self-contained.** One file per handler in `backend/functions/src/handlers/`. Shared utilities go in `backend/functions/src/utils/`. Do not create cross-handler dependencies.

### Frontend / Flutter Rules
- **Drift is the only data source for UI.** Screens and widgets must never read from the network directly. All data comes from Drift queries.
- **Riverpod for all state.** Do not use `setState`, `ChangeNotifier`, or other state management approaches. All state flows through Riverpod providers.
- **Keep widgets under 100 lines.** If a widget grows beyond ~100 lines, extract sub-widgets into separate files in the same feature directory.
- **Use `sealed` classes for finite state.** Tracking state, sync status, trip direction, and similar enums/states must use sealed classes or enums — never raw strings.
- **No hardcoded values.** All thresholds, labels, durations, and config values go in `lib/config/constants.dart`.

### Code Quality
- **No dead code.** Do not leave commented-out code, unused imports, or unreachable branches. Delete what isn't needed.
- **No speculative abstractions.** Only build what is needed right now. Do not create generic utilities, base classes, or factory patterns for a single use case.
- **Meaningful names.** Variables, functions, and files should describe what they do. Avoid abbreviations unless they are universally understood (e.g., `id`, `url`, `db`).
- **Test what matters.** When writing a module, include unit tests for business logic (stats calculations, traffic thresholds, sync queue state transitions). Don't test framework boilerplate.

### Task Discipline
- **Check tasks.md before starting work.** Verify which tasks are relevant to the current request. Update task checkboxes as you complete items.
- **One concern per commit.** Each commit should address a single feature, fix, or task. Use the commit prefix convention: `[tracking]`, `[sync]`, `[backend]`, `[auth]`, `[stats]`, `[dashboard]`, `[settings]`, `[infra]`.

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Commute Tracker**

A consumer Android app that lets anyone track their daily commute with a simple start/stop button, then shows them exactly how much time they spend stuck in traffic and how their commute trends over weeks. Built with Flutter, backed by Firebase for cloud sync and restore.

**Core Value:** Show people the reality of their commute — time wasted in traffic and how it changes over time. If nothing else works, this insight must.

### Constraints

- **Platform**: Android only for v0.1 — ship fast, expand later
- **Timeline**: Ship fast — minimize scope creep, prioritize working features over polish
- **Architecture**: Offline-first, client-authoritative — never block UI on network
- **Auth**: Google Sign-In via Firebase Auth (FlutterFire)
- **Backend**: Firebase serverless (Firebase Auth, HTTPS Cloud Functions, Firestore) via Firebase CLI
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| Flutter | 3.41.6 (stable) | Cross-platform UI framework | Locally installed, verified current stable. Dart 3.11.4. Material 3 support, mature Android platform channel APIs for background services and permissions. | HIGH |
| Dart | 3.11.4 | Language runtime | Ships with Flutter 3.41.6. Sealed classes, pattern matching, records all stable. Required for Drift code generation and Riverpod annotations. | HIGH |
| Drift | ^2.22 | Local SQLite database (source of truth) | Best-in-class type-safe SQLite for Flutter. Reactive streams, code generation, migration support. Far superior to sqflite for complex queries (stats aggregation, sync queue management). | MEDIUM |
| Riverpod | ^2.6 (flutter_riverpod + riverpod_annotation + riverpod_generator) | State management | Compile-safe, testable, no BuildContext dependency. Code generation with `@riverpod` annotation eliminates boilerplate. The standard for new Flutter projects since 2024. | MEDIUM |
| geolocator + flutter_background_service | See GPS section below | GPS tracking | See detailed GPS section -- Tracelet requires investigation. | LOW |
| Firebase CLI | latest | Infrastructure as Code + deploy | Official Firebase tooling for Cloud Functions + Firestore + Security Rules. `firebase deploy` matches the 3-endpoint scope. Local testing via Emulator Suite. | HIGH |
### GPS / Location Stack (Critical Decision)
| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| geolocator | ^13.0 | High-level location API | Most popular Flutter location package (1000+ pub points). Provides position stream with speed, heading, accuracy. Works on Android/iOS. Well-maintained by Baseflow. | 
| flutter_background_service | ^5.0 | Background execution | Keeps GPS recording alive when app is backgrounded on Android. Uses foreground service with notification (required by Android 14+). |
| google_maps_flutter | ^2.9 | Map display for trip routes | Official Google Maps plugin. Render polylines on trip detail screen. |
| flutter_polyline_points | ^2.1 | Polyline encoding/decoding | Encode GPS points to compressed polyline string for storage. |
- `location` package: Less maintained than geolocator, smaller community, fewer features.
- `background_locator_2`: Abandoned/unmaintained as of 2024.
- Raw platform channels for GPS: Unnecessary complexity when geolocator handles it.
### Authentication
| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| firebase_core | latest | FlutterFire initialization | Required base for all FlutterFire plugins. Configured via `flutterfire configure` / `google-services.json`. Pin versions to a known-good set. |
| firebase_auth | latest | Firebase Authentication | First-party (Google owns Flutter). Handles Google sign-in, session persistence, and ID-token issuance/refresh automatically. |
| google_sign_in | ^6.2 | Google OAuth on device | Official Flutter plugin by Google. Provides the Google credential that `firebase_auth` consumes via `GoogleAuthProvider`. |
| flutter_secure_storage | ^9.2 | Secure token storage | Stores the Firebase ID token in Android Keystore for the sync layer. Never use SharedPreferences for auth tokens. |
### Data & Sync
| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| drift | ^2.22 | Local SQLite with type safety | Reactive queries (watch trips table), type-safe schema, generated code, migration support. DAOs keep query logic organized. |
| drift_dev | ^2.22 | Drift code generation (dev) | Generates `.g.dart` files from table definitions. |
| build_runner | ^2.4 | Code generation runner (dev) | Required by Drift and Riverpod for `dart run build_runner build`. |
| http | ^1.2 | HTTP client | Official Dart package. Sufficient for 3 REST endpoints (sync, delete, restore). No need for Dio. |
| connectivity_plus | ^6.1 | Network status detection | Detect online/offline for sync engine. Fires on connectivity change. |
| uuid | ^4.5 | UUID generation | Client-side trip ID generation. v4 random UUIDs. |
### UI & Charts
| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| fl_chart | ^0.69 | Charts and trend lines | Best Flutter charting library for custom charts. Line charts (4-week trends), bar charts (weekly totals), pie charts (traffic breakdown). |
| flutter_local_notifications | ^18.0 | Local push notifications | Tracking reminders, weekly summary notifications. Handles Android notification channels. |
| intl | ^0.19 | Date/time formatting | Format durations, dates, times for UI display. Standard Dart internationalization. |
| table_calendar | ^3.1 | Calendar widget | Daily log calendar view. Customizable, supports event markers on dates. |
### Backend (Firebase Cloud Functions / TypeScript)
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| TypeScript | ^5.5 | Cloud Function handler language | Strict type safety, excellent Firebase Admin SDK types. |
| Node.js | 20.x+ | Cloud Functions runtime | Supported runtime for Cloud Functions 2nd gen. |
| firebase-functions | latest | HTTPS trigger framework | v2 `onRequest` HTTPS triggers for the 3 REST endpoints. |
| firebase-admin | latest | Admin SDK (Firestore + Auth) | Server-side Firestore reads/writes + `verifyIdToken` for auth. Bypasses Security Rules (deny-all to clients). |
| zod | ^3.23 | Input validation | Schema-based validation at handler entry. Generates TypeScript types from schemas. |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| build_runner | Dart code generation | Run `dart run build_runner build` after schema/provider changes |
| flutter_lints | Static analysis | Use `flutter analyze` -- catches null safety issues, unused imports |
| very_good_analysis | Stricter lint rules | Opinionated lint rules. Use instead of default `flutter_lints` for higher code quality. |
| mockito + build_runner | Testing mocks | Generate typed mocks for DAOs, services in unit tests |
| Firebase Emulator Suite | Backend local testing | Run Auth + Firestore + Functions locally with hot-reload via `firebase emulators:start` |
## Installation
# Create Flutter project
# Core dependencies (add to pubspec.yaml)
# Dev dependencies
# Backend
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Drift | sqflite | Never for this project. sqflite has no type safety, no reactive queries, no migrations. Only use sqflite for trivial key-value storage. |
| Drift | Isar / ObjectBox | If you need NoSQL-style document storage. Not appropriate here -- trips table has relational structure (sync_queue FK, aggregation queries). |
| Riverpod | Bloc/Cubit | If team already knows Bloc. Riverpod is simpler for this app's state complexity (no complex event routing needed). |
| Riverpod | Provider (legacy) | Never. Provider is the predecessor; Riverpod fixes all its limitations (no BuildContext, compile-safe, better testing). |
| http | Dio | If you need interceptors, retry logic, or multipart uploads. This app has 3 simple JSON endpoints -- http is sufficient. |
| fl_chart | syncfusion_flutter_charts | If you need 50+ chart types or enterprise features. fl_chart is free, lighter, and covers line/bar/pie which is all we need. |
| geolocator | location | If geolocator has a blocking bug. Otherwise geolocator has better maintenance and larger community. |
| Firebase | AWS (Cognito/Lambda/DynamoDB/SAM) | If the project becomes a learning vehicle for AWS, or grows into queue processing / multi-service event flows. See `cloud-vendor-tradeoffs.pdf` for the full comparison. |
| Cloud Functions (HTTPS) | Direct Firestore SDK from client | Never for this project. Calling Firestore directly from Flutter breaks offline-first (Drift = SOT) and vendor portability. Always go through Cloud Functions over REST. |
| firebase_auth | amazon_cognito_identity_dart_2 | Only if migrating back to AWS Cognito. FlutterFire is first-party and far simpler for Google sign-in. |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Provider (state management) | Legacy package, Riverpod is its replacement by the same author | Riverpod |
| GetX | Encourages anti-patterns, tight coupling, poor testability | Riverpod |
| shared_preferences for tokens | Not encrypted, trivially readable on rooted devices | flutter_secure_storage |
| sqflite directly | No type safety, manual SQL strings, no reactive streams, painful migrations | Drift (wraps SQLite) |
| background_locator_2 | Abandoned/unmaintained | flutter_background_service + geolocator |
| cloud_firestore (in the Flutter client) | Breaks offline-first (Drift is SOT) and vendor portability; tempts direct DB access. | http → HTTPS Cloud Functions |
| AWS Cognito + Lambda + DynamoDB | Higher build effort (Hosted UI + deep links, single-table design) for a 3-endpoint app. Superseded by the Firebase decision. | Firebase Auth + Cloud Functions + Firestore |
| Hive | No SQL queries, no relations, poor for aggregation. Fine for key-value, bad for trip data. | Drift |
## Stack Patterns
- Use Drift as single source of truth for all UI reads
- Sync queue table tracks pending changes (create/update/delete)
- Sync engine runs on connectivity change + app resume + post-save
- Never block UI on network -- sync is fire-and-forget with retry
- geolocator provides position stream with speed data
- flutter_background_service keeps the stream alive when app is backgrounded
- Android foreground service notification is REQUIRED (Android 14+ enforces this)
- Process speed samples into time_moving vs time_stuck during trip finalization
- Drift tables + Riverpod providers both use code generation
- Run `dart run build_runner build` after changing any annotated code
- Use `dart run build_runner watch` during active development
- Generated files are `.g.dart` -- commit them to version control
## Version Compatibility
| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Flutter 3.41.6 | Dart 3.11.4 | Verified locally installed |
| drift ^2.22 | Dart >=3.0, Flutter >=3.10 | Requires build_runner for code gen |
| flutter_riverpod ^2.6 | riverpod_annotation ^2.6, riverpod_generator ^2.6 | Keep all three at same minor version |
| geolocator ^13.0 | Android API 21+, compileSdk 34+ | Needs location permissions in AndroidManifest |
| flutter_background_service ^5.0 | Android 8.0+ (API 26+) | Foreground service type must be declared |
| google_sign_in ^6.2 | Android compileSdk 34+ | Requires SHA-1 fingerprint in Google Cloud Console |
| drift + sqlite3_flutter_libs | Same version family | sqlite3_flutter_libs bundles native SQLite binary |
## Critical Version Notes
## Risk: Tracelet Package
## Sources
- Flutter 3.41.6 / Dart 3.11.4 -- verified from local installation (HIGH confidence)
- Package versions -- based on training data up to May 2025, flagged as MEDIUM confidence. Actual latest versions may be higher. Run `flutter pub add [package]` to get current versions.
- Firebase (Auth, Cloud Functions, Firestore), firebase-admin/firebase-functions SDKs -- well-established, first-party (HIGH confidence)
- Backend vendor switched AWS→Firebase on 2026-05-27 (see `cloud-vendor-tradeoffs.pdf`); FlutterFire versions should be pinned to a known-good set in pubspec.yaml
- Tracelet package -- UNVERIFIED, not found in training data (LOW confidence)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

| Skill | Description | Path |
|-------|-------------|------|
| dynamodb-table-designer | \| Dynamodb Table Designer - Auto-activating skill for AWS Skills. Triggers on: dynamodb table designer, dynamodb table designer Part of the AWS Skills skill category. | `.agents/skills/dynamodb-table-designer/SKILL.md` |
| flutter-architecting-apps | Architects a Flutter application using the recommended layered approach (UI, Logic, Data). Use when structuring a new project or refactoring for scalability. | `.agents/skills/flutter-architecting-apps/SKILL.md` |
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
