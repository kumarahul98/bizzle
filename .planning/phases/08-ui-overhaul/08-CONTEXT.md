# Phase 8: UI Overhaul - Context

**Gathered:** 2026-05-14
**Status:** Ready for planning
**Source:** Claude Design handoff bundle (Traevy.html)

<domain>
## Phase Boundary

Replace all visual styling across every screen with the Traevy design system. This phase touches only presentation layer code — theme files, widget styling, constants, and shared UI components. No business logic, state management, data access, or navigation structure changes. The app must be fully functional before and after this phase with all existing tests passing.

Screens in scope: Home/Dashboard, Active Recording, Trip History list, Trip Detail, Stats, Settings, Onboarding (skeleton only — full auth flow is Phase 9).

</domain>

<decisions>
## Implementation Decisions

### Design Tokens
- Replace all hardcoded colors with a `TraevyTokens` class in `lib/config/theme.dart` that exposes both light and dark token sets
- Use `oklch()` colors approximated to their closest sRGB hex equivalents for Flutter compatibility (Flutter does not support oklch natively)
- Token names must match the design: `bg`, `bgElev`, `surface`, `surface2`, `border`, `borderStr`, `text`, `textDim`, `textMuted`, `moving`, `movingBg`, `stuck`, `stuckBg`, `accent`, `accentBg`, `danger`, `record`

**Light token hex approximations:**
- `bg`: `#FAFAF7` (oklch 0.985 0.003 80)
- `bgElev`: `#FFFFFF`
- `surface`: `#F5F5F0` (oklch 0.97 0.004 80)
- `surface2`: `#EEEEE8` (oklch 0.945 0.005 80)
- `border`: `#E5E5DF` (oklch 0.9 0.005 80)
- `borderStr`: `#D4D4CE` (oklch 0.84 0.006 80)
- `text`: `#2A2A38` (oklch 0.22 0.01 250)
- `textDim`: `#6B6B7A` (oklch 0.45 0.01 250)
- `textMuted`: `#9A9AAA` (oklch 0.62 0.01 250)
- `moving`: `#2E8B57` (oklch 0.62 0.13 155 → warm green)
- `movingBg`: `#DCF2E4` (oklch 0.93 0.04 155)
- `stuck`: `#C4820A` (oklch 0.68 0.14 65 → muted amber)
- `stuckBg`: `#F5EDDA` (oklch 0.94 0.04 75)
- `accent`: `#3A5F8F` (oklch 0.45 0.06 240)
- `accentBg`: `#E8EEF5` (oklch 0.94 0.015 240)
- `danger`: `#C0392B` (oklch 0.6 0.18 25)
- `record`: `#C0392B` (oklch 0.62 0.16 25)

**Dark token hex approximations:**
- `bg`: `#1A1B22` (oklch 0.16 0.006 250)
- `bgElev`: `#22242E` (oklch 0.21 0.006 250)
- `surface`: `#24262F` (oklch 0.22 0.006 250)
- `surface2`: `#2A2C38` (oklch 0.26 0.006 250)
- `border`: `#2E3040` (oklch 0.28 0.008 250)
- `borderStr`: `#383A4A` (oklch 0.34 0.01 250)
- `text`: `#F2F2F7` (oklch 0.96 0.005 250)
- `textDim`: `#A0A0B8` (oklch 0.72 0.008 250)
- `textMuted`: `#6E6E88` (oklch 0.55 0.008 250)
- `moving`: `#5BC88A` (oklch 0.78 0.14 155)
- `movingBg`: `#1E3D2E` (oklch 0.32 0.04 155)
- `stuck`: `#D4A832` (oklch 0.8 0.13 75)
- `stuckBg`: `#3A2E10` (oklch 0.34 0.05 70)
- `accent`: `#8AABCF` (oklch 0.78 0.08 240)
- `accentBg`: `#1E2A38` (oklch 0.28 0.025 240)
- `danger`: `#E05A4A` (oklch 0.7 0.18 25)
- `record`: `#E05A4A` (oklch 0.7 0.18 25)

### Typography
- Add `google_fonts` package (or use `fontFamily` assets) to bring in **Inter** and **JetBrains Mono**
- Inter: all body copy, labels, buttons, headings
- JetBrains Mono: all numeric values (duration, distance, speed, time, percentages), monospace data displays
- Define `TraevyFonts.ui` and `TraevyFonts.mono` TextStyle base objects in `lib/config/theme.dart`
- Add constants to `constants.dart`: `kFontUI = 'Inter'` and `kFontMono = 'JetBrainsMono'`

### App-Wide Theme
- Rewrite `lib/config/theme.dart` with `buildLightTheme()` and `buildDarkTheme()` functions using `TraevyTokens`
- `ColorScheme` seeds: primary from `accent`, error from `danger`, surface from `surface`
- Card theme: `borderRadius: 16`, `elevation: 0`, border via shape
- Bottom navigation bar theme: uses `bgElev` background, token colors for selected/unselected

### Bottom Tab Bar
- 4 tabs: **Today** (home icon), **Trips** (list icon), **Stats** (bar chart icon), **Settings** (settings icon)
- Active tab: text color, stroke weight 2.0; inactive: `textMuted`, stroke weight 1.6
- Tab label font size 10.5, fontWeight 500/600
- Background: `bgElev`, top border `1px solid border`

### Home / Dashboard Screen
- Header: date line (`Mon · 28 Apr`) in 11sp uppercase muted + user name in 22sp bold 700; avatar circle 36dp with `surface` bg
- Hero record card: `bgElev` surface with 24dp border radius, centered circular button 124dp diameter in `record` color with play icon + "START" label, shadow `0 12px 32px rgba(180,60,40,0.25)` light / `rgba(0,0,0,0.4)` dark; subtitle "Auto-labelled **To home** · HH:MM"
- Today's trips: section header "TODAY" uppercase muted 12sp + trip count in mono 12sp; trips in `bgElev` card with `TripRow` component; empty slot row with dashed circle icon
- This week card: "You lost" label + `stuck`-colored JetBrains Mono 38sp number + "to traffic this week." + `StuckBar` + moving/total labels in mono 11.5sp

### Active Recording Screen
- **Variant A (implement this one)**: "● RECORDING" header pill in `record` color + direction label right; centered elapsed timer 76sp JetBrains Mono; 3 stat cards (Distance, Speed, Stuck) in row; mini faux map 180dp height; full-width "Stop and save trip" button in `text`-colored background
- Recording indicator: 8dp circle with `record` bg, pulsing animation

### Trip History Screen
- "Trips" title 22sp bold 700; calendar icon button (surface bg) + plus icon button (`text` bg) in top-right
- List/Calendar pill segmented control: active pill = `text` bg / `bg` text, inactive = transparent with border
- Date sections: date bold 13sp + label 11sp muted; right-aligned total in mono 12sp; trips in `bgElev` card spanning full width (border top+bottom, no side padding)
- `TripRow` component: 36dp direction avatar (`accentBg`/`movingBg`), direction name 15sp bold, duration mono 13sp bold right; time range + distance mono 12sp dim + stuck time in `stuck` color 12sp bold

### Trip Detail Screen
- Back arrow button (36dp surface circle) + date/time center label + more-options button
- Faux map placeholder: 210dp height, `mapBg` surface with subtle street grid
- "Evening commute" label uppercase muted 11sp + direction name 24sp bold
- Stats card: Duration + Distance in mono 28sp bold side-by-side; `StuckBar`; moving/stuck legend in mono 12sp with colored dots
- Traffic insight callout: `stuckBg` bg, clock icon in `stuck` + sentence "You lost **X minutes** stuck in traffic. That's **Y%** of this trip."
- Timeline section: rows with mono time 12sp + 28dp icon circle + label 13.5sp + duration in `stuck` color

### Stats Screen
- "Stats" title 22sp bold; subtitle "Last 28 days · N trips" 12sp dim
- Hero card: "You lost" + stuck-colored mono 56sp number + "to traffic this week." + comparison vs last week in 12sp dim
- Donut chart: 110dp, 14dp stroke, `moving` arc over `stuck` arc; center: stuck% in mono 22sp bold
- 28-day TrendBars: bar chart with `borderStr` bars, `stuck` highlight for worst day, `accent` for today
- WeekdayChart: Mon–Fri bars, `stuck` color for worst, `moving` for best; labels in 11sp mono above bars
- Section label style: 12sp fontWeight 600, `textMuted`, letterSpacing 0.5, UPPERCASE

### Settings Screen
- Grouped section style: 11sp uppercase muted section title above full-width card with top+bottom border
- Account row: 44dp avatar circle (`accentBg`/`accent`) + name 15sp bold + email 12sp dim
- Row pattern: label 14sp + optional mono 12sp dim subtitle + right control (Toggle or Chevron)
- Toggle: 38×22dp pill, `moving`-colored when on / `borderStr` when off; 18dp white knob
- Section groups: Account, Recording, Notifications, Appearance

### Shared Components to create in `lib/shared/widgets/`:
- `TraevyTokens` / theme helpers in `lib/config/theme.dart`
- `StuckBar` widget: proportional moving+stuck segmented bar, height configurable
- `TripRowCard` widget: standard trip list item with avatar, labels, mono time/distance/stuck
- `SectionLabel` widget: uppercase muted 12sp label with letterSpacing
- `TraevyToggle` widget: custom toggle matching design spec
- `StatCard` widget: labeled mono value card used in recording screen

### What does NOT change
- All Riverpod providers, DAOs, services, sync logic, GPS tracking, notification scheduling
- Route names and navigation structure
- Drift schema and data models
- Test logic (widget tests will need theme-aware setup but no business logic changes)

### Claude's Discretion
- Exact faux map implementation: use a styled `Container` with subtle grid/dot pattern as placeholder — full map is Trip Detail concern already handled by `google_maps_flutter` in Phase 4
- Onboarding screen: scaffold the layout (logo, headline, feature ticks, Google button) but wire up to real auth only in Phase 9; for now it can be a static screen accessible via a route
- Exact `google_fonts` version — use whatever is current stable on pub.dev

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing theme and constants
- `lib/config/theme.dart` — current theme to replace
- `lib/config/constants.dart` — add font constants here
- `lib/config/routes.dart` — route names (do not change)

### Screens to restyle
- `lib/features/dashboard/screens/` — Home/Dashboard screen
- `lib/features/tracking/screens/` — Active recording screen
- `lib/features/trips/screens/` — History list and trip detail screens
- `lib/features/stats/screens/` — Stats screen
- `lib/features/settings/screens/` — Settings screen

### Shared widgets
- `lib/shared/widgets/` — add new Traevy shared components here

### Design source (read for visual spec)
- `/tmp/travey/project/tokens.jsx` — complete color token system (light + dark)
- `/tmp/travey/project/phone.jsx` — TabBar, Icon set, Phone shell structure
- `/tmp/travey/project/charts.jsx` — StuckBar, TrendBars, WeekdayChart, Donut, TripRow
- `/tmp/travey/project/screens-1.jsx` — Onboarding and Home screens
- `/tmp/travey/project/screens-recording.jsx` — Active recording (3 variants; implement Variant A)
- `/tmp/travey/project/screens-history.jsx` — History, Trip Detail, Stats, Settings, Lockscreen

</canonical_refs>

<specifics>
## Specific Ideas

- App name is **Traevy** — logo mark is "tv" in JetBrains Mono 700, 28sp, in a 56×56 rounded square (borderRadius 16) with `text` bg / `bg` text
- Pointed copy tone: "You lost 1h 42m to traffic" not "1h 42m in traffic"
- Recording badge: "● REC" pill with 1px `record`-colored border, 10sp mono, used on lockscreen notification
- Phase 9 (Authentication) will add the real Google Sign-In screen; this phase only scaffolds the onboarding layout

</specifics>

<deferred>
## Deferred Ideas

- Full-bleed map recording variant (Variant B) — deferred, implement only Variant A
- Finance-dashboard recording variant (Variant C) — deferred
- Stats Variation B (pointed dark hero card) — deferred, implement only Variation A
- Real faux map with streets — deferred to Trip Detail polish; use styled placeholder
- Lockscreen notification redesign — covered by existing notification service styling

</deferred>

---

*Phase: 08-ui-overhaul*
*Context gathered: 2026-05-14 from Claude Design handoff (Traevy)*
