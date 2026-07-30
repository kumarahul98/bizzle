---
phase: 37-release-play-internal-testing
created: 2026-07-25
status: not_started
mode: manual-gsd
requirements: [REL-01, LOC-03]
depends_on: [29, 36]
result: >
  NOT STARTED. Ships the v0.3 build already on main to the Play Store INTERNAL
  TESTING track. Two plans: 37-01 is the only code change (real release signing);
  37-02 is a human-gated ops runbook (keystore, signed AAB, Play Console
  first-publish, internal-testing release, post-upload UAT). Phase 30 is NOT a
  dependency — this ships what is on main today.
---

# Phase 37 — Release to Play Internal Testing

**Goal**: The v0.3 build on `main` is signed with a real upload key, its data collection is
accurately declared, and it is live on the Play **Internal testing** track for real-device
validation.

**Depends on**: Phase 29 (precise-location collection that drives the Data Safety change),
Phase 36 (last code batch + the deferred device-UAT it carries).

Phase 30 (geofence departure detection) is **explicitly not** a dependency — it is optional
and blocked on the 30-00 drive spike. This phase ships what is already on `main`.

---

## Why internal testing first

Internal testing is fast (live in minutes–hours, no full production review), caps at 100
testers, and is the vehicle on which the remaining on-device UAT runs against the *actual
shipped build*. The critical path here is **signing + content declarations**, not review
latency. Reaching production later is a separate, mostly-serial set of gates (see Forward
dependencies) and is out of scope for this phase.

## What is already satisfied (do not redo)

- targetSdk 35 (Play compliance), verified in the built APK via aapt2.
- Phase 29 backend deployed and live at `travey-298a7` (`api`, us-central1).
- `.gitignore` already excludes `key.properties`, `**/*.jks`, `**/*.keystore`.
- Launcher icon present (`ic_launcher.png`).

## The blockers this phase clears

1. Release build is signed with the **debug keystore** — Play rejects debug-signed uploads.
   `android/app/build.gradle.kts` release block.
2. Play **Data Safety** still says "no location collected" while `main` uploads precise
   Home/Office coords (`.planning/RELEASE-GATES.md`). Console-side.
3. **No privacy-policy URL** — mandatory once location collection is declared.

---

## 37-01 — Release signing (CODE — the only repo change)

**File:** `android/app/build.gradle.kts`

- Load a gitignored `android/key.properties` at file top (`java.util.Properties` +
  `FileInputStream`, guarded by `keystorePropertiesFile.exists()`).
- Add a `release` signing config inside `android { }`:
  ```kotlin
  signingConfigs {
      create("release") {
          keyAlias = keystoreProperties["keyAlias"] as String?
          keyPassword = keystoreProperties["keyPassword"] as String?
          storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
          storePassword = keystoreProperties["storePassword"] as String?
      }
  }
  ```
- Replace the release build block (currently `signingConfig = signingConfigs.getByName(
  "debug")`) with `signingConfig = signingConfigs.getByName("release")`.
- Comment it: release is signed by the upload key from `key.properties`; a missing file
  means the build is **unsigned** and fails on upload rather than silently debug-signing.
- Leave `minifyEnabled` **unset** (R8 off — Flutter default). Firebase + Google Sign-In need
  no ProGuard rules with minify disabled; do not enable it for this release.
- `pubspec.yaml` version stays `1.0.0+1` — correct for a first internal release.

**Success criteria covered:** SC1, SC2, SC3.

---

## 37-02 — Ops runbook (HUMAN-GATED)

### Keystore (you run keytool — interactive)
```bash
keytool -genkey -v -keystore ~/traevy-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Create `android/key.properties` (already gitignored — never commit):
```
storePassword=<store password you set>
keyPassword=<key password you set>
keyAlias=upload
storeFile=/Users/coolman/traevy-upload-keystore.jks
```
**Back up the keystore + passwords durably.** With Play App Signing a lost *upload* key can
be reset, but it is still a support round-trip.

### Pre-build verification (no device)
```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```
If the suite count or any failure is a surprise, stop and investigate before signing.

### Build + verify the signed AAB
```bash
flutter build appbundle --release   # build/app/outputs/bundle/release/app-release.aab
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab | head
```
Confirm the signer is the **upload key**, not "Android Debug". Optional device smoke-test of
the release build via `bundletool build-apks --mode=universal` + `install-apks` (the only
Step needing a phone; otherwise rely on the internal-testing install).

### Play Console — first publish (human)
1. **Create app**; confirm **Play App Signing** is enrolled (your `.jks` is the *upload*
   key; Play holds the app-signing key).
2. **Data Safety** → declare **precise location collected + stored + linked to the user's
   account** (clears the RELEASE-GATES blocker). Do NOT leave it at "no location collected".
3. **Privacy policy** → write + host (Google account/email for auth; precise location =
   Home/Office coords + commute routes; stored in Firebase linked to the account; no
   third-party sharing). Paste the URL into the listing. Mandatory once collection is
   declared.
4. **Content rating** questionnaire, **Target audience**, **App access** (provide test
   Google credentials so testers/reviewers get past sign-in — note the guest/Skip path),
   **Ads** = none, and a minimal **store listing** (title, short + full description, one
   feature graphic, a couple of phone screenshots).

**Success criteria covered:** SC4.

### Internal testing release
- Play Console → Testing → **Internal testing** → create release → upload the AAB → add
  tester emails → roll out. Live in minutes–hours; no full review. Share the opt-in URL.

**Success criteria covered:** SC5, SC6 (after installing via the opt-in link and exercising
Google Sign-In + a start/stop trip + a sync round-trip on the release build).

### Post-upload UAT (when a device is available — validates the shipped build)
Owner of record: `.planning/TRAEVY-DEVICE-CHECKS.xlsx`. From ROADMAP Phase 36 "Deferred
UAT":
- **A1–A6** — recording-notification channel/ranking. Phone only.
- **B1–B5** — auto-pause prompt + shared stop/pause confirmation dialog. Phone only.
- **C1** — GPS stationary drift: 15 min stationary, distance ~0. **Run outdoors or at a
  window** (indoor 30 m accuracy gate → false pass). The one check wanting an outdoor
  context.
- **C2** — full widget session (add → idle stats match → START → resize 4×2 → shrink 2×2 →
  PAUSED chip → STOP). Phone only.
- **Phase 29 E2E** — fresh install → sign in → pins restore from cloud → first trip labels
  by geofence.

Record results in the xlsx and flip `.planning/RELEASE-GATES.md` (Data Safety + the
known-unverified section) once verified.

**Success criteria covered:** SC7 (RELEASE-GATES flip once Data Safety lands). The batched
device UAT gates *widening* beyond internal, not the internal upload itself.

---

## Forward dependencies (noted; NOT blocking internal testing)

- **Closed-testing 14-day clock.** If the Play Console account is a **personal account
  created after Nov 2023**, production access requires a closed test with ≥12–20 testers for
  ≥14 continuous days, and **internal testing does not count**. Start a **closed** test
  early if aiming for production. Confirm the account type in Console.
- **Cloud Functions runtime.** Live backend runs `nodejs20` (decommissions **2026-10-30**);
  `main` pins `nodejs24`. Redeploy before the deadline — a backend deadline, not a
  client-ship gate. `.planning/RELEASE-GATES.md` "Deadline, not a gate".
- **Artifact Registry cleanup policy** (us-central1) — images accumulate/bill slowly.
  `firebase functions:artifacts:setpolicy`. Hygiene only.

---

## Success criteria (what must be TRUE)

1. `flutter build appbundle --release` produces an AAB signed by the **upload key** (not the
   debug keystore), confirmed by `jarsigner -verify`.
2. Release signing reads from a gitignored `android/key.properties`; a missing file fails the
   build loudly rather than silently debug-signing. `minifyEnabled` stays off.
3. `flutter analyze` clean and `flutter test` green immediately before the signed build.
4. Play Console Data Safety declares precise location collected + stored + linked to account;
   privacy-policy URL present; App-content shows no incomplete banners.
5. The AAB is live on the Internal testing track and installs via the opt-in link.
6. On the installed release build: Google Sign-In works, a start/stop trip records, and a
   sync round-trip completes.
7. `.planning/RELEASE-GATES.md` Data-Safety blocker flipped to satisfied once #4 lands.
