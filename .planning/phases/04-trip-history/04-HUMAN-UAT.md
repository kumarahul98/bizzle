---
status: partial
phase: 04-trip-history
source: [04-VERIFICATION.md]
started: 2026-04-26T07:00:00Z
updated: 2026-04-26T07:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. History list visual layout
expected: Sticky date headers pin at top while scrolling, trip cards show direction icon (arrow), distance, duration, and departure time. Empty state ("No trips yet") shows when no data.
result: [pending]

### 2. Calendar event markers and date filtering
expected: Calendar toggle button in AppBar switches to TableCalendar. Days with trips show event dot markers. Tapping a date filters to show only that day's trips in a sub-list below.
result: [pending]

### 3. Trip card navigation to detail
expected: Tapping a trip card body navigates to TripDetailScreen. Stats shown (duration, distance, direction, date) match the tapped trip's data.
result: [pending]

### 4. GPS trip map rendering
expected: TripDetailScreen for a GPS trip shows a flutter_map with OpenStreetMap tiles loaded from network, polyline route drawn, and scroll events pass through the map (IgnorePointer active).
result: [pending]

### 5. Two-step delete flow
expected: Tapping more_vert on a trip card opens bottom sheet with Edit trip / Delete trip. Tapping Delete trip shows confirmation dialog. Confirming removes the trip from the list and shows a snackbar. List updates reactively without manual refresh.
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
