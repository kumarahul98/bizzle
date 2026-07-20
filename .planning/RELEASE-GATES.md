# Release gates

Things that MUST be true before a release build ships to users. Not a nice-to-have
list — each item here is either a policy violation or a known-broken user experience
if skipped.

Check this file before building a release AAB/APK for the Play Store.

---

## 🔴 BLOCKING — Play Data Safety declaration (Phase 29, LOC-03)

**Status: NOT DONE as of 2026-07-20.**

`main` now contains code that uploads the user's saved Home and Office
coordinates to Firestore (`PreferencesSyncService`, merged from
`phase-29-sync-home-office`). The backend endpoints are deployed and live.

Before ANY release build carrying this code ships, the Play Console Data Safety
form must change from:

> no location data collected

to:

> **precise location** collected and stored, **linked to the user's account**

### Why this is a real blocker

Phase 21 originally decided (T-21-02) that these coordinates must never leave
the device, and wrote that guarantee into the schema's own dartdocs. Phase 29
reversed that deliberately — see D-01 in
`.planning/phases/29-sync-home-office-locations/29-PLAN.md`. The reversal is
legitimate, but it is exactly the kind of change Play's Data Safety declaration
exists to surface. Shipping undeclared collection of precise location risks app
removal and developer-account strikes.

### Why this file exists

Until 2026-07-20 the `phase-29-sync-home-office` branch being unmerged WAS the
enforcement mechanism — the code physically could not reach a release build.
That branch is now merged, so the structural guard is gone and this file
replaces it. Merging is not shipping; this gate is about shipping.

**T-21-03 was not reversed:** never log a coordinate. That still holds
everywhere.

---

## 🟡 Known-unverified — on-device behaviour

None of these are policy problems, but each is a real user-facing risk that no
test in this repo can catch. Full table with reasons lives under **Phase 23** in
`ROADMAP.md`.

- **Edge-to-edge rendering** (targetSdk 35). Android 15 forces edge-to-edge; the
  bottom nav, the `flutter_map` screens, and bottom sheets have never been seen
  on a device under it.
- **WR-05 force-stop recovery.** The fix has never been exercised against the
  original repro (`adb shell am force-stop traevy.traevy` while tracking, then
  Stop from the notification). Until it runs, "WR-05 is fixed" is an informed
  expectation, not a verified fact.
- **Phase 27/28** GPS drift, auto-pause default, per-page tour, widget resize.
- **Phase 29 end-to-end** — runnable now that the backend is live: fresh install
  → sign in → pins restore → first trip labels by geofence.

---

## 🟢 Satisfied

- **targetSdk 35** for Play compliance (`a5fffce`) — verified in the built APK
  via aapt2, not just source.
- **Phase 29 backend deployed** (2026-07-20) — SC#2 satisfied; the client can
  ship without stranding payloads, once the gate above clears.

---

## ⏳ Deadline, not a gate

- **Cloud Functions runtime.** `main` pins `nodejs24` but the LIVE backend still
  runs `nodejs20`, which **decommissions 2026-10-30** — after that date no deploy
  succeeds until the pinned runtime is deployed. Redeploy well before then, and
  watch it: a runtime swap is riskier than a code change, and all five REST routes
  share one `onRequest(app)` function.
