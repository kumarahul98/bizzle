package traevy.traevy

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget provider.
 *
 * Phase 28: serves TWO layouts and lets Android pick by size via the
 * RemoteViews(Map<SizeF, RemoteViews>) constructor (API 31+; minSdk is 34).
 * The compact layout keeps the small 2x2 experience; the large layout fills a
 * full-width (~4x2) widget with today/this-week stats when idle and live
 * speed + moving/stuck when recording.
 *
 * All displayed values are pre-formatted strings written from Dart — this class
 * never computes. Keys must match lib/config/constants.dart (kWidgetKey*).
 */
class CommuteWidgetProvider : HomeWidgetProvider() {

    private companion object {
        const val UNKNOWN = "--"

        // Shared with lib/config/constants.dart
        const val KEY_SHOW_STATS = "widget_show_stats"
        const val KEY_DISTANCE = "widget_distance"
        const val KEY_DURATION = "widget_duration"
        const val KEY_SPEED = "widget_speed"
        const val KEY_MOVING = "widget_moving"
        const val KEY_STUCK = "widget_stuck"
        const val KEY_PAUSED = "widget_paused"
        const val KEY_TODAY_TRIPS = "widget_today_trips"
        const val KEY_TODAY_TRAFFIC = "widget_today_traffic"
        const val KEY_WEEK_TOTAL = "widget_week_total"
        const val KEY_WEEK_STUCK = "widget_week_stuck"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            // Android selects the largest variant that fits the current size.
            val views = RemoteViews(
                mapOf(
                    SizeF(110f, 110f) to buildViews(context, widgetData, large = false),
                    SizeF(250f, 110f) to buildViews(context, widgetData, large = true),
                )
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /**
     * Build one size variant. Only IDs that exist in the chosen layout are
     * touched — setting a view absent from the inflated layout is not safe.
     */
    private fun buildViews(
        context: Context,
        widgetData: SharedPreferences,
        large: Boolean,
    ): RemoteViews {
        val layoutId = if (large) R.layout.widget_layout_large else R.layout.widget_layout
        return RemoteViews(context.packageName, layoutId).apply {
            val showStats = widgetData.getBoolean(KEY_SHOW_STATS, false)

            // Idle vs active — both layouts carry these two containers.
            setViewVisibility(
                R.id.widget_idle_state,
                if (showStats) View.GONE else View.VISIBLE,
            )
            setViewVisibility(
                R.id.widget_active_state,
                if (showStats) View.VISIBLE else View.GONE,
            )

            // Present in both layouts.
            setTextViewText(R.id.widget_distance, read(widgetData, KEY_DISTANCE))
            setTextViewText(R.id.widget_duration, read(widgetData, KEY_DURATION))

            if (large) {
                // Active-state extras.
                setTextViewText(R.id.widget_speed, read(widgetData, KEY_SPEED))
                setTextViewText(R.id.widget_moving, read(widgetData, KEY_MOVING))
                setTextViewText(R.id.widget_stuck, read(widgetData, KEY_STUCK))
                setViewVisibility(
                    R.id.widget_paused,
                    if (widgetData.getBoolean(KEY_PAUSED, false)) View.VISIBLE else View.GONE,
                )

                // Idle-state stats.
                setTextViewText(R.id.widget_today_trips, read(widgetData, KEY_TODAY_TRIPS))
                setTextViewText(R.id.widget_today_traffic, read(widgetData, KEY_TODAY_TRAFFIC))
                setTextViewText(R.id.widget_week_total, read(widgetData, KEY_WEEK_TOTAL))
                setTextViewText(R.id.widget_week_stuck, read(widgetData, KEY_WEEK_STUCK))
            }

            // Click intents — identical IDs in both layouts.
            setOnClickPendingIntent(R.id.btn_start_commute, launchIntent(context, "start"))
            setOnClickPendingIntent(R.id.btn_pause_commute, launchIntent(context, "pause"))
            setOnClickPendingIntent(R.id.btn_stop_commute, launchIntent(context, "stop"))
        }
    }

    private fun read(widgetData: SharedPreferences, key: String): String =
        widgetData.getString(key, UNKNOWN) ?: UNKNOWN

    private fun launchIntent(context: Context, action: String) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("traevy://widget?action=$action"),
        )
}
