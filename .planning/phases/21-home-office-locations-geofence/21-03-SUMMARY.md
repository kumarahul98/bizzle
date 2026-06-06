# Geofence Backfill Service
_Phase 21 Plan 03 (LOC-02)_

We have successfully implemented the geofence backfill logic to automatically re-label historical trips when the user updates their Home or Office locations.

## Changes Made
- Added a targeted query `geofenceBackfillCandidates()` to `TripsDao` that retrieves non-manual trips with a non-empty polyline, strictly skipping rows where `direction_source == 'manual'`.
- Implemented `GeofenceBackfillService` to decode polylines and use the pure `GeofenceDirectionResolver` to test proximity. It writes back to the DB with `direction_source = 'geofence'` only when the result is confident and differs from the current label. This preserves strict idempotency and avoids unnecessary SQLite writes.
- Added a one-shot `geofenceBackfillProvider` (Riverpod `FutureProvider`) and wired it into `LocationPickerScreen`. After a location is confirmed and saved, the provider is invalidated, triggering the background backfill.

## Verification
- Added comprehensive unit tests in `test/unit/features/trips/geofence_backfill_service_test.dart` simulating the SQLite behavior with memory data structures, verifying no manual trips get altered and checking idempotency logic.
- Run `dart run build_runner build` to refresh generated code.
- Run `flutter test` resulting in **All tests passed!** (548 out of 548).
- Checked `dart analyze` resulting in **No issues found!**
