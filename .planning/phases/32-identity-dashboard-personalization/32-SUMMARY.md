---
phase: 32-identity-dashboard-personalization
completed: 2026-07-22
status: code_complete_device_unverified
mode: manual-gsd
requirements: [UX-10]
branch: main
commits:
  - 905da16 (32-01 identity + account sheet)
  - 61e32e7 (32-02 weekly summary explainer)
result: >
  Both plans built, tested, and committed to main. Flutter 836 tests green
  (was 804), analyze 0 errors / 0 warnings / 283 info (baseline unchanged).
  Not pushed, not merged elsewhere. Two manual UAT items from the plan
  (sign out/in round trip, restore from its new home) are device-unverified.
---

# Phase 32 — Identity & Dashboard Personalization — SUMMARY

## What shipped

| Plan | Commit | Content |
|---|---|---|
| 32-01 | `905da16` | `home_header.dart` wired to `authStateProvider`; new `account_sheet.dart`; `_AccountSection` deleted from `settings_screen.dart`; 25 tests |
| 32-02 | `61e32e7` | `InfoIconButton` on the "This week" card + explainer copy; 7 tests |

**Verification:** `flutter analyze` 0 errors / 0 warnings / **283 info**
(identical to the pre-phase baseline — none added, none fixed) ·
`dart format lib test` clean · `flutter test` **836 passed, 10 skipped**
(was 804 / 10).

## Success criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Signed-in user sees "Hi, {first name}" + their initial | ✅ unit + widget tests |
| 2 | Guest / no-display-name / whitespace-only sees "Hi, Traveller" + "T", no blank, no crash | ✅ unit + widget tests, all six edge cases |
| 3 | Avatar opens the account sheet; contents match pre-phase Settings, both states | ✅ widget tests, incl. the migrated Phase 9/11 row coverage |
| 4 | Settings has no Account section, no second sign-out or restore | ✅ negative widget tests, guest **and** signed-in |
| 5 | Sign in/out while the dashboard is visible updates greeting + avatar | ✅ widget test flips a live notifier both directions; ⚠️ against a *fake* notifier, not real Firebase |
| 6 | Info icon explains the Mon–Sun window, what "lost" measures, breaks excluded | ✅ widget + copy tests |
| 7 | Touch target ≥ 48×48, painted size unchanged | ✅ widget test measures both |

SC#5 deserves the asterisk. The test proves the widget rebuilds on an
`AuthState` transition, which is the mechanism T-32-04 cares about. It does
not prove `FirebaseAuth.authStateChanges()` fires on a real sign-out — that is
the plan's own manual UAT item and it has not been run on a device.

## Decisions as-built

D-01 through D-03 held. Four things were sharper in code than on paper:

**The plan's threat model contains a factual error.** T-32-02 says "Sign out
keeps its existing confirmation and `dangerous: true` styling." There is no
existing confirmation. `_AccountSection` wired the row straight to
`unawaited(ref.read(authServiceProvider).signOut())` with `dangerous: true` as
the only guard. Behaviour was carried across unchanged rather than a
confirmation being invented, because this phase's mandate is to *move* the
controls, not redesign them. The mitigation column of T-32-02 is therefore
half-true: the styling is real, the confirmation is not. If a confirmation is
wanted it needs its own decision — note that the accompanying argument still
holds (local Drift data survives sign-out, so an accidental one is not data
loss).

**The signed-in sheet does not fit in a default bottom sheet.** Four rows
overflowed by 8.5px at the 800×600 test viewport, which the plan did not
anticipate — it treats the sheet as a drop-in for a Settings section, and a
Settings section lives in a scroll view that hides the problem. The sheet is
now `isScrollControlled` with a `SingleChildScrollView` body. Worth knowing
because it is the *signed-in* path that overflows; a guest-only smoke test
would have passed and shipped the bug.

**The avatar became an `IconButton`, not an `InkWell`.** D-02 says "wrap the
avatar in an `InkWell`". A bare `InkWell` gives no semantics label, and a
screen reader announcing an account button as the single letter "A" is not
usable. `IconButton` is what `GuestConnectionIndicator` and `InfoIconButton`
already use for exactly this, and it enforces the interactive minimum itself.
Same visual, same tap behaviour, correct accessibility — a deviation in
letter, not in intent.

**The initial is read through `characters`, not `[0]`.** The plan's D-01
sketch is `name.split(' ').first` plus its first letter. `[0]` on a name
beginning with a non-BMP grapheme yields half a surrogate pair and renders as
a replacement glyph. `characters.first` is the fix and costs nothing; the
existing `AccountRow` call sites still use `[0]` and were left alone (out of
scope, and their input is the full display name, not the derived first word).

## Surprises

**The guest sign-in CTA had to change shape.** In Settings the row called
`showSignInSheet(context)` directly. From inside a bottom sheet that stacks a
second modal on the first. The account sheet now pops with a private enum
result and `showAccountSheet` opens the sign-in sheet in its place — asserted
by a test that checks the account sheet is *gone* once the sign-in sheet is up.

**`Override` is not a public Riverpod 3.2.1 type.** Same family of problem as
the Phase 31 `StreamProviderFamily` gotcha: `List<Override>` as a test helper
return type is an `undefined_class` error, because `override.dart` is a
`part` of `framework.dart` and never exported. Inline the list or pass a
notifier factory instead.

**`find.bySemanticsLabel` needs `tester.ensureSemantics()`** and even then did
not match a `Semantics(label:)` wrapper around an `InkWell`. Moot after the
`IconButton` switch — `find.byTooltip` is the finder that works — but it cost
a cycle.

**Settings shed a lot of test scaffolding.** Deleting `_AccountSection` made
`_FakeAuthService`, `_FakeApiClient`, `_FakeSyncEngine`, `_FakeSyncStatusNotifier`,
`_restoreCompanion` and six imports dead in `settings_screen_test.dart`. They
moved to `account_sheet_test.dart` with the tests that need them rather than
being left behind as unreferenced warnings.

## What is NOT done

**Both manual UAT items from the plan.** Neither has been run:
1. Sign out and back in from the avatar sheet; confirm the greeting changes
   both ways without restarting the app.
2. Confirm restore still works from its new location in the sheet.

Both need a real device with a real Google account — the whole suite runs with
`firebaseReady=false`, so no real `authStateChanges()` emission and no real
restore round trip has been exercised anywhere in this phase.

**No visual check.** The avatar's tap target grew from 36 to 48 logical px
inside a `Row` with a trailing 20px padding, so the painted circle's centre
shifts ~6px left of where it sat. Tests assert both sizes; nobody has looked
at it. Worth a glance next time the app is on a screen.

**`build_runner` was not run.** No annotated code changed — every provider in
this phase is a manual `Provider` / `NotifierProvider` declaration and no
`.g.dart` input was touched — so there was nothing to regenerate. Called out
because the phase brief asked for it unconditionally.

## Follow-ups

1. Run the two manual UAT items on a device (roll into the Phase 23 device queue).
2. Decide whether Sign out should gain a real confirmation — T-32-02 assumes
   one exists, and it does not.
3. Eyeball the avatar's new position on the dashboard.
4. Optional, explicitly deferred by D-03: point the same weekly explainer at
   the identical concept on the stats screen. Left out to keep the file
   surface disjoint from Phase 34.

**Repo note (not caused by this phase):** the working tree moved from
`/Users/coolman/Documents/Projects/bizzle` to `/Users/coolman/bizzle`
mid-session, by something outside this work. History is continuous — the
session-start commit is an ancestor of `HEAD` — and the diff at commit time
contained only this phase's files, but the path change is worth knowing for
anything holding the old absolute path.
