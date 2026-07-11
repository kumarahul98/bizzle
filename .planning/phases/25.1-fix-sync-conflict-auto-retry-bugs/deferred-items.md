# Deferred Items — Phase 25.1

Out-of-scope discoveries logged during execution. Not fixed per scope boundary rules.

## 2026-07-11 — Plan 02 execution

- **Pre-existing analyzer baseline is non-zero:** `flutter analyze` reports 270 info-level
  issues project-wide (very_good_analysis strictness: `lines_longer_than_80_chars`,
  `directives_ordering`, `avoid_print`, `deprecated_member_use` for RadioListTile
  groupValue/onChanged, etc.). Verified identical count (270) before and after plan 02's
  changes — zero new issues introduced. Includes pre-existing lints in
  `lib/features/settings/widgets/conflict_resolution_sheet.dart` and its widget test
  (e.g. `print` calls in test 1, deprecated Radio APIs). Cleaning these is unrelated
  refactoring work, out of scope for this bug-fix phase.
