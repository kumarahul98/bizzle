---
phase: 25-interrupted-trip-recovery
verified: 2026-07-14T00:00:00Z
status: gaps_found
score: 1/5 must-haves verified
overrides_applied: 0
gaps:
  - truth: "While a trip is active, its state (route, timing, breaks, direction) is persisted durably so it survives a force-quit / app-swipe / OS kill (SC#1, TRACK-13)"
    status: failed
    reason: "The persistence hot path is dead code in production. TripAccumulator only writes active_trip.json when a non-null TripStatePersister is injected, but none of the four production construction sites pass one, so _persister is always null and _persistState() returns immediately at every call. active_trip.json is never written during a real trip."
    artifacts:
      - path: "lib/features/tracking/services/main_isolate_tracking_engine.dart"
        issue: "Lines 119 & 121 construct TripAccumulator.restore(...) and TripAccumulator(startedAt:...) with NO persister argument."
      - path: "lib/features/tracking/services/tracking_service.dart"
        issue: "Lines 85 & 93 (background/fbs isolate — the real Android path) construct TripAccumulator and TripAccumulator.restore with NO persister argument."
      - path: "lib/features/tracking/services/trip_accumulator.dart"
        issue: "_persistState() (line 249) early-returns when _persister == null (line 251); the whole addSample/pause/resume→saveState chain is therefore never exercised in production."
    missing:
      - "Inject a TripStatePersister() into TripAccumulator at all four production construction sites (main_isolate_tracking_engine.dart:119,121 and tracking_service.dart:85,93), including the restored accumulator on resume so a resumed trip continues persisting."
      - "A test that constructs the accumulator the way production does and asserts saveState is actually invoked from addSample/pause/resume (current tests only cover dumpState/restore round-trip and standalone file I/O, so the missing wire is invisible to the green suite)."
  - truth: "On next launch, if a trip was interrupted, the app detects this and logs it (SC#2, TRACK-13)"
    status: partial
    reason: "Detection is correctly wired (TrackingNotifier.build → _checkInterruptedTrip → persister.loadState → debugPrint + TrackingInterrupted), but it can never fire in production because SC#1 is broken — no active_trip.json is ever written, so loadState() always returns null."
    artifacts:
      - path: "lib/features/tracking/providers/tracking_providers.dart"
        issue: "Detection logic is sound (lines 189-196) but starved of input by the upstream persistence gap."
    missing:
      - "Close the SC#1 persistence gap so a real interruption leaves a file for loadState() to find."
  - truth: "The user is presented with a clear prompt offering resume or discard (SC#3, TRACK-13)"
    status: partial
    reason: "RecoveryPromptDialog is fully built (barrierDismissible false via PopScope, correct copy/tokens) and wired via MainShell ref.listen on TrackingInterrupted, but is unreachable because TrackingInterrupted is never emitted in production (cascade from SC#1)."
    artifacts:
      - path: "lib/features/tracking/widgets/recovery_prompt_dialog.dart"
        issue: "Correct in isolation; never shown at runtime due to upstream gap."
    missing:
      - "Close the SC#1 persistence gap."
  - truth: "Resuming restores accumulated state and continues as one trip; discarding cleans up with no orphan (SC#4, TRACK-13)"
    status: partial
    reason: "resumeInterruptedTrip/discardInterruptedTrip and the full start(initialAccumulatorState) plumbing (controller → event source → kSetInitialStateCommand → isolate → TripAccumulator.restore) are correctly implemented and wired. But the path is unreachable (cascade from SC#1), AND even after a resume the restored accumulator is itself built without a persister, so a resumed trip would not re-persist and a second interruption would be lost."
    artifacts:
      - path: "lib/features/tracking/services/tracking_service.dart"
        issue: "Line 93 restores without a persister, so a resumed trip stops persisting again."
    missing:
      - "Close the SC#1 persistence gap, including wiring the persister into the restored accumulator on resume."
deferred: []
human_verification:
  - test: "End-to-end interrupted-trip recovery on a real Android device"
    expected: "After the persistence gap is closed: start a trip, force-quit/swipe-away the app mid-trip, relaunch, and confirm the recovery prompt appears with accumulated distance/timing/breaks intact; Resume continues the same record and Discard removes it with no orphan trip."
    why_human: "Requires actually killing the OS process on a device; cannot be confirmed statically. Currently blocked — the static gap means this would fail today."
---

# Phase 25: Interrupted-Trip Recovery Verification Report

**Phase Goal:** A commute interrupted by a force-quit, app-clear, or OS-level kill is never silently lost — its state is persisted continuously, and on next launch the user is told about the interrupted trip and can resume or discard it.
**Verified:** 2026-07-14T00:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification (traceability-debt closure from v0.3 milestone audit)

## Goal Achievement

### Observable Truths

| #   | Truth (ROADMAP SC) | Status | Evidence |
| --- | ------------------ | ------ | -------- |
| 1   | While active, trip state is persisted durably so it survives a force-quit / swipe / OS kill (SC#1) | ✗ FAILED | Persister is never injected into the production `TripAccumulator`; `_persistState()` is a permanent no-op (`_persister == null`), so `active_trip.json` is never written during a real trip. |
| 2   | On next launch, an interrupted trip is detected and logged (SC#2) | ⚠️ PARTIAL | Detection wiring is correct (`_checkInterruptedTrip` → `loadState` → `debugPrint` + `TrackingInterrupted`) but starved: `loadState()` always returns null because nothing is ever saved. |
| 3   | User is presented a clear resume/discard prompt (SC#3) | ⚠️ PARTIAL | `RecoveryPromptDialog` built to spec and wired via `MainShell` `ref.listen`, but never triggered (cascade from SC#1). |
| 4   | Resume restores state and continues as one trip; discard cleans up with no orphan (SC#4) | ⚠️ PARTIAL | Resume/discard + full `start(initialAccumulatorState)` plumbing implemented and wired; unreachable, and the restored accumulator is also persister-less so a resumed trip would not re-persist. |
| 5   | A clean stop leaves no interrupted-trip state, so the prompt never appears after a normal finish (SC#5) | ✓ VERIFIED (vacuous) | `finalize()` calls `_persister?.clear()`; but since nothing is ever persisted, no `active_trip.json` ever exists to leak. True today only because persistence is entirely inert. |

**Score:** 1/5 truths verified (SC#5, and only vacuously)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/features/tracking/services/trip_state_persister.dart` | File I/O for `active_trip.json` (save/load/clear) | ✓ VERIFIED | Complete, robust (cached dir Future, systemTemp fallback, tolerant decode). Unit-tested. |
| `lib/features/tracking/services/trip_accumulator.dart` | `dumpState()` / `restore()` + continuous persist on update | ⚠️ ORPHANED | `dumpState`/`restore`/`_persistState` all present and correct, but `_persistState` never runs in production (persister never injected). |
| `lib/features/tracking/state/tracking_state.dart` | `TrackingInterrupted(snapshot)` variant | ✓ VERIFIED | Added to sealed hierarchy carrying the raw snapshot map. |
| `lib/features/tracking/providers/tracking_providers.dart` | Detect on launch + resume/discard notifier methods | ⚠️ ORPHANED | Logic correct and self-consistent, but unreachable due to upstream persistence gap. |
| `lib/features/tracking/widgets/recovery_prompt_dialog.dart` | Modal prompt, non-dismissible, Resume/Discard | ✓ VERIFIED | Matches UI-SPEC (PopScope canPop:false, tokens, copy constants). |
| `lib/features/shell/main_shell.dart` | Listen for `TrackingInterrupted`, show/dismiss dialog | ✓ VERIFIED | `ref.listen` shows dialog with `barrierDismissible:false` and pops on transition away. (Note: lives at `features/shell/`, not `core/widgets/` as the plan stated.) |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `main_isolate_tracking_engine.dart` (prod) | `trip_state_persister.dart` | `TripAccumulator(persister:)` | ✗ NOT_WIRED | Lines 119/121 construct the accumulator with no persister. |
| `tracking_service.dart` (fbs/prod) | `trip_state_persister.dart` | `TripAccumulator(persister:)` | ✗ NOT_WIRED | Lines 85/93 construct the accumulator with no persister — the real Android path. |
| `trip_accumulator.dart` addSample/pause/resume | `trip_state_persister.dart` | `saveState(dumpState())` | ⚠️ PARTIAL | Call sites exist (lines 315/327/342/383/394/409) but gated behind null persister. |
| `main_shell.dart` | `tracking_providers.dart` | `ref.listen(TrackingInterrupted)` → `RecoveryPromptDialog` | ✓ WIRED | Correct. |
| `tracking_providers.dart` | `trip_state_persister.dart` | `loadState()` / `clear()` | ✓ WIRED | Detection + discard use a default `TripStatePersister()` (same app-docs dir). |
| `tracking_providers.dart` resume | engine | `controller.start(initialAccumulatorState:)` | ✓ WIRED | Full chain controller → event source → `kSetInitialStateCommand` → isolate → `TripAccumulator.restore`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `tracking_providers.dart` (`_checkInterruptedTrip`) | `snapshot` | `TripStatePersister.loadState()` reading `active_trip.json` | No — file is never written in production | ✗ DISCONNECTED |
| `recovery_prompt_dialog.dart` | `TrackingInterrupted` state | `TrackingNotifier` | No — state never emitted at runtime | ✗ DISCONNECTED |

The upstream producer (`TripAccumulator._persistState` → `saveState`) never runs, so every downstream consumer is fed an empty source. The pieces are individually correct; the pipe is severed at the very first link.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Serialization round-trips losslessly | `trip_accumulator_test.dart` "dumpState and restore round-trips" | Passes (dump→restore→identical snapshot & finalize) | ✓ PASS |
| Persister file I/O save/load/clear | `trip_state_persister_test.dart` | Passes (with injected temp dir) | ✓ PASS |
| Production accumulator actually persists during a trip | (no such test exists) | Not covered — green suite never exercises the injected-persister path | ✗ FAIL (gap) |
| Force-quit → relaunch → prompt on device | device only | Cannot run statically | ? SKIP → human |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| TRACK-13 | 25-01, 25-02, 25-03 | Persist active-trip state continuously; on next launch detect + log interruption, inform user, offer resume/discard | ✗ BLOCKED | All sub-mechanisms (serialize, restore, detect, prompt, resume/discard) are implemented and individually wired, but the continuous-persistence link is missing in production, so the end-to-end requirement is not met. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `trip_accumulator.dart` | 249-251 | Guarded no-op (`if (_persister == null) return;`) with no production caller supplying a persister | 🛑 Blocker | Entire persistence feature is inert in production. |
| `main_isolate_tracking_engine.dart` / `tracking_service.dart` | 119,121 / 85,93 | Accumulator constructed without the collaborator that makes TRACK-13 work | 🛑 Blocker | Root cause of the gap. |

### Human Verification Required

### 1. End-to-end interrupted-trip recovery on a real Android device

**Test:** Start a trip, force-quit / swipe-away the app (or trigger an OS kill) mid-trip, relaunch, and observe the recovery prompt. Then exercise both Resume and Discard.
**Expected:** Prompt appears with accumulated distance/timing/breaks preserved; Resume continues the same record and keeps recording; Discard removes state with no orphan trip; a normal clean stop never shows the prompt.
**Why human:** Requires actually killing the OS process on a device — not statically verifiable. Note: this is currently expected to FAIL because of the persistence-wiring gap above; it is listed for confirmation once that gap is closed, not as an independent passing item.

### Gaps Summary

Phase 25 is ~90% built and remarkably clean at every individual layer: `TripStatePersister` (file I/O), `TripAccumulator.dumpState/restore` (lossless serialization), the `TrackingInterrupted` sealed state, the launch-time detection notifier, the `RecoveryPromptDialog`, the `MainShell` listener, and the full `start(initialAccumulatorState)` resume plumbing across controller/event-source/isolate. Each is correctly wired to its immediate neighbors and is covered by green unit tests.

But there is exactly one missing wire, and it is the load-bearing one: **no production code ever injects a `TripStatePersister` into the `TripAccumulator`.** All four construction sites (`main_isolate_tracking_engine.dart:119,121` and the real Android `tracking_service.dart:85,93`) build the accumulator with `persister == null`, so `_persistState()` early-returns on every GPS sample, pause, and resume. `active_trip.json` is therefore never written, which means detection can never fire, the prompt never appears, and resume/discard are unreachable. The clean-stop criterion (SC#5) passes only vacuously because there is never any state to leak.

The green test suite hides this because tests either (a) exercise the persister/serializer directly with injected fakes, or (b) construct the accumulator without a persister and only assert serialization — none construct it the way production does and assert `saveState` is called. This is the classic "wired in tests, unwired in production" stub pattern.

**Fix is small and localized:** pass `TripStatePersister()` into `TripAccumulator(...)` and `TripAccumulator.restore(...)` at the four production sites (including on resume, so a recovered trip keeps persisting), and add a test that asserts a production-shaped accumulator actually writes on addSample/pause/resume.

---

_Verified: 2026-07-14T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
