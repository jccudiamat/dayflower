package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The reunion countdown, on the home screen.
 *
 * Reads one row's worth of data — title, place, when — that
 * `DayflowerWidgets.syncReunion()` pushes across from the same `reunions`
 * row the card on Events reads, so the two cannot disagree. The background
 * photo is separate and device-local: a decision about one home screen
 * rather than a fact about the couple.
 */
class ReunionWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            renderSafely(context, appWidgetManager, widgetId, widgetData)
        }
    }

    companion object {
        private const val TAG = "DayflowerWidget"

        /**
         * 🔴 A provider runs in the **app's own process**, so an uncaught
         * throw here is the app closing about a second after it opens — the
         * grey-screen crash that took a build to find. Same guard, same
         * reason, as TodaysTulipWidget.renderSafely: draw the plain card if
         * anything about the photo or the date goes wrong, and log it.
         */
        fun renderSafely(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            widgetData: SharedPreferences,
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.reunion_widget)
                render(context, views, widgetData, manager.getAppWidgetOptions(widgetId))
                manager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                android.util.Log.e(TAG, "reunion render failed", e)
                try {
                    val plain = RemoteViews(context.packageName, R.layout.reunion_widget)
                    renderFallback(context, plain, widgetData)
                    manager.updateAppWidget(widgetId, plain)
                } catch (inner: Throwable) {
                    android.util.Log.e(TAG, "reunion fallback failed", inner)
                }
            }
        }

        fun render(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
            options: Bundle? = null,
        ) {
            renderBackground(context, views, widgetData, options)
            renderCountdown(views, widgetData)
            TodaysTulipWidget.roundTheWholeCard(views, R.id.reunion_root)

            views.setOnClickPendingIntent(
                R.id.reunion_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dayflower://events"),
                ),
            )
        }

        /** Text only — no bitmap, nothing that can throw twice. */
        fun renderFallback(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
        ) {
            views.setViewVisibility(R.id.reunion_photo, View.GONE)
            views.setViewVisibility(R.id.reunion_fallback, View.VISIBLE)
            renderCountdown(views, widgetData)
            views.setOnClickPendingIntent(
                R.id.reunion_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dayflower://events"),
                ),
            )
        }

        /**
         * The chosen photo, or the app's gradient.
         *
         * ⚠️ The stored path carries a `?v=` suffix written when the file was
         * saved. The filename itself never changes — one photo, one slot —
         * so without that suffix nothing downstream can tell that the bytes
         * behind it are new. It is stripped here before opening the file.
         */
        fun renderBackground(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
            options: Bundle?,
        ) {
            val stored = widgetData.getString("reunion_bg", "") ?: ""
            val path = stored.substringBefore('?')
            val photo = if (path.isEmpty()) {
                null
            } else {
                TodaysTulipWidget.decodePhoto(path)
                    ?.let { TodaysTulipWidget.roundCorners(context, it, options) }
            }

            if (photo != null) {
                views.setImageViewBitmap(R.id.reunion_photo, photo)
                views.setViewVisibility(R.id.reunion_photo, View.VISIBLE)
                views.setViewVisibility(R.id.reunion_fallback, View.GONE)
            } else {
                views.setViewVisibility(R.id.reunion_photo, View.GONE)
                views.setViewVisibility(R.id.reunion_fallback, View.VISIBLE)
            }
        }

        /**
         * How long is left, worked out **here** rather than in Dart.
         *
         * ⚠️ A widget can be left alone on a home screen for days. A string
         * baked when the app last ran would say "412 days" all week, so what
         * crosses is the instant, and the arithmetic happens every time this
         * draws — on the 30-minute update, on a resize, on a reboot.
         */
        fun renderCountdown(views: RemoteViews, widgetData: SharedPreferences) {
            val happensAt = widgetData.getLong("reunion_at", 0L)
            val title = widgetData.getString("reunion_title", "") ?: ""
            val place = widgetData.getString("reunion_place", "") ?: ""

            if (happensAt <= 0L) {
                views.setTextViewText(R.id.reunion_title, "Nothing planned yet")
                views.setTextViewText(R.id.reunion_count, "—")
                views.setTextViewText(R.id.reunion_unit, "")
                views.setTextViewText(
                    R.id.reunion_when,
                    "Tap to set a date to count down to.",
                )
                return
            }

            views.setTextViewText(
                R.id.reunion_title,
                if (title.isEmpty()) "Reunion" else title,
            )

            val days = wholeDaysUntil(happensAt)
            when {
                days > 1L -> {
                    views.setTextViewText(R.id.reunion_count, "$days")
                    views.setTextViewText(R.id.reunion_unit, "days to go")
                }
                days == 1L -> {
                    views.setTextViewText(R.id.reunion_count, "1")
                    views.setTextViewText(R.id.reunion_unit, "day to go")
                }
                days == 0L -> {
                    // The one day this card exists for.
                    views.setTextViewText(R.id.reunion_count, "Today")
                    views.setTextViewText(R.id.reunion_unit, "")
                }
                else -> {
                    views.setTextViewText(R.id.reunion_count, "Together")
                    views.setTextViewText(R.id.reunion_unit, "")
                }
            }

            val date = DATE_FORMAT.format(Date(happensAt))
            views.setTextViewText(
                R.id.reunion_when,
                if (place.isEmpty()) date else "$date  ·  $place",
            )
        }

        /**
         * Whole calendar days from today to [happensAt].
         *
         * ⚠️ Calendar days, not elapsed hours. A reunion at 8am tomorrow is
         * "1 day", not "0" because only 14 hours are left — the number on
         * this card has to agree with the one a person counts on a calendar,
         * which is the only reason they look at it.
         */
        fun wholeDaysUntil(happensAt: Long): Long {
            val target = startOfDay(happensAt)
            val today = startOfDay(System.currentTimeMillis())
            // ⚠️ Rounded, not truncated. Two midnights are 24 hours apart
            // except across a daylight-saving change, where they are 23 or
            // 25 — and integer division of 23 hours by a day is zero, which
            // would silently drop a day from the count once a year.
            return Math.round((target - today) / 86_400_000.0)
        }

        private fun startOfDay(millis: Long): Long {
            val cal = Calendar.getInstance()
            cal.timeInMillis = millis
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.timeInMillis
        }

        private val DATE_FORMAT = SimpleDateFormat("d MMM yyyy", Locale.getDefault())
    }
}
