import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/services/auth_service.dart';

/// Riverpod 3.x wiring for the authentication feature.
///
/// Manual provider declarations (no `@riverpod` annotation) per Phase 1
/// D-12: `riverpod_generator` / `custom_lint` / `riverpod_lint` pin
/// `analyzer ^9` while `drift_dev 2.32.1` pins `analyzer ^10`, so the
/// combination is not installable today. See the Phase 1 comment in
/// `lib/database/providers.dart` for the canonical statement of this
/// constraint. When the ecosystem catches up, a later plan will migrate
/// this file to the `@Riverpod` annotation form.
///
/// Lifecycle notes:
///   * Every provider below uses bare `Provider(...)` /
///     `NotifierProvider(...)`, which in Riverpod 3.x defaults to
///     `isAutoDispose = false` — the manual equivalent of the codegen
///     annotation `@Riverpod(keepAlive: true)`. Do NOT switch any of
///     these to `.autoDispose`.
///   * `AuthStateNotifier` cancels its `StreamSubscription<User?>` in
///     `ref.onDispose` so test containers (`container.dispose()`)
///     release the Firebase stream cleanly.
///
/// CRITICAL: This repo uses Riverpod 3.x `Notifier<T>` + `NotifierProvider`.
/// Never use `StateNotifier` — `grep "StateNotifier" lib/` returns zero hits.

/// Whether Firebase was successfully initialised at app startup.
///
/// Injected via `ProviderScope(overrides: [firebaseReadyProvider
/// .overrideWithValue(...)])` in `main.dart`. Tests override it with `false`
/// to prevent any platform-channel calls (D-15 degrade path). Widget tests
/// override it with `false` to avoid `FirebaseAuth.instance` /
/// `GoogleSignIn.instance` crashes on the test host.
///
/// See lib/features/tracking/providers/tracking_providers.dart for the
/// analogous injection pattern used by `notificationServiceProvider`.
final Provider<bool> firebaseReadyProvider = Provider<bool>(
  (ref) => false,
  name: 'firebaseReadyProvider',
);

/// The `FirebaseAuth` singleton, exposed as an overridable provider.
///
/// Tests override this with a fake `FirebaseAuth`-implementing object so
/// no real Firebase platform channels are invoked (RESEARCH §Validation
/// Architecture). Matches the `notificationServiceProvider` override note
/// in `settings_providers.dart` — same rationale: singleton crashes on
/// the test host, so it MUST be provider-injected.
final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
  name: 'firebaseAuthProvider',
);

/// The `GoogleSignIn` singleton, exposed as an overridable provider.
///
/// Tests override this with a fake so no Credential Manager or platform
/// channel is involved. The real instance is only reached at runtime after
/// `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)`
/// has been called from `main()`.
final Provider<GoogleSignIn> googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn.instance,
  name: 'googleSignInProvider',
);

/// `FlutterSecureStorage` instance for caching the Firebase ID token.
///
/// Token is written under `kFirebaseIdTokenKey` by `AuthService.signIn()`.
/// Tests override this with a fake to avoid Android Keystore platform-channel
/// calls and to assert the exact key written.
final Provider<FlutterSecureStorage> secureStorageProvider =
    Provider<FlutterSecureStorage>(
      (ref) => const FlutterSecureStorage(),
      name: 'secureStorageProvider',
    );

/// `AuthService` constructed with all dependencies injected via `ref.watch`
/// so tests can override each dependency in isolation (RESEARCH §Wave 0 —
/// injectable seams mandate). Mirrors the `trackingServiceControllerProvider`
/// factory in `tracking_providers.dart` lines 78-89.
final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
    secureStorage: ref.watch(secureStorageProvider),
    tripsDao: ref.watch(tripsDaoProvider),
    prefsDao: ref.watch(userPreferencesDaoProvider),
    db: ref.watch(appDatabaseProvider),
  ),
  name: 'authServiceProvider',
);

/// Global auth state provider. Notifier subscribes to
/// `FirebaseAuth.authStateChanges()` when `firebaseReady=true`, or sets
/// `AuthGuest` immediately when `firebaseReady=false` (D-15 degrade path).
///
/// Downstream consumers use an exhaustive `switch` on [AuthState] — never
/// `.when()` (which is for `AsyncValue`, not sealed classes).
final NotifierProvider<AuthStateNotifier, AuthState> authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(
      AuthStateNotifier.new,
      name: 'authStateProvider',
    );

/// Notifier that owns the UI-side [AuthState]. Subscribes to the Firebase
/// auth-state-changes stream in `build()` and cancels via `ref.onDispose`.
///
/// State machine:
///
///   * `AuthLoading`  — initial state when Firebase is ready; waiting for
///     the first `authStateChanges()` event.
///   * `AuthGuest`    — Firebase returned null user, or Firebase is not
///     ready (D-15 degrade path).
///   * `AuthSignedIn` — Firebase returned a non-null user; carries uid,
///     display name, and email.
///
/// Pattern: mirrors `TrackingNotifier` in
/// `lib/features/tracking/providers/tracking_providers.dart` —
/// stream subscription inside `build()`, cancellation in `ref.onDispose`,
/// `state =` assignment for every new event.
///
/// CRITICAL: this class uses `Notifier<AuthState>`, NOT `StateNotifier`.
class AuthStateNotifier extends Notifier<AuthState> {
  StreamSubscription<User?>? _authSub;

  @override
  AuthState build() {
    final firebaseReady = ref.watch(firebaseReadyProvider);

    // D-15 degrade path: Firebase not configured (dev/CI build without
    // google-services.json). Return AuthGuest immediately; do NOT subscribe
    // to authStateChanges() — that would crash on the test host.
    if (!firebaseReady) {
      return const AuthGuest();
    }

    // Cancel the subscription if the provider is disposed (e.g. test
    // container disposal). Mirrors TrackingNotifier.build() / ref.onDispose
    // discipline.
    ref.onDispose(() {
      unawaited(_authSub?.cancel());
    });

    _attach();

    // Return AuthLoading as the initial value before the first stream event.
    // FirebaseAuth.authStateChanges() does NOT emit synchronously, so the
    // notifier will sit in AuthLoading until the first event arrives.
    return const AuthLoading();
  }

  void _attach() {
    final auth = ref.read(firebaseAuthProvider);
    _authSub = auth.authStateChanges().listen(
      (user) {
        if (user == null) {
          state = const AuthGuest();
        } else {
          state = AuthSignedIn(
            uid: user.uid,
            // PII guard: never log user.displayName, user.email, or user.uid.
            // Use kPlaceholderUserName when displayName is absent (e.g.
            // email-only accounts). AUTH-02 fallback contract.
            name: user.displayName ?? kPlaceholderUserName,
            email: user.email ?? '',
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        // WR-03 analog: the Firebase auth stream errored. Do NOT forward
        // error.toString() — it may contain PII (uid, email). Degrade to
        // AuthGuest so the app remains usable without sign-in.
        unawaited(_authSub?.cancel());
        _authSub = null;
        state = const AuthGuest();
      },
    );
  }
}
