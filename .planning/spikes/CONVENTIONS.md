# Spike Conventions

Patterns and stack choices established across spike sessions. New spikes follow these unless the question requires otherwise.

## Stack
- **Backend spikes:** TypeScript + Node.js 25 + `tsx` for direct execution (no compile step)
- **Database spikes:** `dynalite` for DynamoDB Local (no Docker needed), `pg-mem` for PostgreSQL (no server needed)
- **Flutter spikes:** Dart code analysis only — no separate Flutter test project; read directly by planner/executor

## Structure
- Each spike in `.planning/spikes/NNN-name/` with `README.md` + spike source files
- READMEs use YAML frontmatter (spike, name, type, validates, verdict, related, tags)
- Comparison spikes use shared number + letter suffix: `001a`, `001b`

## Patterns
- Use in-process simulators (dynalite, pg-mem) to avoid Docker/server dependencies
- Show Supabase JS / real SQL equivalent in comments when using pg-mem
- Auth spikes produce real implementation code even when not runnable (code is the artifact)

## Tools & Libraries
- `tsx` — direct TypeScript execution, no tsconfig needed
- `dynalite@4.0.0` — DynamoDB Local simulator, works with AWS SDK v3
- `pg-mem@3.0.14` — in-memory PostgreSQL, pg adapter compatible
- `@aws-sdk/client-dynamodb` + `@aws-sdk/lib-dynamodb` — DynamoDB SDK v3
- `jose` — lightweight JWT verification (preferred over `jsonwebtoken` for Lambda)
