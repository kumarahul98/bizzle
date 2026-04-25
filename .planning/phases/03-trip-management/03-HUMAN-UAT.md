---
status: partial
phase: 03-trip-management
source: [03-VERIFICATION.md]
started: 2026-04-25T00:00:00.000Z
updated: 2026-04-25T00:00:00.000Z
---

## Current Test

[testing complete]

## Tests

### 1. EditTripSheet full edit flow
expected: Sheet opens, user can change direction and adjust times, Save dismisses with 'Trip updated' SnackBar. Requires Phase 4 trip card to trigger, or debug harness.
result: blocked
blocked_by: prior-phase
reason: "No trip cards yet — EditTripSheet entry point arrives in Phase 4."

### 2. End-before-start validation in EditTripSheet
expected: When end time is set before or equal to start time, inline error 'End time must be after start time.' appears in colorScheme.error color and Save button is disabled.
result: blocked
blocked_by: prior-phase
reason: "EditTripSheet requires Phase 4 trip cards to open."

### 3. ManualEntrySheet Save-disabled and inline error states
expected: Save disabled while HH:MM field is empty. 'Enter a duration like 0:45.' shown on empty submit. 'Use HH:MM format between 0:00 and 23:59.' shown on malformed input (e.g. '99:99').
result: pass

### 4. FAB visibility toggle during active tracking
expected: [+] FAB is visible on home screen when not tracking; FAB disappears when a tracking session is active. Requires live device with background service running.
result: pass

### 5. Delete flow triggered from trip card
expected: Long-press or delete icon on trip card calls handleDeleteTrip, AlertDialog appears with 'Delete trip?' and destructive FilledButton, confirming removes the trip and shows 'Trip deleted' SnackBar. Requires Phase 4 trip cards.
result: blocked
blocked_by: prior-phase
reason: "No trip cards yet — arrives in Phase 4."

### 6. Phase 2 backfill on upgrade
expected: On first launch after upgrading from a Phase 2 build that has trips with direction='unknown', directionBackfillProvider runs once and labels all unknown rows. No unknown-direction trips remain after backfill.
result: skipped
reason: No UI to surface direction labels until Phase 4 trip cards. Re-test when trip cards are available.

## Summary

total: 6
passed: 2
issues: 0
pending: 0
skipped: 1
blocked: 3

## Gaps
