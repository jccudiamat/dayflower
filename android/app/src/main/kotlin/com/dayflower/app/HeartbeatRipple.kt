package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.widget.RemoteViews

/**
 * The ripple burst on the home-screen widget.
 *
 * Home-screen widgets genuinely cannot animate: `RemoteViews` has no animator,
 * no view references escape the launcher's process, and the framework only
 * redraws when someone calls `updateAppWidget`. So this is not an animation in
 * the usual sense — it is five complete widget redraws pushed ~80ms apart from
 * whichever of *our* processes learned about the pulse. That buys a ~400ms
 * expanding ring and a heart that swells and settles, which is about the
 * ceiling for what a widget can do.
 *
 * The consequence worth remembering: nothing here can fire on its own. A ripple
 * only plays if the app or the widget's background isolate is running to push
 * the frames — a received pulse cannot ripple on a phone where Dayflower is fully
 * closed. Sends from the widget itself always ripple, because tapping the
 * widget *is* what starts the isolate.
 */
object HeartbeatRipple {

    /** Written from Dart — see DayflowerWidgets.syncHeartbeat. */
    const val KEY_AT = "beat_pulse_at"
    const val KEY_DIR = "beat_pulse_dir"

    /** Ours alone; stored as a Long, so never read these from Dart. Kept per
     *  provider so that a phone with both the dedicated and the adaptive
     *  widget placed sees both of them ripple, not whichever woke first. */
    private fun shownKey(provider: Class<*>) = "beat_pulse_shown_${provider.simpleName}"

    private const val FRAME_MS = 80L

    /** A marker older than this is stale — a widget rebuilt after a reboot or
     *  a launcher restart must not replay a pulse from hours ago. */
    private const val FRESH_MS = 10_000L

    private const val COLOR_SENT = 0xFFF58FB4.toInt() // brand pink
    private const val COLOR_RECEIVED = 0xFFC4B0FF.toInt() // lavender

    /** ring drawable, ring alpha (0-255), heart size in sp. */
    private val FRAMES = arrayOf(
        Frame(R.drawable.ripple_ring_1, 255, 38f),
        Frame(R.drawable.ripple_ring_2, 220, 40f),
        Frame(R.drawable.ripple_ring_3, 170, 36f),
        Frame(R.drawable.ripple_ring_4, 110, 34f),
        Frame(R.drawable.ripple_ring_5, 55, 33f),
        Frame(R.drawable.ripple_ring_5, 0, 32f), // rest — matches the layout
    )

    private data class Frame(val ring: Int, val alpha: Int, val heartSp: Float)

    /** Resting look, applied on every ordinary render. */
    fun applyRest(views: RemoteViews) {
        applyFrame(views, FRAMES.last(), COLOR_RECEIVED)
    }

    /**
     * Plays the burst if [widgetData] carries a pulse marker this widget has
     * not shown yet. Returns true when frames were scheduled, in which case
     * [pending] is finished by the last frame rather than by the caller.
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
        val shown = try {
            widgetData.getLong(shownKey, 0L)
        } catch (_: ClassCastException) {
            0L
        }
        if (at <= shown) return false
        if (System.currentTimeMillis() - at > FRESH_MS) return false

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        if (ids.isEmpty()) return false

        // Claim the marker before the first frame — every widget update we push
        // below comes straight back as another broadcast, and without this each
        // one would start a fresh burst.
        widgetData.edit().putLong(shownKey, at).apply()

        val color = if (widgetData.getString(KEY_DIR, "sent") == "sent") {
            COLOR_SENT
        } else {
            COLOR_RECEIVED
        }

        val handler = Handler(Looper.getMainLooper())
        FRAMES.forEachIndexed { i, frame ->
            handler.postDelayed({
                try {
                    val views = RemoteViews(context.packageName, layoutId)
                    HeartbeatWidget.renderHeartbeat(context, views, widgetData)
                    applyFrame(views, frame, color)
                    ids.forEach { manager.updateAppWidget(it, views) }
                } finally {
                    // Always release the receiver, even if a frame throws —
                    // leaking a PendingResult is an ANR.
                    if (i == FRAMES.size - 1) pending?.finish()
                }
            }, i * FRAME_MS)
        }
        return true
    }

    private fun applyFrame(views: RemoteViews, frame: Frame, color: Int) {
        views.setImageViewResource(R.id.beat_ring, frame.ring)
        // Both of these are @RemotableViewMethod on ImageView; tinting a white
        // ring is what lets one set of drawables serve both directions.
        views.setInt(R.id.beat_ring, "setColorFilter", color)
        views.setInt(R.id.beat_ring, "setImageAlpha", frame.alpha)
        views.setTextViewTextSize(
            R.id.beat_heart,
            TypedValue.COMPLEX_UNIT_SP,
            frame.heartSp,
        )
    }
}
