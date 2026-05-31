import { getAuth } from 'firebase-admin/auth';
import type { Request } from 'express';

/**
 * Thrown when authentication fails (missing/malformed header, invalid or
 * expired token). Carries the 401 status so callers map it directly to a
 * response. The message is always safe to surface — it never echoes the token
 * or an underlying SDK error (D-06).
 */
export class AuthError extends Error {
  public readonly statusCode = 401;

  constructor(message: string) {
    super(message);
    this.name = 'AuthError';
  }
}

/**
 * Extract the bearer token from an `Authorization` header value.
 *
 * Pure and Admin-SDK-free so it is unit-testable in isolation. Requires the
 * exact `Bearer <token>` scheme; throws {@link AuthError} on a missing or
 * malformed header.
 */
export function extractBearerToken(header: string | undefined): string {
  if (!header) {
    throw new AuthError('Missing Authorization header');
  }
  const match = /^Bearer (.+)$/.exec(header);
  if (!match) {
    throw new AuthError('Malformed Authorization header');
  }
  return match[1];
}

/**
 * Verify the request's Firebase ID token and return the authenticated uid
 * (D-07). This is the first gate of every handler. Verification failures are
 * rethrown as {@link AuthError} so the raw SDK error never reaches the client.
 */
export async function verifyAuth(req: Request): Promise<string> {
  const token = extractBearerToken(req.headers.authorization);
  try {
    const decoded = await getAuth().verifyIdToken(token);
    return decoded.uid;
  } catch {
    throw new AuthError('Invalid or expired token');
  }
}
