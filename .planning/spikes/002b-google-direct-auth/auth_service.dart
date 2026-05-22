// Spike 002b — Plain Google Sign-In (no Cognito)
// Flutter AuthService: google_sign_in only, Google ID token used directly for API calls.
//
// Dependencies needed in pubspec.yaml:
//   google_sign_in: ^6.2.0
//   flutter_secure_storage: ^9.2.0
//
// NO Cognito User Pool needed.
// NO amazon_cognito_identity_dart_2 dependency.
// google-services.json still needed (same as 002a).
//
// Trade-off: API Gateway cannot use the native Cognito Authorizer.
// Instead, Phase 10 must deploy a Lambda Authorizer (see lambda-authorizer.ts).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

const _keyGoogleIdToken = 'google_id_token';
const _keyDisplayName = 'display_name';
const _keyEmail = 'email';
const _keyUserId = 'google_user_id';  // Google subject ID (stable per Google account)

/// Result of a successful sign-in.
final class SignInResult {
  const SignInResult({
    required this.sub,
    required this.displayName,
    required this.email,
    required this.idToken,
  });

  final String sub;        // Google subject ID
  final String displayName;
  final String email;
  final String idToken;    // Google ID token — sent in Authorization header
}

/// Handles Google Sign-In only — no Cognito token exchange.
///
/// Flow:
///   1. google_sign_in → Google ID token (one step, no exchange)
///   2. Store Google ID token in flutter_secure_storage
///   3. Send Google ID token as Authorization header on API calls
///   4. Lambda Authorizer on the backend verifies it using Google's public keys
class AuthService {
  AuthService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // Scopes: profile gives us name, email gives us email.
  // No serverClientId needed — we're using the ID token as-is.
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // ── Sign in ───────────────────────────────────────────────────────────────

  Future<SignInResult> signIn() async {
    // One step — no exchange, no network call to Cognito
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw const SignInCancelledException();

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw const GoogleTokenMissingException();

    final sub = googleUser.id;  // Stable Google subject ID
    final name = googleUser.displayName ?? 'Traveller';
    final email = googleUser.email;

    // Persist — same as Cognito approach
    await Future.wait([
      _storage.write(key: _keyGoogleIdToken, value: idToken),
      _storage.write(key: _keyUserId, value: sub),
      _storage.write(key: _keyDisplayName, value: name),
      _storage.write(key: _keyEmail, value: email),
    ]);

    return SignInResult(sub: sub, displayName: name, email: email, idToken: idToken);
  }

  // ── Restore session from storage ──────────────────────────────────────────

  Future<SignInResult?> restoreSession() async {
    // ⚠️  SPIKE FINDING: Google ID tokens expire after 1 hour.
    // Unlike Cognito (which has long-lived refresh tokens), Google ID tokens
    // are short-lived. On restore, we must check expiry and silently refresh.
    //
    // google_sign_in handles this via signInSilently() — it refreshes the token
    // without showing a UI. This works as long as the user hasn't revoked access.
    // If silent sign-in fails, the user must go through the full sign-in flow again.

    final sub = await _storage.read(key: _keyUserId);
    if (sub == null) return null;

    // Try silent token refresh
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        await _storage.deleteAll();
        return null;
      }
      final auth = await googleUser.authentication;
      final freshToken = auth.idToken;
      if (freshToken != null) {
        await _storage.write(key: _keyGoogleIdToken, value: freshToken);
      }
      final name = await _storage.read(key: _keyDisplayName) ?? 'Traveller';
      final email = await _storage.read(key: _keyEmail) ?? '';
      return SignInResult(sub: sub, displayName: name, email: email, idToken: freshToken ?? '');
    } catch (_) {
      await _storage.deleteAll();
      return null;
    }
  }

  // ── Get token for API calls ───────────────────────────────────────────────

  Future<String?> getIdToken() async {
    // ⚠️  SPIKE FINDING: Must check freshness before every API call.
    // Google ID tokens expire after 1 hour. Unlike Cognito tokens (which have
    // a refresh token that works for 30+ days), we must call signInSilently()
    // before each API call or check the JWT exp claim.
    //
    // In practice: call signInSilently() once per app session and cache the
    // result for up to 50 minutes. Or check exp claim and refresh proactively.
    final googleUser = await _googleSignIn.signInSilently();
    if (googleUser == null) return null;
    final auth = await googleUser.authentication;
    return auth.idToken;
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _storage.deleteAll();
  }
}

final class SignInCancelledException implements Exception {
  const SignInCancelledException();
}

final class GoogleTokenMissingException implements Exception {
  const GoogleTokenMissingException();
}
