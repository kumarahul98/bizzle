---
phase: 01-foundation
plan: 02
subsystem: infra
tags: [flutter, riverpod, material3, lint, very_good_analysis, theme, constants]

# Dependency graph
requires:
  - phase: 01-foundation / plan 01
    provides: Flutter scaffold, flutter_riverpod 3.3.1, very_good_analysis 10.2.0, strict Android SDK pinning
provides:
  - "lib/config/constants.dart — 13 locked Phase 1 top-level constants (speed threshold, cutoff hours, default user id, DB name, retry cap, direction + sync-action + sync-status literals)"
  - "lib/config/theme.dart — Material 3 lightTheme / darkTheme defaults"
  - "lib/config/routes.dart — empty kAppRoutes map reserving the symbol for future phases"
  - "lib/main.dart — ProviderScope-wrapped entry point running TraevyApp"
  - "lib/app.dart — TraevyApp (MaterialApp) + PlaceholderHome Phase 1 shell"
  - "analysis_options.yaml — strict-casts / strict-inference / strict-raw-types, exclusions for *.g.dart / drift_schemas, public_member_api_docs override, custom prefer_const rules"
  - "test/unit/config/constants_test.dart — regression test for every Phase 1 constant"
  - "test/unit/app_bootstrap_test.dart — smoke test pumping ProviderScope + TraevyApp"
affects: [01-03, 01-04, 02-tracking, 03-database, 04-trips]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Feature-agnostic top-level constants live in lib/config/constants.dart — no enums/classes in Phase 1 (sealed direction enum waits for Phase 3 per CLAUDE.md)"
    - "MaterialApp wired with lightTheme + darkTheme + ThemeMode.system from day one so Phase 7 polish swaps ThemeData values without touching app.dart"
    - "All intra-package imports under lib/ use package:traevy/... form (very_good_analysis always_use_package_imports)"
    - "Strict analyzer language modes (strict-casts / strict-inference / strict-raw-types) are on from Phase 1 so subsequent phases inherit full type safety"
    - "Riverpod 3.x manual providers are the standard — no @riverpod annotations until custom_lint / riverpod_generator ships an analyzer ^10 compatible release"
    - "Per-task atomic commits with --no-verify (worktree-parallel execution)"

key-files:
  created:
    - "lib/config/constants.dart"
    - "lib/config/theme.dart"
    - "lib/config/routes.dart"
    - "lib/app.dart"
    - "test/unit/config/constants_test.dart"
    - "test/unit/app_bootstrap_test.dart"
    - ".planning/phases/01-foundation/01-02-SUMMARY.md"
  modified:
    - "lib/main.dart (full rewrite — replaces the broken default counter scaffold with a minimal ProviderScope entry)"
    - "analysis_options.yaml (very_good_analysis base + strict language modes + rule overrides + generated-file exclusions)"
    - "pubspec.yaml (dependencies sorted alphabetically to satisfy sort_pub_dependencies)"
  deleted:
    - "test/widget_test.dart (referenced removed MyApp counter scaffold; Plan 04 will recreate a proper smoke test)"

key-decisions:
  - "Defer custom_lint / riverpod_lint plugin registration — Wave 1 (01-01) could not install them because drift_dev 2.32.1 locks analyzer ^10 while every published custom_lint / riverpod_generator requires analyzer ^9. Commented-out plugins block in analysis_options.yaml preserves a re-enable path."
  - "Keep themeMode: ThemeMode.system and routes: kAppRoutes explicit in TraevyApp even though both happen to match MaterialApp defaults today — plan locks them as contract, suppressed with inline avoid_redundant_argument_values ignores."
  - "Delete the stale test/widget_test.dart instead of stubbing it — Plan 01-04 owns widget-test creation, deletion keeps flutter test exit-zero in the meantime."
  - "Sort pubspec.yaml dependencies alphabetically and move the Flutter SDK dependency into its alphabetical slot (between drift_flutter and flutter_riverpod) to satisfy sort_pub_dependencies at the expected column."

patterns-established:
  - "Every constant in lib/config/constants.dart carries a doc comment citing its source (CLAUDE.md section or CONTEXT.md decision ID)"
  - "Config-only test directory layout under test/unit/config/ — feature tests will live under test/unit/<feature>/ in later phases"
  - "TDD tasks commit RED (failing test) and GREEN (implementation) as separate atomic commits"

requirements-completed: [SYNC-01]

# Metrics
duration: ~12min
completed: 2026-04-12
---

# Phase 01 Plan 02: Config + Theme + Entry Point Summary

**ProviderScope-wrapped TraevyApp with Material 3 light/dark themes, 13 locked Phase 1 top-level constants, very_good_analysis 10.2.0 strict-casts ruleset, and exit-zero `flutter analyze` / `flutter test` across the whole project**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-12T09:05:00Z
- **Completed:** 2026-04-12T09:17:56Z
- **Tasks:** 4
- **Files modified:** 6 created, 3 modified, 1 deleted (+ this SUMMARY)

## Accomplishments

- Every locked Phase 1 constant (speed threshold, cutoff hour, default user id, database name, sync queue retry cap, direction literals, sync action literals, sync status literals) lives in `lib/config/constants.dart` with a doc comment tying it back to CLAUDE.md or the CONTEXT.md decision that pinned the value.
- `lib/main.dart` is now a four-line `runApp(const ProviderScope(child: TraevyApp()))` — the broken counter scaffold (which contained invalid Dart literals `.fromSeed(...)` and `.center` inherited from Wave 1) is gone.
- `lib/app.dart` declares `TraevyApp` (title `'Traevy'`, `lightTheme`, `darkTheme`, `ThemeMode.system`, `kAppRoutes`, `PlaceholderHome` home) and `PlaceholderHome` (AppBar + centered `'Traevy Phase 1'`). All widgets are `const`-constructible.
- `analysis_options.yaml` enables very_good_analysis strict-casts / strict-inference / strict-raw-types, excludes generated Drift/Riverpod files, and overrides `public_member_api_docs` and `avoid_positional_boolean_parameters`.
- `flutter analyze` returns zero findings across the whole project. `flutter test` runs all 9 tests green (8 constants assertions + 1 bootstrap smoke test).

## Task Commits

Each task was committed atomically with `--no-verify` (parallel-executor mode). TDD tasks 1 and 4 have separate RED + GREEN commits:

1. **Task 1 RED — failing constants test + stale widget_test removal** — `c8fc9cf` (test)
2. **Task 1 GREEN — lib/config/constants.dart** — `fc1a723` (feat)
3. **Task 2 — theme.dart + routes.dart** — `11810bd` (feat)
4. **Task 3 — analysis_options.yaml strict ruleset** — `da4c408` (chore)
5. **Task 4 RED — failing TraevyApp bootstrap smoke test** — `4146022` (test)
6. **Task 4 GREEN — main.dart/app.dart rewrite + lint cleanup** — `47bcbbf` (feat)

## Files Created/Modified

Created:

- `lib/config/constants.dart` — 13 top-level `const` declarations, each with a doc comment citing CLAUDE.md or CONTEXT.md
- `lib/config/theme.dart` — `lightTheme` / `darkTheme` Material 3 defaults (`useMaterial3: true`)
- `lib/config/routes.dart` — empty `const Map<String, WidgetBuilder> kAppRoutes`
- `lib/app.dart` — `TraevyApp` + `PlaceholderHome`
- `test/unit/config/constants_test.dart` — 8 expectations covering every Phase 1 constant
- `test/unit/app_bootstrap_test.dart` — pumps `ProviderScope(TraevyApp)` and asserts MaterialApp title, themes, themeMode, and `PlaceholderHome` content

Modified:

- `lib/main.dart` — full rewrite to `runApp(const ProviderScope(child: TraevyApp()))`
- `analysis_options.yaml` — strict language modes, generated-file exclusions, rule overrides, prefer_const cluster
- `pubspec.yaml` — alphabetical dependency sort (moves Flutter SDK dep into the sorted order between `drift_flutter` and `flutter_riverpod`)

Deleted:

- `test/widget_test.dart` — referenced the removed `MyApp` counter scaffold; Plan 01-04 owns widget-test authoring

## Reference: Final `lib/config/constants.dart` Inventory

For cross-phase reference (Plan 01-03 imports these to seed the Drift defaults, Phase 2+ imports these for runtime thresholds):

| Constant | Type | Value | Source |
|---|---|---|---|
| `kStuckSpeedThresholdKmh` | `double` | `10` | CLAUDE.md "Traffic Calculation" |
| `kDefaultDirectionCutoffHour` | `int` | `12` | CLAUDE.md "Direction Auto-Labeling" |
| `kDefaultUserId` | `String` | `'local_user'` | CONTEXT.md D-02 |
| `kDatabaseName` | `String` | `'traevy'` | CONTEXT.md D-04 |
| `kSyncQueueMaxRetries` | `int` | `3` | CLAUDE.md "sync_queue retries max 3" |
| `kDirectionToOffice` | `String` | `'to_office'` | CLAUDE.md "Direction Auto-Labeling" |
| `kDirectionToHome` | `String` | `'to_home'` | CLAUDE.md "Direction Auto-Labeling" |
| `kSyncActionCreate` | `String` | `'create'` | CLAUDE.md "sync_queue" schema |
| `kSyncActionUpdate` | `String` | `'update'` | CLAUDE.md "sync_queue" schema |
| `kSyncActionDelete` | `String` | `'delete'` | CLAUDE.md "sync_queue" schema |
| `kSyncStatusPending` | `String` | `'pending'` | CLAUDE.md "sync_queue" schema |
| `kSyncStatusSynced` | `String` | `'synced'` | CLAUDE.md "sync_queue" schema |
| `kSyncStatusFailed` | `String` | `'failed'` | CLAUDE.md "sync_queue" schema |

Total: **13 constants** (exactly the count in the plan's `<interfaces>` block).

## Reference: Final `analysis_options.yaml` Active Rule Set

For Plan 01-04 (tests) to know exactly which rules are in force when it writes test files:

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - lib/**/*.g.dart
    - lib/**/*.freezed.dart
    - test/generated_migrations/**
    - drift_schemas/**
    - build/**
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  # plugins: (commented out — custom_lint deferred; see deviations)
  errors:
    public_member_api_docs: ignore
    avoid_positional_boolean_parameters: warning

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    avoid_dynamic_calls: true
```

**Active lint cluster inherited from `very_good_analysis ^10.2.0`:** the full VGV ruleset (strict `always_use_package_imports`, `lines_longer_than_80_chars`, `sort_pub_dependencies`, `avoid_redundant_argument_values`, etc.). Test files must use `package:` imports, stay under 80 columns, and avoid dynamic calls.

## Decisions Made

1. **Defer `custom_lint` plugin registration.** The plan called for `plugins: - custom_lint` in `analysis_options.yaml`, but Wave 1 (plan 01-01) could not install `custom_lint` / `riverpod_lint` because of the analyzer ^9 vs ^10 conflict with `drift_dev 2.32.1`. Adding the plugin directive without the package would hard-fail `flutter analyze` with "plugin not found". Kept a commented-out `plugins:` block so re-enabling is a one-line edit when the ecosystem catches up.
2. **Keep `themeMode` and `routes` explicit on `MaterialApp` despite matching defaults.** Both values happen to equal `MaterialApp`'s defaults today, triggering `avoid_redundant_argument_values`. The plan explicitly mandates both as part of the contract, and the bootstrap test asserts `materialApp.themeMode == ThemeMode.system`. Resolved with per-line `// ignore: avoid_redundant_argument_values` comments plus rationale comments explaining the contract intent.
3. **Delete `test/widget_test.dart` outright** instead of stubbing. The plan says "Prefer deletion — Plan 04 recreates it" and the stale file references the removed `MyApp` class, which would break `flutter test` compilation. Plan 01-04 will author a proper ProviderScope + TraevyApp smoke test.
4. **Sort `pubspec.yaml` dependencies alphabetically** (including moving the Flutter SDK dep into its alphabetical slot between `drift_flutter` and `flutter_riverpod`). Plan 01-01 left dependencies in `flutter pub add` insertion order, which tripped `sort_pub_dependencies`. Sorting here clears the noise early so future plans don't inherit it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Omitted `plugins: - custom_lint` from `analysis_options.yaml`**
- **Found during:** Task 3 (analysis_options.yaml wiring)
- **Issue:** Plan task 3 dictates `plugins: - custom_lint` under `analyzer:`. Wave 1 (plan 01-01) documented in its SUMMARY that `custom_lint` and `riverpod_lint` were not installed because `drift_dev ^2.32.1` locks `analyzer ^10` while every published `custom_lint` / `riverpod_generator` requires `analyzer ^9`. Adding the plugin directive without the package in `dev_dependencies` would make every `flutter analyze` invocation fail with "plugin not found".
- **Fix:** Wrote `analysis_options.yaml` with everything else the plan specified (strict-casts, exclusions, error overrides, prefer_const cluster) and left a commented-out `plugins:` block explaining the deferral. Documented the reasoning inline in the task 3 commit message.
- **Files modified:** `analysis_options.yaml`
- **Verification:** `flutter analyze` exits zero on the whole project; the comment preserves a one-line re-enable path for when the Riverpod tooling ships an analyzer ^10 compatible release.
- **Committed in:** `da4c408` (Task 3 commit)

**2. [Rule 1 - Bug] Switched `lib/` intra-package imports from relative to `package:traevy/...`**
- **Found during:** Task 4 (full-project `flutter analyze` gate)
- **Issue:** The plan's task 4 code block shows relative imports (`import 'app.dart';`, `import 'config/theme.dart';`). Under very_good_analysis the `always_use_package_imports` rule is on, so three files emitted info-level findings after task 4.
- **Fix:** Rewrote the imports in `lib/main.dart` and `lib/app.dart` to use `package:traevy/app.dart`, `package:traevy/config/routes.dart`, `package:traevy/config/theme.dart`. Behavior is identical; only the import path syntax changes.
- **Files modified:** `lib/main.dart`, `lib/app.dart`
- **Verification:** `flutter analyze` zero findings; `flutter test` 9/9 passing.
- **Committed in:** `47bcbbf` (Task 4 GREEN commit)

**3. [Rule 2 - Missing Critical] Added inline `// ignore: avoid_redundant_argument_values` on `themeMode` and `routes`**
- **Found during:** Task 4 (full-project `flutter analyze` gate)
- **Issue:** The plan locks `themeMode: ThemeMode.system` and `routes: kAppRoutes` as an explicit contract on `MaterialApp`, and the bootstrap test asserts those exact values. Both happen to equal MaterialApp's defaults today, so very_good_analysis reports `avoid_redundant_argument_values` info-level findings. Removing the arguments would violate the plan contract and break the test assertion `materialApp.themeMode == ThemeMode.system`.
- **Fix:** Added per-line `// ignore: avoid_redundant_argument_values` comments with rationale comments explaining that the arguments are intentional contract locks.
- **Files modified:** `lib/app.dart`
- **Verification:** `flutter analyze` zero findings; bootstrap test still asserts contract correctly.
- **Committed in:** `47bcbbf` (Task 4 GREEN commit)

**4. [Rule 3 - Blocking] Deleted `test/widget_test.dart` (referenced removed `MyApp`)**
- **Found during:** Task 1 (first `flutter test` run)
- **Issue:** Plan 01-01 created the default Flutter scaffold including `test/widget_test.dart`, which imports `MyApp` from `lib/main.dart`. Task 4 of this plan replaces `main.dart` and removes `MyApp`, so the file would fail to compile. The plan's task 4 action explicitly says "Prefer deletion — Plan 04 recreates it". Until the file is gone, `flutter test` cannot run at all.
- **Fix:** Deleted `test/widget_test.dart` alongside the RED constants test commit so task 1's verification (`flutter test test/unit/config/constants_test.dart`) could execute. Plan 01-04 owns recreating a proper ProviderScope + TraevyApp smoke test.
- **Files modified:** `test/widget_test.dart` (deleted)
- **Verification:** `flutter test` runs cleanly; tracked in `test/unit/app_bootstrap_test.dart` as interim smoke coverage.
- **Committed in:** `c8fc9cf` (Task 1 RED commit)

**5. [Rule 1 - Bug] Sorted `pubspec.yaml` dependencies alphabetically**
- **Found during:** Task 4 (full-project `flutter analyze` gate)
- **Issue:** Plan 01-01 left `pubspec.yaml` in `flutter pub add` insertion order, triggering `sort_pub_dependencies` info-level findings that its SUMMARY noted plan 01-02 would address. Task 4's final `flutter analyze` gate surfaced the finding.
- **Fix:** Reordered `dependencies:` block alphabetically: `cupertino_icons`, `drift`, `drift_flutter`, `flutter` (sdk), `flutter_riverpod`, `intl`, `path_provider`, `riverpod_annotation`, `uuid`. `dev_dependencies:` was already sorted.
- **Files modified:** `pubspec.yaml`
- **Verification:** `flutter pub get` succeeds with the same resolved versions; `flutter analyze` zero findings.
- **Committed in:** `47bcbbf` (Task 4 GREEN commit)

---

**Total deviations:** 5 auto-fixed (2 Rule 3 blocking, 2 Rule 1 bug, 1 Rule 2 missing-critical)
**Impact on plan:** No scope creep — every deviation is either a lint cleanup necessary to hit the plan's stated exit-zero `flutter analyze` criterion, or a side effect of Wave 1's deferred tooling. The single material change (custom_lint plugin deferral) is preserved as a commented-out block so re-enabling stays a one-line edit. All plan success criteria met.

## Issues Encountered

- `lib/main.dart` inherited from Plan 01-01 contained invalid Dart (`.fromSeed(seedColor: ...)` and `mainAxisAlignment: .center` — the scaffold's type names were dropped somewhere). It did not fail compilation because Task 4 replaces the file wholesale, but it would have broken hot-reload if anyone had run `flutter run` between Wave 1 and Wave 2. Task 4's rewrite is clean and `flutter analyze` is now green on the file.
- `very_good_analysis` reports `sort_pub_dependencies` against line 36 (the first entry after the comment) rather than against the offending pair. Initial alphabetical sort on the non-SDK deps left `flutter` (sdk) out of its sorted slot, and the finding persisted. Resolved by moving the Flutter SDK dep into its alphabetical position between `drift_flutter` and `flutter_riverpod`.

## Threat Surface (from plan `<threat_model>`)

The plan registered three threats, all `mitigate` or `accept`:

- **T-01-05 (Tampering, analysis_options.yaml, mitigate):** Mitigated via `include: package:very_good_analysis/analysis_options.yaml` — the ruleset is sourced from a versioned, caret-pinned package rather than hand-maintained rules. Generated files are excluded from linting but not from compilation; the Dart analyzer still type-checks them.
- **T-01-06 (Information Disclosure, constants.dart, accept):** No secrets or PII in Phase 1. `kDefaultUserId = 'local_user'` is a placeholder replaced by Cognito `sub` in Phase 8; `kDatabaseName = 'traevy'` is not security-sensitive.
- **T-01-07 (Denial of Service, missing ProviderScope, mitigate):** Mitigated — `lib/main.dart` wraps `TraevyApp` directly in `ProviderScope`. The bootstrap test (`test/unit/app_bootstrap_test.dart`) pumps `ProviderScope(child: TraevyApp())` and would fail at compile time if the structure regressed. Plan 01-04's widget smoke test will strengthen the coverage further.

**No new threat surface introduced.** This plan adds no network endpoints, auth paths, file access, or schema changes.

## User Setup Required

None — no external service configuration required for this plan.

## Next Phase Readiness

**Ready for plan 01-03 (Drift database scaffolding):**

- `lib/config/constants.dart` exposes `kDatabaseName` for the Drift opener and `kDefaultUserId` for seeding default rows.
- `lib/main.dart` already wraps `TraevyApp` in `ProviderScope`, so plan 03 can add an `appDatabase` provider and consume it without touching bootstrap code.
- `analysis_options.yaml` excludes `lib/**/*.g.dart` — `drift_dev build_runner` output will not spam `flutter analyze`.

**Ready for plan 01-04 (tests):**

- `test/unit/config/` layout is in place and verified against the VGV ruleset (package imports, <=80 cols, no dynamic calls).
- Active lint rule set is documented above so plan 04's test files can target the exact constraints.
- Stub `test/unit/app_bootstrap_test.dart` exists as interim smoke coverage — plan 04 can replace or extend it.

**Open follow-ups for later plans (not blockers for 01-03 / 01-04):**

- When the Riverpod / `custom_lint` ecosystem aligns on `analyzer ^10`, install `riverpod_generator`, `custom_lint`, `riverpod_lint` and uncomment the `plugins:` block in `analysis_options.yaml`.
- Phase 7 (polish) should replace the Material 3 default `ThemeData.light/dark` values in `lib/config/theme.dart` with branded colours.

## Self-Check

**Files verified present:**

- `lib/config/constants.dart` — 13 top-level `const` declarations, each with a doc comment
- `lib/config/theme.dart` — `lightTheme` + `darkTheme`
- `lib/config/routes.dart` — `kAppRoutes`
- `lib/app.dart` — `TraevyApp` + `PlaceholderHome`
- `lib/main.dart` — `runApp(const ProviderScope(child: TraevyApp()))`
- `analysis_options.yaml` — VGV include + strict language modes + overrides
- `test/unit/config/constants_test.dart` — 8 assertions, all passing
- `test/unit/app_bootstrap_test.dart` — 1 assertion, passing
- `.planning/phases/01-foundation/01-02-SUMMARY.md` — this file

**Commits verified in git log:**

- `c8fc9cf` Task 1 RED — failing constants test + stale widget_test removal
- `fc1a723` Task 1 GREEN — `lib/config/constants.dart`
- `11810bd` Task 2 — `theme.dart` + `routes.dart`
- `da4c408` Task 3 — `analysis_options.yaml`
- `4146022` Task 4 RED — failing TraevyApp bootstrap smoke test
- `47bcbbf` Task 4 GREEN — `main.dart` / `app.dart` rewrite + lint cleanup

**Quality gates:**

- `flutter analyze` → `No issues found! (ran in 4.3s)` — zero errors, zero warnings, zero info
- `flutter test` → `All tests passed!` (9/9: 8 constants + 1 bootstrap smoke)

## Self-Check: PASSED

---
*Phase: 01-foundation*
*Plan: 02*
*Completed: 2026-04-12*
