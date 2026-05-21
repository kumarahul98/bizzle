# Spike Manifest

## Idea

Two architectural decisions for Commute Tracker that need real comparison before Phase 9-10 planning is locked:
1. **Backend database**: DynamoDB single-table design vs Supabase PostgreSQL — does DynamoDB's complexity pay off for 3 simple endpoints?
2. **Auth approach**: Google → Cognito token exchange vs plain Google Sign-In — does Cognito add enough value to justify the extra setup?

## Requirements

- Decision on database stack (DynamoDB or Supabase) must be locked before Phase 10 planning
- Decision on auth stack (Cognito or Google Direct) must be locked in Phase 9 CONTEXT.md
- Winner of each comparison must be justified against the 3 actual access patterns (batch-sync, soft-delete, restore-all)

## Spikes

| # | Name | Type | Validates | Verdict | Tags |
|---|------|------|-----------|---------|------|
| 001a | dynamo-single-table | comparison | Given 3 access patterns, does DynamoDB single-table stay clean? | ✓ VALIDATED | dynamodb, backend, database |
| 001b | supabase-postgres | comparison | How does PostgreSQL/Supabase compare on same patterns? | ✓ VALIDATED | supabase, postgres, backend, database |
| 002a | cognito-token-exchange | comparison | What is the actual Cognito exchange code + setup complexity? | ⚠ PARTIAL | cognito, auth, flutter |
| 002b | google-direct-auth | comparison | What does Lambda Authorizer + Google Direct cost? | ✓ VALIDATED | google-auth, auth, lambda, flutter |

## Key Findings

### Database (001a vs 001b)
- PostgreSQL is objectively simpler for all 3 access patterns
- DynamoDB adds: 25-item BatchWriteItem chunking, expression syntax verbosity, FilterExpression RCU waste
- **BUT**: Supabase is not AWS-native — it cannot use API Gateway Cognito Authorizer without a custom Lambda
- If you want Supabase, you'd also drop Cognito entirely and use Supabase Auth (a much larger shift)
- DynamoDB on-demand is ~$0 at personal-app scale, requires zero schema migrations, fits the AWS plan

### Auth (002a vs 002b)
- `amazon_cognito_identity_dart_2` v3.7 does NOT support federated login directly — Cognito requires Hosted UI + deep link handling
- Plain Google Sign-In is simpler Flutter-side but Google tokens expire every 1 hour (vs Cognito's 30-day refresh)
- Plain Google requires a Lambda Authorizer (~50 lines) replacing Cognito's zero-config API Gateway integration
- Session durability strongly favors Cognito for a commute app used daily with potential offline gaps

## Decision Anchors

| Stack | Keep? | Reason |
|-------|-------|--------|
| DynamoDB | **YES** — keep | Simpler queries with Supabase, but switching means leaving AWS entirely. DynamoDB complexity is manageable and cost is essentially zero. |
| Cognito | **YES — but with eyes open** | amazon_cognito_identity_dart_2 doesn't do the exchange directly. Phase 9 needs Hosted UI + deep link. Worth it for 30-day session durability. |
