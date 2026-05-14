---
phase: 08-ui-overhaul
plan: "02"
subsystem: ui-theme
tags:
  - design-tokens
  - theme-extension
  - google-fonts
  - material3
  - wave-2-green
dependency_graph:
  requires:
    - google_fonts ^8.1.0 dependency (Plan 01)
    - Inter + JetBrainsMono TTF assets (Plan 01)
    - Phase 8 constants kFontUI/kFontMono (Plan 01)
    - Wave-0 RED tests theme_test.dart + theme_extension_test.dart (Plan 01)
  provides:
    - TraevyTokens immutable data class (18 fields, light + dark const instances)
    - TraevyTokensExt ThemeExtension<TraevyTokensExt> (14 fields, full lerp)
    - TraevyFonts.ui() / TraevyFonts.mono() TextStyle factories
    - buildLightTheme() / buildDarkTheme() — fully-wired Material 3 ThemeData
    - GoogleFonts runtime fetch disabled in main.dart
  affects:
    - lib/config/theme.dart (rewritten)
    - lib/config/theme_extension.dart (new)
    - lib/app.dart (theme wiring updated)
    - lib/main.dart (fetch-disable added)
    - test/unit/config/theme_test.dart (binding init added)
    - test/unit/config/theme_extension_test.dart (stub type corrected)
tech_stack:
  added: []
  patterns:
    - TraevyTokens immutable data class with private constructor + static const instances
    - TraevyTokensExt ThemeExtension registered on ThemeData.extensions
    - Explicit ColorScheme constructor (no ColorScheme.fromSeed) — Pitfall 3
    - CardThemeData elevation:0 with BorderRadius.circular(16) — Pitfall 4
    - GoogleFonts.interTextTheme base + copyWith overrides for specific roles
    - TraevyTokensExt re-exported from theme.dart for single-import convenience
key_files:
  created:
    - lib/config/theme_extension.dart
  modified:
    - lib/config/theme.dart
    - lib/app.dart
    - lib/main.dart
    - test/unit/config/theme_test.dart
    - test/unit/config/theme_extension_test.dart
decisions:
  - "TraevyTokensExt re-exported from theme.dart so the Wave-0 test (which only imports theme.dart) resolves TraevyTokensExt without a separate import"
  - "Added setUpAll(TestWidgetsFlutterBinding.ensureInitialized) to theme_test.dart because GoogleFonts.interTextTheme requires the Flutter binding even in unit tests"
  - "_StubThemeExtension updated to extend ThemeExtension<TraevyTokensExt> (not ThemeExtension<_StubThemeExtension>) so it satisfies the lerp parameter type while still failing the is! TraevyTokensExt guard"
  - "buildLightTheme and buildDarkTheme included in theme.dart (Task 1 file) rather than split — avoids circular dependency since _build() calls TraevyTokensExt.fromTokens() which lives in theme_extension.dart that imports theme.dart"
  - "ColorScheme constructed explicitly per Pitfall 3 — no ColorScheme.fromSeed to prevent tonal palette overrides"
metrics:
  duration_minutes: 25
  completed: "2026-05-14"
  tasks_completed: 2
  files_created: 1
  files_modified: 5
---

# Phase 8 Plan 02: Traevy Theme System Summary

**One-liner:** TraevyTokens (18 color fields, light+dark const), TraevyTokensExt ThemeExtension (14-field full lerp per Review MEDIUM #3), TraevyFonts helpers, and explicit Material 3 ColorScheme wiring — all Wave-0 RED tests turn GREEN.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | TraevyTokens + TraevyTokensExt (full 14-field lerp) + TraevyFonts | 3eb4a8d | lib/config/theme.dart, lib/config/theme_extension.dart, test/unit/config/theme_extension_test.dart |
| 2 | buildLightTheme + buildDarkTheme + app.dart wire + main.dart fetch-disable | 02406c4 | lib/app.dart, lib/main.dart, test/unit/config/theme_test.dart |

## What Was Built

### TraevyTokens Data Class

`lib/config/theme.dart` exports an `@immutable class TraevyTokens` with a private `_()` constructor and two `static const` instances:

- `TraevyTokens.light` — 18 light-mode color fields with CONTEXT.md hex values
- `TraevyTokens.dark` — 18 dark-mode color fields with CONTEXT.md hex values

All 18 fields: `bg`, `bgElev`, `surface`, `surface2`, `border`, `borderStr`, `text`, `textDim`, `textMuted`, `moving`, `movingBg`, `stuck`, `stuckBg`, `accent`, `accentBg`, `danger`, `record`, `mapBg`.

### TraevyTokensExt ThemeExtension

`lib/config/theme_extension.dart` exports `TraevyTokensExt extends ThemeExtension<TraevyTokensExt>` with:

- 14 `final Color` fields (the non-Material token subset): `bgElev`, `surface2`, `border`, `borderStr`, `textDim`, `textMuted`, `moving`, `movingBg`, `stuck`, `stuckBg`, `accent`, `accentBg`, `record`, `mapBg`
- `factory TraevyTokensExt.fromTokens(TraevyTokens t)` — copies the 14 fields from a `TraevyTokens` instance
- `copyWith({...})` — all 14 fields optional
- `lerp(other, t)` — interpolates **every one of the 14 fields** via explicit `Color.lerp(field, other.field, t)!` calls (Review MEDIUM #3)

#### lerp implementation — Review MEDIUM #3 compliance

All 14 `Color.lerp(...)` calls are explicitly named in the `lerp` body:

```dart
bgElev:    Color.lerp(bgElev,    other.bgElev,    t)!,
surface2:  Color.lerp(surface2,  other.surface2,  t)!,
border:    Color.lerp(border,    other.border,    t)!,
borderStr: Color.lerp(borderStr, other.borderStr, t)!,
textDim:   Color.lerp(textDim,   other.textDim,   t)!,
textMuted: Color.lerp(textMuted, other.textMuted, t)!,
moving:    Color.lerp(moving,    other.moving,    t)!,
movingBg:  Color.lerp(movingBg,  other.movingBg,  t)!,
stuck:     Color.lerp(stuck,     other.stuck,     t)!,
stuckBg:   Color.lerp(stuckBg,   other.stuckBg,   t)!,
accent:    Color.lerp(accent,    other.accent,    t)!,
accentBg:  Color.lerp(accentBg,  other.accentBg,  t)!,
record:    Color.lerp(record,    other.record,    t)!,
mapBg:     Color.lerp(mapBg,     other.mapBg,     t)!,
```

`grep -c "Color.lerp(" lib/config/theme_extension.dart` returns **14**.

### TraevyFonts Helpers

```dart
class TraevyFonts {
  static TextStyle ui({required double size, FontWeight weight, Color? color,
                       double letterSpacing, double? height});
  static TextStyle mono({required double size, FontWeight weight, Color? color,
                         double letterSpacing});
}
```

`ui(...)` delegates to `GoogleFonts.inter(...)`. `mono(...)` delegates to `GoogleFonts.jetBrainsMono(...)`. Runtime fetching is disabled so both resolve from the bundled TTF assets in `assets/fonts/`.

### buildLightTheme / buildDarkTheme

Both are top-level functions in `lib/config/theme.dart` delegating to a private `_build(TraevyTokens t, Brightness b)` factory.

#### ColorScheme → Token Mapping

| ColorScheme slot | Token |
|-----------------|-------|
| `primary` | `t.accent` |
| `onPrimary` | `t.bg` |
| `secondary` | `t.moving` |
| `onSecondary` | `t.bg` |
| `error` | `t.danger` |
| `onError` | `Colors.white` |
| `surface` | `t.bg` |
| `onSurface` | `t.text` |
| `surfaceContainerLowest` | `t.bgElev` |
| `surfaceContainerLow` | `t.bgElev` |
| `surfaceContainer` | `t.surface` |
| `surfaceContainerHigh` | `t.surface2` |
| `surfaceContainerHighest` | `t.surface2` |
| `outline` | `t.border` |
| `outlineVariant` | `t.borderStr` |
| `onSurfaceVariant` | `t.textDim` |

Constructed explicitly — no `ColorScheme.fromSeed` (Pitfall 3 avoided).

#### TextTheme Overrides

Base from `GoogleFonts.interTextTheme(ThemeData(brightness: b).textTheme)` with these role overrides:

| Role | Size | Weight | LetterSpacing | Height |
|------|------|--------|---------------|--------|
| `displaySmall` | 36 | w700 | -1.2 | 1.05 |
| `titleLarge` | 22 | w700 | -0.6 | — |
| `bodyLarge` | 15 | w500 | 0 | — |
| `bodyMedium` | 13 | w500 | 0 | — |
| `labelLarge` | 14 | w600 | 0 | — |
| `labelMedium` | 12 | w600 | 1.0 | — |
| `labelSmall` | 11 | w600 | 1.0 | — |

Mono font (`JetBrains Mono`) is NOT in `textTheme` — callers use `TraevyFonts.mono(...)` directly.

#### Other Theme Slots

- `cardTheme`: `elevation: 0`, `color: t.bgElev`, `margin: EdgeInsets.zero`, `shape: RoundedRectangleBorder(radius: 16, border: t.border)` — Pitfall 4 compliant
- `appBarTheme`: `bg: t.bg`, `surfaceTintColor: transparent`, `elevation: 0`, `scrolledUnderElevation: 0`
- `navigationBarTheme`: `bg: t.bgElev`, `height: 64`, selected/unselected icon+label via `WidgetStateProperty`
- `dividerTheme`: `color: t.border`, `thickness: 1`, `space: 1`
- `iconTheme`: `color: t.text`, `size: 22`
- `extensions`: `[TraevyTokensExt.fromTokens(t)]`

### app.dart + main.dart Wiring

- `lib/app.dart`: `theme: buildLightTheme()`, `darkTheme: buildDarkTheme()` — legacy `lightTheme`/`darkTheme` finals removed
- `lib/main.dart`: `GoogleFonts.config.allowRuntimeFetching = false` added immediately after `WidgetsFlutterBinding.ensureInitialized()` and before `runApp` (Pitfall 2)

## Verification Results

| Check | Result |
|-------|--------|
| `flutter analyze lib/config/ lib/app.dart lib/main.dart` | No issues found |
| `flutter test test/unit/config/theme_test.dart` | 12/12 PASS (GREEN) |
| `flutter test test/unit/config/theme_extension_test.dart` | 24/24 PASS (GREEN) |
| `flutter test test/unit/config/` | 44/44 PASS |
| `flutter test test/widget/features/dashboard/dashboard_screen_test.dart` | 12/12 PASS (Phase 7 regression clean) |
| `grep -c "Color.lerp(" lib/config/theme_extension.dart` | 14 (all 14 fields) |
| Legacy `lightTheme`/`darkTheme` in `lib/config/theme.dart` | NONE |
| `GoogleFonts.config.allowRuntimeFetching = false` before `runApp` | CONFIRMED |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wave-0 theme_extension_test _StubThemeExtension type mismatch**
- **Found during:** Task 1 test GREEN phase
- **Issue:** `_StubThemeExtension` extended `ThemeExtension<_StubThemeExtension>` but `lerp` parameter is `ThemeExtension<TraevyTokensExt>?` — Dart type system rejected the call `light.lerp(stub, 0.5)` at compile time
- **Fix:** Changed `_StubThemeExtension` to extend `ThemeExtension<TraevyTokensExt>`. It is still NOT a `TraevyTokensExt` instance so the `is! TraevyTokensExt` guard still fires, preserving the test's intent
- **Files modified:** `test/unit/config/theme_extension_test.dart`
- **Commit:** 3eb4a8d

**2. [Rule 1 - Bug] Re-export TraevyTokensExt from theme.dart**
- **Found during:** Task 1 test GREEN phase
- **Issue:** Wave-0 test only imports `package:traevy/config/theme.dart` but `TraevyTokensExt` lives in `theme_extension.dart` — compile error on `TraevyTokensExt` references
- **Fix:** Added `export 'package:traevy/config/theme_extension.dart';` to `theme.dart`
- **Files modified:** `lib/config/theme.dart`
- **Commit:** 3eb4a8d

**3. [Rule 1 - Bug] Unit test binding not initialized for GoogleFonts**
- **Found during:** Task 2 test GREEN phase
- **Issue:** `buildLightTheme()` calls `GoogleFonts.interTextTheme(ThemeData(brightness:b).textTheme)` which requires the Flutter binding. Plain `test()` (non-widget test) does not initialize the binding automatically
- **Fix:** Added `setUpAll(TestWidgetsFlutterBinding.ensureInitialized)` to `theme_test.dart`
- **Files modified:** `test/unit/config/theme_test.dart`
- **Commit:** 02406c4

## Known Stubs

None — all theme data is wired to locked hex values from CONTEXT.md. No placeholder or hardcoded empty values flow to UI rendering.

## Threat Flags

None — this plan only modifies theme configuration files, a test file, and app entrypoints. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `lib/config/theme_extension.dart`: FOUND
- `lib/config/theme.dart` contains `class TraevyTokens`: CONFIRMED
- `lib/config/theme.dart` contains `buildLightTheme`: CONFIRMED
- `lib/config/theme.dart` contains `buildDarkTheme`: CONFIRMED
- `lib/app.dart` contains `buildLightTheme()`: CONFIRMED
- `lib/main.dart` contains `allowRuntimeFetching = false`: CONFIRMED
- Commit 3eb4a8d: FOUND
- Commit 02406c4: FOUND
- `grep -c "Color.lerp(" lib/config/theme_extension.dart` = 14: CONFIRMED
- All 44 unit config tests PASS: CONFIRMED
- All 12 dashboard widget tests PASS: CONFIRMED
