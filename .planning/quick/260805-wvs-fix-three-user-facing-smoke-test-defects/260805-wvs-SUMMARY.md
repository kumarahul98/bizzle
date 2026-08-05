---
quick_id: 260805-wvs
title: Fix three user-facing defects found by the pre-release device smoke test
type: quick
status: complete
requirements: [SMOKE-02, SMOKE-03, SMOKE-04]
key-files:
  created: []
  modified:
    - lib/config/constants.dart
    - lib/features/trips/services/trip_actions.dart
    - lib/features/trips/providers/trip_management_providers.dart
    - lib/features/trips/screens/history_screen.dart
    - test/unit/config/constants_test.dart
    - test/unit/features/trips/manual_entry_notifier_test.dart
    - test/widget/features/trips/history_screen_test.dart
decisions:
  - "Delete-trip copy split into prefix/suffix around kTrashRetentionDays, mirroring kTrashEmptyBodyPrefix/Suffix, so the retention window cannot disagree between the delete dialog and the Trash screen"
  - "kTrashPermanentDeleteDialogBody deliberately untouched — the blunt wording is correct there; a test now pins the two apart so they cannot converge again"
  - "Manual entries always record direction_source 'manual' rather than only when the user overrides the time-derived default: the trip is user-authored end to end, it is a one-line change, and it shields the direction from restore enrichment"
  - "_IconCircleButton.semanticLabel is REQUIRED, not optional — an optional label is what allowed the bug in the first place (same failure mode as HeroRecordCard's optional autoLabelDirection)"
  - "View-toggle label names the destination view and flips with _view; a fixed label would be wrong half the time"
metrics:
  duration: "~35 min"
  completed: 2026-08-05
---

# Quick Task 260805-wvs: Three user-facing smoke-test defects

Three independent defects surfaced by the pre-release on-device smoke test,
each committed separately. All were **wiring or copy** problems, not logic
problems, which is why 1015 passing tests did not catch any of them.

## 1. Delete dialog described the wrong operation (`7b9fec5`)

`kTripDeleteDialogBody` read *"This trip will be permanently removed."*
Per-trip delete is SOFT (Phase 35, D-05) — verified on device that the row
survives with `deleted_at`, a tombstone syncs, and Trash restore clears the
flag and re-syncs a compensating create.

Worse, the sentence was near-identical to `kTrashPermanentDeleteDialogBody`,
which describes the genuinely irreversible Trash action, so two very different
operations shared one piece of copy. A user reading "permanently removed" has
no reason to look in Trash.

Now split into `kTripDeleteDialogBodyPrefix` / `kTripDeleteDialogBodySuffix`
and assembled around `kTrashRetentionDays` at the call site. Four tests pin the
new copy: no "permanent" claim, names the Trash destination, states the
retention window, and stays distinct from the permanent-delete copy.

Deletion wording matters more than usual here — it is what Play's Data Safety
review reads, and it must agree with the published privacy policy.

## 2. Manual entries recorded the wrong direction provenance (`9bc0050`)

`insertManualTrip` omitted `directionSource`, so every manual entry took the
column default `'time'` despite the direction being chosen by the user.
Verified on device: an explicit "To home" persisted as `to_home(time)`.

**Not cosmetic.** `restore_controller.dart` enriches when local
`directionSource == 'time'` and the cloud copy's is not, letting the cloud
direction overwrite the local one — so a mislabelled manual entry was eligible
to have the user's own pick overwritten, exactly what T-21-03-01 forbids.

`editTrip` already set `kDirectionSourceManual`, so the manual-entry path was
the lone inconsistency. `geofenceBackfillCandidates()` was never at risk: it
independently excludes manual entries via `isManualEntry = false` and the
non-empty polyline requirement.

Intended side effect: manual entries now satisfy
`tripIdsWithNonDefaultMetadata()` and are enqueued once for an idempotent
metadata update sync.

## 3. Toolbar icon buttons were invisible to screen readers (`6ad58f7`)

`_IconCircleButton` had no semantics at all, so the view toggle and add-a-trip
controls announced nothing — confirmed on device, where `uiautomator` reported
empty `content-desc` for both nodes. Added a **required** `semanticLabel`, a
`Semantics(button: true)` wrapper, and `ExcludeSemantics` around the icon.

## Verification

- `flutter analyze` — no errors or warnings on any touched file.
- `flutter test test/widget/` — **224 passed** (was 222; +2 new a11y tests).
- `flutter test test/unit/features/trips/ test/unit/sync/ test/sync/ test/unit/database/` — **328 passed**.
- **Adversarial check on defect 2:** removing the new `directionSource` line
  makes the regression test fail on the default `'time'`; restoring it passes.
  Defect 3's guard is definitionally tied to the new code (the labels did not
  previously exist), so no probe applies.

## Not verified yet

All three still need the device pass: the delete dialog wording, a manual entry
landing with `direction_source = manual`, and `content-desc` present on both
toolbar nodes. Batched with the other outstanding device checks.
