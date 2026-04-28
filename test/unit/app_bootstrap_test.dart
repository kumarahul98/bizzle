import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/app.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';

/// Minimal stub notifier that skips fbs initialisation.
///
/// DashboardScreen.build watches trackingStateProvider (FAB mode gate).
/// The real TrackingNotifier.build calls FlutterBackgroundService.on,
/// which throws on non-Android/iOS platforms. This subclass returns
/// TrackingIdle immediately so the test host never touches the channel.
class _IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

void main() {
  group('TraevyApp bootstrap', () {
    testWidgets(
      'pumps inside ProviderScope and renders DashboardScreen',
      (tester) async {
        // Override appDatabaseProvider with an in-memory DB so the
        // widget test does not open a real file-based database, and
        // override directionBackfillProvider with a completed no-op so
        // the FutureProvider does not leave a pending timer in fake async.
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
              // DashboardScreen watches allTripSummariesProvider via
              // todaysTripSummariesProvider — override to avoid Drift I/O.
              allTripSummariesProvider.overrideWith(
                (ref) => const Stream<List<TripSummary>>.empty(),
              ),
            ],
            child: const TraevyApp(),
          ),
        );
        // Two pumps: resolve the stream emission and settle initial frame.
        await tester.pump();
        await tester.pump();

        // MaterialApp is configured with the expected title and themes.
        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.title, 'Traevy');
        expect(materialApp.theme, lightTheme);
        expect(materialApp.darkTheme, darkTheme);
        expect(materialApp.themeMode, ThemeMode.system);

        // Phase 6 mounts DashboardScreen as the app root (UX-01).
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.text('Start commute'), findsOneWidget);
      },
    );
  });
}
