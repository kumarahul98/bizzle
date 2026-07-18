import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:traevy/config/constants.dart';

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
