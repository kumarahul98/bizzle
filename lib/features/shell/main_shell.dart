import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
import 'package:traevy/features/settings/screens/settings_screen.dart';
import 'package:traevy/features/shell/providers/main_shell_provider.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/sync/restore_controller.dart';
import 'package:traevy/sync/sync_engine.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  StreamSubscription<Uri?>? _sub;
  bool _hasRunAutoRestoreForCurrentSession = false;

  @override
  void initState() {
    super.initState();
    _sub = HomeWidget.widgetClicked.listen(_onWidgetClicked);
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) _onWidgetClicked(uri);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onWidgetClicked(Uri? uri) {
    if (uri?.host == 'widget') {
      final action = uri?.queryParameters['action'];
      if (action == 'start') {
        _handleStart();
      } else if (action == 'pause') {
        _showConfirmationDialog('Pause Commute', 'Are you sure you want to pause?', () {
          ref.read(trackingStateProvider.notifier).pause();
        });
      } else if (action == 'stop') {
        _showConfirmationDialog('Stop Commute', 'Are you sure you want to stop and save this trip?', () {
          ref.read(trackingStateProvider.notifier).stop();
        });
      }
    }
  }

  void _showConfirmationDialog(String title, String message, VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStart() async {
    // Switch to Dashboard tab
    ref.read(mainShellIndexProvider.notifier).setIndex(0);

    final service = ref.read(trackingPermissionServiceProvider);
    final status = await service.preflight();
    if (!mounted) return;
    if (status == TrackingPermissionStatus.denied) return;
    
    if (status == TrackingPermissionStatus.permanentlyDenied || 
        status == TrackingPermissionStatus.notificationDenied) {
      // Permissions are denied, standard logic will handle prompts if user clicks normally.
      // But we can just surface a quick snackbar here.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions required to start tracking.')),
      );
      return;
    }
    
    ref.read(trackingStateProvider.notifier).start();
  }

  Future<void> _runAutoRestore() async {
    ref.read(syncEngineProvider).pauseUploads();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kAutoRestoreInProgress)),
      );
    }
    
    await ref.read(restoreControllerProvider.notifier).restore();
    
    if (!mounted) return;
    
    ref.read(syncEngineProvider).resumeUploads();
    
    final restoreState = ref.read(restoreControllerProvider);
    if (restoreState is RestoreSuccess) {
      if (restoreState.count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kAutoRestoreUpToDate)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kAutoRestoreResultTemplate.replaceAll('{n}', restoreState.count.toString()),
            ),
          ),
        );
      }
    } else if (restoreState is RestoreError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kAutoRestoreError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthSignedIn && !_hasRunAutoRestoreForCurrentSession) {
        _hasRunAutoRestoreForCurrentSession = true;
        _runAutoRestore();
      }
    });

    final index = ref.watch(mainShellIndexProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const <Widget>[
          DashboardScreen(),
          HistoryScreen(),
          StatsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref
            .read(mainShellIndexProvider.notifier)
            .setIndex,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
