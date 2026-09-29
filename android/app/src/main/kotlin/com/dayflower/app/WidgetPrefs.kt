package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences

/**
 * A number Dart wrote into the widget's preferences, whichever width it
 * arrived as.
 *
 * 🔴 **Never `getLong` on a value Dart wrote.** `HomeWidget.saveWidgetData<int>`
 * crosses the platform channel as whatever StandardMessageCodec picks, and
 * that depends on the *value*, not the Dart type: anything that fits in 32
 * bits arrives as an Int and is stored with putInt, anything larger as a Long
 * with putLong. An epoch-millis expiry is always a Long — so day photos
 * worked — but a flower never expires and writes **0**, which is stored as an
 * Int, and `getLong` on an Int throws ClassCastException. renderSafely caught
 * it and drew the bare emoji-and-name card: every flower sent to a home
 * screen looked like that, the painting and the sender's header both gone.
 * Clearing the reunion (also 0) did the same to the reunion widget.
 *
 * The heartbeat widget met this first and stores its time as a string; this
 * reads either width, and a string too, so a value already on a phone from
 * before the fix is read correctly the moment the update lands.
 */
fun SharedPreferences.longOf(key: String, default: Long = 0L): Long =
    when (val value = all[key]) {
        is Long -> value
        is Int -> value.toLong()
        is Number -> value.toLong()
        is String -> value.toLongOrNull() ?: default
        else -> default
    }

/** [longOf], for a value that is only ever small — seconds, not millis. */
fun SharedPreferences.intOf(key: String, default: Int = 0): Int =
    longOf(key, default.toLong()).toInt()

/**
 * Asks [provider] to redraw every widget of its on the home screen, the way
 * the system does: an APPWIDGET_UPDATE to its own receiver, so its
 * onReceive runs (and a heartbeat widget gets to play a pulse there).
 */
fun redrawWidgets(context: Context, provider: Class<*>) {
    val manager = AppWidgetManager.getInstance(context)
    val ids = manager.getAppWidgetIds(ComponentName(context, provider))
    if (ids.isEmpty()) return
    context.sendBroadcast(
        Intent(context, provider)
            .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
    )
}
