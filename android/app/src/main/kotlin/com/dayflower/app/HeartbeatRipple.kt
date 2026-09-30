package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews

/**
 * A pulse on the heartbeat widget: the scene beats (lub-dub), light blooms
 * over its heart, and two heart-shaped ripples grow out of it and fade.
 * Pink for a heartbeat sent, lavender for one that arrived.
 *
 * 🔴 **The launcher plays it; this only starts it.** It used to be five
 * complete widget redraws pushed ~80ms apart, the only animation a
 * RemoteViews seemed to allow, and launchers applied those unevenly: it
 * stuttered, and a ring stepping between five sizes never looked like it
 * moved. Now every moving part sits in a ViewFlipper whose in-animation is
 * that part's move (res/anim/hb_*), and showing a flipper's child starts its
 * in-animation, even when it is the child already showing. So a pulse is
 * one widget update, and the launcher animates it smoothly at the screen's
 * rate. See layout/heartbeat_widget.
 *
 * Then, once it has played, one more update puts the rings away (their
 * flippers back on an empty child). The launcher keeps the last update it
 * was sent and applies it again whenever it rebuilds the widget, on a
 * rotation or a restart; left on the pulse, a rebuild would ripple again
 * out of nowhere.
 *
 * Something has to be running to send the update: a pulse plays when the
 * app, the widget's own tap (HeartbeatTapReceiver), or a heartbeat's push
 * wakes one of our processes. Ordinary redraws never start one.
 */
object HeartbeatRipple {

    /** Written by Dart (DayflowerWidgets._markPulse) and HeartbeatTapReceiver. */
    const val KEY_AT = "beat_pulse_at"
    const val KEY_DIR = "beat_pulse_dir"

    /** Ours alone; stored as Longs, so never read these from Dart. Kept per
     *  provider so that a phone with both the dedicated and the adaptive
     *  widget placed sees both of them ripple, not whichever woke first. */
    private fun shownKey(provider: Class<*>) = "beat_pulse_shown_${provider.simpleName}"
    private const val PLAYED_AT = "beat_pulse_played_at"

    /** A marker older than this is stale: a widget rebuilt after a reboot or
     *  a launcher restart must not replay a pulse from hours ago. */
    private const val FRESH_MS = 10_000L

    /** How long a pulse takes to play: the echo ring's 300ms wait and 950ms
     *  of growing (anim/hb_echo), with room to spare. */
    private const val PLAY_MS = 1_500L

    private const val COLOR_SENT = 0xFFFF7AB6.toInt()      // pink
    private const val COLOR_RECEIVED = 0xFFC9B6FF.toInt()  // lavender

    /** The flippers with an empty first child to rest on. The scene's is
     *  not one of them: showing its only child would beat it. */
    private val RINGS = intArrayOf(R.id.beat_glow_flip, R.id.beat_ring_flip, R.id.beat_echo_flip)

    /**
     * An ordinary redraw's part: the rings put away. Unless a pulse is
     * playing, because a redraw that lands mid-pulse (the app refreshing
     * the widgets as the heartbeat it just sent comes back) would cut it off.
     */
    fun applyRest(views: RemoteViews, widgetData: SharedPreferences) {
        val played = widgetData.longOf(PLAYED_AT)
        if (System.currentTimeMillis() - played < PLAY_MS) return
        settle(views)
    }

    private fun settle(views: RemoteViews) {
        for (flip in RINGS) views.setDisplayedChild(flip, 0)
    }

    private fun start(views: RemoteViews, color: Int) {
        views.setInt(R.id.beat_glow, "setColorFilter", color)
        views.setInt(R.id.beat_ring, "setColorFilter", color)
        views.setInt(R.id.beat_echo, "setColorFilter", color)
        views.setDisplayedChild(R.id.beat_art_flip, 0)
        for (flip in RINGS) views.setDisplayedChild(flip, 1)
    }

    /**
     * Plays the pulse if [widgetData] carries a marker this widget has not
     * shown yet. Returns true when it did, in which case [pending] is
     * finished once the pulse has been put away rather than by the caller.
     */
    fun playIfPulsed(
        context: Context,
        provider: Class<*>,
        layoutId: Int,
        widgetData: SharedPreferences,
        pending: BroadcastReceiver.PendingResult?,
    ): Boolean {
        val at = widgetData.getString(KEY_AT, null)?.toLongOrNull() ?: return false
        val shownKey = shownKey(provider)
        val shown = widgetData.longOf(shownKey)
        if (at <= shown) return false
        val now = System.currentTimeMillis()
        if (now - at > FRESH_MS) return false

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        if (ids.isEmpty()) return false

        // Claimed before anything is drawn: every update below comes back as
        // another broadcast, and without this each one would start a pulse.
        // The time it started is what keeps ordinary redraws off it.
        widgetData.edit().putLong(shownKey, at).putLong(PLAYED_AT, now).apply()

        val color = if (widgetData.getString(KEY_DIR, "sent") == "sent") {
            COLOR_SENT
        } else {
            COLOR_RECEIVED
        }
        // One each: the words on each are sized to that widget.
        ids.forEach { id ->
            val pulse = RemoteViews(context.packageName, layoutId)
            HeartbeatWidget.renderHeartbeat(context, pulse, widgetData, id)
            start(pulse, color)
            manager.updateAppWidget(id, pulse)
        }

        Handler(Looper.getMainLooper()).postDelayed({
            try {
                // A newer pulse started meanwhile: it puts itself away.
                if (widgetData.longOf(PLAYED_AT) == now) {
                    ids.forEach { id ->
                        val rest = RemoteViews(context.packageName, layoutId)
                        HeartbeatWidget.renderHeartbeat(context, rest, widgetData, id)
                        settle(rest)
                        manager.updateAppWidget(id, rest)
                    }
                }
            } catch (e: Throwable) {
                android.util.Log.e("DayflowerWidget", "heartbeat pulse could not settle", e)
            } finally {
                // Always released, or the receiver it holds is an ANR.
                pending?.finish()
            }
        }, PLAY_MS)
        return true
    }
}
