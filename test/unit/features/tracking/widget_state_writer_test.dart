// Regression test for WIDGET-01 stuck-widget fix.
//
// writeWidgetIdle() is the single source of the idle-reset widget write, reused
// by the background-isolate stop handler and by reconcileWidgetOnStartup() (the
// app-launch reconciliation that unsticks a widget frozen on the active state
// after a force-stop). This test pins that it pushes widget_show_stats=false +
// the idle title + an updateWidget refresh through the home_widget channel.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/tracking/services/widget_state_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          // saveWidgetData and updateWidget both return bool in home_widget 0.9.3.
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'writeWidgetIdle writes the idle state and refreshes the widget',
    () async {
      await writeWidgetIdle();

      final saves = calls.where((c) => c.method == 'saveWidgetData').toList();

      final showStats = saves.firstWhere(
        (c) => (c.arguments as Map)['id'] == kWidgetKeyShowStats,
        orElse: () => throw StateError('widget_show_stats was never written'),
      );
      expect((showStats.arguments as Map)['data'], isFalse);

      final title = saves.firstWhere(
        (c) => (c.arguments as Map)['id'] == kWidgetKeyTitle,
        orElse: () => throw StateError('widget_title was never written'),
      );
      expect((title.arguments as Map)['data'], kWidgetTitleIdle);

      expect(
        calls.any((c) => c.method == 'updateWidget'),
        isTrue,
        reason: 'the RemoteViews must be refreshed after the data write',
      );
    },
  );

  // --- Phase 28: idle-state stats block -----------------------------------

  String? savedValue(List<MethodCall> calls, String key) {
    for (final c in calls.where((c) => c.method == 'saveWidgetData')) {
      final args = c.arguments as Map;
      if (args['id'] == key) return args['data'] as String?;
    }
    return null;
  }

  TripSummary trip({required int stuckSeconds}) => TripSummary(
    id: 't-$stuckSeconds',
    startTime: DateTime.utc(2026, 7, 18, 8),
    endTime: DateTime.utc(2026, 7, 18, 9),
    durationSeconds: 3600,
    distanceMeters: 12000,
    direction: kDirectionToOffice,
    timeMovingSeconds: 3600 - stuckSeconds,
    timeStuckSeconds: stuckSeconds,
    isManualEntry: false,
  );

  group('formatWidgetDuration', () {
    test('formats minutes and hours, and rejects negatives', () {
      expect(formatWidgetDuration(0), '0m');
      expect(formatWidgetDuration(90), '1m');
      expect(formatWidgetDuration(3600), '1h 0m');
      expect(formatWidgetDuration(13200), '3h 40m');
      expect(formatWidgetDuration(-1), kWidgetValueUnknown);
    });
  });

  group('writeWidgetIdleStats', () {
    test('sums today\'s stuck time and pluralizes the trip count', () async {
      await writeWidgetIdleStats(
        todayTrips: [trip(stuckSeconds: 600), trip(stuckSeconds: 300)],
        weekStats: null,
      );

      expect(savedValue(calls, kWidgetKeyTodayTrips), '2 trips');
      expect(savedValue(calls, kWidgetKeyTodayTraffic), '15m in traffic');
      // No week aggregation available yet → placeholders, never blank.
      expect(savedValue(calls, kWidgetKeyWeekTotal), kWidgetValueUnknown);
      expect(savedValue(calls, kWidgetKeyWeekStuck), kWidgetValueUnknown);
      expect(calls.any((c) => c.method == 'updateWidget'), isTrue);
    });

    test('uses the singular form for exactly one trip', () async {
      await writeWidgetIdleStats(
        todayTrips: [trip(stuckSeconds: 60)],
        weekStats: null,
      );

      expect(savedValue(calls, kWidgetKeyTodayTrips), '1 trip');
      expect(savedValue(calls, kWidgetKeyTodayTraffic), '1m in traffic');
    });

    test('writes placeholders (never blank) when there are no trips', () async {
      await writeWidgetIdleStats(todayTrips: const [], weekStats: null);

      expect(savedValue(calls, kWidgetKeyTodayTrips), '0 trips');
      expect(savedValue(calls, kWidgetKeyTodayTraffic), kWidgetValueUnknown);
    });
  });
}
