import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';

/// Service that owns the Google → Firebase sign-in sequence, ID-token
/// cache, and transactional userId backfill.
///
/// All dependencies are constructor-injected so tests override them with
/// fakes and no platform channels are exercised in the test host (RESEARCH
/// §Validation Architecture, PATTERNS §auth_service.dart).
///
/// Sign-in sequence (AUTH-01):
///   1. Guard `GoogleSignIn.instance.supportsAuthenticate()`.
///   2. Call `googleSignIn.authenticate()` (google_sign_in v7 API — NOT
///      v6 `signIn()`). See the probe test for verified symbol paths.
///   3. Build `GoogleAuthProvider.credential(idToken: ...)` from the
///      synchronous `.authentication.idToken` field.
///   4. Call `firebaseAuth.signInWithCredential(credential)`.
///   5. Cache the Firebase ID token under [kFirebaseIdTokenKey] in
///      `flutter_secure_storage` (Android Keystore — CLAUDE.md, D-10).
///   6. Backfill both DAOs transactionally (D-11, Pitfall 7 ordering).
///   7. Return `tripsChanged > 0` as the first-sign-in signal (D-12).
///
/// Security invariants:
///   * The Firebase ID token is NEVER passed to `print` / `debugPrint` /
///     `log` (RESEARCH Security Domain, T-09-03-02).
///   * The token is stored in `flutter_secure_storage`, never in
///     `shared_preferences` or plain text (CLAUDE.md, T-09-03-01).
class AuthService {
  /// Construct [AuthService] with all dependencies injected.
  ///
  /// [firebaseAuth], [googleSignIn], and [db] are optional so tests can
  /// construct the service with only the storage/DAO fakes they need.
  /// Those tests skip the `signIn()` call itself; the constructor gate
  /// confirms the shape compiles and instantiates correctly.
  ///
  /// The [firebaseAuth] and [googleSignIn] params are NOT accessed in the
  /// constructor body — they are lazily resolved during `signIn()`. This
  /// allows test code to construct [AuthService] without a live Firebase
  /// app present on the host.
  AuthService({
    required FlutterSecureStorage secureStorage,
    required TripsDao tripsDao,
    required UserPreferencesDao prefsDao,
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    AppDatabase? db,
  }) : _secureStorage = secureStorage,
       _tripsDao = tripsDao,
       _prefsDao = prefsDao,
       _firebaseAuthOverride = firebaseAuth,
       _googleSignInOverride = googleSignIn,
       _db = db;

  final FlutterSecureStorage _secureStorage;
  final TripsDao _tripsDao;
  final UserPreferencesDao _prefsDao;

  // Lazy: accessed at signIn()-call time, not construction time, so test
  // code can construct AuthService without a live Firebase app.
  final FirebaseAuth? _firebaseAuthOverride;
  final GoogleSignIn? _googleSignInOverride;
  final AppDatabase? _db;

  FirebaseAuth get _firebaseAuth =>
      _firebaseAuthOverride ?? FirebaseAuth.instance;

  GoogleSignIn get _googleSignIn =>
      _googleSignInOverride ?? GoogleSignIn.instance;

  /// Perform the full Google → Firebase sign-in sequence.
  ///
  /// Returns `true` when the trips backfill updated at least one row
  /// (D-12 first-sign-in signal — caller navigates to the success screen).
  /// Returns `false` when the backfill changed zero rows (already signed
  /// in on this device, or no local trips existed).
  ///
  /// Throws [GoogleSignInException] when the user cancels the account
  /// picker — callers should treat the cancel code as a silent no-op
  /// (stay in guest state). Other exceptions propagate so the UI can
  /// surface "Couldn't sign in."
  ///
  /// Ordering (RESEARCH Pitfall 7 / PATTERNS §token-async-boundary):
  ///   The backfill is awaited inside a single `db.transaction` BEFORE
  ///   this method returns so the auth-stream re-render cannot race a
  ///   stale userId.
  Future<bool> signIn() async {
    // Step 1: Guard — only proceed if the platform supports authenticate().
    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'GoogleSignIn.supportsAuthenticate() returned false on this platform.',
      );
    }

    // Step 2: Invoke the v7 Google sign-in flow. Throws
    // GoogleSignInException on failure (including user cancel).
    final account = await _googleSignIn.authenticate();

    // Step 3: Read idToken via the SYNCHRONOUS getter verified in the
    // probe test. Null means serverClientId was not provided (Pitfall 2).
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw StateError(
        'GoogleSignIn returned a null idToken. '
        'Ensure kGoogleServerClientId is the Web OAuth client ID '
        '(RESEARCH Pitfall 2 — omitting it yields no idToken on Android).',
      );
    }

    // Step 4: Exchange for a Firebase credential and sign in.
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final user = userCredential.user!;

    // Step 5: Cache the Firebase ID token in flutter_secure_storage.
    // SECURITY (T-09-03-02): never log the token, credential, or the
    // output of getIdToken() — any format.
    final firebaseIdToken = await user.getIdToken() ?? '';
    await _secureStorage.write(
      key: kFirebaseIdTokenKey,
      value: firebaseIdToken,
    );

    // Step 6: Backfill both DAOs atomically (D-11).
    // uid captured before the transaction — build any value BEFORE the
    // mutating call (Pitfall 3 discipline).
    final uid = user.uid;
    var tripsChanged = 0;
    final db = _db;
    if (db != null) {
      await db.transaction(() async {
        tripsChanged = await _tripsDao.backfillUserId(uid);
        await _prefsDao.backfillUserId(uid);
      });
    } else {
      // No AppDatabase injected (test-only path; signIn() is skipped
      // in all unit tests). Run the calls without a transaction wrapper.
      tripsChanged = await _tripsDao.backfillUserId(uid);
      await _prefsDao.backfillUserId(uid);
    }

    // Step 7: Return the first-sign-in signal (D-12).
    return tripsChanged > 0;
  }
}
