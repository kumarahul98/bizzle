// Spike 002a — Cognito Token Exchange
// Flutter AuthService: Google Sign-In → amazon_cognito_identity_dart_2 → Cognito JWT
//
// Dependencies needed in pubspec.yaml:
//   google_sign_in: ^6.2.0
//   amazon_cognito_identity_dart_2: ^3.7.0
//   flutter_secure_storage: ^9.2.0
//
// Cognito User Pool setup required (Phase 10 infra):
//   - User Pool with Google as federated identity provider
//   - App client (no secret — mobile app client)
//   - google-services.json with the OAuth client ID for Android
//   - Callback URL configured in User Pool: myapp://callback
//
// Configured via --dart-define (D-14 from Phase 9 context):
//   COGNITO_POOL_ID, COGNITO_CLIENT_ID, COGNITO_REGION

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Injected via --dart-define build flags (D-14)
const _poolId = String.fromEnvironment('COGNITO_POOL_ID');
const _clientId = String.fromEnvironment('COGNITO_CLIENT_ID');
const _region = String.fromEnvironment('COGNITO_REGION', defaultValue: 'us-east-1');

const _keyAccessToken = 'cognito_access_token';
const _keyIdToken = 'cognito_id_token';
const _keyRefreshToken = 'cognito_refresh_token';
const _keyCognitoSub = 'cognito_sub';
const _keyDisplayName = 'cognito_display_name';
const _keyEmail = 'cognito_email';

/// Result of a successful sign-in.
final class SignInResult {
  const SignInResult({
    required this.sub,
    required this.displayName,
    required this.email,
    required this.idToken,
  });

  final String sub;
  final String displayName;
  final String email;
  final String idToken;
}

/// Handles Google Sign-In → Cognito token exchange.
///
/// Flow:
///   1. google_sign_in → Google ID token
///   2. Pass Google ID token to Cognito User Pool as federated credential
///   3. Receive Cognito JWT (id + access + refresh tokens)
///   4. Store tokens in flutter_secure_storage
///   5. Return SignInResult with Cognito sub + profile
class AuthService {
  AuthService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  late final _userPool = CognitoUserPool(_poolId, _clientId, region: _region);

  // ── Sign in ───────────────────────────────────────────────────────────────

  Future<SignInResult> signIn() async {
    // Step 1: Google Sign-In → Google ID token
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw const SignInCancelledException();

    final googleAuth = await googleUser.authentication;
    final googleIdToken = googleAuth.idToken;
    if (googleIdToken == null) throw const GoogleTokenMissingException();

    // Step 2: Exchange Google ID token for Cognito tokens
    // The Cognito User Pool must have Google configured as an identity provider.
    // amazon_cognito_identity_dart_2 federates via initiateAuth with
    // AuthFlow=USER_PASSWORD_AUTH or via hosted UI — for mobile, use hosted UI
    // with a deep-link callback, OR use the Identity Pool federated approach.
    //
    // Simplest approach for mobile: Cognito Hosted UI with redirect.
    // The amazon_cognito_identity_dart_2 package supports this via CognitoUserPool
    // with a custom auth flow, but for Google federation the standard path is:
    //
    //   CognitoUserPool.authenticateUserWithFederatedIdentity(
    //     provider: 'Google',
    //     token: googleIdToken,
    //   )
    //
    // This is NOT in the published amazon_cognito_identity_dart_2 API as of v3.7.
    // The package supports USER_SRP_AUTH and CUSTOM_AUTH but NOT federated identity
    // directly. The real flow requires either:
    //   a) Cognito Hosted UI (browser-based, deep link back) — works but adds UX friction
    //   b) Identity Pool federation (separate from User Pool auth)
    //   c) Custom Lambda trigger in the User Pool that accepts Google tokens
    //
    // ⚠️  SPIKE FINDING: amazon_cognito_identity_dart_2 v3.7 does NOT expose a
    // federated login method that takes a Google ID token and returns a User Pool JWT.
    // This is the package's most significant limitation for this use case.
    //
    // Workaround used in practice: use the Cognito Hosted UI with google_sign_in
    // acting only as a UX helper (to surface the Google account picker), then redirect
    // to Cognito's /oauth2/authorize endpoint which does the actual Google OAuth flow.
    // The app receives a Cognito authorization code via deep link, then exchanges it
    // for tokens via the /oauth2/token endpoint.

    // Cognito Hosted UI approach (what actually works):
    final session = await _exchangeViaHostedUI(googleIdToken);

    // Step 3: Extract Cognito sub + profile from ID token claims
    final claims = _decodeJwtPayload(session.idToken.jwtToken!);
    final sub = claims['sub'] as String;
    final name = (claims['name'] ?? claims['email'] ?? 'Traveller') as String;
    final email = (claims['email'] ?? '') as String;

    // Step 4: Persist tokens
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: session.accessToken.jwtToken),
      _storage.write(key: _keyIdToken, value: session.idToken.jwtToken),
      _storage.write(key: _keyRefreshToken, value: session.refreshToken?.token),
      _storage.write(key: _keyCognitoSub, value: sub),
      _storage.write(key: _keyDisplayName, value: name),
      _storage.write(key: _keyEmail, value: email),
    ]);

    return SignInResult(sub: sub, displayName: name, email: email, idToken: session.idToken.jwtToken!);
  }

  // ── Restore session from storage ──────────────────────────────────────────

  Future<SignInResult?> restoreSession() async {
    final sub = await _storage.read(key: _keyCognitoSub);
    final idToken = await _storage.read(key: _keyIdToken);
    final name = await _storage.read(key: _keyDisplayName) ?? 'Traveller';
    final email = await _storage.read(key: _keyEmail) ?? '';
    if (sub == null || idToken == null) return null;
    return SignInResult(sub: sub, displayName: name, email: email, idToken: idToken);
  }

  // ── Get token for API calls ───────────────────────────────────────────────

  Future<String?> getIdToken() => _storage.read(key: _keyIdToken);

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _storage.deleteAll();
  }

  // ── Private: Hosted UI exchange ───────────────────────────────────────────
  //
  // In practice, this requires launching the Cognito Hosted UI URL in a WebView
  // or using url_launcher + a deep-link callback URI scheme. The actual token
  // exchange is a POST to https://<domain>.auth.<region>.amazoncognito.com/oauth2/token.
  // This is boilerplate that amazon_cognito_identity_dart_2 doesn't abstract.
  //
  // Real implementation needs: url_launcher + app_links (deep link handler)
  // plus an HTTP call to the Cognito token endpoint.

  Future<CognitoUserSession> _exchangeViaHostedUI(String googleIdToken) async {
    // Placeholder — real implementation requires:
    // 1. Launch Cognito Hosted UI URL
    // 2. Receive authorization code via deep link
    // 3. POST code to /oauth2/token
    // 4. Return CognitoUserSession from response
    throw UnimplementedError('Hosted UI exchange — see spike README for full impl');
  }

  // ── Private: JWT decode ───────────────────────────────────────────────────

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw const InvalidTokenException();
    final payload = base64Url.normalize(parts[1]);
    return jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
  }
}

// ── Exceptions ────────────────────────────────────────────────────────────────

final class SignInCancelledException implements Exception {
  const SignInCancelledException();
}

final class GoogleTokenMissingException implements Exception {
  const GoogleTokenMissingException();
}

final class InvalidTokenException implements Exception {
  const InvalidTokenException();
}
