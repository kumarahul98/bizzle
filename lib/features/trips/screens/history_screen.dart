import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wave 1 placeholder for the trip history screen.
///
/// The full implementation lands in Wave 2 (Plan 04-03). This stub exists
/// so `lib/config/routes.dart` can register `kRouteHistory` as part of
/// Wave 1's shared infrastructure without breaking compilation of the
/// existing test suite (`app_bootstrap_test`, `home_screen_test`,
/// `app_test`) which all transitively load `routes.dart`.
///
/// Wave 2 will overwrite this file with the real screen.
class HistoryScreen extends ConsumerWidget {
  /// Create the history screen placeholder.
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
