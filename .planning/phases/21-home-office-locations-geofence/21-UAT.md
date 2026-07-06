---
status: testing
phase: 21-home-office-locations-geofence
source: [21-01-SUMMARY.md, 21-02-SUMMARY.md, 21-03-SUMMARY.md]
started: 2026-06-08T00:58:22Z
updated: 2026-06-08T00:58:22Z
---

## Current Test

number: 1
name: Cold Start Smoke Test
expected: |
  Kill any running server/service. Clear ephemeral state (temp DBs, caches, lock files). Start the application from scratch. Server boots without errors, any seed/migration completes, and a primary query (health check, homepage load, or basic API call) returns live data.
awaiting: user response

## Tests

### 1. Cold Start Smoke Test
expected: |
  Kill any running server/service. Clear ephemeral state (temp DBs, caches, lock files). Start the application from scratch. Server boots without errors, any seed/migration completes, and a primary query (health check, homepage load, or basic API call) returns live data.
result: pending

### 2. Set Home/Office Locations in Settings
expected: |
  In Settings, under the Commute section, tapping Home or Office opens a full-screen map picker. The map defaults to the user's current location, last trip, or Bengaluru. The user can pan the map under a fixed crosshair and tap confirm to save the coordinate. The SavedLocationTile then shows the saved coordinate instead of "Not set".
result: pending

### 3. Geofence Applied on Commute Finalize
expected: |
  When tracking a new commute, stopping the commute within 250m of the saved Home/Office location automatically labels the trip with the correct direction without prompting, unless manually overridden during the trip.
result: pending

### 4. Manual Edits are Preserved
expected: |
  Manually editing the direction of a trip permanently stamps it as 'manual'. Future geofence backfills do not overwrite this manual choice.
result: pending

### 5. Geofence Backfill on Location Save
expected: |
  When the user updates and saves their Home or Office location in the LocationPickerScreen, past trips (that were not manually edited) are automatically evaluated in the background and re-labeled with the 'geofence' direction if their end coordinate matches the new location.
result: pending

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0

## Gaps

