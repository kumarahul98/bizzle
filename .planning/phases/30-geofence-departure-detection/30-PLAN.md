---
phase: 30-geofence-departure-detection
created: 2026-07-19
status: blocked_on_spike
mode: manual-gsd
requirements: [AUTO-03]
depends_on: [21]
blocked_by: "P0 spike (task 30-00) — requires a real drive with logcat attached"
result: >
  NOT STARTED, and deliberately NOT executable yet. Task 30-00 is a
  throwaway measurement spike that must run on a real device, in a real
  car, before ANY production code is written. If the spike shows trigger
  latency is unusable, this phase is cancelled rather than built — see the
  kill criteria. Do not skip 30-00 to "get started on the UI".
---

# Phase 30 — Geofence Departure Detection

**Goal**: The app notices the user has left Home (or Office) and starts tracking on its
own, so a commute is captured even when the user forgets to press Start.

**Depends on**: Phase 21 — the Home/Office coordinates and the geofence resolver already
exist. This phase adds *detection*, not storage. Phase 21 geofences a trip **after** it
ends (to label direction); this phase acts on a boundary crossing **as it happens**.

---

## Why this phase leads with a spike

The entire feature rests on one unverified assumption: **that Android's geofence
`GEOFENCE_TRANSITION_EXIT` fires soon enough after the user actually leaves to be
useful.** Android geofence triggers are documented as best-effort with a
"responsiveness" hint, and in practice on Doze-aggressive OEM builds the delay can run
from ~30 seconds to several minutes.

That number decides whether the feature is worth building at all:

- If EXIT fires within ~60s, we lose a tolerable head of the trip and can backfill the
  start point from the Home coordinate.
- If it routinely takes minutes, an "automatic" trip would begin partway down the road
  with a mangled start, a wrong distance, and a corrupted stuck-vs-moving ratio — which
  attacks the app's core value ("show people the reality of their commute"). A feature
  that silently produces wrong stats is worse than no feature.

Nothing in the codebase or in public docs settles this for the user's actual device and
OEM. Only a drive settles it. **Writing the permission flow and settings toggle first
would be building the trim of a car whose engine may not start.**

## 30-00 — SPIKE (throwaway, blocking, P0)

Not production code. Goal is one table of numbers.

**Method**
- Minimal debug build: register a single EXIT geofence on the saved Home coord with
  radius 150 m (matching the Phase 21 confidence radius) and `setInitialTriggerBehavior`
  left at default.
- On receiver fire, log a monotonic timestamp + the fix that triggered it. Coordinates
  are NOT logged (T-21-03 stands) — log the *delay*, not the *place*.
- Drive away from Home normally. Note wall-clock time of actually crossing ~150 m.
- Repeat **≥5 runs**, including at least one cold-start (app force-stopped) and one after
  the phone has sat idle overnight (Doze-adjacent).

**Record per run**: time-to-fire, whether the app was foreground / background /
force-stopped, battery-saver state, and whether it fired at all.

**Kill criteria — decide BEFORE looking at the data:**

| Median time-to-fire | Decision |
|---|---|
| ≤ 60 s, ≥ 4/5 runs fire | Build as planned. |
| 60–180 s, or 3/5 fire | Build only with the D-02 confirmation prompt; never auto-start silently. |
| > 180 s, or ≤ 2/5 fire, or force-stopped never fires | **Cancel the phase.** Record the numbers in the roadmap so this is not re-proposed from optimism later. |

The middle row is the likely one, and it is why D-02 exists.

---

## Provisional decisions (valid only if the spike passes)

## D-01 — This is where `configureFlutterEngine` finally earns its place

Phase WR-05 was *wrongly* assumed to need a `MainActivity.configureFlutterEngine`
MethodChannel (see `ef4d03e` — the call originated in the background service isolate,
so an activity-engine handler was invisible to it, and a file-based store replaced it).

A geofence `BroadcastReceiver` is genuinely different: it is native Android code with no
Dart isolate of its own, and it must hand an event to the app. This phase is the first
real need for that native seam. **Do not cite WR-05 as precedent for how to wire it** —
that precedent was retracted.

## D-02 — Confirm, do not auto-start (default)

On EXIT, post a notification: *"Heading out? Tap to start tracking."* rather than
starting a recording silently. Rationale: a false positive that silently records the
user walking to a corner shop produces a junk trip in their history and burns battery;
a false positive that shows a dismissible notification costs nothing. A "start
automatically without asking" setting can come later, once the spike numbers and real
usage justify it.

## D-03 — Permissions

Needs `ACCESS_BACKGROUND_LOCATION`, which on Android 11+ cannot be requested inline —
it requires a trip to system settings with a rationale screen first. This is a
meaningful UX cost and a common install-time drop-off point. The settings toggle must
be OFF by default and explain the permission before requesting it.

## D-04 — Interaction with targetSdk 35 / Android 15

Foreground-service launch restrictions tightened in Android 14/15. If the notification
in D-02 leads to starting the tracking foreground service, verify that path is legal
from a broadcast-receiver-initiated context on 35 — a `ForegroundServiceStartNotAllowed`
crash here would be an on-device-only failure that no test in this repo would catch.
Depends on `chore/android-target-sdk-35` landing.

---

## Threat model (provisional)

| ID | Category | Asset | Decision | Mitigation |
|---|---|---|---|---|
| T-30-01 | Information disclosure | Home coord passed to the native geofence API | mitigate | The coord crosses into Android's geofence registration only. Never logged (T-21-03 upheld — the spike logs delays, not places). |
| T-30-02 | Denial of service | Battery drain from background location | mitigate | Geofence API is OS-batched and materially cheaper than a live location stream. Feature is opt-in and OFF by default (D-03). |
| T-30-03 | Data integrity | Junk trips from false-positive exits | mitigate | D-02 confirmation prompt — no silent recording. The Phase 21 short-trip discard (D-10) is a second net. |

---

## Success criteria (what must be TRUE)

0. **The 30-00 spike has run and passed its kill criteria.** No other criterion may be
   assessed before this one.
1. With the feature on and Home set, driving away from Home produces the D-02
   notification within the spike-measured latency budget.
2. Tapping the notification starts tracking; ignoring it leaves no trace — no partial
   trip, no orphaned service.
3. The toggle is OFF by default and no background-location permission is requested until
   the user turns it on.
4. Feature off ⇒ behavior is byte-for-byte the existing app (purely additive).
5. No coordinate appears in any log.
