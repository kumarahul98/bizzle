import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/dashboard/providers/dashboard_providers.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
import 'package:traevy/features/settings/screens/settings_screen.dart';
import 'package:traevy/features/shell/providers/main_shell_provider.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
import 'package:traevy/features/tour/page_tour_host.dart';
import 'package:traevy/features/tour/tour_config.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/services/widget_state_writer.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/tracking/widgets/recovery_prompt_dialog.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/settings/widgets/conflict_resolution_sheet.dart';
import 'package:traevy/sync/restore_controller.dart';
import 'package:traevy/sync/sync_engine.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _sub;
  bool _hasRunAutoRestoreForCurrentSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = HomeWidget.widgetClicked.listen(_onWidgetClicked);
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) _onWidgetClicked(uri);
    });
    // WIDGET-01: reset a widget left frozen on the active state by a prior
    // force-stop / OS kill (the stop handler needs the service alive to clear
    // it). No-op when a trip is genuinely running (service owns the widget).
    unawaited(reconcileWidgetOnStartup());
    // Phase 28: seed the idle stats once the first frame's providers resolve
    // (the ref.listen below only fires on subsequent changes).
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushWidgetIdleStats());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Phase 28: refresh the widget's idle stats on resume — the widget never
    // self-refreshes (updatePeriodMillis=0), so without this the numbers go
    // stale (e.g. across a midnight rollover) until the next trip is saved.
    if (state == AppLifecycleState.resumed) {
      _pushWidgetIdleStats();
    }
  }

  /// Push today/this-week stats to the home-screen widget. Cheap and
  /// event-driven — never polled (see the 5s throttle rationale in
  /// tracking_service.dart).
  void _pushWidgetIdleStats() {
    if (!mounted) return;
    final todayTrips = ref.read(todaysTripSummariesProvider).asData?.value;
    if (todayTrips == null) return;
    unawaited(
      writeWidgetIdleStats(
        todayTrips: todayTrips,
        weekStats: ref.read(statsSummaryProvider).asData?.value,
      ),
    );
  }

  void _onWidgetClicked(Uri? uri) {
    if (uri?.host == 'widget') {
      final action = uri?.queryParameters['action'];
      if (action == 'start') {
        _handleStart();
      } else if (action == 'pause') {
        _showConfirmationDialog(
          'Pause Commute',
          'Are you sure you want to pause?',
          () {
            ref.read(trackingStateProvider.notifier).pause();
          },
        );
      } else if (action == 'stop') {
        _showConfirmationDialog(
          'Stop Commute',
          'Are you sure you want to stop and save this trip?',
          () {
            ref.read(trackingStateProvider.notifier).stop();
          },
        );
      }
    }
  }

  void _showConfirmationDialog(
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
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
        const SnackBar(
          content: Text('Permissions required to start tracking.'),
        ),
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
              kAutoRestoreResultTemplate.replaceAll(
                '{n}',
                restoreState.count.toString(),
              ),
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

  /// One-time backfill of trips with non-default v0.3 metadata (Phase 26,
  /// D-01/D-02/D-03).
  ///
  /// Marker-guarded exactly-once per install: if the stored marker is
  /// already at (or past) [kBackfillMarkerVersion] this is a silent no-op.
  /// Otherwise every candidate id from
  /// `TripsDao.tripIdsWithNonDefaultMetadata()` is re-enqueued for upload
  /// and the marker is stamped AFTER the enqueue loop completes — the
  /// sync queue is persistent with retries, so enqueue-time is when the
  /// backfill counts as done. Deliberately silent (no snackbar/dialog):
  /// unlike auto-restore, backfill has no user-visible outcome to report.
  Future<void> _runBackfillIfNeeded() async {
    if (!mounted) return;
    final prefsDao = ref.read(userPreferencesDaoProvider);
    final markerVersion = await prefsDao.getBackfillMarkerVersion();
    if (markerVersion >= kBackfillMarkerVersion) return;
    if (!mounted) return;
    final candidateIds = await ref
        .read(tripsDaoProvider)
        .tripIdsWithNonDefaultMetadata();
    if (!mounted) return;
    final syncQueueDao = ref.read(syncQueueDaoProvider);
    for (final id in candidateIds) {
      await syncQueueDao.enqueueUpdate(id);
    }
    await prefsDao.setBackfillMarkerVersion(kBackfillMarkerVersion);
  }

  /// Sign-in sequencing (Phase 26, T-26-12): auto-restore fully completes
  /// BEFORE the backfill runs, so the backfill's enqueues never race
  /// Phase 24's restore-then-resume-uploads sequence. Fire-and-forget from
  /// the `ref.listen` callback; the sequencing lives here.
  Future<void> _runAutoRestoreThenBackfill() async {
    await _runAutoRestore();
    await _runBackfillIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    // Phase 28: the trip providers are reactive, so listening here refreshes
    // the widget's idle stats whenever trips change — which covers the
    // post-trip-save case without hooking the tracking controller.
    ref.listen<AsyncValue<List<TripSummary>>>(
      todaysTripSummariesProvider,
      (_, __) => _pushWidgetIdleStats(),
    );
    ref.listen<AsyncValue<StatsSummary>>(
      statsSummaryProvider,
      (_, __) => _pushWidgetIdleStats(),
    );

    ref.listen<TrackingState>(trackingStateProvider, (previous, next) {
      if (next is TrackingInterrupted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const RecoveryPromptDialog(),
        );
      } else if (previous is TrackingInterrupted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthSignedIn && !_hasRunAutoRestoreForCurrentSession) {
        _hasRunAutoRestoreForCurrentSession = true;
        _runAutoRestoreThenBackfill();
      }
    });

    ref.listen<RestoreState>(restoreControllerProvider, (previous, next) {
      if (next is RestoreConflictState) {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (ctx) => ConflictResolutionSheet(conflicts: next.conflicts),
        );
      } else if (next is RestoreSuccess && previous is RestoreConflictState) {
        if (next.count == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(kAutoRestoreUpToDate)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                kAutoRestoreResultTemplate.replaceAll(
                  '{n}',
                  next.count.toString(),
                ),
              ),
            ),
          );
        }
      }
    });

    final index = ref.watch(mainShellIndexProvider);
    // Each tab screen is wrapped in a PageTourHost that runs its one-time
    // guided tour the first time that tab becomes visible (UX-07). The screens
    // themselves stay const; the tours (pageKey + steps) come from
    // buildPageTours(), tab order matching the IndexedStack below.
    final tours = buildPageTours();
    const screens = <Widget>[
      DashboardScreen(),
      HistoryScreen(),
      StatsScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: <Widget>[
          for (var i = 0; i < screens.length; i++)
            PageTourHost(tour: tours[i], child: screens[i]),
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
