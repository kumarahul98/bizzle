import type { Request } from 'express';

const verifyIdTokenMock = jest.fn();

jest.mock('firebase-admin/auth', () => ({
  getAuth: () => ({ verifyIdToken: verifyIdTokenMock }),
}));

// Imported after the mock is registered so verifyAuth picks up the mocked SDK.
import { extractBearerToken, verifyAuth, AuthError } from '../auth';

describe('extractBearerToken', () => {
  it('returns the token from a well-formed Bearer header', () => {
    expect(extractBearerToken('Bearer t.o.k')).toBe('t.o.k');
  });

  it('throws AuthError (401) when the header is undefined', () => {
    try {
      extractBearerToken(undefined);
      fail('expected AuthError');
    } catch (e) {
      expect(e).toBeInstanceOf(AuthError);
      expect((e as AuthError).statusCode).toBe(401);
    }
  });

  it('throws AuthError when the scheme is missing', () => {
    expect(() => extractBearerToken('token-without-scheme')).toThrow(AuthError);
  });

  it('throws AuthError for a non-Bearer scheme', () => {
    expect(() => extractBearerToken('Basic xyz')).toThrow(AuthError);
  });

  it('throws AuthError when the token is empty (Bearer with trailing space)', () => {
    expect(() => extractBearerToken('Bearer ')).toThrow(AuthError);
  });

  it('throws AuthError when the token is whitespace-only', () => {
    expect(() => extractBearerToken('Bearer    ')).toThrow(AuthError);
  });
});

describe('verifyAuth', () => {
  beforeEach(() => {
    verifyIdTokenMock.mockReset();
  });

  function makeReq(authorization?: string): Request {
    return { headers: { authorization } } as unknown as Request;
  }

  it('returns the uid for a valid token', async () => {
    verifyIdTokenMock.mockResolvedValue({ uid: 'u1' });
    await expect(verifyAuth(makeReq('Bearer good.token'))).resolves.toBe('u1');
    expect(verifyIdTokenMock).toHaveBeenCalledWith('good.token');
  });

  it('throws AuthError (not the raw error) when verification fails', async () => {
    verifyIdTokenMock.mockRejectedValue(new Error('auth/id-token-expired'));
    await expect(verifyAuth(makeReq('Bearer bad.token'))).rejects.toBeInstanceOf(AuthError);
  });

  it('throws AuthError without calling verifyIdToken when the header is missing', async () => {
    await expect(verifyAuth(makeReq(undefined))).rejects.toBeInstanceOf(AuthError);
    expect(verifyIdTokenMock).not.toHaveBeenCalled();
  });
});
