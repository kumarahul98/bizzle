# Phase 2: Core Tracking - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `02-CONTEXT.md` — this log preserves the discussion.

**Date:** 2026-04-12
**Phase:** 02-core-tracking
**Mode:** discuss (interactive)
**Areas discussed:** GPS stack, app kill resilience, permission flow, min trip threshold, active tracking UI, notification content, metrics timing

## Gray Areas Presented

| # | Area | Options offered |
|---|------|----------------|
| 1 | GPS package | Tracelet-first / geolocator+flutter_background_service (recommended) / raw platform channels |
| 2 | App kill resilience | Best-effort foreground service (recommended) / incremental sample persistence / Claude decides |
| 3 | Permission flow | Two-step while-using → always (recommended) / always upfront / foreground only |
| 4 | Min trip threshold | 30s + 100m (recommended) / no threshold / confirm dialog |
| 5 | Active tracking UI | Live stats (recommended) / minimal button + timer / rich with map |
| 6 | Notification content | Live-updating (recommended) / static / static + Stop button |
| 7 | Metrics timing | Streaming accumulators (recommended) / post-process on stop / Claude decides |

## User Decisions

### 1. GPS package → **Try Tracelet first**
- Researcher verifies Tracelet exists and works on Android 14 foreground service, then falls back to `geolocator + flutter_background_service` if it fails any check.
- **Divergence from recommendation:** recommended was "geolocator direct"; user asked for a Tracelet verification pass first.

### 2. App kill resilience → **Best-effort foreground service (recommended)**
- Samples live in memory. No incremental persistence. Accept data loss on process kill.

### 3. Permission flow → **Two-step (recommended)**
- `ACCESS_FINE_LOCATION` on first launch, upgrade to `ACCESS_BACKGROUND_LOCATION` on first Start tap.

### 4. Min trip threshold → **30s AND 100m (recommended)**
- Both thresholds must be met. Short trips show a snackbar and are discarded.

### 5. Active tracking UI → **Live stats (recommended)**
- Three ticking tiles (duration / distance / current speed) + big Stop button. No map in Phase 2.

### 6. Notification content → **Static text + Stop button**
- "Recording commute" static body with a Stop action. No per-sample refreshes.
- **Divergence from recommendation:** recommended was live-updating; user chose the cheaper static-text-with-action variant.

### 7. Metrics timing → **Streaming accumulators (recommended)**
- Moving and stuck counters update on every GPS sample. Live stats UI reads directly from the notifier.

## Scope Redirections

None — all gray areas stayed inside TRACK-01/02/04/05 + UX-03. Dashboard, maps, direction labeling, edit/delete, and sync were all flagged as future-phase concerns in the deferred section.
