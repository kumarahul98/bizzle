# Phase 8: UI Overhaul — UI Design Contract

**Source:** Claude Design handoff (Traevy.html, tokens.jsx, screens-*.jsx)
**Date:** 2026-05-14
**Status:** Locked — implement pixel-faithfully

---

## 1. Design System

### Color Tokens (`TraevyTokens`)

| Token | Light hex | Dark hex | Usage |
|-------|-----------|----------|-------|
| `bg` | `#FAFAF7` | `#1A1B22` | Screen background |
| `bgElev` | `#FFFFFF` | `#22242E` | Cards, bottom bar, sheets |
| `surface` | `#F5F5F0` | `#24262F` | Pill backgrounds, avatar fills |
| `surface2` | `#EEEEE8` | `#2A2C38` | StuckBar track, secondary surfaces |
| `border` | `#E5E5DF` | `#2E3040` | Card borders, dividers |
| `borderStr` | `#D4D4CE` | `#383A4A` | Stronger borders, TrendBar default fill |
| `text` | `#2A2A38` | `#F2F2F7` | Primary text, icons, active tab |
| `textDim` | `#6B6B7A` | `#A0A0B8` | Secondary labels, times, captions |
| `textMuted` | `#9A9AAA` | `#6E6E88` | Section headers, inactive tab labels |
| `moving` | `#2E8B57` | `#5BC88A` | Moving time, best-day bar, toggle-on |
| `movingBg` | `#DCF2E4` | `#1E3D2E` | Moving badge bg, to-home avatar bg |
| `stuck` | `#C4820A` | `#D4A832` | Stuck time, worst-day bar, callout text |
| `stuckBg` | `#F5EDDA` | `#3A2E10` | Traffic callout card bg |
| `accent` | `#3A5F8F` | `#8AABCF` | Links, "See stats →", today bar |
| `accentBg` | `#E8EEF5` | `#1E2A38` | To-office avatar bg |
| `danger` | `#C0392B` | `#E05A4A` | Delete button, destructive actions |
| `record` | `#C0392B` | `#E05A4A` | START button, recording badge, REC text |

### Typography

| Role | Font | Weight | Size |
|------|------|--------|------|
| Screen titles | Inter | 700 | 22sp, letterSpacing -0.6 |
| Section headers | Inter | 600 | 12sp, UPPERCASE, letterSpacing 1 |
| Body / labels | Inter | 400–600 | 13–15sp |
| Buttons | Inter | 600 | 14–15sp |
| Hero numerics | JetBrains Mono | 500–700 | 28–76sp, letterSpacing -1 to -3 |
| Data/tabular | JetBrains Mono | 400–600 | 10.5–22sp |
| Mono captions | JetBrains Mono | 400 | 10.5–12sp |

---

## 2. Bottom Navigation Bar

- 4 tabs: **Today** (home), **Trips** (list), **Stats** (bar-chart), **Settings** (gear)
- Background: `bgElev`, top border `1px solid border`
- Active: `text` color, icon strokeWidth 2.0, label fontWeight 600, size 10.5
- Inactive: `textMuted` color, icon strokeWidth 1.6, label fontWeight 500
- Padding: 6dp top and bottom per tab

---

## 3. Home / Dashboard Screen

```
┌─────────────────────────────┐
│ Mon · 28 Apr          [R]   │  ← date 11sp MUTED CAPS + name 22sp 700; avatar 36dp surface circle
│ Hi, Rahul                   │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │  READY TO RECORD      │  │  ← 12sp muted caps
│  │      ╭───────╮        │  │
│  │      │  ▶    │        │  │  ← 124dp circle, record bg, white play+START
│  │      │ START │        │  │
│  │      ╰───────╯        │  │  ← shadow 0 12px 32px
│  │  Auto-labelled To home│  │  ← 12.5sp dim; direction bold text color
│  └───────────────────────┘  │  ← bgElev, border, radius 24
│                             │
│  TODAY               1 of 2 │  ← 12sp MUTED CAPS + mono 12sp dim
│  ┌───────────────────────┐  │
│  │ → To office  35m      │  │  ← TripRow
│  ├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤  │
│  │ ○  Evening commute    │  │  ← dashed circle placeholder
│  │    Tap START or add   │  │
│  └───────────────────────┘  │  ← bgElev card, radius 16
│                             │
│  THIS WEEK        See stats→│
│  ┌───────────────────────┐  │
│  │ You lost              │  │
│  │ 1h 42m    ← mono 38sp │  │  ← stuck color
│  │ to traffic this week. │  │
│  │ ████████░░░░░░        │  │  ← StuckBar
│  │ 2h 41m moving  4h 23m │  │
│  └───────────────────────┘  │
│ [Today] [Trips] [Stats] [⚙] │
└─────────────────────────────┘
```

---

## 4. Active Recording Screen (Variant A)

```
┌─────────────────────────────┐
│ ● RECORDING          To office│ ← record dot + label caps 12sp
├─────────────────────────────┤
│                             │
│        ELAPSED              │  ← 11sp MUTED CAPS
│      00:22:14               │  ← JetBrains Mono 76sp 500, letterSpacing -3
│                             │
│  ┌───────┐┌───────┐┌──────┐ │
│  │DISTANC││ SPEED ││STUCK │ │  ← 10.5sp MUTED CAPS
│  │ 4.1km ││ 38km/h││  4m  │ │  ← mono 22sp 600; stuck in stuck color
│  └───────┘└───────┘└──────┘ │  ← bgElev cards, radius 16
│                             │
│  ┌─────────────────────────┐│
│  │  [faux map placeholder] ││  ← 180dp height, mapBg surface
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ ■  Stop and save trip   ││  ← text bg / bg text, radius 16, 18px 20px padding
│  └─────────────────────────┘│
└─────────────────────────────┘
```

---

## 5. Trip History Screen

```
┌─────────────────────────────┐
│ Trips              [📅] [+] │  ← 22sp 700; cal icon surface circle; plus icon text-bg circle
│ [List] [Calendar]           │  ← pill segmented: active=text/bg, inactive=transparent+border
├─────────────────────────────┤
│ Today · Mon, 28 Apr   1h 22m│  ← date 13sp 600 + label 11sp muted; total mono 12sp
│ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔ │  ← full-width bgElev card, top+bottom border
│ → To office          35m   │  ← TripRow
│ ← To home            47m   │  ← TripRow
│ ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ │
│ Sun, 27 Apr    No trips     │
│ Fri, 25 Apr    2 trips 1h31m│
│ ...                         │
│ [Today] [Trips] [Stats] [⚙] │
└─────────────────────────────┘
```

**TripRow component spec:**
- 36dp avatar circle: `accentBg` + right-arrow for "to office"; `movingBg` + left-arrow for "to home"
- Direction name: 15sp 600 Inter
- Duration: mono 13sp 600, right-aligned
- Second line: `{start} → {end} · {dist}` mono 12sp `textDim`; `{stuck} stuck` mono 12sp `stuck` 600, right-aligned
- Padding: 14px vertical, 20px horizontal
- Divider: `1px solid border` between rows

---

## 6. Trip Detail Screen

```
┌─────────────────────────────┐
│ [←]   Mon, 28 Apr · 18:05  [⋮]│
├─────────────────────────────┤
│  [faux map 210dp height]    │  ← mapBg, subtle street grid placeholder
├─────────────────────────────┤
│ EVENING COMMUTE             │  ← 11sp MUTED CAPS
│ To home                     │  ← 24sp 700
│ ┌──────────┬──────────┐     │
│ │ DURATION │ DISTANCE │     │  ← 11sp MUTED CAPS
│ │   47m    │  6.4 km  │     │  ← mono 28sp 600
│ └──────────┴──────────┘     │  ← bgElev card, radius 16
│ ████████░░░░░░               │  ← StuckBar
│ ● 29m moving  ● 18m stuck   │  ← mono 12sp, colored dots
│                             │
│ ┌─────────────────────────┐ │
│ │ 🕐 You lost 18 minutes  │ │  ← stuckBg card, clock icon stuck color
│ │    stuck in traffic.    │ │
│ │    That's 38% of trip.  │ │
│ └─────────────────────────┘ │
│                             │
│ TIMELINE                    │  ← 11sp MUTED CAPS
│ 18:05  📍  Started recording│
│ 18:14  🕐  Stuck on Outer.. │  ← stuck color bg circle, 11m in stuck
│ 18:52  🏁  Arrived home     │
│                             │
│ [✏ Edit]        [🗑 Delete] │  ← border buttons, delete in danger color
└─────────────────────────────┘
```

---

## 7. Stats Screen

```
┌─────────────────────────────┐
│ Stats                       │  ← 22sp 700
│ Last 28 days · 22 trips     │  ← 12sp dim
├─────────────────────────────┤
│ ┌───────────────────────┐   │
│ │ You lost              │   │
│ │ 1h 42m    ← mono 56sp │   │  ← stuck color, letterSpacing -2.5
│ │ to traffic this week. │   │
│ │ +14m vs last week     │   │  ← 12sp dim
│ └───────────────────────┘   │  ← bgElev, radius 18
│                             │
│ ┌───────────────────────┐   │
│ │ [Donut 110dp] THIS WEEK│  │  ← donut: moving arc + stuck arc
│ │                4h 23m │   │  ← mono 22sp
│ │ ● 2h 41m mov ● 1h stuck│  │  ← mono 11.5sp colored dots
│ └───────────────────────┘   │
│                             │
│ ┌───────────────────────┐   │
│ │ 28-DAY TREND     min  │   │
│ │ [TrendBars height 84] │   │
│ │ Apr 1    Apr 14  Apr28│   │
│ └───────────────────────┘   │
│                             │
│ ┌───────────────────────┐   │
│ │ WEEKDAY AVERAGES      │   │
│ │ [WeekdayChart h=120]  │   │
│ │ Worst Mon·52m Best Wed│   │
│ └───────────────────────┘   │
│ [Today] [Trips] [Stats] [⚙] │
└─────────────────────────────┘
```

---

## 8. Settings Screen

```
┌─────────────────────────────┐
│ Settings                    │  ← 22sp 700
├─────────────────────────────┤
│ ACCOUNT                     │  ← 11sp MUTED CAPS section label
│ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔│
│ [R] Rahul Menon             │  ← 44dp accentBg avatar, name 15sp 600
│     rahul@gmail.com         │
│ Cloud sync  [● ON]          │  ← movingBg pill badge
│ Restore from cloud       >  │
│ Sign out                    │  ← danger color text
│ ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│
│ RECORDING                   │
│ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔│
│ Cutoff "to office" Before 13>│
│ Auto-pause on stop    [ON]  │
│ ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│
│ NOTIFICATIONS               │
│ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔│
│ Daily reminder 08:00·wkdays [ON] │
│ Include weekends           [OFF]│
│ Weekly summary Sun evening [ON] │
│ ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│
│ APPEARANCE                  │
│ Theme  System            >  │
│ [Today] [Trips] [Stats] [⚙] │
└─────────────────────────────┘
```

**Toggle spec:** 38×22dp pill. On: `moving` bg, knob at right. Off: `borderStr` bg, knob at left. Knob: 18dp white circle, shadow `0 1px 3px rgba(0,0,0,0.2)`.

---

## 9. Onboarding Screen (static scaffold)

```
┌─────────────────────────────┐
│                             │
│  ┌──┐                       │
│  │tv│  ← 56×56 radius 16    │  ← text bg / bg text, mono 700 28sp
│  └──┘                       │
│                             │
│  Track every                │  ← 36sp 700, letterSpacing -1.2
│  commute.                   │
│  One tap to start...        │  ← 16sp dim, lineHeight 1.5
│                             │
│  ✓ One-tap recording        │  ← 28dp movingBg circle, check icon
│    Start when you leave...  │
│  ✓ Auto traffic detection   │
│  ✓ Works offline            │
│                             │
│  [G  Continue with Google]  │  ← bgElev card, 1px borderStr border, radius 14
│  Skip — try without account │  ← transparent, textDim 14sp
│                             │
│  By continuing you agree... │  ← 11sp textMuted center
└─────────────────────────────┘
```

---

## 10. Shared Component Contracts

### `StuckBar`
- Props: `moving` (minutes), `stuck` (minutes), `height` (default 14dp)
- Renders a pill-shaped bar: left segment `moving` color for moving proportion, right segment `stuck` color for stuck proportion
- Background track: `surface2`
- Border radius: `height / 2`

### `TripRowCard`
- Props: direction (`toOffice`/`toHome`), start/end times, duration, distance, stuck time, showDivider
- Uses `accentBg`/`accent` for to-office, `movingBg`/`moving` for to-home
- All time/distance values in JetBrains Mono

### `SectionLabel`
- Props: text
- Style: 11–12sp, fontWeight 600, `textMuted`, UPPERCASE, letterSpacing 1

### `TraevyToggle`
- Props: value (bool), onChanged
- Matches toggle spec from §8 above

### `StatMiniCard`
- Props: label, value, unit, tone (`neutral`/`stuck`/`moving`)
- Used in recording screen stat row

---

## 11. Design Principles (non-negotiable)

1. **Calm & spacious** — generous padding (horizontal 20dp minimum), no cramped layouts
2. **Pointed copy** — "You lost X to traffic" not "X commute time"
3. **JetBrains Mono for all numbers** — duration, distance, speed, time, percentages
4. **No gradients, no emoji** in UI (icons use the SVG set from design)
5. **Consistent card radius** — 16dp for cards, 18dp for hero cards, 14dp for buttons/chips
6. **Color meaning** — `moving` (green) = good, `stuck` (amber) = bad, `record` (red) = active recording
