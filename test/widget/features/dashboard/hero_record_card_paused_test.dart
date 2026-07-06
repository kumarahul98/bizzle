// Widget tests for the PAUSED hero state — Phase 18 Plan 03.
//
// The _HeroActive surface inside HeroRecordCard is a DUMB TERMINAL (D-08):
// its paused-or-running treatment is driven purely by the injected
// TrackingActive.isPaused — there is no local pause clock. These tests inject
// a running vs paused TrackingActive through a stub TrackingNotifier and
// assert:
//   * running  → a Pause button, no PAUSED badge
//   * paused   → a Resume button, a PAUSED badge, and a break-count indicator
//   * tapping Pause routes to TrackingNotifier.pause()

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
import 'package:traevy/features/tracking/widgets/pause_resume_button.dart';

/// Stub notifier serving a fixed [TrackingActive] and recording pause()/
/// resume() calls without driving any platform channel.
class _PausedActiveNotifier extends TrackingNotifier {
  _PausedActiveNotifier({
    required this.isPaused,
    required this.breakCount,
    this.onPause,
    this.onResume,
  });

  final bool isPaused;
  final int breakCount;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  TrackingState build() => TrackingActive(
    startedAt: DateTime.now(),
    elapsedSeconds: 600,
    distanceMeters: 3000,
    currentSpeedKmh: 0,
    timeMovingSeconds: 400,
    timeStuckSeconds: 200,
    isPaused: isPaused,
    pausedSeconds: isPaused ? 30 : 0,
    breakCount: breakCount,
  );

  @override
  String resolvedDirection(DateTime startedAt) => kDirectionToOffice;

  @override
  Future<void> pause() async => onPause?.call();

  @override
  Future<void> resume() async => onResume?.call();

  @override
  void setDirection(String direction) {}
}

Future<void> _pumpHero(
  WidgetTester tester, {
  required TrackingNotifier Function() factory,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackingStateProvider.overrideWith(factory),
        userPreferenceProvider.overrideWith(
          (ref) => Stream<UserPreferencesValue>.value(
            const UserPreferencesValue.defaults(),
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

  group('HeroRecordCard PAUSED state', () {
    testWidgets('running snapshot shows a Pause button and no PAUSED badge', (
      tester,
    ) async {
      await _pumpHero(
        tester,
        factory: () => _PausedActiveNotifier(isPaused: false, breakCount: 0),
      );

      expect(find.byType(PauseResumeButton), findsOneWidget);
      expect(find.text(kTrackingPauseLabel), findsOneWidget);
      expect(find.text(kTrackingResumeLabel), findsNothing);
      expect(find.text(kTrackingPausedBadgeLabel), findsNothing);
    });

    testWidgets(
      'paused snapshot shows a Resume button, a PAUSED badge, and break count',
      (tester) async {
        await _pumpHero(
          tester,
          factory: () => _PausedActiveNotifier(isPaused: true, breakCount: 2),
        );

        expect(find.text(kTrackingResumeLabel), findsOneWidget);
        expect(find.text(kTrackingPauseLabel), findsNothing);
        expect(find.text(kTrackingPausedBadgeLabel), findsOneWidget);
        expect(find.text('2 breaks'), findsOneWidget);
      },
    );

    testWidgets('break count uses the singular label when exactly one break', (
      tester,
    ) async {
      await _pumpHero(
        tester,
        factory: () => _PausedActiveNotifier(isPaused: true, breakCount: 1),
      );

      expect(find.text(kTrackingBreakCountSingularLabel), findsOneWidget);
    });

    testWidgets('no break-count indicator when there are zero breaks', (
      tester,
    ) async {
      await _pumpHero(
        tester,
        factory: () => _PausedActiveNotifier(isPaused: false, breakCount: 0),
      );

      expect(find.textContaining('break'), findsNothing);
    });

    testWidgets('tapping Pause routes to TrackingNotifier.pause()', (
      tester,
    ) async {
      var pauseCalls = 0;
      await _pumpHero(
        tester,
        factory: () => _PausedActiveNotifier(
          isPaused: false,
          breakCount: 0,
          onPause: () => pauseCalls++,
        ),
      );

      await tester.tap(find.byType(PauseResumeButton));
      await tester.pump();

      expect(pauseCalls, 1);
    });

    testWidgets('tapping Resume routes to TrackingNotifier.resume()', (
      tester,
    ) async {
      var resumeCalls = 0;
      await _pumpHero(
        tester,
        factory: () => _PausedActiveNotifier(
          isPaused: true,
          breakCount: 0,
          onResume: () => resumeCalls++,
        ),
      );

      await tester.tap(find.byType(PauseResumeButton));
      await tester.pump();

      expect(resumeCalls, 1);
    });
  });
}
