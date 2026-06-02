# Phase 13: Auth on iOS - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the **existing** Google Sign-In (built in Phase 9 for Android) work on **iOS**. The Dart auth stack — `firebase_auth` + `google_sign_in` (v7) + `flutter_secure_storage`, optional/guest sign-in, automatic FlutterFire session restore, ID-token caching — is already implemented and shared. This phase wires the iOS-specific client ID, hardens sign-in error/cancel UX, and validates the OAuth-in-Safari + Keychain-persistence flow on a real iPhone.

**In scope:**
- Add the iOS client ID to the existing `GoogleSignIn.instance.initialize(...)` call (`main.dart`)
- Sign-in error/cancel UX change (snackbar feedback) at the existing catch sites — shared across iOS + Android
- Real-device validation of Google OAuth (Safari redirect via reversed-client-ID URL scheme) and session persistence via iOS Keychain
- Android regression re-verification (shared-code edits touch the Android path)
- Requirements: **IOS-04** (Google sign-in on iOS), **IOS-05** (session persists via Keychain, no `-34018`)

**Out of scope:**
- Background GPS / CoreLocation work (Phase 14 — IOS-06/07/08)
- Any change to the Phase 9 auth architecture (auth gate, guest state, userId backfill) — those are locked and reused as-is
- New auth features (sign-out, account deletion) — still deferred as in Phase 9
- iOS Info.plist / entitlements setup — already completed in Phase 12 (IOS-03)

</domain>

<decisions>
## Implementation Decisions

### iOS Client ID Wiring
- **D-01:** Add `clientId: DefaultFirebaseOptions.currentPlatform.iosClientId` to the existing `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)` call in `lib/main.dart` (~line 83), **unconditionally** — no `defaultTargetPlatform` branch. `iosClientId` is `null` on Android (harmless — Android resolves its client ID from `google-services.json`) and populated on iOS. This matches roadmap success criterion #4 exactly. *(Claude's recommendation, user-accepted.)*
- **D-02:** **No `google_sign_in` version change.** The codebase is already on `google_sign_in ^7.2.0` — the v7 singleton API (`GoogleSignIn.instance`, `supportsAuthenticate()`, throws `GoogleSignInException` on cancel). iOS uses the same shared Dart auth code as Android; the only wiring difference is the `clientId` from D-01.

### Sign-In Error & Cancel UX (cross-platform change)
- **D-03:** Show a **snackbar for both** user-cancel **and** genuine failures. This intentionally **changes the current Phase 9 silent-cancel behavior**. Use distinct copy: cancel → e.g. "Sign-in canceled"; failure → e.g. "Sign-in failed — please try again."
- **D-04:** Update the two existing silent catch sites to surface the snackbar via `ScaffoldMessenger`:
  - `lib/features/auth/widgets/sign_in_sheet.dart` (~line 68) — currently `on GoogleSignInException { }` no-op
  - `lib/features/onboarding/screens/onboarding_screen.dart` (~line 127) — currently silent on `GoogleSignInException`
  Also catch **non-cancel** failures (e.g. the `StateError` for a null idToken thrown in `auth_service.dart`, and `FirebaseAuthException`) and show the failure-copy snackbar — these are the iOS Safari/redirect failure modes that don't exist on the Android in-app flow.
- **D-05:** Because these are **shared widgets**, the snackbar change also affects **Android** cancel UX (previously silent). This is intentional and accepted — it is the reason the Android regression check (D-06) is in scope.

### Cross-Platform Regression Scope
- **D-06:** Phase 13 acceptance **includes re-verifying Android Google sign-in still works** after the shared `main.dart` `initialize()` edit (D-01) and the shared cancel/error UX change (D-03/D-04). This phase is **not iOS-only**.

### Carried Forward — Locked in Phase 9, do NOT re-decide
- Sign-in is **optional**; guest is a permanent valid state (Phase 9 D-05/D-06).
- Stack: `firebase_auth` + `google_sign_in` + `flutter_secure_storage` (Phase 9 D-09).
- FlutterFire **auto-restores** the session on boot — no manual token validation; SDK handles ID-token refresh (Phase 9 D-03). On iOS this persistence is backed by the **Keychain** (the IOS-05 surface).
- Current ID token cached in `flutter_secure_storage` under `kFirebaseIdTokenKey` for the sync layer (Phase 9 D-10).
- Graceful degradation: if Firebase init fails / config absent, start in **guest** state, disable the sign-in button — no crash (Phase 9 D-15).
- Riverpod v3 `Notifier`/`NotifierProvider` + sealed-class `switch` (NOT `StateNotifier`/`.when`) — see `09-PATTERNS.md`.

### iOS Platform Constraints (from Phase 12 + signing state)
- Bundle ID **`com.travey.app`** (note "trav**e**y"); locked by Firebase project `travey-298a7`.
- Signing: **free personal team `2DG5SFXZ5Z`**, cert **expires every 7 days** — before a device test session, if the last install was >7 days ago, re-run `flutter run -d <device>` with the iPhone connected to re-provision.
- iOS **min deployment target 15.0**.
- **Keychain Sharing entitlement** + **reversed-client-ID URL scheme** already configured in Phase 12 (IOS-03). A `-34018` Keychain error in device logs means the Keychain Sharing entitlement is not active — verify on a physical device (success criterion #3).
- **`aps-environment` entitlement was removed** (free teams can't provision Push; app uses local notifications only). Do NOT re-add it.

### Claude's Discretion
- **iOS Firebase config source** (rely on `firebase_options.dart` `iosClientId` vs also adding `GoogleService-Info.plist` to the Runner target) — not selected for discussion; researcher/planner decide. Likely `firebase_options.dart` + the existing Info.plist reversed-client-ID is sufficient; confirm during research.
- Exact snackbar copy, styling, duration, and which `BuildContext`/`ScaffoldMessenger` each catch site uses.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` §iOS — **IOS-04** (Google sign-in on iOS via reversed-client-ID + `iosClientId`), **IOS-05** (session persists via Keychain, no `-34018`), **IOS-03** (entitlements + URL scheme, completed Phase 12)
- `.planning/ROADMAP.md` §Phase 13 — goal + 4 success criteria

### Prior Phase — the auth being ported (read before touching auth code)
- `.planning/phases/09-authentication/09-CONTEXT.md` — all Phase 9 auth decisions (D-01..D-16); the Android implementation this phase ports to iOS
- `.planning/phases/09-authentication/09-PATTERNS.md` — Riverpod v3 `Notifier`/sealed-`switch` pattern; CRITICAL CORRECTION vs the old `StateNotifier`/`.when` shorthand

### Existing Code — touch points
- `lib/main.dart` (~line 83) — `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)` — **add `clientId` here (D-01)**
- `lib/firebase_options.dart` (line 66) — `iosClientId` value source
- `lib/features/auth/services/auth_service.dart` — `signIn()` flow; throws `GoogleSignInException` on cancel, `StateError` on null idToken
- `lib/features/auth/widgets/sign_in_sheet.dart` (~line 68) — silent cancel catch → **add snackbar (D-04)**
- `lib/features/onboarding/screens/onboarding_screen.dart` (~line 127) — silent cancel catch → **add snackbar (D-04)**
- `lib/features/auth/providers/auth_providers.dart` — `authServiceProvider`, `authStateProvider`
- `lib/config/constants.dart` (lines 634, 644) — `kGoogleServerClientId`, `kFirebaseIdTokenKey`

### Snackbar precedent (reuse existing pattern, don't invent)
- `lib/features/trips/services/trip_actions.dart`, `lib/features/settings/widgets/restore_row.dart`, `lib/features/trips/widgets/edit_trip_sheet.dart` — existing `ScaffoldMessenger`/`SnackBar` usage to match

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Full Phase 9 auth feature (`lib/features/auth/`) — services, providers, screens, widgets all exist and work on Android. iOS reuses them unchanged except the `clientId` wiring (D-01) and snackbar additions (D-04).
- `firebase_options.dart` already generated with the iOS client ID (`iosClientId`, line 66) — no `flutterfire configure` re-run needed just to obtain it.
- Established `ScaffoldMessenger`/`SnackBar` usage across several features — reuse for the new sign-in feedback.

### Established Patterns
- Riverpod v3 manual providers, `Notifier<AuthState>` + sealed-class `switch` (NOT `StateNotifier`/`.when`) — see `09-PATTERNS.md`.
- `google_sign_in` v7 singleton flow: `GoogleSignIn.instance.initialize(...)` (called once in `main.dart`), then `supportsAuthenticate()` gate → `authenticate()` → Firebase credential exchange in `auth_service.dart`.

### Integration Points
- `lib/main.dart` — the single `initialize()` call is the one shared wiring point; D-01 edits it.
- The two catch sites (sign_in_sheet, onboarding_screen) are the shared UX points; D-04 edits them.
- iOS Keychain persistence is handled entirely by the Firebase iOS SDK — no Dart code; validated via device logs (no `-34018`).

</code_context>

<specifics>
## Specific Ideas

- D-01 is deliberately branch-free: passing `clientId: DefaultFirebaseOptions.currentPlatform.iosClientId` is correct on both platforms because `currentPlatform` returns the per-platform `FirebaseOptions` and `iosClientId` is only non-null for iOS/macOS.
- The snackbar change (D-03/D-04) is the one place this phase intentionally alters previously-shipped Android behavior — call it out explicitly in the plan so the Android regression check (D-06) covers it.
- Much of IOS-04/IOS-05 acceptance is **human-gated on a real iPhone** (Safari OAuth round-trip, persistence across force-quit, absence of `-34018` in device logs). Plan should separate automated/code checks from device-validation steps.

</specifics>

<deferred>
## Deferred Ideas

- **iOS Firebase config via `GoogleService-Info.plist`** — left to researcher/planner discretion (see Claude's Discretion). Not a blocking decision for this phase.
- **Sign-out / account deletion** — still deferred (as in Phase 9).
- **Background GPS / CoreLocation** — Phase 14 (IOS-06/07/08), explicitly out of scope here.

</deferred>

---

*Phase: 13-auth-on-ios*
*Context gathered: 2026-06-02*
