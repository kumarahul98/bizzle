# Deferred items — Phase 19

Out-of-scope discoveries logged during 19-01 execution. NOT fixed (pre-existing,
unrelated to this plan's changes).

## Pre-existing analyzer `info` items in lib/config/constants.dart

Surfaced only because `flutter analyze lib/config/constants.dart` scans the whole
file; none are in the Phase 19 block (lines 921+):

- `constants.dart:302` — `lines_longer_than_80_chars` (kTrackingSpeedFreshnessWindow dartdoc).
- `constants.dart:708` — `comment_references` ([DirectionSegmentedToggle]).
- `constants.dart:713` — `comment_references` ([DirectionSegmentedToggle]).

All three pre-date Phase 19 (present on commit bc47733). Leave for a dedicated
lint-tidy pass.
