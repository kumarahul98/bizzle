// Widget tests for the Phase 20 no-flash root gate in lib/app.dart (D-03).
//
// Asserts all four (auth × has_seen_onboarding) routing cases plus the
// prefs-loading → Splash no-flash case. Mirrors the TraevyApp override set in
// test/unit/features/settings/theme_mode_test.dart (in-memory DB + backfill /
// tracking / history stubs) and the _FakeAuthNotifier pattern from
// test/widget/features/onboarding/onboarding_screen_test.dart.

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/app.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/screens/login_screen.dart';
import 'package:traevy/features/auth/screens/splash_screen.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/shell/main_shell.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';

/// Stub notifier that skips flutter_background_service init on the test host.
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

/// Minimal fake [AuthStateNotifier] returning a fixed [AuthState] without
/// subscribing to Firebase streams.
class _FakeAuthNotifier extends AuthStateNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

UserPreferencesValue _prefs({required bool hasSeenOnboarding}) {
  return UserPreferencesValue(
    userId: kDefaultUserId,
    darkMode: kDarkModeSystem,
    morningCutoffHour: kDefaultDirectionCutoffHour,
    eveningCutoffHour: kDefaultDirectionCutoffHour,
    reminderEnabled: false,
    reminderTime: null,
    weekendReminder: false,
    weeklyNotificationEnabled: false,
    autoPauseEnabled: false,
    hasSeenOnboarding: hasSeenOnboarding,
    homeLat: null,
    homeLng: null,
    officeLat: null,
    officeLng: null,
    backfillMarkerVersion: 0,
  );
}

/// Pump [TraevyApp] with the auth state and a prefs stream overridden.
///
/// [prefsStream] lets a test script `loading` (never emit) vs `data` to prove
/// the no-flash behaviour. firebaseReady=false avoids platform channels.
Future<void> _pumpGate(
  WidgetTester tester, {
  required AuthState authState,
  required Stream<UserPreferencesValue> prefsStream,
}) async {
  // Generous portrait viewport so the LoginScreen's tall sticky-footer
  // column (logo → headline → ticks → Spacer → sign-in → skip → terms) fits
  // without a false overflow: the flutter_test fallback font is much larger
  // than Inter, so a true-to-device width would trip overflows that never
  // occur with the real font (mirrors onboarding_screen_test).
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // closeStreamsSynchronously avoids a Drift stream-close timer remaining
  // pending after the widget tree is disposed (MainShell opens live Drift
  // watches for the signed-in / shell surfaces).
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(false),
        appDatabaseProvider.overrideWithValue(db),
        tripsDaoProvider.overrideWithValue(db.tripsDao),
        syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        userPreferencesDaoProvider.overrideWithValue(db.userPreferencesDao),
        directionBackfillProvider.overrideWith((_) async {}),
        trackingStateProvider.overrideWith(_IdleTrackingNotifier.new),
        allTripSummariesProvider.overrideWith(
          (ref) => const Stream<List<TripSummary>>.empty(),
        ),
        authStateProvider.overrideWith(() => _FakeAuthNotifier(authState)),
        userPreferenceProvider.overrideWith((ref) => prefsStream),
      ],
      child: const TraevyApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('TraevyApp root gate — no-flash composition (Phase 20, D-03)', () {
    testWidgets('AuthLoading → SplashScreen', (tester) async {
      await _pumpGate(
        tester,
        authState: const AuthLoading(),
        prefsStream: Stream.value(_prefs(hasSeenOnboarding: false)),
      );

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MainShell), findsNothing);
    });

    testWidgets('AuthSignedIn → MainShell', (tester) async {
      await _pumpGate(
        tester,
        authState: const AuthSignedIn(uid: 'u1', name: 'Test', email: ''),
        prefsStream: Stream.value(_prefs(hasSeenOnboarding: false)),
      );

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets(
      'AuthGuest + hasSeenOnboarding:true → MainShell',
      (tester) async {
        await _pumpGate(
          tester,
          authState: const AuthGuest(),
          prefsStream: Stream.value(_prefs(hasSeenOnboarding: true)),
        );

        expect(find.byType(MainShell), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );

    testWidgets(
      'AuthGuest + hasSeenOnboarding:false → LoginScreen',
      (tester) async {
        await _pumpGate(
          tester,
          authState: const AuthGuest(),
          prefsStream: Stream.value(_prefs(hasSeenOnboarding: false)),
        );

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(MainShell), findsNothing);
      },
    );

    testWidgets(
      'AuthGuest + prefs loading → SplashScreen (no flash, NOT LoginScreen)',
      (tester) async {
        // A never-emitting stream keeps the AsyncValue in the loading state.
        await _pumpGate(
          tester,
          authState: const AuthGuest(),
          prefsStream: const Stream<UserPreferencesValue>.empty(),
        );

        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(MainShell), findsNothing);
      },
    );
  });
}
