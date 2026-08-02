// Regression guard for Play-eligibility-critical permission ABSENCES in the
// SOURCE Android manifest. Covers two independent omissions:
//
//   - quick-260802-itr: the manifest must never re-declare
//     `android.permission.ACCESS_BACKGROUND_LOCATION`.
//   - quick-260802-x1q: the manifest must never re-declare
//     `android.permission.USE_EXACT_ALARM` or its sibling
//     `android.permission.SCHEDULE_EXACT_ALARM`.
//
// WHY ACCESS_BACKGROUND_LOCATION matters: requesting that permission
// triggers Google Play's separate, strictly-reviewed background-location
// declaration (including a mandatory demo video) on every submission. The
// app dropped it because tracking is always user-initiated from the
// foreground and background GPS is covered entirely by the location-typed
// foreground service (`android:foregroundServiceType="location"` +
// `FOREGROUND_SERVICE_LOCATION`) started while the app is visible —
// `ACCESS_FINE_LOCATION` granted "while using the app" is sufficient on
// Android 10+.
//
// WHY the exact-alarm permission matters: Google Play restricts it to apps
// whose core functionality is "calendar" or "alarm clock". Traevy is a
// commute tracker, so it is not eligible, and declaring it fails the Play
// app-content declaration across all tracks. Both scheduling call sites
// were switched to `AndroidScheduleMode.inexactAllowWhileIdle` so the
// permission is no longer needed at all.
//
// LIMIT: this test only inspects the SOURCE manifest
// (`android/app/src/main/AndroidManifest.xml`). A Flutter/Gradle plugin can
// still reintroduce a permission via manifest MERGING, which only shows up
// in a built artifact — this test cannot catch that. The merged-manifest
// / `aapt2 dump permissions` check is a manual step in Task 3's real-device
// checklist (quick-260802-itr PLAN.md, Task 3 step 8), and applies equally
// to the exact-alarm permissions guarded here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidManifest.xml source permissions (quick-260802-itr guard)', () {
    test(
      'does not declare ACCESS_BACKGROUND_LOCATION, and still declares the '
      'permissions that make the foreground-service approach safe',
      () {
        // `flutter test` runs with CWD at the package root, so this
        // relative path resolves the same way it does for every other
        // dart:io-based test in this repo. If that assumption ever breaks,
        // fail loudly here rather than let the negative assertion below
        // pass vacuously against a file that was never actually read.
        final manifestFile = File(
          'android/app/src/main/AndroidManifest.xml',
        );
        expect(
          manifestFile.existsSync(),
          isTrue,
          reason:
              'Expected android/app/src/main/AndroidManifest.xml to exist '
              'relative to the CWD `flutter test` runs from (the package '
              'root). If this fails, the CWD assumption broke and every '
              'assertion below would otherwise be checking nothing.',
        );

        final contents = manifestFile.readAsStringSync();

        expect(
          contents.contains('ACCESS_BACKGROUND_LOCATION'),
          isFalse,
          reason:
              'ACCESS_BACKGROUND_LOCATION must not be declared in the '
              'source manifest — it re-triggers the Play Store '
              'background-location declaration (and its mandatory demo '
              'video) that quick-260802-itr deliberately removed. '
              'Background GPS is covered by the location-typed foreground '
              'service instead.',
        );

        // Positive controls: load-bearing. Without these, deleting the
        // ENTIRE permissions block (or the whole file) would make the
        // negative assertion above pass vacuously.
        expect(
          contents.contains('android.permission.ACCESS_FINE_LOCATION'),
          isTrue,
          reason:
              'ACCESS_FINE_LOCATION must remain — it is what the '
              'foreground-service approach depends on for while-in-use GPS.',
        );
        expect(
          contents.contains(
            'android.permission.FOREGROUND_SERVICE_LOCATION',
          ),
          isTrue,
          reason:
              'FOREGROUND_SERVICE_LOCATION must remain — required on '
              'Android 14+ for a location-typed foreground service to call '
              'startForeground() without throwing.',
        );
        expect(
          contents.contains('foregroundServiceType="location"'),
          isTrue,
          reason:
              'The flutter_background_service override must keep '
              'foregroundServiceType="location" — this is the mechanism '
              'that replaces ACCESS_BACKGROUND_LOCATION for background GPS.',
        );
      },
    );

    test(
      'does not declare USE_EXACT_ALARM or SCHEDULE_EXACT_ALARM, and still '
      'declares permissions proving the block was not deleted wholesale',
      () {
        final manifestFile = File(
          'android/app/src/main/AndroidManifest.xml',
        );
        expect(
          manifestFile.existsSync(),
          isTrue,
          reason:
              'Expected android/app/src/main/AndroidManifest.xml to exist '
              'relative to the CWD `flutter test` runs from (the package '
              'root). If this fails, the CWD assumption broke and every '
              'assertion below would otherwise be checking nothing.',
        );

        final contents = manifestFile.readAsStringSync();

        expect(
          contents.contains('USE_EXACT_ALARM'),
          isFalse,
          reason:
              'USE_EXACT_ALARM must not be declared in the source manifest '
              '— Google Play restricts this permission to apps whose core '
              'functionality is "calendar" or "alarm clock". Traevy is a '
              'commute tracker and is therefore ineligible; re-adding it '
              'fails the Play app-content declaration across all tracks.',
        );
        expect(
          contents.contains('SCHEDULE_EXACT_ALARM'),
          isFalse,
          reason:
              'SCHEDULE_EXACT_ALARM is not an acceptable substitute for '
              'USE_EXACT_ALARM (D-3, quick-260802-x1q) — the app is meant '
              'to ship with no exact-alarm permission at all, not merely a '
              'different one.',
        );

        // Positive controls: load-bearing. Without these, deleting the
        // ENTIRE permissions block (or the whole file) would make the
        // negative assertions above pass vacuously.
        expect(
          contents.contains('android.permission.POST_NOTIFICATIONS'),
          isTrue,
          reason:
              'POST_NOTIFICATIONS must remain — it is unrelated to the '
              'exact-alarm removal and its absence here would mean the '
              'whole permissions block was deleted, not just the target '
              'lines.',
        );
        expect(
          contents.contains('android.permission.ACCESS_FINE_LOCATION'),
          isTrue,
          reason:
              'ACCESS_FINE_LOCATION must remain — it is unrelated to the '
              'exact-alarm removal and its absence here would mean the '
              'whole permissions block was deleted, not just the target '
              'lines.',
        );
      },
    );
  });
}
