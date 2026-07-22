// Widget tests for the Traevy-restyled SettingsScreen (Phase 8 Plan 07,
// extended Phase 9 Plan 05, extended Phase 15 debug fix).
//
// Phase 8: Replaces Phase 7 SwitchListTile / RadioListTile assertions with
// TraevyToggle / theme-picker-bottom-sheet assertions while preserving
// the UX-02 (updateDarkMode), UX-04 (updateWeeklyNotificationEnabled),
// and UX-05 (updateReminderEnabled) behavioural wiring.
//
// Phase 9 (AUTH-01): Adds state-aware _AccountSection group — guest override
// renders "Sign in to back up" row; signedIn override renders populated
// AccountRow (constructor swap only, D-07).
//
// Phase 15 debug fix: Adds coverage for:
//   - Reminder time picker row renders with kSettingsReminderTimeLabel.
//   - Tapping "Reminder time" row when reminderTime is null shows time picker
//     and persists the chosen time as HH:mm.
//   - Enabling daily reminder with no time set ALWAYS calls
//     maybeRequestNotificationPermissionForUsage (decoupled from reminderTime).
//   - Enabling daily reminder with a time set calls both permission request AND
//     scheduleReminder.
//   - Enabling daily reminder without a time set does NOT call scheduleReminder.

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
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/screens/settings_screen.dart';
import 'package:traevy/features/settings/widgets/account_row.dart';
import 'package:traevy/features/settings/widgets/reminder_day_picker.dart';
import 'package:traevy/features/settings/widgets/reminder_suggestion_card.dart';
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
    required Set<int> days,
  }) async {
    final sorted = days.toList()..sort();
    calls.add('scheduleReminder($hhMm,${sorted.join('-')})');
  }

  @override
  Future<void> cancelReminder() async => calls.add('cancelReminder');

  @override
  Future<void> maybeRequestNotificationPermissionForUsage({
    AppDatabase? db,
    bool forceRequest = false,
  }) async => calls.add('maybeRequestPermission(force=$forceRequest)');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Preferences with the daily reminder explicitly OFF and no time set.
///
/// Phase 33 (D-03) flipped `UserPreferencesValue.defaults()` to reminder-ON at
/// 07:00, so tests that exercise the enable path or the "no time set" subtitle
/// must start from this explicit off-state rather than the defaults.
const UserPreferencesValue _remindersOff = UserPreferencesValue(
  userId: kDefaultUserId,
  darkMode: kDarkModeSystem,
  morningCutoffHour: 12,
  eveningCutoffHour: 12,
  reminderEnabled: false,
  reminderTime: null,
  weekendReminder: false,
  weeklyNotificationEnabled: false,
  autoPauseEnabled: true,
  hasSeenOnboarding: false,
  homeLat: null,
  homeLng: null,
  officeLat: null,
  officeLng: null,
  backfillMarkerVersion: 0,
);

/// Pump a [SettingsScreen] with [prefs] as the Riverpod override and a
/// [_FakeUserPreferencesDao] capturing writes.
///
/// [authState] overrides [authStateProvider] purely so nothing reaches
/// Firebase. Since Phase 32 (D-02) the screen renders no account controls at
/// all, so the state only matters to the SC#4 negative assertions.
Future<_FakeUserPreferencesDao> _pumpSettingsScreen(
  WidgetTester tester, {
  UserPreferencesValue prefs = const UserPreferencesValue.defaults(),
  _FakeNotificationService? notificationService,
  AuthState authState = const AuthGuest(),
  String? reminderSuggestion,
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
        // Phase 33: the suggestion provider watches allTripSummariesProvider,
        // which would open a real Drift stream and leave a pending timer in
        // the widget test. Override it with a fixed value so the whole
        // trip/DB graph stays out of these tests (default: no suggestion).
        reminderSuggestionProvider.overrideWithValue(reminderSuggestion),
        authStateProvider.overrideWith(() => _FakeAuthNotifier(authState)),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: SettingsScreen()),
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
        // Commute (Phase 21 LOC-01), Recording, Notifications, Appearance.
        // Account left for the dashboard avatar sheet in Phase 32 (D-02).
        expect(find.byType(SettingsSection), findsNWidgets(4));
      },
    );

    testWidgets(
      'renders COMMUTE, RECORDING, NOTIFICATIONS, APPEARANCE labels and no '
      'ACCOUNT label',
      (tester) async {
        await _pumpSettingsScreen(tester);
        expect(find.text('ACCOUNT'), findsNothing);
        expect(find.text('COMMUTE'), findsOneWidget);
        expect(find.text('RECORDING'), findsOneWidget);
        expect(find.text('NOTIFICATIONS'), findsOneWidget);
        expect(find.text('APPEARANCE'), findsOneWidget);
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
      // Recording auto-pause + daily reminder + include weekends + weekly
      // summary toggles. At least 3 (Recording) + (Notifications).
      expect(
        find.byType(TraevyToggle),
        findsAtLeast(3),
      );
    });

    testWidgets(
      'Notifications section renders kSettingsReminderTimeLabel row',
      (tester) async {
        await _pumpSettingsScreen(tester);
        await _scrollTo(tester, find.text(kSettingsReminderTimeLabel));
        expect(find.text(kSettingsReminderTimeLabel), findsOneWidget);
      },
    );
  });

  group('SettingsScreen wiring — UX-02 / UX-04 / UX-05', () {
    testWidgets(
      'UX-05: tapping the daily reminder toggle calls upsert with '
      'reminderEnabled=true',
      (tester) async {
        // Phase 33 (D-03) flipped the default reminder ON, so this toggle
        // test starts from an explicitly-OFF row to exercise the enable path.
        final dao = await _pumpSettingsScreen(tester, prefs: _remindersOff);
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
            autoPauseEnabled: false,
            hasSeenOnboarding: false,
            homeLat: null,
            homeLng: null,
            officeLat: null,
            officeLng: null,
            backfillMarkerVersion: 0,
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
      'UX-08: Auto-pause toggle renders ON by default (Phase 27 default '
      'flip, supersedes TRACK-10/SC#5 opt-in)',
      (tester) async {
        // Default prefs (UserPreferencesValue.defaults()) now carry
        // autoPauseEnabled:true — Phase 27 (UX-08) flips auto-pause ON out
        // of the box.
        await _pumpSettingsScreen(tester);
        final autoPauseRow = find.ancestor(
          of: find.text(kSettingsAutoPauseLabelV2),
          matching: find.byType(SettingsRow),
        );
        expect(autoPauseRow, findsOneWidget);
        final toggle = tester.widget<TraevyToggle>(
          find.descendant(
            of: autoPauseRow,
            matching: find.byType(TraevyToggle),
          ),
        );
        expect(toggle.value, isTrue);
        // Subtitle reflects the ON state.
        expect(
          find.descendant(
            of: autoPauseRow,
            matching: find.text(kSettingsAutoPauseOnSubtitle),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TRACK-10: tapping Auto-pause upserts autoPauseEnabled:true '
      'with no notification side-effect',
      (tester) async {
        final fakeNotif = _FakeNotificationService();
        // Explicit OFF starting state (Phase 27 flipped the DEFAULT to ON —
        // this test exercises the OFF-to-ON toggle path specifically, which
        // now requires an explicit fixture rather than relying on
        // defaults()).
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
            weeklyNotificationEnabled: false,
            autoPauseEnabled: false,
            hasSeenOnboarding: false,
            homeLat: null,
            homeLng: null,
            officeLat: null,
            officeLng: null,
            backfillMarkerVersion: 0,
          ),
          notificationService: fakeNotif,
        );
        final autoPauseRow = find.ancestor(
          of: find.text(kSettingsAutoPauseLabelV2),
          matching: find.byType(SettingsRow),
        );
        final toggle = find.descendant(
          of: autoPauseRow,
          matching: find.byType(TraevyToggle),
        );
        expect(toggle, findsOneWidget);
        await tester.tap(toggle);
        await tester.pump();
        expect(dao.writes, isNotEmpty);
        expect(dao.writes.last.autoPauseEnabled, isTrue);
        // No scheduled alarm — auto-pause has no NotificationService effect.
        expect(fakeNotif.calls, isEmpty);
      },
    );

    testWidgets(
      'reminderEnabled subtitle shows the day-selection label when enabled',
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
            // Phase 33 (D-02): the weekend boolean is superseded by an explicit
            // day set. The default weekday set (Mon–Fri) renders as "Weekdays".
            reminderDays: '1,2,3,4,5',
            weeklyNotificationEnabled: false,
            autoPauseEnabled: false,
            hasSeenOnboarding: false,
            homeLat: null,
            homeLng: null,
            officeLat: null,
            officeLng: null,
            backfillMarkerVersion: 0,
          ),
        );
        await _scrollTo(tester, find.text('Daily reminder'));
        // The Daily reminder row label is still present.
        expect(find.text('Daily reminder'), findsOneWidget);
        // The enabled Daily reminder subtitle is "{time} · {days}". With the
        // Mon–Fri set that day label is kReminderDaysWeekdaysLabel ("Weekdays"),
        // so the combined subtitle is "8:00 AM · Weekdays".
        expect(
          find.textContaining('· $kReminderDaysWeekdaysLabel'),
          findsOneWidget,
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Phase 15 debug fix: Reminder time picker row + decoupled permission
  // ---------------------------------------------------------------------------

  group('SettingsScreen — reminder time picker (Phase 15 fix)', () {
    testWidgets(
      'Reminder time row subtitle shows "—" when reminderTime is null',
      (tester) async {
        await _pumpSettingsScreen(tester, prefs: _remindersOff);
        await _scrollTo(tester, find.text(kSettingsReminderTimeLabel));
        // When no time is set, _formatReminderTime(null) == '—'.
        final timeRow = find.ancestor(
          of: find.text(kSettingsReminderTimeLabel),
          matching: find.byType(SettingsRow),
        );
        expect(timeRow, findsOneWidget);
        expect(
          find.descendant(of: timeRow, matching: find.text('—')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Reminder time row subtitle shows formatted time when reminderTime is set',
      (tester) async {
        await _pumpSettingsScreen(
          tester,
          prefs: const UserPreferencesValue(
            userId: 'test',
            darkMode: kDarkModeSystem,
            morningCutoffHour: 12,
            eveningCutoffHour: 12,
            reminderEnabled: false,
            reminderTime: '09:30',
            weekendReminder: false,
            weeklyNotificationEnabled: false,
            autoPauseEnabled: false,
            hasSeenOnboarding: false,
            homeLat: null,
            homeLng: null,
            officeLat: null,
            officeLng: null,
            backfillMarkerVersion: 0,
          ),
        );
        await _scrollTo(tester, find.text(kSettingsReminderTimeLabel));
        // _formatReminderTime('09:30') → '9:30 AM'. When the reminder is
        // disabled, the Daily reminder row shows 'OFF', so '9:30' appears
        // only in the Reminder time row's subtitle.
        expect(find.textContaining('9:30'), findsOneWidget);
      },
    );

    testWidgets(
      'enabling daily reminder with NO time always calls '
      'maybeRequestNotificationPermissionForUsage (decoupled — IOS-10 fix)',
      (tester) async {
        // reminderTime is null — the previously broken code path that gated
        // the permission request behind (value && reminderTime != null).
        final fakeNotif = _FakeNotificationService();
        await _pumpSettingsScreen(
          tester,
          prefs: const UserPreferencesValue(
            userId: 'test',
            darkMode: kDarkModeSystem,
            morningCutoffHour: 12,
            eveningCutoffHour: 12,
            reminderEnabled: false,
            reminderTime: null,
            weekendReminder: false,
            weeklyNotificationEnabled: false,
            autoPauseEnabled: false,
            hasSeenOnboarding: false,
            homeLat: null,
            homeLng: null,
            officeLat: null,
            officeLng: null,
            backfillMarkerVersion: 0,
          ),
          notificationService: fakeNotif,
        );
        await _scrollTo(tester, find.text(kSettingsReminderLabel));
        final reminderRow = find.ancestor(
          of: find.text(kSettingsReminderLabel),
          matching: find.byType(SettingsRow),
        );
        await tester.tap(
          find.descendant(of: reminderRow, matching: find.byType(TraevyToggle)),
        );
        await tester.pump();

        // Permission MUST be requested even without a time.
        expect(
          fakeNotif.calls,
          contains('maybeRequestPermission(force=true)'),
        );
        // scheduleReminder must NOT be called — no time is set.
        expect(
          fakeNotif.calls.any((c) => c.startsWith('scheduleReminder')),
          isFalse,
        );
      },
    );

    testWidgets(
      'enabling daily reminder WITH a time calls permission request AND '
      'scheduleReminder',
      (tester) async {
        final fakeNotif = _FakeNotificationService();
        await _pumpSettingsScreen(
          tester,
          prefs: const UserPreferencesValue(
            userId: 'test',
            darkMode: kDarkModeSystem,
            morningCutoffHour: 12,
            eveningCutoffHour: 12,
            reminderEnabled: false,
            reminderTime: '07:45',
            weekendReminder: false,
            weeklyNotificationEnabled: false,
            autoPauseEnabled: false,
            hasSeenOnboarding: false,
            homeLat: null,
            homeLng: null,
            officeLat: null,
            officeLng: null,
            backfillMarkerVersion: 0,
          ),
          notificationService: fakeNotif,
        );
        await _scrollTo(tester, find.text(kSettingsReminderLabel));
        final reminderRow = find.ancestor(
          of: find.text(kSettingsReminderLabel),
          matching: find.byType(SettingsRow),
        );
        await tester.tap(
          find.descendant(of: reminderRow, matching: find.byType(TraevyToggle)),
        );
        await tester.pump();

        expect(
          fakeNotif.calls,
          contains('maybeRequestPermission(force=true)'),
        );
        expect(
          fakeNotif.calls,
          contains('scheduleReminder(07:45,1-2-3-4-5)'),
        );
      },
    );

    testWidgets(
      'disabling daily reminder calls cancelReminder (not permission request)',
      (tester) async {
        final fakeNotif = _FakeNotificationService();
        await _pumpSettingsScreen(
          tester,
          prefs: const UserPreferencesValue(
            userId: 'test',
            darkMode: kDarkModeSystem,
            morningCutoffHour: 12,
            eveningCutoffHour: 12,
            reminderEnabled: true,
            reminderTime: '07:45',
            weekendReminder: false,
            weeklyNotificationEnabled: false,
            autoPauseEnabled: false,
            hasSeenOnboarding: false,
            homeLat: null,
            homeLng: null,
            officeLat: null,
            officeLng: null,
            backfillMarkerVersion: 0,
          ),
          notificationService: fakeNotif,
        );
        await _scrollTo(tester, find.text(kSettingsReminderLabel));
        final reminderRow = find.ancestor(
          of: find.text(kSettingsReminderLabel),
          matching: find.byType(SettingsRow),
        );
        await tester.tap(
          find.descendant(of: reminderRow, matching: find.byType(TraevyToggle)),
        );
        await tester.pump();

        expect(fakeNotif.calls, contains('cancelReminder'));
        expect(
          fakeNotif.calls.any((c) => c.startsWith('maybeRequestPermission')),
          isFalse,
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Phase 33 (D-02 / D-04): day-of-week picker and recalibration suggestion
  // ---------------------------------------------------------------------------

  group('SettingsScreen — reminder day picker (Phase 33, D-02)', () {
    testWidgets('renders the day picker in place of the weekend toggle', (
      tester,
    ) async {
      await _pumpSettingsScreen(tester);
      await _scrollTo(tester, find.byType(ReminderDayPicker));
      expect(find.byType(ReminderDayPicker), findsOneWidget);
    });

    testWidgets(
      'tapping a day writes the new selection and reschedules onto it',
      (tester) async {
        final fakeNotif = _FakeNotificationService();
        // Reminder ON at 07:00 on weekdays; tapping Saturday adds day 6.
        final dao = await _pumpSettingsScreen(
          tester,
          prefs: const UserPreferencesValue.defaults(),
          notificationService: fakeNotif,
        );
        await _scrollTo(tester, find.byType(ReminderDayPicker));
        // The seven day dots are GestureDetectors ordered Mon→Sun, so
        // Saturday (weekday 6) is index 5.
        final saturdayDot = find
            .descendant(
              of: find.byType(ReminderDayPicker),
              matching: find.byType(GestureDetector),
            )
            .at(5);
        await tester.tap(saturdayDot);
        await tester.pump();

        expect(dao.writes, isNotEmpty);
        // The stored day CSV now includes Saturday (6) alongside Mon–Fri.
        expect(dao.writes.last.reminderDayNumbers, <int>{1, 2, 3, 4, 5, 6});
        // And the alarm set was rescheduled onto exactly that selection.
        expect(
          fakeNotif.calls,
          contains('scheduleReminder(07:00,1-2-3-4-5-6)'),
        );
      },
    );
  });

  group('SettingsScreen — recalibration suggestion (Phase 33, D-04)', () {
    testWidgets('no card is shown when there is no suggestion', (tester) async {
      await _pumpSettingsScreen(tester);
      expect(find.byType(ReminderSuggestionCard), findsNothing);
    });

    testWidgets('accepting the suggestion adopts it as the reminder time', (
      tester,
    ) async {
      final fakeNotif = _FakeNotificationService();
      final dao = await _pumpSettingsScreen(
        tester,
        prefs: const UserPreferencesValue.defaults(),
        notificationService: fakeNotif,
        reminderSuggestion: '08:05',
      );
      await _scrollTo(tester, find.byType(ReminderSuggestionCard));
      expect(find.byType(ReminderSuggestionCard), findsOneWidget);

      await tester.tap(find.text(kReminderSuggestionAcceptLabel));
      await tester.pump();

      expect(dao.writes, isNotEmpty);
      expect(dao.writes.last.reminderTime, '08:05');
      // Accepting reschedules the enabled reminder onto the new time.
      expect(
        fakeNotif.calls.any((c) => c.startsWith('scheduleReminder(08:05,')),
        isTrue,
      );
    });

    testWidgets('dismissing records the value without changing the time', (
      tester,
    ) async {
      final dao = await _pumpSettingsScreen(
        tester,
        prefs: const UserPreferencesValue.defaults(),
        reminderSuggestion: '08:05',
      );
      await _scrollTo(tester, find.byType(ReminderSuggestionCard));
      await tester.tap(find.text(kReminderSuggestionDismissLabel));
      await tester.pump();

      expect(dao.writes, isNotEmpty);
      // The reminder time is untouched (still the 07:00 default)…
      expect(dao.writes.last.reminderTime, '07:00');
      // …but the dismissed value is remembered so it never re-prompts.
      expect(dao.writes.last.reminderSuggestionValue, '08:05');
    });
  });

  // ---------------------------------------------------------------------------
  // Phase 32 (D-02): the Account section is GONE from Settings
  // ---------------------------------------------------------------------------
  //
  // Its rows moved to the dashboard avatar's account sheet; the positive
  // coverage for them lives in
  // test/widget/features/dashboard/account_sheet_test.dart. What Settings owes
  // is the negative: no duplicate control survived the move (SC#4).

  group('SettingsScreen has no Account section (Phase 32, SC#4)', () {
    testWidgets('guest state shows no account controls at all', (tester) async {
      await _pumpSettingsScreen(tester);

      expect(find.byType(AccountRow), findsNothing);
      expect(find.text(kCopySettingsGuestSignIn), findsNothing);
      expect(find.text(kCopySettingsSignOut), findsNothing);
      expect(find.text(kSettingsCloudSyncRowLabel), findsNothing);
      expect(find.text(kSettingsRestoreRowLabel), findsNothing);
    });

    testWidgets('signed-in state shows no second sign-out or restore', (
      tester,
    ) async {
      await _pumpSettingsScreen(
        tester,
        authState: const AuthSignedIn(
          uid: 'uid-ada',
          name: 'Ada Lovelace',
          email: 'ada@x.dev',
        ),
      );

      expect(find.byType(AccountRow), findsNothing);
      expect(find.text('Ada Lovelace'), findsNothing);
      expect(find.text('ada@x.dev'), findsNothing);
      expect(find.text(kCopySettingsSignOut), findsNothing);
      expect(find.text(kSettingsRestoreRowLabel), findsNothing);
    });
  });
}
