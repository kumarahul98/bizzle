import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/app.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';
import 'package:traevy/features/tracking/screens/home_screen.dart';

void main() {
  group('TraevyApp bootstrap', () {
    testWidgets(
      'pumps inside ProviderScope and renders HomeScreen',
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
              directionBackfillProvider.overrideWith(
                (_) async {},
              ),
            ],
            child: const TraevyApp(),
          ),
        );

        // MaterialApp is configured with the expected title and themes.
        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.title, 'Traevy');
        expect(materialApp.theme, lightTheme);
        expect(materialApp.darkTheme, darkTheme);
        expect(materialApp.themeMode, ThemeMode.system);

        // HomeScreen renders an AppBar title and the Start commute CTA.
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('Traevy'), findsWidgets);
        expect(find.text('Start commute'), findsOneWidget);
      },
    );
  });
}
