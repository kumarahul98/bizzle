# Stack Research

**Domain:** Flutter-based commute/GPS tracking app with offline-first architecture and AWS backend
**Researched:** 2026-04-11
**Confidence:** MEDIUM (versions verified where possible; web search unavailable for pub.dev lookups)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| Flutter | 3.41.6 (stable) | Cross-platform UI framework | Locally installed, verified current stable. Dart 3.11.4. Material 3 support, mature Android platform channel APIs for background services and permissions. | HIGH |
| Dart | 3.11.4 | Language runtime | Ships with Flutter 3.41.6. Sealed classes, pattern matching, records all stable. Required for Drift code generation and Riverpod annotations. | HIGH |
| Drift | ^2.22 | Local SQLite database (source of truth) | Best-in-class type-safe SQLite for Flutter. Reactive streams, code generation, migration support. Far superior to sqflite for complex queries (stats aggregation, sync queue management). | MEDIUM |
| Riverpod | ^2.6 (flutter_riverpod + riverpod_annotation + riverpod_generator) | State management | Compile-safe, testable, no BuildContext dependency. Code generation with `@riverpod` annotation eliminates boilerplate. The standard for new Flutter projects since 2024. | MEDIUM |
| geolocator + flutter_background_service | See GPS section below | GPS tracking | See detailed GPS section -- Tracelet requires investigation. | LOW |
| AWS SAM | latest | Infrastructure as Code | Official AWS tooling for Lambda + API Gateway + DynamoDB. Simpler than CDK for 3-endpoint APIs. Local testing with `sam local invoke`. | HIGH |

### GPS / Location Stack (Critical Decision)

**IMPORTANT FLAG:** "Tracelet" is referenced in CLAUDE.md as the GPS package, but it does not appear in pub.dev package search results that I can verify from training data. It may be a very new, niche, or private package. This needs validation before committing.

**Recommended approach -- use proven packages:**

| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| geolocator | ^13.0 | High-level location API | Most popular Flutter location package (1000+ pub points). Provides position stream with speed, heading, accuracy. Works on Android/iOS. Well-maintained by Baseflow. | 
| flutter_background_service | ^5.0 | Background execution | Keeps GPS recording alive when app is backgrounded on Android. Uses foreground service with notification (required by Android 14+). |
| google_maps_flutter | ^2.9 | Map display for trip routes | Official Google Maps plugin. Render polylines on trip detail screen. |
| flutter_polyline_points | ^2.1 | Polyline encoding/decoding | Encode GPS points to compressed polyline string for storage. |

**If Tracelet is validated as a real, maintained package** that wraps geolocator + background service + polyline encoding into one API, use it instead. But do not depend on an unverified package for the core feature.

**What NOT to use for GPS:**
- `location` package: Less maintained than geolocator, smaller community, fewer features.
- `background_locator_2`: Abandoned/unmaintained as of 2024.
- Raw platform channels for GPS: Unnecessary complexity when geolocator handles it.

### Authentication

| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| google_sign_in | ^6.2 | Google OAuth on device | Official Flutter plugin by Google. Handles credential flow, returns ID token for Cognito exchange. |
| amazon_cognito_identity_dart_2 | ^3.7 | Cognito token exchange | Community Dart SDK for Cognito. Exchange Google ID token for Cognito JWT. Lightweight -- no Amplify dependency. |
| flutter_secure_storage | ^9.2 | Secure token storage | Stores Cognito JWT and refresh tokens in Android Keystore. Required -- never use SharedPreferences for auth tokens. |

**Alternative considered:** AWS Amplify Flutter SDK. Rejected because Amplify pulls in massive dependencies for auth alone. This app only needs 3 API endpoints and token exchange -- `amazon_cognito_identity_dart_2` + `http` is far lighter.

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

### Backend (AWS Lambda / TypeScript)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| TypeScript | ^5.5 | Lambda handler language | Strict type safety, excellent DynamoDB SDK types. |
| Node.js | 20.x | Lambda runtime | LTS runtime, stable, well-supported by AWS. |
| @aws-sdk/client-dynamodb | ^3.600+ | DynamoDB client | AWS SDK v3, modular imports, tree-shakeable. |
| @aws-sdk/lib-dynamodb | ^3.600+ | DynamoDB Document client | Automatic marshalling/unmarshalling. Type-safe with interfaces. |
| zod | ^3.23 | Input validation | Schema-based validation at handler entry. Generates TypeScript types from schemas. |
| esbuild | ^0.24 | Lambda bundling | Fast bundling, tree-shaking. SAM integrates with esbuild natively. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| build_runner | Dart code generation | Run `dart run build_runner build` after schema/provider changes |
| flutter_lints | Static analysis | Use `flutter analyze` -- catches null safety issues, unused imports |
| very_good_analysis | Stricter lint rules | Opinionated lint rules. Use instead of default `flutter_lints` for higher code quality. |
| mockito + build_runner | Testing mocks | Generate typed mocks for DAOs, services in unit tests |
| SAM CLI | Backend local testing | `sam local invoke` to test Lambda handlers without deploying |

## Installation

```bash
# Create Flutter project
flutter create --org com.yourcompany --project-name commute_tracker .

# Core dependencies (add to pubspec.yaml)
flutter pub add drift sqlite3_flutter_libs
flutter pub add flutter_riverpod riverpod_annotation
flutter pub add geolocator flutter_background_service
flutter pub add google_sign_in amazon_cognito_identity_dart_2
flutter pub add flutter_secure_storage
flutter pub add http connectivity_plus uuid
flutter pub add fl_chart flutter_local_notifications
flutter pub add google_maps_flutter flutter_polyline_points
flutter pub add intl table_calendar

# Dev dependencies
flutter pub add -d drift_dev build_runner riverpod_generator
flutter pub add -d very_good_analysis mockito

# Backend
cd backend
npm init -y
npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb zod
npm install -D typescript @types/node esbuild aws-sam-cli
```

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
| SAM | CDK | If backend grows beyond 5-10 resources or needs complex constructs. SAM is simpler for this small API. |
| SAM | SST | If you want a more developer-friendly experience with live Lambda development. SST is good but adds abstraction over CDK. |
| amazon_cognito_identity_dart_2 | amplify_flutter (auth) | If you plan to use multiple Amplify categories (storage, analytics, etc). For auth-only, Amplify is too heavy. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Provider (state management) | Legacy package, Riverpod is its replacement by the same author | Riverpod |
| GetX | Encourages anti-patterns, tight coupling, poor testability | Riverpod |
| shared_preferences for tokens | Not encrypted, trivially readable on rooted devices | flutter_secure_storage |
| sqflite directly | No type safety, manual SQL strings, no reactive streams, painful migrations | Drift (wraps SQLite) |
| background_locator_2 | Abandoned/unmaintained | flutter_background_service + geolocator |
| AWS Amplify Flutter (full SDK) | Massive dependency tree for 3 endpoints. Pulls DataStore, Analytics, etc. | Direct Cognito SDK + http |
| firebase_auth | Wrong auth provider. Project uses AWS Cognito, not Firebase. | google_sign_in + Cognito SDK |
| Hive | No SQL queries, no relations, poor for aggregation. Fine for key-value, bad for trip data. | Drift |

## Stack Patterns

**Offline-first with sync queue:**
- Use Drift as single source of truth for all UI reads
- Sync queue table tracks pending changes (create/update/delete)
- Sync engine runs on connectivity change + app resume + post-save
- Never block UI on network -- sync is fire-and-forget with retry

**GPS tracking with background service:**
- geolocator provides position stream with speed data
- flutter_background_service keeps the stream alive when app is backgrounded
- Android foreground service notification is REQUIRED (Android 14+ enforces this)
- Process speed samples into time_moving vs time_stuck during trip finalization

**Code generation workflow:**
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

1. **Dart 3.11 sealed classes**: Use `sealed class TrackingState`, `sealed class SyncStatus` etc. Available since Dart 3.0 but well-supported tooling only in 3.5+.

2. **Android 14 (API 34) foreground service changes**: Must declare `foregroundServiceType` in AndroidManifest.xml. Use `location` type for GPS tracking. Without this, background GPS will be killed.

3. **Google Sign-In credential manager migration**: Google is migrating Android sign-in to Credential Manager API. The `google_sign_in` plugin handles this internally but check for updates if authentication fails on newer Android devices.

4. **Riverpod code generation**: The `@riverpod` annotation approach (riverpod_generator) is the recommended pattern going forward. Manual `StateNotifierProvider` is legacy.

## Risk: Tracelet Package

**Status: UNVERIFIED**

"Tracelet" is specified in CLAUDE.md for GPS capture but cannot be confirmed as a published pub.dev package. Options:

1. **If Tracelet exists and is maintained**: Use it. It may wrap geolocator + background service + polyline into a single API, which would simplify the tracking feature.
2. **If Tracelet does not exist or is unmaintained**: Use the geolocator + flutter_background_service + flutter_polyline_points combination recommended above.
3. **Action required**: Run `dart pub add tracelet` to test if the package exists and is compatible with Dart 3.11.

This is the highest-risk item in the stack because GPS tracking is the core feature.

## Sources

- Flutter 3.41.6 / Dart 3.11.4 -- verified from local installation (HIGH confidence)
- Package versions -- based on training data up to May 2025, flagged as MEDIUM confidence. Actual latest versions may be higher. Run `flutter pub add [package]` to get current versions.
- AWS SDK v3, SAM, Node.js 20.x -- well-established, unlikely to have breaking changes (HIGH confidence)
- Tracelet package -- UNVERIFIED, not found in training data (LOW confidence)

---
*Stack research for: Flutter commute/GPS tracking app with offline-first + AWS backend*
*Researched: 2026-04-11*
