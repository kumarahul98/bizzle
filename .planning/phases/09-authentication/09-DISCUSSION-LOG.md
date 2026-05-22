# Phase 9: Authentication - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-21
**Phase:** 9-authentication
**Areas discussed:** Auth gate routing, Skip / optional sign-in, User ID backfill, Cognito config injection

---

## Auth gate routing

| Option | Description | Selected |
|--------|-------------|----------|
| Auth state provider drives home: | AuthStateNotifier reads flutter_secure_storage on init, app.dart watches it and renders splash/onboarding/MainShell | ✓ |
| SplashRouter widget | Dedicated SplashScreen reads secure storage on first build, then navigates | |
| You decide | Claude picks the approach | |

**User's choice:** Auth state provider (Recommended)
**Notes:** User asked "why do you recommend the first one" — explained reactive by default, consistent with existing Riverpod patterns, token refresh in one place, testable via provider override.

Follow-up Q — AuthStateNotifier location:

| Option | Description | Selected |
|--------|-------------|----------|
| lib/features/auth/providers/ | Creates the anticipated feature directory, consistent with CLAUDE.md structure | ✓ |
| lib/shared/providers/ | Cross-cutting state location | |
| lib/auth_state.dart | Root-level single file | |

Follow-up Q — Loading state:

| Option | Description | Selected |
|--------|-------------|----------|
| Blank screen with splash bg color | Instant, sub-300ms, effectively invisible | |
| CircularProgressIndicator centered | Visible spinner | |
| Static splash screen (logo + bg) | Traevy logo mark during loading | ✓ |

Follow-up Q — Token validation on boot:

| Option | Description | Selected |
|--------|-------------|----------|
| Check existence only — trust stored token | Offline-friendly, no boot latency, lazy refresh via 401 | ✓ |
| Validate token on boot | Network call, 200-500ms latency, fails offline | |
| Check expiry timestamp only | JWT decode, no network, doesn't catch revocation | |

---

## Skip / optional sign-in

| Option | Description | Selected |
|--------|-------------|----------|
| Optional — full app works without sign-in | Guest state, sign-in accessible from Settings | ✓ |
| Required — must sign in to use | No skip link, simpler state, breaks offline-first | |
| Prompt but skippable (soft gate) | Periodic nudge prompts | |

**User's choice:** Optional (Recommended)

Follow-up Q — Sign-in flow from Settings:

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom sheet over Settings screen | Modal, dismissable, no navigation away | ✓ |
| Full-screen onboarding route | Reuses kRouteOnboarding, feels heavy for return user | |
| Inline in Account section | Minimalist, loses context | |

Follow-up Q — Guest state Account section:

| Option | Description | Selected |
|--------|-------------|----------|
| "Sign in to back up" row with Google icon | Single purpose-driven CTA | ✓ |
| Placeholder AccountRow + Sign In button | Shows placeholder values alongside button | |
| Empty Account section | Sign-in not discoverable | |

**Bonus discussion — Cognito vs plain Google Sign-In:**
User asked about the benefits of each. Explained: plain Google tokens can't be used with API Gateway's Cognito Authorizer; dropping Cognito saves Flutter work but adds custom Lambda Authorizer work to Phase 10. User chose to keep Cognito.

| Option | Description | Selected |
|--------|-------------|----------|
| Keep Cognito — Google → Cognito JWT | Matches BACK-01, API Gateway Authorizer works out of box | ✓ |
| Plain Google Sign-In only | Drop Cognito, Phase 10 needs custom Lambda Authorizer | |

---

## User ID backfill

**User's initial response:** Wanted a user-facing merge option (merge local trips with cloud backup on sign-in).

**Clarification:** Phase 9 has no backend connection. The merge/conflict UI belongs in Phase 11 (restore flow). Phase 9 can only do the local userId rewrite.

| Option | Description | Selected |
|--------|-------------|----------|
| Batch UPDATE all local trips to Cognito sub | Single Drift UPDATE on sign-in | ✓ |
| Leave local trips as-is | Only new trips get real userId | |
| Backfill at sync time | Backend resolves 'local_user' → Cognito sub | |

**User's choice:** Batch UPDATE (after clarification that merge UI is Phase 11)

Follow-up Q — Backfill trigger location:

**User's response:** "Give them a one-time sync button to sync local trips with cloud on sign-in."
**Clarification provided:** In Phase 9 there's no backend to sync to. Confirmed: silent local backfill + confirmation screen is the right Phase 9 scope.

| Option | Description | Selected |
|--------|-------------|----------|
| Silent backfill + confirmation screen | Sign-in → batch UPDATE → "Backup is set up" screen | ✓ |
| Just silent backfill, no confirmation | Straight to MainShell | |
| Defer entirely to Phase 11 | Phase 9 stores token, Phase 11 handles backfill | |

---

## Cognito config injection

| Option | Description | Selected |
|--------|-------------|----------|
| --dart-define build flags | Standard Flutter approach, not in source, CI/CD friendly | ✓ |
| constants.dart hard-coded | Simple, single-environment, committed to repo | |
| cognito_config.dart gitignored file | Like --dart-define but manual per-dev setup | |

Follow-up Q — Missing config behavior:

| Option | Description | Selected |
|--------|-------------|----------|
| Fall back to guest mode silently | App functional offline, sign-in disabled | ✓ |
| Assert/throw on missing config | App won't launch without valid config | |
| You decide | Claude picks | |

Follow-up Q — Google client ID injection:

| Option | Description | Selected |
|--------|-------------|----------|
| google-services.json handles it | Standard plugin approach, no --dart-define needed | ✓ |
| Also via --dart-define | Consistent with Cognito but requires google_sign_in override | |
| Research during planning | Let researcher confirm | |

---

## Claude's Discretion

None — user made explicit choices for all gray areas.

## Deferred Ideas

- **Merge/conflict UI** — local vs cloud trips on sign-in. Deferred to Phase 11 restore flow.
- **Sign-out / account deletion** — not in Phase 9 scope.
- **Token refresh** — lazy via 401 handling, deferred to Phase 11.
