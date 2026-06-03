# Traevy — Commute Tracker

A Flutter app that tracks daily commutes via manual start/stop GPS recording, stores data locally with Drift (offline-first), syncs to a Firebase backend, and shows stats like time spent in traffic and weekly trends.

- **Platforms:** Android + iOS (iOS min deployment target 15.0)
- **App id:** `traevy.traevy` (Android) · `com.travey.app` (iOS bundle id)
- **Stack:** Flutter · Drift (SQLite) · Riverpod · Firebase Auth/Functions/Firestore · geolocator + flutter_background_service

---

## First-time setup

```bash
flutter pub get                  # fetch dependencies
dart run build_runner build --delete-conflicting-outputs   # generate Drift/Riverpod code (*.g.dart)
```

Generated `*.g.dart` files are committed; re-run `build_runner` after changing any Drift table, DAO, or annotated provider. Use `dart run build_runner watch` during active development.

Sanity checks:

```bash
flutter analyze                  # static analysis
flutter test                     # full test suite
flutter devices                  # list connected devices + their ids
```

---

## Build & install — Android (APK)

```bash
# Release APK (universal) -> build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release

# Smaller, per-architecture APKs (arm64-v8a / armeabi-v7a / x86_64)
flutter build apk --release --split-per-abi
```

Install the built APK on a connected Android device / emulator:

```bash
flutter install --release                                   # installs the built app
# or with the Android SDK directly:
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Build + install + launch in one step on a connected Android device:

```bash
flutter run --release -d <android-device-id>                # id from `flutter devices`
```

> Tip: test GPS/background tracking on a **real Android device** — emulator GPS is unreliable for traffic calculations.

---

## Install on iOS (real iPhone, free provisioning)

This project installs to a physical iPhone via Xcode **free (personal) provisioning** — no TestFlight/App Store. The signing cert is valid for **7 days**, after which you must re-sign (just re-run `flutter run`).

**One-time prerequisites**

```bash
sudo xcodebuild -license accept   # accept the Xcode license (once per machine)
```

- Xcode installed; CocoaPods available (`pod --version`).
- iPhone connected via USB, **unlocked**, and "Trust This Computer" accepted.
- **Developer Mode** enabled on the iPhone (Settings → Privacy & Security → Developer Mode).
- A signing team selected in Xcode (`ios/Runner.xcodeproj`) — this project uses Personal Team `2DG5SFXZ5Z`.

**Install + launch**

```bash
flutter devices                                             # find the iPhone's device id
flutter run --release -d <iphone-device-id>                 # builds, signs, installs, launches
```

`flutter run` re-signs automatically with the selected team. The release build runs **untethered** — once it launches you can disconnect the cable and use the app standalone (the attached session ends with "Lost connection to device", which is expected). The app stays installed on the Home Screen.

To re-sign after the 7-day cert expires, just connect the iPhone and run `flutter run -d <iphone-device-id>` again.

> Background-GPS behavior can only be validated on a **real device** — the iOS Simulator cannot reproduce CoreLocation background suspension.

---

## Backend (Firebase Cloud Functions)

```bash
cd backend/functions
npm install
npm run build                    # compile TypeScript
firebase emulators:start         # run Auth + Firestore + Functions locally
firebase deploy --only functions # deploy Cloud Functions
firebase deploy --only firestore:rules
```
