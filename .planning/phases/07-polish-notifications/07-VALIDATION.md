---
phase: 7
slug: polish-notifications
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-28
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter 3.41.6) |
| **Config file** | None — standard Flutter test discovery |
| **Quick run command** | `flutter test test/unit/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** `flutter test test/unit/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-02 | `_toThemeMode('dark')` returns `ThemeMode.dark` | unit | `flutter test test/unit/config/constants_test.dart` | ✅ (extend) |
| UX-02 | `userPreferenceProvider` emits dark mode change after upsert | unit | `flutter test test/unit/database/user_preferences_dao_test.dart` | ✅ (extend) |
| UX-02 | Settings screen renders 3 RadioListTile rows | widget | `flutter test test/widget/features/settings/settings_screen_test.dart` | ❌ Wave 0 |
| UX-02 | Gear icon in Dashboard AppBar navigates to SettingsScreen | widget | `flutter test test/widget/features/settings/settings_screen_test.dart` | ❌ Wave 0 |
| UX-04 | Schema migration v1→v2 adds `weekly_notification_enabled` | unit | `flutter test test/unit/database/migration_scaffold_test.dart` | ✅ (extend) |
| UX-04 | `UserPreferencesValue.defaults()` has `weeklyNotificationEnabled = false` | unit | `flutter test test/unit/database/user_preferences_dao_test.dart` | ✅ (extend) |
| UX-05 | Reminder scheduling cancels + reschedules on preference change | manual | Device verification only — `flutter_local_notifications` requires platform channels | ❌ manual-only |

**Manual-only justification (UX-05 scheduling):** `flutter_local_notifications` uses platform channels unavailable in widget test isolates (`MissingPluginException`). Scheduling behavior verified on real Android device only.

---

## Wave 0 — Test Scaffolding

- [ ] `test/widget/features/settings/settings_screen_test.dart` — covers UX-02: 3 RadioListTile rows, gear icon navigation from DashboardScreen to SettingsScreen, notification section visibility

No new framework install required.

---

## Human Verification Items

| # | Item | How to test |
|---|------|-------------|
| 1 | Dark mode toggle applies instantly | Settings → select Dark → verify entire app switches immediately |
| 2 | Theme persists across restarts | Select Light → kill app → relaunch → verify Light theme active |
| 3 | Weekly notification fires Sunday 6pm | Set device clock to Sunday 5:59pm, wait for 6pm notification |
| 4 | Reminder notification fires at set time | Enable reminder, set time 2 mins ahead, wait for notification |
| 5 | Weekend reminder toggle works | Enable reminder, disable weekends, verify no notification fires Saturday |
| 6 | Notification channels distinct from tracking | Active tracking + weekly notification both visible without conflict |
