package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Adaptive widget — renders whichever content the user picked in
 * Settings → Home screen widget. The two dedicated widgets
 * ([TodaysTulipWidget], [HeartbeatWidget]) ignore that preference; this one
 * follows it, so a single home-screen slot can be switched without removing
 * and re-adding a widget.
 *
 * Rendering is delegated to the dedicated providers so there is exactly one
 * implementation of each look.
 */
class DayflowerWidget : HomeWidgetProvider() {

    /** Ripples for the same reason [HeartbeatWidget] does, but only while it
     *  is actually showing the heartbeat. */
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        var rippling = false
        try {
            super.onReceive(context, intent)
            val data = HomeWidgetPlugin.getData(context)
            if (data.getString("widget_mode", "flower") == "heartbeat") {
                rippling = HeartbeatRipple.playIfPulsed(
                    context,
                    DayflowerWidget::class.java,
                    R.layout.heartbeat_widget,
                    data,
                    pending,
                )
            }
        } finally {
            if (!rippling) pending.finish()
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val heartbeatMode = widgetData.getString("widget_mode", "flower") == "heartbeat"

        appWidgetIds.forEach { widgetId ->
            // 🔴 Same guard as TodaysTulipWidget.renderSafely, and for the
            // same reason: this runs in the app's process, so a throw here
            // is the app closing a second after it opened.
            try {
                if (heartbeatMode) {
                    val views = RemoteViews(context.packageName, R.layout.heartbeat_widget)
                    HeartbeatWidget.renderHeartbeat(context, views, widgetData)
                    appWidgetManager.updateAppWidget(widgetId, views)
                } else {
                    TodaysTulipWidget.renderSafely(
                        context,
                        appWidgetManager,
                        widgetId,
                        widgetData,
                    )
                }
            } catch (e: Throwable) {
                android.util.Log.e("DayflowerWidget", "adaptive render failed", e)
            }
        }
    }
}
