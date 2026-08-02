---
quick_id: 260802-ffu
title: Make bulk delete-all-trips hard-delete server-side to match the promise shown to users
type: quick
requirements: [D-1, D-2, D-3, D-4, D-5]
key-files:
  created: []
  modified:
    - backend/functions/src/handlers/delete-all-trips.ts
    - backend/functions/src/utils/bulk-delete.ts
    - backend/functions/src/handlers/delete-account.ts
    - backend/functions/src/index.ts
    - backend/functions/test/handlers/delete-all-trips.test.ts
    - backend/functions/test/handlers/delete-account.test.ts
    - claude.md
    - landing/src/pages/Privacy.jsx
decisions:
  - "DELETE /trips now hard-deletes via hardDeleteAllTripsForUser (reused, not duplicated)"
  - "softDeleteAllTripsForUser removed entirely as dead code"
  - "lib/config/constants.dart verified accurate, left untouched"
metrics:
  duration: "~35 min"
  completed: 2026-08-02
---

# Quick Task 260802-ffu: Make bulk delete-all-trips hard-delete server-side Summary

One-liner: `DELETE /trips` now calls the existing `hardDeleteAllTripsForUser` helper instead of the soft-delete one, so the in-app "delete all data" action genuinely erases every trip (including ones in Trash) from Firestore, closing the false-deletion-promise / compliance gap — but this is NOT yet live in production (see Deployment Gap below).

## What Changed

### Task 1 — Backend behaviour swap (commit `e154ac7`)
- `backend/functions/src/handlers/delete-all-trips.ts`: import and call
  `hardDeleteAllTripsForUser` instead of `softDeleteAllTripsForUser`. One-line
  behaviour change; response shape (`{ statusCode, body: { data: { deletedCount } } }`)
  untouched. File-level JSDoc rewritten to describe hard-delete semantics, the
  "why" (matching the in-app dialog's permanent-deletion promise and the real
  local Drift wipe), and the retained contrast with the still-soft per-trip
  trash flow.
- `backend/functions/src/utils/bulk-delete.ts`: **deleted `softDeleteAllTripsForUser`
  entirely** (function body + JSDoc + the now-unused `FieldValue` import). Grep
  confirms zero remaining references anywhere in `backend/` (see evidence below).
  `hardDeleteAllTripsForUser`'s JSDoc rewritten to state it is now used by BOTH
  bulk erasure flows (`DELETE /trips` and `DELETE /account`), replacing the
  "narrow exception to D-11" framing with the current rule: per-trip trash is
  soft, both bulk flows are hard. `FIRESTORE_BATCH_LIMIT`'s doc comment reworded
  for the hard-delete-only file.
- `backend/functions/src/handlers/delete-account.ts`: **comment-only** edit
  (D-4 preserved) — rewrote the JSDoc cross-reference that used to say the bulk
  delete-all-data endpoint "remains soft-delete-only, unchanged." Handler body,
  ordering rationale, and every response line are byte-identical to before.
- `backend/functions/src/index.ts`: route comments corrected ("bulk soft-delete"
  -> "bulk hard-delete"; removed the now-false "one deliberate exception"
  framing on the `/account` route comment). No `app.delete(...)` registrations
  reordered or changed.

### Task 2 — Tests re-pointed at hard-delete semantics (commit `e154ac7`, bundled with Task 1 per plan's commit guidance)
- `backend/functions/test/handlers/delete-all-trips.test.ts`: rewrote file-level
  JSDoc, renamed the `describe`/`it` blocks from "soft-delete" wording to
  "hard-delete" wording (test names are documentation). Inverted the previously
  bug-confirming assertions:
  - `expect(snap.exists).toBe(true); // NOT hard-deleted` -> `expect(snap.exists).toBe(false)` (document actually gone)
  - Dropped the `deleted:true` / `deletedAt` / `serverUpdatedAt` field checks (no longer meaningful — the doc doesn't exist)
  - **Added a new test**: mixed live + Trash case — seeds 2 live + 2 already-trashed
    trips, calls `DELETE /trips`, asserts `deletedCount: 4` and that a
    `where('userId','==','userA')` query afterward returns an EMPTY snapshot.
    This is the direct regression guard for D-1 (previously, trashed trips were
    silently skipped by the `deleted == false` predicate).
  - Idempotent-rerun test kept, with clarified comment: second call returns 0
    because the documents are gone, not because they were filtered by a `deleted`
    flag.
  - D-08 cross-user isolation test kept unchanged in behaviour/assertions —
    still proves userB's trip survives untouched.
- `backend/functions/test/handlers/delete-account.test.ts`: comment-only fix at
  the top of the file — removed the stale claim that the bulk `DELETE /trips`
  endpoint "remains soft-delete-only." No assertion changed (D-4 preserved).

### Task 3 — Documentation corrected (commits `f4fc46c`, `4abd899`)
- `claude.md` (the file is tracked in git as lowercase `claude.md`, though the
  project convention/path referenced everywhere is `CLAUDE.md` — macOS's
  case-insensitive filesystem resolves both to the same file): rewrote the
  "Soft deletes everywhere — with one deliberate exception" bullet under
  `## Important Notes`. New bullet, retitled "Deletion model — soft for Trash,
  hard for erasure," states plainly: per-trip trash is soft (Trash restore
  depends on it); bulk delete-all-data (`DELETE /trips`) is now HARD; full
  account deletion (`DELETE /account`) is HARD. No more "one deliberate
  exception" framing — both bulk flows are equally deliberate hard-delete
  paths now.
  - **Process note**: my first attempt to commit this edit (`f4fc46c`) silently
    did not include it, because I staged the file via the path `CLAUDE.md` and
    git's index tracks it as `claude.md` — on macOS's case-insensitive
    filesystem `git add CLAUDE.md` resolved to the same file on disk but did
    not get recognized as staging the tracked `claude.md` path, so the working
    tree still showed it as modified after the commit. Caught this during
    final verification (`git status --short` still showed `M claude.md` after
    the "completed" infra commit) and made a follow-up commit (`4abd899`) to
    close the gap. Both commits are real and the final state is correct —
    flagging this so it isn't missed in review.
- `landing/src/pages/Privacy.jsx`: rewrote the `<Strong>Delete all data</Strong>`
  bullet in the `id="delete-account"` section. Removed the sentence claiming
  backend records are "retained" and that erasing them requires deleting the
  account. New copy states the action removes every trip from the device AND
  erases those trips from the backend, including trips still in Trash, while
  the account itself is kept — and that this cannot be undone. The
  `<Strong>Delete account</Strong>` bullet, the email-request paragraph, and
  `LAST_UPDATED` (`'August 2, 2026'`, already today's date) were left
  unchanged as instructed.
- `lib/config/constants.dart`: **verified, not edited.** Re-read
  `kDeleteAllDataDialogBody` and its surrounding dartdoc/section comment
  (~lines 2066–2090). The existing copy — "This permanently deletes every trip
  on this device, and in the cloud if you're signed in. Your account stays
  signed in — this cannot be undone." — is now accurate given the backend
  change, and nothing adjacent claims the server retains data. No edit made,
  per the plan's verify-only instruction.

## Dead Code Removal Evidence (D-2)

```
$ grep -rn "softDeleteAllTripsForUser" --include="*.ts" backend/ | grep -v node_modules
(no output — zero hits)
```
Confirmed zero references anywhere in `backend/functions` (source, tests, or
JSDoc `@link`s) after Task 1/2.

## Out-of-scope observation (not edited)

`landing/src/pages/Privacy.jsx`'s separate "Data retention and your choices"
section (lines ~150-159, describing single-trip Trash) still says: "The
underlying backup record is retained on our backend rather than immediately
erased; to have it and all associated cloud data permanently removed, delete
your account as described below." This sentence remains literally true (it
doesn't claim exclusivity), but after this fix, "Delete all data" would *also*
permanently remove a trashed trip's backend record, which this paragraph
doesn't mention as an alternative path. The plan's Task 3 scope explicitly
authorized only the "Delete all data" bullet inside the `id="delete-account"`
section — this paragraph is outside that scope, so it was left as-is.
Flagging for a future pass if it's worth broadening the "delete your account"
callout to also mention "delete all data."

## Verification Actually Observed

```
cd backend/functions && npm run build
> tsc
(exit 0, no output — compiles clean)

cd backend/functions && npm test
> firebase --project travey-298a7 --config ../firebase.json emulators:exec --only auth,firestore "jest --runInBand"
Test Suites: 11 passed, 11 total
Tests:       116 passed, 116 total
Time:        5.495 s
✔ Script exited successfully (code 0)

cd landing && npm run build
[vite-react-ssg] Build finished.
(dist/privacy.html rendered, exit 0)
```

The Firebase emulator (Java 26, firebase-tools) started and ran successfully
in this environment — all 116 backend tests (11 suites) pass, including the
new mixed live+Trash regression test and the retained D-08 cross-user
isolation test. `flutter analyze` / `flutter test` were NOT run — `lib/config/constants.dart`
was verified-accurate and not edited, matching the plan's condition for
skipping them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - blocking cleanup] Removed now-unused `FieldValue` import in `bulk-delete.ts`**
- Found during: Task 1
- Issue: after deleting `softDeleteAllTripsForUser` (the only user of
  `FieldValue.serverTimestamp()` in that file), the import would have been
  dead/unused, which `tsc --strict`/lint conventions in this repo don't allow.
- Fix: removed `FieldValue` from the `firebase-admin/firestore` import.
- Files: `backend/functions/src/utils/bulk-delete.ts`
- Commit: `e154ac7`

**2. [Process correction] `claude.md` case-sensitivity commit gap, self-caught and fixed**
- Found during: post-Task-3 verification (`git status --short`)
- Issue: see the Task 3 process note above — the CLAUDE.md edit didn't land in
  the first infra commit due to a macOS case-insensitive-filesystem / git
  case-sensitive-index mismatch.
- Fix: follow-up commit `4abd899` staged and committed the actual tracked
  `claude.md` path.
- Files: `claude.md`
- Commit: `4abd899`

No other deviations. Plan executed as written otherwise.

## DEPLOYMENT GAP — REQUIRED FOLLOW-UP (open action, not done by this task)

**This change is NOT live in production.** `DELETE /trips` is already deployed
to **traevy-prod** and is currently serving the OLD soft-delete behaviour to
real users. Until a human deploys this change, the in-app "Delete all data"
confirm dialog's promise — "This permanently deletes every trip on this
device, and in the cloud if you're signed in" — remains **FALSE** in
production. This is the compliance-relevant half of the fix and this task
cannot complete it; it requires a human-run deploy.

Required action:
```bash
cd backend && firebase deploy --only functions
```
Confirm the active Firebase project is `traevy-prod` before running this.

## Self-Check: PASSED

All 8 modified files confirmed present on disk. All 3 commit hashes
(`e154ac7`, `f4fc46c`, `4abd899`) confirmed present in `git log`. `npm run
build` (backend) exit 0. `npm test` (backend, via Firebase emulator) 116/116
passed. `npm run build` (landing) exit 0. Dead-code grep for
`softDeleteAllTripsForUser` returns zero hits in `backend/`.
