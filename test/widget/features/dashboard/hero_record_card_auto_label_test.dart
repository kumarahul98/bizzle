// Widget tests for the IDLE hero card's auto-label row.
//
// Regression guard for the smoke-test finding: the idle card rendered a
// hardcoded 'To office' at every hour of the day because `HeroRecordCard`
// never received an auto-label at all — its `autoLabelDirection` parameter
// was optional and no call site passed it, so the row always fell through to
// its literal default.
//
// These tests are deliberately CLOCK-INDEPENDENT. Rather than freezing time,
// they pick cutoff hours that force one branch of the two-cutoff rule
// regardless of when the suite runs (see `DirectionLabelService.label`):
//
//   * eveningCutoffHour = 0  → `hour >= 0` is always true  → to_home
//   * morningCutoffHour = 24 → `hour < 24`  is always true → to_office
//
// That keeps the real prefs → DirectionLabelService → display-label wiring
// under test without a injected clock, and the to_home case fails against the
// pre-fix code, which could only ever render 'To office'.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/features/dashboard/widgets/hero_record_card.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// Stub notifier pinning the card to [TrackingIdle] — the only state that
/// renders the auto-label row.
class _IdleNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  void setDirection(String direction) {}
}

/// A defaults-based preferences value with the two direction cutoffs
/// overridden. Every other field mirrors [UserPreferencesValue.defaults].
UserPreferencesValue _prefsWithCutoffs({
  required int morning,
  required int evening,
}) {
  return UserPreferencesValue(
    userId: kDefaultUserId,
    darkMode: kDarkModeSystem,
    morningCutoffHour: morning,
    eveningCutoffHour: evening,
    reminderEnabled: true,
    reminderTime: kDefaultReminderTime,
    weekendReminder: false,
    weeklyNotificationEnabled: false,
    autoPauseEnabled: true,
    hasSeenOnboarding: true,
    homeLat: null,
    homeLng: null,
    officeLat: null,
    officeLng: null,
    backfillMarkerVersion: 0,
  );
}

Future<void> _pumpIdleHero(
  WidgetTester tester, {
  required int morning,
  required int evening,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackingStateProvider.overrideWith(_IdleNotifier.new),
        userPreferenceProvider.overrideWith(
          (ref) => Stream<UserPreferencesValue>.value(
            _prefsWithCutoffs(morning: morning, evening: evening),
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        routes: kAppRoutes,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroRecordCard(onStart: () {}),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('HeroRecordCard idle auto-label', () {
    testWidgets('evening cutoff of 0 auto-labels To home at any hour', (
      tester,
    ) async {
      await _pumpIdleHero(tester, morning: 0, evening: 0);

      expect(
        find.textContaining(kDirectionToHomeLabel, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(kDirectionToOfficeLabel, findRichText: true),
        findsNothing,
      );
    });

    testWidgets('morning cutoff of 24 auto-labels To office at any hour', (
      tester,
    ) async {
      await _pumpIdleHero(tester, morning: 24, evening: 24);

      expect(
        find.textContaining(kDirectionToOfficeLabel, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(kDirectionToHomeLabel, findRichText: true),
        findsNothing,
      );
    });

    testWidgets('the auto-label row keeps its explanatory prefix', (
      tester,
    ) async {
      await _pumpIdleHero(tester, morning: 0, evening: 0);

      expect(
        find.textContaining(kAutoLabelledPrefix.trim(), findRichText: true),
        findsOneWidget,
      );
    });
  });
}
