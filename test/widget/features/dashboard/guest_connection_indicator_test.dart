// Widget tests for the guest "not connected" indicator (Phase 20 Plan 02,
// AUTH-04, SC#3, D-06).
//
// Asserts the non-nagging contract:
//   * AuthGuest  → a passive `cloud_off` IconButton is visible.
//   * AuthSignedIn / AuthLoading → the indicator renders nothing
//     (SizedBox.shrink), so a signed-in user never sees a stale badge and
//     the loading state never flashes it.
//   * Tapping the indicator (user-initiated, NOT auto-shown) opens the
//     existing sign-in sheet — proving the CTA path is reachable from the
//     dashboard without leaving it.
//
// Pattern mirrors onboarding_screen_test.dart / settings_screen_test.dart:
// _FakeAuthNotifier + firebaseReadyProvider override=false (no platform
// channels), MaterialApp(theme: buildLightTheme()) so TraevyTokensExt is
// present.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/dashboard/widgets/guest_connection_indicator.dart';
import 'package:traevy/features/onboarding/widgets/google_continue_button.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Minimal fake [AuthStateNotifier] returning a fixed [AuthState].
///
/// Extends [AuthStateNotifier] so the `authStateProvider.overrideWith`
/// factory type-check passes (Riverpod 3.x requires the factory to return
/// the exact Notifier subtype declared in the provider). Returns a
/// configurable fixed state without subscribing to Firebase streams.
class _FakeAuthNotifier extends AuthStateNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump a [GuestConnectionIndicator] inside a ProviderScope with [authState].
///
/// `firebaseReady=false` keeps the sign-in sheet on its degrade path (the
/// Google CTA renders disabled), so no real Firebase / GoogleSignIn platform
/// channel is exercised when the sheet opens.
Future<void> _pumpIndicator(
  WidgetTester tester, {
  required AuthState authState,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(false),
        authStateProvider.overrideWith(() => _FakeAuthNotifier(authState)),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: Center(child: GuestConnectionIndicator()),
        ),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GuestConnectionIndicator (AUTH-04, SC#3, D-06)', () {
    testWidgets('guest mode shows the cloud_off indicator', (tester) async {
      await _pumpIndicator(tester, authState: const AuthGuest());

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      // It is a passive IconButton in the header, NOT a snackbar/dialog/toast.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('signed-in hides the indicator', (tester) async {
      await _pumpIndicator(
        tester,
        authState: const AuthSignedIn(
          uid: 'u1',
          name: kPlaceholderUserName,
          email: 'you@traevy.app',
        ),
      );

      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('loading hides the indicator (no flash)', (tester) async {
      await _pumpIndicator(tester, authState: const AuthLoading());

      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('tapping the indicator opens the sign-in sheet', (
      tester,
    ) async {
      await _pumpIndicator(tester, authState: const AuthGuest());

      await tester.tap(find.byIcon(Icons.cloud_off_outlined));
      await tester.pumpAndSettle();

      // The sign-in sheet content is now shown (user-initiated CTA, D-06).
      expect(find.text(kCopySignInSheetHeadline), findsOneWidget);
      expect(find.byType(GoogleContinueButton), findsOneWidget);
    });
  });
}
