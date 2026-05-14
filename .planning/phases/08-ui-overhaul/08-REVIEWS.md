---
phase: 8
reviewers: [gemini]
reviewed_at: 2026-05-14T00:00:00Z
plans_reviewed: [08-01-PLAN.md, 08-02-PLAN.md, 08-03-PLAN.md, 08-04-PLAN.md, 08-05-PLAN.md, 08-06-PLAN.md, 08-07-PLAN.md]
skipped: [claude (self), codex (binary broken)]
---

# Cross-AI Plan Review — Phase 8: UI Overhaul

## Gemini Review

### Summary

The Phase 8 implementation plans present a highly rigorous, well-architected approach to a comprehensive UI overhaul. By employing a sequential, wave-based rollout underpinned by a RED/GREEN TDD strategy, the plan effectively isolates the creation of the new design system (tokens, typography, shared components) from the refactoring of existing feature screens. The explicit avoidance of Material 3's `ColorScheme.fromSeed` in favor of a strictly defined `ThemeExtension` ensures high fidelity to the custom Traevy design system. While the constraint to avoid business logic changes is ambitious given the scale of the visual rewrite, the clear boundary lines drawn in these plans make it achievable, provided strict attention is paid to Riverpod provider lifecycles during the structural navigation changes.

### Strengths

- **Robust TDD Foundation (Wave 0):** Mandating RED tests for themes and shared components before any screen integration is an excellent strategy to enforce design system compliance and catch token mapping errors early.
- **Absolute Color Control:** Bypassing `ColorScheme.fromSeed` and utilizing a custom `TraevyTokensExt` guarantees that the nuanced oklch-derived colors remain exactly as designed, preventing Flutter from automatically (and incorrectly) shifting the tonal palettes of `moving`, `stuck`, and `accent` states.
- **Offline-First Typography Alignment:** Bundling the TTF files and explicitly setting `GoogleFonts.config.allowRuntimeFetching = false` is a perfect alignment with the app's client-authoritative, offline-first constraint. It eliminates network-induced layout shifts and ensures instant rendering.
- **Lifecycle Preservation:** Utilizing an `IndexedStack` for the `MainShell` navigation (Plan 04) correctly preserves the state of the 4 primary tabs, which is critical for an app managing long-running background tasks like commute tracking.
- **Component Encapsulation:** The strict requirement in Plan 03 to keep shared widgets under 100 lines and pass data via explicit parameters ensures highly testable, decoupled UI components.

### Concerns

- **HIGH: Riverpod Provider Lifecycles in `MainShell`:** Introducing an `IndexedStack` means that Dashboard, Trips, Stats, and Settings will all be mounted in the widget tree simultaneously. If any existing Riverpod providers rely on `.autoDispose` or assume they are only active when their specific route is pushed, the `IndexedStack` could cause unintended state retention or redundant database reads.
- **HIGH: Data-to-UI Mapping in Stats Rewrite (Plan 06):** Deleting 5 legacy stats widgets and replacing them entirely carries a significant risk. If the new `TrendBarsCard` or `WeekdayChartCard` require data shaped differently than what the existing providers expose, the "no business logic untouched" constraint will be violated.
- **MEDIUM: `ThemeExtension.lerp` Implementation Complexity:** Manually writing the `lerp` function for 18 custom colors (Plan 02) is tedious and prone to human error (e.g., lerping a color against the wrong target property). Errors here will cause jarring flashes or crashes during light/dark mode transitions.
- **MEDIUM: Implicit Routing Logic Changes:** Plan 04 dictates that the "See stats →" button switches the tab index rather than pushing a route. While UI-driven, this changes the navigation paradigm. Ensure the routing package and the Riverpod shell state are perfectly synchronized so system back-button behavior remains predictable.
- **LOW: APK Size Increase:** Bundling 7 TTF files (Inter and JetBrains Mono) will increase the base application size. Given the offline requirement, this is a necessary tradeoff, but it should be monitored.

### Suggestions

- **Audit Provider Disposability:** Before executing Plan 04 (MainShell), audit all Riverpod providers consumed by the 4 main screens. Ensure that providers intended to reset upon leaving a screen are manually managed, as the `IndexedStack` will keep them continuously mounted.
- **Pre-validate Stats Data Shapes:** Prior to Plan 06, map the exact input requirements of `fl_chart` (DonutCard, TrendBarsCard) against the existing Drift DAOs and Riverpod stats providers to ensure 1:1 compatibility without requiring intermediate transformation logic.
- **Automate or Triple-Check Lerping:** For Plan 02, ensure `theme_extension_test.dart` explicitly asserts the mid-point (t=0.5) for *every* color token in `TraevyTokensExt.lerp` to guarantee robust theme transitions.
- **Incorporate Golden Tests:** For Plan 03 (Shared Widgets), consider supplementing widget tests with Golden Tests (visual regression testing) to validate the exact oklch-approximated colors and typography pairings against design specs.
- **Safeguard the Map:** In Plan 06, ensure the `flutter_map` TileLayer is wrapped in a `RepaintBoundary` to prevent heavy map rendering from triggering on adjacent state changes.

### Risk Assessment

**MEDIUM** — Foundational Plans 01–03 are extremely low risk due to explicit decoupling and TDD. Risk elevates during Plans 04 and 06. Wholesale replacing the UI layer while strictly forbidden from altering Riverpod/Drift business logic is delicate. The introduction of `IndexedStack` fundamentally changes how Flutter manages primary screen lifecycles, which can expose hidden assumptions in the state management layer. The tight constraints leave little room for error during integration.

---

## Codex Review

*(Skipped — codex binary failed to spawn on this system: `ENOENT @openai/codex-darwin-arm64`. Install a working codex binary and re-run `/gsd-review --phase 8 --codex` to add this review.)*

---

## Consensus Summary

One external AI system reviewed (Gemini). Codex was unavailable.

### Agreed Strengths

- **Wave-based TDD with RED/GREEN cycle** is a sound strategy — validates design contracts before screen integration, catches token mapping errors at unit-test level rather than during visual QA
- **Local TTF bundling + `allowRuntimeFetching = false`** is the correct approach for an offline-first app — aligns with the client-authoritative architecture and prevents CI test flakiness
- **`IndexedStack` for `MainShell`** is the right Flutter pattern for background-service-aware apps (tracking must survive tab switches without teardown)
- **Manual `ColorScheme` construction (no `fromSeed`)** is essential for preserving the specific Traevy token relationships — seed derivation would corrupt `moving`, `stuck`, and `accent` semantic semantics

### Agreed Concerns

- **HIGH — Riverpod `.autoDispose` interaction with `IndexedStack`:** All 4 tab screens become simultaneously mounted. Any providers that self-dispose when not watched (`.autoDispose`) will either persist indefinitely or behave unexpectedly. **Pre-execution audit of provider disposal modes is required before Plan 04.**
- **HIGH — Stats widget deletion risk (Plan 06):** Deleting `BestWorstDayCard`, `DirectionAveragesCard`, `TrafficWasteCard`, `TrendChartCard`, `WeekMonthTotalsCard` — if any of these are consumed by providers or Drift queries that are shaped specifically for them, the new widgets may require provider changes. This must be explicitly validated before execution.
- **MEDIUM — `lerp` implementation correctness:** The Wave-0 `theme_extension_test.dart` tests only a single lerp assertion. Consider expanding to cover all 14 `TraevyTokensExt` fields to fully validate the implementation.

### Divergent Views

*(Single reviewer — no divergence to report.)*

---

## How to Use This Review

To incorporate feedback into planning before execution:

```
/gsd-plan-phase 8 --reviews
```

Or proceed directly to execution if you've reviewed and accepted the HIGH concerns:

```
/gsd-execute-phase 8
```

**Recommended pre-execution steps based on HIGH concerns:**
1. Audit existing Riverpod providers for `.autoDispose` usage in Dashboard, History, Stats, and Settings screens — ensure IndexedStack mounting is safe
2. Check existing stats providers' output shapes against `fl_chart` BarChart/PieChart data types required by the new TrendBarsCard and DonutCard
