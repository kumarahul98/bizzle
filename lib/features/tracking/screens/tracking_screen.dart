import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
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
      TrackingStarting() => const TrackingStatusLayout(
        label: 'Starting GPS...',
      ),
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
      TrackingStopping() => const TrackingStatusLayout(label: 'Saving trip...'),
      TrackingError(:final message) => TrackingErrorLayout(
        message: message,
        onRetry: () => ref.read(trackingStateProvider.notifier).start(),
        onOpenSettings: _openSettings,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Surface the D-10 / save / failure snackbar exactly once per
    // trip_finalized cycle. The notifier transitions
    // TrackingStopping → TrackingIdle after persistFinalizedTrip runs,
    // and the PersistResult is stashed in a last-result slot we consume
    // here. Listening on the provider and consuming on the final edge
    // into TrackingIdle keeps the snackbar bound to a single state
    // transition even if the widget rebuilds for unrelated reasons.
    ref.listen<TrackingState>(trackingStateProvider, (previous, next) {
      if (previous is TrackingStopping && next is TrackingIdle) {
        _handlePersistResult(
          ref.read(trackingStateProvider.notifier).consumeLastPersistResult(),
        );
      }
    });

    final status = _permissionStatus;
    if (status == TrackingPermissionStatus.denied ||
        status == TrackingPermissionStatus.permanentlyDenied ||
        status == TrackingPermissionStatus.notificationDenied) {
      // UX-03: notificationDenied is a hard block — the persistent
      // foreground notification cannot be shown on Android 13+ without
      // POST_NOTIFICATIONS. Route it through PermissionGate with an
      // Open-settings CTA (the system will not re-prompt after "Don't
      // allow"). permanentlyDenied already routes to Open-settings;
      // denied re-runs the preflight to retry the two-step location
      // dance.
      return Scaffold(
        appBar: AppBar(title: const Text('Tracking')),
        body: PermissionGate(
          status: status!,
          onGrant: status == TrackingPermissionStatus.denied
              ? _runPreflight
              : _openSettings,
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

  void _handlePersistResult(PersistResult? result) {
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final text = switch (result) {
      PersistSaved() => 'Trip saved',
      PersistDiscardedTooShort() => 'Trip too short to save',
      PersistFailed(:final error) => 'Unable to save trip: $error',
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
