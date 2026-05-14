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
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/screens/settings_screen.dart';
import 'package:traevy/features/settings/widgets/account_row.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/features/settings/widgets/settings_section.dart';
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump a [SettingsScreen] with [prefs] as the Riverpod override and a
/// [_FakeUserPreferencesDao] capturing writes.
Future<_FakeUserPreferencesDao> _pumpSettingsScreen(
  WidgetTester tester, {
  UserPreferencesValue prefs = const UserPreferencesValue.defaults(),
}) async {
  final fakeDao = _FakeUserPreferencesDao(prefs);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userPreferencesDaoProvider.overrideWithValue(fakeDao),
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SettingsScreen structure', () {
    testWidgets('renders without error', (WidgetTester tester) async {
      await _pumpSettingsScreen(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('renders 4 SettingsSection blocks', (WidgetTester tester) async {
      await _pumpSettingsScreen(tester);
      expect(find.byType(SettingsSection), findsNWidgets(4));
    });

    testWidgets(
      'renders ACCOUNT, RECORDING, NOTIFICATIONS, APPEARANCE labels',
      (WidgetTester tester) async {
        await _pumpSettingsScreen(tester);
        expect(find.text('ACCOUNT'), findsOneWidget);
        expect(find.text('RECORDING'), findsOneWidget);
        expect(find.text('NOTIFICATIONS'), findsOneWidget);
        expect(find.text('APPEARANCE'), findsOneWidget);
      },
    );

    testWidgets('renders AccountRow with placeholder name+initial',
        (WidgetTester tester) async {
      await _pumpSettingsScreen(tester);
      expect(find.byType(AccountRow), findsOneWidget);
      expect(find.text(kPlaceholderUserName), findsOneWidget);
    });

    testWidgets('does not construct a Phase-7 AppBar with the gear tooltip',
        (WidgetTester tester) async {
      await _pumpSettingsScreen(tester);
      // The settings screen now lives inside MainShell — no AppBar of its own.
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('renders at least 3 TraevyToggle instances in Notifications',
        (WidgetTester tester) async {
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
      (WidgetTester tester) async {
        final dao = await _pumpSettingsScreen(tester);
        // Find the reminder row by its label, then tap the toggle inside.
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
      'UX-04: tapping the weekly summary toggle calls upsert with '
      'weeklyNotificationEnabled=true',
      (WidgetTester tester) async {
        final dao = await _pumpSettingsScreen(tester);
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
        expect(dao.writes.last.weeklyNotificationEnabled, isTrue);
      },
    );

    testWidgets(
      'UX-02: opening theme picker and tapping Dark calls upsert with '
      "darkMode='dark'",
      (WidgetTester tester) async {
        final dao = await _pumpSettingsScreen(tester);
        // Tap the Appearance "Theme" row to open the bottom sheet.
        final themeRow = find.ancestor(
          of: find.text('Theme'),
          matching: find.byType(SettingsRow),
        );
        expect(themeRow, findsOneWidget);
        await tester.tap(themeRow);
        await tester.pumpAndSettle();
        // Bottom sheet has three SettingsRow entries: System / Light / Dark.
        expect(find.text('System'), findsOneWidget);
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
      (WidgetTester tester) async {
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
        // The Daily reminder row label is still present.
        expect(find.text('Daily reminder'), findsOneWidget);
        // The subtitle contains the reminder time when enabled.
        expect(find.textContaining('08:00'), findsOneWidget);
      },
    );
  });
}
