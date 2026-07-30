# Security Review — Commute Tracker ("Traevy")

**Scope:** Android platform layer, Flutter/Dart app layer (auth, local storage, sync), Firebase backend (Cloud Functions, Firestore). Covers both the Google Sign-In account mode and the fully local/offline "guest" mode.
**Date:** 2026-07-26
**Method:** Static, read-only review of the repository (`/Users/coolman/bizzle`) — no dynamic testing, no live GCP/Play Console inspection.

---

## Executive Summary

The codebase shows a notably disciplined security posture for its size. The backend consistently applies a verify-token → validate-input → trust-data pattern across all five Cloud Function handlers, enforces ownership server-side (no handler ever trusts a client-supplied user ID), and Firestore is locked behind a genuine unconditional deny-all rule. Error paths and logs are deliberately scrubbed of tokens, PII, and stack traces. No secrets, private keys, or credentials are committed anywhere in the repo or its git history.

That said, the review surfaced a concrete set of gaps, the most significant being a **Play Store compliance gap** (the Data Safety declaration has not been updated to reflect that precise location is now collected and linked to the user's account), and **unencrypted at-rest storage of GPS routes and home/office coordinates** on-device, compounded by `allowBackup` not being explicitly disabled. These, along with several medium-severity items (no certificate pinning, no token-revocation check, disabled code obfuscation, no mock-location filtering), are detailed below.

---

## Findings Table

| # | Severity | Area | Location | Finding |
|---|----------|------|----------|---------|
| 1 | Critical | Cross-cutting / Compliance | `.planning/RELEASE-GATES.md`, `.planning/STATE.md` | Play Data Safety declaration not updated for precise-location collection |
| 2 | High | Flutter | `lib/database/database.dart`; `lib/features/tracking/services/trip_state_persister.dart`; `lib/features/tracking/services/pending_trip_store.dart` | No encryption at rest for trip routes / home-office coordinates (SQLite DB + 2 plaintext JSON files) |
| 3 | High | Android | `android/app/src/main/AndroidManifest.xml` | `android:allowBackup` not explicitly set (defaults to `true`), enabling extraction of the above unencrypted PII via `adb backup` |
| 4 | Medium | Flutter | `lib/sync/api_client.dart` | No certificate pinning — relies solely on system CA trust store |
| 5 | Medium | Firebase | `backend/functions/src/utils/auth.ts:48` | `verifyIdToken()` called without `checkRevoked=true` — revoked tokens remain valid until natural expiry (~1 hr) |
| 6 | Medium | Android | `android/app/build.gradle.kts:76-86` | R8/ProGuard minification disabled for release builds — no code obfuscation |
| 7 | Medium | Flutter | `lib/features/tracking/services/location_settings_builder.dart` | No mock-location (`Position.isMocked`) filtering in the GPS tracking pipeline |
| 8 | Medium | Firebase | `backend/functions/src/index.ts:26-52` | Cloud Function has no IAM-level invoker restriction backing the in-app auth check |
| 9 | Medium | Firebase | `backend/functions/src` (repo-wide) | No Firebase App Check configured — no bot/abuse layer beyond ID-token verification |
| 10 | Medium | Android | `android/app/src/main/AndroidManifest.xml:51`; merged manifest `WatchdogReceiver` | Exported components with no `android:permission`: `HomeWidgetBackgroundReceiver`, `WatchdogReceiver` |
| 11 | Medium | Cross-cutting | `lib/firebase_options.dart:56` vs `:64` | iOS Firebase config points at dev project (`travey-298a7`) while Android points at prod (`traevy-prod`) |
| 12 | Low | Flutter | `lib/features/auth/services/auth_service.dart:129-132` | `flutter_secure_storage` used with default options (no explicit `AndroidOptions(encryptedSharedPreferences: true)`) |
| 13 | Low | Android (local, not repo) | `android/key.properties` (gitignored, not committed) | Locally-stored keystore password follows a weak, guessable app-name+year pattern (`traevy2026`) |
| 14 | Informational | Flutter | `lib/features/tracking/services/tracking_service.dart:189-252` | Home-screen widget shows trip/traffic stats without requiring device unlock |
| 15 | Informational | Firebase | `.planning/RELEASE-GATES.md` | Cloud Functions runtime pinned to `nodejs24`, but live backend still on `nodejs20` (decommissioned 2026-10-30) |
| 16 | Informational | Firebase | `backend/functions/package-lock.json` | No `npm audit`/CVE sweep was run (no network access during this review) |

---

## Detailed Findings

### 1. [Critical] Play Data Safety declaration not updated
`.planning/RELEASE-GATES.md` and `.planning/STATE.md` (last updated 2026-07-25) both explicitly flag this as open: Phase 29 reversed an earlier decision (T-21-02) that home/office coordinates would never leave the device, but the Play Console Data Safety form still declares "no location data collected." Shipping a release build in this state is a Play Store policy violation and risks app removal or account action — this is a store-compliance/legal risk, not a code vulnerability, but it's release-blocking.

### 2. [High] No encryption at rest for trip/location data
- `lib/database/database.dart:330-337` opens Drift via a plain `NativeDatabase` (no `sqlcipher_flutter_libs` dependency anywhere in `pubspec.yaml`).
- `user_preferences.home_lat/home_lng/office_lat/office_lng` (`lib/database/tables/user_preferences_table.dart:146-161`) and `trips.route_polyline` (full GPS route, `lib/database/tables/trips_table.dart:59-62`) are stored unencrypted.
- Two additional plaintext JSON files duplicate trip PII outside the DB, in the app's **documents** directory: `active_trip.json` (`lib/features/tracking/services/trip_state_persister.dart:29`) and `pending_trip.json` (`lib/features/tracking/services/pending_trip_store.dart:73`). Notably, `database.dart`'s own code comment explains the DB deliberately avoids the documents directory to prevent iCloud-backup leakage — that reasoning wasn't extended to these two files.

Risk: anyone with filesystem access to the app sandbox (rooted device, physical access with debugging enabled, or an unencrypted device backup) can read a user's full commute history and home/office location in plaintext.

### 3. [High] `allowBackup` not explicitly disabled
Confirmed via grep across the entire `android/` tree — no `android:allowBackup` attribute exists in `AndroidManifest.xml`, so it defaults to `true`, and there is no `dataExtractionRules`/`fullBackupContent` XML restricting what gets backed up. Combined with Finding #2, this means `adb backup` (on a debuggable or rooted device) or Android's cloud auto-backup could exfiltrate the full unencrypted trip history and saved home/office coordinates.

### 4. [Medium] No certificate pinning
`lib/sync/api_client.dart:76-88` uses a plain injected `http.Client` with no pinning package (`http_certificate_pinning` or similar) in `pubspec.yaml`, and no custom `HttpClient`/`SecurityContext`/`badCertificateCallback` override anywhere in `lib/`. TLS is enforced (HTTPS-only base URL, no cleartext override, no `network_security_config.xml`), but the app trusts any certificate chaining to a system-trusted CA — a device with a malicious CA installed (e.g. via a rogue MDM profile or a tricked user) can MITM the sync traffic, including the bearer token.

### 5. [Medium] Token revocation not checked
`backend/functions/src/utils/auth.ts:48`:
```ts
const decoded = await getAuth().verifyIdToken(token);
```
This is the single-argument form; Admin SDK's `checkRevoked` parameter defaults to `false`. A token revoked server-side (disabled/deleted account, forced re-auth via `revokeRefreshTokens`) remains accepted by this backend until it naturally expires (~1 hour). Common tradeoff (checking revocation costs an extra lookup per request) but worth an explicit decision given this is an auth-critical path.

### 6. [Medium] Release builds are not obfuscated
`android/app/build.gradle.kts:76-86` — the release `buildType` block has no `minifyEnabled`/`shrinkResources`, confirmed by inline comment: *"minifyEnabled stays unset (R8 off — Flutter default)."* No `proguard-rules.pro` exists anywhere in the project. This means the shipped APK/AAB retains full class/method names, making it meaningfully easier to reverse-engineer the app's internal logic, API endpoint structure, and any assumptions baked into the client.

### 7. [Medium] No mock-location detection
`lib/features/tracking/services/location_settings_builder.dart` configures `AndroidSettings(accuracy: LocationAccuracy.high, ...)` with no check of `Position.isMocked` (geolocator exposes this from the underlying `FusedLocationProviderClient`). A user with Developer Options → "Select mock location app" enabled, or a companion app set as the system mock-location provider, can feed the tracker synthetic GPS coordinates that get recorded as real commute data. This is a data-integrity/anti-fraud gap rather than a confidentiality one — relevant if commute data ever feeds expense reimbursement or employer-facing reporting.

### 8. [Medium] No IAM-level backing control on the Cloud Function
`backend/functions/src/index.ts:26-52` mounts a single Express app behind one 2nd-gen `onRequest(app)` function, publicly invokable at the IAM layer (required, since auth is handled entirely in application code rather than via Firebase Callable functions). This means there is no secondary gate: if the in-code `verifyAuth()` check ever regressed or was bypassed by a code change, nothing at the infrastructure layer would stop an unauthenticated request from reaching handler logic.

### 9. [Medium] No App Check
No App Check integration exists in `backend/functions/src` (it appears only as a transitive dependency in `package-lock.json`). There is no bot/scripted-abuse defense layer beyond the per-request ID-token check — a valid but automated/scripted client can call the API at will, bounded only by the existing input-size and batch caps.

### 10. [Medium] Unprotected exported Android components
- `HomeWidgetBackgroundReceiver` (`es.antonborri.home_widget`, `android/app/src/main/AndroidManifest.xml:51`) is `exported="true"` with no `android:permission`, listening for the custom action `es.antonborri.home_widget.action.BACKGROUND`. Any app on the device can send this broadcast. The app never calls `HomeWidget.registerBackgroundCallback` (confirmed via grep of `lib/`), so this is currently an inert sink — but it's still unguarded third-party-plugin attack surface.
- `WatchdogReceiver` (flutter_background_service, visible in the merged manifest at `build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`) is similarly `exported="true"` with no permission and no intent-filter, meaning another app could target it directly by component name. Its only effect is restarting the tracking service, so real-world impact is low, but it's unprotected surface worth tightening.

### 11. [Medium] iOS/Android point at different Firebase projects
`lib/firebase_options.dart:56` (iOS) references `travey-298a7` (dev project), while `:64` (Android) references `traevy-prod`. Confirmed by `backend/.firebaserc` (`"dev": "travey-298a7"`, `"prod": "traevy-prod"`). This is documented in `.planning/RELEASE-GATES.md` as a deliberate, tracked state (iOS migration deferred) rather than an oversight, but it means the two platforms currently trust entirely different backends/security-rule deployments — worth confirming this doesn't create confusion if iOS work resumes.

### 12. [Low] `flutter_secure_storage` using default options
`lib/features/auth/services/auth_service.dart:129-132` and `lib/features/auth/providers/auth_providers.dart:78-82` instantiate `FlutterSecureStorage` with no `AndroidOptions`/`IOSOptions` override, relying on the plugin's defaults rather than an explicit `encryptedSharedPreferences: true` configuration. Not a demonstrated vulnerability, but an implicit dependency on a third-party plugin's current defaults rather than an explicit, reviewed choice. Note: grep found no site that actually reads this cached token back for API calls — `ApiClient` always pulls a live token via `FirebaseAuth.instance.currentUser?.getIdToken()` — so this stored value currently appears to be write-only/vestigial state, which lowers (but doesn't eliminate) the practical exposure.

### 13. [Low] Weak local keystore password
`android/key.properties` (present only on the local development machine, correctly excluded via `android/.gitignore:12` and confirmed absent from git history) contains:
```
storePassword=traevy2026
keyPassword=traevy2026
```
This follows an easily-guessable app-name+year pattern. Not a repo-level finding (never committed), but an operational recommendation to rotate to a high-entropy password, since anyone who learns the app name could reasonably guess this credential if the keystore file itself were ever exposed by another means.

### 14. [Informational] Lock-screen-visible commute stats
`lib/features/tracking/services/tracking_service.dart:189-252` and `lib/features/tracking/services/widget_state_writer.dart` write trip stats (distance/duration/speed, today's/week's traffic totals) to the home-screen widget via `HomeWidget.saveWidgetData`, visible without unlocking the device. Minor privacy consideration for shared/visible devices, not a data-breach vector.

### 15. [Informational] Cloud Functions runtime deadline
`.planning/RELEASE-GATES.md` notes the repo pins `nodejs24` but the live deployed backend still runs `nodejs20`, which Google decommissions 2026-10-30. Time-boxed operational item, not urgent as of this review's date.

### 16. [Informational] No dependency CVE sweep performed
This review did not have network access to run `npm audit` against `backend/functions/package-lock.json`. Direct dependency versions (`firebase-admin ^13.10.0`, `firebase-functions ^7.2.5`, `express ^5.2.1`, `zod ^4.4.3`) are all current majors as of this review, but a full audit against a live vulnerability database wasn't performed and should be run separately (e.g. in CI).

---

## What's Solid

These controls were verified as correctly and consistently implemented, and are worth explicitly protecting from regression:

- **Firestore lockdown**: `backend/firestore.rules` is a genuine, unconditional `allow read, write: if false` on every document — matches the documented design, verified by direct read of the file.
- **Verify → validate → trust, applied consistently**: all five Cloud Function handlers (`sync-trips.ts`, `delete-trip.ts`, `restore-trips.ts`, `sync-preferences.ts`, `restore-preferences.ts`) call `verifyAuth()` before any Firestore access, then validate input with zod (batch caps, UUID-format IDs, `.finite()` lat/lng bounds) before trusting any of it.
- **IDOR protection is real, not assumed**: `userId` is always forced server-side to the verified token uid — no handler ever writes or queries using a client-supplied user ID. `delete-trip.ts` deliberately returns 404 (not 403) for another user's trip, an intentional existence-oracle defense.
- **Error paths are scrubbed**: `SyncException` (Flutter) and `AuthError` (Cloud Functions) never surface stack traces, tokens, uids, or raw SDK errors to the caller; no `console.log`/`debugPrint` of sensitive data was found in the auth or sync code paths.
- **No secrets committed**: no private keys, service-account credentials, or `.env` files exist anywhere in the repo or its git history. The one real secret (`android/key.properties`) is correctly gitignored and confirmed never committed.
- **No SQL injection surface**: every raw `customStatement`/`customUpdate` call in Drift is parameterized; no string concatenation of user-controlled data into SQL was found.
- **Location permission flow is correctly sequenced**: foreground → background → notification permissions are requested in the Play-Store-mandated order, and the GPS foreground service is correctly typed (`foregroundServiceType="location"`) and non-exported (`android:exported="false"`).
- **No WebViews, no externally-invocable deep links**: the app's internal `traevy://widget` URI is only ever dispatched as an explicit-component `PendingIntent`, never registered as a manifest intent-filter, so it can't be triggered by another app.
- **Local-only / guest mode is a genuinely separate code path**: `AuthStateNotifier` never subscribes to Firebase's `authStateChanges()` when `firebaseReady=false`, so no Firebase Auth platform channel is touched at all in fully-offline usage — the "local only" claim in `CLAUDE.md` holds up in code.
