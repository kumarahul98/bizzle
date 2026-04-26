---
phase: 4
slug: trip-history
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-26
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter 3.41.6) |
| **Config file** | none — standard Flutter test runner |
| **Quick run command** | `flutter test test/unit/features/trips/ test/unit/shared/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/features/trips/ test/unit/shared/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 | 0 | HIST-01 | — | N/A | unit | `flutter test test/unit/features/trips/history_grouping_test.dart` | ❌ W0 | ⬜ pending |
| 4-01-02 | 01 | 0 | HIST-01 | — | N/A | unit | `flutter test test/unit/shared/formatters_test.dart` | ❌ W0 | ⬜ pending |
| 4-01-03 | 01 | 0 | HIST-03 | — | N/A | widget | `flutter test test/widget/features/trips/history_screen_test.dart` | ❌ W0 | ⬜ pending |
| 4-01-04 | 01 | 0 | HIST-03 | — | N/A | widget | `flutter test test/widget/features/trips/trip_detail_screen_test.dart` | ❌ W0 | ⬜ pending |
| 4-02-01 | 02 | 1 | HIST-01 | — | N/A | unit | `flutter test test/unit/features/trips/history_grouping_test.dart` | ❌ W0 | ⬜ pending |
| 4-02-02 | 02 | 1 | HIST-01 | — | N/A | widget | `flutter test test/widget/features/trips/history_screen_test.dart` | ❌ W0 | ⬜ pending |
| 4-03-01 | 03 | 2 | HIST-02 | — | N/A | widget | `flutter test test/widget/features/trips/history_screen_test.dart` | ❌ W0 | ⬜ pending |
| 4-04-01 | 04 | 3 | HIST-03 | — | N/A | widget | `flutter test test/widget/features/trips/trip_detail_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/features/trips/history_grouping_test.dart` — stubs for HIST-01: groupTripsByDate, formatDateHeader
- [ ] `test/unit/shared/formatters_test.dart` — stubs for HIST-01/HIST-03: formatDuration, formatDistance, decodedToLatLng
- [ ] `test/widget/features/trips/history_screen_test.dart` — stubs for HIST-01 list render, HIST-02 calendar, empty states
- [ ] `test/widget/features/trips/trip_detail_screen_test.dart` — stubs for HIST-03: manual trip, loading state, not-found state, stats rendering

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| OSM tile layer loads and displays map tiles | HIST-03 | flutter_map makes HTTP requests to OSM tile servers — not feasible in CI widget tests | Run on real Android device; navigate to a GPS trip detail, confirm tiles load within 3 seconds |
| Route polyline renders correctly on map | HIST-03 | Requires real device + OSM network | Open a GPS trip detail; verify polyline overlays tiles with correct start/end points |
| Calendar month navigation works | HIST-02 | table_calendar month swipe requires real interaction | On device: swipe calendar left/right, confirm months change and event markers persist |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
