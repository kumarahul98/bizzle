import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/app.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/screens/home_screen.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// Minimal stub notifier that skips fbs initialisation.
///
/// The real [TrackingNotifier.build] calls FlutterBackgroundService.on,
/// which throws on non-Android/iOS platforms (the test host). This
/// subclass short-circuits [build] to [TrackingIdle] so widget tests
/// that render [HomeScreen] never touch the platform channel.
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

void main() {
  testWidgets(
    'TraevyApp builds under ProviderScope and shows HomeScreen',
    (tester) async {
      // HomeScreen.build now watches trackingStateProvider (FAB
      // visibility gate). Override with _IdleTrackingNotifier so the
      // test host never touches the fbs platform channel. Also override
      // the DB and directionBackfillProvider to avoid file I/O and
      // pending timers in fake_async (same pattern as app_bootstrap_test).
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            tripsDaoProvider.overrideWithValue(db.tripsDao),
            syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
            userPreferencesDaoProvider.overrideWithValue(
              db.userPreferencesDao,
            ),
            directionBackfillProvider.overrideWith((_) async {}),
            trackingStateProvider.overrideWith(_IdleTrackingNotifier.new),
          ],
          child: const TraevyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Root widget tree is a MaterialApp — proves the wiring through
      // ProviderScope reached TraevyApp without throwing.
      expect(find.byType(MaterialApp), findsOneWidget);

      // Phase 2 mounts HomeScreen as the root.
      expect(find.byType(HomeScreen), findsOneWidget);

      // AppBar title uses 'Traevy' and body exposes the Start commute
      // CTA. 'Traevy' appears both in the AppBar and the MaterialApp
      // title chrome, so use findsWidgets instead of findsOneWidget.
      expect(find.text('Traevy'), findsWidgets);
      expect(find.text('Start commute'), findsOneWidget);
    },
  );
}
