---
spike: "002b"
name: google-direct-auth
type: comparison
validates: "Given a raw Google ID token, when used directly for API auth without Cognito, then what does a Lambda Authorizer need and what is the total complexity cost?"
verdict: VALIDATED
related: ["002a"]
tags: [google-auth, auth, lambda, flutter]
---

# Spike 002b: Plain Google Sign-In (No Cognito)

## What This Validates
Given a raw Google ID token from google_sign_in, when used directly as the API authorization credential, what does the backend need to verify it and what is the total complexity cost?

## How to Run
Code comparison only.
```bash
cat .planning/spikes/002b-google-direct-auth/auth_service.dart       # Flutter side
cat .planning/spikes/002b-google-direct-auth/lambda-authorizer.ts     # Backend side
cat .planning/spikes/002b-google-direct-auth/comparison.md            # Full side-by-side
```

## Investigation Trail

### Flutter side — simpler than Cognito
Without the token exchange, the Flutter auth_service.dart drops to:
- google_sign_in call → ID token → flutter_secure_storage
- No Hosted UI, no deep link handler, no HTTP POST to token endpoint
- Sign-in is entirely in-app with Google's native account picker

### Critical finding: Google ID tokens expire in 1 hour
Unlike Cognito's 30-day refresh token, Google ID tokens are valid for exactly 1 hour.
The flutter side must call `signInSilently()` to get a fresh token before API calls.
google_sign_in handles this silently on most devices, but it requires an active Google
session and network connectivity.

Failure scenario: user is offline for > 1 hour → signs back in → silent refresh fails
→ user must re-authenticate. With Cognito, the refresh token would cover this silently.

### Backend side — Lambda Authorizer required
API Gateway's built-in Cognito Authorizer only validates Cognito JWTs. For Google tokens,
a custom Lambda Authorizer is required (~50 lines, uses `jose` for JWT verification).

The authorizer:
- Fetches Google's JWKS on first invocation (~200ms, cached in memory)
- Verifies signature, expiry, audience (must match GOOGLE_CLIENT_ID env var), issuer
- Returns IAM Allow/Deny policy with Google subject as principalId

This is straightforward code but it's an extra Lambda function deployed + maintained.

### Google subject ID vs Cognito sub
- Google subject ID (`googleUser.id`) is stable — doesn't change if user changes their email
- But it's specific to the Google OAuth client — if you change client IDs (e.g., add iOS), the subject IDs change
- Cognito sub is stable across any identity provider the user links

## Results

**Verdict: VALIDATED** — Plain Google Sign-In works cleanly with a Lambda Authorizer.

Key findings:
- Flutter side is simpler (no Hosted UI, no deep link, no token exchange)
- Backend adds a Lambda Authorizer function (~50 lines) vs Cognito's zero-code config
- Google tokens expire in 1 hour — `signInSilently()` handles this but it's a risk
- Session durability is lower than Cognito (no long-lived refresh token)
- GOOGLE_CLIENT_ID must stay in sync between google-services.json and Lambda env var

**Combined verdict (002a vs 002b):** See `comparison.md` for the full side-by-side.

**Bottom line:**
- For a personal app where session durability matters (offline use for >1 hour) → Cognito wins
- For minimal moving parts and simpler setup → Google Direct wins
- The Flutter code difference is small; the real gap is session management and Phase 10 backend setup
