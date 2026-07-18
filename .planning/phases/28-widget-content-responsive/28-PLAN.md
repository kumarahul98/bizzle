---
phase: 28-widget-content-responsive
created: 2026-07-18
status: in_progress
mode: autonomous-subagents
requirements: [WIDGET-02, WIDGET-03]
---

# Phase 28 — Widget content + responsive sizing

Fill the empty space in the (now full-width) home-screen widget with genuinely useful
information, and adapt what's shown to the widget's size.

## Background (from Phase 28 RnD)
- Widget never self-refreshes (`updatePeriodMillis=0`) — it only shows what we last pushed.
- **Active state:** speed / moving-vs-stuck / pause+break data is ALREADY computed in
  `TripSnapshot` every 1 s and reaches the UI isolate; it simply isn't pushed to the widget
  (only `distance`/`duration` are, `tracking_service.dart:206-224`). Cheap to add.
- **Idle state:** anything DB-derived needs a NEW main-isolate push path — the background
  isolate that owns widget writes today has no Drift access. Reuses `computeStatsSummary()`
  (`stats_service.dart`) — the same numbers `WeekLossCard` already shows.
- `minSdk = 34`, so Android 12+ responsive `RemoteViews(Map<SizeF, RemoteViews>)` is available.

## Data-key contract (SHARED — both the Dart and Android sides code against exactly this)
All keys are `String` unless noted; all live in `lib/config/constants.dart` next to the existing
`kWidgetKey*` block. Values are **pre-formatted display strings** — the native side never computes.

Existing (unchanged): `widget_title`, `widget_show_stats` (bool), `widget_distance`, `widget_duration`.

Active-state additions:
| Constant | Key | Example |
|---|---|---|
| `kWidgetKeySpeed` | `widget_speed` | `18 km/h` |
| `kWidgetKeyMoving` | `widget_moving` | `22m` |
| `kWidgetKeyStuck` | `widget_stuck` | `4m` |
| `kWidgetKeyPaused` | `widget_paused` (**bool**) | `true` → show a PAUSED chip |

Idle-state additions:
| Constant | Key | Example |
|---|---|---|
| `kWidgetKeyTodayTrips` | `widget_today_trips` | `2 trips` |
| `kWidgetKeyTodayTraffic` | `widget_today_traffic` | `34m in traffic` |
| `kWidgetKeyWeekTotal` | `widget_week_total` | `3h 40m` |
| `kWidgetKeyWeekStuck` | `widget_week_stuck` | `1h 12m lost` |

Empty/unknown values must be written as `--` (never blank) so the layout never collapses.

## Concern 1 — Dart: push the new data (Wave 1, Agent A)

**Active state** — in the existing throttled write block (`tracking_service.dart:192-226`, already
gated to once per `kTrackingWidgetRefreshInterval`=5 s, so this adds no new timer): format and push
`widget_speed`, `widget_moving`, `widget_stuck`, `widget_paused` from the same `TripSnapshot` the
block already has (`currentSpeedMs`, `timeMovingSeconds`, `timeStuckSeconds`, `isPaused`).
Reuse the existing duration-formatting style already in that block.

**Idle state** — add `writeWidgetIdleStats(...)` to
`lib/features/tracking/services/widget_state_writer.dart`, paralleling `writeWidgetIdle()`. It must
run on the **main isolate** (Drift lives there) and push the 4 idle keys. Wire it at three points:
1. `reconcileWidgetOnStartup()` — extend so that when tracking is NOT running it also pushes fresh
   idle stats (already called from `MainShell.initState`).
2. After a trip saves — `TripsServiceController.persistFinalizedTrip` (or the nearest post-save hook).
3. App resume — add a `WidgetsBindingObserver` to `_MainShellState` (none exists today) and push on
   `AppLifecycleState.resumed`.
Data: reuse `computeStatsSummary()` (`lib/features/stats/services/stats_service.dart`) for
`weekTotalSeconds`/`weekStuckSeconds`, and today's trips for the today line. **Do not invent new
aggregations.** Event-driven only — do NOT add an idle polling timer (battery; see the 5 s throttle
rationale at `tracking_service.dart:186-190`).

Files: `constants.dart`, `widget_state_writer.dart`, `tracking_service.dart`, `main_shell.dart`,
the post-save controller, + tests.

## Concern 2 — Android: responsive layouts (Wave 1, Agent B — fully disjoint files)

- Keep `widget_layout.xml` as the **compact** layout (works today; may only add the PAUSED chip).
- New `widget_layout_large.xml` — full-width horizontal (4×2) design:
  - **Idle:** left = existing circular START button; right = stats block —
    `widget_today_trips` · `widget_today_traffic`, then `widget_week_total` / `widget_week_stuck`.
  - **Active:** top row = DIST / TIME / SPEED; second row = moving vs stuck (`widget_moving` /
    `widget_stuck`) + PAUSED chip when `widget_paused`; bottom = existing PAUSE/STOP buttons.
  - Keep the same button IDs (`btn_start_commute`, `btn_pause_commute`, `btn_stop_commute`) so the
    existing click intents keep working unchanged.
- `widget_info.xml` — `targetCellWidth="4" targetCellHeight="2"` (full-width default), keep
  `resizeMode="horizontal|vertical"`, keep `minResizeWidth/Height` so it can still shrink to 2×2.
- `CommuteWidgetProvider.kt` — build a `RemoteViews(mapOf(SizeF(110f,110f) to compact,
  SizeF(250f,110f) to large))`. Build each `RemoteViews` separately and set ONLY the IDs that exist
  in that layout (do not call setters for views absent from a layout). Both variants must wire all
  three click intents. Read the new keys with `"--"` / `false` defaults.

Files: `android/app/src/main/res/layout/widget_layout_large.xml` (new), `widget_layout.xml`,
`res/xml/widget_info.xml`, `kotlin/traevy/traevy/CommuteWidgetProvider.kt`. **No Dart.**

## Verification
- `flutter analyze` 0 new errors/warnings; full `flutter test` green (currently 664).
- `flutter build apk --release`.
- On device: resize the widget wide → rich stats appear; shrink to 2×2 → compact layout returns.
  Idle shows today/week numbers matching the in-app Stats + dashboard. Start a trip → speed and
  moving/stuck update ~every 5 s; pause → PAUSED chip. Buttons still start/pause/stop correctly.
