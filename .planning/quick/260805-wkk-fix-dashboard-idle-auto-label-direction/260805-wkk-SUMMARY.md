---
quick_id: 260805-wkk
title: Wire up the dashboard idle auto-label so it reflects the real time of day
type: quick
status: complete
requirements: [SMOKE-01]
key-files:
  created:
    - test/widget/features/dashboard/hero_record_card_auto_label_test.dart
  modified:
    - lib/features/dashboard/widgets/hero_record_card.dart
    - lib/config/constants.dart
decisions:
  - "Resolved the label in build() rather than in a Provider — a Provider caches until a dependency changes, so an open session would show a label computed hours earlier"
  - "Deleted autoLabelTime rather than populating it: nothing computed it, and the idle card does not rebuild per minute, so a rendered clock would go stale"
  - "Test made clock-independent via extreme cutoffs (evening=0 always to_home, morning=24 always to_office) instead of injecting a clock abstraction for a single use case"
  - "Extracted 'Auto-labelled ' to kAutoLabelledPrefix; kept it a separate span because the prefix and direction are styled differently"
metrics:
  duration: "~20 min"
  completed: 2026-08-05
---

# Quick Task 260805-wkk: Fix dashboard idle auto-label direction

One-liner: the dashboard's idle hero card rendered a hardcoded "To office" at
every hour because its auto-label parameters were optional and no call site
ever passed them; it now resolves the label from the user's cutoff prefs and
the current time, so it reads "To home" in the evening.

## What changed

**`lib/features/dashboard/widgets/hero_record_card.dart`**
- Added `_autoLabelDirection(UserPreferencesValue?)`, which feeds the user's
  morning/evening cutoffs (defaulting to `kDefaultDirectionCutoffHour` until
  prefs load) and local `DateTime.now()` into `DirectionLabelService`, then
  maps the result through `kDirectionToHomeLabel` / `kDirectionToOfficeLabel`.
- `build` now watches `userPreferenceProvider` and passes the resolved label
  into `_HeroIdle`.
- **Deleted** the dead `autoLabelDirection` and `autoLabelTime` parameters from
  `HeroRecordCard`, the `time` field on `_AutoLabelRow`, and the
  `?? 'To office'` fallback. `_HeroIdle.autoLabelDirection` is now a required
  non-nullable display string.

**`lib/config/constants.dart`**
- Added `kAutoLabelledPrefix` (`'Auto-labelled '`), removing the last inline
  user-facing literal from the widget.

**`test/widget/features/dashboard/hero_record_card_auto_label_test.dart`** (new)
- Three clock-independent cases covering the to_home branch, the to_office
  branch, and the surviving explanatory prefix.

## Verification

- `flutter analyze lib/features/dashboard/ test/widget/features/dashboard/` —
  no errors or warnings (3 pre-existing infos, none from this change).
- `flutter test test/widget/` — **222 passed**.
- **Adversarial check performed.** The label mapping was temporarily replaced
  with a hardcoded `kDirectionToOfficeLabel`; the "evening cutoff of 0" case
  failed and the other two passed, confirming the new test genuinely detects
  the original defect rather than passing vacuously. The probe was then
  reverted and the suite re-run green.

## Scope notes

Only the pre-start preview was ever wrong. The live recording header, the
foreground notification, and the persisted `trips.direction` all resolved
correctly through `TrackingNotifier.resolvedDirection` and were untouched.

## Follow-up

Device confirmation is still outstanding: the idle card should read
"Auto-labelled To home" after the cutoff hour and "Auto-labelled To office"
before it. Folded into the pending device pass alongside the other smoke-test
fixes.
