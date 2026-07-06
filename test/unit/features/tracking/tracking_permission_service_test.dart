import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';

/// Captures the ordered sequence of Permission values passed through an
/// injected probe or requester closure, so tests can assert the strict
/// four-step ordering from D-07 / RESEARCH Pitfall 5 + UX-03:
/// locationWhenInUse MUST resolve before locationAlways is ever touched,
/// and notification MUST NEVER be touched until the location dance has
/// fully resolved to a non-denied state.
class _CallLog {
  final List<Permission> probeCalls = <Permission>[];
  final List<Permission> requestCalls = <Permission>[];

  int indexOfFirstRequest(Permission permission) {
    for (var i = 0; i < requestCalls.length; i++) {
      if (requestCalls[i] == permission) return i;
    }
    return -1;
  }
}

/// Builds a probe closure whose result is keyed off the Permission value.
PermissionStatusProbe _staticProbe(
  Map<Permission, PermissionStatus> values,
  _CallLog log,
) {
  return (Permission permission) async {
    log.probeCalls.add(permission);
    final result = values[permission];
    if (result == null) {
      throw StateError('Unexpected probe call: $permission');
    }
    return result;
  };
}

/// Builds a requester closure whose result is keyed off the Permission value.
PermissionRequester _staticRequester(
  Map<Permission, PermissionStatus> values,
  _CallLog log,
) {
  return (Permission permission) async {
    log.requestCalls.add(permission);
    final result = values[permission];
    if (result == null) {
      throw StateError('Unexpected request call: $permission');
    }
    return result;
  };
}

void main() {
  group('TrackingPermissionService.preflight', () {
    test('returns fullyGranted when all three permissions are already '
        'granted, never calling requester', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.fullyGranted);
      expect(log.requestCalls, isEmpty);
      // locationAlways must never be probed before locationWhenInUse.
      expect(log.probeCalls.first, Permission.locationWhenInUse);
    });

    test('returns foregroundOnly when fine is already granted, background '
        'denied at request, and notification already granted', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.denied,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.locationAlways: PermissionStatus.denied,
        }, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.foregroundOnly);
      // Pitfall 5 ordering guard: locationWhenInUse was never re-requested
      // (already granted), and locationAlways was requested exactly once.
      expect(log.requestCalls, <Permission>[Permission.locationAlways]);
    });

    test('returns foregroundOnly when fine is denied then granted on '
        'request, background denied on request, and notification '
        'already granted', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.denied,
          Permission.locationAlways: PermissionStatus.denied,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.denied,
        }, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.foregroundOnly);
      // Strict ordering: locationWhenInUse must be requested before
      // locationAlways is requested.
      final whenInUseIdx = log.indexOfFirstRequest(
        Permission.locationWhenInUse,
      );
      final alwaysIdx = log.indexOfFirstRequest(Permission.locationAlways);
      expect(whenInUseIdx, isNonNegative);
      expect(alwaysIdx, isNonNegative);
      expect(whenInUseIdx, lessThan(alwaysIdx));
    });

    test(
      'returns denied when fine is denied and request also returns denied',
      () async {
        final log = _CallLog();
        final service = TrackingPermissionService.forTesting(
          probe: _staticProbe(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.denied,
          }, log),
          requester: _staticRequester(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.denied,
          }, log),
        );

        final status = await service.preflight();

        expect(status, TrackingPermissionStatus.denied);
        // Background MUST NOT be requested once fine has been denied
        // (Pitfall 5 ordering guard).
        expect(
          log.requestCalls.contains(Permission.locationAlways),
          isFalse,
        );
        expect(
          log.probeCalls.contains(Permission.locationAlways),
          isFalse,
        );
        // UX-03 ordering guard: notification MUST NOT be touched once
        // fine has been denied — the user has not agreed to location yet
        // so we must not escalate to a second permission prompt.
        expect(
          log.requestCalls.contains(Permission.notification),
          isFalse,
        );
        expect(
          log.probeCalls.contains(Permission.notification),
          isFalse,
        );
      },
    );

    test('returns permanentlyDenied when fine is already permanently denied, '
        'without calling requester', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.permanentlyDenied);
      expect(log.requestCalls, isEmpty);
      // UX-03 ordering guard: notification MUST NOT be touched once
      // fine has resolved permanentlyDenied.
      expect(
        log.probeCalls.contains(Permission.notification),
        isFalse,
      );
    });

    test('returns permanentlyDenied when fine request resolves '
        'permanentlyDenied', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
        }, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.permanentlyDenied);
      // Ordering guard: locationAlways must never be touched once fine
      // has resolved permanentlyDenied.
      expect(
        log.requestCalls.contains(Permission.locationAlways),
        isFalse,
      );
      expect(
        log.probeCalls.contains(Permission.locationAlways),
        isFalse,
      );
      // UX-03 ordering guard: notification must also never be touched.
      expect(
        log.requestCalls.contains(Permission.notification),
        isFalse,
      );
      expect(
        log.probeCalls.contains(Permission.notification),
        isFalse,
      );
    });

    test('NEVER calls Permission.locationAlways.request() before '
        'Permission.locationWhenInUse.request() has completed', () async {
      // This test captures the request-completion-order invariant directly:
      // we wire the requester to fail the test if locationAlways is called
      // before locationWhenInUse has fully resolved.
      final log = _CallLog();
      var whenInUseCompleted = false;

      Future<PermissionStatus> requester(Permission permission) async {
        log.requestCalls.add(permission);
        if (permission == Permission.locationWhenInUse) {
          // Simulate async resolution.
          await Future<void>.delayed(Duration.zero);
          whenInUseCompleted = true;
          return PermissionStatus.granted;
        }
        if (permission == Permission.locationAlways) {
          if (!whenInUseCompleted) {
            fail(
              'Pitfall 5 violation: locationAlways.request() was called '
              'before locationWhenInUse.request() completed.',
            );
          }
          return PermissionStatus.granted;
        }
        throw StateError('Unexpected request call: $permission');
      }

      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.denied,
          Permission.locationAlways: PermissionStatus.denied,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: requester,
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.fullyGranted);
      expect(log.requestCalls, <Permission>[
        Permission.locationWhenInUse,
        Permission.locationAlways,
      ]);
    });

    test('returns notificationDenied when fine + background are granted '
        'but notification request resolves denied', () async {
      // UX-03: location is OK, but POST_NOTIFICATIONS denial is a hard
      // block — the persistent foreground notification cannot be shown
      // without it on Android 13+.
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.granted,
          Permission.notification: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.notification: PermissionStatus.denied,
        }, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.notificationDenied);
      // Ordering: notification must be requested AFTER the location
      // dance has fully resolved.
      expect(
        log.requestCalls,
        <Permission>[Permission.notification],
      );
    });

    test('returns notificationDenied when fine granted, background denied, '
        'and notification denied', () async {
      // Parallel case to foregroundOnly above, but notification is
      // denied — UX-03 still hard-blocks even when location is only
      // partially granted.
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.denied,
          Permission.notification: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.locationAlways: PermissionStatus.denied,
          Permission.notification: PermissionStatus.denied,
        }, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.notificationDenied);
      // Strict ordering: notification request comes AFTER the
      // locationAlways request.
      final alwaysIdx = log.indexOfFirstRequest(Permission.locationAlways);
      final notifIdx = log.indexOfFirstRequest(Permission.notification);
      expect(alwaysIdx, isNonNegative);
      expect(notifIdx, isNonNegative);
      expect(alwaysIdx, lessThan(notifIdx));
    });

    test('returns fullyGranted when notification is already granted on probe, '
        'without calling notification requester', () async {
      // Guards against a regression where we always request even when
      // probe returns granted.
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.fullyGranted);
      expect(
        log.requestCalls.contains(Permission.notification),
        isFalse,
      );
    });

    test('returns fullyGranted when notification is initially denied then '
        'granted on request', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.granted,
          Permission.notification: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.notification: PermissionStatus.granted,
        }, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.fullyGranted);
      expect(
        log.requestCalls,
        <Permission>[Permission.notification],
      );
    });
  });

  group('TrackingPermissionService.currentStatus', () {
    test('returns fullyGranted when all three permissions are granted, '
        'without calling requester', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.currentStatus();

      expect(status, TrackingPermissionStatus.fullyGranted);
      expect(log.requestCalls, isEmpty);
    });

    test('returns foregroundOnly when fine granted, background denied, '
        'and notification granted, without calling requester', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.denied,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.currentStatus();

      expect(status, TrackingPermissionStatus.foregroundOnly);
      expect(log.requestCalls, isEmpty);
    });

    test('returns denied when fine is denied, without calling requester '
        'or touching notification', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.currentStatus();

      expect(status, TrackingPermissionStatus.denied);
      expect(log.requestCalls, isEmpty);
      // UX-03 ordering: notification must not be probed once fine is
      // denied (mirrors preflight).
      expect(
        log.probeCalls.contains(Permission.notification),
        isFalse,
      );
    });

    test('returns permanentlyDenied when fine is permanently denied, '
        'without calling requester or touching notification', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.currentStatus();

      expect(status, TrackingPermissionStatus.permanentlyDenied);
      expect(log.requestCalls, isEmpty);
      expect(
        log.probeCalls.contains(Permission.notification),
        isFalse,
      );
    });

    test('returns notificationDenied when location is granted and '
        'notification is denied, without calling requester', () async {
      // UX-03: currentStatus must classify a denied notification as
      // notificationDenied WITHOUT prompting the user (build-time
      // safety). This test pins the invariant.
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.granted,
          Permission.notification: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.currentStatus();

      expect(status, TrackingPermissionStatus.notificationDenied);
      expect(log.requestCalls, isEmpty);
    });

    test('returns notificationDenied when fine granted, background denied, '
        'and notification denied', () async {
      // Mirrors the preflight parallel case: foreground-only location
      // combined with a denied notification still resolves to the
      // blocking notificationDenied state.
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.locationAlways: PermissionStatus.denied,
          Permission.notification: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.currentStatus();

      expect(status, TrackingPermissionStatus.notificationDenied);
      expect(log.requestCalls, isEmpty);
    });
  });

  group('TrackingPermissionService.openSystemSettings', () {
    test('delegates to the injected SettingsOpener', () async {
      final log = _CallLog();
      var opened = 0;
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{}, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
        opener: () async {
          opened++;
          return true;
        },
      );

      final result = await service.openSystemSettings();

      expect(result, isTrue);
      expect(opened, 1);
    });
  });
}
