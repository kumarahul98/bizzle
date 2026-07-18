import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/stats/services/stats_service.dart';

/// Format a second count as a compact widget duration ("3h 40m" / "22m").
///
/// Shared by the active-state tick in `tracking_service.dart` and the
/// idle-state stats push below so both read identically on the widget.
String formatWidgetDuration(int seconds) {
  if (seconds < 0) return kWidgetValueUnknown;
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}

/// Push the idle (no active trip) state to the Android home-screen widget.
///
/// Reused by the clean-stop handler in the background isolate and by
/// [reconcileWidgetOnStartup], so the widget resets to idle even after a
/// force-stop / OS kill that bypasses the normal `kStopTrackingEvent` handler.
Future<void> writeWidgetIdle() async {
  await HomeWidget.saveWidgetData<String>(kWidgetKeyTitle, kWidgetTitleIdle);
  await HomeWidget.saveWidgetData<bool>(kWidgetKeyShowStats, false);
  await HomeWidget.updateWidget(
    name: kWidgetProviderName,
    androidName: kWidgetProviderName,
  );
}

/// Push the idle-state stats block (today + this week) to the widget.
///
/// Phase 28: the larger widget layout shows these when no trip is recording.
/// Must run on the MAIN isolate — the tracking background isolate that owns the
/// active-state writes has no Drift access. Values are pre-formatted here so the
/// native provider never computes. Reuses the SAME aggregation the in-app
/// WeekLossCard shows, so the widget and the app can't disagree.
Future<void> writeWidgetIdleStats({
  required List<TripSummary> todayTrips,
  required StatsSummary? weekStats,
}) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final tripCount = todayTrips.length;
  final todayStuckSeconds = todayTrips.fold<int>(
    0,
    (sum, t) => sum + t.timeStuckSeconds,
  );
  final todayTrips0 = tripCount == 1 ? '1 trip' : '$tripCount trips';
  final todayTraffic = tripCount == 0
      ? kWidgetValueUnknown
      : '${formatWidgetDuration(todayStuckSeconds)} in traffic';
  final weekTotal = weekStats == null
      ? kWidgetValueUnknown
      : formatWidgetDuration(weekStats.weekTotalSeconds);
  final weekStuck = weekStats == null
      ? kWidgetValueUnknown
      : '${formatWidgetDuration(weekStats.weekStuckSeconds)} lost';

  try {
    await HomeWidget.saveWidgetData<String>(kWidgetKeyTodayTrips, todayTrips0);
    await HomeWidget.saveWidgetData<String>(
      kWidgetKeyTodayTraffic,
      todayTraffic,
    );
    await HomeWidget.saveWidgetData<String>(kWidgetKeyWeekTotal, weekTotal);
    await HomeWidget.saveWidgetData<String>(kWidgetKeyWeekStuck, weekStuck);
    await HomeWidget.updateWidget(
      name: kWidgetProviderName,
      androidName: kWidgetProviderName,
    );
  } on Object {
    // Platform-channel failure — non-fatal; stats refresh on the next push.
  }
}

/// One-shot startup reconciliation (Android only).
///
/// The widget's active state is only ever cleared by the background isolate's
/// stop handler, which needs the foreground service alive. A force-stop / OS
/// kill mid-trip therefore leaves the widget frozen on "Stop Commute" with no
/// path back to idle. On launch, if the tracking service is NOT running, the
/// widget cannot legitimately be showing an active trip — so rewrite it to
/// idle. When the service IS running it owns the widget's live updates, so we
/// leave it untouched.
Future<void> reconcileWidgetOnStartup() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final running = await FlutterBackgroundService().isRunning();
    if (!running) {
      await writeWidgetIdle();
    }
  } on Object {
    // Platform-channel failure — non-fatal; the widget just isn't reconciled
    // this launch. It will be corrected on the next start/stop.
  }
}
