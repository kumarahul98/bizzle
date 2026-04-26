# Phase 4: Trip History - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 04-trip-history
**Areas discussed:** Map package, Navigation to history, Daily list grouping, Manual trip detail

---

## Map package

| Option | Description | Selected |
|--------|-------------|----------|
| flutter_map (OpenStreetMap) | No API key, no billing setup, free. Community package using OSM tiles. | ✓ |
| google_maps_flutter | Requires Google Maps API key, SHA-1 fingerprint registration, Google Cloud billing account. $200/month free credit covers personal use but requires setup. | |

**User's choice:** flutter_map
**Notes:** User asked about cost implications. After clarification that google_maps_flutter requires credit card + billing setup even for the free tier, chose flutter_map for zero infrastructure friction on the MVP.

---

## Navigation to history

| Option | Description | Selected |
|--------|-------------|----------|
| History button on home | "View history" text/outlined button below Start CTA. Simple, Phase 6 replaces home screen anyway. | ✓ |
| AppBar icon | Clock/history icon in AppBar top-right. Minimal, doesn't touch body layout. | |
| Bottom NavigationBar | Material 3 NavigationBar with Home + History tabs. Phase 6 redesigns nav anyway — likely wasted work. | |

**User's choice:** History button on home
**Notes:** No structural nav changes — Phase 6 is the real dashboard and will replace this entry point.

---

## Daily list grouping

| Option | Description | Selected |
|--------|-------------|----------|
| Date headers + trip cards | Sticky date sections ("Today", "Yesterday", "Mon 21 Apr"). Client-side grouping from watchAllSummaries(). | ✓ |
| Flat list, newest first | No date grouping, date shown on each card. Simpler but less organized. | |

**User's choice:** Date headers + trip cards
**Notes:** Client-side grouping — no new DAO query needed.

---

## Manual trip detail

| Option | Description | Selected |
|--------|-------------|----------|
| Stats-only, no map | Hide map widget entirely. Show "Manually entered — no route recorded" then stats. | ✓ |
| Map with placeholder | Show map widget centered on default location with overlay message. Consistent layout but potentially confusing. | |

**User's choice:** Stats-only, no map
**Notes:** Clean and honest about what data exists for manual entries.

---

## Claude's Discretion

- flutter_map version and tile provider config
- table_calendar version and marker styling
- Trip card layout (info density, trailing actions, icons)
- How edit/delete are surfaced from list items (swipe, icon, long-press)
- File/folder layout within `lib/features/trips/screens/`
- Route naming and whether detail is a named route or inline push
- Calendar/list view toggle mechanism

## Deferred Ideas

- Undo delete from history list — Phase 7 polish
- Trip search/filtering by direction or date range — future phase
- Export to CSV/JSON — v2 requirement (ANLYT-03)
