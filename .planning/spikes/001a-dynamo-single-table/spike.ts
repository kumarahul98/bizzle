/**
 * Spike 001a — DynamoDB Single-Table Design
 *
 * Tests the 3 access patterns this app needs:
 *   1. Batch upsert trips (POST /trips/sync)
 *   2. Soft-delete a trip (DELETE /trips/{tripId})
 *   3. Restore all trips for a user (GET /trips/restore)
 *
 * Runs against dynalite (in-process DynamoDB simulator — no Docker needed).
 */

import { DynamoDBClient, CreateTableCommand, ListTablesCommand } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, BatchWriteCommand, UpdateCommand, QueryCommand, GetCommand } from "@aws-sdk/lib-dynamodb";
// @ts-ignore — dynalite has no types
import dynalite from "dynalite";

// ─── Types ──────────────────────────────────────────────────────────────────

interface Trip {
  tripId: string;
  userId: string;
  startTime: string;
  endTime: string;
  durationSeconds: number;
  distanceMeters: number;
  direction: "to_office" | "to_home";
  timeMovingSeconds: number;
  timeStuckSeconds: number;
  routePolyline: string;
  isManualEntry: boolean;
  deleted: boolean;
  createdAt: string;
  updatedAt: string;
}

// ─── DynamoDB Schema ────────────────────────────────────────────────────────
//
// Single-table design:
//   PK = USER#<userId>
//   SK = TRIP#<tripId>
//
// Access patterns:
//   1. Put/update a trip     → PutItem / BatchWriteItem
//   2. Soft delete a trip    → UpdateItem (deleted = true)
//   3. All trips for user    → Query PK=USER#<sub>, filter deleted != true

const TABLE_NAME = "commute-tracker";

function pk(userId: string) { return `USER#${userId}`; }
function sk(tripId: string) { return `TRIP#${tripId}`; }

// ─── Helpers ────────────────────────────────────────────────────────────────

function formatMs(ms: number) { return `${ms}ms`; }
function pad(s: string, n: number) { return s.padEnd(n); }

function printSection(title: string) {
  console.log(`\n${"─".repeat(60)}`);
  console.log(` ${title}`);
  console.log("─".repeat(60));
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  // Start dynalite (in-process DynamoDB simulator)
  const server = dynalite({ createTableMs: 0 });
  await new Promise<void>((resolve) => server.listen(8765, resolve));
  console.log("✓ dynalite running on :8765");

  const rawClient = new DynamoDBClient({
    endpoint: "http://localhost:8765",
    region: "us-east-1",
    credentials: { accessKeyId: "fake", secretAccessKey: "fake" },
  });
  const client = DynamoDBDocumentClient.from(rawClient, {
    marshallOptions: { removeUndefinedValues: true },
  });

  // ── Create table ──────────────────────────────────────────────────────────
  await rawClient.send(new CreateTableCommand({
    TableName: TABLE_NAME,
    BillingMode: "PAY_PER_REQUEST",
    KeySchema: [
      { AttributeName: "PK", KeyType: "HASH" },
      { AttributeName: "SK", KeyType: "RANGE" },
    ],
    AttributeDefinitions: [
      { AttributeName: "PK", AttributeType: "S" },
      { AttributeName: "SK", AttributeType: "S" },
    ],
  }));
  console.log(`✓ Table '${TABLE_NAME}' created`);

  // ── Seed data ─────────────────────────────────────────────────────────────
  const userId = "cognito-sub-abc123";
  const trips: Trip[] = Array.from({ length: 7 }, (_, i) => ({
    tripId: `trip-${String(i + 1).padStart(3, "0")}`,
    userId,
    startTime: new Date(2026, 4, 20 - i, 8, 30).toISOString(),
    endTime: new Date(2026, 4, 20 - i, 9, 15).toISOString(),
    durationSeconds: 2700 + i * 120,
    distanceMeters: 14200 + i * 300,
    direction: i % 2 === 0 ? "to_office" : "to_home",
    timeMovingSeconds: 1800 + i * 60,
    timeStuckSeconds: 900 + i * 30,
    routePolyline: `encoded_polyline_${i}`,
    isManualEntry: i === 6,
    deleted: false,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }));

  // ════════════════════════════════════════════════════════════════════════════
  // ACCESS PATTERN 1: Batch upsert (POST /trips/sync)
  // ════════════════════════════════════════════════════════════════════════════
  printSection("ACCESS PATTERN 1 — Batch Upsert (POST /trips/sync)");

  const batchSize = 25; // DynamoDB BatchWriteItem hard limit
  const chunks: Trip[][] = [];
  for (let i = 0; i < trips.length; i += batchSize) {
    chunks.push(trips.slice(i, i + batchSize));
  }

  const batchStart = Date.now();
  for (const chunk of chunks) {
    await client.send(new BatchWriteCommand({
      RequestItems: {
        [TABLE_NAME]: chunk.map((t) => ({
          PutRequest: {
            Item: {
              PK: pk(t.userId),
              SK: sk(t.tripId),
              ...t,
            },
          },
        })),
      },
    }));
  }
  const batchMs = Date.now() - batchStart;

  console.log(`\nWrote ${trips.length} trips in ${chunks.length} batch(es) — ${formatMs(batchMs)}`);

  console.log("\n📋 Code assessment:");
  console.log("  • BatchWriteItem limit: 25 items per call");
  console.log("  • Client must chunk payload — server doesn't auto-chunk");
  console.log("  • No native upsert — PutItem overwrites silently (good for sync)");
  console.log("  • PK/SK wrapping adds ~4 lines per handler vs raw SQL INSERT ... ON CONFLICT");

  // ════════════════════════════════════════════════════════════════════════════
  // ACCESS PATTERN 2: Soft-delete a trip (DELETE /trips/{tripId})
  // ════════════════════════════════════════════════════════════════════════════
  printSection("ACCESS PATTERN 2 — Soft Delete (DELETE /trips/{tripId})");

  const deleteStart = Date.now();
  await client.send(new UpdateCommand({
    TableName: TABLE_NAME,
    Key: { PK: pk(userId), SK: sk("trip-002") },
    UpdateExpression: "SET deleted = :d, updatedAt = :u",
    ConditionExpression: "attribute_exists(PK)",  // guard: trip must exist
    ExpressionAttributeValues: { ":d": true, ":u": new Date().toISOString() },
  }));
  const deleteMs = Date.now() - deleteStart;

  // Verify
  const deleted = await client.send(new GetCommand({
    TableName: TABLE_NAME,
    Key: { PK: pk(userId), SK: sk("trip-002") },
  }));
  console.log(`\nSoft-deleted trip-002 in ${formatMs(deleteMs)}`);
  console.log(`Verified: deleted = ${deleted.Item?.deleted}`);

  console.log("\n📋 Code assessment:");
  console.log("  • UpdateExpression syntax requires string interpolation — not typed");
  console.log("  • ExpressionAttributeValues dict needed for every value");
  console.log("  • ConditionExpression adds safety guard (prevents silent no-op on missing trips)");
  console.log("  • Equivalent SQL: UPDATE trips SET deleted=true WHERE user_id=? AND id=?");

  // ════════════════════════════════════════════════════════════════════════════
  // ACCESS PATTERN 3: Restore all trips (GET /trips/restore)
  // ════════════════════════════════════════════════════════════════════════════
  printSection("ACCESS PATTERN 3 — Restore All Trips (GET /trips/restore)");

  const restoreStart = Date.now();
  const result = await client.send(new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: "PK = :pk AND begins_with(SK, :skPrefix)",
    FilterExpression: "deleted <> :true",
    ExpressionAttributeValues: {
      ":pk": pk(userId),
      ":skPrefix": "TRIP#",
      ":true": true,
    },
  }));
  const restoreMs = Date.now() - restoreStart;

  const restoredCount = result.Items?.length ?? 0;
  console.log(`\nRestored ${restoredCount} non-deleted trips in ${formatMs(restoreMs)}`);
  console.log("Sample item keys:", Object.keys(result.Items?.[0] ?? {}).join(", "));

  console.log("\n📋 Code assessment:");
  console.log("  • KeyConditionExpression: PK + begins_with(SK) is clean for all user trips");
  console.log("  • FilterExpression runs AFTER key read — costs RCU for deleted items too");
  console.log("  • For large datasets, deleted items waste read capacity");
  console.log("  • Could use sparse GSI (exclude deleted) but adds infra complexity");
  console.log("  • Equivalent SQL: SELECT * FROM trips WHERE user_id=? AND deleted=false");

  // ════════════════════════════════════════════════════════════════════════════
  // SUMMARY
  // ════════════════════════════════════════════════════════════════════════════
  printSection("SUMMARY — DynamoDB Single-Table");

  const rows = [
    ["Pattern", "DynamoDB Approach", "Complexity vs SQL"],
    ["─".repeat(20), "─".repeat(35), "─".repeat(20)],
    ["Batch upsert", "BatchWriteItem (25-item chunks, PutRequest)", "Moderate (+chunking logic)"],
    ["Soft delete", "UpdateExpression + ConditionExpression", "Moderate (+expression syntax)"],
    ["Restore all", "Query PK + begins_with(SK) + FilterExpression", "Moderate (+RCU cost on deleted)"],
  ];

  for (const row of rows) {
    console.log(` ${pad(row[0], 20)} ${pad(row[1], 36)} ${row[2]}`);
  }

  console.log(`
DynamoDB adds:
  ✓ No schema migrations — add/remove fields freely
  ✓ Scales to any size without config changes
  ✓ Integrates natively with Cognito Authorizer + API Gateway
  ✗ Expression syntax is verbose, not typed (string-based)
  ✗ FilterExpression on restore reads deleted items (wastes RCU at scale)
  ✗ 25-item BatchWriteItem limit requires client-side chunking
  ✗ No native upsert semantics — PutItem blindly overwrites

For ${trips.length} trips, this works cleanly. For 10,000+ trips the RCU cost
of filtering deleted rows on restore becomes meaningful.
`);

  server.close();
}

main().catch((err) => {
  console.error("Spike failed:", err);
  process.exit(1);
});
