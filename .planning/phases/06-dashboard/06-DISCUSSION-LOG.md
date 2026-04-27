# Phase 6: Dashboard - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 06-dashboard
**Areas discussed:** Dashboard layout, Today's trips section, Weekly summary card scope, History & stats navigation

---

## Dashboard Layout

### Feature folder placement

| Option | Description | Selected |
|--------|-------------|----------|
| New `lib/features/dashboard/` | Clean feature boundary; new DashboardScreen replaces HomeScreen as app root | ✓ |
| Rework `features/tracking/home_screen.dart` | Evolve in-place; less refactoring but blurs tracking and dashboard concerns | |

**User's choice:** New `lib/features/dashboard/` folder

---

### Screen structure

| Option | Description | Selected |
|--------|-------------|----------|
| Header + scrollable list | Fixed header above scrollable body (weekly card + today's trips) | ✓ |
| Single scrollable column | Everything scrolls; Start button disappears on scroll | |
| Sticky summary + trips below | Weekly card pinned; CTA as FAB | |

**User's choice:** Header + scrollable list

---

### Header CTA placement

| Option | Description | Selected |
|--------|-------------|----------|
| FAB for Start, header shows greeting/date | FAB bottom-right always visible; header slim with app name or date | ✓ |
| Start button in the header | Prominent FilledButton in header like current home screen | |
| Start button at top of scroll body | Start button first item in scrollable column | |

**User's choice:** FAB for Start

---

## Today's Trips Section

### Empty state

| Option | Description | Selected |
|--------|-------------|----------|
| Simple text below weekly card | "No commutes yet today" label, no full-screen takeover | ✓ |
| Illustrated empty state card | Card with icon and prompt text | |

**User's choice:** Simple text

---

### Live in-progress card

| Option | Description | Selected |
|--------|-------------|----------|
| No — tracking stays separate | Dashboard shows completed trips only; FAB navigates to tracking | |
| Yes — show live "In progress" card | In-progress card at top of today's list when GPS tracking is active | ✓ |

**User's choice:** Yes — show live in-progress card

---

### FAB during active tracking

| Option | Description | Selected |
|--------|-------------|----------|
| FAB changes to "Go to tracking" | Icon/label changes; tapping navigates to tracking screen | ✓ |
| FAB disappears when tracking | No FAB; user taps in-progress card to navigate | |
| FAB stays as Start (no change) | Always Start; tapping when active navigates to tracking instead | |

**User's choice:** FAB changes to "Go to tracking"

---

## Weekly Summary Card Scope

### Numbers to display

| Option | Description | Selected |
|--------|-------------|----------|
| Commute time + traffic time | Two rows; focused on core value | |
| Commute time + traffic + trip count | Three rows; more context | ✓ |
| Full mini-stats | Time, traffic, averages; risks duplicating Stats screen | |

**User's choice:** Commute time + traffic + trip count (three rows)

---

### Link to Stats screen

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — tapping card navigates to Stats | Interactive card with "See full stats →" | ✓ |
| No — display only | Stats reached via separate nav element | |

**User's choice:** Yes — tappable card linking to Stats

---

## History & Stats Navigation

| Option | Description | Selected |
|--------|-------------|----------|
| AppBar trailing icons | History and Stats icons in AppBar top-right | ✓ |
| Keep outlined buttons in scroll body | Familiar but takes space; feels like a menu | |
| Bottom navigation bar (3 tabs) | Persistent nav; deferred in Phase 4 D-02 | |

**User's choice:** AppBar trailing icons (removes the two temporary outlined buttons)

---

## Claude's Discretion

- Exact greeting / header text (date format vs "Good morning"; no user name until Phase 8 auth)
- "In progress" card visual treatment (color, elapsed time format, icon)
- Trip count pluralization ("1 trip" vs "5 trips")
- AppBar icon choices for History and Stats
- Whether to label traffic as "In traffic" or "Stuck in traffic"
- Empty state label text
- File and widget naming within `lib/features/dashboard/`
- Provider naming for the today-filtered list
- Manual entry placement (migrate from old HomeScreen FAB; exact new placement is Claude's call)

## Deferred Ideas

- **Phase 8 auth items on dashboard** — User name in greeting, profile avatar. Auth comes in Phase 8 (after Phase 9 backend infra). Noted by user mid-discussion.
- **Bottom navigation bar** — User mentioned it but prior phases deferred it (Phase 4 D-02). AppBar icons cover navigation for now. Revisit at Phase 7 (Polish) if desired.
