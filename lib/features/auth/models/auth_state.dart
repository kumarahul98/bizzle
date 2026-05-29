import 'package:flutter/foundation.dart';

/// Sealed high-level state of the authentication feature as observed by the
/// UI isolate. Widgets switch exhaustively on this type to decide whether to
/// show a splash screen, a guest shell, or the signed-in shell.
///
/// Why a sealed class:
/// * exhaustive `switch` / pattern matching with no `default` branch — a
///   new variant would be a compile error at every call site, which is
///   what we want;
/// * matches CLAUDE.md's "Use `sealed` classes for finite state" rule for
///   tracking, sync, and direction enums;
/// * consistent with the existing `TrackingState` sealed class in
///   `lib/features/tracking/state/tracking_state.dart`.
///
/// Usage:
/// ```dart
/// final Widget home = switch (ref.watch(authStateProvider)) {
///   AuthLoading()  => const SplashScreen(),
///   AuthGuest()    => const MainShell(),
///   AuthSignedIn() => const MainShell(),
/// };
/// ```
///
/// Never add a `default` branch to a switch on [AuthState]. The sealed
/// contract is the safety net — any future variant must be handled explicitly
/// at every call site.
@immutable
sealed class AuthState {
  const AuthState();
}

/// Firebase is initialising (or the auth-state-changes stream has not yet
/// emitted its first event). The app shows a splash screen until this
/// resolves. This state is always transient — it transitions to either
/// [AuthGuest] or [AuthSignedIn] once the stream fires.
///
/// Const constructor — singleton at every call site (identical()).
final class AuthLoading extends AuthState {
  /// Const constructor — singleton at every call site.
  const AuthLoading();
}

/// No authenticated user. The user has not signed in, has signed out, or
/// Firebase is unconfigured (D-15 degrade path). This is a valid permanent
/// state — not an error — and gives full access to all local features.
///
/// Const constructor — singleton at every call site (identical()).
final class AuthGuest extends AuthState {
  /// Const constructor — singleton at every call site.
  const AuthGuest();
}

/// A Firebase user is authenticated. All three fields are non-nullable; the
/// caller (AuthStateNotifier) must substitute `kPlaceholderUserName` when
/// `User.displayName` is null and an empty string when `User.email` is null.
final class AuthSignedIn extends AuthState {
  /// Construct a signed-in auth state with the Firebase user's identity
  /// fields. All fields are required — the UI contract assumes they are
  /// always present.
  const AuthSignedIn({
    required this.uid,
    required this.name,
    required this.email,
  });

  /// Firebase Authentication user identifier (`User.uid`).
  final String uid;

  /// Display name to show in the UI. Never empty — the notifier substitutes
  /// the placeholder name constant when `User.displayName` is null.
  final String name;

  /// Email address. Empty string when the Firebase user has no email.
  final String email;
}
