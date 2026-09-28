package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * The heart on a home-screen widget card, tapped.
 *
 * 🔴 **The heart changes first, here, before anything is sent.** A tap that
 * went straight to Dart waited for a background Flutter engine to start
 * (a second or two) before the card changed at all, which is not what a
 * like feels like anywhere else. So this flips the heart in the widget's
 * own data, redraws every card at once, and only then hands the tap to Dart
 * (`dayflower://like` in widget_sync.dart), which posts or deletes the
 * "❤️" reply that makes it true.
 *
 * Tapping a lit heart takes it back, the way every like does.
 */
class DayLikeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.data?.getQueryParameter("id")?.takeIf { it.isNotBlank() } ?: return
        val data = HomeWidgetPlugin.getData(context)
        val hearted = (data.getString(KEY_HEARTED, "") ?: "")
            .split('\n')
            .filter { it.isNotBlank() }
            .toMutableSet()
        val on = if (hearted.contains(id)) {
            hearted.remove(id)
            false
        } else {
            hearted.add(id)
            true
        }
        // commit(), not apply(): the redraw below reads it straight back.
        // The focus keeps a rotating card on the day just hearted: a redraw
        // starts the rotation over, and hearting the second day only to be
        // shown the first is the heart turning red somewhere you cannot see.
        data.edit()
            .putString(KEY_HEARTED, hearted.joinToString("\n"))
            .putString(KEY_FOCUS, id)
            .putLong(KEY_FOCUS_AT, System.currentTimeMillis())
            .commit()

        redraw(context, TodaysTulipWidget::class.java)
        redraw(context, DayflowerWidget::class.java)

        try {
            HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("dayflower://like?id=" + Uri.encode(id) + "&on=" + (if (on) "1" else "0")),
            ).send()
        } catch (e: Throwable) {
            // The heart shows on this phone; the next sync from the app
            // puts it back to what the thread says.
            android.util.Log.w("DayLikeReceiver", "could not send the heart: $e")
        }
    }

    private fun redraw(context: Context, provider: Class<*>) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        if (ids.isEmpty()) return
        context.sendBroadcast(
            Intent(context, provider)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
        )
    }

    companion object {
        /** DayflowerWidgets.keyHearted in Dart. Change them together. */
        const val KEY_HEARTED = "liked_ids"

        /** The day just hearted, and when: see onReceive. */
        const val KEY_FOCUS = "heart_focus"
        const val KEY_FOCUS_AT = "heart_focus_at"

        /** How long a heart keeps the card on its day. A redraw after that
         *  (a sync, the next day) starts from the newest again. */
        const val FOCUS_MS = 15_000L

        /** The heart's tap, for the card showing message [id]. */
        fun pendingIntent(context: Context, id: String): android.app.PendingIntent =
            android.app.PendingIntent.getBroadcast(
                context,
                // One per message: the data differs too, but a request code
                // of its own keeps two hearts from ever sharing an intent.
                id.hashCode(),
                Intent(context, DayLikeReceiver::class.java)
                    .setData(Uri.parse("dayflower://like?id=" + Uri.encode(id))),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                    android.app.PendingIntent.FLAG_IMMUTABLE,
            )
    }
}
