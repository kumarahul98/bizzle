---
phase: quick-260801-oux
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/config/constants.dart
  - lib/shared/utils/formatters.dart
  - lib/shared/widgets/stuck_bar.dart
  - lib/shared/widgets/trip_row_info.dart
  - lib/shared/widgets/trip_row_card.dart
  - lib/features/dashboard/widgets/week_loss_card.dart
  - lib/features/trips/widgets/trip_traffic_section.dart
  - lib/features/trips/screens/trip_detail_screen.dart
  - test/unit/shared/utils/formatters_test.dart
  - test/widget/shared/widgets/stuck_bar_test.dart
  - test/widget/shared/widgets/trip_row_card_test.dart
  - test/widget/features/trips/estimated_hint_test.dart
  - test/widget/features/trips/trip_traffic_section_test.dart
  - test/widget/features/trips/trip_detail_screen_test.dart
autonomous: true
requirements: [QUICK-260801-OUX]
user_setup: []

must_haves:
  truths:
    - "Editing a GPS trip so its stuck time changes by seconds produces a visibly different stuck figure on the trip detail screen — a non-zero stuck under one minute renders '<1m', never '0m'."
    - "The StuckBar's amber segment is present (non-zero flex) whenever stuck seconds are non-zero, including sub-minute values, and its proportions are exact to the second."
    - "The history-list row and the trip detail screen agree: both derive their stuck label from seconds via the same formatter."
    - "A GPS trip with timeMovingSeconds == 0 AND timeStuckSeconds == 0 shows an honest 'no traffic data' notice with an explainer sheet, instead of an empty grey bar plus '0m moving / 0m stuck'."
    - "No traffic numbers are fabricated for the 0/0 case — rescaleTraffic's D-02 rule is untouched."
    - "dart format ., flutter analyze (zero issues), and the full flutter test suite all pass."
  artifacts:
    - path: "lib/shared/utils/formatters.dart"
      provides: "formatTrafficDuration(int seconds) — seconds-precision moving/stuck label with honest sub-minute rendering"
      contains: "String formatTrafficDuration"
    - path: "lib/shared/widgets/stuck_bar.dart"
      provides: "StuckBar keyed on movingSeconds/stuckSeconds"
      contains: "required this.stuckSeconds"
    - path: "lib/features/trips/widgets/trip_traffic_section.dart"
      provides: "TripTrafficSection — StuckBar + legend, or the 0/0 no-traffic-data notice"
      contains: "class TripTrafficSection"
    - path: "lib/config/constants.dart"
      provides: "kSubMinuteDurationLabel, kNoTrafficDataLabel, kNoTrafficDataInfoTitle, kNoTrafficDataInfoBody"
      contains: "kNoTrafficDataLabel"
    - path: "test/widget/features/trips/trip_traffic_section_test.dart"
      provides: "Widget coverage for the sub-minute label and the 0/0 no-data state"
  key_links:
    - from: "lib/features/trips/screens/trip_detail_screen.dart"
      to: "lib/features/trips/widgets/trip_traffic_section.dart"
      via: "TripTrafficSection(movingSeconds: trip.timeMovingSeconds, stuckSeconds: trip.timeStuckSeconds)"
      pattern: "TripTrafficSection\\("
    - from: "lib/features/trips/widgets/trip_traffic_section.dart"
      to: "lib/shared/widgets/stuck_bar.dart"
      via: "StuckBar(movingSeconds:, stuckSeconds:)"
      pattern: "StuckBar\\(\\s*movingSeconds"
    - from: "lib/shared/widgets/trip_row_card.dart"
      to: "lib/shared/widgets/trip_row_info.dart"
      via: "TripRowInfo(stuckSeconds: stuckSeconds) — no ~/ 60 floor"
      pattern: "stuckSeconds: stuckSeconds"
    - from: "lib/shared/widgets/trip_row_info.dart"
      to: "lib/shared/utils/formatters.dart"
      via: "formatTrafficDuration(stuckSeconds)"
      pattern: "formatTrafficDuration"
---

<objective>
Fix the render-path bugs that make an edited GPS trip's "time stuck in traffic"
look unchanged, and replace the permanent 0/0 dead-end with an honest state.

The write path is already correct and test-covered (`TripManagementNotifier.editTrip`
persists the new `timeStuckSeconds`; `TripEditRecompute.rescaleTraffic` computes it
correctly). The user sees "nothing changed" because **every consumer floors seconds
to whole minutes** before rendering, and because a GPS trip that lands at 0/0 can
never move off zero.

Purpose: an edit that changes stuck time must be visible; a trip with no usable
traffic data must say so instead of showing a bar that looks broken.
Output: a seconds-precision render path (formatter + StuckBar + history row), and a
`TripTrafficSection` widget that surfaces the 0/0 case as "no traffic data" with an
explainer sheet.
</objective>

<execution_context>
@/Users/coolman/Documents/Projects/bizzle/.claude/get-shit-done/workflows/execute-plan.md
@/Users/coolman/Documents/Projects/bizzle/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md

Project skills that apply (read before writing code):
@.agents/skills/flutter-coding-guidelines/SKILL.md
@.agents/skills/flutter-add-widget-test/SKILL.md

Source files:
@lib/config/constants.dart
@lib/shared/utils/formatters.dart
@lib/shared/widgets/stuck_bar.dart
@lib/shared/widgets/trip_row_info.dart
@lib/shared/widgets/trip_row_card.dart
@lib/features/dashboard/widgets/week_loss_card.dart
@lib/features/trips/screens/trip_detail_screen.dart
@lib/features/trips/widgets/traffic_insight_card.dart
@lib/features/trips/widgets/estimated_hint.dart
@lib/shared/widgets/info_sheet.dart

<interfaces>
<!-- Contracts the executor needs. Do not go exploring — these are current as of planning. -->

Existing formatters (lib/shared/utils/formatters.dart) — NONE of these fit the
moving/stuck legend, which is why a new one is added:
```dart
String formatDuration(int seconds);   // 'N min' / 'Nh NNmin'  — stat cards
String formatDistance(double meters); // '12.4 km'
String formatElapsed(int seconds);    // 'MM:SS' / 'H:MM:SS'   — live tracking
String formatStuck(int seconds);      // '4m' / '1h2m'         — notification + Live Activity.
                                      // PINNED by tests: formatStuck(59) == '0m'. DO NOT CHANGE IT.
```

Current StuckBar contract (to be changed to seconds):
```dart
const StuckBar({required int movingMinutes, required int stuckMinutes, double height = 14});
```
Call sites of `StuckBar(` in lib/ — this is the complete list, verified by grep:
- lib/features/trips/screens/trip_detail_screen.dart:348
- lib/features/dashboard/widgets/week_loss_card.dart:98
(`_DonutChart` in lib/features/stats/widgets/donut_card.dart also has
`movingMinutes`/`stuckMinutes` params but it is a DIFFERENT private widget on the
aggregate Stats screen — OUT OF SCOPE, do not touch it.)

Current TripRowInfo contract (to be changed to seconds):
```dart
const TripRowInfo({
  required String displayName, required String durationLabel,
  required String timeRange, required int stuckMins, bool isEdited = false,
});
```

Shared explainer widget already in the codebase (lib/shared/widgets/info_sheet.dart):
```dart
const InfoIconButton({required String title, required String body});
```
Precedent for honest explanation copy: `kStuckInfoTitle` / `kStuckInfoBody`
(lib/config/constants.dart:1514-1522).

TripRow fields used here: `timeMovingSeconds` (int), `timeStuckSeconds` (int),
`durationSeconds` (int), `isEdited` (bool), `isManualEntry` (bool).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add formatTrafficDuration + the new user-facing constants</name>
  <files>lib/config/constants.dart, lib/shared/utils/formatters.dart, test/unit/shared/utils/formatters_test.dart</files>
  <behavior>
    formatTrafficDuration (new, in formatters.dart):
    - formatTrafficDuration(0) == '0m'
    - formatTrafficDuration(1) == kSubMinuteDurationLabel  ('<1m')
    - formatTrafficDuration(59) == kSubMinuteDurationLabel
    - formatTrafficDuration(60) == '1m'
    - formatTrafficDuration(3599) == '59m'
    - formatTrafficDuration(3600) == '1h'
    - formatTrafficDuration(3660) == '1h 1m'
    - Regression guard for the reported bug: formatTrafficDuration(30) != formatTrafficDuration(0)
    - Distinctness guard: formatTrafficDuration(59) != formatStuck(59)  (formatStuck stays '0m')
  </behavior>
  <action>
Append to `lib/config/constants.dart` (new section header comment in the file's
existing style, e.g. `// Quick 260801-oux — sub-minute traffic display`). Follow the
existing `k`-prefixed naming and write a dartdoc for each:

- `kSubMinuteDurationLabel = '<1m'` — label for a non-zero traffic duration shorter
  than one minute. Document WHY: flooring to whole minutes rendered a real,
  edited-down stuck value as '0m', which reads as "the edit did nothing".
- `kNoTrafficDataLabel = 'No traffic data for this trip'` — replaces the StuckBar +
  legend on a GPS trip whose moving and stuck seconds are both zero.
- `kNoTrafficDataInfoTitle = 'Why is there no traffic data?'`
- `kNoTrafficDataInfoBody` — jargon-free explainer matching `kStuckInfoBody`'s tone
  (no "sample", no "m/s", no "threshold"). It must say three things plainly:
  (1) Traevy works out moving vs stuck time from your speed while recording, and on
  this trip the gaps between location updates were too long to tell the two apart —
  usually a weak signal or an interrupted recording; (2) the trip's duration and
  route are still correct; (3) editing the trip will not bring the split back,
  because there is nothing to rescale — Traevy will not invent numbers it did not
  measure. Point (3) is the honest statement of the D-02 rule.

Add `formatTrafficDuration(int seconds)` to `lib/shared/utils/formatters.dart`
(import `package:traevy/config/constants.dart` — constants.dart is a leaf file with
no imports, so there is no cycle). Signature and rules:

  - `seconds <= 0` → `'0m'`
  - `seconds < 60`  → `kSubMinuteDurationLabel`
  - `seconds < 3600` → `'${seconds ~/ 60}m'`
  - otherwise → `'${h}h'` when the minute remainder is 0, else `'${h}h ${m}m'`
    (space-separated, matching the `_formatMinutes` output it replaces on the trip
    detail legend).

Dartdoc must state that this is the moving/stuck legend formatter for FINALIZED
trips, that it is deliberately distinct from `formatStuck` (compact, live-tracking
surfaces, pinned to '0m' under a minute), and why sub-minute values are surfaced
rather than floored.

Do NOT modify `formatStuck`, `formatDuration`, or `formatElapsed` — they have pinned
tests and different consumers (the tracking notification and Live Activity).

Add a `group('formatTrafficDuration', ...)` to
`test/unit/shared/utils/formatters_test.dart` covering every case in `<behavior>`,
following that file's existing per-case `test(...)` + explanatory-comment style.
  </action>
  <verify>
    <automated>flutter test test/unit/shared/utils/formatters_test.dart</automated>
  </verify>
  <done>formatTrafficDuration exists with the four new constants; all cases in `<behavior>` pass; formatStuck's existing pinned tests still pass.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Drive StuckBar and the history row off seconds (root cause 1)</name>
  <files>lib/shared/widgets/stuck_bar.dart, lib/shared/widgets/trip_row_info.dart, lib/shared/widgets/trip_row_card.dart, lib/features/dashboard/widgets/week_loss_card.dart, test/widget/shared/widgets/stuck_bar_test.dart, test/widget/shared/widgets/trip_row_card_test.dart, test/widget/features/trips/estimated_hint_test.dart</files>
  <behavior>
    StuckBar:
    - movingSeconds: 0, stuckSeconds: 0 → renders the full-width surface2 track, no Row of segments (unchanged behaviour).
    - movingSeconds: 3540, stuckSeconds: 30 → renders two Expanded children whose
      flex values are exactly 3540 and 30. The amber segment's flex is NON-ZERO —
      this is the bug: with minutes it was flex 0 and the segment vanished.
    - Negative input (defensive) is treated as 0 — Expanded asserts flex >= 0.
    TripRowInfo:
    - stuckSeconds: 30 → renders '<1m stuck' (previously nothing at all, since
      30 ~/ 60 == 0 failed the `> 0` gate).
    - stuckSeconds: 0 → renders no stuck figure (unchanged).
    - stuckSeconds: 300 → renders '5m stuck'.
    TripRowCard:
    - stuckSeconds: 30 → the row shows '<1m stuck'.
  </behavior>
  <action>
**StuckBar (lib/shared/widgets/stuck_bar.dart):** rename the two required params
`movingMinutes`/`stuckMinutes` → `movingSeconds`/`stuckSeconds` and use them
directly as the `Expanded(flex:)` weights. Clamp each to `>= 0` locally before use
(`final moving = movingSeconds < 0 ? 0 : movingSeconds;` and likewise for stuck) —
`Expanded.flex` asserts non-negative and the week-card call site derives moving by
subtraction. Keep the `total == 0` grey-track branch, the `height` param, and the
ClipRRect/ColoredBox structure exactly as they are.

Update the class dartdoc: segments are sized by SECONDS so the proportions are exact
and a sub-minute stuck stretch still paints a visible sliver. State explicitly that
there is deliberately NO minimum-width floor on a segment — fudging the width would
misreport the proportion, which is the one thing this bar exists to show honestly.

**Call sites (both, verified complete by grep — re-run `grep -rn "StuckBar(" lib/`
after editing to confirm none remain on the old API):**
- `lib/features/dashboard/widgets/week_loss_card.dart:98` — pass
  `movingSeconds: stats.weekTotalSeconds - stats.weekStuckSeconds` and
  `stuckSeconds: stats.weekStuckSeconds`. Leave that card's `_formatHm` /
  `_formatStuckHm` labels and its `stuckMins`/`totalMins`/`movingMins` locals
  untouched — its aggregate week copy is out of scope; only the bar's inputs change.
- `lib/features/trips/screens/trip_detail_screen.dart:348` — for THIS task, do the
  minimal change: pass `movingSeconds: trip.timeMovingSeconds` and
  `stuckSeconds: trip.timeStuckSeconds` so the tree compiles. Task 3 replaces this
  whole block with `TripTrafficSection`.

**TripRowInfo (lib/shared/widgets/trip_row_info.dart):** rename the `stuckMins`
field → `stuckSeconds`, gate on `stuckSeconds > 0`, and render
`'${formatTrafficDuration(stuckSeconds)} stuck'` (import
`package:traevy/shared/utils/formatters.dart`). Update the field dartdoc.

**TripRowCard (lib/shared/widgets/trip_row_card.dart:90):** pass
`stuckSeconds: stuckSeconds` — delete the `~/ 60`. Leave `_dur` and `_dist` alone
(`_dur` formats trip DURATION, a different figure with no sub-minute problem).

**Tests:** update `test/widget/shared/widgets/stuck_bar_test.dart` to the seconds
API (convert the existing 30/10 and 20/5 minute cases to 1800/600 and 1200/300 so
they keep asserting the same proportions), and ADD the sub-minute case from
`<behavior>` — read the flex values with
`tester.widgetList<Expanded>(find.byType(Expanded))` and assert `[3540, 30]`, since
`findsAtLeastNWidgets(2)` alone would not have caught this bug. Update
`test/widget/features/trips/estimated_hint_test.dart` (`stuckMins: 5` →
`stuckSeconds: 300`, both occurrences). Add a `stuckSeconds: 30` case to
`test/widget/shared/widgets/trip_row_card_test.dart` asserting
`find.text('<1m stuck')`.
  </action>
  <verify>
    <automated>flutter analyze && flutter test test/widget/shared/widgets/stuck_bar_test.dart test/widget/shared/widgets/trip_row_card_test.dart test/widget/features/trips/estimated_hint_test.dart</automated>
  </verify>
  <done>`grep -rn "movingMinutes\|stuckMins" lib/shared lib/features/trips lib/features/dashboard` returns nothing; StuckBar flex weights are seconds; a 30-second stuck value renders '<1m stuck' in the history row; flutter analyze reports zero issues.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: TripTrafficSection — seconds legend + the 0/0 no-traffic-data state (root cause 2)</name>
  <files>lib/features/trips/widgets/trip_traffic_section.dart, lib/features/trips/screens/trip_detail_screen.dart, test/widget/features/trips/trip_traffic_section_test.dart, test/widget/features/trips/trip_detail_screen_test.dart</files>
  <behavior>
    TripTrafficSection:
    - movingSeconds: 2400, stuckSeconds: 300 → renders a StuckBar, '40m moving',
      '5m stuck', and the existing stuck InfoIconButton.
    - movingSeconds: 3540, stuckSeconds: 30 → renders '<1m stuck', NOT '0m stuck'.
    - movingSeconds: 0, stuckSeconds: 0 → renders kNoTrafficDataLabel, NO StuckBar,
      no moving/stuck legend; tapping its info icon opens a sheet containing
      kNoTrafficDataInfoTitle.
    - isEdited: true with non-zero traffic → EstimatedHint is shown.
    - isEdited: true with 0/0 → EstimatedHint is NOT shown (nothing was estimated).
    TripDetailScreen:
    - A GPS trip with timeMovingSeconds 0 and timeStuckSeconds 0 shows
      kNoTrafficDataLabel, and neither StuckBar nor TrafficInsightCard.
    - The existing 2400/300 GPS fixture still renders StuckBar + TrafficInsightCard
      + TripTimeline (no regression).
  </behavior>
  <action>
**Create `lib/features/trips/widgets/trip_traffic_section.dart`** with a public
`TripTrafficSection extends StatelessWidget` taking
`{required int movingSeconds, required int stuckSeconds, bool isEdited = false}`.

Move the trip-detail traffic block into it verbatim in structure:
`StuckBar` → `SizedBox(height: 8)` → the legend `Row` (moving dot + label, Spacer,
stuck dot + label, `InfoIconButton(title: kStuckInfoTitle, body: kStuckInfoBody)`,
and the `EstimatedHint(size: 12)` when `isEdited`). Move `_LegendDot` and the
`_kLegendDotSize` constant out of `trip_detail_screen.dart` into this file as
private members — the legend is their only consumer, and leaving copies behind
would be dead code.

Both labels come from `formatTrafficDuration(...)`, never `~/ 60`:
`'${formatTrafficDuration(movingSeconds)} moving'` and
`'${formatTrafficDuration(stuckSeconds)} stuck'`.

Add the no-data branch as the FIRST thing in `build`:
```
if (movingSeconds + stuckSeconds == 0) → the no-traffic-data notice
```
The notice is a single `Row`: an `Expanded` `Text(kNoTrafficDataLabel)` in
`TraevyFonts.mono(size: 12, color: tokens.textDim)`, followed by
`InfoIconButton(title: kNoTrafficDataInfoTitle, body: kNoTrafficDataInfoBody)`.
No StuckBar, no legend, no EstimatedHint — a 0/0 trip has nothing estimated, and an
"~ estimated" marker next to "no traffic data" would be noise.

Class dartdoc must record WHY the branch exists: a GPS trip can legitimately finish
0/0 (`TripAccumulator` attributes nothing when every sample gap exceeds
`kTrackingMaxAttributableGapSeconds`, and a restored pre-Phase-31 snapshot marks its
whole prefix unattributed). `TripEditRecompute.rescaleTraffic` deliberately returns
(0, 0) for a 0/0 input (D-02 — never invent a ratio), so no edit can ever move such a
trip off zero. Rendering an empty grey bar plus "0m moving / 0m stuck" made that look
like a broken edit. This branch does NOT change any math — it only stops the UI from
implying a number exists.

Keep the widget under 100 lines per CLAUDE.md; if it grows past that, extract the
legend `Row` into a private `_TrafficLegend` widget in the SAME file.

**Wire it into `lib/features/trips/screens/trip_detail_screen.dart`:**
- Delete the `movingMinutes` / `stuckMinutes` locals at lines 236-237 and the
  `movingLabel` / `stuckLabel` locals at 240-241.
- Delete the now-unused private `_formatMinutes` method (lines 444-449) and the
  `_LegendDot` class + `_kLegendDotSize` constant (moved to the new file). No dead
  code left behind.
- Replace the `StuckBar` + legend `Row` block (lines 348-387) with:
  `TripTrafficSection(movingSeconds: trip.timeMovingSeconds, stuckSeconds: trip.timeStuckSeconds, isEdited: trip.isEdited)`.
- Keep the `TrafficInsightCard` exactly as it behaves today: compute
  `final insightStuckMinutes = trip.timeStuckSeconds ~/ 60;` and keep the
  `if (insightStuckMinutes > 0)` gate, passing
  `stuckMinutes: insightStuckMinutes, totalMinutes: totalMinutes`. That card's copy
  is literally "You lost N minutes stuck in traffic" — surfacing it at 30 seconds
  would print "You lost 0 minutes". `TrafficInsightCard` is OUT OF SCOPE; do not
  change its API or copy.
- Fix the imports: drop `stuck_bar.dart` from this screen, add
  `trip_traffic_section.dart`. Leave `formatters.dart` imported (still used by
  `decodedToLatLng` / `formatDuration` / `formatDistance`).

**Tests:** create `test/widget/features/trips/trip_traffic_section_test.dart`
covering every `TripTrafficSection` case in `<behavior>` (follow
`estimated_hint_test.dart`'s `host(...)` helper pattern with `buildLightTheme()`;
pump a tap on the info icon and `pumpAndSettle` to assert the sheet title).

In `test/widget/features/trips/trip_detail_screen_test.dart`, add an
`insertZeroTrafficGpsTrip()` fixture (clone `insertGpsTrip` with
`timeMovingSeconds: 0, timeStuckSeconds: 0`) and a test asserting
`find.text(kNoTrafficDataLabel)` findsOneWidget, `find.byType(StuckBar)` findsNothing
and `find.byType(TrafficInsightCard)` findsNothing. Leave the existing 2400/300 GPS
tests untouched — they are the no-regression guard.
  </action>
  <verify>
    <automated>flutter analyze && flutter test test/widget/features/trips/trip_traffic_section_test.dart test/widget/features/trips/trip_detail_screen_test.dart</automated>
  </verify>
  <done>A 0/0 GPS trip shows the no-traffic-data notice with a working explainer sheet and no StuckBar; a 30-second stuck trip shows '<1m stuck'; the 2400/300 fixture's existing assertions still pass; flutter analyze reports zero issues and no dead `_formatMinutes` / `_LegendDot` remain in trip_detail_screen.dart.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | Pure render-path change. No new input crosses a boundary: no network call, no Drift write, no sync payload, no schema change. All values read are already-persisted trusted ints. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-OUX-01 | Information disclosure | `kNoTrafficDataInfoBody` explainer copy | mitigate | Copy is a fixed constant written at plan time — it must never interpolate an error, exception, file path, or any trip/user value. Matches the project's existing PII-free copy rule (`kDeleteAllDataErrorSnackbar`). |
| T-OUX-02 | Denial of service | `StuckBar` `Expanded(flex:)` | mitigate | `Expanded.flex` asserts non-negative; the week-card call site derives moving by subtraction, so StuckBar clamps both inputs to `>= 0` locally (Task 2) rather than trusting callers. |
| T-OUX-03 | Tampering | trip traffic values | accept | No write path is touched. `rescaleTraffic` and `editTrip` are unchanged; this plan only reads `timeMovingSeconds` / `timeStuckSeconds`. |
</threat_model>

<source_coverage_audit>
Sources for this quick task are the problem statement + `<scope>` (no ROADMAP /
REQUIREMENTS / CONTEXT artifact exists for quick tasks).

| Source item | Status | Covered by |
|-------------|--------|------------|
| SCOPE-1 stop flooring; render sub-minute honestly on detail legend + history row | COVERED | Task 1 (formatter), Task 2 (row), Task 3 (legend) |
| SCOPE-2 StuckBar takes seconds; ALL call sites updated | COVERED | Task 2 (stuck_bar.dart, week_loss_card.dart), Task 3 (trip_detail via TripTrafficSection) |
| SCOPE-3 TripRowInfo / trip_row_card stop flooring; row and detail consistent | COVERED | Task 2 — both now call the same `formatTrafficDuration` |
| SCOPE-4 0/0 surfaced as honest "no traffic data" using the InfoIconButton precedent | COVERED | Task 1 (constants), Task 3 (TripTrafficSection branch) |
| CONSTRAINT strings in constants.dart, `k`-prefixed | COVERED | Task 1 |
| CONSTRAINT shared formatter in formatters.dart, not speculative | COVERED | Task 1 — 3 real call sites (2 legend labels + history row); existing formatters checked and none fit |
| CONSTRAINT unit tests for sub-minute formatting | COVERED | Task 1 (`test/unit/shared/utils/formatters_test.dart`) |
| CONSTRAINT tests for the 0/0 no-traffic-data state | COVERED | Task 3 (`trip_traffic_section_test.dart` + `trip_detail_screen_test.dart`) |
| CONSTRAINT widget tests under test/widget/ | COVERED | Tasks 2 and 3 |
| OUT-OF-SCOPE no traffic field on EditTripSheet | RESPECTED | EditTripSheet is not in `files_modified` |
| OUT-OF-SCOPE rescaleTraffic ratio math / D-02 untouched | RESPECTED | `trip_edit_recompute.dart` is not in `files_modified` |
| OUT-OF-SCOPE write path / sync payload / Drift schema / backend untouched | RESPECTED | No provider, DAO, table, or backend file in `files_modified` |
| OUT-OF-SCOPE manual-entry behaviour | RESPECTED | Manual trips already skip the whole traffic block via the `isGps` gate; unchanged |

No unplanned items. No gaps.
</source_coverage_audit>

<verification>
Run from the repo root, in order:

```bash
dart format .
flutter analyze                 # must report zero issues
flutter test test/unit/shared/utils/formatters_test.dart
flutter test test/widget/shared/widgets/stuck_bar_test.dart \
             test/widget/shared/widgets/trip_row_card_test.dart \
             test/widget/features/trips/
flutter test                    # full suite — no regressions anywhere
```

Static checks (must all come back clean):

```bash
grep -rn "StuckBar(" lib/                 # only the 2 known call sites, both on the seconds API
grep -rn "stuckMins\|movingMinutes" lib/shared lib/features/trips lib/features/dashboard   # no hits
grep -rn "_formatMinutes\|_LegendDot" lib/features/trips/screens/trip_detail_screen.dart   # no hits
```

Note: `lib/features/stats/widgets/donut_card.dart` legitimately keeps
`movingMinutes`/`stuckMinutes` on its private `_DonutChart` — aggregate Stats screen,
out of scope. Do not "fix" it.
</verification>

<success_criteria>
- Editing a GPS trip so its stuck seconds change by less than a minute produces a
  different on-screen label ('<1m' vs '0m') and a differently-proportioned StuckBar.
- `StuckBar` segment flex values equal the raw seconds; a non-zero stuck value always
  yields a non-zero-width amber segment.
- The trip detail legend and the history row derive their stuck label from the same
  `formatTrafficDuration` call — no `~/ 60` remains on either path.
- A GPS trip at 0/0 renders `kNoTrafficDataLabel` plus a tappable explainer, and
  neither `StuckBar` nor `TrafficInsightCard`.
- `rescaleTraffic`, `editTrip`, the sync payload, the Drift schema, and the backend
  are byte-for-byte unchanged.
- `dart format .` clean, `flutter analyze` zero issues, full `flutter test` green.
</success_criteria>

<output>
After completion, create
`.planning/quick/260801-oux-fix-stuck-in-traffic-display-edges-for-i/260801-oux-SUMMARY.md`.

Commit with the project's prefix convention, one concern:
`[trips] Render stuck/moving from seconds; surface 0/0 GPS trips as no traffic data`
</output>
