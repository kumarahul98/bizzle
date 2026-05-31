---
phase: 11
reviewers: [gemini]
reviewed_at: 2026-06-01
plans_reviewed: [11-01-PLAN.md, 11-02-PLAN.md, 11-03-PLAN.md]
---

# Cross-AI Plan Review — Phase 11 (Sync Engine)

Reviewer: **Gemini** (default model, `gemini` CLI), per `review.default_reviewers=["gemini"]`.

## Iteration 0 — 3 HIGH found
- **H1 (11-02):** batch must collapse to the latest effective op per `tripId` (create+update→one upsert; create-then-delete handled) before sending.
- **H2 (11-02):** poison-pill — a 400 on one trip burned all 3 retries on the whole batch. Must classify retryable (5xx/network/401) vs non-retryable (4xx → fail fast).
- **H3 (11-03):** cross-plan symbol mismatch `tripJsonToCompanion` vs frozen `TripSerializer.fromJson` → compile error.
- MEDIUMs: full response-envelope unwrap (`body.data.trips`); triggers must respect active backoff window; restore in a single Drift batch.

## Iteration 1 — 0 HIGH (CONVERGED)
All 3 HIGH + 3 MEDIUM resolved in commit `5a36514`. Gemini: *"All 3 prior HIGH concerns and the 3 MEDIUM concerns are fully and correctly resolved. Cross-plan symbol contract is consistent. Serialization still matches the zod schema. All 4 success criteria achievable."* One LOW nice-to-have: map `DELETE 404` → success (idempotent delete).

## Frozen cross-plan contract (consistent across 01/02/03)
`apiClientProvider` (override-able base URL) · `ApiClient.{syncTrips,deleteTrip,restoreTrips}` · `SyncException{statusCode,retryable}` · `TripSerializer.{toJson,fromJson}` · `syncStatusProvider` · `SyncStatusNotifier` · `SyncStatus.{idle,syncing,synced,offline,failed(count)}` · `syncEngineProvider` (plain `Provider<SyncEngine>`) · `SyncEngine.{processPending,retryFailed,start,dispose}` · `SyncQueueDao.{getPending,markFailed,resetFailed,markSynced,incrementRetry,watchPending}`.
</content>
