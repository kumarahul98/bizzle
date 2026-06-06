// Widget tests for SavedLocationTile (Phase 21 Plan 02, LOC-01).
//
// Covers the D-13 "Not set vs coord" rendering and the tap-opens-picker
// callback wiring. The coord is read from userPreferenceProvider, which the
// tests override with a scripted UserPreferencesValue.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/widgets/saved_location_tile.dart';

UserPreferencesValue _prefs({
  double? homeLat,
  double? homeLng,
  double? officeLat,
  double? officeLng,
}) => UserPreferencesValue(
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
  homeLat: homeLat,
  homeLng: homeLng,
  officeLat: officeLat,
  officeLng: officeLng,
);

Future<int> _pumpTile(
  WidgetTester tester, {
  required bool isHome,
  required UserPreferencesValue prefs,
}) async {
  var taps = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userPreferenceProvider.overrideWith(
          (ref) => Stream<UserPreferencesValue>.value(prefs),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: SavedLocationTile(
            isHome: isHome,
            onTap: () => taps++,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return taps;
}

void main() {
  group('SavedLocationTile', () {
    testWidgets('shows "Not set" when the Home coord is null', (tester) async {
      await _pumpTile(tester, isHome: true, prefs: _prefs());
      expect(find.text(kSettingsHomeLocationLabel), findsOneWidget);
      expect(find.text(kCopyLocationNotSet), findsOneWidget);
    });

    testWidgets('shows "Not set" when the Office coord is null', (tester) async {
      await _pumpTile(tester, isHome: false, prefs: _prefs());
      expect(find.text(kSettingsOfficeLocationLabel), findsOneWidget);
      expect(find.text(kCopyLocationNotSet), findsOneWidget);
    });

    testWidgets('shows the formatted coord when Home is set', (tester) async {
      await _pumpTile(
        tester,
        isHome: true,
        prefs: _prefs(homeLat: 12.97123, homeLng: 77.59456),
      );
      expect(find.textContaining('12.97123'), findsOneWidget);
      expect(find.text(kCopyLocationNotSet), findsNothing);
    });

    testWidgets('reads the Office slot independently of Home', (tester) async {
      await _pumpTile(
        tester,
        isHome: false,
        prefs: _prefs(
          homeLat: 1,
          homeLng: 2,
          officeLat: 28.61390,
          officeLng: 77.20900,
        ),
      );
      // Office tile shows the office coord, not the home coord.
      expect(find.textContaining('28.61390'), findsOneWidget);
      expect(find.textContaining('1.00000'), findsNothing);
    });

    testWidgets('tapping the row invokes onTap', (tester) async {
      // Capture taps via a closure threaded through a stateful host.
      var taps = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userPreferenceProvider.overrideWith(
              (ref) => Stream<UserPreferencesValue>.value(_prefs()),
            ),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: SavedLocationTile(
                isHome: true,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(kSettingsHomeLocationLabel));
      await tester.pump();
      expect(taps, equals(1));
    });
  });
}
