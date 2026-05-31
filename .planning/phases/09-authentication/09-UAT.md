---
status: testing
phase: 09-authentication
source: [09-01-SUMMARY.md, 09-02-SUMMARY.md, 09-03-SUMMARY.md, 09-04-SUMMARY.md, 09-05-SUMMARY.md]
started: 2026-05-29T12:21:09Z
updated: 2026-05-29T12:21:09Z
---

## Current Test

number: 1
name: Cold Start Smoke Test
expected: |
  Kill the app fully. Launch fresh from the home screen. The app boots without
  errors or a crash, briefly shows the splash/loading state, then settles into
  the correct screen (onboarding if not signed in, dashboard if a session is
  restored). No red error screen, no hang.
awaiting: user response

## Tests

### 1. Cold Start Smoke Test
expected: Kill the app fully, launch fresh. App boots without errors, shows the splash/loading state briefly, then settles on the correct screen (onboarding if signed out, dashboard if a session restores). No crash, no red error screen, no hang.
result: [pending]

### 2. Onboarding "Continue with Google" sign-in
expected: On the onboarding screen, tapping "Continue with Google" opens the native Google account picker. After choosing an account, sign-in completes and you land on the one-time confirmation ("success") screen showing your account, with a "Let's go" CTA into the app.
result: [pending]

### 3. Sign-in confirmation is one-time only
expected: After completing sign-in once and tapping "Let's go", killing and relaunching the app does NOT show the confirmation screen again — it goes straight to the app (dashboard).
result: [pending]

### 4. Existing trips get tagged to your account
expected: With trips already recorded locally before signing in, after your first sign-in those existing trips are retained and now associated with your account (no trips lost, none duplicated).
result: [pending]

### 5. Session persists across restart
expected: After signing in, fully kill and relaunch the app. You remain signed in (no re-prompt for Google sign-in) — the app restores your session automatically.
result: [pending]

### 6. Settings Account section reflects auth state
expected: In Settings, the Account section shows a "Sign in to back up" entry point when signed out, and shows your signed-in account (name/email) once authenticated.
result: [pending]

### 7. Sign-in bottom sheet — cancel is safe
expected: Opening the sign-in sheet (e.g. from Settings) and dismissing it or cancelling the Google picker returns you to where you were with no crash and no error — you simply stay signed out.
result: [pending]

### 8. Degrade-to-guest on unconfigured build
expected: On a build without Firebase configured (no google-services.json / init fails), the app still launches and runs as a guest. Sign-in buttons appear disabled (dimmed, with a tooltip) rather than crashing or throwing an error.
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps

[none yet]
