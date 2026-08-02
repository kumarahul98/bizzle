// Regression guard for quick-260802-itr: the SOURCE Android manifest must
// never re-declare `android.permission.ACCESS_BACKGROUND_LOCATION`.
//
// WHY this matters: requesting that permission triggers Google Play's
// separate, strictly-reviewed background-location declaration (including a
// mandatory demo video) on every submission. The app dropped it because
// tracking is always user-initiated from the foreground and background GPS
// is covered entirely by the location-typed foreground service
// (`android:foregroundServiceType="location"` + `FOREGROUND_SERVICE_LOCATION`)
// started while the app is visible — `ACCESS_FINE_LOCATION` granted
// "while using the app" is sufficient on Android 10+.
//
// LIMIT: this test only inspects the SOURCE manifest
// (`android/app/src/main/AndroidManifest.xml`). A Flutter/Gradle plugin can
// still reintroduce the permission via manifest MERGING, which only shows
// up in a built artifact — this test cannot catch that. The merged-manifest
// / `aapt2 dump permissions` check is a manual step in Task 3's real-device
// checklist (quick-260802-itr PLAN.md, Task 3 step 8).
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
  });
}
