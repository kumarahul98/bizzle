# Phase 5: Stats & Analytics - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 05-stats-analytics
**Areas discussed:** Stats overview, Screen layout, Period definitions, Manual entry in stats, Trend line shape, Stats computation location, Minimum data thresholds, Empty state + screen entry, Trend chart x-axis

---

## Stats Overview

User confirmed the 5 requirements-defined stats (STAT-01 through STAT-05) are correct as-is. No additions or removals requested.

**Notes:** User asked "can we discuss what kind of stats we can show?" — surfaced requirements list, user confirmed it matches their vision.

---

## Screen Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Single scrollable page | All stat cards stacked vertically on one screen | ✓ |
| Tabbed: Overview + Trends | Two tabs splitting summary stats from trend chart | |
| You decide | Claude picks layout | |

**User's choice:** Single scrollable page
**Notes:** Preview of stacked card layout confirmed the expected structure.

---

## Period Definitions — Week

| Option | Description | Selected |
|--------|-------------|----------|
| Calendar week Mon–Sun | Resets on Monday, current Mon–Sun block | ✓ |
| Rolling last 7 days | Trailing 7 days from today, shifts daily | |
| You decide | Claude picks | |

**User's choice:** Calendar week Mon–Sun

---

## Period Definitions — Month

| Option | Description | Selected |
|--------|-------------|----------|
| Calendar month | Jan 1–Jan 31, resets on 1st | ✓ |
| Rolling last 30 days | Trailing 30 days, shifts daily | |
| You decide | Claude picks | |

**User's choice:** Calendar month

---

## Manual Entry in Stats

| Option | Description | Selected |
|--------|-------------|----------|
| Include time, exclude traffic | Count for totals/averages, exclude from STAT-05 | ✓ |
| Exclude from all stats | Only GPS trips counted | |
| Include in everything | Count timeStuckSeconds = 0 as no traffic | |

**User's choice:** Include time, exclude traffic
**Notes:** Honest approach — trip duration counts, but zero traffic data doesn't skew STAT-05.

---

## Trend Line — Data Point

| Option | Description | Selected |
|--------|-------------|----------|
| Daily total commute time | Sum of all trip durations per calendar day | ✓ |
| Per-trip dots | One dot per trip, multiple dots on busy days | |
| Daily average per trip | Average duration per trip per day | |

**User's choice:** Daily total commute time

---

## Trend Line — Direction Split

| Option | Description | Selected |
|--------|-------------|----------|
| Single combined line | One line, total daily commute | ✓ |
| Two lines by direction | Separate to-office and to-home lines | |
| You decide | Claude picks | |

**User's choice:** Single combined line

---

## Best/Worst Commute Day — Time Range

| Option | Description | Selected |
|--------|-------------|----------|
| All recorded trips | Day-of-week average across all history | ✓ |
| Last 4 weeks only | Trailing 28 days | |
| Current month only | This calendar month only | |

**User's choice:** All recorded trips

---

## Stats Computation Location

| Option | Description | Selected |
|--------|-------------|----------|
| Pure Dart in Riverpod provider | Single-pass over watchAllSummaries(), easy to unit test | ✓ |
| SQL aggregate queries in DAO | GROUP BY / AVG / SUM via Drift's aggregate API | |
| You decide | Claude picks | |

**User's choice:** Pure Dart in Riverpod provider

---

## Minimum Data Thresholds (STAT-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Always show, no threshold | All 5 weekdays shown regardless of sample count | ✓ |
| Hide days below N trips | Only show weekdays with ≥3 trips | |
| Show with sample count label | Show all days with "(N trips)" label | |

**User's choice:** Always show, no threshold

---

## Empty State

| Option | Description | Selected |
|--------|-------------|----------|
| Empty state card per section | Each card shows "—" in place of numbers | ✓ |
| Full-screen empty state | Replace entire screen with single message | |
| You decide | Claude picks | |

**User's choice:** Empty state card per section

---

## Screen Entry Point

| Option | Description | Selected |
|--------|-------------|----------|
| Button below 'View history' | Same pattern as Phase 4, stacked temporary buttons | ✓ |
| Replace with nav row | Two outlined buttons side-by-side: History + Stats | |
| You decide | Claude picks | |

**User's choice:** Button below 'View history'

---

## Trend Chart X-Axis

| Option | Description | Selected |
|--------|-------------|----------|
| Week labels only | 4 labels: Week 1, Week 2, Week 3, This week | ✓ |
| Monday dates per week | "14 Apr", "21 Apr", etc. | |
| You decide | Claude picks | |

**User's choice:** Week labels only

---

## Claude's Discretion

- Exact card styling, padding, typography within Material 3
- Whether days with no trips show 0-height or a visual gap on the trend chart
- `fl_chart` widget type (LineChart vs BarChart)
- How best/worst weekday is visually highlighted
- File/folder naming within `lib/features/stats/`
- Whether one combined provider or multiple focused providers
- AppBar title
- Exact empty-state copy per card

## Deferred Ideas

- Average trip distance — available in `TripSummary.distanceMeters` but not in STAT requirements; noted for future
- Month-over-month comparison — ANLYT-01 in v2 requirements
- Interactive trend chart tap-to-reveal — deferred to Claude's discretion
