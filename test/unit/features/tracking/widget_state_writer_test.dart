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

  test('writeWidgetIdle writes the idle state and refreshes the widget',
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
  });
}
