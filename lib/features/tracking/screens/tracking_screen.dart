import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/tracking/widgets/permission_banner.dart';
import 'package:traevy/features/tracking/widgets/permission_gate.dart';
import 'package:traevy/features/tracking/widgets/tracking_active_layout.dart';
import 'package:traevy/features/tracking/widgets/tracking_error_layout.dart';
import 'package:traevy/features/tracking/widgets/tracking_idle_layout.dart';
import 'package:traevy/features/tracking/widgets/tracking_status_layout.dart';

/// Live tracking screen (D-12). Watches `trackingStateProvider` and
/// renders the five sealed states via extracted layout widgets. Runs
/// the D-07 two-step permission pre-flight in `initState` so denied
/// and foreground-only branches render regardless of entry path.
class TrackingScreen extends ConsumerStatefulWidget {
  /// Create the tracking screen.
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  TrackingPermissionStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPreflight());
  }

  Future<void> _runPreflight() async {
    final service = ref.read(trackingPermissionServiceProvider);
    final status = await service.preflight();
    if (!mounted) return;
    setState(() => _permissionStatus = status);
  }

  Future<void> _openSettings() async {
    await ref.read(trackingPermissionServiceProvider).openSystemSettings();
  }

  Widget _buildBody(TrackingState state) {
    return switch (state) {
      TrackingIdle() => TrackingIdleLayout(
          onStart: () => ref.read(trackingStateProvider.notifier).start(),
        ),
      TrackingStarting() =>
        const TrackingStatusLayout(label: 'Starting GPS...'),
      TrackingActive(
        :final elapsedSeconds,
        :final distanceMeters,
        :final currentSpeedKmh,
      ) =>
        TrackingActiveLayout(
          elapsedSeconds: elapsedSeconds,
          distanceMeters: distanceMeters,
          currentSpeedKmh: currentSpeedKmh,
          onStop: () => ref.read(trackingStateProvider.notifier).stop(),
        ),
      TrackingStopping() =>
        const TrackingStatusLayout(label: 'Saving trip...'),
      TrackingError(:final message) => TrackingErrorLayout(
          message: message,
          onRetry: () => ref.read(trackingStateProvider.notifier).start(),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _permissionStatus;
    if (status == TrackingPermissionStatus.denied ||
        status == TrackingPermissionStatus.permanentlyDenied) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tracking')),
        body: PermissionGate(
          status: status!,
          onGrant: status == TrackingPermissionStatus.permanentlyDenied
              ? _openSettings
              : _runPreflight,
        ),
      );
    }
    final trackingState = ref.watch(trackingStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking')),
      body: Column(
        children: <Widget>[
          if (status == TrackingPermissionStatus.foregroundOnly)
            PermissionBanner(onOpenSettings: _openSettings),
          Expanded(child: _buildBody(trackingState)),
        ],
      ),
    );
  }
}
