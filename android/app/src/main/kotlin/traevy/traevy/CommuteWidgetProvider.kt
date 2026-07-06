package traevy.traevy

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class CommuteWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val distance = widgetData.getString("widget_distance", "--")
                val duration = widgetData.getString("widget_duration", "--")
                val showStats = widgetData.getBoolean("widget_show_stats", false)
                
                if (showStats) {
                    setViewVisibility(R.id.widget_idle_state, android.view.View.GONE)
                    setViewVisibility(R.id.widget_active_state, android.view.View.VISIBLE)
                    setTextViewText(R.id.widget_distance, distance)
                    setTextViewText(R.id.widget_duration, duration)
                } else {
                    setViewVisibility(R.id.widget_idle_state, android.view.View.VISIBLE)
                    setViewVisibility(R.id.widget_active_state, android.view.View.GONE)
                }
                
                // Launch intent to start commute
                val startIntent = HomeWidgetLaunchIntent.getActivity(
                    context, 
                    MainActivity::class.java,
                    Uri.parse("traevy://widget?action=start")
                )
                setOnClickPendingIntent(R.id.btn_start_commute, startIntent)

                // Launch intent to pause commute
                val pauseIntent = HomeWidgetLaunchIntent.getActivity(
                    context, 
                    MainActivity::class.java,
                    Uri.parse("traevy://widget?action=pause")
                )
                setOnClickPendingIntent(R.id.btn_pause_commute, pauseIntent)

                // Launch intent to stop commute
                val stopIntent = HomeWidgetLaunchIntent.getActivity(
                    context, 
                    MainActivity::class.java,
                    Uri.parse("traevy://widget?action=stop")
                )
                setOnClickPendingIntent(R.id.btn_stop_commute, stopIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
