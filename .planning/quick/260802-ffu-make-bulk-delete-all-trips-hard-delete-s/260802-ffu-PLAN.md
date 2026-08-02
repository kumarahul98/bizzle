---
phase: quick-260802-ffu
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - backend/functions/src/handlers/delete-all-trips.ts
  - backend/functions/src/utils/bulk-delete.ts
  - backend/functions/src/handlers/delete-account.ts
  - backend/functions/src/index.ts
  - backend/functions/test/handlers/delete-all-trips.test.ts
  - backend/functions/test/handlers/delete-account.test.ts
  - CLAUDE.md
  - landing/src/pages/Privacy.jsx
autonomous: true
requirements: [D-1, D-2, D-3, D-4, D-5]

must_haves:
  truths:
    - "A signed-in user who taps 'Delete all data' has every one of their trip documents erased from Firestore, including trips already sitting in Trash"
    - "Another user's trips are completely untouched by that call (D-08 isolation)"
    - "The wire contract is unchanged: DELETE /trips still returns { statusCode: 200, body: { data: { deletedCount } } }"
    - "No comment, JSDoc, CLAUDE.md rule, or privacy-policy sentence still claims the bulk endpoint soft-deletes"
    - "The backend test suite asserts hard-delete semantics (documents gone), not soft-delete semantics"
  artifacts:
    - path: "backend/functions/src/handlers/delete-all-trips.ts"
      provides: "DELETE /trips handler calling hardDeleteAllTripsForUser"
      contains: "hardDeleteAllTripsForUser"
    - path: "backend/functions/src/utils/bulk-delete.ts"
      provides: "hardDeleteAllTripsForUser only (soft bulk helper removed as dead code)"
    - path: "backend/functions/test/handlers/delete-all-trips.test.ts"
      provides: "Hard-delete integration coverage incl. mixed live+Trash case"
    - path: "CLAUDE.md"
      provides: "Corrected deletion rule: per-trip trash = soft; bulk delete-all = HARD; account deletion = HARD"
    - path: "landing/src/pages/Privacy.jsx"
      provides: "Privacy policy stating bulk delete erases trips from device and backend"
  key_links:
    - from: "backend/functions/src/handlers/delete-all-trips.ts"
      to: "backend/functions/src/utils/bulk-delete.ts"
      via: "import { hardDeleteAllTripsForUser }"
      pattern: "hardDeleteAllTripsForUser"
    - from: "backend/functions/src/index.ts"
      to: "deleteAllTripsHandler"
      via: "app.delete('/trips', ...) route registration (unchanged)"
      pattern: "app\\.delete\\('/trips',"
---

<objective>
Make `DELETE /trips` (the in-app "Delete all data" action that keeps the user's
account) HARD-delete every trip owned by the caller — including trips already
sitting in Trash — so the backend matches the promise the confirmation dialog
already makes to users, and so cloud behaviour matches the genuine local Drift
wipe.

Purpose: today the endpoint soft-deletes and skips already-trashed trips, while
`kDeleteAllDataDialogBody` tells the user "This permanently deletes every trip
on this device, and in the cloud if you're signed in." That is a false deletion
promise — a Play / GDPR compliance exposure.

Output: one-line behaviour change in the handler, removal of the now-dead soft
bulk helper, corrected docs everywhere the old rule was written down (JSDoc,
route comments, CLAUDE.md, privacy policy), and backend tests re-pointed at
hard-delete semantics.
</objective>

<execution_context>
@/Users/coolman/Documents/Projects/bizzle/.claude/get-shit-done/workflows/execute-plan.md
@/Users/coolman/Documents/Projects/bizzle/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@backend/functions/src/handlers/delete-all-trips.ts
@backend/functions/src/utils/bulk-delete.ts
@backend/functions/src/handlers/delete-account.ts
@backend/functions/src/index.ts
@backend/functions/test/handlers/delete-all-trips.test.ts
@landing/src/pages/Privacy.jsx

<locked_decisions>
D-1: `DELETE /trips` must HARD-delete every trip owned by the caller, including
     trips already in Trash. Nothing may be left behind for that uid.
D-2: `hardDeleteAllTripsForUser` already implements exactly this. REUSE it.
     Do NOT write a second hard-delete helper.
D-3: The per-trip trash flow (`DELETE /trips/:tripId`, `delete-trip.ts`) stays
     SOFT — Trash restore depends on it. Do not change its behaviour.
D-4: `delete-account.ts` stays HARD. Do not change its behaviour.
D-5: The CLAUDE.md "Soft deletes everywhere — with one deliberate exception"
     rule is now wrong and MUST be rewritten in this same change, or a future
     agent will read it as authoritative and revert this fix.
</locked_decisions>

<interfaces>
<!-- Contracts the executor needs. No codebase exploration required. -->

backend/functions/src/utils/bulk-delete.ts (current exports):
```typescript
export async function softDeleteAllTripsForUser(uid: string): Promise<number>; // to be DELETED
export async function hardDeleteAllTripsForUser(uid: string): Promise<number>; // KEEP — reuse
```

`hardDeleteAllTripsForUser` already does exactly what D-1 requires:
- queries `tripsCollection().where('userId', '==', uid)` with NO `deleted` filter
- `batch.delete()` per doc, chunked at `FIRESTORE_BATCH_LIMIT = 500`
- returns the number of documents erased

Verified caller inventory (grep, whole repo, excluding node_modules):
- `softDeleteAllTripsForUser` — exactly ONE call site: `delete-all-trips.ts:44`.
  After Task 1 it has zero callers and becomes dead code.
- `hardDeleteAllTripsForUser` — called by `delete-account.ts:56`; gains
  `delete-all-trips.ts` as a second caller.

Response contract (unchanged by this plan):
```typescript
// 200: { statusCode: 200, body: { data: { deletedCount: number } } }
// 401: { statusCode: 401, body: { error: 'Unauthorized' } }
// 500: { statusCode: 500, body: { error: 'Internal error' } }
```
Only the MEANING of `deletedCount` shifts: "soft-deleted" -> "erased".

Test harness helpers (backend/functions/test/helpers/emulator.ts):
```typescript
clearFirestore(): Promise<void>
seedTrip({ id, userId, deleted }): Promise<void>
db // Admin Firestore instance for direct assertions
mintIdToken(uid: string): Promise<string> // from test/helpers/mint-token
```
</interfaces>

<out_of_scope>
Do NOT touch, and do NOT let these drift into the diff:
- `delete-trip.ts` behaviour (per-trip soft delete, D-3) and its test suite.
- `delete-account.ts` BEHAVIOUR (D-4). Task 1 edits only ONE stale sentence in
  its JSDoc that describes the OTHER endpoint — no code, no logic.
- The Flutter delete flow: `DeleteTripsController`, `delete_all_data_row.dart`,
  `ApiClient.deleteAllTrips()`, `TripsDao.deleteAllTrips()`. The client already
  hard-wipes locally and the wire contract is unchanged, so no client code
  change is needed. If you conclude otherwise, STOP and report rather than
  editing client code.
- Firestore security rules, indexes, the sync engine, and anything from quick
  tasks 260801-oux / 260801-tjx / 260802-dgp.
</out_of_scope>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Switch DELETE /trips to hard delete and purge the stale soft-delete narrative from backend source</name>
  <files>backend/functions/src/handlers/delete-all-trips.ts, backend/functions/src/utils/bulk-delete.ts, backend/functions/src/handlers/delete-account.ts, backend/functions/src/index.ts</files>
  <action>
Four edits, all in backend/functions/src.

1. `handlers/delete-all-trips.ts` — the behaviour change (D-1, D-2):
   - Change the import on line 3 from `softDeleteAllTripsForUser` to
     `hardDeleteAllTripsForUser`.
   - Change line 44 to `const deletedCount = await hardDeleteAllTripsForUser(uid);`.
   - Leave `verifyAuth`, the 401/500 branches, the status codes, and the
     `{ statusCode, body: { data: { deletedCount } } }` shape EXACTLY as they
     are. This is a one-call swap, not a rewrite.
   - Rewrite the file-level JSDoc (lines 5-29). The current block argues at
     length FOR soft delete — especially the D-11 paragraph at lines 18-22 —
     and would directly contradict the code. The new block must state:
       * `DELETE /trips` is the "delete all my data, keep my account" action
         (Phase 38, BACK-05) required by Google Play.
       * It HARD-deletes every trip owned by the caller via
         {@link hardDeleteAllTripsForUser}, INCLUDING trips already sitting in
         the user's Trash. Nothing is retained for that uid.
       * WHY it is hard: the in-app confirm dialog
         (`kDeleteAllDataDialogBody`) promises "This permanently deletes every
         trip on this device, and in the cloud if you're signed in", and the
         local Drift wipe is a genuine hard delete. A "delete all my data"
         that quietly retains records is a false promise to the user and a
         Play / GDPR exposure. Device and cloud must agree.
       * Contrast that remains true: the per-trip trash flow
         (`delete-trip.ts`) is still SOFT, because Trash restore depends on it.
       * Keep the still-accurate parts: verify -> validate -> trust (D-07)
         with no body/path param to validate; zero matching trips is a
         successful `deletedCount: 0`, not an error; the
         `{ statusCode, body: { data? | error? } }` shape (D-06) with short
         typed error strings that never leak internals.
       * Note that `deletedCount` now means "trips erased".

2. `utils/bulk-delete.ts` — remove dead code and fix the surviving JSDoc:
   - Delete `softDeleteAllTripsForUser` entirely (lines 11-63: its JSDoc block
     and function body). Grep already confirms `delete-all-trips.ts:44` was
     its only call site, so after edit 1 it has zero callers, and CLAUDE.md
     says "No dead code — delete what isn't needed". Re-run
     `grep -rn "softDeleteAllTripsForUser" --include="*.ts" backend/ | grep -v node_modules`
     after the edit and confirm ZERO hits remain (including JSDoc @link
     references) before moving on.
   - Update `hardDeleteAllTripsForUser`'s JSDoc: "Used only by
     `DELETE /account`" (line 67-68) is now false — it has two callers,
     `DELETE /account` (full account deletion) and `DELETE /trips` (bulk
     delete-all-data). Rewrite the framing: this is no longer a "narrow
     exception to D-11". State the current rule plainly — per-trip trash is
     soft; both bulk erasure flows are hard, because both promise the user
     their data is gone. Keep the accurate contract notes: no `deleted`
     filter (deliberately also purges trips already in Trash),
     `batch.delete()` not `.update()`, <=500-op chunks committed sequentially
     mirroring `sync-trips.ts`, zero matches returns 0 and is not an error,
     Firestore errors propagate untranslated for the handler to map.
   - Fix the `FIRESTORE_BATCH_LIMIT` doc comment (lines 4-9), which currently
     says "Bulk soft-delete chunks the caller's non-deleted trips at this
     size" — reword for the hard-delete helper.

3. `handlers/delete-account.ts` — COMMENT ONLY, no code change (D-4):
   Its JSDoc lines 20-26 assert that "the bulk 'delete all my data, keep my
   account' endpoint in `delete-all-trips.ts` [remains] soft-delete-only,
   unchanged" and frame account deletion as "the one deliberate exception".
   Both statements become false. Rewrite just that cross-reference so it says:
   per-trip trash (`delete-trip.ts`) stays soft; the bulk delete-all-data
   endpoint is also hard; account deletion additionally removes the
   preferences doc and the Auth user. Leave the handler body, the a/b/c
   ordering rationale, and every response line untouched.

4. `index.ts` — route comment lines 45-49 say "bulk soft-delete ALL of the
   caller's trips". Change to hard-delete wording. Keep the Express
   route-ordering rationale sentence verbatim. Also fix line 54-55's "(the one
   deliberate exception to the project's soft-delete rule — see claude.md...)"
   so it no longer claims uniqueness. Do not reorder or change any
   `app.delete(...)` registration.

Strict TypeScript throughout, no `any`, no new dependencies. No behaviour
change anywhere except the single helper swap in edit 1.
  </action>
  <verify>
    <automated>cd backend/functions && npm run build && grep -rn "softDeleteAllTripsForUser" --include="*.ts" src/ test/ | grep -v node_modules; test $? -ne 0</automated>
  </verify>
  <done>
`npm run build` compiles clean (tsc, strict). `delete-all-trips.ts` imports and
calls `hardDeleteAllTripsForUser`. `softDeleteAllTripsForUser` no longer exists
anywhere in backend/functions (source, tests, or JSDoc links). No JSDoc or route
comment in backend/functions/src still describes `DELETE /trips` as
soft-deleting, and none still calls account deletion the only hard-delete
exception. `delete-account.ts` and `delete-trip.ts` behaviour is byte-identical
apart from the one cross-reference sentence in `delete-account.ts`'s JSDoc.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Re-point the backend tests at hard-delete semantics and add mixed live+Trash coverage</name>
  <files>backend/functions/test/handlers/delete-all-trips.test.ts, backend/functions/test/handlers/delete-account.test.ts</files>
  <behavior>
`DELETE /trips` integration suite, after this task:
- auth-reject: no Authorization header -> 401; invalid bearer -> 401. UNCHANGED.
- empty-trips: caller with no trips -> 200, `deletedCount: 0`. UNCHANGED.
- HARD-delete of live trips: seed 3 trips for userA with `deleted:false`, call
  the endpoint -> 200, `deletedCount: 3`, and for each id
  `db.collection('trips').doc(id).get()` has `snap.exists === false`. The
  existing assertions `expect(snap.exists).toBe(true) // NOT hard-deleted` and
  the `deleted:true` / `deletedAt` / `serverUpdatedAt` checks are now inverted
  expectations and must be REPLACED, not merely relaxed.
- MIXED live + Trash (the case that motivated D-1, new): seed 2 trips for
  userA with `deleted:false` and 2 with `deleted:true` (already in Trash).
  Call the endpoint -> 200, `deletedCount: 4` (all four counted, because the
  hard helper has no `deleted` filter), and afterwards a query
  `db.collection('trips').where('userId','==','userA').get()` returns an EMPTY
  snapshot — nothing at all remains for that uid.
- idempotent re-run: first call erases the seeded trip and returns
  `deletedCount: 1`; a second call returns `deletedCount: 0` because the
  documents are gone (not because they were filtered out by `deleted:true`).
- cross-user isolation (D-08): seed one trip for userA and one for userB, both
  `deleted:false`. userA's call -> `deletedCount: 1`; userB's document still
  exists (`snap.exists === true`) with `deleted === false`. This property must
  still hold after the change.
  </behavior>
  <action>
Update `test/handlers/delete-all-trips.test.ts` in place. Rewrite the file-level
JSDoc (lines 1-11): it currently advertises "bulk soft-delete semantics" and
"already-deleted trips left alone". Describe hard-delete semantics, the mixed
live+Trash case, and the retained D-08 cross-user property.

Rename the `describe('multi-trip bulk soft-delete')` block and the
`it('soft-deletes every non-deleted trip owned by the caller')` case to
hard-delete wording — test names are documentation and must not lie. Keep the
existing structure, harness helpers (`clearFirestore`, `seedTrip`, `db`,
`mintIdToken`), supertest style, and `beforeEach(clearFirestore)` — match the
patterns already in the file, do not introduce new ones.

Add the MIXED live + Trash case described in <behavior> as a new `it(...)` in
the same describe block. It is the regression guard for D-1: before this change
those Trash trips were skipped entirely by the `deleted == false` predicate.

Also fix the stale comment at `test/handlers/delete-account.test.ts:10`, which
tells the reader that the other bulk flows are "soft-delete-only". Comment
only — do not change any account-deletion assertion (D-4).

Do NOT delete or weaken any existing assertion to make the suite pass. Every
soft-delete assertion is replaced by the equivalent hard-delete assertion, not
dropped. Do not touch `delete-trip.test.ts` (D-3).

The suite runs against the Firebase emulator via the `test` script; expect the
run to boot auth + firestore emulators.
  </action>
  <verify>
    <automated>cd backend/functions && npm test</automated>
  </verify>
  <done>
`npm test` passes green (all jest projects: unit + integration under the
emulator). `delete-all-trips.test.ts` asserts `snap.exists === false` for erased
trips, contains the mixed live+Trash case proving zero documents remain for the
uid, and still proves userB's trips are untouched. No test name or comment in
the touched files describes `DELETE /trips` as soft-deleting.
  </done>
</task>

<task type="auto">
  <name>Task 3: Correct the user-facing and agent-facing documentation of the deletion model</name>
  <files>CLAUDE.md, landing/src/pages/Privacy.jsx, lib/config/constants.dart</files>
  <action>
1. `CLAUDE.md` — rewrite the "Soft deletes everywhere — with one deliberate
   exception" bullet in `## Important Notes` (the long bullet beginning
   "**Soft deletes everywhere...**"). This is D-5 and is NOT optional: the
   current text explicitly documents the bulk flow as soft-delete-by-design and
   frames account deletion as "the ONE exception", so leaving it would license
   a future agent to revert this fix.

   The replacement bullet must state, unambiguously:
     * Per-trip trash (`DELETE /trips/:tripId`) is SOFT — it marks
       `deleted: true` and Trash restore depends on that. Do not make it hard.
     * Bulk "delete all my data, keep my account" (`DELETE /trips`) is HARD —
       it erases every trip document for that uid, including trips already in
       Trash. The in-app dialog promises permanent deletion and the local Drift
       wipe is a real delete, so the backend must match. Do not "fix" this back
       to soft-delete.
     * Full account deletion (`DELETE /account`) is HARD — same rationale, plus
       the uid can never authenticate again.
   Retitle the bullet so the lead-in no longer says "Soft deletes everywhere"
   (e.g. "**Deletion model — soft for Trash, hard for erasure.**"). Keep it a
   single bullet in the existing list; do not restructure the surrounding
   section.

2. `landing/src/pages/Privacy.jsx` — rewrite the `<Strong>Delete all data</Strong>`
   bullet in the `id="delete-account"` section (currently lines 171-177). The
   sentence "On our backend those trips are marked deleted and excluded from
   sync and restore, but the records are <Strong> retained</Strong> rather than
   erased. To erase them outright, delete your account instead." becomes false
   and must go. New copy must say the action removes every trip from the device
   AND erases those trips from our backend, including trips still sitting in
   Trash, while the account itself is kept so the user can carry on with a clean
   slate — and that this cannot be undone. Match the surrounding voice and the
   existing `<Strong>` / `<LI>` / JSX-entity conventions used in the file.

   Leave the `<Strong>Delete account</Strong>` bullet exactly as-is — it is
   still accurate. Leave the email-request paragraph and the on-device-data
   paragraph as-is.

   `LAST_UPDATED` is already `'August 2, 2026'`, which is today — leave it
   unchanged and say so in the summary rather than editing it.

3. `lib/config/constants.dart` — VERIFY ONLY, expect no edit. Re-read
   `kDeleteAllDataDialogBody` (~line 2085) and its dartdoc (~2082-2084) plus the
   Phase 38 section comment (~2066-2074). Once the backend hard-deletes, the
   existing copy — "This permanently deletes every trip on this device, and in
   the cloud if you're signed in. Your account stays signed in — this cannot be
   undone." — becomes TRUE, so it should need no change. Confirm that
   explicitly. Only edit if some adjacent dartdoc claims the server retains
   data; if nothing does, leave the file untouched and record in the summary
   that it was verified accurate rather than edited. Do not edit it reflexively.
  </action>
  <verify>
    <automated>cd landing && npm run build</automated>
  </verify>
  <done>
`landing` builds clean. CLAUDE.md's deletion bullet describes per-trip trash as
soft and BOTH bulk delete-all-data and account deletion as hard, with no
surviving "one deliberate exception" framing. Privacy.jsx's "Delete all data"
bullet states trips are erased from the device and the backend; the "Delete
account" bullet and `LAST_UPDATED` are unchanged. `constants.dart` is either
untouched (verified accurate) or has only a dartdoc correction — and the summary
says which, with the reason.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Flutter client -> `DELETE /trips` | Untrusted caller; only the verified ID-token uid may scope the deletion |
| Handler -> Firestore (Admin SDK) | Admin SDK bypasses deny-all Security Rules, so the query predicate is the only isolation control |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-FFU-01 | Spoofing | `deleteAllTripsHandler` auth | mitigate | Unchanged `verifyAuth(req)` runs FIRST; uid comes only from the verified token, never from body/query. 401 before any Firestore access. Covered by the retained auth-reject tests. |
| T-FFU-02 | Tampering / Elevation | `hardDeleteAllTripsForUser` query scope | mitigate | Query is `where('userId','==',uid)` with no client-supplied input. Now IRREVERSIBLE, so a scoping bug destroys data permanently — the D-08 cross-user test (userB's trip must survive intact) is the guard and MUST stay green (Task 2). |
| T-FFU-03 | Denial of Service | Unbounded batch loop | accept | Per-uid trip counts are bounded by real commute history; existing <=500-op chunking already caps each commit. Same exposure as the already-shipped `DELETE /account`. |
| T-FFU-04 | Repudiation | Erased trips leave no audit trail | accept | Deliberate: the product promise is erasure, and retaining a shadow record would recreate the exact false-promise problem this change fixes. `deletedCount` is returned to the caller as the acknowledgement. |
| T-FFU-05 | Information disclosure | Error responses | mitigate | Unchanged `catch` returns the fixed string `'Internal error'` with no Firestore internals; response shape `{ statusCode, body: { error } }` preserved. |
</threat_model>

<verification>
Run from the repo root, in order:

```bash
cd backend/functions && npm run build     # strict tsc, must compile clean
cd backend/functions && npm test          # jest via firebase emulators:exec (auth + firestore)
cd landing && npm run build               # Privacy.jsx change
```

`flutter analyze` and `flutter test` are required ONLY if Task 3 ends up editing
`lib/config/constants.dart`. The expected outcome is that it does not — if the
Dart file is untouched, skip both and say so in the summary.

Manual grep gate (must return nothing):
```bash
grep -rn "softDeleteAllTripsForUser" --include="*.ts" backend/ | grep -v node_modules
```
</verification>

<success_criteria>
- `DELETE /trips` calls `hardDeleteAllTripsForUser`; `softDeleteAllTripsForUser`
  no longer exists in the repo.
- A user with both live trips and trips in Trash who calls `DELETE /trips` has
  ZERO trip documents remaining for their uid, proven by an integration test.
- Another user's trips are provably untouched (D-08 test still green).
- `delete-trip.ts` (soft, D-3) and `delete-account.ts` (hard, D-4) behaviour are
  unchanged; only a stale JSDoc cross-reference in the latter was corrected.
- No client/Flutter code changed; the `DELETE /trips -> { deletedCount }` wire
  contract is identical.
- CLAUDE.md, both backend JSDoc blocks, the `index.ts` route comments, the test
  names, and Privacy.jsx all describe the same deletion model: trash = soft,
  bulk delete-all = hard, account deletion = hard.
- `npm run build`, `npm test`, and `landing` build all pass.
</success_criteria>

<deployment_note>
REQUIRED FOLLOW-UP — the summary MUST carry this forward as an open action:

This change is NOT live until the backend is redeployed to **traevy-prod**.
`DELETE /trips` is already deployed and is serving the SOFT behaviour in
production right now, so until a human runs the deploy, the in-app dialog's
"permanently deletes ... in the cloud" promise remains FALSE for real users.
This is the compliance-relevant half of the fix.

Deploy command (human-run, not part of this plan):
```bash
cd backend && firebase deploy --only functions
```
Confirm the active Firebase project is traevy-prod before deploying.
</deployment_note>

<commit_guidance>
Use the CLAUDE.md bracket convention, one concern per commit:
- Tasks 1 + 2 -> `[backend] Hard-delete all trips on DELETE /trips`
- Task 3 -> `[infra] Correct deletion-model docs in CLAUDE.md and privacy policy`
</commit_guidance>

<output>
After completion, create
`.planning/quick/260802-ffu-make-bulk-delete-all-trips-hard-delete-s/260802-ffu-SUMMARY.md`.

The summary must explicitly record:
1. Whether `lib/config/constants.dart` was edited or verified-accurate-and-left-alone.
2. That `softDeleteAllTripsForUser` was removed as dead code, with the grep evidence.
3. The traevy-prod redeploy follow-up from <deployment_note> as an OPEN action.
</output>
</content>
</invoke>
