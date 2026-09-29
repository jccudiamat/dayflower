package com.dayflower.app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * The heartbeat widget, tapped.
 *
 * 🔴 **It ripples first, here, and only then sends.** The tap used to go
 * straight to Dart, and the widget rippled when the heartbeat had been sent:
 * a background engine to start and a round trip to Supabase later, a second
 * or more after the tap, which does not feel like the tap did anything. Now
 * this marks a sent pulse and redraws the heartbeat widgets (whose
 * onReceive plays it, see HeartbeatRipple) at once, then hands the tap to
 * Dart (`dayflower://heartbeat` in widget_sync.dart) to send.
 *
 * Nobody signed in, or nobody to send to ([KEY_READY] is "0", which the
 * app writes): it opens the app instead, where that is fixed, rather than
 * ripple as if something had gone.
 */
class HeartbeatTapReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val data = HomeWidgetPlugin.getData(context)
        if (data.getString(KEY_READY, null) == "0") {
            try {
                context.startActivity(
                    Intent(context, MainActivity::class.java)
                        .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
                        .setData(Uri.parse("dayflower://heartbeat"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            } catch (e: Throwable) {
                android.util.Log.w("HeartbeatTap", "could not open the app: $e")
            }
            return
        }

        // A string, as Dart writes it (DayflowerWidgets._markPulse).
        // commit(), not apply(): the redraw below reads it straight back.
        data.edit()
            .putString(HeartbeatRipple.KEY_AT, System.currentTimeMillis().toString())
            .putString(HeartbeatRipple.KEY_DIR, "sent")
            .commit()
        redrawWidgets(context, HeartbeatWidget::class.java)
        redrawWidgets(context, DayflowerWidget::class.java)

        try {
            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("dayflower://heartbeat")).send()
        } catch (e: Throwable) {
            android.util.Log.w("HeartbeatTap", "could not send the heartbeat: $e")
        }
    }

    companion object {
        /** DayflowerWidgets.keyBeatReady in Dart. Change them together. */
        const val KEY_READY = "beat_ready"

        fun pendingIntent(context: Context): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, HeartbeatTapReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
    }
}
