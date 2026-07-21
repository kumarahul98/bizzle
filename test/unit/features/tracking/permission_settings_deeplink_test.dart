import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';

/// Guards Phase 36 D-03 — the "Open settings" CTA reaching the app's PERMISSION
/// LIST rather than App Info, and surviving a device where the intent behind it
/// does not resolve.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Install a fake `MainActivity` handler on the real channel and record every
  /// method name it receives.
  List<String> installHandler({required Object? Function() reply}) {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(platformChannel, (call) async {
      calls.add(call.method);
      return reply();
    });
    return calls;
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(platformChannel, null);
  });

  group('openAppPermissionSettings — the channel call', () {
    test(
      'invokes the openAppPermissions method on the platform channel',
      () async {
        final calls = installHandler(reply: () => true);

        final shown = await openAppPermissionSettings();

        expect(calls, <String>[kOpenAppPermissionsMethod]);
        expect(shown, isTrue);
      },
    );

    test('reports false when the platform showed nothing', () async {
      // MainActivity returns false only when NEITHER ACTION_APP_PERMISSIONS nor
      // the App Info fallback resolved. Reporting that honestly is what lets a
      // caller surface the failure instead of assuming settings opened.
      installHandler(reply: () => false);

      expect(await openAppPermissionSettings(), isFalse);
    });

    test('treats a null reply as "nothing was shown"', () async {
      // invokeMethod<bool> yields null if the platform ever answers with a
      // non-bool. Defaulting to true there would silently claim success.
      installHandler(reply: () => null);

      expect(await openAppPermissionSettings(), isFalse);
    });

    test('the channel name matches the constant MainActivity is pinned to', () {
      // MainActivity.kt hard-codes these two strings. If either constant moves
      // without the Kotlin side moving with it, the call silently becomes a
      // MissingPluginException and every denial path quietly degrades to App
      // Info — which is exactly the behaviour this phase removed.
      expect(platformChannel.name, kPlatformChannelName);
      expect(kPlatformChannelName, 'traevy/platform');
      expect(kOpenAppPermissionsMethod, 'openAppPermissions');
    });
  });

  group('openAppPermissionSettings — the fallback branch', () {
    test('falls back to permission_handler when the channel is absent', () async {
      // No mock handler installed → MissingPluginException, which is what iOS
      // (no MainActivity) and any un-mocked host produce. The call must return
      // rather than propagate: an unhandled throw here lands on the user at the
      // moment they are already blocked by a denied permission.
      messenger.setMockMethodCallHandler(platformChannel, null);

      // permission_handler is itself unregistered in the test host, so its own
      // MissingPluginException escapes — proving control reached the fallback.
      await expectLater(
        openAppPermissionSettings(),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test(
      'a PlatformException from the channel routes to the fallback too',
      () async {
        messenger.setMockMethodCallHandler(platformChannel, (call) async {
          throw PlatformException(code: 'UNAVAILABLE');
        });

        // Same reasoning as above: reaching permission_handler is the
        // observable proof the catch fired, and it must not be the raw
        // PlatformException that surfaces.
        await expectLater(
          openAppPermissionSettings(),
          throwsA(isA<MissingPluginException>()),
        );
      },
    );
  });

  group('TrackingPermissionService.openSystemSettings', () {
    test('delegates to the injected opener', () async {
      var opened = 0;
      final service = TrackingPermissionService.forTesting(
        probe: (_) async => PermissionStatus.granted,
        requester: (_) async => PermissionStatus.granted,
        opener: () async {
          opened++;
          return true;
        },
      );

      expect(await service.openSystemSettings(), isTrue);
      expect(opened, 1);
    });

    test('production default routes through the platform channel', () async {
      // The const constructor is what the Riverpod provider builds, so this is
      // the instance every denial path in the app actually uses.
      final calls = installHandler(reply: () => true);

      await const TrackingPermissionService().openSystemSettings();

      expect(calls, <String>[kOpenAppPermissionsMethod]);
    });
  });

  group('D-03 — one destination for every denial path', () {
    test('the shared CTA label and message are non-empty', () {
      expect(kOpenPermissionSettingsLabel, isNotEmpty);
      expect(kPermissionsRequiredMessage, isNotEmpty);
    });

    test('the CTA no longer promises the device-wide location screen', () {
      // The tracking-error button used to read "Open Location Settings" and
      // opened Android's global location page. The label must not describe a
      // destination this app no longer sends anyone to.
      expect(
        kOpenPermissionSettingsLabel.toLowerCase(),
        isNot(contains('location')),
      );
    });
  });
}
