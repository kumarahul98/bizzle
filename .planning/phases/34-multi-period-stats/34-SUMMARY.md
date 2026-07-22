---
phase: 34-multi-period-stats
completed: 2026-07-22
status: code_complete_device_unverified
mode: manual-gsd
requirements: [STATS-03]
branch: main
commits:
  - 7297200 (Wave 2 · 34-02 aggregation layer)
  - 4dd1a07 (Wave 3 · 34-03 selector + period-aware cards)
result: >
  Waves 2 and 3 built on main against the ratified RnD (Wave 1 gate was already
  accepted). The Stats screen now selects a calendar period (week / month /
  year); the per-commuting-day average is labelled so its denominator cannot be
  misread; the trend chart re-buckets per period (Q6 overrule). No schema
  change. Flutter 945 passed, 10 skipped (baseline 925/10, +20). analyze
  0 errors / 0 warnings, dart format clean, debug APK built. Not
  device-verified (no manual period-switch on real trip history).
---

# Phase 34 — Multi-Period Stats — SUMMARY

## What shipped

| Wave | Commit | Content |
|---|---|---|
| 2 (34-02) | `7297200` | sealed `StatsPeriod` (week/month/year); `selectedStatsPeriodProvider`; `computeStatsSummary` generalised to per-period total/stuck/share/avg/commuting-days + `periodTrendBars`, with the standalone week accumulators PRESERVED for the dashboard; stuck-share population fix; `monthTotalSeconds` → `periodTotalSeconds`; two dead constants deleted; shared formatters. 18 tests |
| 3 (34-03) | `4dd1a07` | `StatsPeriodSelector` (3-segment); period-aware `TrafficLossHero` + `DonutCard` (per-commuting-day lines, `· so far` marker, stuck-share %) + re-bucketed `TrendBarsCard`; subtitle replaced (mislabelled "N trips" deleted); `WeekdayChartCard` title `· all time`; fixed-window divider + `All time` section. Net +2 tests |

**Verification:** `flutter analyze` **0 errors / 0 warnings** (297 pre-existing
info lints, none net-new) · `flutter test` **945 passed, 10 skipped** (baseline
on `main` before this phase was **925 passed, 10 skipped**, +20) ·
`dart format lib test` clean · `flutter build apk --debug` succeeds.

## The ratified decisions, as built

All six D-01 answers plus D-02/D-03 and the stuck-share fix were built to the
"Review outcome (ratified 2026-07-22)" table.

1. **Calendar periods** — Mon–Sun / 1st-to-last / Jan–Dec, half-open, reusing
   the existing anchor math. Week boundary bytes unchanged.
2. **Daily average = total ÷ commuting days**, commuting day = a distinct
   `startTime.toLocal()` date with ≥1 trip, built as a `Set<DateTime>` in the
   single pass (no day arithmetic, DST-immune). Labels are exact:
   `1h 30m per commuting day`, `5 commuting days` / `1 commuting day`,
   `— per commuting day` over `No commuting days`,
   subtitle `This week · 5 commuting days`. `per day` / `daily average` appear
   nowhere. `kStatsEmptyPlaceholder` now has its first caller
   (`formatPerCommutingDay`).
3. **Metrics**: total, stuck, stuck share %, per-commuting-day average,
   commuting-day count. No distance, no trip count. The mislabelled
   `stats_screen.dart` "N trips" line (it counted non-zero days) is deleted and
   replaced by the `{period} · {n} commuting days` subtitle.
4. **Partial periods**: `· so far` marker on the DonutCard title, never
   extrapolated. (See Surprises for what "suppress the totals delta" met in the
   code.)
5. **Aggregation**: extended `computeStatsSummary` in-memory. No SQL GROUP BY,
   no memoisation.
6. **Stuck-share population fix**: numerator (`periodStuckSeconds`) and
   denominator (`periodNonBlankTotalSeconds`) are both over the
   non-blank-manual population; the headline total stays all-trips. A test pins
   that a blank hand entry moves the headline total but not the share.

**D-02**: `monthTotalSeconds` renamed to `periodTotalSeconds` and RENDERED as
the DonutCard centre for every period. `kStatsCardMonthLabel` and
`kStatsTrendWeekCount` deleted (confirmed self-referential only).

**D-03**: held. The dashboard reads `weekTotalSeconds` / `weekStuckSeconds`,
which are computed in their own block ALWAYS for the current week, independent
of the selected period. Test T-34-02 asserts they do not move when the stats
period is Month, and that the Week-period totals equal them.

## As-built decision — the Q6 overrule

The RnD recommended leaving `TrendBarsCard` at 28 days; the user overruled it.
`TrendBarsCard` is now period-aware and follows `selectedStatsPeriodProvider`,
bucketed in the service (`periodTrendBars`), each bucketing with its own axis
semantics:

- **Week** → 7 daily bars, labelled `Mon…Sun` (`DateFormat('EEE')`).
- **Month** → one bar per calendar week touching the month (~4–5), labelled
  `W1…Wn`.
- **Year** → 12 monthly bars, labelled `Jan…Dec` (`DateFormat('MMM')`).

Highlight logic was reconsidered rather than transferred: the bucket containing
today is the accent bar (carried on each `StatsTrendBar.isCurrent`, so the card
does not re-derive `now`); the tallest non-zero bucket is the stuck/worst bar;
empty buckets render at zero height. The card title names the bucketing
(`Daily trend` / `Weekly trend` / `Monthly trend`). Bar width widens for fewer
bars. `WeekdayChartCard` stays all-time — NOT overruled — and its title now
states so.

## Reporting items — the plan vs the code

Per the batch standard, the RnD had a factual slip against real code:

**1. The RnD's worked-example TOTAL strings do not match the shipped
formatter.** §2 says the printed figures "follow the existing integer-minute
formatter (`donut_card.dart:90-96`), so [they] are what the app would actually
show", then prints totals as `6h 00m`, `18h 00m`, `33h 00m`. That formatter
DROPS a zero-minute tail — it returns `6h`, `18h`, `33h`. So of the four
examples' incidental total annotations only A's `7h 30m` matches; the rest are
`6h`/`18h`/`33h` in the app. **The AVERAGE strings — the ones the phase is
actually about — all match verbatim**: every example renders
`1h 30m per commuting day`, and the count strings (`5` / `4` / `12` / `22` /
`1` commuting day(s), `No commuting days`) match. Tests assert the real
formatter output (`6h`, not `6h 00m`); no formatter change was made.

**2. `isPeriodPartial` is always true for the shown period.** The spec's
"complete when `now >= end anchor`" branch is unreachable: the period is always
the CURRENT one, anchored to `now`, so `now < periodEnd` always holds and the
`· so far` marker always renders. The check is implemented honestly (and works
if a past period is ever shown), but there is no navigation to past periods, so
in practice the marker is permanent. This is correct behaviour, not a bug — the
current period genuinely is in progress — but it means the "complete period
drops the marker" case only exists in the unit test's imagination.

**3. Decision 4's "suppress the totals period-over-period delta while
incomplete" had nothing to suppress.** There is no period-over-period delta
anywhere in the code — `TrafficLossHero` already omits a "vs last week" row
because `StatsSummary` carries no prior-period figure, and this phase added
none. Building a delta only to suppress it would have been unplanned scope and
dead code. The shipped deliverable of decision 4 is the `· so far` marker;
the delta-suppression clause is moot against the current UI.

**4. Donut centre can exceed the wedge sum (by design).** The centre total is
all-trips; the wedges + stuck-share are the matched non-blank-manual
population. When a user has blank hand entries, the centre reads higher than
`moving + stuck`. This is the ratified tradeoff ("headline total stays
all-trips, share over non-blank") made visible; in the common case (no blank
manuals) the two populations coincide and nothing looks odd.

## Test coverage added

- Four Q2 worked examples verbatim, incl. rendered strings and the T-34-01
  stability property (A vs B, holiday-June vs full-June award zero average
  improvement).
- Period labels (`This week` / `July` / `2026`), partial marker, empty period
  (null average → em-dash, `No commuting days`), DST/date-only bucketing,
  23:50↔00:10 two-day split.
- T-34-02 dashboard/stats week agreement.
- Stuck-share population fix (blank hand entry moves total, not share; null
  share when the non-blank population is empty).
- Trend bucketing counts at service level (7 / 5 / 12) and widget level
  (BarChart bar-group count per period), selector switches all period-aware
  cards together, `· so far` marker on screen.

## What is NOT done

**Device verification.** SC "switch periods on a device holding real trip
history and sanity-check the yearly figure against a hand tally" is unmet — no
device run. All evidence is synthetic. Add to the Phase 23 device queue.

**Performance measurement on device.** The RnD's Q5 measurement (0.41 ms at a
year of data, desktop VM) stands; this phase did not re-measure on hardware.
The provider still recomputes on every trips-table write (unchanged, and
un-memoisable because it reads `DateTime.now()`), as the RnD accepted.

## Follow-ups

1. Device-verify the yearly view against a hand tally of a known month.
2. If past-period navigation is ever added, the `isPeriodPartial` complete
   branch and a genuine period-over-period delta both become live — the marker
   logic and decision-4 delta-suppression are already specified for it.
3. The RnD flagged a separate, out-of-scope win: `watchAllSummaries()` reads the
   6 KB polyline column and discards it (−29 % to −56 % of the query cost).
   Narrowing that projection is the cheapest available stats-path improvement;
   it touches the history data path and deserves its own change.
