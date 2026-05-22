---
phase: "08"
plan: "07"
subsystem: settings-onboarding
tags:
  - settings
  - onboarding
  - traevy-toggle
  - theme-picker
  - wave-5-green
dependency_graph:
  requires:
    - 08-02-theme (TraevyTokensExt, TraevyFonts, buildLightTheme)
    - 08-03-primitives (TraevyToggle, TraevyLogoMark, SectionLabel)
    - 08-04-shell (kRouteOnboarding declared; MainShell tab navigation)
  provides:
    - SettingsSection widget (uppercase label + bgElev card + auto-dividers)
    - SettingsRow widget (label + optional mono subtitle + trailing slot)
    - AccountRow widget (44dp accentBg avatar + name + email)
    - FeatureTick widget (28dp movingBg circle + check + title/subtitle)
    - GoogleContinueButton widget (bgElev card with borderStr outline)
    - OnboardingScreen (static scaffold reachable at /onboarding)
    - notificationServiceProvider (Riverpod-managed NotificationService)
  affects:
    - lib/features/settings/screens/settings_screen.dart (rewritten)
    - lib/features/settings/providers/settings_providers.dart (added provider)
    - lib/config/routes.dart (registered kRouteOnboarding builder)
    - test/widget/features/settings/settings_screen_test.dart (rewritten)
tech_stack:
  added: []
  patterns:
    - Material(type: transparency) + InkWell pattern for tappable rows
      living outside an enclosing Scaffold (MainShell renders content
      without a per-tab Scaffold).
    - SingleChildScrollView + Column over ListView for eager mounting
      of all four SettingsSection children (test viewport 800x600 is
      shorter than the unrolled settings list).
    - notificationServiceProvider as a Riverpod handle so widget tests
      can swap a fake to bypass flutter_local_notifications platform
      channels (which crash on the test host with LateInitializationError).
    - Bottom-sheet theme picker — showModalBottomSheet returning the
      selected kDarkMode* literal replaces the previous RadioListTile
      column.
key_files:
  created:
    - lib/features/settings/widgets/settings_section.dart
    - lib/features/settings/widgets/settings_row.dart
    - lib/features/settings/widgets/account_row.dart
    - lib/features/onboarding/screens/onboarding_screen.dart
    - lib/features/onboarding/widgets/feature_tick.dart
    - lib/features/onboarding/widgets/google_continue_button.dart
  modified:
    - lib/features/settings/screens/settings_screen.dart
    - lib/features/settings/providers/settings_providers.dart
    - lib/config/routes.dart
    - test/widget/features/settings/settings_screen_test.dart
decisions:
  - Tappable SettingsRow wraps its InkWell in Material(type: transparency)
    so the missing Scaffold ancestor (MainShell no longer wraps each tab
    in a Scaffold) does not crash with "No Material widget found".
  - SettingsScreen uses SingleChildScrollView + Column instead of ListView
    so the test runner (800x600) can find all 4 SettingsSection blocks at
    once — ListView would render Account/Recording/Notifications and lazy
    out Appearance.
  - Introduced notificationServiceProvider so the UX-04 / UX-05 wiring is
    testable without the FlutterLocalNotificationsPlugin platform channel
    (which throws LateInitializationError when accessed off-device).
  - UX-04 widget test starts with weeklyNotificationEnabled=true so the
    toggle tap exercises the cancelWeeklySummary path. The schedule path
    calls ref.read(appDatabaseProvider) which opens real Drift — that is
    out of scope for a widget test.
  - Theme picker is a bottom sheet of three SettingsRow entries returning
    kDarkModeSystem / kDarkModeLight / kDarkModeDark on tap; the existing
    UserPreferencesDao.upsert path is preserved exactly.
  - OnboardingScreen helper widgets (FeatureTick, GoogleContinueButton)
    extracted to widgets/ so the screen file stays at 102 lines.
  - "Sign out" row left as a non-tappable visual placeholder — Phase 9
    auth integration will wire the destructive flow.
  - "Cloud sync" and "Auto-pause on stop" toggles are visual-only and use
    a top-level `_noopBool` no-op handler so the enclosing SettingsRow can
    be declared `const`. Phase 9 (cloud sync) and a future backlog item
    (auto-pause) will wire real state.
  - The Recording → Cutoff row renders without onTap (no chevron) because
    the existing settings notifier does not yet expose cutoff updates;
    rendering a chevron without a destination would mislead the user.
metrics:
  duration_minutes: 50
  completed: "2026-05-14"
  tasks_completed: 2
  files_created: 6
  files_modified: 4
---

# Phase 8 Plan 07: Settings + Onboarding Restyle Summary

**One-liner:** Settings screen restyled into 4 Traevy grouped sections
(Account / Recording / Notifications / Appearance) with `TraevyToggle`
replacing `SwitchListTile` and a bottom-sheet theme picker replacing
`RadioListTile`; OnboardingScreen scaffolded and registered at
`kRouteOnboarding`. UX-02 / UX-04 / UX-05 behavioural wiring preserved.

## Tasks Completed

| Task | Name | Commits | Key Files |
|------|------|---------|-----------|
| RED  | Rewrite settings test for TraevyToggle + theme-picker bottom sheet | 2c4b6d3 | settings_screen_test.dart |
| 1    | Settings building blocks + restyled SettingsScreen | a2aefba | settings_section.dart, settings_row.dart, account_row.dart, settings_screen.dart, settings_providers.dart, settings_screen_test.dart |
| 2    | OnboardingScreen scaffold + routes.dart registration | df5e5cf | onboarding_screen.dart, feature_tick.dart, google_continue_button.dart, routes.dart |

## What Was Built

### SettingsSection — uppercase header + bgElev card

`lib/features/settings/widgets/settings_section.dart` (73 lines):

```dart
SettingsSection({
  required String title,    // uppercased via SectionLabel(fontSize: 11)
  required List<Widget> children,  // auto-divider-interleaved
});
```

Renders 20dp horizontal padding, 8dp vertical padding, a SectionLabel
header, then a DecoratedBox with `tokens.bgElev` fill and top+bottom
`tokens.border` BorderSides. Internal `_interleaveWithDividers` injects a
1dp `Divider(tokens.border)` between every pair of children.

### SettingsRow — label + optional subtitle + trailing slot

`lib/features/settings/widgets/settings_row.dart` (100 lines):

```dart
SettingsRow({
  required String label,
  String? subtitle,         // rendered in JetBrains Mono 12sp textDim
  Widget? trailing,         // typically TraevyToggle
  VoidCallback? onTap,      // if non-null and trailing is null, chevron auto-rendered
  bool dangerous = false,   // tokens.record color for label
});
```

When `onTap` is non-null, the row is wrapped in
`Material(type: MaterialType.transparency)` + `InkWell` so the splash
sink works without a Scaffold ancestor — `MainShell` renders each tab
without a per-tab Scaffold so the previous AppBar-based implicit Material
is no longer present.

### AccountRow — 44dp accentBg avatar + name + email

`lib/features/settings/widgets/account_row.dart` (86 lines):

```dart
AccountRow({
  required String name,     // Inter 15sp w600 onSurface
  required String email,    // JetBrains Mono 12sp textDim
  required String initial,  // Inter 16sp w700 accent inside 44dp circle
});
```

Currently fed by `kPlaceholderUserName` / `kPlaceholderUserInitial`;
Phase 9 wires real Cognito profile data.

### SettingsScreen — 4 grouped sections

`lib/features/settings/screens/settings_screen.dart` (348 lines, includes
4 section StatelessWidgets, theme-picker function, copy helper, notification
side-effect helpers):

| Section | Rows |
|---------|------|
| Account | AccountRow + Cloud sync toggle (placeholder) + Restore from cloud (placeholder snackbar) + Sign out (placeholder) |
| Recording | Cutoff "to office" (read-only) + Auto-pause on stop toggle (placeholder) |
| Notifications | Daily reminder TraevyToggle + Include weekends TraevyToggle + Weekly summary TraevyToggle |
| Appearance | Theme row → bottom-sheet picker (System / Light / Dark) |

### OnboardingScreen — static scaffold at `/onboarding`

`lib/features/onboarding/screens/onboarding_screen.dart` (102 lines):

Top-to-bottom: `TraevyLogoMark` → two-line 36sp "Track every\ncommute."
headline → 16sp dim subhead → three `FeatureTick` rows → `Spacer` →
`GoogleContinueButton` (visual scaffold) → "Skip — try without account"
GestureDetector that pops if a previous route exists → 11sp textMuted
terms blurb.

The screen is registered in `kAppRoutes[kRouteOnboarding]` so any caller
can `Navigator.pushNamed(context, kRouteOnboarding)` once Phase 9 decides
the auto-display logic.

## Controller Call Diff (Phase 7 → Phase 8)

**None.** Every notifier method invoked by the new SettingsScreen
matches the Phase 7 controller surface exactly:

| Phase 7 invocation | Phase 8 invocation |
|-------------------|--------------------|
| `userPreferencesDao.upsert(_copy(prefs, darkMode: …))` | identical |
| `_toggleWeeklySummary` → upsert + `scheduleWeeklySummary(db)` / `cancelWeeklySummary` | identical (but `NotificationService` now sourced via `notificationServiceProvider`) |
| `_toggleReminder` → upsert + `scheduleReminder(hhMm, includeWeekends)` / `cancelReminder` | identical (provider-sourced) |
| `_toggleWeekend` → upsert + `scheduleReminder(...)` | identical (provider-sourced) |

The notification service is now obtained from
`ref.read(notificationServiceProvider)` instead of constructed inline
with `NotificationService()`. Production behaviour is unchanged because
the default provider implementation is `NotificationService()` and
`FlutterLocalNotificationsPlugin` is a singleton under the hood.

## Theme Picker Bottom Sheet Flow

```
Settings → Appearance → Theme row tap
  → showModalBottomSheet returns a SafeArea(Column) with 3 SettingsRow
    entries: System / Light / Dark
  → user taps a row → Navigator.pop(sheetCtx, kDarkMode*)
  → showModalBottomSheet future resolves with the literal
  → settings_screen calls userPreferencesDao.upsert(_copyPrefs(..., darkMode: picked))
  → userPreferenceProvider stream emits the new value
  → TraevyApp.themeMode rebuilds (D-04 wiring unchanged from Phase 7)
```

## Onboarding Registration Confirmation

- `lib/config/routes.dart` contains:
  ```dart
  kRouteOnboarding: (BuildContext context) => const OnboardingScreen(),
  ```
- The route is **not** auto-displayed. `MainShell` is still the home
  widget. Phase 9 auth integration will decide whether to push
  onboarding on first launch.

## Verification Results

| Check | Result |
|-------|--------|
| `flutter analyze lib/features/settings/ lib/features/onboarding/ lib/config/routes.dart` | No issues found |
| `flutter analyze lib/` (full) | No issues found |
| `flutter test test/widget/features/settings/` | 10/10 PASS |
| `flutter test test/widget/` (full) | 91/91 PASS |
| `flutter test test/unit/` | 190/190 PASS |
| `! grep -q "SwitchListTile" lib/features/settings/screens/settings_screen.dart` | PASS (no matches) |
| `grep -c "TraevyToggle" lib/features/settings/screens/settings_screen.dart` | 5 (≥ 3) |
| `grep -q "kRouteOnboarding: (BuildContext" lib/config/routes.dart` | PASS |
| Widget files ≤ 100 lines | settings_section=73, settings_row=100, account_row=86, feature_tick=64, google_continue_button=56 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] InkWell crashed with "No Material widget found"**
- **Found during:** Task 1 GREEN phase — first test run after creating SettingsRow.
- **Issue:** The Phase 7 SettingsScreen had a `Scaffold(appBar: AppBar(...))` which supplied an implicit `Material` ancestor. Plan 04 moved the screen into `MainShell` without a per-tab `Scaffold`, so the new `InkWell` inside `SettingsRow` had no Material to sink ink splashes into.
- **Fix:** Wrap the tappable branch of `SettingsRow.build` in `Material(type: MaterialType.transparency)`.
- **Files modified:** `lib/features/settings/widgets/settings_row.dart`
- **Commit:** a2aefba

**2. [Rule 1 - Bug] ListView lazy-mounted only 3 of 4 sections in the test viewport**
- **Found during:** Task 1 GREEN phase — `findsNWidgets(4)` returned only 3 SettingsSection widgets.
- **Issue:** `ListView(children: …)` uses `SliverList` under the hood and only mounts widgets that intersect the viewport. At 800×600 the Appearance section was below the fold.
- **Fix:** Changed the screen body to `SingleChildScrollView` + `Column` so all 4 sections mount eagerly. UI behaviour identical for users (still scrollable).
- **Files modified:** `lib/features/settings/screens/settings_screen.dart`
- **Commit:** a2aefba

**3. [Rule 2 - Missing] NotificationService not testable without a Riverpod handle**
- **Found during:** Task 1 GREEN phase — UX-05 toggle tap threw `LateInitializationError` from `flutter_local_notifications` platform channels in the test isolate.
- **Issue:** The notification side-effect helpers constructed `NotificationService()` inline, so widget tests could not inject a fake.
- **Fix:** Added `notificationServiceProvider` to `settings_providers.dart` and replaced all `NotificationService()` constructor calls in `settings_screen.dart` with `ref.read(notificationServiceProvider)`. Production behaviour unchanged (the default factory still returns `NotificationService()`); tests can now `overrideWithValue(_FakeNotificationService())`.
- **Files modified:** `lib/features/settings/providers/settings_providers.dart`, `lib/features/settings/screens/settings_screen.dart`, test file.
- **Commit:** a2aefba

**4. [Rule 1 - Bug] OnboardingScreen exceeded 150-line line-count target**
- **Found during:** Task 2 acceptance criteria check.
- **Issue:** The natural Flutter widget tree (Scaffold → SafeArea → Padding → Column with 14+ children + 2 helper widget classes) reached 191 lines.
- **Fix:** Extracted `FeatureTick` and `GoogleContinueButton` to standalone files under `lib/features/onboarding/widgets/`. `onboarding_screen.dart` is now 102 lines.
- **Files created:** `lib/features/onboarding/widgets/feature_tick.dart`, `lib/features/onboarding/widgets/google_continue_button.dart`.
- **Commit:** df5e5cf

### Deviations Acknowledged in Plan

- The plan specified the screen-side `_openCutoffPicker(context, ref)` flow. The existing settings notifier does not expose a cutoff updater. Per the plan's own guidance ("if the controller does not expose cutoff updates, this row is rendered without onTap. Verify before committing."), the row is rendered without `onTap` (no chevron). The subtitle still reflects the current cutoff hour.
- The plan called for at least 3 `TraevyToggle` instances in the screen file. Count is 5 (Cloud sync, Auto-pause on stop, Daily reminder, Include weekends, Weekly summary) — the Account-section Cloud-sync and Recording-section Auto-pause toggles are intentional visual placeholders for Phase 9 / future backlog.

## Known Stubs

- **Cloud sync toggle (Account section)** — `TraevyToggle(value: false, onChanged: _noopBool)`. Wired in Phase 9 when authentication ships. Has a "OFF — sign in to enable" subtitle to communicate state.
- **Restore from cloud row (Account section)** — `onTap` shows a placeholder snackbar "Restore — available after sign-in". Real restore endpoint ships in Phase 11.
- **Sign out row (Account section)** — `onTap: null` (non-tappable, danger-color label). Phase 9 wires the destructive flow.
- **Auto-pause on stop toggle (Recording section)** — visual-only, `value: true`. `UserPreferences` does not yet carry this flag.
- **Cutoff "to office" row (Recording section)** — read-only display. The settings notifier does not yet expose a cutoff updater.
- **OnboardingScreen "Continue with Google" button** — `onTap: () {}`. Phase 9 wires Google sign-in via the existing `google_sign_in` + Cognito flow.

All stubs are documented in code comments and do **not** block any
Phase 8 goal. The plan's objective — "Close out the remaining two
visible screens in Phase 8" — is fully achieved.

## Threat Flags

None — this plan introduces no new network endpoints, auth paths, file
access patterns, or schema changes. The Cloud sync toggle, Restore row,
Sign out row, and Continue-with-Google button are visual scaffolds that
do not execute any auth or network code in Phase 8.

## Self-Check: PASSED

Files confirmed present:
- `lib/features/settings/widgets/settings_section.dart`: FOUND
- `lib/features/settings/widgets/settings_row.dart`: FOUND
- `lib/features/settings/widgets/account_row.dart`: FOUND
- `lib/features/onboarding/screens/onboarding_screen.dart`: FOUND
- `lib/features/onboarding/widgets/feature_tick.dart`: FOUND
- `lib/features/onboarding/widgets/google_continue_button.dart`: FOUND

Commits confirmed in `git log`:
- 2c4b6d3: FOUND (test RED rewrite)
- a2aefba: FOUND (settings restyle)
- df5e5cf: FOUND (onboarding scaffold)

Verification commands:
- `flutter test test/widget/features/settings/`: 10/10 PASS
- `flutter test test/widget/`: 91/91 PASS
- `flutter test test/unit/`: 190/190 PASS
- `flutter analyze lib/`: No issues found
- `! grep -q SwitchListTile lib/features/settings/screens/settings_screen.dart`: PASS
- `grep -c TraevyToggle lib/features/settings/screens/settings_screen.dart` = 5: PASS (≥ 3)
- `grep -q "kRouteOnboarding: (BuildContext" lib/config/routes.dart`: PASS
- Widget files ≤ 100 lines: PASS (max = 100 lines in settings_row.dart)
