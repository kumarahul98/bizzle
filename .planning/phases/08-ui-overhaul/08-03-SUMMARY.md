---
phase: 08-ui-overhaul
plan: "03"
subsystem: ui-shared-primitives
tags:
  - shared-widgets
  - design-tokens
  - wave-3-green
  - primitives
dependency_graph:
  requires:
    - TraevyTokensExt ThemeExtension (Plan 02)
    - TraevyFonts.ui / TraevyFonts.mono helpers (Plan 02)
    - kFontUI / kFontMono / kBrandShortName / kDirectionToOffice / kDirectionToHome (Plan 01)
    - Wave-0 RED widget test files for 5 primitives (Plan 01)
  provides:
    - StuckBar widget (movingMinutes, stuckMinutes, height)
    - SectionLabel widget (text, fontSize)
    - TraevyLogoMark widget (size)
    - TripRowCard widget (direction, startTime, endTime, durationSeconds, distanceMeters, stuckSeconds, showDivider, onTap)
    - TripRowInfo helper widget (displayName, durationLabel, timeRange, stuckMins)
    - TraevyToggle widget (value, onChanged)
    - StatMiniCard widget + StatMiniCardTone enum (label, value, unit, tone)
    - kTraevyKnobShadow constant in theme.dart
    - Inter + JetBrainsMono declared under flutter.fonts in pubspec.yaml
  affects:
    - lib/shared/widgets/ (7 new files)
    - lib/config/theme.dart (TraevyFonts implementation + kTraevyKnobShadow)
    - lib/config/constants.dart (trailing newline fix)
    - pubspec.yaml (fonts section added)
tech_stack:
  added: []
  patterns:
    - StatelessWidget with TraevyTokensExt via Theme.of(context).extension<TraevyTokensExt>()!
    - TextStyle(fontFamily: kFontUI/kFontMono) for testable font family checks
    - Private helper widget extracted to separate file to satisfy 100-line limit
    - Token-aware colors only — no Color(0x...) hex literals in widget files
    - GestureDetector + AnimatedContainer toggle pattern (180ms, no setState)
key_files:
  created:
    - lib/shared/widgets/stuck_bar.dart
    - lib/shared/widgets/section_label.dart
    - lib/shared/widgets/traevy_logo_mark.dart
    - lib/shared/widgets/trip_row_card.dart
    - lib/shared/widgets/trip_row_info.dart
    - lib/shared/widgets/traevy_toggle.dart
    - lib/shared/widgets/stat_mini_card.dart
  modified:
    - lib/config/theme.dart (TraevyFonts + kTraevyKnobShadow)
    - lib/config/constants.dart (trailing newline fix)
    - pubspec.yaml (flutter.fonts section)
decisions:
  - "TraevyFonts.ui/mono changed from GoogleFonts.*() to TextStyle(fontFamily: kFontUI/kFontMono) — google_fonts appends _600/_regular weight suffixes to fontFamily breaking fontFamily == kFontMono test assertions"
  - "pubspec.yaml flutter.fonts section added for Inter and JetBrainsMono so TextStyle(fontFamily:) resolves bundled TTFs without google_fonts intermediary"
  - "TripRowInfo extracted to trip_row_info.dart to keep trip_row_card.dart under 100 lines per CLAUDE.md constraint"
  - "kTraevyKnobShadow constant placed in theme.dart (where all Color constants live) to eliminate Color(0x...) from widget directory"
  - "TripRowCard uses durationSeconds/stuckSeconds (seconds) not durationMinutes/stuckMinutes — matched to Plan 01 test signatures which use durationSeconds"
  - "SectionLabel uses named text: parameter (not positional) to match Plan 01 test call SectionLabel(text: 'today')"
metrics:
  duration_minutes: 45
  completed: "2026-05-14"
  tasks_completed: 2
  files_created: 7
  files_modified: 4
---

# Phase 8 Plan 03: Shared UI Primitives Summary

**One-liner:** Six token-aware StatelessWidget primitives (StuckBar, SectionLabel, TraevyLogoMark, TripRowCard, TraevyToggle, StatMiniCard) implemented under `lib/shared/widgets/` — all five Plan-01 RED tests turn GREEN (19/19 widget + 44/44 unit tests pass, analyzer clean).

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | StuckBar + SectionLabel + TraevyLogoMark | 7a9f9f7 | stuck_bar.dart, section_label.dart, traevy_logo_mark.dart |
| 2 | TripRowCard + TraevyToggle + StatMiniCard | d12cf3c | trip_row_card.dart, traevy_toggle.dart, stat_mini_card.dart, trip_row_info.dart, theme.dart, pubspec.yaml |

## What Was Built

### Widget Line Counts

| File | Lines | UI-SPEC Section |
|------|-------|-----------------|
| `stuck_bar.dart` | 68 | §10 StuckBar contract |
| `section_label.dart` | 40 | §1 Section header style |
| `traevy_logo_mark.dart` | 49 | §9 Onboarding 'tv' logo |
| `trip_row_card.dart` | 96 | §5 Trip History |
| `trip_row_info.dart` | 74 | §5 Trip History (helper) |
| `traevy_toggle.dart` | 72 | §8 Settings Toggle |
| `stat_mini_card.dart` | 99 | §4 Active Recording |

All files are under 100 lines per CLAUDE.md constraint.

### StuckBar

Renders a proportional horizontal bar showing moving (green) vs stuck (amber) time. Uses `ClipRRect(BorderRadius.circular(height/2))` containing a `Row` with two `Expanded` children sized by `movingMinutes` and `stuckMinutes` flex values. Zero-state renders a full-width `surface2` track. All colors from `TraevyTokensExt`.

### SectionLabel

Single `Text` widget rendering `text.toUpperCase()` in `TraevyFonts.ui(size: fontSize, weight: w600, color: tokens.textMuted, letterSpacing: 1)`. No internal padding — callers wrap as needed.

### TraevyLogoMark

56dp rounded square (`BorderRadius.circular(16)`) with `colorScheme.onSurface` fill and `scaffoldBackgroundColor` text — auto-inverts in dark mode. Renders `kBrandShortName` ("tv") in `TraevyFonts.mono(size: size*0.5, weight: w700)`.

### TripRowCard + TripRowInfo

`TripRowCard` renders `Material(color: transparent) + InkWell` wrapping a `Row` with:
- `CircleAvatar(radius: 18)` — `accentBg` + forward arrow (to_office) or `movingBg` + back arrow (to_home)
- `TripRowInfo` — name+duration row above, time-range+stuck row below

`TripRowInfo` extracted to `trip_row_info.dart` to keep `trip_row_card.dart` under 100 lines.

Formatter helpers (private static methods):
- `_dur(int seconds)` — `"47m"` or `"1h 12m"` 
- `_dist(double meters)` — `"12.5 km"` or `"450 m"`
- `_name(String direction)` — `"To office"` or `"To home"`

### TraevyToggle

`GestureDetector` wrapping `AnimatedContainer(duration: 180ms)` pill with `BorderRadius.circular(11)`. Knob is an 18dp white `BoxShape.circle` container with `kTraevyKnobShadow` BoxShadow. `Align` switches between `Alignment.centerLeft` (off) and `Alignment.centerRight` (on).

### StatMiniCard

Container with `bgElev` background, `BorderRadius.circular(16)`, `Border.all(color: tokens.border)`, 14/12dp padding. Inside: `Text(label)` in Inter 10.5sp w600 textMuted, then `Row` with `Text(value)` in Mono 22sp w600 tone-colored + optional `Text(unit)` in Mono 11sp w500 textDim.

`StatMiniCardTone` enum: `neutral` (onSurface), `moving` (tokens.moving), `stuck` (tokens.stuck).

## Formatter Helpers Introduced

| Helper | Location | Signature | Output example |
|--------|----------|-----------|----------------|
| `_dur` | TripRowCard | `(int seconds) → String` | `"1h 12m"` / `"47m"` |
| `_dist` | TripRowCard | `(double meters) → String` | `"12.5 km"` / `"450 m"` |
| `_name` | TripRowCard | `(String direction) → String` | `"To office"` / `"To home"` |

All are private static methods — not exported. Callers outside TripRowCard should use their own formatting or a shared utility.

## Verification Results

| Check | Result |
|-------|--------|
| `flutter analyze lib/shared/widgets/` | No issues found |
| `flutter analyze lib/` (full) | No issues found |
| `flutter test test/widget/shared/widgets/` | 19/19 PASS |
| `flutter test test/unit/config/` | 44/44 PASS |
| `grep -rE "Color\(0x" lib/shared/widgets/` | No matches |
| `wc -l lib/shared/widgets/*.dart` all < 100 | PASS (max 99) |
| `flutter test test/widget/features/dashboard/` | 12/12 PASS (regression clean) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TraevyFonts.ui/mono font family suffix mismatch**
- **Found during:** Task 2, GREEN phase — `stat_mini_card` tests failing
- **Issue:** `GoogleFonts.inter(fontWeight: w600)` produces `fontFamily: 'Inter_600'`; `GoogleFonts.inter()` produces `fontFamily: 'Inter_regular'`. Neither matches `kFontUI = 'Inter'` exactly. Plan 01 Wave-0 tests assert `fontFamily == kFontMono` / `fontFamily == kFontUI` using `==` not `startsWith`.
- **Fix:** Changed `TraevyFonts.ui()` and `TraevyFonts.mono()` in `lib/config/theme.dart` to use `TextStyle(fontFamily: kFontUI/kFontMono, ...)` directly. The `_build()` function still uses `GoogleFonts.interTextTheme()` for the Material TextTheme base — that import is retained.
- **Files modified:** `lib/config/theme.dart`
- **Commit:** d12cf3c

**2. [Rule 2 - Missing] pubspec.yaml fonts section absent**
- **Found during:** Task 2, after TraevyFonts fix
- **Issue:** `TextStyle(fontFamily: 'Inter')` only resolves from bundled assets if the font is declared under `flutter.fonts:` in pubspec.yaml. Without this, the font falls back to system default.
- **Fix:** Added `fonts:` section with Inter (400/500/600/700) and JetBrainsMono (400/500/600) pointing to the TTFs already in `assets/fonts/`.
- **Files modified:** `pubspec.yaml`
- **Commit:** d12cf3c

**3. [Rule 2 - Missing] TripRowCard line count over 100**
- **Found during:** Task 2, acceptance criteria check
- **Issue:** The Flutter widget tree for TripRowCard is inherently verbose. With 8 fields and two text rows, the file reached 138+ lines, violating CLAUDE.md's 100-line rule.
- **Fix:** Extracted `TripRowInfo` (the inner info column) to `lib/shared/widgets/trip_row_info.dart`. `trip_row_card.dart` reduced to 96 lines.
- **Files created:** `lib/shared/widgets/trip_row_info.dart`
- **Commit:** d12cf3c

**4. [Rule 2 - Missing] Inline Color(0x33000000) in TraevyToggle**
- **Found during:** Task 2, acceptance criteria check `grep -rE "Color\(0x" lib/shared/widgets/`
- **Issue:** The toggle knob shadow `Color(0x33000000)` is a spec-mandated value (UI-SPEC §8) but cannot live as an inline hex literal in widget code.
- **Fix:** Added `const Color kTraevyKnobShadow = Color(0x33000000)` to `lib/config/theme.dart` (where all Color constants are defined) and referenced it from `traevy_toggle.dart`.
- **Files modified:** `lib/config/theme.dart`, `lib/shared/widgets/traevy_toggle.dart`
- **Commit:** d12cf3c

**5. [Rule 1 - Bug] SectionLabel text parameter must be named, not positional**
- **Found during:** Analysis of Plan 01 test signatures before implementing
- **Issue:** Plan interface spec shows `SectionLabel(this.text, ...)` (positional) but Plan 01 tests call `SectionLabel(text: 'today')` (named). Named call on positional param is a compile error.
- **Fix:** Implemented `SectionLabel({required this.text, ...})` with named parameter.
- **Files modified:** `lib/shared/widgets/section_label.dart`
- **Commit:** 7a9f9f7

**6. [Rule 1 - Bug] TripRowCard uses durationSeconds/stuckSeconds not durationMinutes/stuckMinutes**
- **Found during:** Analysis of Plan 01 test signatures before implementing
- **Issue:** Plan interface spec names fields `durationMinutes` and `stuckMinutes` (int minutes) but Plan 01 tests pass `durationSeconds: 1800` and `stuckSeconds: 300` (int seconds). Using minutes would produce wrong display values.
- **Fix:** Implemented `TripRowCard` with `durationSeconds` and `stuckSeconds` matching the test signatures. Internal helpers `_dur()` and `stuckMins` convert to minutes for display.
- **Files modified:** `lib/shared/widgets/trip_row_card.dart`
- **Commit:** d12cf3c

## Known Stubs

None — all six widgets are fully wired to live token colors from `TraevyTokensExt`. No placeholder data flows to UI rendering.

## Threat Flags

None — this plan creates purely presentational StatelessWidgets with no network access, auth paths, file I/O, or schema changes. All data is passed in via constructor parameters.

## Self-Check: PASSED

- `lib/shared/widgets/stuck_bar.dart`: FOUND
- `lib/shared/widgets/section_label.dart`: FOUND
- `lib/shared/widgets/traevy_logo_mark.dart`: FOUND
- `lib/shared/widgets/trip_row_card.dart`: FOUND
- `lib/shared/widgets/trip_row_info.dart`: FOUND
- `lib/shared/widgets/traevy_toggle.dart`: FOUND
- `lib/shared/widgets/stat_mini_card.dart`: FOUND
- Commit 7a9f9f7: FOUND
- Commit d12cf3c: FOUND
- `flutter test test/widget/shared/widgets/` 19/19 PASS: CONFIRMED
- `flutter test test/unit/config/` 44/44 PASS: CONFIRMED
- `flutter analyze lib/` No issues: CONFIRMED
- All widget files < 100 lines: CONFIRMED (max 99)
- No Color(0x...) in lib/shared/widgets/: CONFIRMED
