package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Heartbeat widget. Tapping fires a *background* broadcast — the Dart
 * callback in lib/features/widget/widget_sync.dart sends the pulse without
 * ever opening the app.
 *
 * Keys in [widgetData] are written from Dart by DayflowerWidgets.syncHeartbeat();
 * they must stay in sync.
 */
class HeartbeatWidget : HomeWidgetProvider() {

    /**
     * `goAsync` keeps this receiver's process alive while [HeartbeatRipple]
     * pushes its frames — without it Android is free to kill us mid-burst and
     * the widget would be left frozen on a half-expanded ring.
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
            val views = RemoteViews(context.packageName, R.layout.heartbeat_widget)
            renderHeartbeat(context, views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        /** Shared with DayflowerWidget so the adaptive variant renders identically. */
        fun renderHeartbeat(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
        ) {
            // Daily reset happens HERE, not in Dart. The counts carry the
            // local day they were written for; once that is no longer today
            // they are yesterday's news and the widget zeroes them itself.
            // Widgets refresh every 30 min, so the reset lands shortly
            // after midnight even if the app is never opened.
            val stamped = widgetData.getString("beat_date", "") ?: ""
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val fresh = stamped.isEmpty() || stamped == today

            val mine =
                if (fresh) widgetData.getString("beat_mine", "0") ?: "0" else "0"
            val partner =
                if (fresh) widgetData.getString("beat_partner", "0") ?: "0" else "0"
            val partnerName =
                widgetData.getString("beat_partner_name", "Your partner")
                    ?: "Your partner"

            views.setTextViewText(
                R.id.beat_mine,
                if (mine == "0") {
                    context.getString(R.string.heartbeat_widget_prompt)
                } else {
                    "Tapped $mine× today"
                },
            )
            views.setTextViewText(
                R.id.beat_partner,
                if (partner == "0") {
                    "$partnerName hasn't tapped yet today"
                } else {
                    "$partnerName sent $partner today"
                },
            )

            HeartbeatRipple.applyRest(views)

            views.setOnClickPendingIntent(
                R.id.beat_root,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("dayflower://heartbeat"),
                ),
            )
        }
    }
}
