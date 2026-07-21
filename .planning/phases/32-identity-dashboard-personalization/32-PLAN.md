---
phase: 32-identity-dashboard-personalization
created: 2026-07-21
status: not_started
mode: manual-gsd
requirements: [UX-10]
depends_on: [20, 24, 31]
result: >
  NOT STARTED. Plan only. No schema change. Must land BEFORE Phase 33: this
  phase deletes _AccountSection from settings_screen.dart while Phase 33
  restructures the remaining sections of that same file. Consumes the InfoSheet
  introduced in Phase 31.
---

# Phase 32 — Identity & Dashboard Personalization

**Goal**: The app greets the user by their actual name, the avatar in the corner is
theirs, and account controls live behind that avatar instead of being buried at the top
of Settings.

**Depends on**: Phase 20 (first-run login with skip — the guest state this must handle),
Phase 24 (auto-restore, which `CloudSyncRow`/`RestoreRow` surface), Phase 31 (the shared
`InfoSheet`)

---

## D-01 — The header reads real auth state

`home_header.dart` hardcodes both the greeting (`:50`, `'Hi, $kPlaceholderUserName'`)
and the avatar letter (`:61-78`, `kPlaceholderUserInitial`). The widget is already a
`ConsumerWidget` and already holds a `ref` — it just uses it for the sibling
`GuestConnectionIndicator` and never asks who is signed in, even though
`authStateProvider` has the name sitting right there.

Wire both to the existing sealed `AuthState`:

- `AuthSignedIn` → the user's **first name** for the greeting (`name.split(' ').first`)
  and its first letter, uppercased, for the avatar.
- `AuthGuest` / `AuthLoading` → `kPlaceholderUserName` / `kPlaceholderUserInitial`
  ("Traveller" / "T") unchanged. These constants stop being placeholders and become the
  documented guest fallback — their dartdocs must be updated to say so, or the next
  reader will delete them as dead placeholder cruft.

Two edge cases the fallback must absorb, both real: `displayName` can be null (already
handled upstream at `auth_providers.dart:184-191`, which substitutes
`kPlaceholderUserName`), and it can be an empty or whitespace-only string, which the
upstream `??` does **not** catch. Trim and re-check before splitting, or the avatar
renders blank.

The avatar stays a letter in a circle. `User.photoURL` is never read anywhere in this
codebase and adding remote image loading to the dashboard header — with its cache,
failure and layout-shift concerns — is not justified by this request.

## D-02 — The avatar becomes the account entry point

Wrap the avatar in an `InkWell` opening an account bottom sheet holding exactly what
`_AccountSection` holds today (`settings_screen.dart:90-136`): `AccountRow`,
`CloudSyncRow`, `RestoreRow`, and Sign out when signed in; the "Sign in to back up" row
when guest, reusing `showSignInSheet`.

| Option | Verdict |
|---|---|
| Push a full account screen | **Rejected.** A new route and an extra tap to reach four rows. |
| Bottom sheet from the avatar | **Chosen.** Matches the established `sign_in_sheet` / `edit_trip_sheet` / options-menu precedent, dismissible by swipe, no route registration. |
| Keep a copy in Settings too | **Rejected.** The request is to *move* the information. Two Sign-out buttons reading the same state is a correctness hazard, and a duplicated `RestoreRow` could fire two restores. |

Then **delete** `_AccountSection` from `settings_screen.dart`. Settings begins at the
Commute/locations section.

The avatar needs a real hit target. It is a 36×36 `Container` today; wrap it so the
touch area is at least 48×48 per Material guidance, without changing the painted size.

## D-03 — Weekly summary explainer

Attach the Phase 31 `InfoSheet` beside the "This week" heading in `week_loss_card.dart`.

The copy has to answer a genuinely ambiguous question, because the card's own numbers
are not self-explanatory: the week runs **Monday to Sunday** and is anchored to today
(the D-03 definition already implemented in `stats_service.dart`), so it is the current
partial week and not a rolling 7 days; "lost to traffic" is time recorded below 10 km/h;
and time during breaks counts toward neither figure.

Point the same explainer at the identical concept on the stats screen later if wanted —
but not in this phase, to keep the file surface disjoint from Phase 34.

---

## Execution waves (conflict-safe)

**Wave 1 — both plans, fully parallel** (disjoint files)

- `32-01` — `home_header.dart` identity wiring, the new
  `lib/features/dashboard/widgets/account_sheet.dart`, and removal of `_AccountSection`
  from `settings_screen.dart`. **Owns the settings file in this phase.**
- `32-02` — `week_loss_card.dart` info icon + constants.

Constants collisions are the only overlap; both plans append to distinct banner sections
of `constants.dart`, which the project convention (append, never edit) already handles.

---

## Threat model

| ID | Category | Asset | Decision | Mitigation |
|---|---|---|---|---|
| T-32-01 | Information disclosure | The user's real name and email now render on the dashboard, visible to anyone glancing at the phone | **accept** | The dashboard is behind the device lock screen, and the name is the user's own. Only the first name shows in the greeting; the email appears only inside the sheet, which requires a deliberate tap. |
| T-32-02 | Elevation of privilege | Sign out reachable in one tap from the home screen | mitigate | Sign out keeps its existing confirmation and `dangerous: true` styling. Local Drift data survives sign-out unchanged (existing behaviour), so an accidental sign-out is not data loss. |
| T-32-03 | Availability | Account sheet unreachable if the avatar fails to render | mitigate | The avatar has no failure path — it renders a letter from a string with a guest fallback, never a network resource (D-01). |
| T-32-04 | Data integrity | Stale identity after sign-in/sign-out while the dashboard is mounted | mitigate | `authStateProvider` is watched, not read, so the header rebuilds on every auth transition. |

---

## Success criteria (what must be TRUE)

1. A signed-in user sees "Hi, {their first name}" and their initial in the avatar.
2. A guest — and a user whose Google account has no display name, or a whitespace-only
   one — sees "Hi, Traveller" and "T", with no blank avatar and no crash.
3. Tapping the avatar opens the account sheet; its contents match what Settings showed
   before this phase, for both the signed-in and guest states.
4. Settings no longer contains an Account section, and contains no second sign-out or
   restore control.
5. Signing in or out while the dashboard is visible updates the greeting and avatar
   without a manual refresh.
6. An info icon beside the weekly summary explains the Mon–Sun window, what "lost to
   traffic" measures, and that breaks are excluded.
7. The avatar's touch target is at least 48×48 while its painted size is unchanged.

## Verification

- Unit: first-name derivation — full name, single name, empty string, whitespace-only,
  leading/trailing spaces, a name with a non-Latin first character.
- Widget: header renders name + initial for `AuthSignedIn`; falls back for `AuthGuest`
  and `AuthLoading`.
- Widget: tapping the avatar opens the sheet; signed-in and guest variants render the
  expected rows.
- Widget: settings screen no longer contains `AccountRow` or a sign-out control.
- `flutter analyze` and `dart format .` clean.
- **Manual**: sign out and back in from the avatar sheet; confirm the greeting changes
  both ways without restarting the app.
- **Manual**: confirm restore still works from its new location in the sheet.
