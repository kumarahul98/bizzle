---
phase: 6
slug: dashboard
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-27
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built into Flutter SDK) |
| **Config file** | None (uses default flutter test runner) |
| **Quick run command** | `flutter test test/widget/features/dashboard/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** `flutter test test/widget/features/dashboard/ && flutter test test/widget/app_test.dart && flutter test test/unit/app_bootstrap_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-01 | DashboardScreen renders as app root | Widget | `flutter test test/widget/app_test.dart` | ✅ (update existing) |
| UX-01 | Today's trips list shows TripCard for each today trip | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | Empty state shown when no trips today | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | Weekly summary card renders weekTotalSeconds + weekStuckSeconds + trip count | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | FAB shows "Start commute" when tracking idle | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | FAB shows "Go to tracking" when tracking active | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | InProgressCard visible when TrackingActive, hidden otherwise | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | _handleStart with permanentlyDenied shows settings dialog | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 (migrate from home_screen_test.dart) |
| UX-01 | _handleStart with notificationDenied shows notification dialog | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 (migrate from home_screen_test.dart) |
| UX-01 | _handleStart with fullyGranted navigates to tracking screen | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 (migrate from home_screen_test.dart) |
| UX-01 | AppBar has History and Stats icon buttons | Widget | `flutter test test/widget/features/dashboard/` | ❌ Wave 0 |
| UX-01 | todaysTripSummariesProvider filters to today only | Unit | `flutter test test/unit/features/dashboard/` | ❌ Wave 0 |

---

## Wave 0 — Test Scaffolding

These test files must be created in Wave 0 (before implementation):

- [ ] `test/widget/features/dashboard/dashboard_screen_test.dart` — covers all UX-01 widget behaviors; migrates permission path tests from `test/widget/features/tracking/home_screen_test.dart`
- [ ] `test/unit/features/dashboard/dashboard_providers_test.dart` — unit test for `todaysTripSummariesProvider` filter logic (today boundary, yesterday exclusion)

No new framework installs needed — `flutter_test` is already available.

---

## Human Verification Items

| # | Item | How to test |
|---|------|-------------|
| 1 | Dashboard is the first screen on app launch | Run app on device, verify DashboardScreen appears |
| 2 | FAB changes icon/label when tracking starts | Start a trip, verify FAB shows "Go to tracking" |
| 3 | In-progress card shows elapsed time while tracking | Start a trip, verify card appears at top of today's list |
| 4 | Weekly summary card numbers are accurate | Compare card values against known trip data |
| 5 | Tapping weekly card navigates to Stats screen | Tap card, verify StatsScreen appears |
| 6 | AppBar icons navigate to History and Stats | Tap each icon, verify correct screen |
