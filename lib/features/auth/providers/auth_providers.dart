import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:traevy/features/auth/models/auth_state.dart';

// Manual Riverpod providers — no @riverpod codegen.
//
// Rationale: the repo uses bare Provider(...)/NotifierProvider(...) throughout
// (see lib/database/providers.dart lines 7-29). The drift_dev ^2.32.1
// dependency pins analyzer ^10 which blocks riverpod_generator ^2.6
// (needs analyzer ^9). Bare providers are isAutoDispose=false (keepAlive)
// by default. Every provider sets a `name:` for Riverpod DevTools.
//
// CRITICAL: This repo uses Riverpod 3.x Notifier<T> + NotifierProvider.
// Never use StateNotifier — grep "StateNotifier" lib/ returns zero hits.

/// Whether Firebase was successfully initialised at app startup.
///
/// Injected via `ProviderScope(overrides: [firebaseReadyProvider
/// .overrideWithValue(...)])` in `main.dart`. Tests override it with `false`
/// to prevent any platform-
/// channel calls (D-15 degrade path). Widget tests override it with `false`
/// to avoid `FirebaseAuth.instance` / `GoogleSignIn.instance` crashes on the
/// test host.
///
/// See lib/features/tracking/providers/tracking_providers.dart for the
/// analogous injection pattern used by `notificationServiceProvider`.
final Provider<bool> firebaseReadyProvider = Provider<bool>(
  (ref) => false,
  name: 'firebaseReadyProvider',
);

/// Global auth state provider. Notifier subscribes to
/// `FirebaseAuth.instance.authStateChanges()` when `firebaseReady=true`,
/// or sets `AuthGuest` immediately when `firebaseReady=false` (D-15).
///
/// Implemented in Plan 09-03. Declaration here so Wave 0 RED contracts
/// compile and downstream providers can depend on it.
final NotifierProvider<AuthStateNotifier, AuthState>
    authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
  name: 'authStateProvider',
);

/// Auth state notifier. Implementation is completed in Plan 09-03 when
/// Firebase platform-channel dependencies are wired (AuthService,
/// FirebaseAuth stream subscription, token cache).
///
/// Plan 09-02 declares the shell so [authStateProvider] compiles and
/// Wave 0 sealed-subtype tests pass.
class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    if (!firebaseReady) {
      return const AuthGuest();
    }
    // Full stream subscription implemented in Plan 09-03.
    // Return AuthLoading as the initial state while Firebase is ready but
    // the authStateChanges stream has not yet emitted.
    return const AuthLoading();
  }
}
