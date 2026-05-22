---
spike: "001b"
name: supabase-postgres
type: comparison
validates: "Given 3 trip access patterns, when implemented with PostgreSQL (pg-mem) + Supabase JS equivalent, then how does setup + query complexity compare to DynamoDB?"
verdict: VALIDATED
related: ["001a"]
tags: [supabase, postgres, backend, database]
---

# Spike 001b: Supabase / PostgreSQL

## What This Validates
Given the same 3 access patterns as 001a, when implemented with PostgreSQL, how does query complexity compare?

## Research

| Approach | Pros | Cons |
|----------|------|------|
| Supabase (PostgreSQL) | Simpler queries, free tier, auto REST API | Not AWS-native, breaks Cognito Authorizer wiring |
| RDS PostgreSQL | Fully managed, AWS-native | ~$15/mo minimum, VPC complexity |
| pg-mem (test only) | In-memory, no setup | Not a production database |

**Chosen:** pg-mem for spike execution (no server needed). Supabase JS client syntax shown as comments.

## How to Run
```bash
cd .planning/spikes/001b-supabase-postgres
npx tsx spike.ts
```

## What to Expect
- pg-mem starts in-process
- trips table + index created
- 7 trips upserted via INSERT ... ON CONFLICT
- trip-002 soft-deleted, rowCount confirms it
- 6 trips restored via SELECT WHERE deleted=false
- Side-by-side comparison table printed

## Investigation Trail

### Iteration 1 — Query simplicity
`INSERT ... ON CONFLICT (trip_id) DO UPDATE` is native upsert — no client-side chunking required. No artificial batch limit. A real Postgres server accepts multi-row VALUES in one statement.

### Iteration 2 — Soft delete
`UPDATE trips SET deleted=TRUE WHERE trip_id=$1 AND user_id=$2` — rowCount immediately tells you if the row existed. DynamoDB requires an explicit ConditionExpression for the same guarantee.

### Iteration 3 — Restore query
`SELECT * FROM trips WHERE user_id=$1 AND deleted=FALSE` uses the index on user_id. No wasted reads on deleted rows. DynamoDB's FilterExpression reads all rows first, then filters.

### Iteration 4 — Supabase-specific findings
Supabase adds:
- Auto-generated REST + GraphQL API: the 3 Lambda handlers become optional (Supabase PostgREST exposes them automatically)
- Row-level security (RLS): `user_id = auth.uid()` replaces manual user_id checks
- BUT: Supabase Auth replaces Cognito — if you use Supabase Auth, you'd drop google_sign_in + amazon_cognito_identity_dart_2 entirely (Supabase has its own Google provider)
- This is a much larger architectural shift than just swapping the database

## Results

**Verdict: VALIDATED** — PostgreSQL is simpler for all 3 patterns.

Key findings:
- Native upsert, no 25-item limit, no expression syntax
- Simpler soft delete (rowCount vs ConditionExpression)
- Index-based restore (zero wasted reads vs DynamoDB FilterExpression)
- Schema migrations required — but for this app's schema (one table, stable columns), migration risk is essentially zero
- **Supabase free tier** covers this app entirely with room to spare
- **BUT**: Supabase breaks the all-AWS architecture. API Gateway Cognito Authorizer won't accept Supabase JWTs. Either: switch to Supabase Auth (drop Cognito entirely, simplify everything) or add a custom Lambda Authorizer

**The real architectural question** this spike surfaces:
- **All-AWS stack** (DynamoDB + Cognito): more expression verbosity, but everything integrates natively
- **Supabase stack**: simpler queries AND simpler auth (Supabase handles both) — but exits the AWS ecosystem entirely
- **Hybrid** (Supabase DB + Cognito Auth): worst of both worlds — doesn't work without a custom Authorizer

**Winner for keeping the current plan:** DynamoDB — it fits the AWS-native architecture.
**Winner if willing to fully switch:** Supabase — simpler in every dimension, but requires dropping Cognito too.
