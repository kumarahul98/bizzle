import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel(
      'plugins.flutter.io/path_provider',
    ).setMockMethodCallHandler((MethodCall methodCall) async {
      return '.';
    });
  });

  group('TrackingNotifier Recovery', () {
    test('TrackingInterrupted carries the persisted snapshot', () async {
      // We cannot easily test the full flow without overriding the persister and controller,
      // but we can ensure TrackingInterrupted exists.
      final state = TrackingInterrupted({'elapsedSeconds': 100});
      expect(state.snapshot['elapsedSeconds'], 100);
    });
  });
}
