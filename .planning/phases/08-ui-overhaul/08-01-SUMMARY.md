---
phase: 08-ui-overhaul
plan: "01"
subsystem: ui-foundation
tags:
  - fonts
  - google_fonts
  - design-tokens
  - test-scaffolding
  - wave-0-red
dependency_graph:
  requires: []
  provides:
    - google_fonts ^8.1.0 dependency declared
    - Inter TTF assets (400/500/600/700)
    - JetBrains Mono TTF assets (400/500/600)
    - Phase 8 constants (kFontUI, kFontMono, kPlaceholderUserName, kPlaceholderUserInitial, kBrandShortName, kBrandFullName)
    - test/flutter_test_config.dart (google_fonts network fetch disabled globally)
    - Wave-0 RED test scaffolds for Plans 02/03/04
  affects:
    - pubspec.yaml
    - lib/config/constants.dart
    - test/ (all new files)
tech_stack:
  added:
    - google_fonts: ^8.1.0
  patterns:
    - Wave-0 RED test scaffolding (import-fail RED state, Plan turns GREEN)
    - flutter_test_config.dart pre-test hook for font test isolation
key_files:
  created:
    - assets/fonts/Inter-Regular.ttf
    - assets/fonts/Inter-Medium.ttf
    - assets/fonts/Inter-SemiBold.ttf
    - assets/fonts/Inter-Bold.ttf
    - assets/fonts/JetBrainsMono-Regular.ttf
    - assets/fonts/JetBrainsMono-Medium.ttf
    - assets/fonts/JetBrainsMono-SemiBold.ttf
    - test/flutter_test_config.dart
    - test/unit/config/theme_test.dart
    - test/unit/config/theme_extension_test.dart
    - test/widget/shared/widgets/stuck_bar_test.dart
    - test/widget/shared/widgets/trip_row_card_test.dart
    - test/widget/shared/widgets/section_label_test.dart
    - test/widget/shared/widgets/traevy_toggle_test.dart
    - test/widget/shared/widgets/stat_mini_card_test.dart
    - test/widget/features/shell/main_shell_test.dart
  modified:
    - pubspec.yaml (google_fonts dep + assets/fonts/ bundle)
    - lib/config/constants.dart (Phase 8 constants block appended)
decisions:
  - "Downloaded static Inter TTFs from google/fonts GitHub (Inter_18pt-Regular/Medium/SemiBold/Bold) rather than variable-axis to match specific weight names required by google_fonts package"
  - "Downloaded JetBrainsMono static TTFs from google/fonts GitHub matching exact weight names"
  - "test/unit/config/theme_extension_test.dart covers all 14 TraevyTokensExt fields at t=0.5 per Review MEDIUM #3 requirement"
  - "Used ignore_for_file: uri_does_not_exist on all Wave-0 RED tests to silence analyzer on not-yet-existing imports"
metrics:
  duration_minutes: 6
  completed: "2026-05-14"
  tasks_completed: 2
  files_created: 17
  files_modified: 2
---

# Phase 8 Plan 01: Foundation Scaffolding — Font Assets, Constants, Wave-0 RED Tests Summary

**One-liner:** google_fonts ^8.1.0 declared, 7 Inter/JetBrainsMono TTF assets bundled, 6 Phase 8 constants appended to constants.dart, and 9 Wave-0 RED test files staged for Plans 02/03/04 to turn GREEN — including full 14-field lerp coverage on TraevyTokensExt per Review MEDIUM #3.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | pubspec + font assets + constants block | 08c676b | pubspec.yaml, assets/fonts/ (7 TTFs), lib/config/constants.dart |
| 2 | test config + Wave-0 RED test scaffolds | 97f29ce | test/flutter_test_config.dart, 8 RED test files |

## What Was Built

### Task 1: pubspec + Font Assets + Constants Block

**pubspec.yaml changes:**
- Added `google_fonts: ^8.1.0` in alphabetical position between `geolocator: ^14.0.2` and `intl: ^0.20.2`
- Added `- assets/fonts/` under `flutter.assets` alongside existing `assets/icons/logo.jpeg`

**TTF files downloaded** (each ~307 KB, well above 50 KB minimum):
- `assets/fonts/Inter-Regular.ttf` — source: `google/fonts` ofl/inter/static/Inter_18pt-Regular.ttf
- `assets/fonts/Inter-Medium.ttf` — source: `google/fonts` ofl/inter/static/Inter_18pt-Medium.ttf
- `assets/fonts/Inter-SemiBold.ttf` — source: `google/fonts` ofl/inter/static/Inter_18pt-SemiBold.ttf
- `assets/fonts/Inter-Bold.ttf` — source: `google/fonts` ofl/inter/static/Inter_18pt-Bold.ttf
- `assets/fonts/JetBrainsMono-Regular.ttf` — source: `google/fonts` ofl/jetbrainsmono/static/JetBrainsMono-Regular.ttf
- `assets/fonts/JetBrainsMono-Medium.ttf` — source: `google/fonts` ofl/jetbrainsmono/static/JetBrainsMono-Medium.ttf
- `assets/fonts/JetBrainsMono-SemiBold.ttf` — source: `google/fonts` ofl/jetbrainsmono/static/JetBrainsMono-SemiBold.ttf

**constants.dart additions** (Phase 8 block appended, no existing constants changed):
```dart
const String kFontUI = 'Inter';
const String kFontMono = 'JetBrainsMono';
const String kPlaceholderUserName = 'Traveller';
const String kPlaceholderUserInitial = 'T';
const String kBrandShortName = 'tv';
const String kBrandFullName = 'Traevy';
```

### Task 2: Test Config + Wave-0 RED Test Scaffolds

**test/flutter_test_config.dart** — Pre-test hook that runs before every test in the entire `test/` tree. Sets `GoogleFonts.config.allowRuntimeFetching = false` so widget tests never attempt network font downloads on CI.

**Wave-0 RED test files** (all import not-yet-existing production targets; all fail with compile or import errors):

1. `test/unit/config/theme_test.dart` — Asserts `buildLightTheme()` returns ThemeData with primary=`Color(0xFF3A5F8F)`, error=`Color(0xFFC0392B)`, scaffoldBg=`Color(0xFFFAFAF7)`, brightness=light, useMaterial3=true; same shape for `buildDarkTheme()` with dark hex values.

2. `test/unit/config/theme_extension_test.dart` — **Full 14-field lerp coverage (Review MEDIUM #3)**:
   - Group A: `fromTokens` round-trip for light and dark variants (moving, accent, record)
   - Group B: All 14 `TraevyTokensExt` fields tested at t=0.5 against their expected `Color.lerp` midpoints (bgElev, surface2, border, borderStr, textDim, textMuted, moving, movingBg, stuck, stuckBg, accent, accentBg, record, mapBg)
   - Group C: Boundary cases — t=0.0 (all fields match light source), t=1.0 (all fields match dark source), `lerp(null, 0.5)` returns `this` unchanged, `lerp(non-TraevyTokensExt, 0.5)` returns `this` unchanged

3. `test/widget/shared/widgets/stuck_bar_test.dart` — StuckBar renders without crash at (0,0); produces Row with 2 Expanded children proportional to inputs.

4. `test/widget/shared/widgets/trip_row_card_test.dart` — TripRowCard renders for to_office (accentBg avatar) and to_home (movingBg avatar); duration text uses kFontMono; tap callback fires.

5. `test/widget/shared/widgets/section_label_test.dart` — SectionLabel renders UPPERCASE text with letterSpacing >= 1.0 and textMuted=`Color(0xFF9A9AAA)`.

6. `test/widget/shared/widgets/traevy_toggle_test.dart` — TraevyToggle off-state knob aligned left; on-state knob aligned right; tap invokes onChanged with inverted value.

7. `test/widget/shared/widgets/stat_mini_card_test.dart` — StatMiniCard renders label (Inter)/value (JetBrainsMono)/optional unit; tone=stuck tints value with `Color(0xFFC4820A)`.

8. `test/widget/features/shell/main_shell_test.dart` — MainShell shows NavigationBar with exactly 4 NavigationDestinations labeled Today/Trips/Stats/Settings; tapping Trips switches IndexedStack to HistoryScreen.

## Verification Results

| Check | Result |
|-------|--------|
| `flutter pub get` | PASS — Got dependencies! |
| `ls assets/fonts/*.ttf \| wc -l` | 7 |
| All 7 TTF files >= 50 KB | PASS (each ~307 KB) |
| `grep "google_fonts: ^8.1.0" pubspec.yaml` | PASS |
| `grep "- assets/fonts/" pubspec.yaml` | PASS |
| `grep "kFontUI = 'Inter'" constants.dart` | PASS |
| `grep "kFontMono = 'JetBrainsMono'" constants.dart` | PASS |
| `flutter analyze lib/config/constants.dart` | No issues found |
| `test/unit/config/theme_test.dart` RED state | PASS (compile fails: buildLightTheme not found) |
| `test/unit/config/theme_extension_test.dart` RED state | PASS (compile fails: TraevyTokensExt not found) |
| `Color.lerp` assertions count >= 14 | 14 (exactly all 14 fields) |
| All 14 field names present in theme_extension_test | PASS |
| Boundary cases present (t=0.0, t=1.0, null, wrong-type) | PASS |
| `dart format --set-exit-if-changed` all 9 new test files | PASS (0 changed) |

## Deviations from Plan

None — plan executed exactly as written.

The Inter static TTFs were sourced from `google/fonts` GitHub as `Inter_18pt-*` variants (18pt suffix is the standard static export name used in the Google Fonts repository for the Inter family). This matches the naming convention used by the `google_fonts` package when resolving font assets locally.

## Known Stubs

None — this plan creates only asset files and test scaffolds. No production widget code with stub data flows.

## Threat Flags

None — this plan only adds font assets, appends string constants, and creates test files. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `assets/fonts/Inter-Regular.ttf`: FOUND
- `assets/fonts/Inter-Medium.ttf`: FOUND
- `assets/fonts/Inter-SemiBold.ttf`: FOUND
- `assets/fonts/Inter-Bold.ttf`: FOUND
- `assets/fonts/JetBrainsMono-Regular.ttf`: FOUND
- `assets/fonts/JetBrainsMono-Medium.ttf`: FOUND
- `assets/fonts/JetBrainsMono-SemiBold.ttf`: FOUND
- `test/flutter_test_config.dart`: FOUND
- `test/unit/config/theme_test.dart`: FOUND
- `test/unit/config/theme_extension_test.dart`: FOUND
- `test/widget/shared/widgets/stuck_bar_test.dart`: FOUND
- `test/widget/shared/widgets/trip_row_card_test.dart`: FOUND
- `test/widget/shared/widgets/section_label_test.dart`: FOUND
- `test/widget/shared/widgets/traevy_toggle_test.dart`: FOUND
- `test/widget/shared/widgets/stat_mini_card_test.dart`: FOUND
- `test/widget/features/shell/main_shell_test.dart`: FOUND
- Commit 08c676b: FOUND
- Commit 97f29ce: FOUND
