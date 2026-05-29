// Widget tests for the wired OnboardingScreen (Phase 9 Plan 05, AUTH-03).
//
// Asserts that tapping "Continue with Google" invokes AuthService.signIn()
// (D-08 wiring). Uses hand-rolled fakes via implements+noSuchMethod so no
// real Firebase / GoogleSignIn platform channels are exercised.
//
// Pattern mirrors test/widget/features/settings/settings_screen_test.dart:
// _FakeUserPreferencesDao + ProviderScope overrides + _pumpScreen helper.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/services/auth_service.dart';
import 'package:traevy/features/onboarding/screens/onboarding_screen.dart';
import 'package:traevy/features/onboarding/widgets/google_continue_button.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Captures every `signIn()` call. Configurable return value allows tests to
/// exercise both the first-sign-in path (returns true) and the repeat path
/// (returns false).
///
/// Uses implements+noSuchMethod so no real FirebaseAuth / GoogleSignIn
/// platform channels are invoked (same discipline as _FakeUserPreferencesDao
/// in settings_screen_test.dart).
class _FakeAuthService implements AuthService {
  _FakeAuthService({bool firstSignIn = false}) : _firstSignIn = firstSignIn;

  final bool _firstSignIn;
  int signInCallCount = 0;

  @override
  Future<bool> signIn() async {
    signInCallCount++;
    return _firstSignIn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

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

/// Pump [OnboardingScreen] inside a ProviderScope with the given overrides.
///
/// [fakeAuthService] overrides [authServiceProvider] so taps on the button
/// exercise [_FakeAuthService.signIn] instead of the real Firebase sequence.
/// [firebaseReady] controls the D-15 disabled-state path.
/// [authState] controls what the auth gate resolves to (used for
/// first-sign-in navigation assertions).
Future<void> _pumpOnboardingScreen(
  WidgetTester tester, {
  required _FakeAuthService fakeAuthService,
  bool firebaseReady = true,
  AuthState authState = const AuthGuest(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(fakeAuthService),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
        authStateProvider.overrideWith(
          () => _FakeAuthNotifier(authState),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const OnboardingScreen(),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OnboardingScreen — Continue with Google wiring (AUTH-03)', () {
    testWidgets(
      'tapping Continue with Google invokes AuthService.signIn()',
      (tester) async {
        final fakeService = _FakeAuthService();
        await _pumpOnboardingScreen(tester, fakeAuthService: fakeService);

        // The GoogleContinueButton should be present and tappable.
        expect(find.byType(GoogleContinueButton), findsOneWidget);

        await tester.tap(find.byType(GoogleContinueButton));
        // pumpAndSettle waits for the async signIn() future + any animations.
        await tester.pumpAndSettle();

        expect(fakeService.signInCallCount, equals(1));
      },
    );

    testWidgets(
      'tapping Continue with Google twice invokes signIn() twice',
      (tester) async {
        final fakeService = _FakeAuthService();
        await _pumpOnboardingScreen(tester, fakeAuthService: fakeService);

        await tester.tap(find.byType(GoogleContinueButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(GoogleContinueButton));
        await tester.pumpAndSettle();

        expect(fakeService.signInCallCount, equals(2));
      },
    );

    testWidgets(
      'firebaseReady=false: button is disabled (Semantics enabled:false)',
      (tester) async {
        final fakeService = _FakeAuthService();
        await _pumpOnboardingScreen(
          tester,
          fakeAuthService: fakeService,
          firebaseReady: false,
        );

        // Button is present but wrapped in Semantics(enabled: false).
        final semanticsData = tester.getSemantics(
          find.byType(GoogleContinueButton).first,
        );
        // enabled=false means the hasEnabledState flag is set and
        // isEnabled is false.
        expect(semanticsData.hasFlag(SemanticsFlag.isEnabled), isFalse);

        // Tapping must NOT invoke signIn().
        await tester.tap(find.byType(GoogleContinueButton));
        await tester.pumpAndSettle();
        expect(fakeService.signInCallCount, equals(0));
      },
    );

    testWidgets(
      'firebaseReady=false: disabled button shows kCopySignInDisabledTooltip',
      (tester) async {
        final fakeService = _FakeAuthService();
        await _pumpOnboardingScreen(
          tester,
          fakeAuthService: fakeService,
          firebaseReady: false,
        );

        // The Tooltip widget wrapping the disabled button should be present
        // with the correct message.
        final tooltipFinder = find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == kCopySignInDisabledTooltip,
        );
        expect(tooltipFinder, findsOneWidget);
      },
    );
  });
}
