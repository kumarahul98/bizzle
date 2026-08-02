import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';

/// Captures the ordered sequence of Permission values passed through an
/// injected probe or requester closure, so tests can assert the two-step
/// contract (quick-260802-itr, superseding the earlier four-step dance):
/// `locationWhenInUse` MUST resolve granted before `notification` is ever
/// touched, and `Permission.locationAlways` must NEVER be touched at all.
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
  // ---------------------------------------------------------------------
  // ACCESS_BACKGROUND_LOCATION regression guard (Permission.locationAlways
  // is never touched)
  //
  // This group is the single most important artifact in this file. A
  // failure here means the Play Store background-location declaration
  // requirement (with its mandatory demo video) has silently returned —
  // quick-260802-itr removed ACCESS_BACKGROUND_LOCATION from the manifest
  // and Permission.locationAlways from the permission dance specifically to
  // avoid that requirement, relying instead on the location-typed
  // foreground service for background GPS.
  //
  // Deliberately, NONE of the probe/request maps below seed
  // Permission.locationAlways, so a stray call to either the probe or the
  // requester ALSO throws StateError ("Unexpected probe/request call") —
  // belt and braces on top of the explicit assertions.
  //
  // Every reachable outcome of preflight() and currentStatus() is driven,
  // on both platforms.
  // ---------------------------------------------------------------------
  group(
    'ACCESS_BACKGROUND_LOCATION regression guard '
    '(Permission.locationAlways is never touched)',
    () {
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      void expectLocationAlwaysNeverTouched(_CallLog log) {
        expect(
          log.probeCalls.contains(Permission.locationAlways),
          isFalse,
          reason:
              'Permission.locationAlways must never be probed — background '
              'GPS is covered by the location-typed foreground service, not '
              'a background-location permission.',
        );
        expect(
          log.requestCalls.contains(Permission.locationAlways),
          isFalse,
          reason:
              'Permission.locationAlways must never be requested — doing so '
              'would re-trigger the Play Store background-location '
              'declaration requirement.',
        );
      }

      group('preflight()', () {
        test('fine permanently denied on probe', () async {
          final log = _CallLog();
          final service = TrackingPermissionService.forTesting(
            probe: _staticProbe(<Permission, PermissionStatus>{
              Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
            }, log),
            requester: _staticRequester(<Permission, PermissionStatus>{}, log),
          );

          final status = await service.preflight();

          expect(status, TrackingPermissionStatus.permanentlyDenied);
          expectLocationAlwaysNeverTouched(log);
        });

        test('fine denied on probe, denied on request', () async {
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
          expectLocationAlwaysNeverTouched(log);
        });

        test(
          'fine denied on probe, permanently denied on request',
          () async {
            final log = _CallLog();
            final service = TrackingPermissionService.forTesting(
              probe: _staticProbe(<Permission, PermissionStatus>{
                Permission.locationWhenInUse: PermissionStatus.denied,
              }, log),
              requester: _staticRequester(<Permission, PermissionStatus>{
                Permission.locationWhenInUse:
                    PermissionStatus.permanentlyDenied,
              }, log),
            );

            final status = await service.preflight();

            expect(status, TrackingPermissionStatus.permanentlyDenied);
            expectLocationAlwaysNeverTouched(log);
          },
        );

        test(
          'fine denied on probe, granted on request, notification granted',
          () async {
            final log = _CallLog();
            final service = TrackingPermissionService.forTesting(
              probe: _staticProbe(<Permission, PermissionStatus>{
                Permission.locationWhenInUse: PermissionStatus.denied,
                Permission.notification: PermissionStatus.granted,
              }, log),
              requester: _staticRequester(<Permission, PermissionStatus>{
                Permission.locationWhenInUse: PermissionStatus.granted,
              }, log),
            );

            final status = await service.preflight();

            expect(status, TrackingPermissionStatus.fullyGranted);
            expectLocationAlwaysNeverTouched(log);
          },
        );

        test(
          'fine granted, notification denied on probe and on request',
          () async {
            final log = _CallLog();
            final service = TrackingPermissionService.forTesting(
              probe: _staticProbe(<Permission, PermissionStatus>{
                Permission.locationWhenInUse: PermissionStatus.granted,
                Permission.notification: PermissionStatus.denied,
              }, log),
              requester: _staticRequester(<Permission, PermissionStatus>{
                Permission.notification: PermissionStatus.denied,
              }, log),
            );

            final status = await service.preflight();

            expect(status, TrackingPermissionStatus.notificationDenied);
            expectLocationAlwaysNeverTouched(log);
          },
        );

        test('fine granted, notification granted', () async {
          final log = _CallLog();
          final service = TrackingPermissionService.forTesting(
            probe: _staticProbe(<Permission, PermissionStatus>{
              Permission.locationWhenInUse: PermissionStatus.granted,
              Permission.notification: PermissionStatus.granted,
            }, log),
            requester: _staticRequester(<Permission, PermissionStatus>{}, log),
          );

          final status = await service.preflight();

          expect(status, TrackingPermissionStatus.fullyGranted);
          expectLocationAlwaysNeverTouched(log);
        });

        test('iOS: fine granted resolves fullyGranted', () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          final log = _CallLog();
          final service = TrackingPermissionService.forTesting(
            probe: _staticProbe(<Permission, PermissionStatus>{
              Permission.locationWhenInUse: PermissionStatus.granted,
            }, log),
            requester: _staticRequester(<Permission, PermissionStatus>{}, log),
          );

          final status = await service.preflight();

          expect(status, TrackingPermissionStatus.fullyGranted);
          expectLocationAlwaysNeverTouched(log);
        });
      });

      group('currentStatus()', () {
        test('fine permanently denied on probe', () async {
          final log = _CallLog();
          final service = TrackingPermissionService.forTesting(
            probe: _staticProbe(<Permission, PermissionStatus>{
              Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
            }, log),
            requester: _staticRequester(<Permission, PermissionStatus>{}, log),
          );

          final status = await service.currentStatus();

          expect(status, TrackingPermissionStatus.permanentlyDenied);
          expectLocationAlwaysNeverTouched(log);
        });

        test('fine denied on probe', () async {
          final log = _CallLog();
          final service = TrackingPermissionService.forTesting(
            probe: _staticProbe(<Permission, PermissionStatus>{
              Permission.locationWhenInUse: PermissionStatus.denied,
            }, log),
            requester: _staticRequester(<Permission, PermissionStatus>{}, log),
          );

          final status = await service.currentStatus();

          expect(status, TrackingPermissionStatus.denied);
          expectLocationAlwaysNeverTouched(log);
        });

        test('fine granted, notification denied', () async {
          final log = _CallLog();
          final service = TrackingPermissionService.forTesting(
            probe: _staticProbe(<Permission, PermissionStatus>{
              Permission.locationWhenInUse: PermissionStatus.granted,
              Permission.notification: PermissionStatus.denied,
            }, log),
            requester: _staticRequester(<Permission, PermissionStatus>{}, log),
          );

          final status = await service.currentStatus();

          expect(status, TrackingPermissionStatus.notificationDenied);
          expectLocationAlwaysNeverTouched(log);
        });

        test('fine granted, notification granted', () async {
          final log = _CallLog();
          final service = TrackingPermissionService.forTesting(
            probe: _staticProbe(<Permission, PermissionStatus>{
              Permission.locationWhenInUse: PermissionStatus.granted,
              Permission.notification: PermissionStatus.granted,
            }, log),
            requester: _staticRequester(<Permission, PermissionStatus>{}, log),
          );

          final status = await service.currentStatus();

          expect(status, TrackingPermissionStatus.fullyGranted);
          expectLocationAlwaysNeverTouched(log);
        });

        test('iOS: fine granted resolves fullyGranted', () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          final log = _CallLog();
          final service = TrackingPermissionService.forTesting(
            probe: _staticProbe(<Permission, PermissionStatus>{
              Permission.locationWhenInUse: PermissionStatus.granted,
            }, log),
            requester: _staticRequester(<Permission, PermissionStatus>{}, log),
          );

          final status = await service.currentStatus();

          expect(status, TrackingPermissionStatus.fullyGranted);
          expectLocationAlwaysNeverTouched(log);
        });
      });
    },
  );

  group('TrackingPermissionService.preflight', () {
    test('returns fullyGranted when both permissions are already '
        'granted, never calling requester', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.fullyGranted);
      expect(log.requestCalls, isEmpty);
      expect(log.probeCalls.first, Permission.locationWhenInUse);
    });

    test('returns fullyGranted when fine is denied then granted on '
        'request, and notification already granted', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.denied,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
        }, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.fullyGranted);
      expect(log.requestCalls, <Permission>[Permission.locationWhenInUse]);
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
        // Ordering guard: notification MUST NOT be touched once fine has
        // been denied — the user has not agreed to location yet so we
        // must not escalate to a second permission prompt. (This also
        // implicitly asserts the new locationAlways-never-touched
        // invariant, since the maps above never seed it.)
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
      expect(
        log.requestCalls.contains(Permission.notification),
        isFalse,
      );
      expect(
        log.probeCalls.contains(Permission.notification),
        isFalse,
      );
    });

    test('returns notificationDenied when fine is granted but notification '
        'request resolves denied', () async {
      // UX-03: location is OK, but POST_NOTIFICATIONS denial is a hard
      // block — the persistent foreground notification cannot be shown
      // without it on Android 13+.
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.notification: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.notification: PermissionStatus.denied,
        }, log),
      );

      final status = await service.preflight();

      expect(status, TrackingPermissionStatus.notificationDenied);
      // Ordering: notification must be requested AFTER locationWhenInUse
      // has resolved granted.
      expect(
        log.requestCalls,
        <Permission>[Permission.notification],
      );
    });

    test('returns fullyGranted when notification is already granted on probe, '
        'without calling notification requester', () async {
      // Guards against a regression where we always request even when
      // probe returns granted.
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
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
    test('returns fullyGranted when both permissions are granted, '
        'without calling requester', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{}, log),
      );

      final status = await service.currentStatus();

      expect(status, TrackingPermissionStatus.fullyGranted);
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

  group('TrackingPermissionService.requestWhenInUse', () {
    test(
      'returns granted without calling requester when already granted',
      () async {
        final log = _CallLog();
        final service = TrackingPermissionService.forTesting(
          probe: _staticProbe(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.granted,
          }, log),
          requester: _staticRequester(<Permission, PermissionStatus>{}, log),
        );

        final status = await service.requestWhenInUse();

        expect(status, LocationWhenInUseStatus.granted);
        expect(log.requestCalls, isEmpty);
        expect(
          log.probeCalls.contains(Permission.locationAlways),
          isFalse,
        );
        expect(
          log.probeCalls.contains(Permission.notification),
          isFalse,
        );
      },
    );

    test('returns granted when probe denied but request grants', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.granted,
        }, log),
      );

      final status = await service.requestWhenInUse();

      expect(status, LocationWhenInUseStatus.granted);
      expect(log.requestCalls, <Permission>[Permission.locationWhenInUse]);
      expect(
        log.requestCalls.contains(Permission.locationAlways),
        isFalse,
      );
      expect(
        log.requestCalls.contains(Permission.notification),
        isFalse,
      );
    });

    test('returns denied when probe denied and request also denies', () async {
      final log = _CallLog();
      final service = TrackingPermissionService.forTesting(
        probe: _staticProbe(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.denied,
        }, log),
        requester: _staticRequester(<Permission, PermissionStatus>{
          Permission.locationWhenInUse: PermissionStatus.denied,
        }, log),
      );

      final status = await service.requestWhenInUse();

      expect(status, LocationWhenInUseStatus.denied);
      expect(
        log.requestCalls.contains(Permission.locationAlways),
        isFalse,
      );
      expect(
        log.requestCalls.contains(Permission.notification),
        isFalse,
      );
    });

    test(
      'returns permanentlyDenied on probe without calling requester',
      () async {
        final log = _CallLog();
        final service = TrackingPermissionService.forTesting(
          probe: _staticProbe(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
          }, log),
          requester: _staticRequester(<Permission, PermissionStatus>{}, log),
        );

        final status = await service.requestWhenInUse();

        expect(status, LocationWhenInUseStatus.permanentlyDenied);
        expect(log.requestCalls, isEmpty);
        expect(
          log.probeCalls.contains(Permission.locationAlways),
          isFalse,
        );
        expect(
          log.probeCalls.contains(Permission.notification),
          isFalse,
        );
      },
    );

    test(
      'returns permanentlyDenied when probe denied and request '
      'permanently denies',
      () async {
        final log = _CallLog();
        final service = TrackingPermissionService.forTesting(
          probe: _staticProbe(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.denied,
          }, log),
          requester: _staticRequester(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
          }, log),
        );

        final status = await service.requestWhenInUse();

        expect(status, LocationWhenInUseStatus.permanentlyDenied);
        expect(
          log.requestCalls.contains(Permission.locationAlways),
          isFalse,
        );
        expect(
          log.requestCalls.contains(Permission.notification),
          isFalse,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // iOS branch (IOS-09 / IOS-10)
  //
  // These tests exercise the iOS platform branch in preflight() and
  // currentStatus(). Since quick-260802-itr, D-2 is unconditional
  // (Permission.locationAlways is never touched on ANY platform), so the
  // iOS branch collapses to: locationWhenInUse granted -> fullyGranted,
  // with neither locationAlways nor notification ever probed or requested.
  //
  // DEC-C: iOS is a PAUSED platform (v0.2). This collapse is accepted as a
  // side effect for now; iOS background-location strategy must be
  // re-decided when the platform resumes — iOS has no Android
  // foreground-service equivalent, so the reasoning that justifies this
  // change on Android does NOT transfer to iOS.
  //
  // Test technique: `debugDefaultTargetPlatformOverride = TargetPlatform.iOS`
  // exercises the iOS code path without dart:io Platform (Pitfall 2).
  // -------------------------------------------------------------------------

  group('iOS branch (IOS-09/IOS-10) — preflight()', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'returns fullyGranted on iOS once locationWhenInUse resolves granted, '
      'and never probes locationAlways or notification',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final log = _CallLog();
        final service = TrackingPermissionService.forTesting(
          probe: _staticProbe(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.granted,
            // locationAlways and notification intentionally absent — must
            // never be probed.
          }, log),
          requester: _staticRequester(<Permission, PermissionStatus>{}, log),
        );

        final status = await service.preflight();

        expect(status, TrackingPermissionStatus.fullyGranted);
        expect(
          log.probeCalls.contains(Permission.locationAlways),
          isFalse,
        );
        expect(
          log.probeCalls.contains(Permission.notification),
          isFalse,
          reason: 'preflight() on iOS must never probe Permission.notification',
        );
        expect(
          log.requestCalls.contains(Permission.notification),
          isFalse,
          reason:
              'preflight() on iOS must never request Permission.notification',
        );
      },
    );

    test(
      // DEC-C: this state used to resolve to `foregroundOnly` when the app
      // still requested locationAlways on iOS. That variant is gone and
      // locationAlways is never touched, so When-In-Use alone now resolves
      // to fullyGranted here too, same as the fully-granted case above.
      // iOS (v0.2, currently paused): the background-location strategy has
      // to be re-decided when iOS resumes — iOS has no foreground-service
      // equivalent to fall back on.
      'returns fullyGranted on iOS when only When-In-Use is granted (DEC-C), '
      'and never probes notification',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final log = _CallLog();
        final service = TrackingPermissionService.forTesting(
          probe: _staticProbe(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.granted,
          }, log),
          requester: _staticRequester(<Permission, PermissionStatus>{}, log),
        );

        final status = await service.preflight();

        expect(status, TrackingPermissionStatus.fullyGranted);
        expect(
          log.probeCalls.contains(Permission.notification),
          isFalse,
        );
        expect(
          log.requestCalls.contains(Permission.notification),
          isFalse,
        );
      },
    );

    test(
      'never returns notificationDenied on iOS (RESEARCH Pitfall 5)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final log = _CallLog();
        // Simulate iOS where location is granted — on iOS, preflight()
        // must NOT return notificationDenied because tracking on iOS does
        // not depend on notification permission, and notification is
        // never even probed.
        final service = TrackingPermissionService.forTesting(
          probe: _staticProbe(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.granted,
          }, log),
          requester: _staticRequester(<Permission, PermissionStatus>{}, log),
        );

        final status = await service.preflight();

        expect(
          status,
          isNot(equals(TrackingPermissionStatus.notificationDenied)),
          reason:
              'D-06: preflight() must never return notificationDenied on iOS',
        );
        expect(status, TrackingPermissionStatus.fullyGranted);
      },
    );
  });

  group('iOS branch (IOS-09) — currentStatus()', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'never returns notificationDenied on iOS when location is granted '
      '(RESEARCH Pitfall 5)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final log = _CallLog();
        // On iOS, currentStatus() must not reach the notification probe —
        // the result reflects location-only state.
        final service = TrackingPermissionService.forTesting(
          probe: _staticProbe(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.granted,
          }, log),
          requester: _staticRequester(<Permission, PermissionStatus>{}, log),
        );

        final status = await service.currentStatus();

        expect(
          status,
          isNot(equals(TrackingPermissionStatus.notificationDenied)),
          reason:
              'RESEARCH Pitfall 5: currentStatus() must never return '
              'notificationDenied on iOS — Start button would be permanently '
              'disabled even though location is granted',
        );
        expect(status, TrackingPermissionStatus.fullyGranted);
      },
    );

    test(
      'never probes Permission.notification or Permission.locationAlways '
      'on iOS in currentStatus()',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final log = _CallLog();
        final service = TrackingPermissionService.forTesting(
          probe: _staticProbe(<Permission, PermissionStatus>{
            Permission.locationWhenInUse: PermissionStatus.granted,
            // notification and locationAlways absent — currentStatus()
            // must not reach either.
          }, log),
          requester: _staticRequester(<Permission, PermissionStatus>{}, log),
        );

        await service.currentStatus();

        expect(
          log.probeCalls.contains(Permission.notification),
          isFalse,
          reason: 'D-06: currentStatus() on iOS must never probe notification',
        );
        expect(
          log.probeCalls.contains(Permission.locationAlways),
          isFalse,
        );
      },
    );
  });
}
