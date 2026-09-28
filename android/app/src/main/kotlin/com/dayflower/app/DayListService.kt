package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Their days, for the My Day widget's scrolling list (widget_list), when
 * Settings says Scroll rather than Rotate.
 *
 * The launcher binds this and asks for rows as they come into view, so a
 * day's photo is decoded when it is about to be seen, not all five at every
 * render. Each row is the card again (widget_day_item): the photo cut to
 * the card's shape, and its own caption and heart.
 *
 * 🔴 **Taps are filled in, not attached.** The launcher ignores a
 * PendingIntent set on anything inside a list row, so the list carries one
 * template (DayLikeReceiver.listTemplate) and each row only says what was
 * tapped: `dayflower://like?id=` for its heart, `dayflower://open?reply=`
 * for its reply, `dayflower://open?day=` for the rest of it.
 */
class DayListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        DayListFactory(
            applicationContext,
            intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            ),
        )
}

private class DayListFactory(
    private val context: Context,
    private val widgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {

    private var days: List<TodaysTulipWidget.Companion.DayRef> = emptyList()
    private var hearted: Set<String> = emptySet()

    override fun onCreate() {}

    /** Called for notifyAppWidgetViewDataChanged: a sync, or a heart. */
    override fun onDataSetChanged() {
        val data = HomeWidgetPlugin.getData(context)
        days = TodaysTulipWidget.dayRefs(data)
        hearted = TodaysTulipWidget.linesOf(data, DayLikeReceiver.KEY_HEARTED).toSet()
    }

    override fun onDestroy() {
        days = emptyList()
    }

    override fun getCount(): Int = days.size

    override fun getViewAt(position: Int): RemoteViews {
        val row = RemoteViews(context.packageName, R.layout.widget_day_item)
        val day = days.getOrNull(position) ?: return row
        // 🔴 Same guard as TodaysTulipWidget.renderSafely: this runs in the
        // app's own process, and a throw here is not an empty row.
        try {
            val photo = TodaysTulipWidget.decodePhoto(day.path)
            if (photo != null) {
                // Cut to the card's shape, which is what makes the row the
                // card's height (see widget_day_item).
                val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
                // 🔴 **An Icon, never setImageViewBitmap.** A bitmap in a
                // RemoteViews is a number into a table of bitmaps, and newer
                // Android folds the list's rows into the card's own
                // RemoteViews without renumbering them: on the emulator
                // (API 37) the first day showed the header's avatar, and
                // every day after it the photo of the day before. An Icon
                // carries its bitmap itself, so there is no number to get
                // wrong.
                row.setImageViewIcon(
                    R.id.widget_day_photo,
                    Icon.createWithBitmap(TodaysTulipWidget.roundCorners(context, photo, options)),
                )
            }
        } catch (e: Throwable) {
            android.util.Log.e("DayflowerWidget", "list row photo failed", e)
        }
        TodaysTulipWidget.setTextOrBlank(row, R.id.widget_day_note, day.note)
        row.setOnClickFillInIntent(
            R.id.widget_day_photo,
            Intent().setData(Uri.parse("dayflower://open?day=" + Uri.encode(day.id ?: ""))),
        )

        val id = day.id
        if (id.isNullOrBlank()) {
            row.setViewVisibility(R.id.widget_day_heart, View.INVISIBLE)
            row.setViewVisibility(R.id.widget_day_reply, View.INVISIBLE)
        } else {
            val on = hearted.contains(id)
            row.setImageViewResource(
                R.id.widget_day_heart,
                if (on) R.drawable.ic_widget_heart_on else R.drawable.ic_widget_heart_off,
            )
            row.setContentDescription(
                R.id.widget_day_heart,
                if (on) "Loved. Tap to take it back" else "Love",
            )
            row.setOnClickFillInIntent(
                R.id.widget_day_heart,
                Intent().setData(Uri.parse("dayflower://like?id=" + Uri.encode(id))),
            )
            row.setOnClickFillInIntent(
                R.id.widget_day_reply,
                Intent().setData(Uri.parse("dayflower://open?reply=" + Uri.encode(id))),
            )
        }
        return row
    }

    /** The card's colour, not the launcher's grey "Loading…". */
    override fun getLoadingView(): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_day_loading)

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        days.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()

    /** By message id, so a heart redraws that day where it is. */
    override fun hasStableIds(): Boolean = true
}
