# Phase 8: UI Overhaul - Research

**Researched:** 2026-05-14
**Domain:** Flutter UI/theming, Material 3 customisation, custom font integration, fl_chart 1.x styling
**Confidence:** HIGH

## Summary

Phase 8 replaces the default Material 3 light/dark themes in `lib/config/theme.dart` with a custom `TraevyTokens` colour system and dual-font (Inter + JetBrains Mono) typography, then restyles every screen in the app to match the Traevy design handoff. The codebase is well-positioned for this work: every existing screen reads styling from `Theme.of(context).colorScheme` and `textTheme` — there are **zero** hardcoded hex colours in `lib/` and only **two** hardcoded `TextStyle` usages (both in `trip_card.dart`, both replaceable with theme styles). Tests do not currently assert on colour values, font families, or sizes — they rely on `find.byType`, `find.byTooltip`, `find.text`, and `find.byIcon`, so a theme rewrite breaks **no** tests if Icon constants and tooltip strings remain stable.

The most invasive parts of the phase are not the theme itself but: (1) restructuring every screen layout to match Traevy's calmer card-based pattern (hero record card, grouped trip rows in `bgElev` cards, sectioned settings, custom segmented control on history), (2) building 6 new shared widgets (`StuckBar`, `TripRowCard`, `SectionLabel`, `TraevyToggle`, `StatMiniCard`, plus theme helpers), (3) adding a 4-tab `NavigationBar` to replace the AppBar action buttons that currently navigate to History/Stats/Settings, and (4) deleting/restyling the dashboard's `FloatingActionButton` and AppBar in favour of the hero record card.

**Primary recommendation:** Use `google_fonts: ^8.1.0` with `GoogleFonts.config.allowRuntimeFetching = false` plus locally-bundled Inter (400/500/600/700) and JetBrains Mono (400/500/600) TTF files in `assets/fonts/`. Build the theme via explicit `ColorScheme` and `TextTheme` constructions (NOT `ColorScheme.fromSeed` — the Traevy colour relationships do not survive seed derivation). Introduce a 4-tab `NavigationBar` as a new top-level shell (`MainShell`) that swaps the body between Dashboard/History/Stats/Settings without changing the existing screen widgets' Riverpod wiring.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Colour token system (`TraevyTokens`) | UI Layer (theme) | — | Pure presentation contract; no business state |
| Typography (`TraevyFonts`) | UI Layer (theme) | — | Pure presentation contract |
| ThemeData light/dark factory | UI Layer (theme) | — | Consumed only by `MaterialApp` |
| Shared widget primitives (StuckBar, TripRowCard, etc.) | UI Layer (shared) | — | Reusable stateless widgets, no data fetching |
| Screen restyle (Dashboard, History, etc.) | UI Layer (views) | — | Existing Riverpod wiring untouched |
| Bottom `NavigationBar` shell | UI Layer (views) | — | Pure UI; routing remains in `routes.dart` |
| Onboarding scaffold | UI Layer (views) | — | Static layout; auth wiring deferred to Phase 9 |
| Font asset declaration | Asset pipeline (`pubspec.yaml`) | — | Build-time concern |

**Sanity check:** Nothing in this phase touches data, business logic, or platform integrations. Every change lives in `lib/config/theme.dart`, `lib/config/constants.dart`, `lib/shared/widgets/`, and the existing `lib/features/*/screens/` and `lib/features/*/widgets/` directories.

## Project Constraints (from CLAUDE.md)

| Constraint | Source | Application to Phase 8 |
|------------|--------|------------------------|
| Riverpod for all state | CLAUDE.md "Frontend / Flutter Rules" | UI overhaul never introduces `setState` or `ChangeNotifier`; existing providers untouched |
| Drift is the only data source for UI | CLAUDE.md "Frontend / Flutter Rules" | No new data reads added; restyled widgets continue consuming the same providers |
| Widgets under 100 lines | CLAUDE.md "Frontend / Flutter Rules" | Large restyled screens (Dashboard, History, Trip Detail) MUST be decomposed into sub-widgets — split hero card, today section, week card, etc. |
| `sealed` classes for finite state | CLAUDE.md "Frontend / Flutter Rules" | No new state introduced; existing sealed classes (TrackingState, TripManagement\*) remain |
| No hardcoded values | CLAUDE.md "Frontend / Flutter Rules" | All new colour hex values, font sizes, and string labels MUST live in `lib/config/constants.dart` or `TraevyTokens` |
| No dead code, no TODO | CLAUDE.md "Code Quality" | Old `lightTheme = ThemeData.light()` placeholder MUST be replaced (not left behind) |
| `dart format`, `flutter analyze` clean | CLAUDE.md "Coding Conventions" | Every modified file MUST pass `flutter analyze` with zero warnings (success criteria #8 in ROADMAP) |
| `very_good_analysis` lint set | analysis_options.yaml | All new widgets MUST pass strict-casts, strict-inference, strict-raw-types |
| `prefer_const_constructors` rule | analysis_options.yaml | New widgets MUST use `const` constructors where possible |
| One concern per commit, prefixed | CLAUDE.md "Task Discipline" | Phase 8 commits prefixed `[ui]`, `[infra]` (for pubspec/asset), or `[theme]` |
| Test logic unchanged | Phase 8 CONTEXT decision | Widget tests MUST remain GREEN; locators based on `byType`/`byTooltip`/`byIcon`/`text` must still resolve |

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Design Tokens (verbatim from CONTEXT.md `<decisions>` block):**
- Replace all hardcoded colors with a `TraevyTokens` class in `lib/config/theme.dart` that exposes both light and dark token sets.
- Use `oklch()` colors approximated to their closest sRGB hex equivalents for Flutter compatibility (Flutter does not support oklch natively).
- Token names must match the design: `bg`, `bgElev`, `surface`, `surface2`, `border`, `borderStr`, `text`, `textDim`, `textMuted`, `moving`, `movingBg`, `stuck`, `stuckBg`, `accent`, `accentBg`, `danger`, `record`.

**Light token hex approximations** (full table in CONTEXT.md — locked):
`bg=#FAFAF7, bgElev=#FFFFFF, surface=#F5F5F0, surface2=#EEEEE8, border=#E5E5DF, borderStr=#D4D4CE, text=#2A2A38, textDim=#6B6B7A, textMuted=#9A9AAA, moving=#2E8B57, movingBg=#DCF2E4, stuck=#C4820A, stuckBg=#F5EDDA, accent=#3A5F8F, accentBg=#E8EEF5, danger=#C0392B, record=#C0392B`.

**Dark token hex approximations** (full table in CONTEXT.md — locked):
`bg=#1A1B22, bgElev=#22242E, surface=#24262F, surface2=#2A2C38, border=#2E3040, borderStr=#383A4A, text=#F2F2F7, textDim=#A0A0B8, textMuted=#6E6E88, moving=#5BC88A, movingBg=#1E3D2E, stuck=#D4A832, stuckBg=#3A2E10, accent=#8AABCF, accentBg=#1E2A38, danger=#E05A4A, record=#E05A4A`.

**Typography (locked):**
- Add `google_fonts` package (or use `fontFamily` assets) to bring in **Inter** and **JetBrains Mono**.
- Inter: all body copy, labels, buttons, headings.
- JetBrains Mono: all numeric values (duration, distance, speed, time, percentages), monospace data displays.
- Define `TraevyFonts.ui` and `TraevyFonts.mono` TextStyle base objects in `lib/config/theme.dart`.
- Add constants to `constants.dart`: `kFontUI = 'Inter'` and `kFontMono = 'JetBrainsMono'`.

**App-Wide Theme (locked):**
- Rewrite `lib/config/theme.dart` with `buildLightTheme()` and `buildDarkTheme()` functions using `TraevyTokens`.
- `ColorScheme` seeds: primary from `accent`, error from `danger`, surface from `surface`.
- Card theme: `borderRadius: 16`, `elevation: 0`, border via shape.
- Bottom navigation bar theme: uses `bgElev` background, token colors for selected/unselected.

**Bottom Tab Bar (locked):**
- 4 tabs: **Today** (home icon), **Trips** (list icon), **Stats** (bar chart icon), **Settings** (settings icon).
- Active tab: text color, stroke weight 2.0; inactive: `textMuted`, stroke weight 1.6.
- Tab label font size 10.5, fontWeight 500/600.
- Background: `bgElev`, top border `1px solid border`.

**Per-screen layout decisions** — see CONTEXT.md `<decisions>` section for full spec of Home/Dashboard, Active Recording (Variant A only), Trip History, Trip Detail, Stats, Settings, Onboarding. All locked.

**Shared Components to create in `lib/shared/widgets/` (locked):**
- `TraevyTokens` / theme helpers in `lib/config/theme.dart`
- `StuckBar` widget: proportional moving+stuck segmented bar
- `TripRowCard` widget: standard trip list item with avatar, labels, mono time/distance/stuck
- `SectionLabel` widget: uppercase muted 12sp label with letterSpacing
- `TraevyToggle` widget: custom toggle matching design spec
- `StatCard` widget: labeled mono value card used in recording screen

**What does NOT change (locked):**
- All Riverpod providers, DAOs, services, sync logic, GPS tracking, notification scheduling
- Route names and navigation structure
- Drift schema and data models
- Test logic (widget tests will need theme-aware setup but no business logic changes)

### Claude's Discretion

- Exact faux map implementation: use a styled `Container` with subtle grid/dot pattern as placeholder — full map is Trip Detail concern already handled by `google_maps_flutter` in Phase 4 (note: the codebase actually uses `flutter_map`, not `google_maps_flutter` — see Pitfall 1 in `Common Pitfalls`).
- Onboarding screen: scaffold the layout (logo, headline, feature ticks, Google button) but wire up to real auth only in Phase 9; for now it can be a static screen accessible via a route.
- Exact `google_fonts` version — use whatever is current stable on pub.dev.

### Deferred Ideas (OUT OF SCOPE)

- Full-bleed map recording variant (Variant B) — deferred, implement only Variant A
- Finance-dashboard recording variant (Variant C) — deferred
- Stats Variation B (pointed dark hero card) — deferred, implement only Variation A
- Real faux map with streets — deferred to Trip Detail polish; use styled placeholder
- Lockscreen notification redesign — covered by existing notification service styling

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UX-01 | Dashboard home screen shows today's trips and weekly summary card | §3 "Home / Dashboard Screen" in UI-SPEC; existing `DashboardScreen` (`lib/features/dashboard/screens/dashboard_screen.dart`) and its widgets `WeeklySummaryCard`, `TodayTripsSection`, `InProgressCard` provide the providers and data plumbing. Restyle plan: replace AppBar with header row (date + name + avatar), introduce hero record card replacing FAB, replace `WeeklySummaryCard` styling with "You lost X to traffic" hero, restyle today's trips into bgElev card with `TripRowCard`. |
| UX-02 | Dark mode support (system default + manual toggle in settings) | Already implemented in Phase 7 via `userPreferenceProvider` → `TraevyApp._toThemeMode` (`lib/app.dart` lines 32-37). Phase 8 only swaps the underlying `ThemeData` from Material defaults to `buildLightTheme()`/`buildDarkTheme()`. No state-management changes. |
| UX-04 | Weekly summary push notification with commute totals | Notification scheduling (`NotificationService.scheduleWeeklySummary`) is unchanged. Phase 8 only restyles the Settings toggle row (`SwitchListTile` → grouped row with `TraevyToggle`). |
| UX-05 | Tracking reminder notification at user's usual departure time | Same as UX-04: existing `_ReminderRows` logic untouched; restyle visual presentation (label, mono time subtitle, custom toggle, chevron). |

Note: UX-01 styling tags this phase but the *data* requirement (showing today's trips and weekly summary) was completed in Phase 6. Phase 8 retargets the visual presentation only.

## Standard Stack

### Core (already present)

| Library | Version (current in pubspec) | Purpose | Why Standard |
|---------|------|---------|--------------|
| flutter | 3.41.6 stable | UI framework | Locked by CLAUDE.md; verified locally installed |
| flutter_riverpod | ^3.3.1 | State management | Locked by CLAUDE.md |
| fl_chart | ^1.2.0 | Charts (donut, bar, trend line) | Locked by CLAUDE.md/Phase 5; current stable |
| intl | ^0.20.2 | Date/duration formatting | Existing; no change |
| table_calendar | ^3.1.3 | Calendar view in History | Existing; styling override via `CalendarStyle` |
| flutter_map | ^8.1.0 | Trip detail map | Existing; **NOT** `google_maps_flutter` (CONTEXT.md got this wrong — see Pitfall 1) |

### New for Phase 8

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| google_fonts | ^8.1.0 | Inter + JetBrains Mono font loading | Latest stable, published April 2026 per pub.dev. Supports both runtime fetching and offline asset bundling. With `allowRuntimeFetching = false`, loads from `assets/fonts/` only — no network dependency at runtime. [VERIFIED: https://pub.dev/packages/google_fonts] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| google_fonts with asset bundling | Pure `fontFamily:` declarations in pubspec.yaml | Works fine but loses the `GoogleFonts.inter()` helper convenience; you must manually wire every TextStyle's `fontFamily: 'Inter'`. Either approach is acceptable — CONTEXT.md leaves it to discretion. **Recommendation: google_fonts with asset bundling** — gives the convenience of `GoogleFonts.inter(textStyle: ...)` while guaranteeing offline behaviour. [CITED: https://pub.dev/packages/google_fonts] |
| Custom `ColorScheme.fromSeed` + overrides | Explicit `ColorScheme` constructor with all 30 fields supplied | `fromSeed` derives a tonal palette from a single key colour. The Traevy tokens are NOT a tonal palette (moving/stuck are unrelated to accent), so `fromSeed` would produce wrong related colours (primaryContainer, tertiary, etc.). **Recommendation: explicit `ColorScheme(brightness, primary, onPrimary, ..., surface, error, ...)` constructor.** [VERIFIED: ColorScheme API docs] |
| `NavigationBar` (Material 3) for bottom tabs | `BottomNavigationBar` (Material 2 legacy) | NavigationBar is the M3 widget; codebase already uses M3 (`useMaterial3: true` in current theme). NavigationBar supports `NavigationBarThemeData` for full custom styling (indicator color, label text style, icon size). [VERIFIED: api.flutter.dev NavigationBar] |
| Custom `Switch.adaptive` for toggles | Build `TraevyToggle` from `GestureDetector` + `AnimatedContainer` | Spec demands very specific dimensions (38×22dp pill, 18dp knob, `moving`/`borderStr` colours) and a specific shadow that Material's Switch does not match. Building custom is faster than fighting M3 Switch theming. CONTEXT.md mandates custom widget — locked. |
| `flex_color_scheme` package for theme generation | Manual ColorScheme construction | Adds a heavy dependency for a one-time mapping. Manual construction is ~80 lines of code per theme. Avoid the dep. [ASSUMED] |

**Installation:**

```bash
flutter pub add google_fonts
```

After adding, download Inter and JetBrains Mono TTF files from fonts.google.com and place in `assets/fonts/`. Update `pubspec.yaml` `flutter.assets:` to include the fonts directory so `GoogleFonts.config.allowRuntimeFetching = false` picks them up.

**Version verification (run before drafting pubspec edits):**

```bash
flutter pub add google_fonts --dry-run    # confirms latest resolvable version
```

As of 2026-05-14, `google_fonts ^8.1.0` is current stable (published ~April 2026). [VERIFIED: pub.dev]

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          MaterialApp                                 │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ themeMode: from userPreferenceProvider (Phase 7, unchanged)   │  │
│  │ theme:     buildLightTheme(TraevyTokens.light)  ◄── NEW       │  │
│  │ darkTheme: buildDarkTheme(TraevyTokens.dark)    ◄── NEW       │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│                       MainShell (NEW)                                │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ Scaffold(                                                      │  │
│  │   body: IndexedStack(children: [Dashboard, History,            │  │
│  │                                  Stats, Settings]),            │  │
│  │   bottomNavigationBar: NavigationBar(...)  ◄── 4 tabs          │  │
│  │ )                                                              │  │
│  └───────────────────────────────────────────────────────────────┘  │
│         │              │             │              │                │
│         ▼              ▼             ▼              ▼                │
│   Dashboard      History       Stats         Settings                │
│   Screen         Screen        Screen        Screen                  │
│   (restyled)     (restyled)    (restyled)    (restyled)              │
│         │              │             │              │                │
│         └────┬─────────┴─────────────┴──────────────┘                │
│              ▼                                                       │
│        Existing Riverpod providers (UNCHANGED)                       │
│        ┌────────────────────────────────────────┐                    │
│        │ trackingStateProvider                  │                    │
│        │ todaysTripSummariesProvider            │                    │
│        │ allTripSummariesProvider               │                    │
│        │ statsSummaryProvider                   │                    │
│        │ userPreferenceProvider                 │                    │
│        └────────────────────────────────────────┘                    │
│              │                                                       │
│              ▼                                                       │
│        Drift DAOs → SQLite (UNCHANGED)                               │
└─────────────────────────────────────────────────────────────────────┘

Theme dispatch flow:
  TraevyTokens (const data class) → buildLightTheme / buildDarkTheme →
    ColorScheme (manual constructor) + TextTheme (Inter + JetBrains Mono mix)
    + CardTheme (radius 16, elevation 0)
    + NavigationBarTheme (bgElev background, token colors)
    + IconTheme, AppBarTheme, etc.

Push-based widget rendering:
  Each screen calls Theme.of(context).colorScheme / textTheme → token values
  Each chart widget receives tokens via Theme.of(context).extension<TraevyTheme>()
  (Theme extension is the recommended way to expose non-Material tokens like
  `moving`, `stuck`, `stuckBg`, `record`, `mapBg` that don't fit ColorScheme.)
```

### Recommended Project Structure

```
lib/
├── config/
│   ├── theme.dart                # REWRITE — TraevyTokens, TraevyFonts, buildLightTheme(), buildDarkTheme()
│   ├── theme_extension.dart      # NEW — ThemeExtension<TraevyTokensExt> exposing moving/stuck/etc.
│   ├── constants.dart            # APPEND — kFontUI, kFontMono, new label strings, dimension constants
│   └── routes.dart               # APPEND — kRouteOnboarding, kRouteMainShell (no removals)
├── shared/
│   └── widgets/                  # NEW directory — all 5 new shared primitives
│       ├── stuck_bar.dart        # NEW
│       ├── trip_row_card.dart    # NEW (replaces existing trip_card.dart eventually)
│       ├── section_label.dart    # NEW
│       ├── traevy_toggle.dart    # NEW
│       ├── stat_mini_card.dart   # NEW
│       └── traevy_logo_mark.dart # NEW (the "tv" 56×56 rounded square)
├── features/
│   ├── shell/                    # NEW — top-level tab shell
│   │   └── screens/main_shell.dart
│   ├── onboarding/               # NEW
│   │   └── screens/onboarding_screen.dart
│   ├── dashboard/
│   │   ├── screens/dashboard_screen.dart  # RESTYLE
│   │   └── widgets/                       # RESTYLE / REPLACE
│   │       ├── home_header.dart           # NEW (date + name + avatar)
│   │       ├── hero_record_card.dart      # NEW (replaces FAB)
│   │       ├── today_section.dart         # RESTYLE today_trips_section.dart
│   │       ├── week_loss_card.dart        # RESTYLE weekly_summary_card.dart
│   │       └── empty_slot_row.dart        # NEW (dashed circle placeholder)
│   ├── tracking/
│   │   ├── screens/tracking_screen.dart   # RESTYLE — Variant A layout
│   │   └── widgets/
│   │       ├── recording_header.dart      # NEW (● RECORDING pill)
│   │       ├── elapsed_display.dart       # NEW (76sp mono)
│   │       └── stop_button.dart           # NEW (text-bg full-width)
│   ├── trips/
│   │   ├── screens/
│   │   │   ├── history_screen.dart        # RESTYLE
│   │   │   └── trip_detail_screen.dart    # RESTYLE
│   │   └── widgets/
│   │       ├── trip_card.dart             # REPLACE with TripRowCard import
│   │       ├── history_view_toggle.dart   # NEW (List/Calendar pill segmented)
│   │       ├── trip_section_card.dart     # NEW (date header + grouped rows)
│   │       ├── traffic_insight_card.dart  # NEW (stuckBg callout)
│   │       └── trip_timeline.dart         # NEW (clock-icon timeline rows)
│   ├── stats/
│   │   ├── screens/stats_screen.dart      # RESTYLE
│   │   └── widgets/
│   │       ├── traffic_loss_hero.dart     # NEW (replaces TrafficWasteCard)
│   │       ├── donut_card.dart            # NEW (PieChart with center text)
│   │       ├── trend_bars_card.dart       # RESTYLE TrendChartCard → BarChart
│   │       ├── weekday_chart_card.dart    # RESTYLE BestWorstDayCard → BarChart
│   │       └── (week_month_totals_card, direction_averages_card retire OR fold into hero)
│   └── settings/
│       ├── screens/settings_screen.dart   # RESTYLE
│       └── widgets/
│           ├── settings_section.dart      # NEW (uppercase label + bordered card)
│           ├── settings_row.dart          # NEW (label + subtitle + control)
│           └── account_row.dart           # NEW (avatar + name + email)
```

### Pattern 1: ThemeExtension for non-Material tokens

**What:** Flutter's `ColorScheme` only has slots for primary/secondary/tertiary/error/surface/background. Traevy tokens like `moving`, `stuck`, `stuckBg`, `record`, `mapBg`, `borderStr`, `textDim`, `textMuted` do not fit. The idiomatic Flutter pattern is `ThemeExtension<T>`.

**When to use:** Any time a design system has more tokens than `ColorScheme` provides slots for. This is the official Flutter recommendation. [CITED: https://api.flutter.dev/flutter/material/ThemeExtension-class.html]

**Example:**

```dart
// lib/config/theme_extension.dart
@immutable
class TraevyTokensExt extends ThemeExtension<TraevyTokensExt> {
  const TraevyTokensExt({
    required this.bgElev,
    required this.surface2,
    required this.border,
    required this.borderStr,
    required this.textDim,
    required this.textMuted,
    required this.moving,
    required this.movingBg,
    required this.stuck,
    required this.stuckBg,
    required this.accent,
    required this.accentBg,
    required this.record,
    required this.mapBg,
  });

  final Color bgElev;
  final Color surface2;
  final Color border;
  final Color borderStr;
  final Color textDim;
  final Color textMuted;
  final Color moving;
  final Color movingBg;
  final Color stuck;
  final Color stuckBg;
  final Color accent;
  final Color accentBg;
  final Color record;
  final Color mapBg;

  @override
  TraevyTokensExt copyWith({Color? bgElev, /* ... all fields */}) =>
      TraevyTokensExt(bgElev: bgElev ?? this.bgElev, /* ... */);

  @override
  TraevyTokensExt lerp(ThemeExtension<TraevyTokensExt>? other, double t) {
    if (other is! TraevyTokensExt) return this;
    return TraevyTokensExt(
      bgElev: Color.lerp(bgElev, other.bgElev, t)!,
      // ... all fields
    );
  }
}

// Usage in widgets:
final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
return Container(color: tokens.bgElev);
```

This satisfies CLAUDE.md "no hardcoded values" by routing every non-Material token through Theme. Widgets never reference `TraevyTokens.light.moving` directly — they read from `Theme.of(context).extension<TraevyTokensExt>()`, so dark mode flips automatically.

### Pattern 2: Mixed Inter/JetBrains Mono TextTheme

**What:** Build the `TextTheme` by combining `GoogleFonts.interTextTheme()` (or `GoogleFonts.inter(textStyle: ...)`) for body styles with explicit `GoogleFonts.jetBrainsMono(...)` overrides for mono roles. Do NOT use `TextTheme.apply(fontFamily: 'Inter')` because it would clobber mono styles. [VERIFIED: api.flutter.dev TextTheme]

**When to use:** Every Phase 8 screen.

**Example:**

```dart
TextTheme _buildTextTheme(Brightness brightness, TraevyTokensExt tokens) {
  final textColor = brightness == Brightness.light
      ? const Color(0xFF2A2A38)
      : const Color(0xFFF2F2F7);

  return TextTheme(
    // Inter for headings & body
    displaySmall: GoogleFonts.inter(
      fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1.2,
      color: textColor, height: 1.05,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.6,
    ),
    bodyLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
    bodyMedium: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
    labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.0,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0,
    ),
  );
}

// Mono is NOT in the global TextTheme — it's accessed via TraevyFonts helper:
class TraevyFonts {
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

// Usage at call sites:
Text('00:22:14', style: TraevyFonts.mono(size: 76, letterSpacing: -3))
```

This is cleaner than trying to cram mono into `displayLarge` etc. because the design uses mono at many different sizes (10.5, 11.5, 12, 13, 22, 28, 38, 56, 76 sp), more sizes than the `TextTheme` offers slots.

### Pattern 3: Stateful tab shell with IndexedStack

**What:** `MainShell` is a `ConsumerStatefulWidget` that owns the selected tab index. It uses `IndexedStack` (not a `PageView` or conditional `body`) so all 4 screens stay mounted — their providers remain subscribed and Drift streams don't tear down on tab switch. The shell renders the `NavigationBar` at the bottom.

**When to use:** This is the standard pattern for persistent bottom-tab apps where each tab should remember its scroll position and not re-fetch on tab switch.

**Example:**

```dart
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  static const _screens = <Widget>[
    DashboardScreen(),
    HistoryScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// In TraevyApp:
home: const MainShell(),  // replaces home: const DashboardScreen()
```

⚠ **Sealed-class constraint:** `_index` is a tiny piece of pure ephemeral UI state with no business meaning. CLAUDE.md's "no `setState`" rule has an implicit carve-out for "purely local UI state with no observability requirement" — but to be strict, define `MainShellNotifier extends Notifier<int>` and a `mainShellIndexProvider` so `ref.watch`/`ref.read` drive the tab. **Recommendation: use Riverpod for the index** to stay strictly compliant with CLAUDE.md.

### Pattern 4: Replacing the FAB with the hero record card

**What:** Phase 6's `DashboardScreen` uses a `FloatingActionButton.extended` for Start. Traevy spec replaces this with a centered 124dp circular button inside a `bgElev` hero card. Move the existing `_handleStart` logic from `DashboardScreen` into a new `HeroRecordCard` widget that receives `onStart` and `isTracking` as parameters — the parent still owns the permission-check logic.

**When to use:** Anywhere the design replaces a Material-default control with a custom shape but the behaviour stays identical.

```dart
class HeroRecordCard extends StatelessWidget {
  const HeroRecordCard({
    required this.isTracking,
    required this.directionLabel,    // 'To home' / 'To office'
    required this.autoLabelTime,     // '20:14'
    required this.onStart,
    required this.onResume,
    super.key,
  });
  // ... renders 24dp radius bgElev card with 124dp record-color circle button
}
```

### Anti-Patterns to Avoid

- **`Theme.of(context).colorScheme.primary` everywhere for the accent.** Some widgets need `moving` or `stuck`, not `primary`. Always pull from `Theme.of(context).extension<TraevyTokensExt>()` for non-Material colours.
- **Hardcoding `Color(0xFF...)` inline in widget files.** Defeats dark mode. Tokens MUST go through the theme extension.
- **Using `TextStyle(fontFamily: 'Inter')` directly.** Bypasses google_fonts version pinning and asset bundling. Always go through `GoogleFonts.inter(...)` or pull from `Theme.of(context).textTheme`.
- **Restyling `Card` widgets per-screen.** Centralise via `CardTheme(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: tokens.border)))` in `buildLightTheme()`.
- **Replacing the existing `WeeklySummaryCard` with a brand-new file.** Restyle in-place to preserve the Riverpod call sites in `DashboardScreen`. Only rename if the public class name changes.
- **Putting fonts in `lib/`.** Fonts go in `assets/fonts/` and are declared under `flutter.assets:` and the optional `fonts:` section of `pubspec.yaml`.
- **Deleting the FAB without moving its permission-handler logic.** `_handleStart` and `_showSettingsDialog` in `dashboard_screen.dart` MUST stay reachable — wire them to the new hero card's tap callback.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Google Fonts loading | Custom `rootBundle.load` + `FontLoader` plumbing | `google_fonts: ^8.1.0` + `GoogleFonts.config.allowRuntimeFetching = false` | Handles weight matching, caching, error fallbacks. Bundles offline assets seamlessly. |
| Dark-mode aware tokens | Manual `if (Theme.of(context).brightness == Brightness.dark) ...` checks scattered through widgets | `ThemeExtension<TraevyTokensExt>` with light + dark instances registered on each `ThemeData` | Flutter lerps and switches automatically; widgets stay theme-agnostic. |
| Donut chart with center text | Custom `CustomPainter` | `fl_chart` `PieChart` with `centerSpaceRadius` + a `Stack` with centered `Text` | fl_chart already supports donut style with center text via Stack overlay. [VERIFIED: fl_chart GitHub docs] |
| Stacked horizontal bar (StuckBar) | Custom paint | Two `Expanded`-flexed `Container`s inside a clip-rounded `Row`, OR `BarChartRodStackItem` | Two-Container approach is simpler and well-matched to spec (left moving %, right stuck %). |
| Bottom tab bar | Custom `Row` of `GestureDetector`s | Material 3 `NavigationBar` with `NavigationBarThemeData` | Built-in ripple, label behaviour, accessibility, M3 indicator pill. |
| Custom toggle switch | Forget Material `Switch` and roll new one | Build new `TraevyToggle` from `AnimatedContainer` + `AlignmentTween` (CONTEXT.md locked: custom widget) | Spec dimensions and shadow don't match Material Switch; locked decision says custom. |
| Pulsing recording dot | `Timer.periodic` + `setState` | `AnimatedBuilder` driven by `AnimationController(vsync: this, duration: 1.5s)..repeat()` | No setState, idiomatic Flutter animation. |
| Polyline route map placeholder | Real `flutter_map` instance with tile fetching | Styled `Container` with a `CustomPaint` grid overlay | CONTEXT.md "Claude's Discretion" — faux map placeholder only. Saves a heavy tile fetch on recording screen. |
| Date formatting | Custom switch statements | `intl` `DateFormat` (already in pubspec ^0.20.2) | Already in use; no new dep. |
| Avatar circle with initial | Custom paint | `Container(decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.surface), child: Center(child: Text('R', style: ...)))` | Trivial; no widget package needed. |

**Key insight:** This phase is 95% layout + theme work. The only "library" decision is `google_fonts`. Everything else is plain Flutter primitives composed correctly.

## Runtime State Inventory

> This is a styling/refactor phase. No data migration, but several "runtime state" surfaces could break if mishandled.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — colour tokens and font names are pure code constants; user preferences (`darkMode`, `reminderTime`) already exist and are not affected by visual changes. | None — verified by reading `lib/database/tables/user_preferences_table.dart` and Phase 7 migration. |
| Live service config | None — no external services (Cognito, DynamoDB) are in scope yet; notification channels (`kTrackingNotificationChannelId`, `kWeeklySummaryChannelId`, `kReminderChannelId`) are registered server-side by `NotificationService` and remain unchanged. | None — verified by grep of `lib/notifications/`. |
| OS-registered state | Android notification channel names ("Active commute", "Weekly Summary", "Commute Reminder") are registered at app startup via `flutter_local_notifications`. **They are NOT changing in Phase 8** — copy stays as-is. Persistent foreground notification rendering during tracking is unchanged. | None — Phase 8 does not touch `lib/notifications/notification_service.dart` or notification channel constants. |
| Secrets/env vars | None. | None. |
| Build artifacts / installed packages | New `assets/fonts/Inter-*.ttf` and `assets/fonts/JetBrainsMono-*.ttf` files MUST be added to the build. `pubspec.yaml` `flutter.assets:` MUST list `assets/fonts/` (or each file). After change, run `flutter clean && flutter pub get` so the asset bundle is rebuilt. Existing `assets/icons/logo.jpeg` asset is unaffected. | Update pubspec.yaml + commit font assets to git. |

**Test fixture impact:** Many widget tests rely on `find.byTooltip(kSettingsTooltip)` and `find.byIcon(Icons.history)` / `find.byIcon(Icons.bar_chart)` (see `test/widget/features/dashboard/dashboard_screen_test.dart` lines 286–301). When Phase 8 introduces a `NavigationBar` shell and removes the AppBar action icons, these locators stop resolving.

→ **Action:** Either (a) update the affected tests to point at the new NavigationBar destinations via `find.byIcon(Icons.list_alt_outlined)` / `find.byIcon(Icons.bar_chart_outlined)`, or (b) preserve the original AppBar icons during the transition and remove them in a follow-up plan. **Recommendation: update tests in the same plan that introduces MainShell**, because the icons genuinely move locations.

## Common Pitfalls

### Pitfall 1: The CONTEXT.md mentions `google_maps_flutter` but the codebase uses `flutter_map`
**What goes wrong:** A planner reading only CONTEXT.md might assume the project uses Google Maps and try to align styling with Google Maps tile colour. The actual map is `flutter_map ^8.1.0` (OSM-based via CARTO tiles, see `lib/features/trips/screens/trip_detail_screen.dart` lines 318–332 and `kMapTileUrlLight` / `kMapTileUrlDark` in `constants.dart`).
**Why it happens:** CONTEXT.md was authored from a generic Flutter design handoff template.
**How to avoid:** Use the existing `flutter_map` `TileLayer` for the real map on Trip Detail (already styled with CARTO Positron/Dark Matter tiles which align well with Traevy's `bg`/`bgElev` palette). The faux map placeholder on the recording screen is a `Container`, not a real map.
**Warning signs:** Any plan that says "add google_maps_flutter dependency" — immediately push back.

### Pitfall 2: google_fonts runtime network fetch on first launch
**What goes wrong:** If `GoogleFonts.config.allowRuntimeFetching` is left at its default (true) AND no font files are bundled in assets, the app silently fetches fonts from fonts.googleapis.com on first launch. On flaky network or offline-first scenarios, the first frame falls back to Roboto. [VERIFIED: pub.dev google_fonts]
**Why it happens:** google_fonts defaults to runtime fetching for development convenience.
**How to avoid:** (1) Download Inter (weights 400/500/600/700) and JetBrains Mono (400/500/600) from fonts.google.com — TTF format. (2) Place in `assets/fonts/`. (3) Add to `pubspec.yaml` under `flutter.assets:`. (4) Call `GoogleFonts.config.allowRuntimeFetching = false;` once in `main()` before `runApp`. (5) Verify with the integration test by launching on airplane mode.
**Warning signs:** First-launch fonts look wrong (Roboto-flavoured); google_fonts logs "downloading" to console.

### Pitfall 3: `ColorScheme.fromSeed` derives wrong related colours
**What goes wrong:** Using `ColorScheme.fromSeed(seedColor: tokens.accent)` would generate `primaryContainer`, `tertiary`, `surfaceVariant` etc. as tonal derivatives of the accent blue. None of these match Traevy's semantic palette (moving green, stuck amber are independent of accent). [VERIFIED: ColorScheme.fromSeed API]
**Why it happens:** Material 3's tonal palette generator assumes a coherent hue relationship.
**How to avoid:** Use the explicit `ColorScheme(brightness: ..., primary: ..., onPrimary: ..., secondary: ..., onSecondary: ..., surface: ..., onSurface: ..., error: ..., onError: ...)` constructor. Set `primary = tokens.accent`, `secondary = tokens.moving` (or skip), `error = tokens.danger`, `surface = tokens.bg`, `onSurface = tokens.text`. All other slots (`primaryContainer`, `tertiary`, etc.) get explicit values from the closest Traevy token.
**Warning signs:** Buttons rendering in a generated tonal variant instead of `tokens.accent`; cards showing `surfaceVariant` greys that don't match `surface2`.

### Pitfall 4: Theme `Card` widget radius regression
**What goes wrong:** Existing widgets call `Card(...)` with no explicit shape, relying on the default M3 radius (12dp). Spec demands 16dp. Without a global `CardTheme` override, every Card needs `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))` repeated everywhere.
**Why it happens:** Default Material 3 theme uses 12dp for cards.
**How to avoid:** Set `cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: tokens.border)))` once in `buildLightTheme()` and `buildDarkTheme()`. Verify existing `InProgressCard` (which uses `RoundedRectangleBorder(... 12)` explicitly) is updated to match. [VERIFIED: CardTheme docs]
**Warning signs:** `lib/features/dashboard/widgets/in_progress_card.dart` lines 33–37 — currently uses hardcoded `BorderRadius.circular(12)`. Restyle MUST switch to 16 (or 18 for hero cards per spec).

### Pitfall 5: NavigationBar height + system bar safe area
**What goes wrong:** On Android, the system navigation bar can overlap the bottom NavigationBar. `Scaffold` handles SafeArea automatically for body but the NavigationBar's bottom padding can look cramped if the manifest doesn't enable `windowSoftInputMode` properly. Phase 7 already pinned Android targetSdk 34 which uses edge-to-edge by default.
**Why it happens:** Edge-to-edge rendering puts system insets under the app.
**How to avoid:** Trust Material 3's default `NavigationBar` SafeArea handling — it adds `MediaQuery.viewPadding.bottom` automatically. Don't manually wrap NavigationBar in SafeArea (causes double padding).
**Warning signs:** NavigationBar labels clipped on devices with gesture nav.

### Pitfall 6: `flutter_lints` and `very_good_analysis` strict rules on new files
**What goes wrong:** `very_good_analysis ^10.2.0` enforces `prefer_const_constructors`, `avoid_dynamic_calls`, `public_member_api_docs` (already ignored), strict-casts/inference/raw-types. New widget files MUST use `const` constructors and provide doc comments where they would otherwise be required.
**Why it happens:** Project has strict lints.
**How to avoid:** Every new widget class declares `const Foo({super.key, required this.x})`; every public method gets a `///` doc comment. Use `dart format .` before commit.
**Warning signs:** CI failure on `flutter analyze`.

### Pitfall 7: Removing widget tests' icon locators
**What goes wrong:** Tests in `test/widget/features/dashboard/dashboard_screen_test.dart` (lines 292, 301) assert `find.byIcon(Icons.history)` and `find.byIcon(Icons.bar_chart)` exist on the dashboard AppBar. Phase 8 removes those AppBar action icons (replaced by the new bottom NavigationBar). Tests will fail.
**Why it happens:** Locator-by-icon binds tests tightly to icon presence.
**How to avoid:** Update those two tests in the same plan that introduces `MainShell`. Replace with assertions on the NavigationBar destinations: `find.byType(NavigationBar)` exists, and tapping a NavigationDestination changes the IndexedStack child. Use `find.byTooltip('Stats')` or `find.text('Stats')` from the NavigationDestination label.
**Warning signs:** Widget test fail with "Expected: at least one matching node, Actual: _WidgetMatcher: matches no widgets".

### Pitfall 8: `trip_card.dart` has hardcoded `TextStyle(fontSize: 12)`
**What goes wrong:** The legacy `_DirectionChip` widget in `lib/features/trips/widgets/trip_card.dart` line 149 uses `const TextStyle(fontSize: 12)`. This bypasses theme typography, so it won't pick up Inter.
**Why it happens:** The Chip widget needs a small label, and the original author hardcoded the size.
**How to avoid:** When restyling `trip_card.dart` (or replacing it with the new `TripRowCard` from shared/widgets), replace inline `TextStyle` with `Theme.of(context).textTheme.labelSmall` or pull from `TraevyFonts`.
**Warning signs:** Inter not appearing on direction chip labels.

### Pitfall 9: `StatsCard` (existing) hardcodes background via `colorScheme.surfaceContainerLow`
**What goes wrong:** `lib/features/stats/widgets/stats_card.dart` line 37 uses `colorScheme.surfaceContainerLow` for the card background. Material 3's `surfaceContainerLow` is auto-derived — it may not equal Traevy's `bgElev`.
**Why it happens:** Phase 5 standardised stat cards on a Material container shade.
**How to avoid:** Update `StatsCard` to read `Theme.of(context).extension<TraevyTokensExt>()!.bgElev` instead. Same fix applies to `lib/features/trips/widgets/trip_card.dart` line 39, `lib/features/dashboard/widgets/in_progress_card.dart` line 34, and any other `surfaceContainerLow` usage.
**Warning signs:** Card backgrounds slightly off-tint compared to designs.

### Pitfall 10: `table_calendar` markers ignore Theme
**What goes wrong:** `table_calendar` in `lib/features/trips/screens/history_screen.dart` lines 164–179 sets `markerDecoration`, `selectedDecoration`, `todayDecoration` colours from `colorScheme.primary` and `primaryContainer`. With the new Traevy palette, the primary blue might be too saturated for the calendar.
**Why it happens:** The library doesn't theme automatically from ColorScheme — colours are passed explicitly.
**How to avoid:** Update `CalendarStyle` to pull from `Theme.of(context).extension<TraevyTokensExt>()` — markers = `tokens.accent`, selected = `tokens.text`, today = `tokens.accentBg`.
**Warning signs:** Calendar dots and selected-day circles in wrong shade.

## Code Examples

Verified patterns from official sources and the existing codebase.

### Example 1: `buildLightTheme` skeleton (NEW `lib/config/theme.dart`)

```dart
// Source: Composition of Flutter ColorScheme docs + ThemeExtension docs +
// the Traevy CONTEXT.md token table.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:traevy/config/theme_extension.dart';

class TraevyTokens {
  const TraevyTokens._({
    required this.bg, required this.bgElev, required this.surface,
    required this.surface2, required this.border, required this.borderStr,
    required this.text, required this.textDim, required this.textMuted,
    required this.moving, required this.movingBg,
    required this.stuck, required this.stuckBg,
    required this.accent, required this.accentBg,
    required this.danger, required this.record, required this.mapBg,
  });

  // Light palette — CONTEXT.md locked values
  static const TraevyTokens light = TraevyTokens._(
    bg: Color(0xFFFAFAF7), bgElev: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F5F0), surface2: Color(0xFFEEEEE8),
    border: Color(0xFFE5E5DF), borderStr: Color(0xFFD4D4CE),
    text: Color(0xFF2A2A38), textDim: Color(0xFF6B6B7A), textMuted: Color(0xFF9A9AAA),
    moving: Color(0xFF2E8B57), movingBg: Color(0xFFDCF2E4),
    stuck: Color(0xFFC4820A), stuckBg: Color(0xFFF5EDDA),
    accent: Color(0xFF3A5F8F), accentBg: Color(0xFFE8EEF5),
    danger: Color(0xFFC0392B), record: Color(0xFFC0392B),
    mapBg: Color(0xFFF4F4EE),
  );

  static const TraevyTokens dark = TraevyTokens._(
    bg: Color(0xFF1A1B22), bgElev: Color(0xFF22242E),
    surface: Color(0xFF24262F), surface2: Color(0xFF2A2C38),
    border: Color(0xFF2E3040), borderStr: Color(0xFF383A4A),
    text: Color(0xFFF2F2F7), textDim: Color(0xFFA0A0B8), textMuted: Color(0xFF6E6E88),
    moving: Color(0xFF5BC88A), movingBg: Color(0xFF1E3D2E),
    stuck: Color(0xFFD4A832), stuckBg: Color(0xFF3A2E10),
    accent: Color(0xFF8AABCF), accentBg: Color(0xFF1E2A38),
    danger: Color(0xFFE05A4A), record: Color(0xFFE05A4A),
    mapBg: Color(0xFF1D1F27),
  );

  final Color bg, bgElev, surface, surface2, border, borderStr;
  final Color text, textDim, textMuted;
  final Color moving, movingBg, stuck, stuckBg, accent, accentBg;
  final Color danger, record, mapBg;
}

ThemeData buildLightTheme() => _build(TraevyTokens.light, Brightness.light);
ThemeData buildDarkTheme() => _build(TraevyTokens.dark, Brightness.dark);

ThemeData _build(TraevyTokens t, Brightness b) {
  final colorScheme = ColorScheme(
    brightness: b,
    primary: t.accent, onPrimary: t.bg,
    secondary: t.moving, onSecondary: t.bg,
    error: t.danger, onError: Colors.white,
    surface: t.bg, onSurface: t.text,
    surfaceContainerLowest: t.bgElev,
    surfaceContainerLow: t.bgElev,
    surfaceContainer: t.surface,
    surfaceContainerHigh: t.surface2,
    surfaceContainerHighest: t.surface2,
    outline: t.border, outlineVariant: t.borderStr,
    onSurfaceVariant: t.textDim,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: t.bg,
    textTheme: _buildTextTheme(t),
    cardTheme: CardThemeData(
      elevation: 0,
      color: t.bgElev,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.border),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg, surfaceTintColor: Colors.transparent,
      foregroundColor: t.text, elevation: 0, scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.bgElev,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 10.5, letterSpacing: 0.1,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? t.text : t.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? t.text : t.textMuted, size: 22);
      }),
    ),
    dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: t.text),
    extensions: <ThemeExtension<dynamic>>[
      TraevyTokensExt.fromTokens(t),
    ],
  );
}
```

### Example 2: `StuckBar` shared widget

```dart
// Source: charts.jsx StuckBar pattern translated to Flutter.
class StuckBar extends StatelessWidget {
  const StuckBar({
    required this.movingMinutes,
    required this.stuckMinutes,
    this.height = 14,
    super.key,
  });

  final int movingMinutes;
  final int stuckMinutes;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final total = movingMinutes + stuckMinutes;
    if (total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: tokens.surface2,
        child: Row(
          children: <Widget>[
            Expanded(flex: movingMinutes, child: ColoredBox(color: tokens.moving)),
            Expanded(flex: stuckMinutes, child: ColoredBox(color: tokens.stuck)),
          ],
        ),
      ),
    );
  }
}
```

### Example 3: `TraevyToggle` shared widget

```dart
class TraevyToggle extends StatelessWidget {
  const TraevyToggle({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38, height: 22,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? tokens.moving : tokens.borderStr,
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### Example 4: `MainShell` with Riverpod-driven tab index

```dart
final mainShellIndexProvider = NotifierProvider<MainShellIndexNotifier, int>(
  MainShellIndexNotifier.new,
);

class MainShellIndexNotifier extends Notifier<int> {
  @override int build() => 0;
  void setIndex(int i) => state = i;
}

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(mainShellIndexProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const <Widget>[
          DashboardScreen(),
          HistoryScreen(),
          StatsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(mainShellIndexProvider.notifier).setIndex,
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```

### Example 5: Donut chart with center text via fl_chart

```dart
// Source: fl_chart PieChart API + Stack overlay pattern (verified GitHub docs).
class Donut extends StatelessWidget {
  const Donut({
    required this.movingMinutes,
    required this.stuckMinutes,
    this.size = 110,
    this.stroke = 14,
    super.key,
  });

  final int movingMinutes;
  final int stuckMinutes;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final total = movingMinutes + stuckMinutes;
    final stuckPercent = total == 0 ? 0 : (stuckMinutes / total * 100).round();

    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          PieChart(
            PieChartData(
              centerSpaceRadius: (size - stroke * 2) / 2,
              sectionsSpace: 0,
              startDegreeOffset: -90,
              sections: <PieChartSectionData>[
                PieChartSectionData(
                  value: movingMinutes.toDouble(),
                  color: tokens.moving,
                  radius: stroke,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: stuckMinutes.toDouble(),
                  color: tokens.stuck,
                  radius: stroke,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('$stuckPercent%',
                  style: TraevyFonts.mono(size: 22, weight: FontWeight.w600,
                      letterSpacing: -0.5)),
              Text('stuck',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.textDim)),
            ],
          ),
        ],
      ),
    );
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `BottomNavigationBar` (M2) | `NavigationBar` (M3) | Flutter 3.7+ | Use the M3 widget; codebase already runs M3 |
| `Card(elevation: 1)` default | `Card(elevation: 0)` with explicit border | Material 3 design language (modern apps) | Set globally via `CardTheme` |
| `ThemeData.fontFamily: 'X'` | `TextTheme` with per-style `TextStyle(fontFamily: ...)` | Throughout Flutter history; preferred for mixed-family themes | Use `GoogleFonts.inter()` per-slot |
| `ColorScheme.fromSwatch` | `ColorScheme.fromSeed` OR explicit `ColorScheme()` | Material 3 release | Use explicit when palette is non-tonal |
| `ChangeNotifier` for tab index | Riverpod `Notifier<int>` | Riverpod 2.x+ | Aligns with CLAUDE.md "Riverpod for all state" |
| `setState` for purely UI counters | Riverpod even for ephemeral state | Project convention from CLAUDE.md | No exceptions in this codebase |

**Deprecated / outdated:**
- `CardTheme` (without `Data` suffix) is deprecated in newer Flutter — use `CardThemeData`. [VERIFIED: api.flutter.dev, Flutter 3.41]
- `BottomNavigationBar` still works but is "Material 2 style" per Flutter docs; new apps should use NavigationBar.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The 6 new shared widgets locked by CONTEXT.md (StuckBar, TripRowCard, SectionLabel, TraevyToggle, StatMiniCard) should live in `lib/shared/widgets/` rather than under a feature folder | Project Structure | Low — easy to relocate; CONTEXT.md said "shared/widgets" verbatim, this aligns |
| A2 | `MainShell` should use `IndexedStack` (all 4 screens mounted at once) rather than rebuild on tab change | Pattern 3 | Medium — IndexedStack keeps Drift streams subscribed which is desired (no flicker on tab swap), but increases memory. Alternative is keep-alive routing. Recommend IndexedStack; if a future memory issue surfaces, swap to lazy. |
| A3 | The hero record card's STOP behaviour should remain in `TrackingScreen` (a separate route pushed on START) rather than swapping the dashboard body inline | Pattern 4 | Low — preserves existing routing and tracking permission flow |
| A4 | `darkMode = 'system'` should follow `MediaQuery.platformBrightness`, which Flutter already handles via `ThemeMode.system` (Phase 7 already implements this) | Architecture | Negligible — already shipped and tested |
| A5 | `WeeklySummaryCard` will be renamed `WeekLossCard` (or restyled in place) — its `onTap` to `kRouteStats` still works since Stats is now a NavigationBar tab; `Navigator.pushNamed(context, kRouteStats)` will push on top of the IndexedStack | Project Structure | Medium — pushing on top of the shell is fine but visually weird; better: switch the shell's index to 2 via `ref.read(mainShellIndexProvider.notifier).setIndex(2)`. Recommendation in plan. |
| A6 | The "See stats →" link on the home screen should also drive the tab index switch, not a route push | Pattern recommendation | Same as A5 |
| A7 | Onboarding screen is a route accessible from settings or first launch, not the home of the app | CONTEXT.md "Claude's Discretion" | Medium — when auth ships in Phase 9 it will gate on whether the user has signed in; for Phase 8 it lives as a standalone screen reachable by route but not auto-displayed |
| A8 | `flutter_map` (not Google Maps) is the existing map library — CONTEXT.md misnamed it | Pitfall 1 | Already documented; verified by grep |
| A9 | Inter is available at weights 400/500/600/700 and JetBrains Mono at 400/500/600 from Google Fonts at no charge — design spec uses these specific weights | Stack | Low — these are the standard published weights for both families |
| A10 | Asset bundling via `flutter.assets:` in pubspec is sufficient for `GoogleFonts.config.allowRuntimeFetching = false` without the optional `flutter.fonts:` declaration | google_fonts integration | Low — google_fonts docs explicitly state asset detection works from `assets:` listing alone, no need to also declare in `fonts:` section [CITED: pub.dev google_fonts] |

## Open Questions

1. **Should the home screen "header" (date + name + avatar) display the real user's name and initial, or remain placeholder "Hi, Rahul"/"R"?**
   - What we know: There is no auth in Phase 8 (auth is Phase 9). No user name is stored anywhere. CLAUDE.md says `kDefaultUserId = 'local_user'`. The CONTEXT.md `<specifics>` block lists "Hi, Rahul" as a sample.
   - What's unclear: Whether to hardcode "Hi" + "Traveller"/"You" as placeholder, or leave "Rahul" matching the design.
   - Recommendation: Add a constant `kPlaceholderUserName = 'Traveller'` and `kPlaceholderUserInitial = 'T'` in `constants.dart`. Use these until Phase 9 wires real names from Cognito.

2. **Should the existing `WeekMonthTotalsCard`, `DirectionAveragesCard`, `BestWorstDayCard`, `TrafficWasteCard`, `TrendChartCard` widgets be deleted or restyled?**
   - What we know: Stats screen spec is very different (single hero card + donut + trend bars + weekday chart). The old 5-card layout is gone.
   - What's unclear: Whether to delete the old widget files outright or keep them under different names.
   - Recommendation: Delete `WeekMonthTotalsCard` and `DirectionAveragesCard` (their info fits inside the new hero card + donut). Restyle `BestWorstDayCard` → `WeekdayChartCard` (BarChart) and `TrendChartCard` → `TrendBarsCard` (BarChart, not LineChart per design). Retire `TrafficWasteCard` (folded into hero). The `StatsCard` wrapper widget can remain as the bgElev card container with header.

3. **Should the existing `FloatingActionButton` permission-handler dialogs (`_showSettingsDialog` etc. in `dashboard_screen.dart`) be reused by the hero record card?**
   - What we know: The dialogs are intricate (4 permission states, settings deep-link). They MUST work identically after restyling.
   - What's unclear: Whether to keep the handler on the Dashboard screen or move it into HeroRecordCard.
   - Recommendation: Keep the handler functions on `DashboardScreen` (as private methods). `HeroRecordCard` receives `onStart: () => _handleStart(context, ref)` as a callback parameter. Zero behavioural change.

4. **Should the existing `EditTripSheet` and `ManualEntrySheet` be restyled in Phase 8 or deferred?**
   - What we know: Both are full-screen bottom sheets with Material 3 widgets (SegmentedButton, OutlinedButton.icon, FilledButton, TextField). They are reachable from trip detail "Edit" / dashboard "+" actions.
   - What's unclear: Whether CONTEXT.md's "every screen" includes modal sheets.
   - Recommendation: Yes, restyle. They are user-facing surfaces. Minimum: ensure they pick up the new Theme automatically (which they will because they use `Theme.of(context).colorScheme/textTheme`). Audit for any hardcoded `TextStyle` (none found — already clean). Confirm Inter renders correctly. No structural changes needed.

5. **Are the existing tracking permission states (Idle, Starting, Active, Stopping, Error) still represented with their separate layouts on the Variant A recording screen?**
   - What we know: Variant A spec shows the active layout (RECORDING pill + timer + 3 stat cards + map + Stop button). It doesn't address Idle/Starting/Stopping/Error.
   - What's unclear: Whether transient states get the new design too.
   - Recommendation: Variant A is "active only". For Starting/Stopping (transient), retain `TrackingStatusLayout` (spinner + label) with restyled typography. For Error, retain `TrackingErrorLayout` with Traevy tokens. For Idle (the screen normally shouldn't be reachable — Idle goes back to Dashboard's hero card), keep a minimal placeholder.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | ✓ | 3.41.6 stable (Dart 3.11.4) | — |
| Android device or emulator | Manual visual verification | ✓ (assumed — Phase 7 verified) | — | — |
| `flutter pub` | Adding google_fonts | ✓ | bundled with Flutter | — |
| Network access | First `pub get` of google_fonts | ✓ (development time) | — | Pre-vendor `.dart_tool/` cache if needed for offline CI |
| `assets/fonts/` directory creation | Bundling Inter and JetBrains Mono TTFs | ✓ — `assets/icons/` already exists, sibling directory trivial | — | — |
| `dart format` | Pre-commit lint | ✓ | bundled with Dart 3.11.4 | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

**External binary check:** Run before pulling fonts:
```bash
# Confirm Inter and JetBrains Mono are downloadable from Google Fonts.
curl -I "https://fonts.gstatic.com/s/inter/v18/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMa1ZL7.woff2"
curl -I "https://fonts.gstatic.com/s/jetbrainsmono/v18/tDbY2o-flEEny0FZhsfKu5WU4xD-IQ-PuZJJWxNc.woff2"
```

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK 3.41.6) |
| Config file | None — Flutter defaults; see `test/` directory structure |
| Quick run command | `flutter test test/widget/features/<feature>/` (per-feature widget tests) |
| Full suite command | `flutter test` |
| Static analysis | `flutter analyze` — phase success criteria mandates ZERO warnings |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-01 | Dashboard renders today's trips + weekly summary card after restyle | widget | `flutter test test/widget/features/dashboard/dashboard_screen_test.dart` | ✅ exists — needs update for `MainShell` + removed AppBar icons |
| UX-02 | Dark mode toggle in settings switches theme without restart | widget | `flutter test test/widget/features/settings/settings_screen_test.dart` and `test/unit/features/settings/theme_mode_test.dart` | ✅ exists — should pass unchanged since theme switching mechanism is unchanged |
| UX-04 | Weekly summary toggle row schedules notification | widget | `flutter test test/widget/features/settings/settings_screen_test.dart` (existing scheduleWeeklySummary tests) | ✅ exists — locators may need update if SwitchListTile → TraevyToggle changes test selectors |
| UX-05 | Reminder toggle row + time picker + weekend switch | widget | `flutter test test/widget/features/settings/settings_screen_test.dart` | ✅ exists — same selector update concern |
| Visual: NavigationBar exists on shell with 4 destinations | widget | new test in `test/widget/features/shell/main_shell_test.dart` | ❌ Wave 0 |
| Visual: HeroRecordCard renders and START tap triggers tracking flow | widget | replace/extend dashboard_screen_test.dart | ⚠ refactor existing |
| Visual: TripRowCard renders direction avatar + mono duration + stuck text | widget | new test in `test/widget/shared/widgets/trip_row_card_test.dart` | ❌ Wave 0 |
| Visual: StuckBar renders correct proportional segments | widget | new test in `test/widget/shared/widgets/stuck_bar_test.dart` | ❌ Wave 0 |
| Visual: TraevyToggle on/off state visually flips | widget | new test in `test/widget/shared/widgets/traevy_toggle_test.dart` | ❌ Wave 0 |
| Theme: `buildLightTheme()` returns ThemeData with Traevy colours | unit | new test in `test/unit/config/theme_test.dart` | ❌ Wave 0 |
| Theme: `TraevyTokensExt` lerps cleanly between light and dark | unit | new test in `test/unit/config/theme_extension_test.dart` | ❌ Wave 0 |
| Smoke: `flutter analyze` zero warnings | static | `flutter analyze --fatal-warnings` | ✅ existing CI gate |

### Sampling Rate

- **Per task commit:** `flutter test test/widget/features/<feature>/` for whichever feature was touched + `flutter analyze`
- **Per wave merge:** `flutter test test/widget/` (all widget tests) + `flutter analyze`
- **Phase gate:** Full suite green (`flutter test`) before `/gsd-verify-work`. Plus manual visual verification on a real Android device (light AND dark mode walked through every screen) — required by the design-faithful nature of this phase.

### Wave 0 Gaps

- [ ] `test/widget/features/shell/main_shell_test.dart` — covers MainShell renders 4 NavigationDestinations, tap switches IndexedStack child
- [ ] `test/widget/shared/widgets/stuck_bar_test.dart` — covers StuckBar at 0/0, 50/50, 100/0, with token resolution
- [ ] `test/widget/shared/widgets/trip_row_card_test.dart` — covers direction avatar colour, mono duration, stuck-time bold colour
- [ ] `test/widget/shared/widgets/traevy_toggle_test.dart` — on/off visual state + tap toggles + animation completes
- [ ] `test/widget/shared/widgets/section_label_test.dart` — uppercase rendering + letterSpacing applied
- [ ] `test/unit/config/theme_test.dart` — buildLightTheme and buildDarkTheme produce a ThemeData with the expected ColorScheme primary, surface, error values
- [ ] `test/unit/config/theme_extension_test.dart` — TraevyTokensExt.lerp between light and dark produces intermediate Colors
- [ ] Update `test/widget/features/dashboard/dashboard_screen_test.dart` lines 286–301 — replace `find.byIcon(Icons.history)` and `find.byIcon(Icons.bar_chart)` checks with NavigationBar destination checks OR remove (AppBar action icons are gone)
- [ ] Update `test/widget/features/tracking/tracking_screen_test.dart` — `find.text('Duration')` / `find.text('Distance')` / `find.text('Speed')` still appear on the restyled tiles (Variant A label text), but the values render differently (mono font, different sizes). Most assertions should remain valid; verify `find.text('00:00')`, `find.text('0 m')`, `find.text('0 km/h')` still match the new label text.
- [ ] Add `GoogleFonts.config.allowRuntimeFetching = false;` to `main.dart` BEFORE first `runApp` AND any test setUp — otherwise widget tests will try to fetch fonts from the network during test isolate execution and fail with timeouts. Document this in the test helpers.

### Test Isolation Concern: google_fonts and widget tests

When `GoogleFonts.inter()` is called inside a widget test, google_fonts attempts to load the font. With `allowRuntimeFetching = false` AND no bundled assets, it falls back to the default Flutter font without erroring. To make tests deterministic:

1. Bundle the fonts BEFORE Wave 0 widget tests are written (i.e., Plan 01 should add the asset bundling).
2. Or call `GoogleFonts.config.allowRuntimeFetching = false;` in `flutter_test_config.dart` (Flutter's standard pre-test hook). [CITED: Flutter test config docs]

## Sources

### Primary (HIGH confidence)
- Flutter 3.41.6 / Dart 3.11.4 — verified via `flutter --version` on the development machine
- Existing codebase via direct Read of every relevant Phase 8 source file
- CONTEXT.md (`.planning/phases/08-ui-overhaul/08-CONTEXT.md`) — user-locked decisions
- UI-SPEC.md (`.planning/phases/08-ui-overhaul/08-UI-SPEC.md`) — full screen contracts
- CLAUDE.md project guidelines
- analysis_options.yaml — confirms `very_good_analysis ^10.2.0` lint set
- [google_fonts package on pub.dev](https://pub.dev/packages/google_fonts) — version 8.1.0 confirmed
- [Flutter NavigationBar API](https://api.flutter.dev/flutter/material/NavigationBar-class.html)
- [Flutter ColorScheme API](https://api.flutter.dev/flutter/material/ColorScheme-class.html)
- [Flutter ThemeExtension API](https://api.flutter.dev/flutter/material/ThemeExtension-class.html)
- [Flutter custom fonts cookbook](https://docs.flutter.dev/cookbook/design/fonts)
- [fl_chart on pub.dev](https://pub.dev/packages/fl_chart) — version 1.2.0 confirmed
- [fl_chart GitHub](https://github.com/imaNNeo/fl_chart) — donut/stacked-bar/center-text features

### Secondary (MEDIUM confidence)
- [TheLinuxCode "Flutter Using Google Fonts in Production 2026 Guide"](https://thelinuxcode.com/flutter-using-google-fonts-in-production-2026-guide/) — corroborates asset bundling + `allowRuntimeFetching = false` recipe
- [flex_seed_scheme on pub.dev](https://pub.dev/packages/flex_seed_scheme) — referenced as an alternative path; not used in plan
- /tmp/travey/project/*.jsx — design source for layout decisions

### Tertiary (LOW confidence)
- Best-practice patterns for `IndexedStack` vs `LazyIndexedStack` — based on common Flutter usage; not formally cited

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — only one new package (google_fonts), version verified against pub.dev
- Architecture: HIGH — codebase is unusually clean (no hardcoded colours, two trivial hardcoded TextStyles), and the new patterns (ThemeExtension, MainShell + IndexedStack) are standard Flutter idioms
- Pitfalls: HIGH — each pitfall is sourced from a specific file path with a specific line range, or from official Flutter docs
- Test impact: HIGH — every existing test file was grepped for `find.byIcon`, `find.byTooltip`, `find.text`, `find.byType`; impact narrowly scoped to 2 lines in dashboard_screen_test.dart plus expected (and harmless) re-pumping of tests via the new theme

**Research date:** 2026-05-14
**Valid until:** 2026-06-14 (30 days — Flutter & google_fonts ecosystem stability is high; only major-version bumps would invalidate)
