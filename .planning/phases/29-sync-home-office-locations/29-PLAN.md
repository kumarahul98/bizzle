---
phase: 29-sync-home-office-locations
created: 2026-07-19
status: not_started
mode: manual-gsd
requirements: [LOC-03]
depends_on: [21, 24, 26]
reverses: [T-21-02, T-21-02-01, T-21-03]
result: >
  NOT STARTED. Plan only. This phase deliberately overturns the Phase 21
  T-21-02 privacy mitigation (Home/Office coords never leave the device).
  That reversal is the phase's defining decision, not a side effect — see
  D-01. Requires a Play Data Safety declaration change BEFORE release.
---

# Phase 29 — Sync Home & Office Locations to Cloud

**Goal**: A user who reinstalls the app or signs in on a new device gets their saved
Home and Office locations back automatically, so geofence auto-labeling keeps working
without re-picking two map pins.

**Depends on**: Phase 21 (the coord columns + geofence resolver), Phase 24 (auto-restore
on sign-in — the seam this hooks into), Phase 26 (the sync/restore wire-contract patterns
this mirrors)

---

## D-01 — Overturning T-21-02 (the decision this phase exists to make)

Phase 21 recorded, and **mitigated**, the risk of Home/Office coordinates leaving the
device. This is not an oversight being corrected; it is a decision being reversed on
purpose. Recorded here so the reversal is auditable:

**What Phase 21 decided** (`21-01-PLAN.md` T-21-02, `21-02-PLAN.md` T-21-02-01):

> Coord columns are stored locally in Drift; NO new sync field carries them (v0.3 sync
> is unchanged). […] Coords live only in local Drift; NEVER logged or printed; not sent
> to any backend in this plan.

The constraint is also written into the schema itself — `user_preferences_table.dart`
lines 84–101 carry per-column dartdocs stating "Stored locally in Drift only; no sync
field carries it."

**Why we are reversing it**: without cloud persistence, a reinstall silently degrades
geofence auto-labeling to the time-of-day heuristic with no user-visible explanation.
The user accepted this trade in Phase 21 when restore did not exist; Phase 24 has since
made "sign in and everything comes back" the expected behavior, and Home/Office are now
the only user-configured data that does not honour it.

**What the reversal costs** — all mandatory, none optional:

1. **Play Data Safety declaration must change** before any release carrying this code.
   The listing moves from *no location data collected* to *precise location collected
   and stored*, linked to the account. This is user-visible on the store page.
2. The three PII dartdocs above become false and MUST be rewritten in the same commit
   that adds the sync field — a stale "never leaves the device" comment sitting above a
   column that now syncs is worse than no comment.
3. `T-21-03` ("NEVER log") stays in force and is NOT reversed. Transporting a coordinate
   over TLS to our own Firestore is a different act from writing it to logcat. No
   logging of coords is permitted anywhere on the new path.

**Gate**: do not merge this phase to a release branch until the Data Safety form is
updated. Code-complete ≠ shippable here.

---

## D-02 — Preferences do not ride the trip sync queue

`sync_queue.tripId` is `text()` — **non-nullable**, and used as the FK to `trips.id`
throughout `SyncQueueDao`. A preferences entry has no trip. Three options were weighed:

| Option | Verdict |
|---|---|
| Make `tripId` nullable + add an `entityType` discriminator | **Rejected.** Touches every existing sync-queue query and risks destabilizing the trip path, which Phases 24/25.1/26 have already stabilized at real cost. |
| A second `preferences_sync_queue` table | **Rejected.** Speculative machinery for a single idempotent row. |
| **Push directly, no queue** | **Chosen.** |

Home/Office is ONE row, tiny, idempotent, order-independent, and last-write-wins. A
queue exists to preserve ordering and survive partial failure across many entities;
neither applies. Push on change and on sign-in; on failure, do nothing — the next change
or next sign-in re-pushes the current truth. This cannot drift, because the payload is
always the whole current value rather than a delta.

## D-03 — Restore precedence: local wins, cloud fills only nulls

CLAUDE.md is explicit that the client is authoritative and Drift is the source of truth.
On restore, a cloud coordinate is written **only where the local value is null**. A user
who has already set Home on this device never has it silently moved by a stale cloud
copy. This makes restore purely additive and removes any need for conflict UI.

## D-04 — Firestore shape

One document per user at `users/{uid}` with a `savedLocations` map
(`homeLat/homeLng/officeLat/officeLng`, all nullable numbers). NOT a subcollection —
there is exactly one row per user, forever. Security Rules stay deny-all to clients;
only the Admin SDK touches it, matching the existing trips posture.

## D-05 — Endpoint surface

Two new handlers, one file each per CLAUDE.md:

- `backend/functions/src/handlers/sync-preferences.ts` — `POST /preferences/sync`
- `backend/functions/src/handlers/restore-preferences.ts` — `GET /preferences/restore`

Deliberately NOT folded into the trip handlers: different entity, different lifecycle,
and `sync-trips.ts` is already the most-touched backend file in the project.

---

## Execution waves (conflict-safe)

**Wave 1 — backend first** (SC#2: backend must deploy before any client emits)

- `29-01` — zod schema + both handlers + Firestore converter + handler tests; deploy live.
  Schema accepts all four coords as **optional nullable**, so a client that has never set
  Home still syncs cleanly.

**Wave 2 — client wire** *(blocked on Wave 1 being live)*

- `29-02` — `ApiClient` methods, a `PreferencesSyncService`, and the D-01 dartdoc
  rewrite on all four coord columns. No schema migration needed: the columns already
  exist (v6). **`schemaVersion` stays 8.**

**Wave 3 — triggers** *(blocked on Wave 2)*

- `29-03` — push on change (the location-picker confirm seam) + push/restore on sign-in
  (the Phase 24 auto-restore seam in MainShell). D-03 null-only merge on the restore side.

---

## Threat model

| ID | Category | Asset | Decision | Mitigation |
|---|---|---|---|---|
| T-29-01 | Information disclosure | Home/Office coords in transit and at rest in Firestore | **accept (reverses T-21-02)** | Accepted deliberately per D-01. Transport is TLS; at rest the doc is Admin-SDK-only (Rules deny-all to clients), same posture as trip polylines — which already encode the user's route past their front door, so the marginal disclosure over existing synced data is smaller than it first appears. Requires the Data Safety declaration in D-01. |
| T-29-02 | Information disclosure | Coords in logs / error traces | **mitigate (T-21-03 upheld)** | No `print`/`debugPrint` of coords on the new path. The sync service logs status codes only, never the payload. Handler errors return generic messages and never echo the body. |
| T-29-03 | Spoofing | Another user's preferences doc | mitigate | Doc id is derived server-side from the verified `uid` in the Firebase ID token — never from the request body. A client cannot name the document it writes. |
| T-29-04 | Tampering | Out-of-range coordinates | mitigate | zod validates lat ∈ [-90, 90], lng ∈ [-180, 180], and rejects NaN/Infinity. A poisoned coord would silently corrupt geofence labeling on every future trip. |
| T-29-05 | Data loss | Cloud copy overwriting a good local value | mitigate | D-03 null-only merge — restore never overwrites a non-null local coord. |

---

## Success criteria (what must be TRUE)

1. Setting Home or Office pushes both pairs to Firestore within one sync cycle; the
   Firestore doc reflects the local values exactly.
2. The backend is deployed and live BEFORE any client build emits preference payloads
   (the non-strict zod schema would otherwise strip unknown keys and lose data silently
   — the Phase 26 SC#2 lesson).
3. A fresh install that signs in receives its saved Home/Office and geofence auto-labeling
   works on the first trip, with no map interaction.
4. A device that already has Home set locally does NOT have it changed by restore (D-03).
5. A user who has never set Home/Office syncs and restores cleanly — all-null payload is
   valid, not an error.
6. No coordinate appears in any log, on device or in Cloud Functions logs.
7. The Play Data Safety declaration is updated before release (process gate, not code).

## Verification

- Handler unit tests (zod accept/reject incl. the range and NaN cases in T-29-04).
- `PreferencesSyncService` unit tests incl. the D-03 null-only merge matrix.
- A test asserting the serializer emits coords ONLY on the preferences path — the trip
  payload key-set test from Phase 26 must still pass unchanged, proving trip sync did
  not silently gain a coord field.
- Manual: install fresh → sign in → confirm pins restore.
