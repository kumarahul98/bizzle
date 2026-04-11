# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 01-Foundation
**Areas discussed:** Schema design, Project scaffold, Migration strategy, Dev workflow

---

## Schema Design

| Option | Description | Selected |
|--------|-------------|----------|
| Separate table | trip_routes with FK to trips. Keeps list queries fast. | |
| Same table | Simpler schema, selective column query on detail screen. | ✓ |
| You decide | Claude picks based on research | |

**User's choice:** Same table
**Notes:** User preferred simplicity over separate table approach.

| Option | Description | Selected |
|--------|-------------|----------|
| Nullable text, backfill later | Column exists but allows null. Phase 8 fills it. | |
| Default placeholder value | Use 'local_user' as default, replace in Phase 8. | ✓ |
| You decide | Claude picks simplest | |

**User's choice:** Default placeholder value ('local_user')

| Option | Description | Selected |
|--------|-------------|----------|
| start_time + direction | Covers daily log and stats queries. | |
| Minimal (just PK) | Add indexes later. | |
| You decide | Claude picks based on query patterns. | ✓ |

**User's choice:** You decide (Claude's discretion)

| Option | Description | Selected |
|--------|-------------|----------|
| JSON text column | Serialized trip as JSON string. | |
| Structured columns | Mirror trip fields in sync_queue. | |
| You decide | Claude picks simplest for one-way sync. | ✓ |

**User's choice:** You decide (Claude's discretion)

| Option | Description | Selected |
|--------|-------------|----------|
| Seed on first launch | Insert default row during DB creation. | |
| Create on demand | No row until user changes setting. Code handles null. | ✓ |

**User's choice:** Create on demand

## Project Scaffold

| Option | Description | Selected |
|--------|-------------|----------|
| All upfront | Create full directory tree now. | |
| Phase by phase | Create directories as each phase needs them. | ✓ |
| You decide | Claude picks cleanest approach. | |

**User's choice:** Phase by phase

| Option | Description | Selected |
|--------|-------------|----------|
| Core only | Drift, Riverpod, build_runner, uuid, intl. | ✓ |
| All upfront | Every package from CLAUDE.md now. | |
| You decide | Claude picks based on Phase 1 needs. | |

**User's choice:** Core only

**App name:** Traevy
**Package identifier:** traevy.traevy
**Min SDK:** Latest Android (API 34)

## Migration Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Versioned from v1 | Start at schemaVersion 1. Future changes increment. | ✓ |
| Defer migration setup | Add infrastructure when schema actually changes. | |
| You decide | Claude handles it. | |

**User's choice:** Versioned from v1
**Notes:** User initially asked for more info on what database migrations are. After explanation, chose to version from v1.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, scaffold now | Create test infrastructure for migrations. | ✓ |
| Defer to first change | Write tests when we have a migration to test. | |
| You decide | Claude picks based on effort vs risk. | |

**User's choice:** Yes, scaffold now

## Dev Workflow

| Option | Description | Selected |
|--------|-------------|----------|
| very_good_analysis | Stricter rules, catches more issues. | ✓ |
| flutter_lints | Standard Flutter linting, less strict. | |
| You decide | Claude picks appropriate strictness. | |

**User's choice:** very_good_analysis

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, create structure | test/unit/, test/widget/, test/integration/ with sample DAO test. | ✓ |
| Defer | Create when we write actual tests. | |
| You decide | Claude decides. | |

**User's choice:** Yes, create structure

## Claude's Discretion

- Sync queue payload format (JSON text vs structured columns)
- Exact index composition
- build_runner configuration
- Drift DAO organization
- Theme and routes placeholder setup

## Deferred Ideas

None
