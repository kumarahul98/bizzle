// Widget tests for the Traevy-restyled SettingsScreen (Phase 8 Plan 07).
//
// Replaces the Phase 7 SwitchListTile / RadioListTile assertions with
// TraevyToggle / theme-picker-bottom-sheet assertions while preserving
// the UX-02 (updateDarkMode), UX-04 (updateWeeklyNotificationEnabled),
// and UX-05 (updateReminderEnabled) behavioural wiring.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
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
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
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
  }) async =>
      calls.add('scheduleReminder($hhMm,$includeWeekends)');

  @override
  Future<void> cancelReminder() async => calls.add('cancelReminder');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump a [SettingsScreen] with [prefs] as the Riverpod override and a
/// [_FakeUserPreferencesDao] capturing writes.
Future<_FakeUserPreferencesDao> _pumpSettingsScreen(
  WidgetTester tester, {
  UserPreferencesValue prefs = const UserPreferencesValue.defaults(),
  _FakeNotificationService? notificationService,
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

    testWidgets('renders AccountRow with placeholder name+initial',
        (tester) async {
      await _pumpSettingsScreen(tester);
      expect(find.byType(AccountRow), findsOneWidget);
      expect(find.text(kPlaceholderUserName), findsOneWidget);
    });

    testWidgets('does not construct a Phase-7 AppBar with the gear tooltip',
        (tester) async {
      await _pumpSettingsScreen(tester);
      // The settings screen now lives inside MainShell — no AppBar of its own.
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('renders at least 3 TraevyToggle instances in Notifications',
        (tester) async {
      await _pumpSettingsScreen(tester);
      // Daily reminder + Include weekends + Weekly summary.
      // Account section also has a "Cloud sync" toggle which is a
      // visual placeholder for Phase 9 — so at minimum 4 toggles total.
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
}
