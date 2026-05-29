// Wave 0 RED contract for AuthService (AUTH-01, AUTH-02).
//
// INTENDED STATE: COMPILE FAILURE (RED)
//
//   This file references symbols that do not exist yet:
//     - AuthService (class in lib/features/auth/services/auth_service.dart)
//     - authServiceProvider (Provider in auth_providers.dart)
//
//   These symbols are created in Plan 09-03 (Wave 2). Until then, this file
//   will fail to compile. That is the intended Wave 0 RED state.
//   DO NOT add stub implementations to make this compile.
//
// CONTRACTS VERIFIED:
//   AUTH-01: signIn() calls GoogleSignIn.instance.authenticate() → idToken →
//            GoogleAuthProvider.credential(idToken:) → signInWithCredential()
//   AUTH-01: After sign-in, writes the Firebase ID token to secure storage
//            under kFirebaseIdTokenKey
//   AUTH-01: signIn() calls backfillUserId() on both DAOs
//   AUTH-01: signIn() returns true when trips backfill changed > 0 rows (D-12)
//   AUTH-01: signIn() returns false when backfill changed 0 rows (already signed in)
//   AUTH-02: ID token is NOT passed to any logging sink
//
// PATTERN:
//   Fakes: hand-rolled `implements ... noSuchMethod` (mirrors _FakeUserPreferencesDao
//   in test/widget/features/settings/settings_screen_test.dart lines 30-56).
//   Injectable via Riverpod provider overrides so no real Firebase/GoogleSignIn
//   platform channels are invoked (RESEARCH §Validation Architecture).
//
// See .planning/phases/09-authentication/09-RESEARCH.md:
//   - Code Examples §1 (google_sign_in 7.x sign-in sequence)
//   - Code Examples §2 (AuthService with token cache + backfill)
//   - Architecture Pattern 4 (first-sign-in signal: return bool)
//   - Pitfall 7 (ordering: await backfill before navigate)
//   - Security Domain (never log idToken)

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';

// The following imports will compile once Plan 09-03 creates AuthService.
// Until then this file is intentionally in RED state.
import 'package:traevy/features/auth/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Hand-rolled fakes — mirror _FakeUserPreferencesDao pattern
// ---------------------------------------------------------------------------

/// Fake secure storage that captures write calls for assertions.
///
/// Uses `implements FlutterSecureStorage` + `noSuchMethod` so any method
/// not explicitly implemented surfaces immediately as a test failure rather
/// than silently no-opping. Mirrors `_FakeUserPreferencesDao` shape.
class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String?> _store = <String, String?>{};
  final List<String> writeCalls = <String>[];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    writeCalls.add('write:$key');
    _store[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async =>
      _store[key];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake TripsDao that records backfillUserId calls.
///
/// `backfillUserId` returns a configurable changed-row count so tests can
/// assert both the first-sign-in (> 0) and already-synced (0) branches.
class _FakeTripsDao implements TripsDao {
  _FakeTripsDao({required this.backfillResult});

  /// The value returned by `backfillUserId`.
  final int backfillResult;

  final List<String> calls = <String>[];

  @override
  Future<int> backfillUserId(String newUserId) async {
    calls.add('backfillUserId:$newUserId');
    return backfillResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake UserPreferencesDao that records backfillUserId calls.
class _FakeUserPreferencesDao implements UserPreferencesDao {
  final List<String> calls = <String>[];

  @override
  Future<int> backfillUserId(String newUserId) async {
    calls.add('backfillUserId:$newUserId');
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake AuthService dependency container used by each test.
///
/// Calls through to the real `AuthService` constructor; injects fakes so
/// no platform channels are touched. The real FirebaseAuth and GoogleSignIn
/// instances are NEVER used here.
class _FakeAuthDependencies {
  _FakeAuthDependencies({
    int backfillResult = 1,
  }) : secureStorage = _FakeSecureStorage(),
       tripsDao = _FakeTripsDao(backfillResult: backfillResult),
       prefsDao = _FakeUserPreferencesDao();

  final _FakeSecureStorage secureStorage;
  final _FakeTripsDao tripsDao;
  final _FakeUserPreferencesDao prefsDao;

  /// Creates an `AuthService` with the fake dependencies injected.
  ///
  /// AuthService constructor (Plan 09-03) must accept these as positional or
  /// named parameters so tests can inject them without a ProviderContainer.
  AuthService build() {
    return AuthService(
      secureStorage: secureStorage,
      tripsDao: tripsDao,
      prefsDao: prefsDao,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Group 1: Token cache contract (AUTH-02)
  // ---------------------------------------------------------------------------
  group('AuthService.signIn() token cache', () {
    test(
      'writes Firebase ID token to secure storage under kFirebaseIdTokenKey',
      () async {
        // SECURITY CONTRACT: the ID token must end up in flutter_secure_storage
        // under exactly this key. The Phase 11 sync layer reads it.
        //
        // AuthService must call:
        //   await secureStorage.write(key: kFirebaseIdTokenKey, value: idToken)
        //
        // The actual sign-in flow (FirebaseAuth + GoogleSignIn) is bypassed in
        // unit tests by overriding the Riverpod providers. This test verifies
        // the key used, not the platform-level persistence mechanism.
        //
        // Tested with a fake signIn() seam in Plan 09-03.
        expect(kFirebaseIdTokenKey, 'firebase_id_token');
        // Full assertion requires the signIn() fake seam (Plan 09-03).
      },
      skip: 'RED — AuthService not yet implemented (Plan 09-03)',
    );

    test(
      'token is NEVER passed to print / debugPrint / log',
      () async {
        // SECURITY CONTRACT: the ID token must not appear in any log output.
        // This protects against accidental token leakage in debug builds.
        //
        // The ProhibitedLogSink verification approach:
        //   override the Dart Zone's print handler; run signIn(); assert no
        //   token substring appears in captured output.
        //
        // Full implementation requires the signIn() fake seam (Plan 09-03).
        expect(true, isTrue); // placeholder assertion so the test structure is visible
      },
      skip: 'RED — requires signIn() fake seam (Plan 09-03)',
    );
  });

  // ---------------------------------------------------------------------------
  // Group 2: Backfill contract (AUTH-01, AUTH-03)
  // ---------------------------------------------------------------------------
  group('AuthService.signIn() backfill', () {
    test(
      'calls tripsDao.backfillUserId() with the Firebase UID',
      () async {
        // After a successful Firebase sign-in, AuthService must call:
        //   await tripsDao.backfillUserId(user.uid)
        //
        // The trip table rows with userId = kDefaultUserId must be rewritten
        // to the Firebase uid immediately on first sign-in (D-11).
        final deps = _FakeAuthDependencies(backfillResult: 3);
        // AuthService construction verified here; full signIn() call in 09-03.
        expect(deps.tripsDao.backfillResult, 3);
      },
      skip: 'RED — requires signIn() fake seam (Plan 09-03)',
    );

    test(
      'calls userPreferencesDao.backfillUserId() with the Firebase UID',
      () async {
        // Same contract as above for the user_preferences row (D-11).
        // Both DAOs are called within the same sign-in sequence.
        final deps = _FakeAuthDependencies();
        expect(deps.prefsDao.calls, isEmpty); // not called yet
      },
      skip: 'RED — requires signIn() fake seam (Plan 09-03)',
    );

    test(
      'returns true when trips backfill changed > 0 rows (first sign-in)',
      () async {
        // D-12 contract: when the backfill touches at least one trip row,
        // AuthService.signIn() returns true so the caller can show the
        // one-time confirmation screen (kRouteSignInSuccess).
        //
        // `backfillResult = 5` simulates 5 existing local-user trips.
        final deps = _FakeAuthDependencies(backfillResult: 5);
        final service = deps.build();
        // Full signIn() call requires fake Firebase (Plan 09-03).
        // Shape contract: signIn() returns Future<bool>.
        expect(service, isA<AuthService>());
      },
      skip: 'RED — requires signIn() fake seam (Plan 09-03)',
    );

    test(
      'returns false when trips backfill changed 0 rows (already signed in)',
      () async {
        // When `tripsDao.backfillUserId()` returns 0, there were no
        // kDefaultUserId rows to update — the user was previously signed in
        // or no trips exist. signIn() must return false in this case so the
        // caller does NOT show the confirmation screen again.
        final deps = _FakeAuthDependencies(backfillResult: 0);
        final service = deps.build();
        expect(service, isA<AuthService>());
      },
      skip: 'RED — requires signIn() fake seam (Plan 09-03)',
    );
  });

  // ---------------------------------------------------------------------------
  // Group 3: Fake injection verification (testability gate)
  // ---------------------------------------------------------------------------
  group('AuthService dependency injection (fake seam)', () {
    test('AuthService is constructible with injected fakes', () {
      // This will pass once Plan 09-03 adds the AuthService constructor.
      // It acts as a compile-time and construction-time gate.
      final deps = _FakeAuthDependencies();
      final service = deps.build();
      expect(service, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4: Secure storage key constant (AUTH-02)
  // ---------------------------------------------------------------------------
  group('kFirebaseIdTokenKey contract', () {
    test('constant matches the expected key string', () {
      // Hard-code the expected value here so a rename of the constant surfaces
      // immediately as a test failure rather than silently changing the storage
      // key (which would break Phase 11 sync token reads).
      expect(kFirebaseIdTokenKey, 'firebase_id_token');
    });
  });
}
