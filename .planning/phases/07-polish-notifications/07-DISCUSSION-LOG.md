# Phase 7: Polish & Notifications - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 07-polish-notifications
**Areas discussed:** Settings screen access & layout, Dark mode toggle UI, Weekly summary notification, Tracking reminder setup

---

## Settings Screen Access

| Option | Description | Selected |
|--------|-------------|----------|
| Gear icon in Dashboard AppBar (4th trailing icon) | Consistent with existing AppBar nav pattern | ✓ |
| Gear icon in Stats screen AppBar | Less discoverable | |
| Long-press on AppBar title | Hidden gesture | |

**User's choice:** Gear icon in Dashboard AppBar

---

## Settings Screen Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Two sections: Appearance + Notifications | Dark mode in section 1; weekly + reminder in section 2 | ✓ |
| Single flat list | No sections, just toggles | |
| Three sections | Each notification type gets own section header | |

**User's choice:** Two sections (Appearance + Notifications)

---

## Dark Mode Toggle UI

| Option | Description | Selected |
|--------|-------------|----------|
| SegmentedButton with 3 options | Compact single row | |
| RadioListTile rows | Three rows with descriptions, more space | ✓ |
| DropdownButton | Collapsed until tapped | |

**User's choice:** RadioListTile rows

---

## Dark Mode Reactivity

| Option | Description | Selected |
|--------|-------------|----------|
| Instant via Riverpod | MaterialApp.themeMode reacts dynamically | ✓ |
| On next app launch | Save to DB, restart required | |

**User's choice:** Instant via Riverpod

---

## Weekly Notification Schedule

| Option | Description | Selected |
|--------|-------------|----------|
| Monday morning at 8am | Shows last week, user sees it starting new week | |
| Sunday evening at 6pm | End-of-week, shows just-completed week | ✓ |
| User-configurable | Extra complexity, day + time picker needed | |

**User's choice:** Sunday at 6pm

---

## Weekly Notification Toggle

| Option | Description | Selected |
|--------|-------------|----------|
| Always-on (no toggle) | No schema changes needed | |
| User-toggleable in settings | Requires new schema field + migration | ✓ |

**User's choice:** Toggle in Notifications section (adds `weeklyNotificationEnabled` column)

---

## Weekly Notification Content

| Option | Description | Selected |
|--------|-------------|----------|
| Commute time + traffic time | Core value — "X total, Y in traffic" | ✓ |
| Full stats summary | Trip count + time + traffic + best/worst day | |
| Just total commute time | Minimal, one line | |

**User's choice:** Commute time + traffic time

---

## Tracking Reminder Time Picker

| Option | Description | Selected |
|--------|-------------|----------|
| Tap row → system TimePickerDialog | Standard Android pattern, no extra packages | ✓ |
| Inline drum/spinner picker | Embedded in settings, takes more space | |

**User's choice:** Tap to open TimePickerDialog

---

## Tracking Reminder Notification Text

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed: "Time to track your commute" | Simple, actionable | ✓ |
| Personalized with day of week | "Good morning! Ready to start your Monday commute?" | |

**User's choice:** Fixed text

---

## Claude's Discretion

- Exact notification channel IDs and names (new channels must not reuse `kTrackingNotificationChannelId`)
- Whether to extend `TrackingNotificationService` or create a new `NotificationService`
- Settings AppBar title
- Section header styling (color, weight, padding)
- Empty-week notification body text
- Time picker result format in ListTile subtitle
- Whether weekend toggle hides or disables when reminder is off
- File naming within `lib/features/settings/`
- Provider naming for user preferences stream

## Deferred Ideas

- Weekly notification configurable time/day — deferred, always Sunday 6pm for v0.1
- Notification deep-link to Stats screen — tapping opens Stats; deferred due to action wiring complexity
