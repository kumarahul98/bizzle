---
spike: "002a"
name: cognito-token-exchange
type: comparison
validates: "Given google_sign_in ID token in Flutter, when exchanging via amazon_cognito_identity_dart_2, then what is the actual code complexity and what does the User Pool setup require?"
verdict: PARTIAL
related: ["002b"]
tags: [cognito, auth, flutter, aws]
---

# Spike 002a: Cognito Token Exchange

## What This Validates
Given a Google ID token from google_sign_in, when using amazon_cognito_identity_dart_2 to exchange it for a Cognito JWT, what is the code complexity and what does setup require?

## Research

| Approach | Library | Status |
|----------|---------|--------|
| amazon_cognito_identity_dart_2 federated login | v3.7.0 | **Does not exist** — no federated identity method |
| Cognito Hosted UI + deep link | url_launcher + app_links | Works, adds UX/code friction |
| Custom Lambda trigger | AWS Lambda | Works, adds backend complexity |

## How to Run
Code comparison only — cannot run without a live Cognito User Pool.
```bash
# Read the code:
cat .planning/spikes/002a-cognito-token-exchange/auth_service.dart
```

## What to Expect
Analysis of actual Flutter code complexity, not a runnable demo.

## Investigation Trail

### Critical finding: amazon_cognito_identity_dart_2 doesn't support federated login
The package v3.7 supports `USER_SRP_AUTH` (username/password) and `CUSTOM_AUTH` but has **no method that takes a Google ID token and returns a Cognito User Pool JWT directly**.

The common misconception: "pass Google ID token to Cognito SDK and get back a JWT." This is not how it works. Cognito's Google federation is exposed through the Hosted UI (a browser-based OAuth flow), not a server-to-server token exchange.

### What actually works (two options):

**Option A: Cognito Hosted UI**
- Launch `https://<domain>.auth.<region>.amazoncognito.com/oauth2/authorize?identity_provider=Google&...`
- User is redirected to Google login in a browser
- On success, Cognito redirects back to your app via a deep link callback URL
- App receives authorization code, exchanges it for tokens via POST to `/oauth2/token`
- Requires: `url_launcher`, `app_links`, HTTP call, deep link scheme registered in AndroidManifest

**Option B: Custom Lambda trigger (Pre-Token Generation)**
- Write a Lambda that accepts Google ID tokens via a custom auth challenge
- Lambda verifies the Google token, creates/finds the Cognito user, generates Cognito tokens
- More backend work, but cleaner Flutter-side experience

**What google_sign_in actually provides**
google_sign_in on Android uses the native Google Sign-In SDK, which gives you a Google ID token. This token is:
- Valid for Google's APIs
- Verifiable using Google's JWKS
- **NOT directly accepted by Cognito User Pool JWT endpoints**

### Cognito setup requirements (Phase 10)
1. User Pool with Google identity provider configured
2. App Client (no client secret for mobile)
3. Hosted UI domain (e.g., `commute-tracker.auth.us-east-1.amazoncognito.com`)
4. Callback URL: `commute.tracker://callback` (deep link scheme)
5. google-services.json with Cognito's client ID added as an authorized redirect URI in Google Cloud Console
6. SAM template: ~50 lines of UserPool + UserPoolClient + UserPoolIdentityProvider resources

## Results

**Verdict: PARTIAL** — The Cognito approach works but requires more setup than expected.

Key findings:
- `amazon_cognito_identity_dart_2` does NOT abstract the Google federation flow
- The real implementation requires Hosted UI + deep link handling (adds `url_launcher` + `app_links` + HTTP POST to token endpoint)
- Once set up, Cognito provides 30-day refresh tokens — significantly better session durability than plain Google tokens (1-hour expiry)
- API Gateway integration in Phase 10 is zero-config (just reference the User Pool ARN)
- Setup complexity is front-loaded in Phase 10 infra, not Phase 9 Flutter

**See 002b for the plain Google alternative and combined comparison.**
