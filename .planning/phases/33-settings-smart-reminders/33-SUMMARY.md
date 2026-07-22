---
phase: 33-settings-smart-reminders
completed: 2026-07-22
status: code_complete
mode: autonomous-subagents
requirements: [NOTIF-04, UX-11]
branch: main
commits:
  - 6a517f0 (Wave 1 — schema v10, day selection, default-on, uniform scheduling)
  - aacb412 (Wave 2 — ReminderSuggestionService)
  - 21f27c4 (Wave 3 — day picker, suggestion card, auto-pause explainer)
result: >
  Code complete on main, not pushed. The executing subagent stalled partway
  through Wave 3 (watchdog killed it while the UI wiring was written but
  uncommitted and one compile error stood); the orchestrator finished Wave 3,
  fixed a pending-timer test crash the new provider introduced, updated stale
  settings-screen assertions, and added the missing Wave 3 behavioural tests.
  Suite 836 → 896, analyze clean (0 errors, 0 warnings, 283 pre-existing info).
  The plan's D-03 "backfill existing users to ON" was found to be unsatisfiable
  without violating T-33-02 and was deliberately not done — see Decisions
  as-built. SC#1/#2/#4 depend on real notification delivery over real days and
  are unverified pending device.
---

# Phase 33 — Settings & Smart Reminders — SUMMARY

## What shipped

| Wave | Commit | Content |
|---|---|---|
| 1 | `6a517f0` | Schema **v10**: `reminderDays`, `reminderSuggestionState`, `reminderSuggestionValue`; DEFAULT change for `reminderEnabled`/`reminderTime` via `TableMigration`; `weekend_reminder → reminderDays` backfill. `scheduleReminder` rewritten to one uniform `dayOfWeekAndTime` alarm per selected day, IDs 20–26, cancel sweep widened to 20–26. `UserPreferencesValue` extended across all touch points. |
| 2 | `aacb412` | `ReminderSuggestionService`: median `to_office` GPS start time, ≥5 trips / 28 days, 15 min earlier rounded down to 5, manual entries excluded, >20-min re-offer rule. 22 unit tests. |
| 3 | `21f27c4` | `ReminderDayPicker` (Mon–Sun) replacing the weekend boolean; `ReminderSuggestionCard` + accept/dismiss handlers + permanent reminder-row subtitle; auto-pause `InfoIconButton` with the label corrected to "Ask to pause when stopped"; inert cutoff row deleted. |

**Verification:** `flutter test` → **896 passed, 10 skipped** (from 836). `flutter analyze` → 0 errors, 0 warnings, 283 pre-existing info lints. `dart format` clean. `SchemaVerifier` v9 → v10 green.

## Success criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Fresh install: reminder ON at 07:00 on weekdays, no Settings visit | ✅ by construction (`defaults()` + migration test line 219) — ⚠ real delivery unverified (device) |
| 2 | An explicitly-disabled user stays disabled after upgrade | ✅ T-33-02 migration test asserts `reminder_enabled = 0` survives v9 → v10 |
| 3 | `weekendReminder = true` → all seven days after upgrade | ✅ migration backfill + test |
| 4 | An arbitrary day subset schedules on exactly those days; deselect stops Sat/Sun | ✅ scheduling + widget tests — ⚠ real multi-day delivery unverified (device) |
| 5 | Zero days = no reminders, never silently reverts to weekdays | ✅ `_setReminderDays` + `reminder_days` parse tests |
| 6 | ≥5 `to_office` GPS trips in 28 days → suggested time (median − 15, rounded to 5) | ✅ service + widget accept test |
| 7 | Dismissing prevents re-offer until value moves >20 min | ✅ `shouldOffer` tests at deltas 0/19/20/21 + dismiss widget test |
| 8 | Manual entries do not influence the suggestion | ✅ service test |
| 9 | Cutoff row gone; direction labelling unchanged | ✅ row deleted; `morningCutoffHour` untouched in schema |
| 10 | Auto-pause info explains the app *asks*, non-technical | ✅ `InfoIconButton` + copy-quality test |
| 11 | `schemaVersion` 10; v9 → v10 preserves all preferences | ✅ `SchemaVerifier` + preservation tests |

## Decisions as-built

**D-03 "backfill existing users to ON" was not done, on purpose, because it cannot be done safely.** The plan reasoned that a `reminder_enabled = false` row could be told apart from a deliberate opt-out and only the former flipped to true. It cannot: `false` is simultaneously the old table default and the value a user writes by switching the reminder off, and SQLite keeps no third state to distinguish them. A blanket `columnTransformer: Constant(true)` — the only mechanism available — would re-enable notifications for everyone who turned them off, which is precisely T-33-02, the one outcome the phase forbids. So the migration copies existing values across untouched and changes only the DEFAULT for future inserts. **The observable consequence: only fresh installs get the 07:00 reminder; existing installs keep whatever they had (off, for anyone who never turned it on).** This satisfies SC#1 and SC#2 but not the unstated hope that reminders would retroactively appear for existing users. The reasoning is written into the migration comment at `database.dart:239-252`. This is the right call and the safe one, but it is a genuine narrowing of D-03 and is flagged for the user.

**Auto-pause label renamed** from "Auto-pause when stationary" to "Ask to pause when stopped" (`kSettingsAutoPauseLabelV2`), executing the plan's D-05 suggestion rather than leaving a documented-but-misleading label. The old constant is retained, unreferenced, per the append-only constants convention.

**Uniform scheduling** collapsed the old one-daily-vs-five-weekday branch into one `dayOfWeekAndTime` alarm per selected day. All-seven-days now costs seven exact alarms instead of one — accepted, as the plan stated, to delete the branch that let the ID-range mismatch exist.

## Surprises

**The subagent stalled mid-Wave-3 and had to be finished by the orchestrator.** Waves 1 and 2 were committed cleanly. Wave 3's UI code was fully written but uncommitted, with one compile error left standing (`allTripSummariesProvider.valueOrNull` — the wrong accessor; the house pattern is `.asData?.value`). The orchestrator fixed that, then found the new `reminderSuggestionProvider` had pulled `allTripSummariesProvider` — a real Drift stream — into the settings widget graph, which left a pending timer and crashed *every* settings widget test with "A Timer is still pending after the widget tree was disposed." The pump helper now overrides the suggestion provider, matching how the file already stubs `userPreferenceProvider` and `notificationServiceProvider`. Three stale assertions (renamed auto-pause label, the new day-selection subtitle replacing "· weekdays") were updated, and five Wave 3 behavioural tests were added — the stall had left the two new widgets with no coverage at all.

## What is NOT done

- **SC#1, #2, #4 real delivery** — the alarms are scheduled and unit-verified, but no notification has fired on a device across real days. Device queue.
- The **default-on reminder never reaches existing installs** (Decisions as-built). If retroactively enabling them is wanted, it needs a separate, explicit opt-in prompt — not a silent migration flip.

## Follow-ups

1. Device-verify a weekday-only subset fires on the right days and not the excluded ones, and that a fresh install fires 07:00 without a launch-time permission dialog.
2. Decide whether existing installs should be offered the default-on reminder via a one-time in-app prompt (the safe equivalent of the migration flip that could not be done).
3. Device-verify the recalibration suggestion appears after real commutes and matches a hand-computed median.
