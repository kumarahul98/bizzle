---
phase: 3
slug: trip-management
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (dart:test) |
| **Config file** | `flutter_test` dependency already in pubspec.yaml |
| **Quick run command** | `flutter test test/unit/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| 03-01-01 | 01 | 0 | TRACK-03 | N/A | unit | `flutter test test/unit/direction_label_service_test.dart` | ⬜ pending |
| 03-01-02 | 01 | 0 | TRACK-06 | N/A | unit | `flutter test test/unit/trips_dao_test.dart` | ⬜ pending |
| 03-01-03 | 01 | 0 | TRACK-07 | N/A | unit | `flutter test test/unit/trips_dao_test.dart` | ⬜ pending |
| 03-01-04 | 01 | 1 | TRACK-03 | N/A | unit | `flutter test test/unit/direction_label_service_test.dart` | ⬜ pending |
| 03-01-05 | 01 | 1 | TRACK-06 | N/A | unit | `flutter test test/unit/trip_management_notifier_test.dart` | ⬜ pending |
| 03-01-06 | 01 | 1 | TRACK-07 | N/A | unit | `flutter test test/unit/trip_management_notifier_test.dart` | ⬜ pending |
| 03-02-01 | 02 | 1 | TRACK-08 | N/A | unit | `flutter test test/unit/manual_entry_notifier_test.dart` | ⬜ pending |
| 03-02-02 | 02 | 1 | TRACK-08 | N/A | unit | `flutter test test/unit/manual_entry_notifier_test.dart` | ⬜ pending |
| 03-03-01 | 03 | 1 | TRACK-03 | N/A | unit | `flutter test test/unit/backfill_provider_test.dart` | ⬜ pending |
| 03-04-01 | 04 | 2 | TRACK-06 | N/A | widget | `flutter test test/widget/edit_trip_sheet_test.dart` | ⬜ pending |
| 03-04-02 | 04 | 2 | TRACK-07 | N/A | widget | `flutter test test/widget/home_screen_test.dart` | ⬜ pending |
| 03-04-03 | 04 | 2 | TRACK-08 | N/A | widget | `flutter test test/widget/manual_entry_sheet_test.dart` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/direction_label_service_test.dart` — unit stubs for TRACK-03 (label(DateTime) → direction string, cutoff boundary cases, UTC→local conversion)
- [ ] `test/unit/trips_dao_test.dart` — extend existing file with stubs for `updateTrip` and `deleteTrip`
- [ ] `test/unit/trip_management_notifier_test.dart` — stubs for edit/delete notifier state transitions
- [ ] `test/unit/manual_entry_notifier_test.dart` — stubs for HH:MM validation, max 23:59, malformed input, TRACK-08
- [ ] `test/unit/backfill_provider_test.dart` — stubs for one-shot backfill: skips known trips, updates unknowns, enqueues sync

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bottom sheet slides up and swipe-to-dismiss closes without saving | TRACK-06 | `showModalBottomSheet` drag behavior requires physical gesture — not testable with `pumpAndSettle` alone | Open edit sheet, partially swipe down, release — verify no save occurred and sheet dismisses |
| `showTimePicker` and `showDatePicker` system dialogs open and return selected values | TRACK-06, TRACK-08 | Platform time/date picker dialogs are not accessible via flutter_test widget pump | Tap time field, select a time, confirm — verify field updates to selected time |
| `AlertDialog` dismiss via "Cancel" does not delete trip | TRACK-07 | Dialog dismiss requires real tap; mock can test but UI fidelity requires device | Long-press / tap delete, tap Cancel — verify trip still present |
| SnackBar "Trip deleted" appears after successful delete | TRACK-07 | SnackBar overlay timing is environment-sensitive | Delete a trip, observe SnackBar appears within 1 second |
| `[+] FAB` is visible and tappable when home screen has trips | TRACK-08 | FAB positioning and z-order require visual inspection | Scroll to bottom — verify FAB remains visible and does not overlap content |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
