// Wave 0 compile-probe test — google_sign_in 7.2.0 API surface verification.
//
// PURPOSE:
//   Pins the exact symbol names, types, and property access paths that
//   AuthService (Plan 09-03) will use, resolving RESEARCH Open Question A2
//   before any implementation code is written.
//
//   Wrong symbol names cause a COMPILE ERROR here, not a runtime failure
//   discovered during integration testing — that is the intent.
//
// VERIFIED idToken ACCESS PATH (against installed google_sign_in 7.2.0):
//   account.authentication.idToken
//
//   Where:
//     account   : GoogleSignInAccount  (returned by authenticate())
//     .authentication : GoogleSignInAuthentication  (synchronous getter — no await)
//     .idToken  : String?  (nullable; null if the SDK could not mint a token)
//
//   This path is SYNCHRONOUS (no additional await).
//   Do NOT use:
//     - account.idToken          (does not exist — v7 removed this top-level field)
//     - account.authentication.accessToken  (does not exist in v7 — use idToken)
//     - GoogleSignIn().signIn()  (v6 constructor-based API — removed in v7)
//
// PACKAGE VERSIONS VERIFIED:
//   google_sign_in         7.2.0   (pub.dev, 2026-05-29)
//   google_sign_in_android 7.2.11
//   firebase_auth          6.5.1
//
// See .planning/phases/09-authentication/09-RESEARCH.md:
//   - Assumptions A2 (API surface, now resolved)
//   - Code Examples §1 (sign-in sequence)
//   - Pitfall 1 (v6 vs v7 API break)
//   - Pitfall 2 (serverClientId required on Android)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Group 1: GoogleSignIn.instance singleton and method surface
  // ---------------------------------------------------------------------------
  group('GoogleSignIn 7.x instance API (compile probe)', () {
    test('GoogleSignIn.instance is accessible as a static singleton', () {
      // Verifies that the singleton pattern (v7) compiles correctly.
      // DO NOT call any method here — platform channel would crash the test
      // host. We confirm the reference itself is non-null.
      //
      // v7 API: GoogleSignIn.instance  (replaces v6 GoogleSignIn() constructor)
      final instance = GoogleSignIn.instance;
      expect(instance, isNotNull);
    });

    test('initialize method tear-off is a function (not null)', () {
      // Verifies `initialize` exists and has the expected signature:
      //   Future<void> initialize({String? serverClientId, ...})
      //
      // DO NOT call it — hits GoogleSignInPlatform.instance.init() which
      // requires a registered platform plugin.
      final Future<void> Function({
        String? clientId,
        String? serverClientId,
        String? nonce,
        String? hostedDomain,
      })
      initTearOff = GoogleSignIn.instance.initialize;
      expect(initTearOff, isNotNull);
    });

    test('authenticate method tear-off is a function (not null)', () {
      // Verifies `authenticate` exists:
      //   Future<GoogleSignInAccount> authenticate({List<String> scopeHint = []})
      //
      // v7 replacement for v6's `signIn()`. Throws GoogleSignInException on
      // failure (including cancel) rather than returning null.
      //
      // DO NOT call it — triggers Android Credential Manager, crashes test host.
      final Future<GoogleSignInAccount> Function({
        List<String> scopeHint,
      })
      authenticateTearOff = GoogleSignIn.instance.authenticate;
      expect(authenticateTearOff, isNotNull);
    });

    test('supportsAuthenticate method tear-off is a function (not null)', () {
      // Verifies `supportsAuthenticate` exists:
      //   bool supportsAuthenticate()
      //
      // Used by AuthService to guard the authenticate() call on platforms
      // that provide a different sign-in path (e.g., web FedCM).
      //
      // DO NOT call it — delegates to GoogleSignInPlatform.instance which
      // may not be registered in the test isolate.
      final bool Function() supportsTearOff =
          GoogleSignIn.instance.supportsAuthenticate;
      expect(supportsTearOff, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: GoogleSignInAuthentication — the idToken access path
  // ---------------------------------------------------------------------------
  group('GoogleSignInAuthentication idToken access path (compile probe)', () {
    test(
      'GoogleSignInAuthentication can be constructed with a known idToken',
      () {
        // Verifies the SYNCHRONOUS getter chain:
        //   account.authentication  → GoogleSignInAuthentication
        //   .idToken                → String?
        //
        // GoogleSignInAuthentication is a plain Dart class with a public
        // `const` constructor — safe to instantiate without platform channels.
        //
        // AuthService reads the idToken via:
        //   final auth = account.authentication;
        //   final idToken = auth.idToken;  // nullable; handle null as failure
        const auth = GoogleSignInAuthentication(idToken: 'probe_token_value');
        expect(auth.idToken, 'probe_token_value');
      },
    );

    test(
      'GoogleSignInAuthentication with null idToken represents missing token',
      () {
        // Verifies that idToken is `String?` (nullable).
        // When null, AuthService must treat it as a sign-in failure (no usable
        // credential for FirebaseAuth). This typically means serverClientId was
        // not provided (RESEARCH Pitfall 2).
        const auth = GoogleSignInAuthentication(idToken: null);
        expect(auth.idToken, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 3: GoogleAuthProvider.credential — Firebase credential construction
  // ---------------------------------------------------------------------------
  group('GoogleAuthProvider credential (compile probe)', () {
    test(
      'GoogleAuthProvider.credential accepts named idToken parameter',
      () {
        // Verifies the firebase_auth credential factory used by AuthService:
        //   GoogleAuthProvider.credential(idToken: auth.idToken)
        //
        // This is a pure Dart object — no platform channel involved.
        // The credential is then passed to FirebaseAuth.signInWithCredential.
        //
        // IMPORTANT: Do NOT pass accessToken here. v7 removes accessToken from
        // GoogleSignInAuthentication; Firebase requires idToken for the Google
        // provider (RESEARCH Pitfall 1 — v6 vs v7 API break).
        final credential = GoogleAuthProvider.credential(
          idToken: 'test_id_token',
        );
        expect(credential, isNotNull);
      },
    );

    test(
      'GoogleAuthProvider.credential with both idToken and accessToken compiles',
      () {
        // GoogleAuthProvider.credential accepts both parameters; in v7 we only
        // need idToken. Document that accessToken is optional and absent from
        // GoogleSignInAuthentication in v7 (there is no accessToken field).
        final credential = GoogleAuthProvider.credential(
          idToken: 'test_id_token',
          accessToken: null,
        );
        expect(credential, isNotNull);
      },
    );
  });
}
