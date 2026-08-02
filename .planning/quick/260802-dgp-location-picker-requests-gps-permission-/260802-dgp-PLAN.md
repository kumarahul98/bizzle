---
phase: quick-260802-dgp
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/tracking/services/tracking_permission_service.dart
  - lib/config/constants.dart
  - lib/features/settings/screens/location_picker_screen.dart
  - test/unit/features/tracking/tracking_permission_service_test.dart
  - test/widget/features/settings/location_picker_screen_test.dart
autonomous: true
requirements: [LOC-01]
must_haves:
  truths:
    - "Opening the Home/Office picker on a fresh install shows the Android location permission dialog"
    - "Granting it centres the map on the user's actual position instead of the Bengaluru default"
    - "Declining it lands the map on the existing fallback (recent trip end, then default constant) with no error UI"
    - "Tapping Locate me when permission was declined shows a SnackBar instead of doing nothing"
    - "Tapping Locate me when permission is permanently denied shows a SnackBar with an Open settings action"
    - "Tapping Locate me when permission is granted but the fix fails shows a SnackBar instead of doing nothing"
    - "Opening the picker for a slot that already has a saved coord does NOT prompt"
    - "Nothing in the picker path ever requests background location or notifications"
  artifacts:
    - path: "lib/features/tracking/services/tracking_permission_service.dart"
      provides: "requestWhenInUse() + LocationWhenInUseStatus 3-way enum"
      contains: "enum LocationWhenInUseStatus"
    - path: "lib/features/settings/screens/location_picker_screen.dart"
      provides: "Prompt-on-open + non-silent Locate me"
      contains: "requestWhenInUse"
    - path: "lib/config/constants.dart"
      provides: "Picker-specific permission feedback copy"
      contains: "kLocationPickerLocation"
    - path: "test/unit/features/tracking/tracking_permission_service_test.dart"
      provides: "requestWhenInUse coverage incl. never-touches-always/notification assertion"
    - path: "test/widget/features/settings/location_picker_screen_test.dart"
      provides: "Prompt-on-open, silent-decline, and Locate-me feedback widget tests"
  key_links:
    - from: "lib/features/settings/screens/location_picker_screen.dart"
      to: "trackingPermissionServiceProvider"
      via: "ref.read(...).requestWhenInUse()"
      pattern: "trackingPermissionServiceProvider"
    - from: "lib/features/settings/screens/location_picker_screen.dart"
      to: "TrackingPermissionService.openSystemSettings"
      via: "SnackBarAction onPressed"
      pattern: "openSystemSettings"
---

<objective>
The location picker never asks for GPS permission, so on a fresh install it opens
on a hardcoded Bengaluru centre and its "Locate me" FAB is a silent no-op.

Fix both: request `locationWhenInUse` (and only that) when the picker opens
without a saved coord, and make the FAB always give feedback — move the map,
or say why it can't.

Purpose: a user setting their Home location gets a map on their actual location,
and the one control that should fix a wrong centre stops being dead.
Output: a narrow `requestWhenInUse()` on the app's single permission service,
a rewired picker, picker-specific copy in constants, and unit + widget coverage.
</objective>

<execution_context>
@/Users/coolman/Documents/Projects/bizzle/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@CLAUDE.md
@lib/features/settings/screens/location_picker_screen.dart
@lib/features/tracking/services/tracking_permission_service.dart
@lib/features/tracking/providers/tracking_providers.dart
@lib/features/shell/main_shell.dart
@test/unit/features/tracking/tracking_permission_service_test.dart
@test/widget/features/settings/location_picker_screen_test.dart

Project skill (binding): `.agents/skills/flutter-coding-guidelines/SKILL.md` —
Riverpod for all state, business logic out of UI files, DI via `ref.read`.

<decisions>
D-1: The picker requests location permission on OPEN. This supersedes the old
     "D-13: do not aggressively prompt" rule FOR THIS SCREEN. Every dartdoc that
     asserts the old never-prompt behaviour must be rewritten, not left standing.
D-2: `locationWhenInUse` ONLY. Do NOT call `preflight()` — it also requests
     `locationAlways` and `notification`, which is exactly the over-prompting the
     old rule guarded against.
D-3: Declining on open is a legitimate answer. Fall back silently through the
     existing chain (recent trip end → default constant). NO error UI on open.
D-4: "Locate me" must never be a silent no-op. Request if needed; move on
     success; SnackBar on denied; SnackBar + "Open settings" on permanently
     denied.
D-5: Permission goes through `TrackingPermissionService` (permission_handler),
     not `geolocator`'s permission API — one permission source of truth.
     `Geolocator.getCurrentPosition()` stays for the position read.
</decisions>

<interfaces>
Existing, in `lib/features/tracking/services/tracking_permission_service.dart`:

```dart
typedef PermissionStatusProbe = Future<PermissionStatus> Function(Permission);
typedef PermissionRequester   = Future<PermissionStatus> Function(Permission);
typedef SettingsOpener        = Future<bool> Function();

class TrackingPermissionService {
  const TrackingPermissionService();
  @visibleForTesting
  TrackingPermissionService.forTesting({
    required PermissionStatusProbe probe,
    required PermissionRequester requester,
    SettingsOpener? opener,
  });
  Future<TrackingPermissionStatus> preflight();     // OUT OF SCOPE — do not touch
  Future<TrackingPermissionStatus> currentStatus(); // OUT OF SCOPE — do not touch
  Future<bool> openSystemSettings();
}
```

Existing provider (`lib/features/tracking/providers/tracking_providers.dart:54`):

```dart
final Provider<TrackingPermissionService> trackingPermissionServiceProvider;
```

Established snackbar-with-CTA pattern (`lib/features/shell/main_shell.dart:227-235`):

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text(kPermissionsRequiredMessage),
    action: SnackBarAction(
      label: kOpenPermissionSettingsLabel,
      onPressed: () => unawaited(service.openSystemSettings()),
    ),
  ),
);
```

Established widget-test override pattern
(`test/widget/features/dashboard/dashboard_screen_test.dart:208`):

```dart
trackingPermissionServiceProvider.overrideWithValue(permissionService),
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add requestWhenInUse() to TrackingPermissionService + picker copy</name>
  <files>
    lib/features/tracking/services/tracking_permission_service.dart,
    lib/config/constants.dart,
    test/unit/features/tracking/tracking_permission_service_test.dart
  </files>
  <behavior>
    New unit tests in `test/unit/features/tracking/tracking_permission_service_test.dart`,
    in a new `group('TrackingPermissionService.requestWhenInUse', ...)`. Reuse the
    file's existing `_CallLog` / `_staticProbe` / `_staticRequester` helpers — do
    not invent a second harness.

    - already granted → returns `LocationWhenInUseStatus.granted` and
      `log.requestCalls` is empty (no dialog for an already-granted permission).
    - probe denied, request granted → returns `granted`; `log.requestCalls`
      equals `[Permission.locationWhenInUse]`.
    - probe denied, request denied → returns `denied`.
    - probe permanentlyDenied → returns `permanentlyDenied` and
      `log.requestCalls` is empty.
    - probe denied, request permanentlyDenied → returns `permanentlyDenied`.
    - NARROWNESS ASSERTION (add to every case above, or one dedicated test per
      outcome): neither `log.probeCalls` nor `log.requestCalls` ever contains
      `Permission.locationAlways` or `Permission.notification`. Because
      `_staticProbe`/`_staticRequester` throw `StateError` on an unmapped
      Permission, seeding the maps with ONLY `locationWhenInUse` already makes
      any stray call an explicit failure — do both: seed narrowly AND assert
      `isNot(contains(...))`, matching how the existing preflight tests assert
      ordering.
  </behavior>
  <action>
In `lib/features/tracking/services/tracking_permission_service.dart`:

1. Add a new top-level enum ABOVE `TrackingPermissionService`:

```dart
enum LocationWhenInUseStatus { granted, denied, permanentlyDenied }
```

   Dartdoc it, and state the reuse decision explicitly (a reviewer will ask):
   `TrackingPermissionStatus` is deliberately NOT reused because its granted
   variants encode background+notification state — `fullyGranted` means
   `locationAlways` AND `notification` are granted, and `foregroundOnly` /
   `notificationDenied` are only meaningful after the full preflight dance. A
   when-in-use-only caller has exactly three outcomes and must not be handed an
   enum whose variants it can neither produce nor honestly interpret. CLAUDE.md
   requires an enum (never a bool/String) for finite state, so this is a new
   3-way enum rather than a nullable bool.

2. Add the method to `TrackingPermissionService` (place it after `preflight`,
   before `currentStatus`, so the public API reads location-first):

```dart
  Future<LocationWhenInUseStatus> requestWhenInUse() async {
    final status = await _probe(Permission.locationWhenInUse);
    if (status.isPermanentlyDenied) {
      return LocationWhenInUseStatus.permanentlyDenied;
    }
    if (status.isGranted) return LocationWhenInUseStatus.granted;
    final requested = await _request(Permission.locationWhenInUse);
    if (requested.isPermanentlyDenied) {
      return LocationWhenInUseStatus.permanentlyDenied;
    }
    return requested.isGranted
        ? LocationWhenInUseStatus.granted
        : LocationWhenInUseStatus.denied;
  }
```

   Dartdoc it: probes first and only requests when not already granted; touches
   ONLY `Permission.locationWhenInUse` and NEVER `locationAlways` or
   `notification`; exists for callers (the location picker) that need to centre a
   map and have no business asking for background location or notifications;
   uses the same injected probe/requester seams as `preflight`, so it is unit
   testable with no platform channel.

3. Update the CLASS dartdoc (currently lines ~119-149). Both edits are required —
   the doc claims to list the full public contract and to state invariants that
   `requestWhenInUse` must not appear to violate:
   - Add a `requestWhenInUse` bullet to the "The public contract is:" list,
     described as the narrow when-in-use-only request used by non-tracking
     callers.
   - Extend "Ordering invariants". Invariants 1 and 2 are scoped to `preflight`
     and stay true as written — say so explicitly ("invariants 1 and 2 govern
     the `preflight` dance"). Add invariant 3: `requestWhenInUse` is NOT part of
     that dance; it touches `Permission.locationWhenInUse` and nothing else, so
     it cannot violate 1 or 2, and it must never grow a background or
     notification step.
   - The class dartdoc's opening line says the class "wraps permission_handler
     for Phase 2's strict four-step tracking permission dance". Widen it: the
     class is now also the app's single permission entry point for non-tracking
     callers.

In `lib/config/constants.dart`, add a new subsection after the picker block that
ends at line ~1299 (`kLocationPickerCrosshairSize`), headed
`// --- Location picker permission feedback (quick 260802-dgp) ---`:

```dart
const String kLocationPickerPermissionDeniedMessage =
    'Location permission is needed to find you on the map.';

const String kLocationPickerPermissionBlockedMessage =
    'Location permission is blocked. Enable it in settings to find you on '
    'the map.';

const String kLocationPickerLocationUnavailableMessage =
    "Couldn't get your location. Check that location services are on.";
```

   Dartdoc each. REUSE decision to record in the dartdocs: the existing
   `kOpenPermissionSettingsLabel` IS reused for the SnackBar action (it is
   deliberately the single shared label for every "take me to the permission
   page" control). The existing `kPermissionsRequiredMessage` is NOT reused —
   it reads "Traevy needs location and notification permissions to record a
   commute", which names a permission the picker never requests (D-2) and an
   activity the user is not doing.
  </action>
  <verify>
    <automated>dart format . &amp;&amp; flutter analyze &amp;&amp; flutter test test/unit/features/tracking/tracking_permission_service_test.dart</automated>
  </verify>
  <done>
    `requestWhenInUse()` exists, returns `LocationWhenInUseStatus`, and its new
    unit-test group passes including the assertion that `locationAlways` and
    `notification` are never probed or requested. The pre-existing `preflight` /
    `currentStatus` tests still pass unchanged. Three new `k`-prefixed picker
    constants exist. `flutter analyze` reports no new errors or warnings.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Prompt on open and make Locate me speak up</name>
  <files>lib/features/settings/screens/location_picker_screen.dart</files>
  <behavior>
    Behaviour pinned by Task 3's widget tests (written against this task's
    contract):
    - no saved coord → `requestWhenInUse()` is called exactly once on open
    - saved coord present → `requestWhenInUse()` is NEVER called
    - open + denied → map still renders, centre falls back, NO SnackBar
    - Locate me + denied → SnackBar with the denied message, no action
    - Locate me + permanentlyDenied → SnackBar with the blocked message AND an
      "Open settings" action that calls `openSystemSettings()`
    - Locate me + granted + resolver returns null → SnackBar with the
      unavailable message
    - Locate me + granted + resolver returns a fix → map moves, no SnackBar
  </behavior>
  <action>
SEAM DECISION (state it in the file where the seam is used, briefly):
the permission call goes through `ref.read(trackingPermissionServiceProvider)`
and tests override that provider with `TrackingPermissionService.forTesting(...)`.
No new widget constructor parameter. Rationale: CLAUDE.md and the project skill
mandate Riverpod for dependency injection, the provider override is the
established pattern in this suite
(`test/widget/features/dashboard/dashboard_screen_test.dart:208`), and adding a
second constructor override would give the screen two competing injection styles
for the same concern. The pre-existing `currentLocation` constructor seam stays
as-is — it is now purely a POSITION-read seam, not a permission seam, and that
split is the point.

1. `_defaultCurrentLocation` — DELETE the `Geolocator.checkPermission()` block.
   It becomes a pure position read (permission is the caller's concern now):

```dart
  static Future<LatLng?> _defaultCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } on Exception {
      return null;
    }
  }
```

   Rewrite its dartdoc: reads a fix assuming the caller has already resolved
   permission; returns null when services are off or the read times out; the
   returned coordinate is PII-adjacent and is never logged. Delete the
   "D-13 — never prompt from the picker" sentence, it is now false.
   Keep the `geolocator` import (still used for `getCurrentPosition`); the
   `LocationPermission` symbol is no longer referenced — make sure no unused
   import or dead reference is left behind (CLAUDE.md: no dead code).

2. `CurrentLocationResolver` typedef dartdoc (lines 16-23) — rewrite. It
   currently says the production default "checks permission WITHOUT prompting
   (D-13: do not aggressively prompt)". New text: resolves the device's current
   position, or null if unavailable (services off or timeout); permission is
   handled separately by `TrackingPermissionService` and is NOT this seam's
   job; injection seam so widget tests can drive the map without the geolocator
   platform channel.

3. Class dartdoc (lines 25-37) — rewrite the "Initial camera (D-13)" paragraph.
   New text, stating the supersession outright: the picker REQUESTS
   `locationWhenInUse` on open when the slot has no saved coord (quick
   260802-dgp, D-1), because landing a location picker on a hardcoded default
   city is worse than one prompt at the moment the user has clearly asked to
   pick a location. This supersedes the earlier D-13 "never prompt from the
   picker" rule for this screen. Background location and notifications are
   deliberately NOT requested (D-2). Initial camera chain: saved coord for this
   slot ?? device location (after the when-in-use request resolves granted) ??
   most recent GPS trip's end point ?? a sane non-(0,0) default constant.
   Declining the request is a legitimate answer and falls through that chain
   silently (D-3).

4. `_resolveInitialCenter` — request before reading a fix, only on the
   no-saved-coord branch. Preserve the rest of the chain EXACTLY:

```dart
    } else {
      // D-1: the user opened a location picker — asking for location here is
      // expected, not aggressive. D-2: when-in-use only.
      final status = await ref
          .read(trackingPermissionServiceProvider)
          .requestWhenInUse();
      if (status == LocationWhenInUseStatus.granted) {
        center = await _resolveLocation();
      }
      // D-3: a declined prompt is a legitimate answer — fall through the
      // remaining chain with no error UI.
      center ??= await _mostRecentTripEnd();
    }
```

   Note `ref` is safe here: this runs from a post-frame callback in a
   `ConsumerState`, exactly as the existing `ref.read(userPreferencesDaoProvider)`
   two lines above already does.

5. `_locateMe` — the D-4 rewrite. No branch may return without either moving the
   map or showing a SnackBar:

```dart
  Future<void> _locateMe() async {
    final service = ref.read(trackingPermissionServiceProvider);
    final status = await service.requestWhenInUse();
    if (!mounted) return;
    switch (status) {
      case LocationWhenInUseStatus.denied:
        _showSnack(kLocationPickerPermissionDeniedMessage);
        return;
      case LocationWhenInUseStatus.permanentlyDenied:
        _showSnack(
          kLocationPickerPermissionBlockedMessage,
          action: SnackBarAction(
            label: kOpenPermissionSettingsLabel,
            onPressed: () => unawaited(service.openSystemSettings()),
          ),
        );
        return;
      case LocationWhenInUseStatus.granted:
        break;
    }
    final fix = await _resolveLocation();
    if (!mounted) return;
    if (fix == null) {
      // Granted but no fix: services off or timeout. Previously this path
      // returned silently, so the FAB looked broken.
      _showSnack(kLocationPickerLocationUnavailableMessage);
      return;
    }
    _mapController.move(fix, kLocationPickerInitialZoom);
  }
```

   Use an exhaustive `switch` on the enum (no `default`) so a future variant is a
   compile error rather than a silent no-op — that is the exact failure mode
   being fixed.

6. Add the private helper right below `_locateMe`, mirroring the main_shell
   pattern rather than inventing a new one:

```dart
  void _showSnack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }
```

7. Imports: add `tracking_permission_service.dart` and
   `tracking_providers.dart`. `dart:async` (for `unawaited`) and
   `constants.dart` are already imported.

Widget size check (CLAUDE.md ~100 lines): `LocationPickerScreen.build` and
`_PickerMap.build` both stay well under 100 lines — the growth is in async
handlers on the State class, not in a build method. Do NOT split the file
speculatively; only extract if a build method actually crosses the guidance.
  </action>
  <verify>
    <automated>dart format . &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    The picker calls `requestWhenInUse()` on open when no saved coord exists and
    never calls `preflight()`. `_locateMe` has no path that returns without
    feedback. `Geolocator.checkPermission` no longer appears in the file. Every
    dartdoc asserting the old never-prompt behaviour is rewritten. `flutter
    analyze` reports no new errors or warnings.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Widget tests for prompt-on-open and Locate-me feedback</name>
  <files>test/widget/features/settings/location_picker_screen_test.dart</files>
  <behavior>
    Extend the existing file — do NOT delete or rewrite the LOC-02 backfill test
    it already contains.

    FIRST, fix the existing test: `pumpAndOpenPicker` opens the Home picker with
    NO saved coord, so after Task 2 it hits the new permission request and the
    real `const TrackingPermissionService` would reach the permission_handler
    platform channel. Add a `trackingPermissionServiceProvider.overrideWithValue(...)`
    to its `ProviderScope.overrides`, defaulting to an always-granted fake, and
    give `pumpAndOpenPicker` optional parameters so the new tests can vary the
    permission outcome, the `currentLocation` resolver, and whether a saved coord
    is seeded. This is the "update the existing test rather than delete it" step —
    its LOC-02 assertions must survive byte-for-byte.

    Build the fakes with `TrackingPermissionService.forTesting(probe:, requester:,
    opener:)`, recording which `Permission` values were touched and how many times
    `opener` fired, mirroring the `_CallLog` idea from the service unit tests.

    New tests:
    1. prompts on open when the slot has no saved coord — the requester recorded
       exactly one `Permission.locationWhenInUse` call, and the map centred on the
       resolver's coordinate (assert via the saved value after tapping confirm, or
       via `FlutterMap`'s `MapController.camera.center` — pick whichever the
       existing test's style supports; the confirm-then-read-prefs route is
       already proven in this file).
    2. does NOT prompt when a saved coord already exists — seed
       `db.userPreferencesDao.setHomeLocation(...)` BEFORE pumping, then assert
       both `probeCalls` and `requestCalls` are empty. (There is nothing to
       locate; prompting would be gratuitous.)
    3. declining on open falls back silently — permission fake returns denied,
       `currentLocation` resolver must NOT be invoked (assert with a flag; it
       would be a bug to read a position without permission), the map renders,
       and `find.byType(SnackBar)` finds nothing (D-3).
    4. Locate me on denied shows the SnackBar — tap
       `find.byIcon(Icons.my_location_rounded)`, pump, expect
       `find.text(kLocationPickerPermissionDeniedMessage)` and
       `find.byType(SnackBarAction)` findsNothing.
    5. Locate me on permanently denied shows the Open-settings action — expect
       `find.text(kLocationPickerPermissionBlockedMessage)`, then tap
       `find.text(kOpenPermissionSettingsLabel)` and assert the injected
       `opener` fired exactly once.
    6. Locate me granted but resolver returns null shows
       `kLocationPickerLocationUnavailableMessage` — this is the second half of
       the dead-FAB bug and must not regress.
  </behavior>
  <action>
Follow the conventions the existing file already establishes — they encode
hard-won constraints, do not deviate:
  - real in-memory Drift (`AppDatabase(DatabaseConnection(NativeDatabase.memory(),
    closeStreamsSynchronously: true))`) with `tripsDaoProvider` and
    `userPreferencesDaoProvider` overridden;
  - `theme: buildLightTheme()` on the `MaterialApp` — `LocationPickerCrosshair`
    reads `Theme.of(context).extension<TraevyTokensExt>()!` and a bare
    `MaterialApp` makes that null-check throw during build;
  - **plain `tester.pump(Duration)` loops only — NEVER `pumpAndSettle` while
    `FlutterMap` is mounted**, its tile timers never settle. The existing helper
    uses a 12 × 20ms loop; reuse that shape for the async permission +
    resolution chain and lengthen the loop if a test flakes on timing.

Head the file's comment block with a short second section describing the
260802-dgp bug (picker never prompted; Locate me was a silent no-op) alongside
the existing LOC-02 note, so the file's purpose stays legible.

For test 2, note the picker's confirm path writes prefs and pushes to the cloud;
`preferencesSyncServiceProvider` is only touched on confirm, so tests that do not
tap confirm need no override. If a new test does tap confirm, follow whatever the
existing LOC-02 test does (it currently does not override it) and do not add
network mocking speculatively.
  </action>
  <verify>
    <automated>dart format . &amp;&amp; flutter analyze &amp;&amp; flutter test test/widget/features/settings/location_picker_screen_test.dart</automated>
  </verify>
  <done>
    Six new widget tests pass, the pre-existing LOC-02 backfill test still passes
    with its assertions unchanged, and no test reaches a real platform channel.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app → Android permission system | A runtime permission dialog is now raised from a new screen |
| device GPS → app memory | A precise coordinate enters the app and is rendered on a map |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-DGP-01 | Elevation of Privilege | `requestWhenInUse()` | mitigate | Method touches `Permission.locationWhenInUse` only; a unit test asserts `locationAlways` and `notification` are never probed or requested, so scope creep into background location fails CI. |
| T-DGP-02 | Information Disclosure | `_defaultCurrentLocation` / `_locateMe` | mitigate | Coordinates are never logged and never enter a SnackBar message — all three new copy constants are static strings with no interpolation. Existing T-21-02-01 PII rule preserved. |
| T-DGP-03 | Repudiation | on-open prompt | accept | Android owns the consent record; the app persists no "asked once" flag by product decision (a re-prompt is the OS's to suppress). No app-side audit trail needed for a permission the OS already governs. |
</threat_model>

<verification>
Full-suite gate, run after all three tasks:

```bash
dart format .
flutter analyze
flutter test
```

Analyze baseline: **295 info-level lints**. New ERRORS or WARNINGS are
regressions and must be fixed. Info-level lints that match the existing
test-suite convention are acceptable.

Grep checks:
```bash
# The picker must no longer use geolocator's permission API (D-5).
grep -n "checkPermission" lib/features/settings/screens/location_picker_screen.dart   # expect: no match
# The picker must never call the full dance (D-2).
grep -n "preflight" lib/features/settings/screens/location_picker_screen.dart          # expect: no match
# The narrow request must never touch background/notification permissions.
grep -n "locationAlways\|Permission.notification" lib/features/settings/screens/location_picker_screen.dart  # expect: no match
```

**Real-device confirmation (cannot be done in CI or reliably in an emulator).**
CLAUDE.md requires GPS behaviour to be verified on a real Android device.
Do this on a FRESH INSTALL (or after clearing app data + revoking location
permission in Settings → Apps → Traevy → Permissions):
  1. Settings → Commute → Home location. The system location dialog appears.
  2. Allow → the map opens centred on your actual location, not Bengaluru.
  3. Clear data, reopen the picker, Deny → the map opens on the fallback with
     NO error toast/snackbar.
  4. Tap Locate me → SnackBar appears (no longer a dead button).
  5. Deny twice / "Don't allow" until permanently denied, tap Locate me →
     SnackBar with "Open settings"; tapping it lands on the app's PERMISSION
     list, not App Info.
  6. Grant permission, turn device Location Services OFF, tap Locate me →
     the "couldn't get your location" SnackBar appears.
Record the result in the quick-task summary.
</verification>

<success_criteria>
- Opening the Home or Office picker with no saved coord raises the Android
  when-in-use location prompt; granting it centres the map on the device fix.
- Opening a picker whose slot already has a saved coord raises no prompt.
- Declining on open falls back through recent-trip-end → default constant with
  no error UI.
- "Locate me" always produces an outcome: map move, denied SnackBar,
  permanently-denied SnackBar with a working "Open settings" action, or the
  location-unavailable SnackBar.
- Nothing on the picker path requests `locationAlways` or `notification`.
- `preflight()` and `currentStatus()` are byte-for-byte unchanged and their
  existing tests pass.
- `dart format .` clean, `flutter analyze` with no new errors/warnings,
  `flutter test` fully green.
</success_criteria>

<commits>
CLAUDE.md bracket convention, NOT conventional-commit prefixes. One concern per
commit:

- Task 1 → `[tracking] Add when-in-use-only permission request for the location picker`
- Task 2 → `[settings] Location picker requests GPS on open and Locate me no longer no-ops`
- Task 3 → `[settings] Widget tests for picker permission prompt and Locate-me feedback`
</commits>

<output>
After completion, create
`.planning/quick/260802-dgp-location-picker-requests-gps-permission-/260802-dgp-SUMMARY.md`.
</output>
</content>
</invoke>
