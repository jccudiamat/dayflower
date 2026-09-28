package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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
 *
 * It also takes every tap on the scrolling list (see [listTemplate]), where
 * the rest of a day, not its heart, opens that day in the app.
 */
class DayLikeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.data?.host == "open") {
            val reply = intent.data?.getQueryParameter("reply")
            open(
                context,
                if (!reply.isNullOrBlank()) {
                    "dayflower://reply?id=" + Uri.encode(reply)
                } else {
                    val day = intent.data?.getQueryParameter("day")
                    if (day.isNullOrBlank()) "dayflower://days" else "dayflower://days?id=" + Uri.encode(day)
                },
            )
            return
        }
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

    /**
     * A day in the scrolling list, tapped: the app, on the My Day viewer on
     * that day, or (its reply) on the chat with a reply to it started. The
     * same intents the card's own taps send (TodaysTulipWidget.openDays,
     * openReply), so the app cannot tell them apart.
     *
     * ⚠️ Started from here, a receiver, because a list's taps all go to one
     * place and the heart's must not open anything. A launcher lets a
     * widget's broadcast start the app it belongs to (AOSP's does,
     * explicitly), but one that did not would leave this tap doing nothing;
     * the header above the list opens the viewer directly either way.
     */
    private fun open(context: Context, target: String) {
        try {
            context.startActivity(
                Intent(context, MainActivity::class.java)
                    .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
                    .setData(Uri.parse(target))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Throwable) {
            android.util.Log.w("DayLikeReceiver", "could not open $target: $e")
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

        /**
         * Every tap on the scrolling list, before its row says which day
         * and what part of it (DayListService).
         *
         * 🔴 Mutable, which nothing else here is: the row's part of the
         * intent is filled in when it is tapped, and Android 12 and later
         * ignore the fill-in on an immutable PendingIntent, so every tap
         * would arrive saying nothing. Explicit (this class), so a filled-in
         * intent can only ever come here.
         */
        fun listTemplate(context: Context): android.app.PendingIntent =
            android.app.PendingIntent.getBroadcast(
                context,
                LIST_REQUEST,
                Intent(context, DayLikeReceiver::class.java),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        android.app.PendingIntent.FLAG_MUTABLE
                    } else {
                        0
                    }),
            )

        private const val LIST_REQUEST = 0x4C495354

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
