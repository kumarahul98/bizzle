---
phase: quick-260802-itr
plan: 01
type: execute
wave: 1
depends_on: []
autonomous: false
files_modified:
  - android/app/src/main/AndroidManifest.xml
  - lib/features/tracking/services/tracking_permission_service.dart
  - lib/features/tracking/services/tracking_service_controller.dart
  - lib/config/constants.dart
  - test/unit/features/tracking/tracking_permission_service_test.dart
  - test/unit/android_manifest_permissions_test.dart
  - test/widget/features/dashboard/dashboard_screen_test.dart
requirements: [D-1, D-2, D-3]
user_setup: []

must_haves:
  truths:
    - "The app's Android manifest declares no ACCESS_BACKGROUND_LOCATION permission, so no Play background-location declaration or demo video is required."
    - "Neither preflight() nor currentStatus() probes or requests Permission.locationAlways in any reachable state, on either platform."
    - "A failing test fires if Permission.locationAlways is ever reintroduced into the permission dance."
    - "A failing test fires if ACCESS_BACKGROUND_LOCATION is ever reintroduced into the source manifest."
    - "Tracking still starts, records, and stops with only ACCESS_FINE_LOCATION granted while-in-use, via the location-typed foreground service."
    - "flutter analyze reports 0 errors and 0 warnings; flutter test is fully green."
  artifacts:
    - path: "android/app/src/main/AndroidManifest.xml"
      provides: "Permission set with ACCESS_BACKGROUND_LOCATION removed and its comment gone"
      contains: "FOREGROUND_SERVICE_LOCATION"
    - path: "lib/features/tracking/services/tracking_permission_service.dart"
      provides: "Two-step locationWhenInUse -> notification dance, four-variant status enum, accurate contract dartdoc"
    - path: "test/unit/features/tracking/tracking_permission_service_test.dart"
      provides: "Re-pointed dance tests plus the locationAlways-never-touched regression guard"
    - path: "test/unit/android_manifest_permissions_test.dart"
      provides: "Source-manifest guard: background permission absent, enabling permissions present"
  key_links:
    - from: "lib/features/shell/main_shell.dart"
      to: "TrackingPermissionService.preflight()"
      via: "_handleStart branching on denied / permanentlyDenied / notificationDenied"
      pattern: "TrackingPermissionStatus\\.(denied|permanentlyDenied|notificationDenied)"
    - from: "android/app/src/main/AndroidManifest.xml"
      to: "id.flutter.flutter_background_service.BackgroundService"
      via: "foregroundServiceType=\"location\" + FOREGROUND_SERVICE_LOCATION"
      pattern: "foregroundServiceType=\"location\""
---

<objective>
Drop `android.permission.ACCESS_BACKGROUND_LOCATION` from the app and stop
requesting `Permission.locationAlways`, relying entirely on the already-declared
`foregroundServiceType="location"` service for background GPS.

Purpose: Google Play requires a separate, strictly-reviewed declaration (with a
mandatory demo video) for background location, and it is one of the most common
first-submission rejection causes. The app never needs the permission: tracking
is always user-initiated from the foreground, and a location-typed foreground
service started while the app is visible keeps receiving updates on Android 10+
with only `ACCESS_FINE_LOCATION` granted as "while using the app".

Output: One manifest permission removed, a two-step permission dance replacing
the four-step one, a four-variant status enum, corrected documentation across
three files, re-pointed unit tests, and two new regression guards.
</objective>

<execution_context>
@/Users/coolman/Documents/Projects/bizzle/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md

@android/app/src/main/AndroidManifest.xml
@lib/features/tracking/services/tracking_permission_service.dart
@test/unit/features/tracking/tracking_permission_service_test.dart
@test/widget/features/dashboard/dashboard_screen_test.dart

<verified_facts>
These were verified during planning. Do NOT re-derive them; they are inputs.

1. The manifest already has everything the foreground-service approach needs:
   `foregroundServiceType="location"` on the flutter_background_service
   declaration (line 35), `FOREGROUND_SERVICE_LOCATION` (line 69),
   `FOREGROUND_SERVICE` (line 66), `ACCESS_FINE_LOCATION` (line 61).
   `ACCESS_BACKGROUND_LOCATION` is line 64 with an explanatory comment on
   line 63. That comment + permission are the entire manifest diff.

2. `ACCESS_BACKGROUND_LOCATION` appears in EXACTLY ONE place in the whole
   repo (the app manifest). No build.gradle, no RELEASE-GATES.md, no iOS file
   references it.

3. `TrackingPermissionStatus.foregroundOnly` has NO production consumer.
   `main_shell.dart:218-237` branches only on `denied`, `permanentlyDenied`
   and `notificationDenied`; `fullyGranted` and `foregroundOnly` both fall
   through to `start()`. The only other lib/ reference is a dartdoc on
   `kIosPermissionBannerBody` (constants.dart:1099), and that constant is
   itself unused in lib/ (parked Phase 15 iOS work).

4. That constants.dart reference is a BACKTICKED code span
   (`` `TrackingPermissionStatus.foregroundOnly` ``), not a `[bracketed]`
   doc reference, so removing the variant will NOT trip `comment_references`.
   It still becomes factually wrong and must be reworded.

5. `test/widget/features/settings/location_picker_screen_test.dart` only
   exercises `requestWhenInUse()` and its fake THROWS on any permission other
   than `locationWhenInUse` (lines 416-435). It is unaffected — verify and
   leave alone.

6. `test/widget/features/dashboard/dashboard_screen_test.dart:65-108` has an
   EXHAUSTIVE switch over `TrackingPermissionStatus`. Removing a variant is a
   compile break there. It seeds `Permission.locationAlways` in three probe
   maps (lines 75, 82, 101) and has a `foregroundOnly` case (line 79).

7. `test/unit/` already contains a root-level test file
   (`app_bootstrap_test.dart`), so a new root-level file there is conventional.
   `flutter test` runs with CWD at the package root.
</verified_facts>

<decisions_made_during_planning>
These are decided. Implement them; do not relitigate.

**DEC-A — DELETE `TrackingPermissionStatus.foregroundOnly`.**
Once `locationAlways` is never probed, the variant is unreachable on BOTH
platforms (the iOS branch is the only other producer and it loses its
background input too, per D-2 which is unconditional). CLAUDE.md forbids dead
code and speculative abstractions; an unreachable enum variant that every
`switch` must still handle is the worst of both. The parked-iOS-work argument
does not save it: the one artifact that anticipates it
(`kIosPermissionBannerBody`) is itself unused, and when iOS resumes it will
need a fresh decision about background location anyway (see DEC-C). Deleting
now is reversible in one line; leaving a permanently-false variant in a
five-way enum is not free.

**DEC-B — KEEP the name `fullyGranted`.**
Post-change it means "every permission this app requires is granted", which is
exactly what the enum needs to express and what it now honestly is. It reads
correctly against the three remaining denial variants. Renaming would churn
~15 call sites across two test files for no semantic gain and would obscure
the real diff in review. Its DARTDOC must still be rewritten — the current one
claims background location, which becomes false.

**DEC-C — iOS semantics change as a side effect, and that is accepted.**
D-2 is unconditional, so the iOS branch of `preflight()`/`currentStatus()`
collapses from `backgroundGranted ? fullyGranted : foregroundOnly` to just
`fullyGranted` after `locationWhenInUse` resolves. iOS is a PAUSED platform
(v0.2) and out of scope per D-3. Do NOT touch `ios/Runner/Info.plist`
(`NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes`) or
`ios/Podfile`. Leave a `TODO(v0.2-resume)`-style note in the iOS branch's
comment and in the iOS test group stating that iOS background-location
strategy must be re-decided when the platform resumes — iOS has no Android
foreground-service equivalent, so the reasoning that justifies this change
does NOT transfer.

**DEC-D — The ordering invariant becomes structural, not asserted.**
The existing `assert(fineGranted, 'locationAlways must never be touched ...')`
guards a step that no longer exists. Do not rewrite it to guard the
notification step — restructure `preflight()` so every non-granted location
path returns early, making "notification is never touched before location
resolves granted" true by control flow with no local flag and no assert.
Document that in the dartdoc.
</decisions_made_during_planning>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Remove the permission and rewrite the permission contract</name>
  <files>
    android/app/src/main/AndroidManifest.xml
    lib/features/tracking/services/tracking_permission_service.dart
    lib/features/tracking/services/tracking_service_controller.dart
    lib/config/constants.dart
  </files>
  <action>
**1. AndroidManifest.xml (D-1).** Delete line 64
(`ACCESS_BACKGROUND_LOCATION`) AND its explanatory comment on line 63
("Background location for Android 10+, requested as step 2 per D-07") — no
comment may survive describing a permission that is gone. Touch NOTHING else:
`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `WAKE_LOCK`, `INTERNET`,
`USE_EXACT_ALARM` and the `foregroundServiceType="location"` service block all
stay exactly as they are — they are what makes this work. Add one short comment
above `FOREGROUND_SERVICE_LOCATION` recording WHY there is no background
permission: tracking is always user-initiated from the foreground and runs
inside a location-typed foreground service, so `ACCESS_FINE_LOCATION`
(while-in-use) is sufficient on Android 10+; deliberately omitted to avoid the
Play background-location declaration.

**2. tracking_permission_service.dart (D-2) — the substantive work.**

  a. Delete the `foregroundOnly` variant from `TrackingPermissionStatus`
     (DEC-A). Rewrite the enum's own dartdoc: it currently says "Five-way
     classification" and "The four original variants" and cites D-08's
     background-denied banner. It is now a FOUR-way classification of a
     location-when-in-use + notification state. Remove the D-08 background
     banner framing.

  b. Rewrite `fullyGranted`'s dartdoc (DEC-B, keep the name): it now means
     "`locationWhenInUse` granted AND `notification` granted" — it must no
     longer claim or imply background location.

  c. `preflight()`: delete the `locationAlways` probe/request (current lines
     264-269), the `backgroundGranted` local, and the `assert` at 259-263.
     Restructure per DEC-D so every non-granted location path returns early:
     probe `locationWhenInUse`; return `permanentlyDenied` if permanently
     denied; if not granted, request it and return `permanentlyDenied` /
     `denied` as appropriate; past that point fine location IS granted by
     control flow. Then the iOS branch returns `fullyGranted` (DEC-C, with the
     v0.2-resume note). Then probe/request `notification`, returning
     `notificationDenied` if it stays denied, else `fullyGranted`.

  d. `currentStatus()`: delete the `locationAlways` probe (line 344) and the
     `locationStatus` ternary. Probe-only behaviour is unchanged — it must
     still NEVER call the requester. New shape: `locationWhenInUse` probe ->
     `permanentlyDenied` / `denied` early returns -> iOS returns `fullyGranted`
     -> `notification` probe -> `notificationDenied` or `fullyGranted`.

  e. Rewrite the CLASS dartdoc (lines 144-186). The "strict four-step
     permission dance" is now a TWO-step dance
     (`locationWhenInUse` -> `notification`). Delete ordering invariant 1
     (locationAlways after locationWhenInUse) entirely. Renumber: invariant 1
     is now "`notification` is NEVER probed or requested until
     `locationWhenInUse` has resolved granted" — and note it is enforced by
     control flow (early returns), not by an assert. Invariant 2 is the
     existing `requestWhenInUse` invariant, extended: it must never grow a
     background or notification step. Add an explicit statement that
     `Permission.locationAlways` is NEVER touched by this class, and why (Play
     background-location declaration avoided; the location-typed foreground
     service covers the real need). Update the `preflight` bullet's step list.

  f. Rewrite `preflight()`'s own dartdoc (lines 213-240) to describe two steps,
     and drop every "WITHOUT touching `locationAlways`" clause in favour of
     "WITHOUT touching `notification`".

  g. Rewrite `LocationWhenInUseStatus`'s dartdoc (lines 74-84): it currently
     justifies itself by saying `fullyGranted` means "`locationAlways` AND
     `notification` are also granted" and names `foregroundOnly`. Both become
     false. Keep the enum and its rationale (a when-in-use-only caller must not
     be handed the tracking enum) but restate it against the new contract.

  h. Fix `requestWhenInUse()`'s dartdoc (line 302) which says it never touches
     "`locationAlways` or `notification`" — keep the guarantee (it is still
     true and still worth stating) but reword so it does not imply some OTHER
     method does touch `locationAlways`.

**3. tracking_service_controller.dart:95.** The doc comment says tracking
"ideally" wants `locationAlways` and falls back to a D-08 banner. Both false.
Replace that bullet with the accurate precondition: `locationWhenInUse`
granted is sufficient because tracking always runs inside the location-typed
foreground service, which is started while the app is in the foreground.

**4. constants.dart:1098-1105.** Do NOT delete `kIosPermissionBannerBody`
(parked iOS copy). Fix its dartdoc so it no longer references the removed
`foregroundOnly` variant — restate it as parked Phase 15 iOS copy for a
When-In-Use degraded state that the CURRENT Android-only status enum no longer
models, and note it is unused in lib/ pending the v0.2 iOS resume.

Do not touch the tracking service, the accumulator, `flutter_background_service`
wiring, or the notification service. Do not touch any iOS file.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle &amp;&amp; grep -c ACCESS_BACKGROUND_LOCATION android/app/src/main/AndroidManifest.xml; grep -rn "locationAlways\|foregroundOnly" lib/features/tracking/services/tracking_permission_service.dart lib/features/tracking/services/tracking_service_controller.dart lib/config/constants.dart</automated>
  </verify>
  <done>
`grep -c` on the manifest returns 0. The grep over the three lib files returns
NO matches (exit 1). `grep -n 'foregroundServiceType="location"'` and
`grep -n FOREGROUND_SERVICE_LOCATION` on the manifest both still match. The
tree does not yet compile (tests still reference the removed variant) — that is
expected and closed by Task 2.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Re-point the tests and add both regression guards</name>
  <files>
    test/unit/features/tracking/tracking_permission_service_test.dart
    test/unit/android_manifest_permissions_test.dart
    test/widget/features/dashboard/dashboard_screen_test.dart
  </files>
  <behavior>
The new regression guard is the single most important artifact of this whole
change. Write it FIRST, before re-pointing anything else — it should fail
loudly against any tree where `locationAlways` creeps back.

  - Guard 1 (`preflight()` and `currentStatus()`, every reachable outcome,
    both platforms): `Permission.locationAlways` appears in NEITHER
    `probeCalls` NOR `requestCalls`.
  - Guard 2 (source manifest): `ACCESS_BACKGROUND_LOCATION` is absent, while
    `ACCESS_FINE_LOCATION`, `FOREGROUND_SERVICE_LOCATION` and
    `foregroundServiceType="location"` are all present.
  </behavior>
  <action>
**1. `dashboard_screen_test.dart` first — it is the compile break.** In
`_buildFakePermissionService` (lines 65-108): delete the
`case TrackingPermissionStatus.foregroundOnly:` arm entirely, and remove the
`Permission.locationAlways` entries from the `fullyGranted` (line 75) and
`notificationDenied` (line 101) probe maps. Leaving them seeded would be
actively harmful: the map throws `StateError` on any unseeded permission, and
that throw is what makes a stray `locationAlways` call fail loudly. Check
whether any test body elsewhere in the file passes `foregroundOnly`; the
planning grep found only line 79, but confirm and fix if more appear.

**2. NEW regression guard in `tracking_permission_service_test.dart`.** Add a
group named for what it protects, e.g.
`'ACCESS_BACKGROUND_LOCATION regression guard (Permission.locationAlways is
never touched)'`, with a header comment stating that a failure here means the
Play background-location declaration requirement has silently returned. Reuse
the existing `_CallLog` + `_staticProbe` / `_staticRequester` helpers — do not
write new fakes. Drive EVERY reachable outcome and, for each, assert
`log.probeCalls` and `log.requestCalls` both exclude `Permission.locationAlways`:

  - fine permanently denied on probe
  - fine denied on probe, denied on request
  - fine denied on probe, permanently denied on request
  - fine denied on probe, granted on request, notification granted
  - fine granted, notification denied on probe and on request
  - fine granted, notification granted
  - the same sweep for `currentStatus()`
  - at least one case under `debugDefaultTargetPlatformOverride =
    TargetPlatform.iOS` (with `tearDown(() => debugDefaultTargetPlatformOverride
    = null)`), since the iOS branch was the other `locationAlways` consumer

Deliberately do NOT seed `Permission.locationAlways` in any probe/request map,
so a stray call ALSO throws `StateError` — belt and braces.

**3. Re-point the existing tests — do not delete coverage wholesale.**

  preflight group:
   - "returns fullyGranted when all three permissions are already granted" ->
     two permissions; drop `locationAlways` from the probe map; keep the
     `requestCalls, isEmpty` and probe-order assertions.
   - "returns foregroundOnly when fine is already granted, background denied
     at request..." -> its only unique coverage (fine already granted, never
     re-requested) is already covered by the test above. DELETE it.
   - "returns foregroundOnly when fine is denied then granted on request..." ->
     unique coverage is "fine denied on probe, granted on request". KEEP that,
     re-pointed: expect `fullyGranted`, and assert
     `requestCalls == [Permission.locationWhenInUse]`. Drop the
     `whenInUseIdx < alwaysIdx` ordering assertion.
   - "returns denied when fine is denied and request also returns denied" ->
     KEEP as-is including its `locationAlways`-never-touched assertions; they
     now assert the new invariant. Update the stale "Pitfall 5" comments.
   - "returns permanentlyDenied when fine is already permanently denied" ->
     KEEP; ADD `locationAlways`-never-touched assertions to match its sibling.
   - "returns permanentlyDenied when fine request resolves permanentlyDenied"
     -> KEEP as-is; refresh comments.
   - "NEVER calls Permission.locationAlways.request() before
     Permission.locationWhenInUse.request()" -> this asserts an ordering that
     no longer exists. DELETE it; the new guard group supersedes it and is
     strictly stronger.
   - the two `notificationDenied` tests -> drop `locationAlways` from their
     maps; the second one's `alwaysIdx < notifIdx` ordering assertion is gone,
     so fold its remaining value into the first and delete the duplicate.
   - the two trailing `fullyGranted` notification tests -> drop
     `locationAlways` from their maps, keep everything else.

  currentStatus group:
   - drop `locationAlways` from every map.
   - "returns foregroundOnly when fine granted, background denied..." ->
     collapses into the first test. DELETE.
   - the two `notificationDenied` tests likewise collapse into one; keep one.

  iOS groups:
   - "returns fullyGranted on iOS when locationAlways is granted" -> re-point:
     `fullyGranted` on iOS after `locationWhenInUse` alone, asserting NEITHER
     `locationAlways` NOR `notification` is probed or requested.
   - "returns foregroundOnly on iOS when only When-In-Use is granted (D-03)"
     -> that state no longer exists. Re-point to `fullyGranted` and add a
     comment: iOS background-location strategy is deferred to the v0.2 resume
     (DEC-C) — iOS has no foreground-service equivalent, so this change's
     reasoning does not transfer.
   - "never returns notificationDenied on iOS" (both `preflight` and
     `currentStatus` variants) -> KEEP, drop `locationAlways` from the maps.

  Update the file-header `_CallLog` dartdoc (lines 6-11): it describes the
  four-step ordering. Rewrite for the two-step contract.

**4. NEW `test/unit/android_manifest_permissions_test.dart` (guard 2).** A
plain `flutter_test` file using `dart:io`:

  - Resolve `File('android/app/src/main/AndroidManifest.xml')` and assert
    `existsSync()` FIRST with a reason naming the CWD assumption (`flutter test`
    runs from the package root) — so a CWD surprise is a loud failure, never a
    vacuous pass.
  - Assert the file does NOT contain `ACCESS_BACKGROUND_LOCATION`, with a
    reason explaining the Play declaration consequence.
  - Assert it DOES contain `ACCESS_FINE_LOCATION`,
    `FOREGROUND_SERVICE_LOCATION`, and `foregroundServiceType="location"`.
    These positive controls are load-bearing: without them, deleting the whole
    permissions block would make the negative assertion pass vacuously.
  - Document the LIMIT in a header comment: this checks the SOURCE manifest
    only. A Flutter plugin can still reintroduce the permission via manifest
    merging, which only shows up in a built artifact — that check is manual and
    lives in Task 3's checklist.

Then run, from `/Users/coolman/bizzle`: `dart format .`, `flutter analyze`,
`flutter test`.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle &amp;&amp; dart format . &amp;&amp; flutter analyze 2>&amp;1 | tail -5 &amp;&amp; flutter test 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
`flutter analyze` reports 0 errors and 0 warnings (info-level count may drift
below the 292 baseline as removed code takes its lints with it — that is not a
regression; NEW errors or warnings are). `flutter test` is fully green with no
skips. `grep -rn "locationAlways\|foregroundOnly" lib test` returns matches
ONLY inside the new regression-guard group and its explanatory comments (plus
`ios/Podfile`, which is untouched).

Adversarial check before finishing: temporarily re-add the
`locationAlways` probe to `preflight()` and confirm the new guard group FAILS;
temporarily re-add the manifest line and confirm
`android_manifest_permissions_test.dart` FAILS. Revert both. A guard that has
never been seen red is not a guard.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: Real-device background recording verification (BLOCKING)</name>
  <what-built>
`ACCESS_BACKGROUND_LOCATION` is gone from the manifest and
`Permission.locationAlways` is gone from the permission dance. Background GPS
now depends ENTIRELY on the location-typed foreground service. Two automated
guards were added (locationAlways never touched; source manifest clean), plus
the full suite is green.
  </what-built>
  <how-to-verify>
**READ THIS FIRST — the residual risk.**

This change removes the app's second line of defence for background location.
If the foreground service fails to keep receiving GPS on a given device or OEM
skin, the app's CORE FEATURE silently breaks: the user taps Start, locks the
screen, drives, and gets a trip with a truncated route and a frozen elapsed
time. It fails QUIETLY — no crash, no error, no exception. **No test in this
repository can catch it.** `flutter analyze` and `flutter test` being green
proves nothing about this. CLAUDE.md forbids trusting the emulator for GPS.
This checkpoint is the ONLY verification that exists.

Build and install a release-mode (or at minimum profile-mode) build on a REAL
Android device, then run the checklist below. Grant location as
**"While using the app"** — NOT "Allow all the time". If the OS no longer even
offers "Allow all the time", that is the change working.

  1. Fresh-install the build. Confirm the permission prompt asks for location
     while-in-use and notifications, and NEVER shows a background/"all the
     time" prompt.
  2. Tap Start. Confirm the persistent recording notification appears.
  3. LOCK THE SCREEN and leave it locked for at least 5 minutes while moving
     (walk or drive — a stationary trip is discarded by the 100 m floor and
     tells you nothing).
  4. Wake the device, return to the app. Confirm the LIVE elapsed time and the
     LIVE distance both advanced across the locked period with NO gap and no
     reset to zero.
  5. With recording still active, switch to another app (browser, maps) for
     2-3 minutes, then return. Confirm elapsed and distance again advanced
     continuously.
  6. Tap Stop. Open the trip detail. Confirm the route polyline is CONTINUOUS
     across both the screen-locked and app-switched periods — a straight-line
     jump between two points is a FAILURE, not a rendering artifact.
  7. Repeat step 3 once more with battery optimisation left at the device
     default (do not whitelist the app) — that is what a real user gets.
  8. Merged-manifest check (catches plugin manifest merging, which the
     automated guard cannot): after `flutter build apk --release`, inspect
     `android/app/build/intermediates/merged_manifests/release/AndroidManifest.xml`
     for `ACCESS_BACKGROUND_LOCATION`, or run
     `aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk`.
     Either must show NO background-location permission. If one appears, a
     dependency is injecting it and needs a `tools:node="remove"` override —
     report back rather than shipping.

If ANY of steps 4, 6 or 8 fails, STOP. Do not ship. Report which step and what
you observed — the change may need to be reverted or the service reconfigured.
  </how-to-verify>
  <resume-signal>Reply "verified" with the device model and Android version, or describe exactly which step failed and what you saw.</resume-signal>
</task>

</tasks>

<risk_register>
| ID | Risk | Severity | Disposition | Mitigation |
|----|------|----------|-------------|------------|
| R-01 | Foreground service fails to sustain GPS on some device/OEM; background recording silently truncates. **No automated test can detect this.** | HIGH | mitigate | Task 3 blocking real-device checklist (screen lock + app switch + continuous polyline + default battery optimisation). Ship only on a pass. |
| R-02 | A Flutter plugin reintroduces `ACCESS_BACKGROUND_LOCATION` via manifest merging, silently restoring the Play declaration requirement. | MEDIUM | mitigate | Source-manifest guard test (automated, partial) + Task 3 step 8 merged-manifest/aapt2 inspection (manual, complete). Remedy if hit: `tools:node="remove"` override. |
| R-03 | `Permission.locationAlways` creeps back into the dance in a future change. | MEDIUM | mitigate | New regression-guard test group asserting it is never probed or requested across every reachable outcome on both platforms; adversarially verified red before being accepted. |
| R-04 | iOS silently inherits Android-shaped reasoning that does not apply (no foreground-service equivalent). | LOW (paused platform) | accept | D-3 keeps iOS files untouched; DEC-C notes are left in the iOS code branch and the iOS test group requiring a fresh decision at v0.2 resume. |
| R-05 | Removing the enum variant breaks an unnoticed exhaustive `switch`. | LOW | mitigate | Dart exhaustiveness makes this a compile error, not a runtime bug; the one known site (`dashboard_screen_test.dart`) is handled in Task 2 step 1, and `flutter analyze` catches any other. |
</risk_register>

<verification>
From `/Users/coolman/bizzle`:

1. `dart format .` — clean.
2. `flutter analyze` — **0 errors, 0 warnings**. Info-level issues may fall
   below the 292 baseline as removed code takes its lints with it; that is
   expected. New errors or warnings are regressions.
3. `flutter test` — fully green, no skips.
4. `grep -c ACCESS_BACKGROUND_LOCATION android/app/src/main/AndroidManifest.xml`
   returns 0.
5. `grep -rn "foregroundOnly" lib` returns nothing.
6. `grep -rn "locationAlways" lib` returns nothing.
7. `test/widget/features/settings/location_picker_screen_test.dart` is
   UNMODIFIED (quick task 260802-dgp's `requestWhenInUse()` work is untouched).
8. Task 3 checkpoint passed on a real device.
</verification>

<success_criteria>
- `ACCESS_BACKGROUND_LOCATION` and its comment are gone from the manifest; every
  other permission and the `foregroundServiceType="location"` service block are
  byte-identical.
- `Permission.locationAlways` is referenced nowhere in `lib/`.
- `TrackingPermissionStatus` has four variants; `fullyGranted` keeps its name
  with a dartdoc that no longer claims background location.
- The class dartdoc describes a two-step dance with accurate invariants — no
  surviving prose describes the four-step dance.
- The `locationAlways`-never-touched guard and the manifest guard both exist and
  have each been observed failing against a deliberately broken tree.
- `flutter analyze` 0 errors / 0 warnings; `flutter test` green.
- Real-device background recording verified per Task 3.
</success_criteria>

<commit>
Tasks 1 and 2 land as a SINGLE commit — the tree does not compile between them
(removing the enum variant breaks `dashboard_screen_test.dart`), so splitting
would commit a broken tree. It is also one concern.

CLAUDE.md bracket convention, NOT conventional commits:

```
[tracking] Drop ACCESS_BACKGROUND_LOCATION; rely on the location foreground service
```

Body should record: why (Play background-location declaration + demo video
avoided), what makes it safe (user-initiated tracking inside a location-typed
foreground service; `ACCESS_FINE_LOCATION` while-in-use suffices on Android
10+), the `foregroundOnly` removal and its justification, that iOS was
deliberately untouched and must be revisited at v0.2 resume, and that background
recording now has NO automated safety net — device verification is mandatory.
</commit>

<output>
After completion, create
`.planning/quick/260802-itr-drop-access-background-location-and-rely/260802-itr-SUMMARY.md`
recording: the final enum shape, the DEC-A/DEC-B decisions as shipped, the exact
test count delta, the adversarial red-check results for both guards, and the
Task 3 device-verification outcome (device model + Android version, or the
failing step).
</output>
</content>
</invoke>
