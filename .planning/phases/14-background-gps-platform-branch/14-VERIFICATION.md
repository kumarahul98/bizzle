---
phase: 14-background-gps-platform-branch
status: human_needed
verified: 2026-06-02
verifier: inline (gsd-verifier agent socket-dropped at 42 tool calls; orchestrator completed verification against the live codebase + full test run)
score: automated 7/7 verified; 3 device behaviors human-gated
requirements: [IOS-06, IOS-07, IOS-08]
---

# Phase 14 — Verification: Background GPS Platform Branch

**Goal:** Users can record a full commute on iOS with GPS continuing uninterrupted while the app is backgrounded or the screen is off, and moving/stuck traffic stats remain accurate.

## Verdict

**Automated layer: PASS (7/7).** All code-verifiable must_haves confirmed against the live codebase, not just SUMMARY claims. Full `flutter test` suite green (397 passed, ~10 pre-existing skips, 0 failures) — Android regression intact. `flutter analyze`: no errors; Phase 14 source/test files clean (the only repo warnings are pre-existing in `theme_extension_test.dart`, untouched here).

**Status: `human_needed`.** Three success criteria are intrinsically human-gated — the iOS Simulator cannot reproduce CoreLocation background suspension or the Approximate-Location privacy control. The CODE for all three is implemented and unit-tested; only the on-device behavior remains to confirm.

## Automated must_haves — verified in codebase

| # | Must-have | Evidence | Status |
|---|-----------|----------|--------|
| 1 | `buildLocationSettings()` selects via `defaultTargetPlatform`; iOS → `AppleSettings(accuracy: high, allowBackgroundLocationUpdates: true, pauseLocationUpdatesAutomatically: false, activityType: automotiveNavigation, showBackgroundLocationIndicator: true)`; Android `AndroidSettings` unchanged (SC#4, D-02) | `lib/features/tracking/services/location_settings_builder.dart:34-72`; 11 green branch tests assert all params | ✅ |
| 2 | iOS GPS runs on the MAIN isolate; `flutter_background_service` never started on iOS (D-01) | `main_isolate_tracking_engine.dart` uses `Geolocator.getPositionStream`; `grep FlutterBackgroundService` → 0 hits | ✅ |
| 3 | Stop-race ordering preserved on iOS path (stopping flag → cancel sub → finalize; late sample dropped) (IOS-06) | `main_isolate_tracking_engine.dart` stop sequence; `ios_engine_stop_race_test.dart` 3 green tests | ✅ |
| 4 | `pauseLocationUpdatesAutomatically: false` so GPS doesn't silently pause in stop-and-go (IOS-07) | asserted in `location_settings_branch_test.dart` | ✅ |
| 5 | IOS-08 reduced-accuracy gate: `getLocationAccuracy` → reduced → `requestTemporaryFullAccuracy(purposeKey: kPreciseCommutePurposeKey)` → still reduced ⇒ BLOCK | `location_accuracy_gate.dart` (3 outcomes); `reduced_accuracy_gate_test.dart` 3 green tests; controller iOS preflight | ✅ |
| 6 | `NSLocationTemporaryUsageDescriptionDictionary`/`PreciseCommute` in Info.plist (D-06) | `ios/Runner/Info.plist:73-76`; `plutil -lint` OK | ✅ |
| 7 | `TrackingNotifier` subscribes to the `TrackingEventSource` seam, platform-selected (D-04); no direct `FlutterBackgroundService().on` in the notifier; Android behavior unchanged (D-08) | `tracking_providers.dart` (11 seam refs, 0 `FlutterBackgroundService().on`); `tracking_event_source_selection_test.dart` 3 green; full suite 397 green | ✅ |

**Threat T-02-07 (location PII, ASVS L1):** iOS engine runs in-process with UI; `grep -nE "error\.toString\(\)|\.latitude|\.longitude|print\("` on `main_isolate_tracking_engine.dart` → no hits. Only a stable `reason` tag is forwarded on error. ✅

**Requirement traceability:** IOS-06, IOS-07, IOS-08 each implemented and covered by ≥1 plan + tests. (Note: the iOS *device* behaviors behind IOS-06/07 remain human-gated below.)

## human_verification (real iPhone — required before phase is `passed`)

1. **IOS-06 — backgrounded/locked-screen commute:** Start a trip, lock the screen, drive a full commute, stop. Expected: GPS track complete with no gaps.
2. **IOS-07 — stop-and-go accuracy:** Drive a stop-and-go route. Expected: moving/stuck breakdown is plausible; GPS did not silently pause at low speed.
3. **IOS-08 — Approximate Location:** Set Location → Approximate for the app in iOS Settings, tap Start. Expected: precise-accuracy prompt appears; if declined, recording is blocked with a clear message (no garbage speed stats).

**Device prerequisite:** free-provisioning cert expires every 7 days — if the last install was >7 days ago, re-run `flutter run -d <device>` with the iPhone connected to re-provision (last install 2026-06-02).

## Notes / known limitations

- **"Always" vs "When In Use" (RESEARCH §5 landmine):** background updates may require "Always" authorization for fully reliable locked-screen behavior. The "Always" two-step upgrade is **Phase 15 (IOS-09)**. If item #1 above shows background gaps under "When In Use", that is a Phase 15 follow-up, not a Phase 14 code defect.
- Pre-existing `info`/`warning` analyze items in non-Phase-14 files (e.g. `theme_extension_test.dart`, `tracking_notification_service.dart`) are unchanged by this phase.
