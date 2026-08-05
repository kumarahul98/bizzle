---
phase: quick-260805-wkk
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/dashboard/widgets/hero_record_card.dart
  - lib/config/constants.dart
  - test/widget/features/dashboard/hero_record_card_auto_label_test.dart
autonomous: true
requirements: [SMOKE-01]

must_haves:
  truths:
    - "The idle hero card's auto-label reflects the actual time of day and the user's cutoff prefs, not a fixed string"
    - "No caller-supplied auto-label parameters remain on HeroRecordCard — the widget resolves its own label"
    - "The label is recomputed on rebuild, so a session left open across the cutoff does not show a stale direction"
    - "No user-facing label literal remains inline in the widget"
  artifacts:
    - path: "lib/features/dashboard/widgets/hero_record_card.dart"
      provides: "Idle auto-label resolved from prefs + DirectionLabelService"
      contains: "DirectionLabelService"
    - path: "test/widget/features/dashboard/hero_record_card_auto_label_test.dart"
      provides: "Clock-independent regression guard, verified to fail pre-fix"
      contains: "eveningCutoffHour"
---

# Quick Task 260805-wkk: Fix dashboard idle auto-label direction

## Problem

`hero_record_card.dart` resolved its idle auto-label as
`final dir = direction ?? 'To office';`, and the sole call site
(`dashboard_screen.dart:73`) passed only `onStart`. `autoLabelDirection` and
`autoLabelTime` were therefore permanently `null`, so the card rendered a
hardcoded **"To office" at every hour of the day** — observed on device at
22:58, where the correct label is "To home".

`DirectionLabelService` is correct and separately unit-tested; it was simply
never wired to this widget. The existing widget test constructed the card the
same way the app did, so the whole suite stayed green over the defect.

Only the pre-start preview was wrong — the live recording header, the
foreground notification, and the persisted `trips.direction` all resolve
correctly through `TrackingNotifier.resolvedDirection`.

The inline `'To office'` and `'Auto-labelled '` literals also violated
CLAUDE.md's rule that user-facing strings live in `constants.dart`.

## Approach

Resolve the label inside `HeroRecordCard.build`, which is already a
`ConsumerWidget`:

1. Watch `userPreferenceProvider` for the morning/evening cutoffs, falling
   back to `kDefaultDirectionCutoffHour` until prefs load — the same fallback
   `tracking_providers.dart:497-500` uses.
2. Feed `DateTime.now()` (already local, which is what the service requires)
   to `const DirectionLabelService().label(...)`.
3. Map the resulting direction constant to a display label with
   `kDirectionToHomeLabel` / `kDirectionToOfficeLabel`, reusing the exact
   expression already at `_HeroActive._directionLabel`.
4. Delete `autoLabelDirection` / `autoLabelTime` from `HeroRecordCard`, make
   `_HeroIdle.autoLabelDirection` a required non-nullable display string, and
   delete `_AutoLabelRow.time` plus the `?? 'To office'` fallback.
5. Extract `'Auto-labelled '` to `kAutoLabelledPrefix` in `constants.dart`.

### Deviation from the approved plan

The approved plan called for an override-friendly `Provider`. Computing in
`build` instead, because a `Provider` **caches** its value until a dependency
changes: with prefs untouched, a label computed at 09:00 would still read
"To office" at 23:00 for a session left open — reintroducing the very
staleness this fix removes. `todaysTripSummariesProvider` reads `DateTime.now()`
the same way, so this matches the local pattern.

Testability is preserved without an injected clock by choosing cutoffs that
force one branch regardless of run time:

* `eveningCutoffHour = 0` → `hour >= 0` always true → `to_home`
* `morningCutoffHour = 24` → `hour < 24` always true → `to_office`

`autoLabelTime` is deleted rather than populated: nothing computed it, and the
idle card does not rebuild every minute, so a rendered clock would silently go
stale — worse than showing nothing.

## Verification

- `flutter analyze` — no new warnings or errors.
- `flutter test test/widget/` — full widget suite green.
- **Adversarial check:** the label mapping was temporarily replaced with a
  hardcoded `kDirectionToOfficeLabel` and the new test suite was re-run; the
  "evening cutoff of 0" case failed as required, proving the guard is real and
  not vacuously passing.
- On device: the idle card must read "Auto-labelled To home" after the cutoff
  hour and "Auto-labelled To office" before it.
