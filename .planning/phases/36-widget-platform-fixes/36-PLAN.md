---
phase: 36-widget-platform-fixes
created: 2026-07-21
status: not_started
mode: manual-gsd
requirements: [WIDGET-03, UX-12, TRACK-16]
depends_on: [22, 27, 28]
result: >
  NOT STARTED. Plan only. No schema change. Independent of Phases 31-35 —
  touches only Android resources, the permission service, and the tracking
  notification path. May run in parallel with any of them.
---

# Phase 36 — Widget & Platform Fixes

**Goal**: The home-screen widget fits where it should and its stop button reads as stop;
"Open settings" lands on the location permission itself; and the notification's Stop
button visibly stops the trip instead of appearing to merely open the app.

**Depends on**: Phase 22 (the widget), Phase 27 (the auto-pause confirm pattern this
mirrors), Phase 28 (the responsive two-layout sizing this adjusts)

---

## D-01 — Halve the widget's vertical height

`res/xml/widget_info.xml` currently declares `minHeight="110dp"`,
`minResizeHeight="100dp"`, `targetCellHeight="2"`. Halve to `minHeight="55dp"`,
`minResizeHeight="50dp"`, `targetCellHeight="1"`.

The declaration alone is not the whole change. Both layout roots are `match_parent`, so
they will simply be squeezed: `widget_layout.xml` carries a **64dp** start button plus
padding that cannot fit in one cell, and the pause and stop buttons are 48dp. Reduce the
compact layout's button sizes and internal padding to fit a single row cleanly, and
verify text does not clip at the smallest resize.

Also re-check the size-selection breakpoint at `CommuteWidgetProvider.kt:52-57`. It
switches layouts on **width** (250dp), which is unaffected by a height change — but the
large layout at one cell tall is a different proposition than at two, so confirm the
large variant still renders sensibly rather than assuming the width rule carries over.

`updatePeriodMillis="0"` stays: the widget is push-updated from Dart and must not
self-refresh.

## D-02 — Give stop a real stop icon

`btn_stop_commute` uses **`@android:drawable/ic_media_ff`** — the platform
*fast-forward* glyph (▶▶) — in both `widget_layout.xml:160` and
`widget_layout_large.xml:328`. That is the entire cause of the reported bug: a
double-triangle at 18dp reads as play. It also reuses `widget_btn_record`, the red
*record* oval, as its background.

There is no stop drawable in the project at all; `res/drawable/` holds only
`launch_background`, `widget_bg`, `widget_btn_pause` and `widget_btn_record`.

Add `res/drawable/ic_widget_stop.xml` — a vector square, the universal stop glyph, sized
to match the existing 18dp icon slots — and `res/drawable/widget_btn_stop.xml` for its
own background oval, so stop is visually distinct from the record button rather than
borrowing its identity.

Do not use a platform `@android:drawable` again. The platform set has no stop icon, which
is why `ic_media_ff` was reached for in the first place.

## D-03 — Deep-link to the app's permission page

`TrackingPermissionService.openSystemSettings()` (`tracking_permission_service.dart:266`)
calls `openAppSettings()` from permission_handler, which lands on **App Info** — one
level short of where the user was told they were going.

Add a platform-channel method firing `Settings.ACTION_APP_PERMISSIONS` (API 23+) with
`Intent.setData(Uri.fromParts("package", packageName, null))`, falling back to
`ACTION_APPLICATION_DETAILS_SETTINGS` on `ActivityNotFoundException`.

**The fallback is mandatory, not defensive padding.** `ACTION_APP_PERMISSIONS` is not
guaranteed to resolve on every OEM skin, and an unhandled `ActivityNotFoundException`
crashes the app at exactly the moment the user is already frustrated by a denied
permission. Deep-linking straight to the *Location* toggle within that page is not
achievable through public API — the permissions list is as far as Android allows, and
attempting a vendor-specific intent would be fragile across the OEM range this app
targets.

While here, unify the three inconsistent denial paths, which currently send users to
three different places:

- `TrackingPermissionService.openSystemSettings()` → app settings (permission_handler)
- `hero_record_card.dart:126` → `Geolocator.openLocationSettings` — the **device-wide**
  location screen, a different destination entirely
- `main_shell.dart:153` → a bare SnackBar with no way to act on it

All three route through the new method. Delete `permission_gate.dart`: it maps statuses
to titles and buttons and is mounted nowhere since the tracking screen was removed in
08-08, so it is dead code that will otherwise be mistaken for the canonical path.

## D-04 — The notification Stop action relays a confirmation

Both handlers already invoke `kStopTrackingEvent` — `_onForegroundResponse`
(`tracking_notification_service.dart:394`) and the top-level background handler
(`:423`). So the trip most likely *does* stop. What the user observes is that the action
also carries `showsUserInterface: true` (`:224-240`), which brings the activity to the
foreground, producing an experience indistinguishable from "the Stop button just opened
the app" — no dialog, no confirmation, no visible state change at the moment of tapping.

**This exact complaint was already diagnosed and fixed for the neighbouring action.** On
2026-07-21 the auto-pause action was changed (D-02) from acting directly to relaying a
confirm command, and the comment left at `:433` records the reasoning verbatim:

> does NOT pause. Relays to the service, which bounces `kAutoPauseConfirmEvent` back to
> whichever isolate owns the UI so the user gets a confirmation dialog. Pausing here
> directly — the previous behaviour — gave zero feedback that anything had happened.

Mirror it. Introduce `kStopConfirmCommand`; the service bounces `kStopConfirmEvent` to
whichever isolate owns the UI, which shows a "Stop this trip?" dialog. Confirm stops;
cancel leaves the trip recording and the notification intact.

Reuse the widget's existing stop-confirm dialog (`main_shell.dart:98-113`) rather than
writing a second one, so the notification and widget paths cannot drift apart in wording
or behaviour.

Two constraints carried over from the existing handlers, both load-bearing:

- The background handler **must** stay top-level and `@pragma('vm:entry-point')`
  annotated. Without the pragma the tree-shaker drops it in release builds and the action
  silently becomes a no-op — recorded as Pitfall 4 in `02-RESEARCH.md` §10.
- Exact action-id matching only (V5 validation, T-02-17). Do not loosen it to a prefix or
  contains check.

Investigate before building: confirm on a real device whether the trip currently stops.
If it does, this is purely a feedback fix; if it does not, there is a second bug in the
isolate relay and it must be recorded rather than papered over by the dialog.

---

## Execution waves (conflict-safe)

**Wave 1 — all three plans in parallel** (fully disjoint file sets)

- `36-01` — Android resources only: `widget_info.xml`, both layouts, the two new
  drawables. No Dart.
- `36-02` — permission deep-link: `MainActivity.kt` channel method,
  `tracking_permission_service.dart`, the two call-site unifications, deletion of
  `permission_gate.dart`.
- `36-03` — stop-confirm relay: `tracking_notification_service.dart`,
  `tracking_service.dart`, `main_shell.dart` dialog reuse, constants.

`36-02` and `36-03` both touch `main_shell.dart` — `36-02` at the SnackBar (`:153`),
`36-03` at the dialog (`:98-113`). Distinct regions, but they must not land
simultaneously without a rebase. If executed in parallel, `36-03` merges second.

---

## Threat model

| ID | Category | Asset | Decision | Mitigation |
|---|---|---|---|---|
| T-36-01 | Availability | Unresolvable permission intent crashing the app | mitigate | `ActivityNotFoundException` caught with a documented fallback to `ACTION_APPLICATION_DETAILS_SETTINGS` (D-03); never an uncaught `startActivity`. |
| T-36-02 | Data loss | An accidental Stop tap ending a commute mid-drive | **mitigate — the user-facing point of D-04** | Confirmation dialog before stopping; cancel leaves the trip and notification untouched. |
| T-36-03 | Availability | Stop action becoming a silent no-op in release builds | mitigate | Background handler stays top-level with `@pragma('vm:entry-point')`; a release-build device check is in Verification, since no unit test catches tree-shaking. |
| T-36-04 | Spoofing | A forged or stale notification action id | mitigate | Exact action-id matching retained (T-02-17); no prefix or substring matching. |
| T-36-05 | Availability | Widget content clipping or becoming untappable at one cell | mitigate | Compact layout paddings and button sizes reduced alongside the declaration (D-01); touch targets kept at 48dp minimum; verified by resizing on a real launcher. |
| T-36-06 | Data loss | The confirm relay never reaching the UI isolate, leaving the user unable to stop from the notification | mitigate | If confirmation cannot be delivered, the action must fall back to stopping directly rather than doing nothing — a stop the user did not confirm is recoverable via Trash (Phase 35); a trip that cannot be stopped is not. |

---

## Success criteria (what must be TRUE)

1. The widget can be placed and resized to a single cell tall on a real launcher without
   clipped text or unreachable buttons.
2. The stop button is unmistakably a stop control — a square glyph on its own background,
   not the platform fast-forward icon.
3. `ic_media_ff` appears nowhere in the project.
4. Denying location on a fresh install and tapping "Open settings" lands on the app's
   permission list, not App Info.
5. On a device where `ACTION_APP_PERMISSIONS` does not resolve, the fallback opens App
   Info and the app does not crash.
6. All three permission-denial paths lead to the same destination; `permission_gate.dart`
   is deleted.
7. Tapping Stop on the tracking notification brings the app forward **and** shows a
   "Stop this trip?" confirmation; confirming stops the trip, cancelling leaves it
   recording with the notification intact.
8. The notification stop path works in a **release** build with the app backgrounded.
9. The notification and widget stop confirmations use the same dialog and wording.

## Verification

- Unit: permission service calls the new channel method and handles the fallback branch.
- Unit: notification response handler emits `kStopConfirmCommand` for the exact stop
  action id, and ignores near-miss ids.
- Unit: the confirm-relay fallback in T-36-06 stops directly when the UI isolate is
  unreachable.
- Widget: the confirm dialog appears on `kStopConfirmEvent`; cancel leaves tracking
  active.
- `flutter analyze` and `dart format .` clean; Android resources build without lint
  warnings.
- **Manual (release build, real device)**: start a trip, background the app, tap Stop on
  the notification — confirm the app opens with the dialog and that confirming actually
  ends the trip. This is the one check that catches a tree-shaken background handler.
- **Manual**: resize the widget to one cell on a real launcher; confirm all three buttons
  are visible and tappable and that stop reads as stop.
- **Manual**: fresh install, deny location, tap "Open settings" — confirm the permission
  list opens. Repeat on a second OEM device if available, given the D-03 fallback.
