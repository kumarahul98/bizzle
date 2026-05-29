---
phase: 09-authentication
plan: "04"
subsystem: auth
tags: [riverpod, sealed-class, auth-gate, flutter, splash, onboarding]
dependency_graph:
  requires: [09-01, 09-02, 09-03]
  provides: [SplashScreen, SignInSuccessScreen, app.dart-auth-gate]
  affects: [lib/app.dart, lib/features/auth/screens/]
tech_stack:
  added: []
  patterns:
    - Sealed switch on AuthState (no default branch — compile-error safety net)
    - Inline splash frame as MaterialApp.home for AuthLoading state
    - pushReplacement navigation for one-time confirmation screen
    - Private sub-widgets extracted to keep build method under 100 lines
key_files:
  created:
    - lib/features/auth/screens/splash_screen.dart
    - lib/features/auth/screens/sign_in_success_screen.dart
  modified:
    - lib/app.dart
decisions:
  - SplashScreen uses scaffoldBackgroundColor (maps to bg token) rather than TraevyTokensExt.bg — bg is not exposed on the extension; scaffoldBackgroundColor is the canonical route to the same token
  - Widget type annotation removed from `home` variable in app.dart — very_good_analysis omit_local_variable_types lint requires it to be inferred
metrics:
  duration: "4m"
  completed: "2026-05-29"
  tasks_completed: 3
  files_modified: 3
---

# Phase 09 Plan 04: Auth Gate + Splash + Confirmation Screens Summary

**One-liner:** Static `SplashScreen` (bg-token + `TraevyLogoMark`) for `AuthLoading`, one-time `SignInSuccessScreen` (accentBg avatar + display headline + neutral CTA) for D-12, and `app.dart` sealed-switch auth gate routing to the correct home for all three `AuthState` variants.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Build the static splash screen (D-04) | 6433164 | lib/features/auth/screens/splash_screen.dart |
| 2 | Build the one-time confirmation screen (D-12) | c740e59 | lib/features/auth/screens/sign_in_success_screen.dart |
| 3 | Wire the app.dart auth gate (sealed switch) | a36c6b7 | lib/app.dart |

## What Was Built

### Task 1 — SplashScreen

`lib/features/auth/screens/splash_screen.dart` is a `StatelessWidget` with a `const` constructor. It renders a full-screen `ColoredBox` filled with `Theme.of(context).scaffoldBackgroundColor` (the canonical `bg` design token from `buildLightTheme`/`buildDarkTheme` in `lib/config/theme.dart` — line 335: `scaffoldBackgroundColor: t.bg`). The child is a `SizedBox.expand` containing a `Center(child: TraevyLogoMark())` at default size 56. No AppBar, no `CircularProgressIndicator`, no text — this is a flash-frame during Firebase session restore, typically sub-second. The `TraevyLogoMark` already inverts for light/dark automatically via `onSurface`/`scaffoldBackgroundColor` tokens inside the widget.

### Task 2 — SignInSuccessScreen

`lib/features/auth/screens/sign_in_success_screen.dart` is a `StatelessWidget` accepting a required `initial` String (the user's first name initial, passed by the Plan 05 onboarding handler). Layout mirrors the onboarding screen rhythm:

- `Scaffold` with `bg` scaffold background, `SafeArea`, `Padding(horizontal: 28, vertical: 24)`, `Column(crossAxisAlignment: start)`
- `_AvatarCircle`: 44 dp circle, `accentBg` fill, `accent`-colored initial (Inter 16px w700) — exact `AccountRow` avatar treatment
- 48 px gap (hero breathing room, UI-SPEC §C)
- `kCopyConfirmHeadline` in display style (Inter 36px / w700 / letterSpacing -1.2 / height 1.05)
- 12 px gap
- `kCopyConfirmBody` in body style (Inter 16px / w400 / `textDim` / height 1.5)
- `Spacer()`
- `const _LetsGoCta()`: neutral button shell (`bgElev` fill, `borderStr` outline, 14 px radius, `horizontal: 18 / vertical: 16`) with label `kCopyConfirmCta` (Inter 14px w600). Tap calls `Navigator.of(context).pushReplacement` to `MainShell` — back button cannot return to this one-time screen.

All user-facing copy uses named constants from `lib/config/constants.dart`. No inline string literals. Sub-widgets `_AvatarCircle` and `_LetsGoCta` extracted to keep `build` under 100 lines (CLAUDE.md).

### Task 3 — app.dart auth gate

`lib/app.dart` now watches `authStateProvider` via `ref.watch` inside `build`. The auth result drives an exhaustive Dart sealed switch:

```dart
final auth = ref.watch(authStateProvider);
final home = switch (auth) {
  AuthLoading()  => const SplashScreen(),
  AuthGuest()    => const MainShell(),
  AuthSignedIn() => const MainShell(),
};
```

No `.when()` is applied to `authStateProvider` — `.when()` is the `AsyncValue` API and would be a type error here. `AuthState` is a plain sealed class from a `NotifierProvider` (RESEARCH Pitfall 6 / A5). The switch has no `default` branch — a new `AuthState` variant would be a compile error at this call site (T-09-04-02 mitigation). `home: const MainShell()` replaced with `home: home`. The existing `ref.watch(directionBackfillProvider)` and `userPreferenceProvider.when(...)` themeMode block are unchanged.

## Verification Results

- `flutter analyze lib/app.dart lib/features/auth/screens/` — zero issues
- `flutter test` — 297 passed, 10 skipped (pre-existing Wave 0 stubs)
- `grep "switch (auth)" lib/app.dart` — matches; three arms, no default
- `grep "authStateProvider" lib/app.dart` — matches; no `.when(` on auth result
- `grep "CircularProgressIndicator|AppBar\(|Text\(" lib/features/auth/screens/splash_screen.dart` — no matches in code (only dartdoc)
- `grep "kCopyConfirmHeadline" sign_in_success_screen.dart` — found; no inline headline literal

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `TraevyTokensExt.bg` does not exist — used `scaffoldBackgroundColor` instead**

- **Found during:** Task 1 verification (`flutter analyze` reported `undefined_getter: The getter 'bg' isn't defined for the type 'TraevyTokensExt'`)
- **Issue:** The plan and PATTERNS both reference `TraevyTokensExt.bg`, but `bg` is a field on `TraevyTokens` (the data class) — not on `TraevyTokensExt` (the ThemeExtension). The extension only exposes the 14 non-Material tokens. The `bg` token is wired into `ThemeData.scaffoldBackgroundColor` and `ColorScheme.surface` (see `lib/config/theme.dart` lines 274 and 335).
- **Fix:** Replaced `tokens.bg` with `Theme.of(context).scaffoldBackgroundColor`, which resolves to the identical hex value and is the canonical way to access the `bg` token from a widget.
- **Files modified:** `lib/features/auth/screens/splash_screen.dart`
- **Commit:** 6433164

**2. [Rule 1 - Bug] `omit_local_variable_types` lint fired on explicit `final Widget home` annotation**

- **Found during:** Task 3 verification (`flutter analyze lib/app.dart` reported `info: Unnecessary type annotation on a local variable`)
- **Issue:** `very_good_analysis` enforces `omit_local_variable_types` — explicit type annotations on local variables are not permitted when the type can be inferred.
- **Fix:** Removed `Widget` type annotation; `final home = switch (auth) {...}` is inferred as `Widget` from the switch arm types.
- **Files modified:** `lib/app.dart`
- **Commit:** a36c6b7

## Known Stubs

None — all three screens/widgets are fully implemented. `SplashScreen` renders the real design token bg + logo. `SignInSuccessScreen` renders real copy constants + real navigation to `MainShell`. The auth gate switch routes correctly for all three `AuthState` variants.

## Threat Flags

No new security surface beyond what the plan's threat model covers:

- T-09-04-01: `SignInSuccessScreen` renders only the user's initial (first character) + fixed copy constants. No token, email, or uid logged or rendered.
- T-09-04-02: Exhaustive sealed switch with no `default` branch — new `AuthState` variant is a compile error at the `app.dart` call site.

## Self-Check: PASSED
