/**
 * Spike 002b — Lambda Authorizer for plain Google Sign-In
 *
 * This is what Phase 10 needs if we drop Cognito. API Gateway cannot natively
 * validate Google JWTs — it only knows about Cognito tokens. So every API request
 * passes through this Lambda Authorizer, which:
 *
 *   1. Extracts the Bearer token from the Authorization header
 *   2. Fetches Google's public JWKS (cached in memory between invocations)
 *   3. Verifies the JWT signature, expiry, audience, and issuer
 *   4. Returns an IAM policy (Allow or Deny) with the Google subject as principalId
 *
 * Dependencies:
 *   npm install jose  (lightweight JWT verification, no heavy jsonwebtoken)
 *
 * This replaces the built-in Cognito Authorizer config in template.yaml with a
 * full Lambda function that runs on every API call.
 */

import { createRemoteJWKSet, jwtVerify } from "jose";
import type { APIGatewayTokenAuthorizerEvent, APIGatewayAuthorizerResult } from "aws-lambda";

// Google's JWKS endpoint — public keys for verifying Google ID tokens
const GOOGLE_JWKS_URI = "https://www.googleapis.com/oauth2/v3/certs";
const GOOGLE_ISSUERS = ["accounts.google.com", "https://accounts.google.com"];

// Your Android OAuth client ID from google-services.json
// Must match the 'aud' claim in the Google ID token
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID!;

// Cache the JWKS between Lambda invocations (warm start reuse)
let cachedJwks: ReturnType<typeof createRemoteJWKSet> | null = null;

function getJwks() {
  if (!cachedJwks) {
    cachedJwks = createRemoteJWKSet(new URL(GOOGLE_JWKS_URI));
  }
  return cachedJwks;
}

function buildPolicy(
  principalId: string,
  effect: "Allow" | "Deny",
  resource: string,
  context?: Record<string, string>
): APIGatewayAuthorizerResult {
  return {
    principalId,
    policyDocument: {
      Version: "2012-10-17",
      Statement: [{ Action: "execute-api:Invoke", Effect: effect, Resource: resource }],
    },
    context,
  };
}

export async function handler(event: APIGatewayTokenAuthorizerEvent): Promise<APIGatewayAuthorizerResult> {
  const token = event.authorizationToken?.replace(/^Bearer\s+/i, "");

  if (!token) {
    return buildPolicy("anonymous", "Deny", event.methodArn);
  }

  try {
    const { payload } = await jwtVerify(token, getJwks(), {
      issuer: GOOGLE_ISSUERS,
      audience: GOOGLE_CLIENT_ID,
    });

    const sub = payload.sub!;
    const email = (payload.email as string) ?? "";

    return buildPolicy(sub, "Allow", event.methodArn, { userId: sub, email });
  } catch {
    // Invalid signature, expired token, wrong audience, etc.
    return buildPolicy("anonymous", "Deny", event.methodArn);
  }
}
