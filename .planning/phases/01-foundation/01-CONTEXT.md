# Phase 1: Foundation - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Runnable Flutter project with complete Drift database schema and app-wide configuration. Delivers the project scaffold, all three Drift tables (trips, sync_queue, user_preferences), DAOs, config constants, Riverpod setup, and build_runner code generation. No UI features, no GPS, no auth.

</domain>

<decisions>
## Implementation Decisions

### Schema Design
- **D-01:** Polylines stored in the trips table (same table, not separate). Load selectively on detail screens to avoid list query bloat.
- **D-02:** user_id column uses default placeholder value `'local_user'` instead of null. Phase 8 replaces with Cognito sub via UPDATE.
- **D-03:** Indexes on start_time and direction columns for daily log and stats query performance. Claude decides exact index composition.
- **D-04:** user_preferences is created on demand (no seeded row). Code must handle missing row with defaults.

### Project Scaffold
- **D-05:** App name is "Traevy" with package identifier `traevy.traevy`.
- **D-06:** Feature directories created phase-by-phase, not all upfront. Phase 1 creates only database/, config/, and shared/ directories.
- **D-07:** Only core packages in Phase 1: Drift, Riverpod, build_runner, uuid, intl. GPS, charts, notifications added in their respective phases.
- **D-08:** Set both `minSdkVersion` and `targetSdkVersion` to API 34 (Android 14). User accepts narrower device coverage in exchange for modern API baseline. (Research flagged this excludes ~40-55% of Android devices; user confirmed.)
- **D-13:** `sync_queue.payload` is a nullable text column, populated only for delete actions. Create/update entries reference trip_id and read current trip state at sync time. Avoids stale payloads if trip is edited after queueing.

### Migration Strategy
- **D-09:** Drift schema starts at schemaVersion 1. Every future schema change increments version with an explicit migration step.
- **D-10:** Migration test scaffolding created in Phase 1 — test infrastructure ready to verify migrations work when schema changes happen.

### Dev Workflow
- **D-11:** Use very_good_analysis for strict linting rules.
- **D-12:** Test directory structure created upfront: test/unit/, test/widget/, test/integration/ with a sample DAO test.

### Claude's Discretion
- Sync queue payload format (JSON text column vs structured columns)
- Exact index composition beyond start_time + direction
- build_runner configuration and watch mode setup
- Exact Drift DAO organization (one per table vs grouped)
- Theme and routes placeholder setup

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Specification
- `CLAUDE.md` -- Full project spec including Drift schema, folder structure, coding conventions, and architecture decisions
- `MVP-features-0.1.md` -- Original feature list for reference

### Planning Context
- `.planning/PROJECT.md` -- Project vision, core value, constraints
- `.planning/REQUIREMENTS.md` -- v1 requirements with SYNC-01 mapped to this phase
- `.planning/research/STACK.md` -- Recommended package versions and rationale
- `.planning/research/PITFALLS.md` -- Drift migration pitfalls and schema design warnings
- `.planning/research/ARCHITECTURE.md` -- Four-layer architecture and data flow

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None -- greenfield project, no existing code

### Established Patterns
- None yet -- Phase 1 establishes the patterns all other phases follow

### Integration Points
- Drift database is the foundation everything connects to
- Riverpod ProviderScope wraps the entire app
- Config constants referenced by every feature module

</code_context>

<specifics>
## Specific Ideas

- App name "Traevy" with package `traevy.traevy`
- user_id defaults to `'local_user'` (not null) -- cleaner than nullable handling throughout the app
- Polylines stay in trips table for schema simplicity -- selective column loading handles performance
- User preferences created on demand, not seeded -- code handles missing row gracefully

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-04-11*
