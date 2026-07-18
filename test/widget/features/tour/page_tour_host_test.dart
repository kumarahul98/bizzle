// Widget tests for the Phase 27 per-page guided tour (UX-07).
//
// Exercises PageTourHost directly with a synthetic PageTour whose steps target
// two simple keyed boxes, so the tests do not depend on any real screen's
// layout. Verifies: the coach-mark appears with a Skip button when the page is
// unseen; finishing or skipping persists the page key via markTourSeen; and an
// already-seen page shows no tour.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/tour/page_tour_host.dart';
import 'package:traevy/features/tour/tour_config.dart';

/// Fake DAO capturing every [markTourSeen] page key. All other DAO members
/// fail fast via noSuchMethod — none are exercised by the tour.
class _FakeUserPreferencesDao implements UserPreferencesDao {
  final List<String> seenMarks = <String>[];

  @override
  Future<void> markTourSeen(String pageKey) async => seenMarks.add(pageKey);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const String _kTestPageKey = 'test_page';

UserPreferencesValue _prefs({Set<String> seen = const <String>{}}) =>
    UserPreferencesValue(
      userId: kDefaultUserId,
      darkMode: kDarkModeSystem,
      morningCutoffHour: kDefaultDirectionCutoffHour,
      eveningCutoffHour: kDefaultDirectionCutoffHour,
      reminderEnabled: false,
      reminderTime: null,
      weekendReminder: false,
      weeklyNotificationEnabled: false,
      autoPauseEnabled: true,
      hasSeenOnboarding: true,
      homeLat: null,
      homeLng: null,
      officeLat: null,
      officeLng: null,
      backfillMarkerVersion: 0,
      seenTours: seen.join(','),
    );

Future<_FakeUserPreferencesDao> _pumpHost(
  WidgetTester tester, {
  required Set<String> seen,
}) async {
  final dao = _FakeUserPreferencesDao();
  final stepOneKey = GlobalKey(debugLabel: 'step1');
  final stepTwoKey = GlobalKey(debugLabel: 'step2');

  final tour = PageTour(
    pageKey: _kTestPageKey,
    tabIndex: 0,
    steps: <TourStep>[
      TourStep(
        targetKey: stepOneKey,
        title: 'First thing',
        description: 'Description one.',
      ),
      TourStep(
        targetKey: stepTwoKey,
        title: 'Second thing',
        description: 'Description two.',
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userPreferencesDaoProvider.overrideWithValue(dao),
        userPreferenceProvider.overrideWith(
          (ref) => Stream<UserPreferencesValue>.value(_prefs(seen: seen)),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: PageTourHost(
            tour: tour,
            child: Column(
              children: <Widget>[
                SizedBox(key: stepOneKey, width: 120, height: 48),
                const SizedBox(height: 200),
                SizedBox(key: stepTwoKey, width: 120, height: 48),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  // One frame builds + resolves the prefs stream; a couple more let the
  // post-frame callbacks insert the overlay.
  await tester.pumpAndSettle();
  return dao;
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('PageTourHost (UX-07)', () {
    testWidgets('shows the coach-mark with a Skip button when unseen', (
      tester,
    ) async {
      await _pumpHost(tester, seen: const <String>{});

      expect(find.text(kTourSkipLabel), findsOneWidget);
      expect(find.text('First thing'), findsOneWidget);
      expect(find.text(kTourNextLabel), findsOneWidget);
    });

    testWidgets('advances through steps and marks the page seen on finish', (
      tester,
    ) async {
      final dao = await _pumpHost(tester, seen: const <String>{});

      // Step 1 → Next.
      expect(find.text('First thing'), findsOneWidget);
      await tester.tap(find.text(kTourNextLabel));
      await tester.pumpAndSettle();

      // Step 2 shows the final "Got it" action.
      expect(find.text('Second thing'), findsOneWidget);
      expect(find.text(kTourDoneLabel), findsOneWidget);
      expect(dao.seenMarks, isEmpty);

      await tester.tap(find.text(kTourDoneLabel));
      await tester.pumpAndSettle();

      // Overlay dismissed and the page key persisted exactly once.
      expect(find.text(kTourSkipLabel), findsNothing);
      expect(dao.seenMarks, <String>[_kTestPageKey]);
    });

    testWidgets('Skip dismisses the tour and marks the page seen', (
      tester,
    ) async {
      final dao = await _pumpHost(tester, seen: const <String>{});

      expect(find.text(kTourSkipLabel), findsOneWidget);
      await tester.tap(find.text(kTourSkipLabel));
      await tester.pumpAndSettle();

      expect(find.text(kTourSkipLabel), findsNothing);
      expect(find.text('First thing'), findsNothing);
      expect(dao.seenMarks, <String>[_kTestPageKey]);
    });

    testWidgets('does not show when the page is already seen', (tester) async {
      final dao = await _pumpHost(
        tester,
        seen: const <String>{_kTestPageKey},
      );

      expect(find.text(kTourSkipLabel), findsNothing);
      expect(find.text('First thing'), findsNothing);
      expect(dao.seenMarks, isEmpty);
    });
  });
}
