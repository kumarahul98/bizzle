import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';

/// Phase 2 minimal home screen (D-13).
///
/// Shows the app title, a short subtitle, and a single `Start commute`
/// CTA. Tapping the CTA probes — but does not request — the current
/// permission status: if fine location is permanently denied the user
/// is offered the D-09 settings deep-link dialog, otherwise the user
/// is navigated to the tracking screen, which runs the full D-07
/// two-step preflight in its own `initState`.
class HomeScreen extends ConsumerWidget {
  /// Create the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traevy')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Track your commute',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FractionallySizedBox(
              widthFactor: 0.7,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start commute'),
                onPressed: () => _handleStart(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStart(BuildContext context, WidgetRef ref) async {
    final service = ref.read(trackingPermissionServiceProvider);
    final status = await service.currentStatus();
    if (!context.mounted) return;
    if (status == TrackingPermissionStatus.permanentlyDenied) {
      await _showSettingsDialog(context, service);
      return;
    }
    await Navigator.pushNamed(context, kRouteTracking);
  }

  Future<void> _showSettingsDialog(
    BuildContext context,
    TrackingPermissionService service,
  ) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Location permission denied'),
        content: const Text(
          'Location permission is permanently denied. Open system '
          'settings to enable it?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (shouldOpen ?? false) {
      await service.openSystemSettings();
    }
  }
}
