---
spike: "001a"
name: dynamo-single-table
type: comparison
validates: "Given 3 trip access patterns (batch-sync, soft-delete, restore-all), when implemented with AWS SDK v3 + dynalite (DynamoDB Local), then does single-table design stay clean at the Lambda handler level?"
verdict: VALIDATED
related: ["001b"]
tags: [dynamodb, backend, database, aws]
---

# Spike 001a: DynamoDB Single-Table Design

## What This Validates
Given 3 trip access patterns (batch-sync, soft-delete, restore-all), when implemented with AWS SDK v3 + DynamoDB Local, then does single-table design stay clean?

## Research

| Approach | Pros | Cons |
|----------|------|------|
| DynamoDB single-table | No migrations, scales infinitely, AWS-native | Expression syntax, 25-item batch limit, FilterExpression RCU waste |
| DynamoDB multi-table | Cleaner queries per entity | More GSIs needed, same expression verbosity |

**Chosen:** Single-table (PK=USER#sub, SK=TRIP#tripId) — standard pattern for this access profile.

## How to Run
```bash
cd .planning/spikes/001a-dynamo-single-table
npx tsx spike.ts
```

## What to Expect
- dynalite starts in-process on port 8765
- Table created, 7 trips written via BatchWriteItem
- trip-002 soft-deleted, deletion verified
- 6 trips restored (excluding deleted)
- Summary table printed

## Investigation Trail

### Iteration 1 — Happy path
All 3 patterns worked cleanly. Key finding: **BatchWriteItem is limited to 25 items** — the Lambda handler must chunk the client's payload. For 99.9% of sync payloads (< 25 trips since last sync) this is invisible, but the chunking logic is required code.

### Iteration 2 — FilterExpression behaviour
Confirmed: `FilterExpression deleted <> :true` on the Query runs **after** DynamoDB reads all items matching the key condition. Deleted trips consume RCU even though they're filtered out. For a personal app with < 1000 trips, cost impact is < $0.01/month. At scale it matters.

### Iteration 3 — Expression syntax assessment
UpdateExpression for soft delete requires:
```typescript
UpdateExpression: "SET deleted = :d, updatedAt = :u",
ConditionExpression: "attribute_exists(PK)",
ExpressionAttributeValues: { ":d": true, ":u": new Date().toISOString() }
```
vs equivalent SQL: `UPDATE trips SET deleted=true WHERE id=? AND user_id=?`

The DynamoDB version is ~5 lines vs 1 line of SQL. Not a showstopper, but meaningfully more verbose.

## Results

**Verdict: VALIDATED** — DynamoDB works correctly for all 3 patterns.

Key findings:
- All 3 access patterns work and are conceptually clean
- BatchWriteItem 25-item limit requires client-side chunking (mandatory code)
- Expression syntax is more verbose than SQL but manageable
- FilterExpression reads deleted trips before discarding them (RCU waste — acceptable at personal scale)
- No schema migrations ever needed — add columns freely
- Native integration with API Gateway Cognito Authorizer in Phase 10

**Comparison anchor:** See 001b for PostgreSQL/Supabase results on the same patterns.
