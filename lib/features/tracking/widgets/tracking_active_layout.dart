import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/widgets/elapsed_display.dart';
import 'package:traevy/features/tracking/widgets/faux_map_card.dart';
import 'package:traevy/features/tracking/widgets/recording_header.dart';
import 'package:traevy/features/tracking/widgets/stop_button.dart';
import 'package:traevy/features/tracking/widgets/tracking_tiles_row.dart';

/// Active-state body for the tracking screen: Variant A layout.
///
/// Replaces the old AppBar with [RecordingHeader] and composes
/// [ElapsedDisplay], [TrackingTilesRow], [FauxMapCard], and [StopButton]
/// under a [SafeArea] + 20dp horizontal / 16dp vertical padding.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §4 Active Recording.
class TrackingActiveLayout extends StatelessWidget {
  /// Creates the active layout with current live values.
  const TrackingActiveLayout({
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.currentSpeedKmh,
    required this.onStop,
    this.timeStuckSeconds = 0,
    this.direction = kDirectionToOffice,
    super.key,
  });

  /// Current elapsed time in whole seconds.
  final int elapsedSeconds;

  /// Current trip distance in meters.
  final double distanceMeters;

  /// Current speed in km/h.
  final double currentSpeedKmh;

  /// Handler invoked when the user taps the Stop button.
  final VoidCallback onStop;

  /// Running stuck-in-traffic seconds for the STUCK tile.
  final int timeStuckSeconds;

  /// Trip direction — used to derive the header label.
  final String direction;

  String get _directionLabel =>
      direction == kDirectionToHome ? 'To home' : 'To office';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            RecordingHeader(directionLabel: _directionLabel),
            const Spacer(),
            ElapsedDisplay(durationSeconds: elapsedSeconds),
            const SizedBox(height: 32),
            TrackingTilesRow(
              elapsedSeconds: elapsedSeconds,
              distanceMeters: distanceMeters,
              currentSpeedKmh: currentSpeedKmh,
              timeStuckSeconds: timeStuckSeconds,
            ),
            const SizedBox(height: 24),
            const FauxMapCard(),
            const Spacer(),
            StopButton(onPressed: onStop),
          ],
        ),
      ),
    );
  }
}
