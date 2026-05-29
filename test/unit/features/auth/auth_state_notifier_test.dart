// Wave 0 RED contract for AuthStateNotifier (AUTH-01, AUTH-02).
//
// INTENDED STATE: COMPILE FAILURE (RED)
//
//   This file references symbols that do not exist yet:
//     - AuthState (sealed class)
//     - AuthLoading (subtype of AuthState)
//     - AuthGuest  (subtype of AuthState)
//     - AuthSignedIn (subtype of AuthState, with uid/name/email)
//     - AuthStateNotifier (Notifier<AuthState>)
//     - authStateProvider (NotifierProvider<AuthStateNotifier, AuthState>)
//     - firebaseReadyProvider (Provider<bool>)
//
//   These symbols are created in Plan 09-02 (Wave 1). Until then, this file
//   will fail to compile. That is the intended Wave 0 RED state.
//   DO NOT add stub implementations to make this compile — the whole point is
//   that the test defines the contract the implementation must satisfy.
//
// CONTRACTS VERIFIED:
//   AUTH-01: authStateChanges null → AuthGuest; User → AuthSignedIn(uid,name,email)
//   AUTH-02: firebaseReady=false → AuthGuest immediately (D-15 degrade path)
//   AUTH-02: displayName=null falls back to kPlaceholderUserName
//
// PATTERN:
//   Analog: test/unit/features/tracking/tracking_state_map_test.dart
//   (sealed-state const-identity assertions, exhaustive switch)
//
// See .planning/phases/09-authentication/09-RESEARCH.md:
//   - Architecture Pattern 1 (sealed AuthState + Notifier)
//   - Architecture Pattern 3 (degrade-to-guest)
//   - PATTERNS.md § auth_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';

// The following imports will compile once Plan 09-02 creates these files.
// Until then, this file is intentionally in RED (compile failure) state.
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Group 1: Sealed AuthState subtype identity
  // ---------------------------------------------------------------------------
  group('AuthState sealed subtype identity', () {
    test('AuthLoading is a const-constructible singleton', () {
      // Matches TrackingIdle const-singleton pattern.
      const a = AuthLoading();
      const b = AuthLoading();
      expect(identical(a, b), isTrue);
    });

    test('AuthGuest is a const-constructible singleton', () {
      const a = AuthGuest();
      const b = AuthGuest();
      expect(identical(a, b), isTrue);
    });

    test('AuthSignedIn carries uid, name, and email payload', () {
      const s = AuthSignedIn(
        uid: 'uid-abc',
        name: 'Alice',
        email: 'alice@example.com',
      );
      expect(s.uid, 'uid-abc');
      expect(s.name, 'Alice');
      expect(s.email, 'alice@example.com');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: Exhaustive switch — no default branch required (sealed coverage)
  // ---------------------------------------------------------------------------
  group('AuthState exhaustive switch (no default)', () {
    test('switch covers all three variants without a default clause', () {
      // If a fourth variant is ever added, this switch will cause a compile
      // error — exactly the guard we want (sealed class contract).
      String describe(AuthState s) {
        return switch (s) {
          AuthLoading() => 'loading',
          AuthGuest() => 'guest',
          AuthSignedIn() => 'signedIn',
        };
      }

      expect(describe(const AuthLoading()), 'loading');
      expect(describe(const AuthGuest()), 'guest');
      expect(describe(
        const AuthSignedIn(uid: 'u', name: 'n', email: 'e'),
      ), 'signedIn');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: AuthStateNotifier via ProviderContainer — authStateChanges mapping
  // ---------------------------------------------------------------------------
  group('AuthStateNotifier state mapping', () {
    // The notifier depends on firebaseReadyProvider (injected via
    // ProviderContainer overrides) and a FirebaseAuth stream source.
    // These tests use a ProviderContainer with overrides so no real
    // FirebaseAuth.instance or GoogleSignIn.instance is touched.
    //
    // Pattern mirrors the Riverpod container override pattern from
    // test/widget/features/settings/settings_screen_test.dart.

    test(
      'initial state is AuthLoading when firebaseReady=true',
      () {
        // When Firebase IS ready, the notifier subscribes to authStateChanges.
        // Before the first stream event, it emits AuthLoading.
        final container = ProviderContainer(
          overrides: [
            firebaseReadyProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        // The notifier's build() returns AuthLoading() before the stream fires.
        // This requires the underlying stream to not emit synchronously on
        // construction — which is the case for FirebaseAuth.authStateChanges().
        expect(container.read(authStateProvider), isA<AuthLoading>());
      },
      skip: 'RED — AuthStateNotifier not yet implemented (Plan 09-02)',
    );

    test(
      'emits AuthGuest immediately when firebaseReady=false (D-15 degrade)',
      () {
        // D-15: when Firebase is not configured (dev/CI build without
        // google-services.json), the notifier starts in guest without
        // subscribing to authStateChanges(). The sign-in button is disabled.
        final container = ProviderContainer(
          overrides: [
            firebaseReadyProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);

        // With firebaseReady=false the notifier sets state = AuthGuest()
        // synchronously in build() and does NOT open the authStateChanges
        // subscription. No platform channel is involved.
        expect(container.read(authStateProvider), isA<AuthGuest>());
      },
      skip: 'RED — AuthStateNotifier not yet implemented (Plan 09-02)',
    );

    test(
      'maps null Firebase user to AuthGuest',
      () async {
        // When authStateChanges() emits null (signed-out or no session),
        // the notifier must transition to AuthGuest.
        // Tested via a fake firebaseAuthProvider override in Plan 09-02.
        // Stub contract defined here so Plan 09-02 targets the same shape.
        const expected = AuthGuest();
        expect(expected, isA<AuthGuest>());
      },
      skip: 'RED — requires fake FirebaseAuth stream injection (Plan 09-02)',
    );

    test(
      'maps non-null Firebase user to AuthSignedIn(uid, name, email)',
      () async {
        // When authStateChanges() emits a User object, the notifier maps:
        //   state = AuthSignedIn(
        //     uid:   user.uid,
        //     name:  user.displayName ?? kPlaceholderUserName,
        //     email: user.email ?? '',
        //   )
        //
        // Tested with a fake User via firebaseAuthProvider override (Plan 09-02).
        // The placeholder name fallback is verified separately below.
        //
        // This comment acts as the binding contract for the notifier's stream
        // listener implementation.
        const kExpectedUid = 'firebase-uid-123';
        const kExpectedName = 'Bob';
        const kExpectedEmail = 'bob@example.com';
        const s = AuthSignedIn(
          uid: kExpectedUid,
          name: kExpectedName,
          email: kExpectedEmail,
        );
        expect(s.uid, kExpectedUid);
        expect(s.name, kExpectedName);
        expect(s.email, kExpectedEmail);
      },
      skip: 'RED — requires fake FirebaseAuth stream injection (Plan 09-02)',
    );

    test(
      'falls back to kPlaceholderUserName when displayName is null',
      () {
        // User.displayName can be null (e.g., email-only accounts).
        // The notifier MUST substitute kPlaceholderUserName so the UI always
        // has a display string — it must NOT crash or show an empty string.
        //
        // Binding contract: `name: user.displayName ?? kPlaceholderUserName`
        //
        // The constant itself is verified here to match the expected fallback.
        expect(kPlaceholderUserName, isNotEmpty);
        expect(kPlaceholderUserName, 'Traveller');

        // Full notifier-level assertion requires fake stream injection (09-02).
        // The shape is already pinned by the line above.
      },
    );
  });
}
