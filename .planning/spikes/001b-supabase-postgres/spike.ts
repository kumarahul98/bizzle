/**
 * Spike 001b — Supabase / PostgreSQL
 *
 * Tests the same 3 access patterns as 001a, this time with PostgreSQL:
 *   1. Batch upsert trips (POST /trips/sync)
 *   2. Soft-delete a trip (DELETE /trips/{tripId})
 *   3. Restore all trips for a user (GET /trips/restore)
 *
 * Uses pg-mem (in-memory PostgreSQL) so no server needed.
 * Also shows the equivalent Supabase JS client calls — those can't run
 * without a real Supabase project URL, but the syntax is included for
 * direct comparison with the DynamoDB expression approach.
 */

import { newDb } from "pg-mem";

// ─── Types ──────────────────────────────────────────────────────────────────

interface Trip {
  trip_id: string;
  user_id: string;
  start_time: string;
  end_time: string;
  duration_seconds: number;
  distance_meters: number;
  direction: "to_office" | "to_home";
  time_moving_seconds: number;
  time_stuck_seconds: number;
  route_polyline: string;
  is_manual_entry: boolean;
  deleted: boolean;
  created_at: string;
  updated_at: string;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatMs(ms: number) { return `${ms}ms`; }
function pad(s: string, n: number) { return s.padEnd(n); }

function printSection(title: string) {
  console.log(`\n${"─".repeat(60)}`);
  console.log(` ${title}`);
  console.log("─".repeat(60));
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  // In-memory PostgreSQL via pg-mem
  const db = newDb();
  const { Client } = db.adapters.createPg();
  const client = new Client();
  await client.connect();
  console.log("✓ pg-mem (in-memory PostgreSQL) running");

  // ── Create schema ─────────────────────────────────────────────────────────
  await client.query(`
    CREATE TABLE trips (
      trip_id         TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL,
      start_time      TIMESTAMPTZ NOT NULL,
      end_time        TIMESTAMPTZ NOT NULL,
      duration_seconds INTEGER NOT NULL,
      distance_meters  REAL NOT NULL,
      direction        TEXT NOT NULL CHECK (direction IN ('to_office', 'to_home')),
      time_moving_seconds INTEGER NOT NULL,
      time_stuck_seconds  INTEGER NOT NULL,
      route_polyline   TEXT,
      is_manual_entry  BOOLEAN NOT NULL DEFAULT FALSE,
      deleted          BOOLEAN NOT NULL DEFAULT FALSE,
      created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await client.query(`CREATE INDEX idx_trips_user_id ON trips (user_id)`);
  console.log("✓ 'trips' table and index created");

  // ── Seed data ─────────────────────────────────────────────────────────────
  const userId = "cognito-sub-abc123";
  const trips: Trip[] = Array.from({ length: 7 }, (_, i) => ({
    trip_id: `trip-${String(i + 1).padStart(3, "0")}`,
    user_id: userId,
    start_time: new Date(2026, 4, 20 - i, 8, 30).toISOString(),
    end_time: new Date(2026, 4, 20 - i, 9, 15).toISOString(),
    duration_seconds: 2700 + i * 120,
    distance_meters: 14200 + i * 300,
    direction: i % 2 === 0 ? "to_office" : "to_home",
    time_moving_seconds: 1800 + i * 60,
    time_stuck_seconds: 900 + i * 30,
    route_polyline: `encoded_polyline_${i}`,
    is_manual_entry: i === 6,
    deleted: false,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  // ════════════════════════════════════════════════════════════════════════════
  // ACCESS PATTERN 1: Batch upsert (POST /trips/sync)
  // ════════════════════════════════════════════════════════════════════════════
  printSection("ACCESS PATTERN 1 — Batch Upsert (POST /trips/sync)");

  const batchStart = Date.now();

  // PostgreSQL supports native upsert with ON CONFLICT
  // pg-mem doesn't support multi-row VALUES in one INSERT, so we loop —
  // a real Postgres server handles multi-row natively.
  for (const t of trips) {
    await client.query(
      `INSERT INTO trips
         (trip_id, user_id, start_time, end_time, duration_seconds,
          distance_meters, direction, time_moving_seconds, time_stuck_seconds,
          route_polyline, is_manual_entry, deleted, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
       ON CONFLICT (trip_id) DO UPDATE SET
         user_id = EXCLUDED.user_id,
         start_time = EXCLUDED.start_time,
         end_time = EXCLUDED.end_time,
         duration_seconds = EXCLUDED.duration_seconds,
         distance_meters = EXCLUDED.distance_meters,
         direction = EXCLUDED.direction,
         time_moving_seconds = EXCLUDED.time_moving_seconds,
         time_stuck_seconds = EXCLUDED.time_stuck_seconds,
         route_polyline = EXCLUDED.route_polyline,
         is_manual_entry = EXCLUDED.is_manual_entry,
         deleted = EXCLUDED.deleted,
         updated_at = EXCLUDED.updated_at`,
      [t.trip_id, t.user_id, t.start_time, t.end_time, t.duration_seconds,
       t.distance_meters, t.direction, t.time_moving_seconds, t.time_stuck_seconds,
       t.route_polyline, t.is_manual_entry, t.deleted, t.created_at, t.updated_at]
    );
  }
  const batchMs = Date.now() - batchStart;

  console.log(`\nUpserted ${trips.length} trips — ${formatMs(batchMs)}`);

  console.log("\n📋 Code assessment:");
  console.log("  • ON CONFLICT (trip_id) DO UPDATE is native upsert — no client chunking");
  console.log("  • Real Postgres accepts multi-row VALUES in one statement (no per-trip loop)");
  console.log("  • Column names are typed strings — same as DynamoDB, but SQL tooling catches typos");
  console.log("  • No artificial 25-item limit");
  console.log("\n  Supabase JS equivalent (requires live project URL):");
  console.log("    await supabase.from('trips').upsert(trips, { onConflict: 'trip_id' })");

  // ════════════════════════════════════════════════════════════════════════════
  // ACCESS PATTERN 2: Soft-delete a trip (DELETE /trips/{tripId})
  // ════════════════════════════════════════════════════════════════════════════
  printSection("ACCESS PATTERN 2 — Soft Delete (DELETE /trips/{tripId})");

  const deleteStart = Date.now();
  const deleteResult = await client.query(
    `UPDATE trips SET deleted = TRUE, updated_at = $1
     WHERE trip_id = $2 AND user_id = $3`,
    [new Date().toISOString(), "trip-002", userId]
  );
  const deleteMs = Date.now() - deleteStart;

  console.log(`\nSoft-deleted trip-002 in ${formatMs(deleteMs)}`);
  console.log(`Rows affected: ${deleteResult.rowCount}`);

  // Verify
  const verify = await client.query(
    "SELECT deleted FROM trips WHERE trip_id = $1",
    ["trip-002"]
  );
  console.log(`Verified: deleted = ${verify.rows[0].deleted}`);

  console.log("\n📋 Code assessment:");
  console.log("  • Standard SQL UPDATE — no expression syntax or attribute maps");
  console.log("  • rowCount tells you immediately if the trip existed (no conditional expression needed)");
  console.log("  • Equivalent DynamoDB: UpdateExpression + ConditionExpression + ExpressionAttributeValues");
  console.log("\n  Supabase JS equivalent:");
  console.log("    await supabase.from('trips')");
  console.log("      .update({ deleted: true, updated_at: new Date() })");
  console.log("      .eq('trip_id', tripId).eq('user_id', userId)");

  // ════════════════════════════════════════════════════════════════════════════
  // ACCESS PATTERN 3: Restore all trips (GET /trips/restore)
  // ════════════════════════════════════════════════════════════════════════════
  printSection("ACCESS PATTERN 3 — Restore All Trips (GET /trips/restore)");

  const restoreStart = Date.now();
  const restoreResult = await client.query(
    `SELECT * FROM trips WHERE user_id = $1 AND deleted = FALSE ORDER BY start_time DESC`,
    [userId]
  );
  const restoreMs = Date.now() - restoreStart;

  console.log(`\nRestored ${restoreResult.rows.length} non-deleted trips in ${formatMs(restoreMs)}`);
  console.log("Columns:", Object.keys(restoreResult.rows[0]).join(", "));

  console.log("\n📋 Code assessment:");
  console.log("  • WHERE user_id = ? AND deleted = FALSE — reads only matching rows");
  console.log("  • PostgreSQL uses the index on user_id — no wasted reads on deleted rows");
  console.log("  • Equivalent DynamoDB: Query PK + FilterExpression (reads deleted rows, then discards)");
  console.log("  • ORDER BY is native — DynamoDB requires client-side sort");
  console.log("\n  Supabase JS equivalent:");
  console.log("    await supabase.from('trips')");
  console.log("      .select('*')");
  console.log("      .eq('user_id', userId)");
  console.log("      .eq('deleted', false)");
  console.log("      .order('start_time', { ascending: false })");

  // ════════════════════════════════════════════════════════════════════════════
  // SUMMARY — Side-by-side comparison
  // ════════════════════════════════════════════════════════════════════════════
  printSection("SUMMARY — PostgreSQL vs DynamoDB Side-by-Side");

  console.log(`
┌─────────────────────┬──────────────────────────────┬──────────────────────────────┐
│ Dimension           │ PostgreSQL / Supabase         │ DynamoDB Single-Table        │
├─────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ Batch upsert        │ INSERT ... ON CONFLICT        │ BatchWriteItem (25 limit,    │
│                     │ (one statement, no limit)     │ client must chunk)           │
├─────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ Soft delete         │ UPDATE ... WHERE (1 line)     │ UpdateExpression +           │
│                     │ rowCount confirms existence   │ ConditionExpression (5 lines)│
├─────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ Restore all         │ SELECT WHERE deleted=false    │ Query PK + FilterExpression  │
│                     │ (index, zero wasted reads)    │ (reads deleted rows, filter) │
├─────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ Schema migrations   │ Required (ALTER TABLE)        │ Not needed (schemaless)      │
├─────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ AWS integration     │ Extra VPC/config or           │ Native with API Gateway      │
│                     │ Supabase Edge Function        │ + Cognito Authorizer         │
├─────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ Cost (low usage)    │ Supabase free tier (500MB)    │ DynamoDB on-demand ~$0       │
│                     │ vs RDS ~$15/mo                │ at low volume                │
├─────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ Local dev           │ Supabase CLI / Docker /       │ DynamoDB Local (Docker/JAR)  │
│                     │ pg-mem for tests              │ or dynalite for tests        │
├─────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ Supabase bonus      │ Realtime, Auth, Storage,      │ Not applicable               │
│                     │ auto REST+GraphQL API         │                              │
└─────────────────────┴──────────────────────────────┴──────────────────────────────┘

KEY FINDING: For these 3 access patterns, PostgreSQL is objectively simpler.
DynamoDB adds complexity (chunking, expression syntax, RCU waste on filtered reads)
that only pays off if you're building for massive scale or want zero schema management.

For a personal commute app:
  • Supabase free tier covers the entire app with room to spare
  • Supabase auto-generates a REST API — the 3 Lambda handlers become optional
  • BUT: Supabase breaks the all-AWS architecture (API Gateway + Cognito Authorizer)
  • DynamoDB on-demand is genuinely ~$0 at personal-app scale
  • DynamoDB removes the "remember to run migrations" concern forever
`);

  await client.end();
}

main().catch((err) => {
  console.error("Spike failed:", err);
  process.exit(1);
});
