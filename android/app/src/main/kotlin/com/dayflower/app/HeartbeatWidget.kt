package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Heartbeat widget: a scene, "HEARTBEAT", and "Tap to send". A tap sends a
 * heartbeat without opening the app (HeartbeatTapReceiver), and a beat sent
 * or arrived ripples (HeartbeatRipple).
 *
 * No counts any more: it used to say how many you had sent and how many had
 * come today. The scene is the one picked in Settings → Home screen widgets
 * ([KEY_THEME], written by DayflowerWidgets.setBeatTheme).
 */
class HeartbeatWidget : HomeWidgetProvider() {

    /**
     * `goAsync` keeps this receiver's process alive until [HeartbeatRipple]
     * has put a pulse away; without it Android is free to kill us first and
     * leave the launcher's copy of the widget on the pulse.
     */
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        var rippling = false
        try {
            super.onReceive(context, intent) // renders the resting state first
            rippling = HeartbeatRipple.playIfPulsed(
                context,
                HeartbeatWidget::class.java,
                R.layout.heartbeat_widget,
                HomeWidgetPlugin.getData(context),
                pending,
            )
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
        appWidgetIds.forEach { widgetId ->
            // 🔴 A provider runs in the app's own process, so a throw in
            // here closes the app about a second after it opens - see
            // TodaysTulipWidget.renderSafely.
            try {
                val views = RemoteViews(context.packageName, R.layout.heartbeat_widget)
                renderHeartbeat(context, views, widgetData)
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                android.util.Log.e("DayflowerWidget", "heartbeat render failed", e)
            }
        }
    }

    companion object {
        /** DayflowerWidgets.keyBeatTheme in Dart. Change them together. */
        const val KEY_THEME = "beat_theme"

        /**
         * The scene for [theme], a HeartbeatTheme's name in Dart. Anything
         * else, including a theme written by a newer build than this one,
         * is the default.
         */
        fun artFor(theme: String?): Int = when (theme) {
            "cat" -> R.drawable.hb_art_cat
            "tulips" -> R.drawable.hb_art_tulips
            "puppy" -> R.drawable.hb_art_puppy
            "capybara" -> R.drawable.hb_art_capybara
            else -> R.drawable.hb_art_moon
        }

        /** Shared with DayflowerWidget so the adaptive variant renders identically. */
        fun renderHeartbeat(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
        ) {
            // A resource, not a bitmap: the launcher loads it itself, so
            // nothing large crosses to it on every redraw.
            views.setImageViewResource(R.id.beat_art, artFor(widgetData.getString(KEY_THEME, null)))
            views.setOnClickPendingIntent(R.id.beat_root, HeartbeatTapReceiver.pendingIntent(context))
            HeartbeatRipple.applyRest(views, widgetData)
        }
    }
}
