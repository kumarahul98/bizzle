---
plan: 37-01
phase: 37-release-play-internal-testing
status: complete
completed: 2026-07-25
commit: 54be9dc
requirements: [REL-01]
---

# 37-01 Summary — Release signing

## What was built

`android/app/build.gradle.kts` now signs release builds with a real upload key
instead of the debug keystore:

- **key.properties loader** at file top — `java.util.Properties` +
  `FileInputStream`, guarded by `keystorePropertiesFile.exists()`. Resolves via
  `rootProject.file("key.properties")` → `android/key.properties`, which is
  already gitignored (`android/.gitignore:12–14` covers `key.properties`,
  `**/*.keystore`, `**/*.jks`; verified absent + `git check-ignore` positive).
- **`release` signingConfig** inside `android { }` reading `keyAlias`,
  `keyPassword`, `storeFile` (wrapped in `file(...)`), `storePassword`.
- **Release buildType** switched from `signingConfigs.getByName("debug")` to
  `getByName("release")`.
- `minifyEnabled` left unset (R8 off, Flutter default) — Firebase + Google
  Sign-In need no ProGuard rules while minify is disabled.

Fail-loud contract: a missing `key.properties` leaves the config's fields null,
so the release build is **unsigned** and fails on Play upload rather than
silently producing a debug-signed AAB Play would reject.

## Success criteria — ALL VERIFIED end-to-end 2026-07-25

- **SC1** ✅ (AAB signed by upload key): `flutter build appbundle --release`
  produced a 56 MB `app-release.aab`; `jarsigner -verify -certs` reports
  `jar verified.` with signer `CN=Aparna J, OU=Traevy, O=Broken Magnet` — the
  generated upload key, NOT "Android Debug".
- **SC2** ✅ (reads gitignored key.properties, minify off): Gradle read
  `android/key.properties` (keyAlias `upload`, storeFile
  `/Users/coolman/traevy-upload-keystore.jks`) and signed automatically with no
  prompt. minify stayed off.
- **SC3** ✅ (analyze clean, tests green before signing): `flutter analyze` 0
  errors/warnings (295-info baseline); `flutter test` 946 passed / 10 skipped
  immediately before the build.

Note: the release build emitted a non-fatal "failed to strip debug symbols from
native libraries" warning (NDK strip unavailable) — the AAB is produced and
valid, just larger. Fine for internal testing; can be revisited before
production if bundle size matters.

## Verification notes

- Could not run a full Gradle evaluation in this environment: raw
  `./gradlew :app:help` fails with `IllegalArgumentException: 26` on **both** the
  baseline and the edited file (confirmed by stashing the edit) — a JVM/toolchain
  issue with raw-Gradle invocation here, unrelated to the change. The real signed
  build runs through `flutter build appbundle` (flutter-managed JDK) on the
  user's machine in 37-02.
- The edit is the canonical Flutter release-signing pattern and matches
  37-PLAN.md's vetted snippet exactly.

## Self-Check: PASSED

## Remaining (37-02 — human-gated, not code)

Keystore generation, signed AAB build + verify, Play Console first-publish
(Data Safety = precise location collected/linked, privacy-policy URL, listing,
content rating, app access), internal-testing release, post-upload device UAT.
Flip `.planning/RELEASE-GATES.md` Data-Safety blocker once the Console
declaration lands.
