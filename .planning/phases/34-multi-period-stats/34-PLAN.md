---
phase: 34-multi-period-stats
created: 2026-07-21
status: not_started
mode: manual-gsd
requirements: [STATS-03]
depends_on: [5, 31]
result: >
  NOT STARTED. Plan only. No schema change. Wave 1 is a REVIEW GATE — the RnD
  document must be read and accepted before Wave 2 begins. Independent of
  Phases 32/33/35/36; may run any time after Phase 31.
---

# Phase 34 — Multi-Period Stats (RnD First)

**Goal**: Stats answer "how is my commute trending?" across weeks, months and years,
with a daily average that is comparable between periods of different length.

**Depends on**: Phase 5 (the stats feature and `computeStatsSummary` this extends),
Phase 31 (only for the shared `InfoSheet`, if the RnD recommends explainers)

---

## D-01 — Wave 1 is a written RnD artifact and a hard review gate

This was requested as RnD, and it deserves to be. The decisions below are not
implementation details that can be settled while typing — several of them determine
whether the resulting numbers mean anything, and one (the daily-average denominator) can
make the headline figure move in the *opposite* direction from the user's actual
experience if chosen carelessly.

`34-RESEARCH.md` must answer each question below with a **recommendation**, not a survey.
No code is written until it is accepted.

**1. Period semantics — calendar or rolling?**
Calendar (Mon–Sun, 1st–end of month, Jan–Dec) matches the D-03/D-04 definitions already
implemented and shipping in `stats_service.dart`, so week figures stay consistent with the
dashboard card. Rolling windows (7/30/365 days) are more stable — a calendar month is not
comparable to the one before it when today is the 3rd. Recommend one and state what
breaks in the other.

**2. Daily average denominator — the decisive question.**
Dividing by **calendar days** buries a commuter's average under weekends and holidays: a
solid 90-minute weekday commute reports as ~64 minutes/day and drops further over
Christmas, implying an improvement that did not happen. Dividing by **days with at least
one trip** answers "what is a commuting day like", but then taking a week off *raises*
the average. Neither is wrong; they answer different questions.

Recommend one, name the on-screen label precisely enough that the user cannot
misread it (e.g. "per commuting day" is not optional decoration), and show worked
examples for: a normal 5-day week, a week with one day off, a 2-week holiday, and a
month containing a public holiday.

**3. Which metrics get the period treatment.** Total time, stuck time, distance, trip
count, stuck share (%). Recommend a subset — every metric added is another number the
user must interpret, and the app's stated core value is time lost to traffic, not a
dashboard of everything measurable.

**4. Partial periods.** The current week, month and year are incomplete. State whether a
partial period is labelled as such, extrapolated to a full-period estimate, or excluded
from period-over-period comparison. Extrapolation is tempting and usually a mistake —
say so explicitly if that is the recommendation.

**5. Aggregation strategy.** Today there is **no SQL aggregation anywhere**:
`watchAllSummaries()` is a plain `SELECT *` and `computeStatsSummary` does every bucket
in one O(n) Dart pass. Extending that is consistent and simple, but a yearly view means
a full-table pass on every stream rebuild. Introducing the first real `GROUP BY` in
`TripsDao` is faster and is what `tasks.md:44-49` originally specified, but it splits
stats logic across two languages and two test styles.

Include a **measured** estimate — count actual rows in the dev database and extrapolate
from real trip frequency, not a guess. The Phase 29 summary already records that
estimated baselines were a mistake once in this project.

**6. UI shape.** Segmented period selector versus tabs, and which of the four existing
cards (`TrafficLossHero`, `DonutCard`, `TrendBarsCard`, `WeekdayChartCard`) become
period-aware versus staying fixed-window. `TrendBarsCard` is hardcoded to 28 days and
`WeekdayChartCard` is inherently all-time — neither maps onto a year cleanly.

## D-02 — Whichever path is chosen, `monthTotalSeconds` finally renders

`StatsSummary.monthTotalSeconds` is computed today and displayed **nowhere**. The
constants `kStatsCardMonthLabel` and `kStatsTrendWeekCount` are likewise leftovers from
the pre-Phase-8 layout. This phase either renders the value or deletes it and its
constants — carrying a computed-but-unused field through another phase is how it becomes
permanent.

## D-03 — Existing week figures must not move

Whatever the RnD recommends, the "This week" number on the dashboard
(`week_loss_card.dart`) and the stats hero must continue to agree with each other and
with their current values for the same underlying trips. If the RnD recommends rolling
windows, the dashboard card either moves with it or is explicitly exempted — a dashboard
saying 3h and a stats screen saying 3h40m for "this week" is a bug report waiting to be
filed.

---

## Execution waves (conflict-safe)

**Wave 1 — RnD** *(review gate; stop here)*

- `34-01` — write `34-RESEARCH.md` answering D-01's six questions with recommendations,
  worked examples for the denominator, and a measured row-count estimate. **No code.**

**Wave 2 — aggregation** *(blocked on Wave 1 acceptance)*

- `34-02` — implement the accepted period model and daily average, with unit tests
  covering the worked examples from the RnD verbatim.

**Wave 3 — UI** *(blocked on Wave 2)*

- `34-03` — period selector and card updates, including the D-02 resolution of
  `monthTotalSeconds`.

---

## Threat model

| ID | Category | Asset | Decision | Mitigation |
|---|---|---|---|---|
| T-34-01 | Data integrity | A daily average that misleads — implying the commute improved when the user merely took leave | **mitigate — the core risk of this phase** | Denominator chosen deliberately in the RnD and named explicitly in the UI label (D-01 Q2). This directly attacks the app's stated core value, so it is a correctness issue, not a wording one. |
| T-34-02 | Data integrity | Dashboard and stats disagreeing on "this week" | mitigate | D-03 — both read the same computed field, with a test asserting agreement. |
| T-34-03 | Availability | Yearly aggregation over a full-table pass on every rebuild degrading the stats screen | mitigate | Strategy chosen against a measured row count (D-01 Q5); if in-memory is retained, the stats provider must not recompute on unrelated trip-stream emissions. |
| T-34-04 | Data integrity | Partial current period compared against complete prior periods | mitigate | D-01 Q4 states the rule; the UI labels partial periods. |
| T-34-05 | Denial of service | Year view on a device with several years of trips | accept | Bounded by real commute frequency (~500 trips/year); revisit only if the measured estimate in Q5 contradicts this. |

---

## Success criteria (what must be TRUE)

1. `34-RESEARCH.md` exists, answers all six D-01 questions with a recommendation each,
   and has been accepted before any code in this phase is written.
2. The stats screen offers weekly, monthly and yearly periods.
3. Each period shows a daily average whose label states its denominator unambiguously.
4. The worked examples from the RnD are encoded as unit tests and pass.
5. The "this week" figure on the dashboard and on the stats screen agree, and match their
   pre-phase values for the same trips.
6. `monthTotalSeconds` is either rendered or removed along with its unused constants.
7. Switching periods does not re-query in a way the user perceives as a stall on a
   database with a year of trips.

## Verification

- Unit: period boundary math — week/month/year starts, DST transitions (the existing
  `_daysBetweenLocalMidnights` UTC-anchoring pattern must be reused, not re-invented),
  leap years, a trip starting 23:50 and ending 00:10.
- Unit: daily average for each RnD worked example.
- Unit: empty period returns a zero/absent state rather than a division by zero.
- Widget: period selector switches all period-aware cards together.
- Widget: dashboard/stats week agreement test.
- Performance: measure stats screen build with a seeded year of trips; record the number
  in `34-SUMMARY.md` rather than asserting it felt fine.
- `flutter analyze` and `dart format .` clean.
- **Manual**: switch periods on a device holding real trip history and sanity-check the
  yearly figure against a hand tally of a known month.
