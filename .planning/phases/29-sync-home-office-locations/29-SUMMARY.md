---
phase: 29-sync-home-office-locations
completed: 2026-07-20
status: code_complete_backend_deployed_blocked_on_data_safety
mode: manual-gsd
requirements: [LOC-03]
branch: phase-29-sync-home-office
commits:
  - 5733236 (Wave 1 backend)
  - 9843204 (Wave 2 client wire)
  - bf96bbb (Wave 3 triggers)
result: >
  All 3 waves built and tested. BACKEND DEPLOYED to travey-298a7
  2026-07-20 and verified live. Branch still unmerged — the remaining
  gate is the Play Data Safety declaration, which blocks shipping the
  CLIENT (deploying endpoints nothing calls collects no data).
  Flutter 709 tests green, backend 103 green, analyze 0/0, APK builds.
---

# Phase 29 — Sync Home & Office Locations — SUMMARY

## What shipped

| Wave | Commit | Content |
|---|---|---|
| 1 | `5733236` | `POST /preferences/sync`, `GET /preferences/restore`, zod schema, typed converter, 14 tests |
| 2 | `9843204` | `SavedLocations`, two `ApiClient` methods, `PreferencesSyncService`, D-01 dartdoc rewrite, 27 tests |
| 3 | `bf96bbb` | Picker-confirm + sign-in triggers, provider, 5 tests |

**Verification:** `flutter analyze` 0 errors / 0 warnings · `flutter test` 709 passed
(was 677) · backend `npm test` 103 passed (was 89) · `npm run lint` clean ·
debug APK builds.

## Success criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Setting Home/Office pushes to Firestore | ✅ code + tests |
| 2 | Backend deployed BEFORE any client emits | ✅ **deployed + verified live 2026-07-20** |
| 3 | Fresh install restores pins, labeling works first trip | ✅ code + tests; device-unverified |
| 4 | Local value never overwritten by cloud (D-03) | ✅ full merge matrix pinned |
| 5 | Never-set user syncs/restores cleanly | ✅ 200-not-404, all-null valid |
| 6 | No coordinate in any log | ✅ by construction + a test asserting the 400 body does not echo the value |
| 7 | Play Data Safety updated before release | ⛔ **not done** — human gate |

## Decisions as-built

D-01 through D-05 held as planned. Nothing was reversed mid-build, but three
things were sharper in code than on paper:

**`.finite()` is load-bearing, not decoration.** `z.number()` rejects `NaN` but
*accepts* `Infinity`, so a `-Infinity` latitude would satisfy a naive
`.min(-90)` and reach Firestore. Both the zod schema and the client parser
reject non-finite values, and the converter maps a stored non-finite value back
to `null`. This matters more than it looks: a poisoned coordinate does not fail
loudly — it silently mislabels the direction of every future trip through the
geofence resolver.

**Pair consistency is enforced at every layer.** A latitude without its
longitude is not a location, it is corruption. The server rejects it, and
`restore()` ignores a half-set cloud pair rather than writing half a location —
because a lone latitude reads as "set" downstream while being unusable, which is
worse than leaving the gap.

**`push()` fires even when nothing is set.** Clearing a location is a real
change the cloud must learn about. Skipping the all-null push would strand a
cleared coordinate in Firestore forever.

## Surprises

**`clearFirestore` only cleared `trips`.** Six preference tests failed on first
run because the helper predates the `users` collection, so documents leaked
between cases. Extended it to clear both — a no-op for the trip suites.

**Two existing `ApiClient` fakes broke the build.** `sync_engine_test` and
`restore_controller_test` both `implements ApiClient`, so adding two methods to
the class made them abstract. Rather than no-op stubs, both now throw
`UnimplementedError` — `SyncEngine` and the restore flow must never reach the
preference endpoints (D-02), and throwing makes accidental coupling fail loudly
instead of passing silently.

**The Phase 26 key-set test was already the SC#6 guard the plan asked for.**
`trip_serializer_test` asserts an exact key set on the trip payload, so a coord
leaking into trip sync fails it automatically. Added two explicit
`containsKey` assertions to make that role visible rather than incidental.

## What is NOT done

**~~Deploy~~ — DONE 2026-07-20.** `firebase deploy --only functions` against
`travey-298a7`; `api(us-central1)` updated successfully. Verified live against
`https://us-central1-travey-298a7.cloudfunctions.net/api`:

| Endpoint | Unauthenticated | Meaning |
|---|---|---|
| `/health` | 200 `{"status":"ok"}` | function alive |
| `/trips/restore` | 401 | **pre-existing route intact** |
| `/trips/sync` | 401 | **pre-existing route intact** |
| `/preferences/restore` | 401 | new route registered (404 would mean it wasn't) |
| `/preferences/sync` | 401 | auth runs before validation (T-29-03) |

Also confirmed T-29-02 on the live endpoint: POSTing real coordinates
unauthenticated returns the fixed `{"error":"Unauthorized"}` with no echo of
the submitted values.

The blast-radius risk was that all five routes share ONE Cloud Function
(`onRequest(app)`), so the deploy replaced the function already serving trip
sync. The trip 401s above are the evidence it came through clean.

**Play Data Safety declaration — STILL OUTSTANDING, and it is now the only
gate.** Per D-01 this phase moves the listing from *no location data collected*
to *precise location collected and stored, linked to the account*.

Clarification worth keeping: this blocks shipping the CLIENT, not the deploy.
Endpoints that no released app calls collect nothing. That is why the deploy
above was safe to do first — and it is the order SC#2 demanded anyway.

**Device verification.** No real sign-in against the live backend has been run.
Added to the Phase 23 device-only queue.

**The branch is not merged.** `phase-29-sync-home-office` stays off `main`
until the two gates above clear — merging it would put a client that emits
preference payloads on the main line before the endpoint answering them exists.

## Follow-ups

1. ~~Deploy backend~~ — done and verified 2026-07-20.
2. **Update the Play Data Safety form** — the one remaining gate before the client can ship.
3. Merge `phase-29-sync-home-office` to `main` (safe once 2 is done; the backend it depends on is already live).
4. Device-verify: sign in on a fresh install, confirm pins restore and the first trip labels by geofence.

**Housekeeping noticed during deploy (pre-existing, not introduced here):** the
Artifact Registry repo in `us-central1` has no cleanup policy, so container
images from every deploy since Phase 10 accumulate and bill slowly. Fix with
`firebase functions:artifacts:setpolicy` when convenient. Also flagged: Node.js
20 is deprecated and decommissions 2026-10-30 — the runtime will need bumping
before then, worth its own small phase.
