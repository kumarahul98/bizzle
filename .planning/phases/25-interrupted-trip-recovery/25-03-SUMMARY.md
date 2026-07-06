# Plan 25-03 Execution Summary

## Overview
Wired the recovery prompt UI and backend detection for interrupted trips. 
- Integrated `TripStatePersister` into `TrackingNotifier` to detect an interrupted trip on app launch.
- Implemented `resumeInterruptedTrip` and `discardInterruptedTrip`.
- Built `RecoveryPromptDialog` based on the UI specifications.
- Hooked up `MainShell` to listen for the `TrackingInterrupted` state and show the dialog to the user without being dismissible.

## Tasks Completed
1. Task 1: Added UI Constants to `constants.dart`.
2. Task 2: Updated `TrackingState` and `TrackingNotifier` to handle interruptions.
3. Task 3: Created `RecoveryPromptDialog`.
4. Task 4: Wired `MainShell` to show the recovery dialog when an interrupted trip is detected.

## Tests
Tested manually using `tracking_providers_test.dart` and `flutter analyze` which both ran successfully.
