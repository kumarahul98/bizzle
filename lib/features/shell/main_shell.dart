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
import 'package:traevy/sync/preferences_sync_service.dart';
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
        _showStopConfirm();
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

  /// Ask whether to stop the trip (Phase 36, D-04).
  ///
  /// The SINGLE stop-confirmation in the app. Both entry points that can ask
  /// this question — the home-screen widget's Stop button and the recording
  /// notification's Stop action — call this method, so the two cannot drift
  /// apart in wording or behaviour (SC#9). Cancelling leaves the trip
  /// recording and the notification intact.
  ///
  /// Unlike [_showAutoPauseConfirm] this does NOT gate on [TrackingActive].
  /// The dialog is harmless once the trip has already ended (`stop()` on a
  /// finished trip is a no-op), and the notification path can legitimately
  /// arrive while the state stream is still catching up on a cold resume —
  /// suppressing the dialog there would reproduce the exact "Stop did nothing
  /// visible" complaint this change exists to fix.
  void _showStopConfirm() {
    if (!mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(kStopConfirmTitle),
          content: const Text(kStopConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(kStopConfirmDismissLabel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(trackingStateProvider.notifier).stop();
              },
              child: const Text(kStopConfirmAcceptLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// Ask whether to pause after a stationary streak (2026-07-21, D-03).
  ///
  /// Only meaningful while a trip is actually recording: the prompt is fired by
  /// the service mid-trip, but the user may tap Pause long after — by which
  /// point the trip could already be stopped or paused. Guarding here keeps a
  /// stale notification tap from opening a dialog that would do nothing.
  void _showAutoPauseConfirm() {
    if (!mounted) return;
    final state = ref.read(trackingStateProvider);
    if (state is! TrackingActive || state.isPaused) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(kAutoPauseConfirmTitle),
        content: const Text(kAutoPauseConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(kAutoPauseConfirmDismissLabel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(trackingStateProvider.notifier).pause();
            },
            child: const Text(kAutoPauseConfirmAcceptLabel),
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
      // Phase 36 (D-03): this was a bare snackbar stating the problem with no
      // way to act on it — the user is told a permission is missing and left to
      // find the settings page themselves. It now carries the same "Open
      // settings" action, to the same destination, as the other two denial
      // paths.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(kPermissionsRequiredMessage),
          action: SnackBarAction(
            label: kOpenPermissionSettingsLabel,
            onPressed: () => unawaited(service.openSystemSettings()),
          ),
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

    await _syncSavedLocations();
  }

  /// Reconcile saved Home/Office locations with the cloud on sign-in
  /// (Phase 29, LOC-03).
  ///
  /// Order matters: restore FIRST, then push.
  ///
  ///   * restore fills only local gaps (D-03), so a fresh install gets its
  ///     pins back and geofence labeling works on the first trip;
  ///   * the follow-up push then uploads whatever is now locally true. That
  ///     covers the user who set pins while signed out — their locations exist
  ///     only on-device, and without this push they would never reach the
  ///     cloud until the next time they happened to edit one.
  ///
  /// Deliberately silent: unlike trip auto-restore there is no count worth
  /// reporting, and a snackbar about coordinates the user did not ask about
  /// would be noise. Both calls swallow their own failures, so this cannot
  /// break sign-in.
  Future<void> _syncSavedLocations() async {
    final service = ref.read(preferencesSyncServiceProvider);
    await service.restore();
    await service.push();
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

    // 2026-07-21 (D-02/D-03): the auto-pause prompt's Pause action opens the
    // app and asks here, instead of pausing silently from the notification.
    // Mirrors the home-screen widget's Pause button so both entry points
    // behave identically.
    ref
      ..listen<AsyncValue<void>>(autoPauseConfirmRequestProvider, (_, next) {
        if (next is! AsyncData) return;
        _showAutoPauseConfirm();
      })
      // Phase 36 (D-04): the recording notification's Stop action opens the
      // app and asks here, instead of ending the trip with no visible
      // confirmation. Reuses the widget's dialog so both stop entry points are
      // literally the same code (SC#9).
      ..listen<AsyncValue<void>>(stopConfirmRequestProvider, (_, next) {
        if (next is! AsyncData) return;
        // Ack FIRST, before anything that could throw or be skipped. This is
        // the T-36-06 signal that a live UI isolate got the relay; withholding
        // it would have the service stop the trip out from under a dialog that
        // is about to appear.
        ref.read(trackingEventSourceProvider).acknowledgeStopConfirm();
        _showStopConfirm();
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
