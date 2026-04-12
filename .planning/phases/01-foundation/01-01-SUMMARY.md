---
phase: 01-foundation
plan: 01
subsystem: infra
tags: [flutter, dart, drift, riverpod, gradle, android, scaffold]

# Dependency graph
requires: []
provides:
  - Flutter project scaffold at repo root (org traevy, name traevy)
  - Phase 1 core dependencies installed (drift, drift_flutter, flutter_riverpod, riverpod_annotation, uuid, intl, path_provider)
  - Dev dependencies (drift_dev, build_runner, very_good_analysis)
  - Android Gradle locked to minSdk 34 / targetSdk 34, compileSdk 35
  - Working `flutter build apk --debug` pipeline
affects: [01-02, 01-03, 01-04, 02-tracking, 03-database]

# Tech tracking
tech-stack:
  added:
    - "Flutter 3.41.6 / Dart 3.11.4"
    - "drift 2.32.1 + drift_flutter 0.3.0 (SQLite)"
    - "flutter_riverpod 3.3.1 + riverpod_annotation 4.0.2"
    - "uuid 4.5.3, intl 0.20.2, path_provider 2.1.5"
    - "drift_dev 2.32.1, build_runner 2.13.1"
    - "very_good_analysis 10.2.0"
  patterns:
    - "Caret-range pinning on direct deps; pubspec.lock committed for reproducibility"
    - "Explicit literal Android SDK versions (no flutter.* indirection)"
    - "Android-only platforms via flutter create --platforms=android"

key-files:
  created:
    - "pubspec.yaml"
    - "pubspec.lock"
    - "lib/main.dart (default counter scaffold; replaced in plan 02)"
    - "android/app/build.gradle.kts"
    - "android/app/src/main/AndroidManifest.xml"
    - "android/app/src/main/kotlin/traevy/traevy/MainActivity.kt"
    - "analysis_options.yaml"
    - ".gitignore"
    - "README.md"
    - "test/widget_test.dart"
  modified:
    - "android/app/build.gradle.kts (compileSdk 35, minSdk 34, targetSdk 34)"
    - "analysis_options.yaml (very_good_analysis instead of flutter_lints)"
    - "lib/main.dart (MaterialApp title -> 'Traevy')"
    - ".gitignore (extended with .flutter-plugins, .packages, ios/Pods/)"

key-decisions:
  - "Defer riverpod_generator + custom_lint + riverpod_lint to a later plan (analyzer ^9 vs ^10 incompatibility with drift_dev 2.32.1)"
  - "Accept transitive sqlite3_flutter_libs (marked +eol upstream) since drift_flutter 0.3.0 hard-depends on it"
  - "compileSdk = 35 to satisfy jni / jni_flutter plugin requirements while keeping runtime targetSdk at 34 (D-08)"
  - "Use Android Gradle Kotlin DSL (build.gradle.kts) — current Flutter scaffold default"

patterns-established:
  - "Explicit Android SDK pinning: literal integers, no flutter.* fields, with comments referencing the locked decision (D-08)"
  - "Manual Riverpod 3.x providers will be the standard until the riverpod_generator/custom_lint ecosystem catches up to analyzer ^10"
  - "Per-task atomic commits using --no-verify in worktree-parallel mode"

requirements-completed: [SYNC-01]

# Metrics
duration: 51min
completed: 2026-04-12
---

# Phase 01 Plan 01: Project Scaffold Summary

**Traevy Flutter project scaffolded at repo root with drift 2.32.1, flutter_riverpod 3.3.1, Android Gradle pinned to minSdk/targetSdk 34 and compileSdk 35, debug APK builds clean**

## Performance

- **Duration:** ~51 min
- **Started:** 2026-04-12T08:17:00Z
- **Completed:** 2026-04-12T09:08:11Z
- **Tasks:** 3
- **Files modified:** 27 created (full Flutter scaffold) + 1 modified after scaffold (`android/app/build.gradle.kts`)

## Accomplishments

- Flutter project tree exists at the worktree root with `name: traevy` and `applicationId "traevy.traevy"`.
- All 7 runtime dependencies and 3 of 6 dev dependencies declared at the verified Phase 1 versions; the remaining 3 dev deps are deferred (see Deviations).
- `flutter build apk --debug` produces `build/app/outputs/flutter-apk/app-debug.apk` with no warnings.
- `pubspec.lock` is committed for reproducible installs.
- `analysis_options.yaml` rewired from `flutter_lints` to `very_good_analysis` so `flutter analyze` runs cleanly against the chosen rule set.

## Task Commits

Each task was committed atomically with `--no-verify` (parallel-executor mode):

1. **Task 1: Scaffold Flutter project** — `854e850` (chore)
2. **Task 2: Install Phase 1 core dependencies** — `cf9b45e` (chore)
3. **Task 3: Lock Android Gradle to minSdk 34 / targetSdk 34** — `5c221cc` (chore)

## Files Created/Modified

Created (Task 1):
- `pubspec.yaml`, `pubspec.lock` — Flutter project manifest
- `lib/main.dart` — Default counter scaffold with title `'Traevy'` (replaced in plan 02)
- `android/app/build.gradle.kts` — Android app build config (Kotlin DSL)
- `android/build.gradle.kts`, `android/settings.gradle.kts` — Project-level Gradle
- `android/app/src/main/AndroidManifest.xml` — Default manifest (permissions added in plan 03)
- `android/app/src/main/kotlin/traevy/traevy/MainActivity.kt` — Stub activity
- `android/app/src/{debug,profile}/AndroidManifest.xml` — Build-variant manifests
- `android/gradle.properties`, `android/gradle/wrapper/gradle-wrapper.properties`
- `analysis_options.yaml`, `.gitignore`, `.metadata`, `README.md`
- `test/widget_test.dart` — Default widget test (will fail until plan 02 updates main.dart; out of scope here)
- Android resource directories under `android/app/src/main/res/`

Modified after scaffolding:
- `lib/main.dart` — `MaterialApp(title: 'Traevy')` (Task 1)
- `.gitignore` — added `.flutter-plugins`, `.packages`, `ios/Pods/` guards (Task 1)
- `pubspec.yaml` / `pubspec.lock` — installed Phase 1 dependencies (Task 2)
- `analysis_options.yaml` — switched include to `very_good_analysis` (Task 2)
- `android/app/build.gradle.kts` — explicit `minSdk = 34`, `targetSdk = 34`, `compileSdk = 35` (Task 3)

## Resolved Dependency Versions (from pubspec.lock)

For plan 03 to reference real versions instead of caret ranges:

| Package              | Resolved | Notes                                            |
|----------------------|----------|--------------------------------------------------|
| drift                | 2.32.1   | direct main                                      |
| drift_flutter        | 0.3.0    | direct main; pulls in sqlite3_flutter_libs       |
| path_provider        | (latest) | direct main                                      |
| flutter_riverpod     | 3.3.1    | direct main                                      |
| riverpod_annotation  | 4.0.2    | direct main                                      |
| uuid                 | 4.5.3    | direct main                                      |
| intl                 | 0.20.2   | direct main                                      |
| drift_dev            | 2.32.1   | direct dev                                       |
| build_runner         | 2.13.1   | direct dev                                       |
| very_good_analysis   | 10.2.0   | direct dev                                       |
| sqlite3_flutter_libs | 0.6.0+eol| transitive (via drift_flutter)                   |
| sqlcipher_flutter_libs | 0.7.0+eol | transitive (via drift_flutter)                |
| analyzer             | 10.0.1   | transitive                                       |

## Decisions Made

1. **Defer code-generation tooling** (`riverpod_generator`, `custom_lint`, `riverpod_lint`). The plan's locked combination is mathematically impossible: `drift_dev 2.32.1` requires `analyzer ^10.0.0–13.0.0` while every published `riverpod_generator` requires `analyzer ^9.0.0` or older. The user accepted Riverpod 3.x/4.x in D-07; manual provider declarations are still officially supported and produce identical runtime behavior. A follow-up plan (or plan 02) can introduce code-gen once `riverpod_generator` ships an analyzer ^10 release.
2. **Accept the EOL `sqlite3_flutter_libs` transitive dependency.** The plan assumed `drift_flutter` no longer pulls it in, but `drift_flutter 0.3.0` hard-depends on `sqlite3_flutter_libs ^0.6.0+eol` and `sqlcipher_flutter_libs ^0.7.0+eol`. The `+eol` suffix means the package is in maintenance mode upstream — it is not a runtime defect. Removing it would require dropping `drift_flutter`, which contradicts D-07.
3. **Bump `compileSdk` to 35** while keeping `minSdk = targetSdk = 34`. The transitive `jni` and `jni_flutter` plugins (from `drift_flutter`) require API 35 headers at compile time. `compileSdk` controls available APIs to the compiler; `targetSdk` controls runtime behavior. D-08's intent (modern API runtime baseline at 34) is preserved.
4. **Use Kotlin DSL Gradle files** (`build.gradle.kts`). The current Flutter 3.41 scaffold defaults to Kotlin DSL. The plan referred to `build.gradle` (Groovy DSL) generically; the actual files are functionally equivalent.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed `riverpod_generator`, `custom_lint`, `riverpod_lint` from the install list**
- **Found during:** Task 2 (dev dependency installation)
- **Issue:** `flutter pub add` rejected the locked version combination. `drift_dev ^2.32.1` requires `analyzer ^10.0.0–13.0.0`; every `riverpod_generator` version requires `analyzer ^9.0.0` or older. `custom_lint ^0.8.1` requires `analyzer ^8.0.0`. No version solution exists.
- **Fix:** Installed only `drift_dev`, `build_runner`, and `very_good_analysis`. Documented in commit message that the code-gen + lint trio is deferred. No runtime impact — Riverpod 3.x supports manual provider declarations natively.
- **Files modified:** `pubspec.yaml`, `pubspec.lock`
- **Verification:** `flutter pub get` succeeds; `flutter analyze` runs (info-level lints only, all in default scaffold files that plan 02 replaces).
- **Committed in:** `cf9b45e`

**2. [Rule 1 - Bug] Plan asserted `sqlite3_flutter_libs` would be absent from `pubspec.lock`; in reality `drift_flutter 0.3.0` requires it**
- **Found during:** Task 2 (immediately after `flutter pub add drift_flutter`)
- **Issue:** Plan's verify check `! grep -q 'sqlite3_flutter_libs' pubspec.lock` cannot pass: `drift_flutter` directly depends on `sqlite3_flutter_libs ^0.6.0+eol` and `sqlcipher_flutter_libs ^0.7.0+eol`. The `+eol` suffix is upstream maintenance status, not a build failure indicator. The plan's research (RESEARCH.md Pitfall 1) was outdated for this specific drift_flutter version.
- **Fix:** Documented as accepted transitive dependency. The package is functional; abandoning `drift_flutter` would mean re-adding the `path_provider` + `sqlite3_flutter_libs` glue manually, which gives strictly worse outcomes.
- **Files modified:** None (status quo; documented in commit message)
- **Verification:** `flutter pub get` succeeds; `flutter build apk --debug` produces a working APK.
- **Committed in:** `cf9b45e`

**3. [Rule 3 - Blocking] `analysis_options.yaml` referenced removed `flutter_lints` package**
- **Found during:** Task 2 (after removing `flutter_lints` per plan instruction)
- **Issue:** `flutter create` produced an `analysis_options.yaml` whose `include:` directive points at `package:flutter_lints/flutter.yaml`. After removing `flutter_lints`, `flutter analyze` reported `include_file_not_found`.
- **Fix:** Updated the `include:` directive to `package:very_good_analysis/analysis_options.yaml`. Plan 02 will fully customize the lint rules; this is a minimal fix to keep `flutter analyze` exit-zero.
- **Files modified:** `analysis_options.yaml`
- **Verification:** `flutter analyze` runs (info-level lints from `very_good_analysis` only).
- **Committed in:** `cf9b45e`

**4. [Rule 1 - Bug] `compileSdk = 34` triggered plugin warnings; bumped to 35**
- **Found during:** Task 3 (first `flutter build apk --debug`)
- **Issue:** Build emitted warnings: `jni` and `jni_flutter` plugins (transitive via `drift_flutter`) require `compileSdk = 35`. The build still produced an APK on the first attempt, but Flutter explicitly recommended bumping `compileSdk`.
- **Fix:** Set `compileSdk = 35` while leaving `minSdk = 34` and `targetSdk = 34`. Added a comment in `build.gradle.kts` explaining that runtime behavior remains API 34 (D-08 intact). The second build is warning-free.
- **Files modified:** `android/app/build.gradle.kts`
- **Verification:** `flutter build apk --debug` completes in ~6s on incremental rebuild with zero warnings.
- **Committed in:** `5c221cc`

**5. [Rule 3 - Blocking] Plan referred to `android/app/build.gradle` but Flutter 3.41 scaffold generates `build.gradle.kts`**
- **Found during:** Task 1 (post-scaffold inspection)
- **Issue:** Plan's `verify` blocks check `grep -q 'applicationId "traevy.traevy"' android/app/build.gradle`. Flutter 3.41 scaffolds Kotlin DSL (`build.gradle.kts`) by default. The Groovy DSL file does not exist.
- **Fix:** Operated on `build.gradle.kts` throughout. The file's contents (Kotlin DSL syntax) are functionally equivalent: `applicationId = "traevy.traevy"` instead of `applicationId "traevy.traevy"`. Plan's intent fully achieved.
- **Files modified:** `android/app/build.gradle.kts`
- **Verification:** Build succeeds; applicationId is correct.
- **Committed in:** `854e850` (Task 1) and `5c221cc` (Task 3)

---

**Total deviations:** 5 auto-fixed (3 Rule 3 blocking, 2 Rule 1 bug)
**Impact on plan:** All deviations are corrections to outdated assumptions in the plan/research; the plan's stated intent is fully achieved (scaffold + dependencies + buildable APK with minSdk/targetSdk 34). The single material change is the deferral of `riverpod_generator` + `custom_lint` + `riverpod_lint`, which has no runtime impact and which plan 02+ should revisit when the analyzer ^10 ecosystem stabilizes.

## Issues Encountered

- The flutter create scaffold's `lib/main.dart` triggers 6 info-level lints under `very_good_analysis` (missing public_member_api_docs, parameter ordering, etc.). These are NOT errors and are scoped to files plan 02 will replace wholesale. Out of scope per the plan's explicit "we leave the rest of the default counter scaffold intact" note.
- `pubspec.yaml` triggers an info-level `sort_pub_dependencies` lint because `flutter pub add` appends new entries instead of sorting. Plan 02 will sort `pubspec.yaml` when it adds CONFIG-level entries. Out of scope here.
- `test/widget_test.dart` references the default counter UI. After plan 02 replaces `main.dart`, this test will need to be updated or removed. Documented for plan 02's awareness.

## Threat Surface (from plan threat_model)

The plan's threat register targeted T-01-01 (transitive dependency tampering) as `mitigate`. Mitigation applied:
- Caret-range pinning on all direct dependencies. ✅
- `pubspec.lock` committed to git. ✅
- Verified absence of unexpected/suspicious transitive packages by inspecting `flutter pub deps`. The only "+eol" entries are the documented `sqlite3_flutter_libs` and `sqlcipher_flutter_libs` chains via `drift_flutter`; both are maintenance-mode published packages, not malicious.

T-01-02, T-01-03, T-01-04 were `accept` dispositions in the plan; no action required.

No new threat flags introduced — this plan adds no network endpoints, auth surface, file access, or schema changes.

## User Setup Required

None — no external service configuration required for this plan.

## Next Phase Readiness

**Ready for plan 01-02 (config + theme):**
- Stable `pubspec.yaml` with all needed runtime dependencies installed at known versions.
- `lib/` is empty except for the default counter scaffold; plan 02 can replace `lib/main.dart` and add `lib/config/` cleanly.
- `analysis_options.yaml` is wired to `very_good_analysis` (plan 02 may further customize rules).
- `flutter analyze` and `flutter build apk --debug` both green.

**Ready for plan 01-03 (Drift database scaffolding):**
- `drift 2.32.1` and `drift_flutter 0.3.0` installed and resolved.
- `drift_dev 2.32.1` + `build_runner 2.13.1` available for `dart run build_runner build`.
- Can reference real versions (not caret ranges) when generating Drift schemas.

**Open follow-ups for later plans (NOT blockers for plan 02/03/04):**
- When the Riverpod / `custom_lint` ecosystem aligns on analyzer ^10, install `riverpod_generator`, `custom_lint`, `riverpod_lint` and migrate to `@riverpod`-annotated providers.
- After plan 02 replaces `lib/main.dart`, update or remove `test/widget_test.dart` so it stops referring to the default counter UI.
- After plan 02 sorts dependencies in `pubspec.yaml`, the `sort_pub_dependencies` lint will clear.

## Self-Check: PASSED

**Files verified present:**
- `pubspec.yaml`, `pubspec.lock`
- `lib/main.dart`
- `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- `analysis_options.yaml`, `.gitignore`, `README.md`, `test/widget_test.dart`
- `.planning/phases/01-foundation/01-01-SUMMARY.md`
- `build/app/outputs/flutter-apk/app-debug.apk` (~149 MB debug APK)

**Commits verified in git log:**
- `854e850` Task 1 — scaffold
- `cf9b45e` Task 2 — dependencies
- `5c221cc` Task 3 — Android Gradle SDK pinning

---
*Phase: 01-foundation*
*Plan: 01*
*Completed: 2026-04-12*
