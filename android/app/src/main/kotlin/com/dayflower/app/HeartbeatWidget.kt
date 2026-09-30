package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews
import kotlin.math.min
import kotlin.math.roundToInt
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
                renderHeartbeat(context, views, widgetData, widgetId)
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                android.util.Log.e("DayflowerWidget", "heartbeat render failed", e)
            }
        }
    }

    /** Resized: the words are sized to the widget, so it is drawn again. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), HomeWidgetPlugin.getData(context))
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
            widgetId: Int,
        ) {
            // A resource, not a bitmap: the launcher loads it itself, so
            // nothing large crosses to it on every redraw.
            views.setImageViewResource(R.id.beat_art, artFor(widgetData.getString(KEY_THEME, null)))
            views.setOnClickPendingIntent(R.id.beat_root, HeartbeatTapReceiver.pendingIntent(context))
            sizeChrome(context, views, scaleOf(context, widgetId))
            HeartbeatRipple.applyRest(views, widgetData)
        }

        // The words at the default 160 by 200dp; layout/heartbeat_widget
        // has the same numbers, and HeartbeatWidgetPreview in Dart.
        private const val BASE_WIDTH_DP = 160f
        private const val BASE_HEIGHT_DP = 200f
        private const val TITLE_TOP = 16f
        private const val TITLE_TEXT = 12f
        private const val PILL_BOTTOM = 14f
        private const val PILL_LEFT = 12f
        private const val PILL_RIGHT = 10f
        private const val PILL_Y = 5f
        private const val PROMPT_TEXT = 10f
        private const val HEART = 9f
        private const val HEART_GAP = 4f

        /**
         * How much larger than the default [widgetId] is drawn, for its
         * words to grow with it: by whichever of its width and height has
         * less room, so a wide widget's button still clears the heart.
         *
         * Portrait sizes: a launcher reports the width it draws a widget at
         * upright as the minimum and the height as the maximum. Nothing
         * reported yet (the moment it is placed) is the default; the
         * launcher reports the size straight after, and
         * [onAppWidgetOptionsChanged] draws it again.
         */
        private fun scaleOf(context: Context, widgetId: Int): Float {
            val options = try {
                AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
            } catch (e: Throwable) {
                null
            } ?: return 1f
            return scaleFor(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0),
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0),
            )
        }

        fun scaleFor(widthDp: Int, heightDp: Int): Float {
            if (widthDp <= 0 || heightDp <= 0) return 1f
            return min(widthDp / BASE_WIDTH_DP, heightDp / BASE_HEIGHT_DP).coerceIn(0.75f, 1.6f)
        }

        /**
         * The title and the button at [scale] times their default size.
         * Text sizes and paddings can be set on any Android; the button's
         * heart and its gap only from 12 (below that they keep the default,
         * which is close enough on a button this size).
         */
        private fun sizeChrome(context: Context, views: RemoteViews, scale: Float) {
            val px = context.resources.displayMetrics.density * scale
            fun dp(value: Float) = (value * px).roundToInt()
            val unit = TypedValue.COMPLEX_UNIT_DIP
            views.setViewPadding(R.id.beat_chrome, 0, dp(TITLE_TOP), 0, dp(PILL_BOTTOM))
            views.setTextViewTextSize(R.id.beat_label, unit, TITLE_TEXT * scale)
            views.setViewPadding(R.id.beat_pill, dp(PILL_LEFT), dp(PILL_Y), dp(PILL_RIGHT), dp(PILL_Y))
            views.setTextViewTextSize(R.id.beat_prompt, unit, PROMPT_TEXT * scale)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setViewLayoutWidth(R.id.beat_prompt_heart, HEART * scale, unit)
                views.setViewLayoutHeight(R.id.beat_prompt_heart, HEART * scale, unit)
                views.setViewLayoutMargin(
                    R.id.beat_prompt_heart,
                    RemoteViews.MARGIN_LEFT,
                    HEART_GAP * scale,
                    unit,
                )
            }
        }
    }
}
