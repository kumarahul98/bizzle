import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wave 1 placeholder for the trip detail screen.
///
/// The full implementation lands in Wave 2 (Plan 04-04). This stub exists
/// so `lib/config/routes.dart` can register `kRouteTripDetail` as part of
/// Wave 1's shared infrastructure without breaking compilation of the
/// existing test suite (`app_bootstrap_test`, `home_screen_test`,
/// `app_test`) which all transitively load `routes.dart`.
///
/// Wave 2 will overwrite this file with the real screen.
class TripDetailScreen extends ConsumerWidget {
  /// Create the trip detail screen placeholder for [tripId].
  const TripDetailScreen({required this.tripId, super.key});

  /// UUID of the trip to display.
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip')),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
