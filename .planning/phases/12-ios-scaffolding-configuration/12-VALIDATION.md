---
phase: 12
slug: ios-scaffolding-configuration
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-02
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Phase 12 has no new business logic — validation is build-time (analyze/build), config-presence greps, and human-gated device verification.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (existing) + build smoke + config-presence greps + manual device verification |
| **Config file** | analysis_options.yaml (very_good_analysis) |
| **Quick run command** | `flutter analyze` |
| **Full suite command** | `flutter test && flutter build ios --simulator` |
| **Estimated runtime** | ~90–180 seconds (first iOS build slower; pod install) |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze`
- **After every plan wave:** Run `flutter analyze && flutter build ios --simulator`
- **Before `/gsd:verify-work`:** `flutter build ios --simulator` green + all config greps pass
- **Phase gate (human):** real-device launch confirmed on the connected iPhone
- **Max feedback latency:** ~180 seconds

---

## Per-Task Verification Map

| Req | Behavior | Test Type | Automated Command | Pass Condition |
|-----|----------|-----------|-------------------|----------------|
| IOS-01 | App builds for Simulator | build smoke | `flutter build ios --simulator` | exit 0 |
| IOS-01 | App launches on Simulator | manual | `flutter run` on a booted Simulator | app renders |
| IOS-02 | App installs on real iPhone | manual (human-gated) | `flutter run` with device connected | app launches on device |
| IOS-03 | Location when-in-use string | grep | `grep -c NSLocationWhenInUseUsageDescription ios/Runner/Info.plist` | count > 0 |
| IOS-03 | Location always string | grep | `grep -c NSLocationAlwaysAndWhenInUseUsageDescription ios/Runner/Info.plist` | count > 0 |
| IOS-03 | UIBackgroundModes location | grep | `grep -A2 UIBackgroundModes ios/Runner/Info.plist \| grep -c location` | count > 0 |
| IOS-03 | Reversed-client-ID URL scheme | grep | `grep -c "com.googleusercontent.apps" ios/Runner/Info.plist` | count > 0 |
| IOS-03 | NSAppTransportSecurity present | grep | `grep -c NSAppTransportSecurity ios/Runner/Info.plist` | count ≥ 0 (only if exception needed) |
| IOS-03 | Keychain Sharing (Release) | grep | `grep -c keychain-access-groups ios/Runner/Release.entitlements` | count > 0 |
| IOS-03 | Keychain Sharing (Debug) | grep | `grep -c keychain-access-groups ios/Runner/DebugProfile.entitlements` | count > 0 |
| IOS-03 | GoogleService-Info.plist in target | grep | `grep -c GoogleService-Info.plist ios/Runner.xcodeproj/project.pbxproj` | count > 0 |
| IOS-03 | Podfile platform 15.0 | grep | `grep "platform :ios" ios/Podfile` | shows '15.0' |
| IOS-03 | pod install succeeds | build | `cd ios && pod install` | exit 0 |
| IOS-03 | Bundle ID com.travey.app | grep | `grep -rc "com.travey.app" ios/Runner.xcodeproj/project.pbxproj` | count > 0 |
| IOS-03 | App icons generated | fs check | `ls ios/Runner/Assets.xcassets/AppIcon.appiconset/ \| wc -l` | multiple png + Contents.json |
| IOS-03 | Launch screen present | fs check | `ls ios/Runner/Base.lproj/LaunchScreen.storyboard` | exists |
| — | Static analysis clean | analyze | `flutter analyze` | 0 new issues (baseline 0) |
| — | NotificationService iOS init compiles | build | `flutter build ios --simulator` | DarwinInitializationSettings resolves |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.* Phase 12 adds no new business logic. The only Dart edit (`notification_service.dart` Darwin init) is additive and covered by the existing `test/unit/` notification tests.

- [ ] After `notification_service.dart` edit: run `flutter test test/unit/` — existing notification tests still green.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| App launches on iOS Simulator | IOS-01 | Visual confirmation of render | Boot a Simulator, `flutter run`, confirm UI appears |
| App installs + launches on real iPhone | IOS-02 | Requires Apple ID signing + Developer Mode + physical device | Enable Developer Mode, set signing team in Xcode, connect iPhone, `flutter run`, trust dev cert on device, confirm launch |

---

## Validation Sign-Off

- [ ] All tasks have automated verify (build/grep) or are explicitly manual/human-gated
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (none required)
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
