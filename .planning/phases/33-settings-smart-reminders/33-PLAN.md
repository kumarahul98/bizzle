---
phase: 33-settings-smart-reminders
created: 2026-07-21
status: not_started
mode: manual-gsd
requirements: [NOTIF-04, UX-11]
depends_on: [7, 31, 32]
result: >
  NOT STARTED. Plan only. Schema v10 — must land AFTER Phase 31 (v9) and BEFORE
  Phase 35 (v11). Must also land after Phase 32, which deletes _AccountSection
  from the same settings_screen.dart this phase restructures. Consumes the
  InfoSheet from Phase 31.
---

# Phase 33 — Settings & Smart Reminders

**Goal**: Reminders work the moment the app is installed, adapt to when the user
actually commutes instead of when they guessed, run only on the days they choose, and
Settings stops showing a control that does nothing.

**Depends on**: Phase 7 (the reminder scheduling this rewrites), Phase 31 (`InfoSheet`),
Phase 32 (which removes `_AccountSection` from the file this phase restructures)

---

## D-01 — Remove the inert cutoff row

`settings_screen.dart:179-186` renders `Cutoff "to office"` with a subtitle and **no
`onTap`** — it cannot be changed. The code carries its own admission: *"Wired in a
future plan — the settings notifier does not yet expose cutoff updates."*

Delete the row. Since Phase 21, direction comes primarily from Home/Office geofences;
the cutoff is a silent fallback, and the trip detail screen already lets the user fix a
mislabelled trip after the fact. A read-only row explaining an invisible fallback earns
none of the space it occupies.

`morningCutoffHour` / `eveningCutoffHour` **stay in the schema** at their default of 12
and keep working. Dropping columns in SQLite means a full table rebuild
(`TableMigration`), which is real migration risk for zero user benefit. `eveningCutoffHour`
has never had UI at all and does not gain any here.

## D-02 — Day-of-week selection replaces the weekend boolean

New column `reminderDays TEXT` defaulting to `'1,2,3,4,5'` — ISO-8601 weekday numbers,
Monday = 1, matching Dart's `DateTime.weekday` so no conversion table is needed anywhere.

Migration v10 adds the column and backfills from the existing boolean: rows with
`weekendReminder = true` become `'1,2,3,4,5,6,7'`, everything else keeps the weekday
default. `weekendReminder` **stays in the table**, unused, rather than triggering a
rebuild to drop it — same reasoning as D-01.

Then rewrite `scheduleReminder` (`notification_service.dart:141`). It currently branches:
one daily alarm at ID 20 using `DateTimeComponents.time` when weekends are included, or
five Mon–Fri alarms at IDs 20–24 using `dayOfWeekAndTime` otherwise. Collapse to **one
uniform path** — always one `dayOfWeekAndTime` alarm per selected day, at ID
`20 + (weekday - 1)`, giving the range **20–26**.

**The cancel sweep at `:146` must widen from 20–24 to 20–26 before anything else in the
function.** Missing this leaves orphaned Saturday and Sunday alarms firing forever after
a user deselects the weekend — the exact bug the uniform path is meant to prevent, and
one that no unit test will catch unless it asserts the cancel range explicitly.

The all-seven-days case loses its single-alarm optimisation and costs seven exact
alarms instead of one. That is an acceptable price for deleting the branch: the two-path
version is what allowed the ID-range mismatch to exist in the first place.

Empty selection is valid and means no reminders. It must not be conflated with
`reminderEnabled = false`; both independently suppress scheduling, and the UI shows the
toggle off *or* "No days selected" rather than silently re-enabling weekdays.

## D-03 — Reminder on by default at 07:00

`reminderEnabled` currently defaults to **false** and `reminderTime` has **no default at
all** (null). A fresh install therefore never reminds anyone, and the feature is
discoverable only by a user who goes looking for it.

Migration v10 flips `reminderEnabled` to default `true` and sets `reminderTime` to
`'07:00'`, backfilling existing rows. Changing an existing column default requires the
`m.alterTable(TableMigration(..., columnTransformer: ...))` technique — `addColumn`
cannot do it. Phase 8 already did exactly this for `autoPauseEnabled`
(`database.dart:138-180`); follow that shape, including the comment explaining why
`SchemaVerifier` forces it.

**Backfilling existing users is a deliberate choice, not a side effect.** A user who
installed earlier and never touched the setting has no reminder; leaving them alone means
the feature ships to new installs only. Turning it on for them is defensible because
they never *declined* it — the switch was off by default, not by their decision. Anyone
who explicitly turned it off will have `reminderEnabled = false` already, and the
`columnTransformer` must preserve that. **A blanket `Constant(true)` would silently
re-enable notifications for users who opted out, which is the one outcome this phase
must not produce.** Transform only rows still holding the old default.

`initialize()` (`:67`) already reschedules from the DB on every app start, so no new
wiring is needed.

One ordering hazard: on Android 13+ scheduling triggers the notification permission
prompt. Do not let a default setting produce a permission dialog on first launch — keep
the existing `kNotificationPermissionAnchorDays` gating and schedule only once
permission is actually held.

## D-04 — Recalibration suggests; it never writes silently

After **≥ 5 completed GPS trips** labelled `to_office` within the **last 28 days**,
compute the **median** local start time and suggest a reminder **15 minutes before it**,
rounded down to the nearest 5 minutes.

| Option | Verdict |
|---|---|
| Auto-apply the inferred time | **Rejected.** Silently moving someone's morning alarm is hostile, and a single bad inference destroys trust in the feature permanently. |
| Suggest, with accept or edit | **Chosen.** The request was to "show them the reminder time, allow them to edit". |
| Mean instead of median | **Rejected.** One 3am airport run drags the mean by half an hour at n=5. |
| Fewer than 5 trips | **Rejected.** Two commutes is not a pattern; suggesting from them produces a wrong answer at the worst possible moment — first impression. |

Manual entries are excluded (their start times are typed, not observed). Only
`to_office` drives the reminder: a return-commute reminder would fire while the user is
still at work, reminding them of something they cannot act on.

**Surfaced two ways**, because one alone fails: a dismissible card under the reminder
rows in Settings (discoverable, but gone once dismissed), and a permanent subtitle on the
reminder-time row reading "Suggested from your trips: 08:05" (always available, easy to
miss). Accept applies it; Edit opens the existing `_pickReminderTime` (`:326`) seeded
with the suggestion rather than the current 08:00 hardcode.

**Anti-nag** is the part that determines whether this feature is liked or hated. Two new
columns: `reminderSuggestionState TEXT` (`none|offered|accepted|dismissed`) and
`reminderSuggestionValue TEXT` (the HH:mm last offered). Re-offer only when a freshly
computed suggestion differs from the last offered value by **more than 20 minutes**. A
dismissal is remembered indefinitely for that value; drifting three minutes later over a
month must never re-prompt.

Computation runs on settings-screen open, not on every trip save. It is a read over at
most 28 days of trips, it is only ever displayed in Settings, and doing it on the trip
save path would put a query on the hot post-trip flow for a card nobody is looking at.

## D-05 — Auto-pause explainer, which must correct the label

`InfoSheet` beside the toggle at `:191-203`.

The copy has a real discrepancy to resolve. The setting says "Auto-pause when
stationary", but the app **never pauses on its own** — `AutoPauseDetector` only fires a
notification asking, and nothing happens without a tap
(`auto_pause_detector.dart`, and the 2026-07-21 D-02 change in
`tracking_notification_service.dart:433` that made even the notification action ask for
confirmation). A user reading the current label reasonably expects automatic pausing and
will conclude the feature is broken when their trip keeps recording.

Plain-language copy, no jargon: if you stay under 10 km/h for 15 minutes without a break,
a notification asks whether to pause; moving again resets the timer; nothing is ever
paused without tapping. No mention of m/s, radius, geofences, or sampling — there is no
radius involved at all, and inventing one to sound thorough would be wrong.

Consider renaming the label to "Ask to pause when stopped" in the same commit. The
explainer makes the mismatch visible; leaving the label misleading once it is documented
is worse than before.

---

## Execution waves (conflict-safe)

**Wave 1 — data and scheduling**

- `33-01` — schema **v10** (`reminderDays`, `reminderSuggestionState`,
  `reminderSuggestionValue`, plus the `reminderEnabled`/`reminderTime` default change via
  `TableMigration`), the `UserPreferencesValue` **6 touch points**, and the
  `scheduleReminder` rewrite including the widened cancel sweep. **Owns all Drift and
  notification-service work.**

**Wave 2 — inference** *(blocked on Wave 1)*

- `33-02` — `ReminderSuggestionService`: median computation, the 5-trip/28-day gate, the
  15-minute offset, and the >20-minute re-offer rule. Pure logic, heavily unit-tested.

**Wave 3 — UI** *(blocked on Waves 1 and 2)*

- `33-03` — day-of-week picker, removal of the cutoff row, the auto-pause `InfoSheet`,
  and the suggestion card + reminder-row subtitle.

Every preference write in Wave 3 must route through `_copyPrefs` (`:398`). It is the
mandatory full-field copy helper; bypassing it zeroes columns it does not name, and this
phase adds three new ones to keep in step.

---

## Threat model

| ID | Category | Asset | Decision | Mitigation |
|---|---|---|---|---|
| T-33-01 | Information disclosure | The suggested time reveals the user's routine on a screen visible over the shoulder | **accept** | Behind the device lock; strictly less than the trip list already on the dashboard. |
| T-33-02 | Data integrity | `columnTransformer` re-enabling notifications for users who deliberately turned them off | **mitigate — highest risk in this phase** | Transform only rows still at the old default; never a blanket `Constant(true)`. Explicit migration test asserting an opted-out row stays `false` across v9 → v10. |
| T-33-03 | Availability | Orphaned weekend alarms firing after deselection | mitigate | Cancel sweep widened to 20–26 *before* rescheduling (D-02), with a test asserting the cancelled ID range. |
| T-33-04 | Data integrity | Preference upsert zeroing unnamed columns | mitigate | All writes go through `_copyPrefs`, extended with the three new fields in the same commit that adds them. |
| T-33-05 | Annoyance / user trust | Repeated suggestion prompts | mitigate | `reminderSuggestionState` + the >20-minute delta rule (D-04); a dismissal persists indefinitely for that value. |
| T-33-06 | Tampering | Malformed `reminderDays` (empty, duplicates, out-of-range, non-numeric) | mitigate | Parse defensively: ignore unparseable entries, dedupe, clamp to 1–7. An empty result means no reminders, never a fallback to weekdays. |
| T-33-07 | Availability | Default-on scheduling triggering a permission prompt at first launch | mitigate | Schedule only when notification permission is already held; existing anchor-day gating retained (D-03). |

---

## Success criteria (what must be TRUE)

1. A fresh install has the daily reminder enabled at 07:00 on weekdays, with no visit to
   Settings.
2. An existing user who had explicitly disabled the reminder still has it disabled after
   upgrading to v10.
3. An existing user with `weekendReminder = true` has all seven days selected after
   upgrade.
4. Selecting an arbitrary subset of days schedules a reminder on exactly those days and
   on no others; deselecting a day stops it firing, including for Saturday and Sunday.
5. Selecting zero days results in no reminders, and does not silently revert to weekdays.
6. After 5+ `to_office` GPS trips in 28 days, Settings shows a suggested time derived
   from the median start, 15 minutes earlier, rounded down to 5 minutes.
7. Dismissing the suggestion prevents it reappearing until the computed value moves by
   more than 20 minutes.
8. Manual entries do not influence the suggestion.
9. The cutoff row no longer exists; direction labelling behaviour is unchanged.
10. An info icon beside auto-pause explains that the app **asks** rather than pauses, in
    non-technical language.
11. `schemaVersion` is 10 and a v9 → v10 upgrade preserves all existing preferences.

## Verification

- Unit: median start time — even and odd counts, outlier resistance, trips spanning
  midnight, fewer than 5 trips returns no suggestion, manual entries excluded, trips
  older than 28 days excluded.
- Unit: 15-minute offset with 5-minute rounding, including wrap below midnight.
- Unit: re-offer rule — deltas of 0, 19, 20, 21 minutes against each
  `reminderSuggestionState` value.
- Unit: `reminderDays` parsing — empty, `'0'`, `'8'`, `'3,3,1'`, `'abc'`, trailing comma.
- Unit: `scheduleReminder` schedules exactly one alarm per selected day at the expected
  IDs, and cancels 20–26 first.
- Migration: `SchemaVerifier` v9 → v10, **plus** an explicit test that a row with
  `reminder_enabled = 0` survives the transformer unchanged (T-33-02).
- Widget: day picker reflects and writes `reminderDays`; the cutoff row is absent.
- `flutter analyze` and `dart format .` clean.
- **Manual**: set a weekday-only subset on a real device, wait out one excluded day, and
  confirm nothing fires.
- **Manual**: fresh install on a real device; confirm the 07:00 reminder fires the next
  morning without touching Settings, and that no permission dialog appears at launch.
- **Manual**: after enough real commutes, confirm the suggestion appears and matches a
  hand-computed median from the trip list.
