---
phase: 17-tracking-ui-fixes-quick-label
plan: 01
subsystem: ui
tags: [flutter, layout, fittedbox, fontfeatures, tabular-figures, timer, ux-06]

# Dependency graph
requires:
  - phase: 08-ui-overhaul
    provides: ElapsedDisplay widget, TraevyFonts.mono factory, Traevy theme
provides:
  - ElapsedDisplay that fits the 76sp HH:MM:SS timer to width via FittedBox(scaleDown) so it never wraps or clips
  - TraevyFonts.mono fontFeatures param for tabular figures on numeric mono displays
  - UX-06 widget regression test (narrow-width + textScaler 2.0 + format guard)
affects: [tracking, dashboard, hero-record-card, accessibility]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Fit-to-width numeric display: SizedBox(width: infinity) + FittedBox(BoxFit.scaleDown) + maxLines:1/softWrap:false guarantees a fixed-format string shrinks rather than wraps/clips"
    - "Tabular figures via FontFeature.tabularFigures() on mono numeric styles to keep digit advance width constant as values tick"

key-files:
  created:
    - test/widget/features/tracking/elapsed_display_test.dart
  modified:
    - lib/config/theme.dart
    - lib/features/tracking/widgets/elapsed_display.dart

key-decisions:
  - "FontFeature resolved via the existing package:flutter/material.dart import (re-exports dart:ui) — no extra import needed."
  - "fontFeatures param is nullable with a null default, so every existing mono(...) call site is untouched."
  - "FittedBox alignment left at its default (Alignment.center) to satisfy avoid_redundant_argument_values."

patterns-established:
  - "Width-bounded FittedBox(scaleDown) for fixed-width numeric displays at large font sizes"

requirements-completed: [UX-06]

# Metrics
duration: 9min
completed: 2026-06-06
---

# Phase 17 Plan 01: Tracking UI Fixes — UX-06 Timer Overflow Summary

**The active-recording elapsed timer now fits to width via FittedBox(scaleDown) inside a full-width box with maxLines:1/softWrap:false and tabular figures, so the 76sp HH:MM:SS timer never wraps or clips at 2-digit hours or large system text-scales.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-06-06
- **Completed:** 2026-06-06
- **Tasks:** 2
- **Files modified:** 3 (2 modified, 1 created)

## Accomplishments
- `ElapsedDisplay` wraps the 76sp mono timer in `SizedBox(width: double.infinity)` + `FittedBox(fit: BoxFit.scaleDown)` with `maxLines: 1` / `softWrap: false`, mathematically guaranteeing the glyphs shrink to fit instead of wrapping or clipping (D-01/D-02). This flows to the live surface (`HeroRecordCard` → `_HeroActive`).
- `TraevyFonts.mono` gained an optional `List<FontFeature>? fontFeatures` param (nullable default), and the timer passes `const [FontFeature.tabularFigures()]` to keep per-digit advance width constant as the timer ticks (D-03).
- `_formatElapsed` left byte-for-byte unchanged (D-01 regression guard).
- Added `test/widget/features/tracking/elapsed_display_test.dart` with three automated tests: full `99:59:59` at a 320dp width, `00:00:35` at `textScaler 2.0`, and a `01:01:01` format guard — each asserting both the exact string and `tester.takeException()` is null.

## Task Commits

1. **Task 1 + Task 2: UX-06 timer fit-to-width + regression test** — `46b3349` (fix; committed atomically per execution protocol)

**Plan metadata:** see docs commit for this SUMMARY.

## Files Created/Modified
- `lib/config/theme.dart` — `TraevyFonts.mono` gains an optional `fontFeatures` param forwarded to the returned `TextStyle`; dartdoc updated.
- `lib/features/tracking/widgets/elapsed_display.dart` — timer wrapped in width-bounded `FittedBox(scaleDown)` with `maxLines:1`/`softWrap:false` and tabular figures; `_formatElapsed` and `SectionLabel` untouched.
- `test/widget/features/tracking/elapsed_display_test.dart` — UX-06 overflow regression tests (narrow width, textScaler 2.0, format guard).

## Decisions Made
- `FontFeature` is already available through the existing `package:flutter/material.dart` import (re-exports `dart:ui`); no `import 'dart:ui'` was required and the analyzer is clean.
- Removed the explicit `alignment: Alignment.center` on `FittedBox` (matches the default) to satisfy `avoid_redundant_argument_values`.
- Wrote the test's `TextScaler.linear(2)` as an int literal to satisfy `prefer_int_literals`.

## Deviations from Plan
None — plan executed exactly as written. Tasks 1 and 2 were implemented together and committed in a single atomic `[tracking]` commit per the execution protocol for this plan.

## Issues Encountered
None. `flutter analyze` initially flagged two info-level lints (`avoid_redundant_argument_values` on the FittedBox alignment, `prefer_int_literals` on `2.0`); both were resolved before commit, leaving analyze clean.

## Test Results
- `flutter test test/widget/features/tracking/elapsed_display_test.dart` — 3/3 passed.
- `flutter analyze` (theme.dart, elapsed_display.dart, test file) — No issues found.
- Full `flutter test` — 400 passed, 10 skipped, 0 failed. No regression from the `mono(...)` signature change (new param optional/defaulted).

## User Setup Required
None — pure presentation-layer change, no external service configuration.

## Next Phase Readiness
- UX-06 / ROADMAP SC#1 satisfied: the elapsed timer renders fully (no wrap, no clip) at short durations, 2-digit-hour durations, and 2.0 system text-scale, proven by automated tests.
- Ready for the remaining Phase 17 tracking-UI / quick-label work.

---
*Phase: 17-tracking-ui-fixes-quick-label*
*Completed: 2026-06-06*

## Self-Check: PASSED

All 3 modified/created files exist on disk; implementation commit `46b3349` verified in git log; FittedBox + tabularFigures present in elapsed_display.dart; fontFeatures present in theme.dart.
