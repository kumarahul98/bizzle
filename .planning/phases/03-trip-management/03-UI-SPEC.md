---
phase: 3
slug: trip-management
status: draft
shadcn_initialized: false
preset: none
created: 2026-04-24
---

# Phase 3 — UI Design Contract

> Visual and interaction contract for Phase 3 (Trip Management). Consumed by
> `gsd-planner`, `gsd-executor`, `gsd-ui-checker`, and `gsd-ui-auditor`.
> Based on Flutter Material 3 defaults (`ThemeData.light(useMaterial3: true)`
> / `ThemeData.dark(useMaterial3: true)`), all tokens below reference the
> active `Theme.of(context)` rather than hardcoded literals.

---

## Design System

| Property          | Value                                                                                                                   |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Tool              | none (Flutter Material 3 — no shadcn, no web registry)                                                                  |
| Preset            | not applicable                                                                                                          |
| Component library | Flutter Material 3 (`package:flutter/material.dart`, bundled with Flutter 3.41.6)                                       |
| Icon library      | Flutter built-in `Icons` (Material Symbols bundled with Flutter) — no third-party icon pack                             |
| Font              | Roboto (Material default). No custom font declared in `lib/config/theme.dart`; fallback stays Roboto on Android.        |
| Theme source      | `lib/config/theme.dart` — `ThemeData.light(useMaterial3: true)` / `ThemeData.dark(useMaterial3: true)`                  |

**Phase 3 does NOT modify `theme.dart`.** Phase 7 (Polish) is the phase that
may replace the default `ColorScheme`. All Phase 3 widgets must resolve
colors, text styles, and shapes through `Theme.of(context)`,
`Theme.of(context).colorScheme`, and `Theme.of(context).textTheme` — never
via hardcoded `Color(0xFF...)` literals.

---

## Spacing Scale

All spacing values in Phase 3 widgets **must be multiples of 4**. Use the
tokens below — each has a specific role in the edit sheet, manual entry
sheet, delete dialog, and home-screen FAB placement.

| Token | Value | Usage in Phase 3                                                                                                                                                                                                 |
| ----- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| xs    | 4px   | Gap between a label and the value below it (e.g. "Start time" label ↔ value button); vertical padding inside inline error text.                                                                                  |
| sm    | 8px   | Gap between a `SegmentedButton` and the row beneath it; gap between the date field and the time field; icon-to-label gap inside `FilledButton.icon`.                                                             |
| md    | 16px  | Default vertical gap between stacked form fields inside bottom sheets; horizontal padding inside the sheet body; spacing between title, content, and action row in the delete `AlertDialog` (Material default). |
| lg    | 24px  | Top/bottom padding inside the bottom-sheet body (between the drag handle and the first field; between the last field and the Cancel/Save row); top margin of the inline error below the HH:MM field.            |
| xl    | 32px  | Reserved for future section breaks inside sheets — not used in Phase 3 (sheets are single-section forms).                                                                                                        |
| 2xl   | 48px  | Minimum touch-target height for Cancel/Save buttons (aligned with Material 3 `FilledButton` default 40–48px vertical extent; set `minimumSize: Size(64, 48)` when constraining).                                 |
| 3xl   | 64px  | Not used in Phase 3.                                                                                                                                                                                             |

**Exceptions:**

- **Drag handle** at the top of the modal bottom sheet: Flutter Material 3
  default size (32px × 4px). This is set by `showModalBottomSheet` when
  `showDragHandle: true`; **do not override the handle dimensions**.
- **FAB dimensions:** Standard M3 FAB is 56×56 (regular). Use the default
  — do not resize.
- **Inner padding of `SegmentedButton` segments:** Material 3 default
  (not a multiple of 4). Do not override — the widget owns its geometry.
- **Bottom-sheet corner radius:** Material 3 default (`28` for the top
  corners in an M3 modal sheet). Do not override.

**Declaration site:** any Phase 3 widget with spacing >= 8px must pull the
value from a `const` named in the widget file (e.g.
`const double _kFieldGap = 16;`). Do not scatter magic numbers.

---

## Typography

Only **3 type roles** and **2 weights** are used in Phase 3. All resolve
through `Theme.of(context).textTheme` so dark mode and future theming
carry through automatically. **Do not override font family, letter spacing,
or line height at the call site.**

| Role                       | M3 TextTheme slot | Target Size | Weight          | Line Height | Usage in Phase 3                                                                                                                                                      |
| -------------------------- | ----------------- | ----------- | --------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sheet title                | `titleLarge`      | 22px        | w500 (medium)   | ~28px (1.27)| Header inside each bottom sheet: "Edit trip" (edit sheet), "Add missed commute" (manual entry sheet). Single line, left-aligned.                                      |
| Field label                | `labelLarge`      | 14px        | w500 (medium)   | ~20px (1.43)| Caption above each input: "Direction", "Start time", "End time", "Date", "Duration (HH:MM)". Also the text inside `FilledButton` / `TextButton` (`labelLarge` is the M3 button-label slot). |
| Body / value text          | `bodyLarge`       | 16px        | w400 (regular)  | ~24px (1.50)| Dialog body text, inline error messages, formatted date/time shown on the tap-to-change time/date buttons, HH:MM text-field input text.                              |

**Weight policy (exactly two):**

- **Regular (w400):** body text, input values, error messages.
- **Medium (w500):** sheet titles, field labels, button labels (Cancel,
  Save, Delete).

Do NOT introduce w300, w600, or w700 anywhere in Phase 3. Material 3
defaults already restrict the TextTheme to these weights — a Phase 3
widget should never pass `fontWeight:` directly.

**Line-height rule:** Do not set `height:` on any `TextStyle` in Phase 3.
The M3 defaults above already satisfy "body ≈ 1.5, heading ≈ 1.27".

---

## Color

Phase 3 runs on the **default Material 3 `ColorScheme`** (seeded from
Flutter's M3 baseline palette — currently deep purple). Every color is
resolved via `Theme.of(context).colorScheme`. The 60/30/10 split below
maps onto M3 color roles; **no hex literals** appear in Phase 3 source.

| Role           | M3 ColorScheme role                              | Usage (60/30/10)                                                                                                                                                       |
| -------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Dominant (60%) | `colorScheme.surface` / `surfaceContainerLowest` | Home-screen background (already set by `Scaffold`), bottom-sheet background (M3 default), `AlertDialog` background. Plain, low-chroma surface.                         |
| Secondary (30%)| `colorScheme.surfaceContainerHighest`            | `SegmentedButton` unselected segment fill, text-field fill (`InputDecoration` filled), date/time tap-to-change button tonal background.                                |
| Accent (10%)   | `colorScheme.primary` / `onPrimary`              | **Reserved for**: the `[+]` FAB background, the selected segment in the direction `SegmentedButton`, the `Save` button (`FilledButton`). Nothing else.                 |
| Destructive    | `colorScheme.error` / `onError`                  | **Reserved for**: the `Delete` confirm button in the delete `AlertDialog` (rendered as `FilledButton` styled with `backgroundColor: colorScheme.error`); inline HH:MM error text; any form error message.  |

**Accent reserved-for list (exhaustive):**

1. `[+]` FloatingActionButton on the home screen (primary container).
2. Selected segment of the direction `SegmentedButton`.
3. `Save` button in the edit sheet.
4. `Save` button in the manual entry sheet.

Nothing else in Phase 3 uses `colorScheme.primary`. Specifically:

- `Cancel` buttons use `TextButton` default (no fill, `primary`-colored
  label — this is the Material 3 default and stays as-is).
- The inline date/time "tap to change" buttons should use
  `OutlinedButton` or `TextButton.tonalIcon` (tonal), NOT
  `FilledButton`. This prevents three competing accents in a single
  sheet.

**Destructive color policy:**

- The `Delete` confirmation button MUST use
  `FilledButton(style: FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError))`.
- Inline error text (HH:MM invalid, end-before-start) MUST use
  `colorScheme.error` via `Theme.of(context).colorScheme.error` — never
  hardcoded red.
- No other widget in Phase 3 uses `colorScheme.error`.

---

## Copywriting Contract

Fixed strings for every user-visible element in Phase 3. **Do not
paraphrase.** Planners and executors must copy these strings
byte-for-byte.

| Element                                      | Copy                                                                                          |
| -------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Edit sheet title                             | `Edit trip`                                                                                   |
| Edit sheet: direction field label            | `Direction`                                                                                   |
| Edit sheet: start time field label           | `Start time`                                                                                  |
| Edit sheet: end time field label             | `End time`                                                                                    |
| Edit sheet: primary CTA                      | `Save`                                                                                        |
| Edit sheet: secondary CTA                    | `Cancel`                                                                                      |
| Edit sheet: end-before-start error (inline)  | `End time must be after start time.`                                                          |
| Manual entry sheet title                     | `Add missed commute`                                                                          |
| Manual entry sheet: date field label         | `Date`                                                                                        |
| Manual entry sheet: duration field label     | `Duration (HH:MM)`                                                                            |
| Manual entry sheet: duration hint text       | `0:45`                                                                                        |
| Manual entry sheet: direction field label    | `Direction`                                                                                   |
| Manual entry sheet: primary CTA              | `Save`                                                                                        |
| Manual entry sheet: secondary CTA            | `Cancel`                                                                                      |
| Manual entry: HH:MM empty error (inline)     | `Enter a duration like 0:45.`                                                                 |
| Manual entry: HH:MM malformed error (inline) | `Use HH:MM format between 0:00 and 23:59.`                                                    |
| Direction segment: to office                 | `To office`                                                                                   |
| Direction segment: to home                   | `To home`                                                                                     |
| Delete dialog title                          | `Delete trip?`                                                                                |
| Delete dialog body                           | `This trip will be permanently removed.`                                                      |
| Delete dialog: secondary CTA                 | `Cancel`                                                                                      |
| Delete dialog: primary destructive CTA       | `Delete`                                                                                      |
| SnackBar after successful delete             | `Trip deleted`                                                                                |
| SnackBar after successful edit save          | `Trip updated`                                                                                |
| SnackBar after successful manual entry save  | `Trip added`                                                                                  |
| SnackBar on save failure (edit / manual)     | `Couldn't save the trip. Try again.`                                                          |
| SnackBar on delete failure                   | `Couldn't delete the trip. Try again.`                                                        |
| FAB tooltip (Home screen)                    | `Add missed commute`                                                                          |
| FAB semantic label (a11y)                    | `Add missed commute`                                                                          |

**Primary CTA rule:** every primary CTA in Phase 3 is a **verb + noun**
(or bare verb when the noun is implied by context): `Save`, `Delete`,
`Cancel`. No "OK", no "Submit", no "Confirm".

**Error copy rule:** every error message identifies the problem (first
sentence) and tells the user what to do next (second sentence or
embedded hint). No bare "Error" or "Invalid input".

**Destructive confirmation pattern (D-07):** Title is an action question
(`Delete trip?`). Body states the consequence in one sentence
(`This trip will be permanently removed.`). Primary button uses the
destructive color and the bare verb (`Delete`). Secondary button is
`Cancel`. No three-button dialogs.

**Empty state:** Phase 3 has **no empty-state UI** — the trip list lives
in Phase 4. The home screen already exists from Phase 2 and Phase 3 only
adds a FAB to it. The checker should treat "empty state" as N/A for
this phase.

---

## Component Inventory

Prescriptive list of the Material 3 widgets this phase uses and the
exact flavor of each. **Deviations from this list require a spec
revision.**

| Surface / action                 | Widget                                                      | Flavor / notes                                                                                                                                                |
| -------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Edit trip sheet                  | `showModalBottomSheet`                                      | `isScrollControlled: true`, `useSafeArea: true`, `showDragHandle: true`. Body wrapped in `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsets.bottom))` so the keyboard does not cover inputs. |
| Manual entry sheet               | `showModalBottomSheet`                                      | Same flavor as edit sheet above. Body also uses the M3 drag handle.                                                                                           |
| Direction picker                 | `SegmentedButton<TripDirection>`                            | `multiSelectionEnabled: false`, `showSelectedIcon: false` (cleaner for a 2-segment row). `TripDirection` is a Dart `enum { toOffice, toHome }` mapped to constants at save time. |
| Start / end time picker trigger  | `OutlinedButton.icon`                                       | Leading `Icon(Icons.schedule)`, label is the formatted `HH:mm` value (via `intl` `DateFormat.jm()`). Tapping calls `showTimePicker` with `initialTime: TimeOfDay.fromDateTime(currentTime.toLocal())`. |
| Date picker trigger              | `OutlinedButton.icon`                                       | Leading `Icon(Icons.calendar_today)`, label is the formatted date (`DateFormat.yMMMEd()`). Tapping calls `showDatePicker(firstDate: DateTime(2020), lastDate: DateTime.now())`. |
| Duration text field (HH:MM)      | `TextFormField`                                             | `InputDecoration(labelText: 'Duration (HH:MM)', hintText: '0:45', filled: true, errorText: _hhMmError)`. `keyboardType: TextInputType.datetime`. `inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))]`, `maxLength: 5`. |
| Primary CTA (Save)               | `FilledButton`                                              | Default M3 `FilledButton`. Disabled (`onPressed: null`) while form is invalid or while `TripManagementSaving` state is active.                                 |
| Secondary CTA (Cancel)           | `TextButton`                                                | Default M3 `TextButton`. Closes the sheet / pops the dialog without saving.                                                                                   |
| Destructive CTA (Delete confirm) | `FilledButton`                                              | `style: FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError)`. Label: `Delete`.                                   |
| Delete confirmation              | `AlertDialog` via `showDialog<bool>`                        | Title: `Delete trip?`. Content: `This trip will be permanently removed.`. Actions: `[TextButton(Cancel), FilledButton.error(Delete)]`.                        |
| Success / failure toast          | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` | Default M3 SnackBar. No action on success. On failure, no retry action button in Phase 3 (retry by repeating the gesture).                                    |
| Add missed commute trigger       | `FloatingActionButton`                                      | Regular size (56×56). `child: Icon(Icons.add)`. `tooltip: 'Add missed commute'`. Placed via `Scaffold.floatingActionButton` (default bottom-end position).    |
| Inline error (HH:MM, end < start)| `Text(error, style: textTheme.bodyLarge.copyWith(color: colorScheme.error))` | Render immediately below the offending field. Do NOT use a SnackBar for validation errors.                                                                    |

**Do not hand-roll:** custom bottom sheet containers, custom two-button
row direction toggles, custom clocks, custom calendars, custom delete
overlays. The Material 3 widgets above cover every Phase 3 need.

---

## Interaction States

Every interactive widget in Phase 3 must handle these states explicitly.
Material 3 handles visual styling automatically when the right widget is
chosen — the spec below lists what the **application logic** must drive.

| Widget                      | Default                                      | Pressed / Hover                     | Focus                                      | Disabled                                                              | Loading                                                                                   | Error                                                                             |
| --------------------------- | -------------------------------------------- | ----------------------------------- | ------------------------------------------ | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `SegmentedButton`           | One segment selected (matching current value)| M3 ripple (default)                 | M3 focus ring (default)                    | Not used — direction is always selectable                             | Not used                                                                                  | Not used                                                                          |
| Time picker trigger button  | Shows current formatted time                 | M3 ripple (default)                 | M3 focus ring (default)                    | Disabled if parent form is in `TripManagementSaving`                  | N/A (picker dialog handles its own loading)                                               | If new time makes end < start, render inline error below End field                |
| Date picker trigger button  | Shows current formatted date                 | M3 ripple                           | M3 focus ring                              | Disabled in `TripManagementSaving`                                    | N/A                                                                                       | N/A (date picker enforces `lastDate = today`)                                     |
| HH:MM text field            | Empty with hint `0:45`                       | N/A                                 | Labeled outline, cursor visible            | Disabled in `TripManagementSaving`                                    | N/A                                                                                       | `InputDecoration.errorText` from `parseHhMm` result; field border flips to error  |
| Save button (`FilledButton`)| Enabled when form valid                      | M3 ripple                           | M3 focus ring                              | **Disabled when form invalid OR in `TripManagementSaving` state**     | Replace label with `SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary))` while state is `TripManagementSaving` | If save fails, button re-enables + SnackBar shows failure copy                    |
| Cancel button (`TextButton`)| Enabled                                      | M3 ripple                           | M3 focus ring                              | **Never disabled** — user must always be able to back out             | N/A                                                                                       | N/A                                                                               |
| Delete button in dialog     | Enabled                                      | M3 ripple                           | M3 focus ring                              | Not disabled (the dialog itself is modal; no in-flight state surfaces)| If delete is async and >300ms, swap label for the same spinner pattern as Save            | On failure: dismiss dialog, show failure SnackBar                                 |
| `FloatingActionButton`      | Enabled                                      | M3 ripple                           | M3 focus ring                              | **Disabled while a tracking session is active** (tracking takes priority; mirror how Phase 2 hides/locks unrelated controls) | N/A                                                                                       | N/A                                                                               |
| Bottom sheet                | Shown via `showModalBottomSheet`             | Tap-outside / drag-down dismisses   | First focusable element receives focus     | N/A                                                                   | While `TripManagementSaving`, the sheet is NOT auto-dismissed; Save button shows spinner  | Errors remain inline or surface as SnackBar AFTER the sheet dismisses             |

**Loading policy (D-08 atomic transactions):** transactions are local
Drift writes and normally complete in under 50ms. The spinner pattern
only becomes visible if the write is slow. Do **not** insert an
artificial delay; simply drive the button state from the sealed
`TripManagementState`.

**Swipe-to-dismiss (D-01):** the sheet closes without saving on
downward drag. If the form is dirty, **do not show a "discard?" dialog
in Phase 3** — the decision log deliberately did not add an undo or
confirm-discard flow. Keep dismissal instant.

---

## Layout Contracts

### Edit trip sheet (invoked from a trip card, Phase 3+ integration points)

```
┌──────────────────────────────────────────┐
│          ▔▔ (drag handle, M3 default)    │   ← 32×4 handle, top-centered
│                                          │
│   Edit trip                              │   ← titleLarge, 24px top padding
│                                          │
│   Direction                              │   ← labelLarge, 16px above widget
│   [ To office | To home ]                │   ← SegmentedButton, 8px below label
│                                          │
│   Start time                             │   ← labelLarge, 16px below segmented
│   [🕒 8:42 AM]                           │   ← OutlinedButton.icon, 8px below
│                                          │
│   End time                               │   ← labelLarge, 16px below
│   [🕒 9:17 AM]                           │   ← OutlinedButton.icon
│   (inline error if end < start)          │   ← bodyLarge, colorScheme.error
│                                          │
│   ─────────────────────────────────      │
│                 [Cancel] [ Save ]        │   ← TextButton + FilledButton, 24px top padding, right-aligned row
└──────────────────────────────────────────┘
```

- Horizontal padding: **16px** on each side of the body.
- Vertical padding from handle to title: **24px**.
- Vertical gap between field label and its widget: **8px**.
- Vertical gap between one completed field block and the next field label: **16px**.
- Bottom padding before the action row: **24px**.
- Cancel/Save row: right-aligned, 8px gap between the two buttons.
- Action row bottom padding: **16px** (then MediaQuery.viewInsets.bottom absorbs keyboard).

### Manual entry sheet (invoked from the home-screen [+] FAB)

```
┌──────────────────────────────────────────┐
│          ▔▔                              │
│                                          │
│   Add missed commute                     │
│                                          │
│   Date                                   │
│   [📅 Wed, Apr 23, 2026]                 │   ← OutlinedButton.icon
│                                          │
│   Duration (HH:MM)                       │   ← labelLarge
│   ┌──────────────────────────────────┐   │   ← TextFormField, filled, hint `0:45`
│   │ 0:45                             │   │
│   └──────────────────────────────────┘   │
│   (inline error if empty or malformed)   │
│                                          │
│   Direction                              │
│   [ To office | To home ]                │
│                                          │
│   ─────────────────────────────────      │
│                 [Cancel] [ Save ]        │
└──────────────────────────────────────────┘
```

Same padding / gap rules as the edit sheet. The **only difference** is
the fields present (date + duration + direction, instead of direction +
start time + end time).

### Delete confirmation dialog

```
┌─────────────────────────────────┐
│                                 │
│  Delete trip?                   │   ← AlertDialog title (titleLarge)
│                                 │
│  This trip will be              │   ← content (bodyLarge)
│  permanently removed.           │
│                                 │
│  ────────────────────────────── │
│            [Cancel] [Delete]    │   ← TextButton, destructive FilledButton
└─────────────────────────────────┘
```

All spacing provided by the stock `AlertDialog`. Do NOT wrap the dialog
body in custom padding.

### Home-screen FAB

- Placement: `Scaffold.floatingActionButton`; default M3 bottom-end
  position (Flutter handles 16px margin automatically).
- Icon: `Icons.add`.
- Tooltip: `Add missed commute`.
- Visible only when **not actively tracking a commute**. When a tracking
  session is active (per Phase 2 `TrackingState`), the FAB is hidden
  (`floatingActionButton: isTracking ? null : _buildFab(...)`). This
  keeps a single primary action at a time on the home screen.

---

## Accessibility Contract

- **Touch targets:** every tappable element (segment, button, FAB,
  dialog action) must render at least 48×48 logical px. Material 3
  defaults satisfy this — do not shrink.
- **Semantic labels:** the FAB has both `tooltip: 'Add missed commute'`
  and an implicit `Semantics` label (FAB passes tooltip to semantics
  by default — no `Semantics` wrapper required).
- **Screen reader order (edit sheet):** Title → Direction label →
  segments → Start time label → Start button → End time label → End
  button → End-time error (if present) → Cancel → Save. Enforce via
  widget tree order; do not set `Semantics(sortKey:)`.
- **Contrast:** all colors resolve through `ColorScheme`; M3 defaults
  guarantee WCAG AA on text/background pairings. Do not introduce hex
  literals that bypass the scheme.
- **Dismissal:** the modal bottom sheet is dismissible via (a) drag
  down, (b) tap-outside, (c) Android system back button. All three
  must work — do not override the route's back-button handling.
- **Keyboard handling:** the manual entry sheet's HH:MM field must
  auto-focus the text input on sheet open (so the keyboard appears
  immediately); the edit sheet's first interactive element
  (SegmentedButton) must receive focus on open.

---

## Registry Safety

| Registry           | Blocks Used     | Safety Gate                                                       |
| ------------------ | --------------- | ----------------------------------------------------------------- |
| shadcn official    | (not applicable — Flutter project) | not required                                     |
| third-party        | none            | not required — Phase 3 uses only Flutter-bundled Material 3 widgets |

**Safety summary:** Phase 3 introduces **zero new Flutter packages**.
Every widget is served by `package:flutter/material.dart` (bundled with
the Flutter SDK), with date-formatting support from `intl` (already in
`pubspec.yaml`). There is no registry to vet and no third-party UI
code entering the project.

---

## Dark Mode Contract

Phase 7 adds the dark-mode toggle, but Phase 3 widgets must already be
dark-mode-safe today because the app loads `darkTheme` when the device
is in dark mode. The rule is simple:

- **Never** hardcode `Colors.black`, `Colors.white`, or any `Color(0xFF...)`.
- Always resolve via `Theme.of(context).colorScheme` for colors, and
  `Theme.of(context).textTheme` for text styles.
- Inline errors resolve via `colorScheme.error` — which is distinct in
  both light and dark schemes.

The checker must assert no hex literals appear in any Phase 3 UI file.

---

## Sources Pre-Populated

| Source               | Decisions or tokens sourced from it                                                                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CLAUDE.md`          | Material 3 usage, Riverpod policy, `very_good_analysis` lint rules, sealed state policy, no hardcoded strings outside `constants.dart`.                                      |
| `03-CONTEXT.md`      | D-01, D-02, D-07, D-09, D-11: modal bottom sheet pattern, no new routes, AlertDialog flavor, [+] FAB on home screen, HH:MM validation rule.                                  |
| `03-RESEARCH.md`     | Component inventory (Pattern 4–7), SegmentedButton recommendation (Pattern 5), pitfall-driven interaction states (context.mounted, UTC/local, single-transaction atomicity). |
| `REQUIREMENTS.md`    | TRACK-03 (direction auto-label w/ override), TRACK-06 (edit direction + times), TRACK-07 (delete with confirmation), TRACK-08 (manual entry with date/duration/direction).   |
| `lib/config/theme.dart` | Confirmed Flutter Material 3 is active; no custom ColorScheme defined yet → Phase 3 relies on M3 baseline (correct until Phase 7).                                        |
| `lib/features/tracking/screens/home_screen.dart` | Existing home screen structure, existing `AlertDialog` + `FilledButton` pattern reused for delete dialog; FAB slot is currently empty. |

No user-input questions were issued during this UI-SPEC session — every
contract value was derivable from upstream artifacts and the existing
theme file.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending
