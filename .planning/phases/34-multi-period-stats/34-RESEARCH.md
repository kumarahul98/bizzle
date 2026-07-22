---
phase: 34-multi-period-stats
plan: 34-01
created: 2026-07-21
status: accepted
accepted: 2026-07-22
mode: manual-gsd
requirements: [STATS-03]
result: >
  RnD only. No code written. Answers D-01's six questions with a recommendation
  each, D-02 and D-03 with a resolution each. REVIEWED AND RATIFIED 2026-07-22 —
  see "Review outcome" at the top. Five of six recommendations accepted as-is;
  Q6 overruled (the trend chart re-buckets per period). Wave 2/3 unblocked.
---

# Phase 34 — Multi-Period Stats — RESEARCH

## Review outcome (ratified 2026-07-22)

The user reviewed this document and decided:

| # | Question | Decision | vs recommendation |
|---|---|---|---|
| 1 | Period semantics | **Calendar** | Accepted |
| 2 | Daily-average denominator | **Per commuting day** | Accepted |
| 3 | Metrics | **Exclude trip count** (total, stuck, stuck share %, per-commuting-day avg, commuting-day count) | Accepted |
| 4 | Partial periods | **Label `· so far`, never extrapolate** | Accepted (not separately asked — clearly correct) |
| 5 | Aggregation | **Extend in-memory `computeStatsSummary`** | Accepted (not separately asked — settled by measurement) |
| 6 | Trend chart | **Re-bucket per period** — Week→daily, Month→weekly, Year→monthly | **OVERRULED.** The doc recommended leaving `TrendBarsCard` at 28 days; the user wants it period-aware. |
| — | Stuck share population mismatch | **Fix it** — compute share over the non-blank-manual population on both sides; headline total stays all-trips | Accepted (ratifies the Additional-Findings recommendation) |

**Consequence of the Q6 overrule for Wave 3:** `TrendBarsCard` becomes period-aware and follows `selectedStatsPeriodProvider`. Three bucketings under one card, each with its own axis semantics and its own tests:
- **Week** → 7 daily bars (one per weekday of the selected calendar week).
- **Month** → weekly bars (~4–5, one per ISO/calendar week touching the month).
- **Year** → 12 monthly bars.

This is a genuine design addition, not a parameter flip — the "worst day" / "best day" highlight logic and the empty-bar handling must be reconsidered per bucketing. It moves `TrendBarsCard` out of the fixed-window lower section (Q6's card-mapping table) and up with the period-aware group. `WeekdayChartCard` still stays all-time — it was not overruled.

---

# Phase 34 — Multi-Period Stats — RESEARCH (original, as submitted)

## Recommendation summary

| # | Question | Recommendation |
|---|---|---|
| 1 | Period semantics | **Calendar** (Mon–Sun / 1st–end / Jan–Dec). Rolling windows move a shipped user-visible number for no gain once Q2 is answered. |
| 2 | Daily average denominator | **Days with at least one trip.** Labelled `1h 30m per commuting day`, with `5 commuting days` underneath. Never bare "per day". |
| 3 | Which metrics | **Total time, stuck time, stuck share %, per-commuting-day average, commuting-day count.** Reject distance. Reject trip count. |
| 4 | Partial periods | **Label it, never extrapolate.** Compare averages across partial/complete freely (Q2 makes them comparable); suppress the delta on *totals* while the current period is partial. |
| 5 | Aggregation strategy | **Extend in-memory `computeStatsSummary`.** Measured: the Dart pass is 0.41 ms at 730 rows; the query feeding it is 5.56 ms. SQL `GROUP BY` optimises 7% of the cost and adds a second query. |
| 6 | UI shape | **Segmented control**, 3 segments. `TrafficLossHero` and `DonutCard` become period-aware; `TrendBarsCard` and `WeekdayChartCard` stay fixed-window in a visually separate section. |

| Item | Resolution |
|---|---|
| D-02 `monthTotalSeconds` | **Rendered**, generalised to `periodTotalSeconds` in `DonutCard`. `kStatsCardMonthLabel` and `kStatsTrendWeekCount` deleted. `kStatsEmptyPlaceholder` is a third dead constant — sweep it in the same commit. |
| D-03 week agreement | Preserved by construction: calendar semantics are unchanged, and both surfaces keep reading one provider. Guarded by a test. |

---

## 1. Period semantics — calendar

**Recommendation: calendar periods. Mon–Sun week, 1st-to-last-day month, Jan–Dec year.**

The week definition already shipping is calendar Mon–Sun (`stats_service.dart:92-94`),
and it is rendered under the literal word "week" in two places: the dashboard
(`week_loss_card.dart:55`, `:86`) and the stats donut (`donut_card.dart:36`). The month
definition is already calendar too (`stats_service.dart:95-96`). A year is the trivial
extension of the same half-open-interval pattern.

| Option | Verdict |
|---|---|
| Rolling 7/30/365-day windows | **Rejected.** Three costs. (a) It silently changes the "This week" figure on a screen users have already been reading — D-03 exists precisely to forbid that, and the honest version of rolling is to move the dashboard card too, which is a larger blast radius than this phase's value. (b) It creates two competing notions of "recent" on one screen, because `TrendBarsCard` is *already* a rolling 28-day window (`stats_service.dart:157-161`) — a rolling-30-day donut sitting above a rolling-28-day bar chart is two windows that differ by two days for no reason a user can see. (c) Nobody plans around "the last 30 days". Users take leave in weeks and get paid in months. |
| Calendar periods | **Chosen.** Matches shipped behaviour, matches how users already talk about the thing being measured, and costs nothing to extend. |

**What breaks in the calendar choice, and why it stops mattering.** The real objection to
calendar periods is comparability: on the 3rd of the month, "this month" is 3 days and
last month was 31, so the two totals are not comparable. That objection is entirely about
*totals*. It disappears for the *average* the moment Q2 is answered with a per-commuting-day
denominator, because that average is independent of how long the period is. So the
sequence matters: answering Q2 correctly is what makes Q1's answer cheap. Q4 then handles
the residual totals problem by labelling rather than extrapolating.

**Year boundaries.** `DateTime(y, 1, 1)` to `DateTime(y + 1, 1, 1)`, half-open, exactly
the shape of the existing month anchors at `stats_service.dart:95-96`. Leap years need no
special handling — the half-open interval absorbs 29 February for free, in the same way
the existing month code absorbs Dart's month-13 normalisation.

---

## 2. Daily average denominator — days with at least one trip

**Recommendation: divide by the number of local calendar dates in the period that contain
at least one trip. Call them commuting days. Never render the number without that word.**

This is the question the phase exists for. T-34-01 names the failure mode correctly: a
calendar-day denominator makes taking leave look like a shorter commute. That is not a
cosmetic wording problem, it is the app reporting the opposite of what happened, on the
one number the project claims as its core value.

### The two candidates

| Option | Answers the question | Verdict |
|---|---|---|
| Calendar days in period | "How much of my life, averaged over all of it, goes to commuting?" | **Rejected.** Correct as a life-share statistic, useless as a commute statistic. It is dominated by how many non-commuting days the period happens to contain — which is a property of the calendar and of the user's leave, not of their commute. Worked examples below show it moving by 30 minutes/day while the commute is byte-identical. |
| Days with ≥1 trip | "What is a commuting day actually like?" | **Chosen.** Stable under leave, weekends, and month length. Moves only when the commute itself moves. |

### Definition, precisely

A commuting day is a distinct local calendar date `DateTime(y, m, d)` derived from
`trip.startTime.toLocal()` for which at least one trip falls inside the period. This
matches the bucketing every existing stat already uses (`stats_service.dart:119-120`), so
a trip starting 23:50 and ending 00:10 counts once, on its start date — consistent with
`weekTotalSeconds`, `dailyTotalsLast28Days` and the history screen's grouping
(`history_providers.dart:30-34`). Manual entries count, per the existing D-05 treatment of
totals (`stats_service.dart:126-135`).

Implementation note for Wave 2: this is a `Set<DateTime>` of date-only values, populated in
the same single pass. It performs no day arithmetic at all, so it is DST-immune by
construction and does **not** need `_daysBetweenLocalMidnights` (`stats_service.dart:73-77`).
That helper is still required for the period *boundary* math, which does subtract days.

### The exact on-screen labels

D-01 asks for labels the user cannot misread. These are the strings, not paraphrases:

| Slot | String |
|---|---|
| Average | `1h 30m per commuting day` |
| Supporting count | `5 commuting days` / `1 commuting day` |
| Empty period | `— per commuting day` above `No commuting days` |
| Screen subtitle | `This week · 5 commuting days` |

`per day` on its own is forbidden. So is `daily average`. Both read as calendar days to
every user who has not read this document, which is all of them.

### Worked examples

Fixed commute throughout: 2 trips per commuting day, 45 minutes each → 5,400 s (1h 30m)
per commuting day. Formatting follows the existing integer-minute formatter
(`donut_card.dart:90-96`), so the printed figures below are what the app would actually show.

**A — normal 5-day week.** Mon–Fri, 5 commuting days. Total 10 × 2700 = 27,000 s (7h 30m).

| Denominator | Arithmetic | Displays |
|---|---|---|
| Calendar days (7) | 27000 ÷ 7 = 3857 s = 64 min | `1h 4m` |
| **Commuting days (5)** | 27000 ÷ 5 = 5400 s = 90 min | **`1h 30m per commuting day`** |

**B — same week, one day off (Wed).** 4 commuting days. Total 8 × 2700 = 21,600 s (6h 00m).

| Denominator | Arithmetic | Displays | vs A |
|---|---|---|---|
| Calendar days (7) | 21600 ÷ 7 = 3085 s = 51 min | `51m` | **−13 min/day — a fictional improvement** |
| **Commuting days (4)** | 21600 ÷ 4 = 5400 s = 90 min | **`1h 30m per commuting day`** | **unchanged, which is the truth** |

This is T-34-01 in one row. Nothing about the commute changed. The calendar-day figure
reports a 20% improvement.

**C — two-week holiday inside a month.** June 2026: 30 days, 22 weekdays, starts Monday
(verified against the calendar). User commutes 12 weekdays and takes 10 weekdays off.
Total 12 × 5400 = 64,800 s (18h 00m). Baseline for comparison is a full June: 22 commuting
days, 118,800 s (33h 00m).

| Denominator | Holiday June | Full June | Delta |
|---|---|---|---|
| Calendar days (30) | 2160 s = 36 min → `36m` | 3960 s = 66 min → `1h 6m` | **−30 min/day** |
| **Commuting days** | 64800 ÷ 12 = 5400 s → **`1h 30m`** | 118800 ÷ 22 = 5400 s → **`1h 30m`** | **0** |

The calendar-day denominator awards a 30-minute-per-day improvement for going on holiday.

**D — month containing a public holiday.** July 2026: 31 days, 23 weekdays (verified). One
public holiday, so 22 commuting days. Total 22 × 5400 = 118,800 s (33h 00m) — numerically
identical to a full June.

| Denominator | July (31 days) | June (30 days) | Delta |
|---|---|---|---|
| Calendar days | 118800 ÷ 31 = 3832 s = 63 min → `1h 3m` | 3960 s = 66 min → `1h 6m` | **−3 min/day** |
| **Commuting days (22 both)** | **`1h 30m`** | **`1h 30m`** | **0** |

Identical commutes, identical commuting-day counts, and the calendar-day figure still
differs — because July is one day longer than June. Under a calendar-day denominator, the
length of the month is a commute metric.

These four examples are the Wave 2 unit tests, verbatim, including the rendered strings.

### The honest cost of this choice

A per-commuting-day average **hides commute frequency**. A user who moves from five office
days to three sees `1h 30m per commuting day` before and after, while their life
demonstrably improved.

This is real, and it is why Q3 keeps the period **total** as the headline. The total drops
from 7h 30m to 4h 30m and the commuting-day count drops from 5 to 3. The pair
answers both questions; either alone answers one and lies about the other. That pairing is
a requirement of this recommendation, not a nice-to-have — shipping the average without the
commuting-day count next to it reintroduces the ambiguity from the other side.

### Empty period

Zero commuting days returns `null`, rendered as the em-dash placeholder, in the same shape
as the existing nullable averages (`stats_service.dart:168-181`). No division guard beyond
that. The existing `kStatsEmptyPlaceholder` constant (`constants.dart:556`) is currently
referenced only from a doc comment (`stats_service.dart:11`) — this is the phase that
finally gives it a caller.

---

## 3. Which metrics get the period treatment

**Recommendation: total time, stuck time, stuck share %, per-commuting-day average,
commuting-day count. Five values, of which two exist only to make the other three
readable.**

| Metric | Verdict |
|---|---|
| Total commute time | **Include.** Already the donut centre (`donut_card.dart:54`). It is the metric that moves when frequency changes, so it is what makes the Q2 recommendation safe. |
| Time stuck | **Include.** This is the product. The hero renders it (`traffic_loss_hero.dart:27`) and the dashboard mirrors it (`week_loss_card.dart:38`). |
| Stuck share % | **Include.** Free — it is `stuck ÷ total`, no new accumulator — and it is the only one of the five that is comparable between a partial and a complete period without any caveat at all. See the population caveat in Additional Findings before implementing. |
| Per-commuting-day average | **Include.** Q2. This is the phase. |
| Commuting-day count | **Include.** Not really a metric; it is the denominator, and Q2 makes displaying it mandatory. |
| Distance | **Reject.** Two reasons. The app's stated value is time lost, not kilometres; and for a fixed commute distance is near-constant, so a distance trend is a flat line with GPS noise on it. There is also a correctness problem: `distanceMeters` is 0 for blank manual entries, which the existing code specifically tests for (`stats_service.dart:129-132`), so a period distance total silently under-reports by however many trips the user typed in by hand. |
| Trip count | **Reject.** It is ~2× the commuting-day count for essentially every user of a commute tracker, so it is a second number carrying the same information. Worth noting that the screen already claims to show it and does not: `stats_screen.dart:37-46` labels the count of *days with non-zero totals* as `N trips`. That is a pre-existing bug; this phase deletes the line rather than fixing it, replacing it with the Q2 subtitle. |

Five values on a screen that currently shows four cards is close to the ceiling. Each
additional one is a thing the user has to decide whether to care about, and the honest
answer for distance and trip count is no.

---

## 4. Partial periods — label, never extrapolate

**Recommendation: the current period is always marked as in-progress. It is never
extrapolated. Averages compare freely; totals do not.**

**Extrapolation is a mistake and I want to be unambiguous about it.** Scaling a 3-day week
to a 7-day estimate invents trips the user did not take and presents them in the same
typeface as trips they did. It is worst exactly when it is most tempting — on a Monday,
where the sample is one day, and where a single bad-traffic Monday extrapolates into a
catastrophic week that never happens. The app's value proposition is showing people the
reality of their commute; a projected figure is by definition not that. Rejected outright,
not deferred.

The rule, which falls straight out of Q2:

| Value | Partial current period | Rationale |
|---|---|---|
| Per-commuting-day average | **Comparable. Show the delta.** | Length-independent by construction, so 3 commuting days of this week compares honestly against last week's 5. This is the second thing the Q2 answer buys. |
| Stuck share % | **Comparable. Show the delta.** | A ratio; same argument. |
| Total time, stuck time | **Shown, but the period-over-period delta is suppressed while the current period is incomplete.** | "18h vs 33h last month" on the 12th is not a comparison, it is a subtraction dressed as one. Suppress the delta; keep the number, because the running total is genuinely what a user wants to see. |
| Commuting days | Shown; inherently a running count. | — |

**Marker copy.** Append `· so far` to the period label: `This week · so far`,
`July · so far`, `2026 · so far`. A completed period drops it. The marker must be adjacent
to the totals, not in a footnote, since the totals are the values it qualifies.

A period is complete when `now` is at or past its end anchor. Reuse the existing half-open
end anchors (`stats_service.dart:94`, `:96`); no new boundary logic.

---

## 5. Aggregation strategy — extend the in-memory pass

**Recommendation: extend `computeStatsSummary`. Do not introduce SQL `GROUP BY`.**

### What I measured, and what I could not

**Could not measure: the user's actual row count.** There is no development database in the
repository — a filesystem search for `*.db`, `*.sqlite`, `*.sqlite3` returns exactly one
hit, `landing/.wrangler/state/v3/cache/miniflare-CacheObject/metadata.sqlite`, which is a
Cloudflare build cache and unrelated. There are no seeded fixtures; every test constructs
its rows inline against `NativeDatabase.memory()` (`test/unit/database/trips_dao_test.dart:13-19`).
No Android device is attached (`adb devices` lists none), so the on-device database could
not be pulled. Per the Phase 29 correction, I am not going to back-fill a number I did not
observe.

**Did measure: the cost per row**, against the real `AppDatabase`, the real
`TripsDao.watchAllSummaries()`, and the real `computeStatsSummary`, at row counts derived
arithmetically from the plan's own commute frequency. Method: an in-memory Drift database
seeded by batch insert with a 6 KB `routePolyline` per row (the size stated at
`trips_dao.dart:10-13`); 20 timed first-emissions of the stream for the query, 500 timed
calls for the compute; run on the development Mac under the Dart VM.

| Rows | Basis | `watchAllSummaries()` first emission | `computeStatsSummary` |
|---|---|---|---|
| 730 | 2 trips/day × 1 year | **5.56 ms** | **0.41 ms** |
| 1,460 | 2 years | 9.97 ms | 0.82 ms |
| 3,650 | 5 years | 25.75 ms | 2.06 ms |

A separate synthetic run over the same loop confirms the pass is linear at **618 ns/row**,
stable from 730 to 10,000 rows (618.2 / 623.5 / 615.1 / 617.8 ns/row) — so there is no
hidden super-linearity waiting at larger sizes.

These are desktop-VM numbers. A mid-range Android device in AOT will be some multiple
slower; the ratio between the two columns is what the decision rests on, and that ratio is
a property of the work, not the hardware.

### Why the ratio decides it

**The Dart pass is 7% of the cost. The query is 93%.** At the one-year mark the aggregation
everyone is worried about takes 0.41 ms — a twentieth of a 16 ms frame.

More decisively: **the query is not avoidable.** `allTripSummariesProvider`
(`history_providers.dart:12-16`) is a single shared Drift subscription consumed by both the
history screen and `statsSummaryProvider` (`stats_providers.dart:31`). That `SELECT *` runs
on every write to the trips table whether or not stats exists. A `GROUP BY` in `TripsDao`
would therefore **add** a second query rather than replace the first — trading 0.41 ms of
Dart for a fresh round-trip through SQLite, plus stats logic split across two languages and
two test styles, plus a second definition of "week" that can drift out of agreement with
the first and break D-03.

| Option | Verdict |
|---|---|
| SQL `GROUP BY` in `TripsDao` (what `tasks.md:44-49` originally specified) | **Rejected.** Optimises the 7%, adds a query, and puts a second week/month definition in a second language where D-03 cannot be enforced by a single shared field. `tasks.md` was written before `computeStatsSummary` existed and before the shared-stream architecture; it is a stale specification, not a standing requirement. |
| Extend `computeStatsSummary` | **Chosen.** One definition of a period, one language, one test style, one shared field for D-03 to hold, and — measured — the cheaper of the two. |

### T-34-03, restated against the measurement

The threat model worries that a yearly view means "a full-table pass on every stream
rebuild", and asks that the provider not recompute on unrelated emissions. The measurement
says the pass is not the problem: it is 0.41 ms at a year of data and 2.06 ms at five
years. I would not add memoisation for that, and memoisation is in any case impossible in
the current shape — `statsSummaryProvider` calls `DateTime.now()` inside `whenData`
(`stats_providers.dart:33`), so it is not a pure function of its input and Riverpod cannot
cache it. Leave it. **T-34-03 is satisfied by the measurement, not by an optimisation.**

### The performance win that actually exists, and is out of scope

`watchAllSummaries()` builds `select(trips)` (`trips_dao.dart:89-96`), which reads every
column including the 6 KB polyline, and then discards it in `_toSummary`. The dartdoc at
`trips_dao.dart:84-87` says the polyline "never touches the stream" — true of the Dart
object, false of the SQL.

Measured cost of that, same harness, identical rows with an empty polyline column:

| Rows | With 6 KB polyline | Empty polyline | Saving |
|---|---|---|---|
| 730 | 5.56 ms | 3.96 ms | −29% |
| 1,460 | 9.97 ms | 4.40 ms | −56% |
| 3,650 | 25.75 ms | 14.01 ms | −46% |

Narrowing that projection is the cheapest available improvement to the stats path and it
is worth roughly ten times whatever a `GROUP BY` would buy. It is **not** Phase 34's job —
it touches the history screen's data path and deserves its own change with its own tests.
Filed here so the number is not lost.

---

## 6. UI shape — segmented control, two cards period-aware

**Recommendation: a 3-segment segmented control (`Week` / `Month` / `Year`), placed where
the current subtitle sits. `TrafficLossHero` and `DonutCard` follow it. `TrendBarsCard`
and `WeekdayChartCard` do not, and are visually separated so that reads as deliberate.**

| Option | Verdict |
|---|---|
| `TabBar` + `TabBarView` | **Rejected.** Tabs promise swipeable pages of different content. Here the content is the same four cards with different numbers in two of them, so tabs would signal a navigation that is not happening. They also cost a `TabController` and a `Scaffold`/`AppBar` restructure — the screen deliberately has no AppBar (`stats_screen.dart:48-62`) — and they would push the hero below the fold. |
| Segmented control | **Chosen.** Three mutually exclusive states, always all visible, no layout change, no controller. |

### Card mapping

| Card | Period-aware? | Notes |
|---|---|---|
| `TrafficLossHero` | **Yes** | `traffic_loss_hero.dart:48` hardcodes "to traffic this week." → period phrasing. The Week value must remain bit-identical to today's (D-03). |
| `DonutCard` | **Yes** | Title `'This week'` is hardcoded (`donut_card.dart:36`) → period label. This is where D-02 lands (below). |
| `TrendBarsCard` | **No — stays 28 days** | 365 daily bars at 4 px (`trend_bars_card.dart:10`) is ~1,460 px of chart in a ~335 px card. It degenerates. Re-bucketing to weeks for Month and months for Year was **considered and rejected for this phase**: that is three different chart semantics under one title, and it is a separate design problem, not a parameter change. If wanted, it is a Phase 34.1. |
| `WeekdayChartCard` | **No — stays all-time** | Restricted to one week, each bar is a single sample and the Best/Worst callout (`weekday_chart_card.dart:96-99`, `:146-171`) becomes noise rather than insight. All-time is the only window in which "which weekday is worst" means anything. |

Two of four following the selector is a real inconsistency risk. Mitigation: order the
screen as period-aware cards first, then a dim divider and section label, then the two
fixed-window cards with their windows stated in their own titles (`28-day trend` already
does; `Weekday averages` should gain `· all time`). The user should be able to see that the
lower group is a different kind of thing rather than discover it by watching numbers not
change.

**Where the per-commuting-day figure goes:** inside `DonutCard`, as a line under the
existing `total` label (`donut_card.dart:54-66`), with the commuting-day count beneath it.
That block already owns the period totals; a fifth card for one number is not warranted.

**Screen subtitle:** replace `Last 28 days · N trips` (`stats_screen.dart:37-46`) with
`{period label} · {n} commuting days`, plus the Q4 `· so far` marker. This deletes the
mislabelled count described in Q3 as a side effect.

### Provider shape — required for the widget criterion

Wave 3's "period selector switches all period-aware cards together" is only guaranteed if
the period is provider state, not widget state. Every card independently watches
`statsSummaryProvider` (`traffic_loss_hero.dart:24`, `donut_card.dart:28`,
`trend_bars_card.dart:33`, `weekday_chart_card.dart:34`), so a widget-local selection would
have to be threaded through four constructors and could go out of step.

Shape: a `selectedStatsPeriodProvider` holding a `sealed class StatsPeriod` (week / month /
year — per CLAUDE.md, never raw strings), and `statsSummaryProvider` watching it alongside
`allTripSummariesProvider`. One recompute per change, one `StatsSummary`, all cards
consistent by construction.

**Phase 31's `InfoSheet` does not exist yet** — no `InfoSheet` declaration is present
anywhere in `lib/`. If Wave 3 wants an explainer for "per commuting day", either Phase 31
lands first or the explainer is deferred. The label is designed to stand alone without one.

---

## D-02 — `monthTotalSeconds`

**Resolution: rendered, under a generalised name.** `monthTotalSeconds`
(`stats_service.dart:33`, computed at `:139-141`, displayed nowhere) becomes
`periodTotalSeconds`, and finally renders as the `DonutCard` centre total whenever the
selected period is Month or Year. The value is not deleted; the dead *field name* is,
which is the stronger version of what D-02 asks for.

Deleted in the same commit:

| Constant | Evidence |
|---|---|
| `kStatsCardMonthLabel` (`constants.dart:515`) | Referenced only by its own declaration. |
| `kStatsTrendWeekCount` (`constants.dart:502`) | Referenced only by its own declaration. |
| `kStatsEmptyPlaceholder` (`constants.dart:556`) | **Third one, not in the plan.** Referenced only from a dartdoc (`stats_service.dart:11`). Q2's empty-period state gives it a real caller — so this one is *revived*, not deleted. Flagged because it is the same class of leftover and should not survive another phase unresolved either way. |

Test call sites constructing `monthTotalSeconds` will need updating:
`test/unit/features/stats/stats_service_test.dart:53`, `:102`, `:120`;
`test/widget/features/dashboard/dashboard_screen_test.dart:151`;
`test/widget/features/shell/main_shell_test.dart:71`.

## D-03 — the week figure does not move

Satisfied by construction rather than by care:

1. Q1 keeps calendar Mon–Sun, so the boundary math at `stats_service.dart:92-94` is
   untouched and the Week value is arithmetically identical to today's.
2. `week_loss_card.dart:34` and the stats cards keep reading the *same*
   `statsSummaryProvider`, so there is one number, not two that agree.
3. The dashboard card is **not** period-aware — it is a dashboard summary, always the
   current week. It should read the Week figure regardless of the stats screen's selected
   period, which means the week accumulators must survive the generalisation rather than
   being replaced by a single period-parameterised total. That is the one real
   implementation constraint this recommendation places on Wave 2.
4. Wave 2 adds the agreement test the threat model asks for (T-34-02).

---

## Additional findings

**Stuck share has a population mismatch.** `weekStuckSeconds` excludes blank manual entries
(`stats_service.dart:126-135`) while `weekTotalSeconds` includes them (`:124`). Numerator
and denominator are therefore drawn from different populations, and any stuck share
computed as `stuck ÷ total` is understated by exactly the blank-manual-entry time — silently,
and only for users who type trips in by hand. This is pre-existing; it becomes visible for
the first time when Q3 puts a percentage on screen. I recommend the share be computed over
the non-blank-manual population on both sides, with the headline total left as-is (all
trips), but this is a change to a shipped definition and I would rather the human ratify it
than have it arrive inside a percentage.

**`statsSummaryProvider` recomputes on every trips-table write.** Not a performance problem
per Q5, but worth knowing that period selection will inherit the same behaviour.

---

## Where I could be wrong

Three calls where I would not argue hard if overruled:

1. **Q6, `TrendBarsCard` staying 28 days — the closest call in the document.** A user who
   selects Year and sees a 28-day chart underneath has a fair complaint. My case is that
   re-bucketing is a design problem rather than a parameter, and doing it badly inside this
   phase is worse than deferring it. If the reviewer wants week-bucketing for Month and
   month-bucketing for Year, that is defensible and it belongs in Wave 3's scope
   explicitly, not as a stretch goal.
2. **Q3, excluding trip count.** My argument is that it is collinear with commuting days,
   which is true for a two-commutes-a-day user and less true for anyone with errands. If
   the reviewer's own usage is irregular, include it.
3. **Q1, calendar over rolling.** Closer than the table suggests. Rolling windows are
   genuinely more comparable, and the only reason they lose is that Q2's denominator
   already solves the comparability problem they were needed for. If Q2 were answered the
   other way, Q1 should flip too — the two are not independent, and overruling Q2 without
   revisiting Q1 would produce the worst combination available.
