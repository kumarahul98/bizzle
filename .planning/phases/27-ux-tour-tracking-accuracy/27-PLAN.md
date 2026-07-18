---
phase: 27-ux-tour-tracking-accuracy
created: 2026-07-18
status: in_progress
mode: autonomous-overnight
requirements: [TRACK-14, UX-07, UX-08]
---

# Phase 27 — UX Tour + Tracking Accuracy

Three user-requested items, built overnight autonomously with subagents.

## Concern 1 — GPS stationary-drift distance fix (TRACK-14)

**Bug:** standing still logged ~220 m over 14 min. Root cause: `TripAccumulator.addSample()`
adds `Geolocator.distanceBetween(prev, p)` to `_distanceMeters` unconditionally; the only
gate is a loose 30 m accuracy check (`kTrackingMaxAcceptableAccuracyMeters`,
`constants.dart:293`). ~0.79 m of jitter × ~280 samples (3 s interval) ≈ 220 m.

**Fix (option a — minimum-move floor):**
- Add `kTrackingMinMoveMeters = 5.0` to `lib/config/constants.dart` next to the accuracy gate.
- In `lib/features/tracking/services/trip_accumulator.dart` `addSample()`, gate ONLY the
  `_distanceMeters += Geolocator.distanceBetween(...)` line: compute the segment first, add it
  only if `segment >= kTrackingMinMoveMeters`.
- Do NOT touch: `_samples.add(p)` (polyline fidelity), the accuracy gate, time attribution
  (`prev.speed` vs `kStuckSpeedThresholdMs`), or the `kTrackingMaxAttributableGapSeconds`
  gap-branch — those must keep working unchanged.
- **Tests** (`test/unit/features/tracking/trip_accumulator_test.dart`, mirror the accuracy-gate
  test at line ~260): (1) two near-identical fixes, `speedMs: 0`, ~3 s apart → assert
  `distanceMetersForTest` stays 0; (2) a genuine >5 m move → assert it IS counted; (3) confirm
  polyline/sample count and stuck/moving time buckets are unaffected.
- Trade-off (documented): a fixed 5 m floor slightly undercounts sub-5 m/sample crawl, which is
  the stuck-in-traffic regime — acceptable for a driving commute tracker.

Files: `constants.dart`, `trip_accumulator.dart`, `trip_accumulator_test.dart`. **Isolated.**

## Concern 2 — Auto-pause ("break") ON by default + tour persistence scaffold (UX-08, DB foundation)

Grouped because both are Drift schema changes on `user_preferences`; done by ONE agent in a
single v7→v8 migration to avoid codegen races.

**Auto-pause default flip** (the "break option", `auto_pause_enabled`):
- `lib/database/tables/user_preferences_table.dart:64` — `withDefault(const Constant(false))` → `Constant(true)`.
- `lib/database/daos/user_preferences_dao.dart:53` — `autoPauseEnabled = false` → `true` in
  `UserPreferencesValue.defaults()` (governs fresh installs — no seed row, D-04).
- `lib/database/database.dart` — bump `schemaVersion` 7 → 8; add `if (from < 8 && to >= 8)`
  migration with `UPDATE user_preferences SET auto_pause_enabled = 1 WHERE id = 1` (backfill
  existing users), mirroring the v5 `has_seen_onboarding` backfill at database.dart:107.

**Tour persistence scaffold** (same v8 migration):
- Add a `seen_tours` TEXT column to `user_preferences` (default `''`), storing a CSV of page
  keys that have shown their tour. In the v8 migration: `m.addColumn(userPreferences, userPreferences.seenTours)`.
- Add DAO helpers on `UserPreferencesDao`: `Future<void> markTourSeen(String pageKey)` (append
  to CSV if absent) and expose seen set via the existing `UserPreferencesValue` (add `seenTours`
  String field, parse to `Set<String>` in a getter). Follow the existing `setHasSeenOnboarding`
  upsert pattern.
- Codegen: run `dart run build_runner build --delete-conflicting-outputs` and regenerate the
  Drift migration snapshot (`schema_v8.dart` + `schema.json` under `test/generated_migrations/`
  via `drift_dev schema` — see how v5/v7 snapshots exist).

**Tests:** add `migration_v8_test.dart` (mirror `migration_v5_test.dart`) proving auto_pause
backfilled to 1 and seen_tours column added; update `migration_v3_test.dart:91` (D-10 assertion
now stale) and the `autoPauseEnabled: false` default assertions in
`test/widget/features/settings/settings_screen_test.dart` and `user_preferences_dao_test.dart`.

Files: `user_preferences_table.dart`, `user_preferences_dao.dart`, `database.dart`,
`database.g.dart` (gen), `test/generated_migrations/*` (gen), migration + settings tests.
**Owns all Drift work.** Must complete before Concern 3.

## Concern 3 — Per-page guided tour (UX-07) — depends on Concern 2's `seen_tours` DAO

**Behavior:** first time the user lands on a page, show a quick coach-mark/spotlight tour with
a **Skip** button; show each page's tour **only once** (persisted via `seen_tours`).

**Nav/trigger:** MainShell is a 4-tab `IndexedStack` (`main_shell.dart:257-292`): Today
(Dashboard), Trips (History), Stats, Settings — switched via `mainShellIndexProvider.setIndex`.
Trigger a page's tour when its tab first becomes selected AND its key ∉ `seenTours`. Watch
`mainShellIndexProvider` in MainShell; on change (and on first build for the initial tab), if the
target page's tour is unseen, start it, then `markTourSeen(pageKey)`.

**Package:** add `showcaseview` (latest) to `pubspec.yaml` — popular, key-based spotlight with
built-in skip; wrap each page subtree in a `ShowCaseWidget` and target widgets by `GlobalKey`.
(No coach-mark pkg or `shared_preferences` exists today; persistence stays in Drift per above.)

**Per-page targets (2-4 each, keep concise):**
- Today/Dashboard: the Start/Record button, today's summary card.
- Trips/History: the trips list / calendar, a trip row (tap to view/edit).
- Stats: the main chart, the traffic breakdown.
- Settings: the auto-pause toggle, Home/Office locations.
(Executor confirms exact widgets from each screen; add `GlobalKey`s + `Showcase` wrappers.)

**Style:** match `TraevyTokensExt` (`lib/config/theme.dart`) — tooltip bg/text/accent from tokens.
Page keys + tour copy in `constants.dart` (`kTourKeyDashboard`, etc.).

**Tests:** a widget test that pumps a page with an empty `seenTours`, asserts the showcase/skip
appears and `markTourSeen` is called; and that with the key already in `seenTours` it does NOT appear.

Files: `pubspec.yaml`, new `lib/features/<page>/widgets/` showcase wrappers + a shared
`lib/features/tour/` (providers + tour controller), `main_shell.dart`, the 4 screen files,
`constants.dart`, tests.

## Execution waves (conflict-safe)
- **Wave 1 (parallel):** Agent A = Concern 1 (GPS). Agent B = Concern 2 (all Drift schema).
  Disjoint files (A: constants+accumulator; B: database/DAO/tables). Sonnet.
- **Wave 2:** Agent C = Concern 3 (tour), after B commits (needs `seen_tours` DAO). Opus (design-heavy).
- **Wave 3 (orchestrator):** integration — `flutter analyze` + full `flutter test` + `flutter build apk`;
  fix breakage; commit each concern atomically; deliver APK + summary.

## Verification
- `flutter test` full suite green (currently 654); new tests for all 3 concerns pass.
- `flutter analyze` no new errors/warnings.
- `flutter build apk --release` succeeds → deliver for on-device check:
  1. GPS: stand still with tracking on → distance stays ~0 (not climbing).
  2. Break: fresh settings show Auto-pause ON; existing upgraded install flips ON.
  3. Tour: each tab shows its tour once with a Skip button; never again after seen/skip.
