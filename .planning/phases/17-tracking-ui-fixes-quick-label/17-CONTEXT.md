# Phase 17: Tracking UI Fixes & Quick Label - Context

**Gathered:** 2026-06-06 (--auto; design decisions reviewed with Gemini)
**Status:** Ready for planning

<domain>
## Phase Boundary

Two small, independent improvements to the active-tracking surface — no schema change:

1. **Timer overflow fix (UX-06)** — the active-recording elapsed timer must always render fully on one line at any duration (including 2-digit hours) and any system text-scale, never wrapping the last digit or clipping.
2. **Quick direction selector (TRACK-12)** — let the user set/change a trip's direction (to-home / to-office) with a one-tap selector during active tracking and from the trip view, overriding the time-of-day auto-label.

**In scope:**
- Fix `ElapsedDisplay` so the 76sp HH:MM:SS timer never wraps/clips (UX-06)
- A segmented to-office / to-home toggle on the active tracking screen that updates the in-flight trip's direction live (TRACK-12)
- A manual-override mechanism in the tracking notifier so the chosen direction wins over the auto-label at finalize and across notification refreshes (TRACK-12)
- A quick direction toggle from the trip view (detail / row) — reuse existing edit path where possible (TRACK-12)

**Out of scope:**
- Geofence-based labeling (LOC-02, Phase 21) — this phase is manual override + time heuristic only
- Pause/breaks (Phase 18), full trip editing of times (Phase 19)
- Any Drift schema migration — `trips.direction` already stores `to_office`/`to_home`/`unknown`
- iOS-specific surfaces

</domain>

<decisions>
## Implementation Decisions

### Timer overflow fix (UX-06)
- **D-01:** Wrap the timer `Text` in `FittedBox(fit: BoxFit.scaleDown)` and set `maxLines: 1` + `softWrap: false` on the `Text`. FittedBox mathematically guarantees no wrap/clip — it renders at 76sp and shrinks only when it would exceed the available width (2-digit hours, narrow devices, large accessibility text-scale). Confirmed best option by Gemini over maxLines-only (truncates) or hard-coded smaller font (fragile across device/text-scale matrix).
- **D-02:** Give the FittedBox a full-width box (the layout already stretches via `crossAxisAlignment.stretch`, but `ElapsedDisplay`'s inner `Column(mainAxisSize.min)` must allow the FittedBox to take the row width — wrap in a width-bounded `SizedBox`/`Align` so scaleDown has a real constraint to shrink against).
- **D-03:** Add `fontFeatures: [FontFeature.tabularFigures()]` to the mono timer style (Gemini tip) — with `letterSpacing: -3` on JetBrains Mono, tabular figures prevent per-digit micro-jitter so the timer stays visually anchored as digits change. Keep existing size 76 / weight w500 / letterSpacing -3 as the *maximum*.
- **Regression guard:** existing widget tests that `find.byType(ElapsedDisplay)` / assert the formatted string must still pass; the format function `_formatElapsed` is unchanged.

### Quick direction selector — active screen (TRACK-12)
- **D-04:** Present as a **segmented toggle** (To office / To home) placed in/under the `RecordingHeader` area of `TrackingActiveLayout`. One-tap, both options visible, large tap targets — chosen over a bottom sheet (too many taps for an in-motion user) or a hidden tap-the-label affordance (poor discoverability). Style with Traevy tokens (reuse existing segmented/toggle widget if one exists; otherwise a minimal Traevy-styled `SegmentedButton`).
- **D-05:** Add a nullable `manualDirectionOverride` (String? holding `kDirectionToOffice`/`kDirectionToHome`) to the active tracking state / notifier. The direction getter resolves: `override ?? DirectionLabelService().label(startedAt, morning, evening)`. The notifier exposes a `setDirection(String)` method the toggle calls; this propagates instantly to the header label and to `_maybeRefreshNotification` (which must read the resolved getter, not recompute from start-time).
- **D-06:** At **finalize**, persist the resolved direction (override if set, else auto-label). Do NOT add the override flag to Drift — only the final absolute `direction` string is written to the trip row (existing column).

### Quick direction selector — trip view (TRACK-12)
- **D-07:** On the trip detail / `trip_row_card`, add a quick to-office/to-home toggle that writes directly to the trip's `direction` via the existing trips DAO update path (the same write `edit_trip_sheet` already uses). Reuse the existing edit/update plumbing — no new persistence path. Keep it a 1-tap toggle, not a full edit sheet.

### Claude's Discretion (resolve in planning/research)
- Whether a reusable Traevy segmented-toggle widget already exists (`lib/shared/widgets/`) to reuse vs. a thin new one.
- Exact placement of the active-screen toggle (inside `RecordingHeader` vs a row directly below it) — keep the hero timer visually dominant.
- Whether the trip-view quick toggle lives on the detail screen, the row card, or both — pick the lowest-friction single surface; the full edit sheet remains the comprehensive path.

</decisions>

<canonical_refs>
## Canonical References

- Timer widget: `lib/features/tracking/widgets/elapsed_display.dart` (the bug source — plain `Text`, no fitting)
- Active layout: `lib/features/tracking/widgets/tracking_active_layout.dart` (`RecordingHeader` + `_directionLabel`)
- Tracking notifier: `lib/features/tracking/providers/tracking_providers.dart` (`_maybeRefreshNotification` recomputes direction from start-time — must read resolved getter after D-05)
- Direction constants: `lib/config/constants.dart` (`kDirectionToOffice`/`kDirectionToHome`/`kDirectionUnknown`, `kDefaultDirectionCutoffHour`)
- Auto-label: `lib/features/trips/services/direction_label_service.dart` (`DirectionLabelService().label`)
- Existing edit path: `lib/features/trips/widgets/edit_trip_sheet.dart` (direction write to DAO)
- Fonts/tokens: `lib/config/theme.dart` (`TraevyFonts.mono`)
- Requirements: UX-06, TRACK-12 (`.planning/REQUIREMENTS.md`)

</canonical_refs>
