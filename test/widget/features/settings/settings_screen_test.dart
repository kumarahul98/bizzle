// Widget tests for the Traevy-restyled SettingsScreen (Phase 8 Plan 07,
// extended Phase 9 Plan 05).
//
// Phase 8: Replaces Phase 7 SwitchListTile / RadioListTile assertions with
// TraevyToggle / theme-picker-bottom-sheet assertions while preserving
// the UX-02 (updateDarkMode), UX-04 (updateWeeklyNotificationEnabled),
// and UX-05 (updateReminderEnabled) behavioural wiring.
//
// Phase 9 (AUTH-01): Adds state-aware _AccountSection group — guest override
// renders "Sign in to back up" row; signedIn override renders populated
// AccountRow (constructor swap only, D-07).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/services/auth_service.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/screens/settings_screen.dart';
import 'package:traevy/features/settings/widgets/account_row.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/features/settings/widgets/settings_section.dart';
import 'package:traevy/notifications/notification_service.dart';
import 'package:traevy/shared/widgets/traevy_toggle.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Captures every [upsert] call so tests can assert on the post-write value
/// (UX-02, UX-04, UX-05 behavioural wiring).
class _FakeUserPreferencesDao implements UserPreferencesDao {
  _FakeUserPreferencesDao(this._current);

  UserPreferencesValue _current;
  final List<UserPreferencesValue> writes = <UserPreferencesValue>[];

  @override
  Future<void> upsert(UserPreferencesValue value) async {
    writes.add(value);
    _current = value;
  }

  @override
  Future<UserPreferencesValue> getOrDefault() async => _current;

  @override
  Stream<UserPreferencesValue> watch() => Stream<UserPreferencesValue>.value(
    _current,
  );

  // The DAO has many auto-generated members from DatabaseAccessor; we never
  // exercise them in widget tests, so any access in tests should surface
  // immediately as a noSuchMethod failure rather than silently no-op.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal fake [AuthStateNotifier] that returns a fixed [AuthState].
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

/// Captures `signOut()` calls so the Sign-out row wiring can be asserted
/// without touching real FirebaseAuth / GoogleSignIn platform channels.
class _FakeAuthService implements AuthService {
  int signOutCallCount = 0;

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records every NotificationService call so the tests can keep the
/// real `flutter_local_notifications` plugin out of the test isolate
/// (it crashes with a LateInitializationError on the host).
class _FakeNotificationService implements NotificationService {
  final List<String> calls = <String>[];

  @override
  Future<void> scheduleWeeklySummary(AppDatabase db) async =>
      calls.add('scheduleWeeklySummary');

  @override
  Future<void> cancelWeeklySummary() async => calls.add('cancelWeeklySummary');

  @override
  Future<void> scheduleReminder({
    required String hhMm,
    required bool includeWeekends,
  }) async => calls.add('scheduleReminder($hhMm,$includeWeekends)');

  @override
  Future<void> cancelReminder() async => calls.add('cancelReminder');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump a [SettingsScreen] with [prefs] as the Riverpod override and a
/// [_FakeUserPreferencesDao] capturing writes.
///
/// [authState] overrides [authStateProvider] so the state-aware
/// `_AccountSection` renders the correct path without hitting Firebase.
/// Defaults to [AuthGuest] (the D-15 degrade path, which is what
/// tests get when firebaseReady=false — the default provider value).
Future<_FakeUserPreferencesDao> _pumpSettingsScreen(
  WidgetTester tester, {
  UserPreferencesValue prefs = const UserPreferencesValue.defaults(),
  _FakeNotificationService? notificationService,
  AuthState authState = const AuthGuest(),
  AuthService? authService,
}) async {
  final fakeDao = _FakeUserPreferencesDao(prefs);
  final fakeNotif = notificationService ?? _FakeNotificationService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userPreferencesDaoProvider.overrideWithValue(fakeDao),
        notificationServiceProvider.overrideWithValue(fakeNotif),
        userPreferenceProvider.overrideWith(
          (ref) => Stream<UserPreferencesValue>.value(prefs),
        ),
        authStateProvider.overrideWith(() => _FakeAuthNotifier(authState)),
        if (authService != null)
          authServiceProvider.overrideWithValue(authService),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pump();
  return fakeDao;
}

/// Drag the SettingsScreen scroll view until [finder] is visible.
///
/// Tests run at 800×600 — the Notifications and Appearance sections sit
/// below the fold, so toggle taps must scroll into view first.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    -200,
    scrollable: find.byType(Scrollable).first,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SettingsScreen structure', () {
    testWidgets('renders without error', (tester) async {
      await _pumpSettingsScreen(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets(
      'renders 4 SettingsSection blocks',
      (tester) async {
        await _pumpSettingsScreen(tester);
        expect(find.byType(SettingsSection), findsNWidgets(4));
      },
    );

    testWidgets(
      'renders ACCOUNT, RECORDING, NOTIFICATIONS, APPEARANCE labels',
      (tester) async {
        await _pumpSettingsScreen(tester);
        expect(find.text('ACCOUNT'), findsOneWidget);
        expect(find.text('RECORDING'), findsOneWidget);
        expect(find.text('NOTIFICATIONS'), findsOneWidget);
        expect(find.text('APPEARANCE'), findsOneWidget);
      },
    );

    testWidgets(
      'renders AccountRow when signed in (AUTH-01, D-07)',
      (tester) async {
        await _pumpSettingsScreen(
          tester,
          authState: const AuthSignedIn(
            uid: 'u1',
            name: kPlaceholderUserName,
            email: 'you@traevy.app',
          ),
        );
        expect(find.byType(AccountRow), findsOneWidget);
        expect(find.text(kPlaceholderUserName), findsOneWidget);
      },
    );

    testWidgets('does not construct a Phase-7 AppBar with the gear tooltip', (
      tester,
    ) async {
      await _pumpSettingsScreen(tester);
      // The settings screen now lives inside MainShell — no AppBar of its own.
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('renders at least 3 TraevyToggle instances in Notifications', (
      tester,
    ) async {
      await _pumpSettingsScreen(tester);
      // Recording auto-pause + daily reminder + weekly summary toggles.
      // (The old Account "Cloud sync" placeholder toggle was removed — the
      // Account section no longer renders cloud rows.)
      expect(
        find.byType(TraevyToggle),
        findsAtLeast(3),
      );
    });
  });

  group('SettingsScreen wiring — UX-02 / UX-04 / UX-05', () {
    testWidgets(
      'UX-05: tapping the daily reminder toggle calls upsert with '
      'reminderEnabled=true',
      (tester) async {
        final dao = await _pumpSettingsScreen(tester);
        // Scroll the Notifications section into view (it sits below the
        // 600-pixel test viewport).
        await _scrollTo(tester, find.text('Daily reminder'));
        final reminderRow = find.ancestor(
          of: find.text('Daily reminder'),
          matching: find.byType(SettingsRow),
        );
        final reminderToggle = find.descendant(
          of: reminderRow,
          matching: find.byType(TraevyToggle),
        );
        expect(reminderToggle, findsOneWidget);
        await tester.tap(reminderToggle);
        await tester.pump();
        expect(dao.writes, isNotEmpty);
        expect(dao.writes.last.reminderEnabled, isTrue);
      },
    );

    testWidgets(
      'UX-04: tapping the weekly summary toggle flips '
      'weeklyNotificationEnabled and invokes the cancel path',
      (tester) async {
        // Initial state ON so toggle-tap flips to OFF — exercises the
        // cancelWeeklySummary path which does not touch appDatabaseProvider
        // (the schedule path opens Drift, which is undesirable in widget
        // tests).
        final fakeNotif = _FakeNotificationService();
        final dao = await _pumpSettingsScreen(
          tester,
          prefs: const UserPreferencesValue(
            userId: 'test',
            darkMode: kDarkModeSystem,
            morningCutoffHour: 12,
            eveningCutoffHour: 12,
            reminderEnabled: false,
            reminderTime: null,
            weekendReminder: false,
            weeklyNotificationEnabled: true,
          ),
          notificationService: fakeNotif,
        );
        await _scrollTo(tester, find.text('Weekly summary'));
        final weeklyRow = find.ancestor(
          of: find.text('Weekly summary'),
          matching: find.byType(SettingsRow),
        );
        final weeklyToggle = find.descendant(
          of: weeklyRow,
          matching: find.byType(TraevyToggle),
        );
        expect(weeklyToggle, findsOneWidget);
        await tester.tap(weeklyToggle);
        await tester.pump();
        expect(dao.writes, isNotEmpty);
        expect(dao.writes.last.weeklyNotificationEnabled, isFalse);
        expect(fakeNotif.calls, contains('cancelWeeklySummary'));
      },
    );

    testWidgets(
      'UX-02: opening theme picker and tapping Dark calls upsert with '
      "darkMode='dark'",
      (tester) async {
        final dao = await _pumpSettingsScreen(tester);
        await _scrollTo(tester, find.text('Theme'));
        // Tap the Appearance "Theme" row to open the bottom sheet.
        final themeRow = find.ancestor(
          of: find.text('Theme'),
          matching: find.byType(SettingsRow),
        );
        expect(themeRow, findsOneWidget);
        await tester.tap(themeRow);
        await tester.pumpAndSettle();
        // The bottom sheet renders three SettingsRow entries. The Theme row
        // also shows the current darkMode as its subtitle, so 'System' may
        // appear twice — assert at-least-one match for each option, then
        // pick the Light / Dark entries from the bottom sheet specifically.
        expect(find.text('System'), findsAtLeast(1));
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        expect(dao.writes, isNotEmpty);
        expect(dao.writes.last.darkMode, equals(kDarkModeDark));
      },
    );

    testWidgets(
      'reminderEnabled subtitle reflects current state',
      (tester) async {
        await _pumpSettingsScreen(
          tester,
          prefs: const UserPreferencesValue(
            userId: 'test',
            darkMode: kDarkModeSystem,
            morningCutoffHour: 12,
            eveningCutoffHour: 12,
            reminderEnabled: true,
            reminderTime: '08:00',
            weekendReminder: false,
            weeklyNotificationEnabled: false,
          ),
        );
        await _scrollTo(tester, find.text('Daily reminder'));
        // The Daily reminder row label is still present.
        expect(find.text('Daily reminder'), findsOneWidget);
        // The subtitle contains the formatted reminder time when enabled.
        // _formatReminderTime('08:00') uses DateFormat.jm() → '8:00 AM'.
        expect(find.textContaining('8:00'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Phase 9: State-aware _AccountSection (AUTH-01, D-07)
  // ---------------------------------------------------------------------------

  group('SettingsScreen _AccountSection — state-aware (AUTH-01, D-07)', () {
    testWidgets(
      'guest state renders "Sign in to back up" row and no AccountRow',
      (tester) async {
        // Default authState in _pumpSettingsScreen is AuthGuest().
        await _pumpSettingsScreen(tester);
        // Guest path: kCopySettingsGuestSignIn row should be present.
        expect(find.text(kCopySettingsGuestSignIn), findsOneWidget);
        // AccountRow must NOT be present in guest state.
        expect(find.byType(AccountRow), findsNothing);
      },
    );

    testWidgets(
      'signed-in state renders AccountRow with real name and email',
      (tester) async {
        await _pumpSettingsScreen(
          tester,
          authState: const AuthSignedIn(
            uid: 'uid-ada',
            name: 'Ada Lovelace',
            email: 'ada@x.dev',
          ),
        );
        // Signed-in path: AccountRow with real values.
        expect(find.byType(AccountRow), findsOneWidget);
        expect(find.text('Ada Lovelace'), findsOneWidget);
        expect(find.text('ada@x.dev'), findsOneWidget);
        // Guest row must NOT be present.
        expect(find.text(kCopySettingsGuestSignIn), findsNothing);
      },
    );

    testWidgets(
      'guest state hides Sign out, Cloud sync, and Restore rows',
      (tester) async {
        // Default authState is AuthGuest().
        await _pumpSettingsScreen(tester);
        // Only the sign-in CTA belongs to the guest Account section.
        expect(find.text(kCopySettingsGuestSignIn), findsOneWidget);
        expect(find.text(kCopySettingsSignOut), findsNothing);
        expect(find.text('Cloud sync'), findsNothing);
        expect(find.text('Restore from cloud'), findsNothing);
      },
    );

    testWidgets(
      'signed-in Sign out row is tappable and invokes AuthService.signOut()',
      (tester) async {
        final fakeAuth = _FakeAuthService();
        await _pumpSettingsScreen(
          tester,
          authState: const AuthSignedIn(
            uid: 'u',
            name: 'Test User',
            email: 'test@example.com',
          ),
          authService: fakeAuth,
        );
        // Sign out is present only when signed in, and the guest CTA is gone.
        expect(find.text(kCopySettingsSignOut), findsOneWidget);
        expect(find.text(kCopySettingsGuestSignIn), findsNothing);

        await tester.tap(find.text(kCopySettingsSignOut));
        await tester.pump();
        expect(fakeAuth.signOutCallCount, equals(1));
      },
    );
  });
}
