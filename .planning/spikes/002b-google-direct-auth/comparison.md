# Auth Approach Comparison: Cognito Exchange vs Plain Google Sign-In

## Flutter side (auth_service.dart)

### Code line count
| File | Lines | What it does |
|------|-------|--------------|
| 002a/auth_service.dart (Cognito) | ~120 | Google sign-in + hosted UI exchange + token storage |
| 002b/auth_service.dart (Google direct) | ~100 | Google sign-in + token storage |

Both are similar in Flutter code volume. The difference is the exchange step.

---

## Critical finding: amazon_cognito_identity_dart_2 doesn't support federated login directly

The package (v3.7) supports `USER_SRP_AUTH` and `CUSTOM_AUTH` but has **no method that takes
a Google ID token and returns a Cognito User Pool JWT**. This means the Cognito approach
requires one of:

1. **Cognito Hosted UI** — launch a browser URL, receive auth code via deep link, exchange
   for tokens via HTTP POST to `/oauth2/token`. Adds `url_launcher` + `app_links` + HTTP
   call. The amazon_cognito_identity_dart_2 package does NOT abstract this flow.

2. **Custom Lambda trigger** — write a Lambda that accepts Google tokens and issues Cognito
   tokens. Adds backend complexity to avoid Hosted UI friction.

The `google_sign_in` package's flow (tap → Google account picker → ID token) is fully
supported in both approaches. The **extra complexity of Cognito is entirely on the token
exchange**, not on the sign-in UX.

---

## Backend side

### Cognito approach (002a) — template.yaml Authorizer
```yaml
# In template.yaml — that's it. No Lambda needed.
Authorizer:
  Type: COGNITO_USER_POOLS
  ProviderARNs:
    - !GetAtt UserPool.Arn
```

### Google direct approach (002b) — Lambda Authorizer
- New `LambdaAuthorizerFunction` in `template.yaml`
- Fetches Google's JWKS on first invocation (network call, ~200ms cold start cost)
- JWKS cached in Lambda memory between warm invocations
- Must handle token expiry: Google ID tokens expire after **1 hour** (vs Cognito's 30-day refresh token)
- GOOGLE_CLIENT_ID must be kept in sync between Flutter build flags and Lambda env var

---

## Token lifetime comparison

| | Cognito | Google Direct |
|---|---------|---------------|
| Access token | 1 hour (configurable) | — |
| ID token | 1 hour | **1 hour** |
| Refresh token | **30 days** (silent refresh) | None — must call signInSilently() |
| Offline session | Yes — refresh token survives app restarts for 30 days | Fragile — silent refresh requires active Google session |

**Key finding**: Without a Cognito refresh token, plain Google Sign-In requires calling
`signInSilently()` before every API call (or at least every session start). This works
on most devices but silently fails if the user revokes access or Google's session expires.

---

## Setup complexity

### Cognito approach
1. Create Cognito User Pool in AWS Console (or SAM template)
2. Add Google as identity provider (Client ID + Client Secret from Google Cloud Console)
3. Configure Hosted UI domain (e.g., `commute-tracker.auth.us-east-1.amazoncognito.com`)
4. Add callback/logout URLs for the deep link scheme
5. Configure `--dart-define` flags: COGNITO_POOL_ID, COGNITO_CLIENT_ID, COGNITO_REGION
6. Add `app_links` + deep link handler for the auth callback in Flutter

### Google direct approach
1. Confirm `google-services.json` has the correct OAuth client ID (already needed for both)
2. Add `GOOGLE_CLIENT_ID` to Lambda environment variable
3. Deploy `LambdaAuthorizerFunction` in SAM template
4. **No Hosted UI, no callback URL, no deep link handler** — sign-in is fully in-app

---

## Summary verdict

| Dimension | Cognito Exchange | Google Direct |
|-----------|-----------------|---------------|
| Flutter code complexity | Higher (Hosted UI + deep link) | Lower (no exchange) |
| Backend code | Zero (Cognito Authorizer config) | Lambda Authorizer (~50 lines) |
| Session durability | High (30-day refresh token) | Medium (silent refresh, can fail) |
| Token freshness management | Handled by Cognito SDK | Must manage manually |
| AWS-native integration | Full — all services recognize Cognito tokens | Partial — only custom Authorizer validates |
| Future-proofing | Add Apple/email auth as Cognito config | Requires new Lambda Authorizer per provider |
| Setup steps | More (Hosted UI, callback URLs, deep links) | Fewer |

**Winner for this app:** It's genuinely close. If Phase 10 were already using Cognito for
user management features beyond auth (admin, revocation), Cognito wins easily. For 3 simple
API endpoints on a personal app, Google Direct has less total code and simpler setup.

The deciding factors:
- If token expiry management (silent refresh) adds meaningful UX risk → Cognito
- If Hosted UI + deep link UX friction is acceptable → Cognito
- If you want the absolute minimum moving parts → Google Direct
