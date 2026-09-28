package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import java.io.File
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * "Today's Flower" widget (class name predates the label).
 *
 * Values in [widgetData] are written from Dart by DayflowerWidgets.syncFlower()
 * — the keys must stay in sync. Tapping opens the app on the Flowers tab.
 */
class TodaysTulipWidget : HomeWidgetProvider() {

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

        /**
         * Renders one widget, and CANNOT take the app down with it.
         *
         * 🔴 An AppWidgetProvider is a BroadcastReceiver, and it runs in the
         * app's own process. Opening the app syncs the widgets, so anything
         * that throws in here is not a broken widget - it is the app dying
         * about a second after launch, with the crash pointing at a
         * home-screen widget nobody was looking at.
         *
         * The throw is not only ours to make. updateAppWidget() itself
         * rejects a RemoteViews whose bitmaps exceed the host's budget
         * (6 * screen width * height bytes), and that check runs on this
         * side of the binder call. So the retry drops the photo - which is
         * the only large thing in here - rather than trying to be cleverer
         * about why.
         *
         * Whatever the cause, a widget that shows its fallback glyph is a
         * cosmetic problem. An app that will not open is not.
         */
        fun renderSafely(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            widgetData: SharedPreferences,
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.todays_tulip_widget)
                val listed = renderFlower(
                    context,
                    views,
                    widgetData,
                    appWidgetManager.getAppWidgetOptions(widgetId),
                    widgetId,
                )
                appWidgetManager.updateAppWidget(widgetId, views)
                // The list keeps the rows it has until it is told they
                // changed: a new day, or a heart. Its scroll stays put.
                if (listed) {
                    appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
                }
            } catch (e: Throwable) {
                // Named in the log so a logcat says what actually failed
                // rather than leaving the next person guessing at it.
                android.util.Log.e(TAG, "widget render failed, falling back", e)
                try {
                    val plain =
                        RemoteViews(context.packageName, R.layout.todays_tulip_widget)
                    renderFallback(context, plain, widgetData)
                    appWidgetManager.updateAppWidget(widgetId, plain)
                } catch (e2: Throwable) {
                    // Give up on the widget entirely. Never rethrow: this is
                    // the frame that stands between a bad widget and a dead
                    // app process.
                    android.util.Log.e(TAG, "widget fallback failed too", e2)
                }
            }
        }

        /**
         * The flower glyph and nothing else - no photo, no avatar, no
         * bitmaps of any kind. Deliberately the smallest thing that can
         * still be called a rendered widget.
         */
        fun renderFallback(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
        ) {
            // Both photo views. Hiding a child of the flipper would leave
            // the flipper itself cycling empty slots.
            views.setViewVisibility(R.id.widget_photo_still, View.GONE)
            views.setViewVisibility(R.id.widget_flipper, View.GONE)
            views.setViewVisibility(R.id.widget_list, View.GONE)
            views.setViewVisibility(R.id.widget_flower_art, View.GONE)
            views.setViewVisibility(R.id.widget_header, View.GONE)
            views.setViewVisibility(R.id.widget_caption, View.VISIBLE)
            // Invisible, not gone: its box is what holds the line off the
            // card's bottom edge (see widget_caption in the layout).
            views.setViewVisibility(R.id.widget_heart, View.INVISIBLE)
            views.setViewVisibility(R.id.widget_emoji, View.VISIBLE)
            views.setTextViewText(
                R.id.widget_emoji,
                widgetData.getString("tulip_emoji", "🌷"),
            )
            setTextOrHide(views, R.id.widget_title, widgetData.getString("tulip_title", ""))
            views.setViewVisibility(R.id.widget_body_row, View.GONE)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dayflower://flowers"),
                ),
            )
        }

        private const val TAG = "DayflowerWidget"

        /**
         * Settings' choice for more than one live day: [DAYS_SCROLL] for a
         * list to scroll, anything else for the rotation (or none) that
         * `widget_rotate_seconds` sets. DayflowerWidgets.keyDaysStyle in
         * Dart; change them together.
         */
        const val KEY_DAYS_STYLE = "widget_days_style"
        const val DAYS_SCROLL = "scroll"

        /**
         * Shared with DayflowerWidget so the adaptive variant renders
         * identically. Returns whether their days are the scrolling list,
         * which the caller then tells to reload once the views are on the
         * card (renderSafely).
         */
        fun renderFlower(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
            options: Bundle? = null,
            widgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID,
        ): Boolean {
            // A day photo takes the slot when there is a live one; otherwise
            // the flower glyph does. Never both.
            val refs = dayRefs(widgetData)
            // More than one, and Settings says scroll. The list fetches
            // each day's photo itself (DayListService), so none is decoded
            // here for it.
            val listed = refs.size > 1 &&
                widgetId != AppWidgetManager.INVALID_APPWIDGET_ID &&
                widgetData.getString(KEY_DAYS_STYLE, "") == DAYS_SCROLL
            val days = if (listed) {
                emptyList()
            } else {
                refs.mapNotNull { ref ->
                    decodePhoto(ref.path)?.let {
                        Day(roundCorners(context, it, options), ref.id, ref.note)
                    }
                }
            }
            val photos = days.map { it.photo }
            val hearted = linesOf(widgetData, DayLikeReceiver.KEY_HEARTED).toSet()
            // The flower's own painting, for when there is no day photo.
            // WARNING: fitted rather than full-bleed, and in a view of its
            // own - the catalogue art is a 512px square and this card is
            // tall, so centreCrop would keep a narrow vertical strip of it.
            val art = if (!listed && photos.isEmpty()) loadFlowerArt(widgetData) else null
            var rotating = false
            if (listed) {
                renderList(context, views, widgetId)
                views.setViewVisibility(R.id.widget_photo_still, View.GONE)
                // Emptied as well as hidden: last rotation's bitmaps.
                views.removeAllViews(R.id.widget_flipper)
                views.setViewVisibility(R.id.widget_flipper, View.GONE)
                views.setViewVisibility(R.id.widget_flower_art, View.GONE)
                views.setViewVisibility(R.id.widget_emoji, View.GONE)
            } else if (photos.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_list, View.GONE)
                // Which of the two photo views is shown is renderPhotos'
                // decision — it depends on whether anything is rotating.
                rotating = renderPhotos(context, views, widgetData, days, hearted)
                views.setViewVisibility(R.id.widget_flower_art, View.GONE)
                views.setViewVisibility(R.id.widget_emoji, View.GONE)
            } else if (art != null) {
                views.setViewVisibility(R.id.widget_list, View.GONE)
                views.setViewVisibility(R.id.widget_photo_still, View.GONE)
                views.setViewVisibility(R.id.widget_flipper, View.GONE)
                views.setImageViewBitmap(R.id.widget_flower_art, art)
                views.setViewVisibility(R.id.widget_flower_art, View.VISIBLE)
                views.setViewVisibility(R.id.widget_emoji, View.GONE)
            } else {
                // A retired flower with no artwork, or nothing from them at
                // all. The glyph is the honest fallback, not a failure.
                views.setViewVisibility(R.id.widget_list, View.GONE)
                views.setViewVisibility(R.id.widget_photo_still, View.GONE)
                views.setViewVisibility(R.id.widget_flipper, View.GONE)
                views.setViewVisibility(R.id.widget_flower_art, View.GONE)
                views.setViewVisibility(R.id.widget_emoji, View.VISIBLE)
            }

            // Not only over a photo any more. A flower now says who it is
            // from up here, with their face on it, rather than in the
            // caption as "Tulip from Sheena" - the name belongs beside the
            // avatar, and it was being said twice on a card this small.
            // Hides itself when there is nothing from them at all.
            renderStoryHeader(views, widgetData)

            views.setTextViewText(
                R.id.widget_emoji,
                widgetData.getString("tulip_emoji", "🌷"),
            )
            // Empty means hidden, not a blank line. The caption is now only
            // a flower's name or something they actually wrote, so on a day
            // photo with no note there is genuinely nothing to say here and
            // an empty TextView would still hold a line of space open.
            setTextOrHide(views, R.id.widget_title, widgetData.getString("tulip_title", ""))
            // The note's whole row, not only its words: see widget_caption.
            val body = widgetData.getString("tulip_body", "") ?: ""
            views.setTextViewText(R.id.widget_body, body)
            views.setViewVisibility(
                R.id.widget_body_row,
                if (body.isEmpty()) View.GONE else View.VISIBLE,
            )

            // The card's own caption and heart, for one day or a flower.
            // While days rotate or scroll, each carries its own
            // (renderPhotos, DayListService).
            val ownCaption = !rotating && !listed
            views.setViewVisibility(
                R.id.widget_caption,
                if (ownCaption) View.VISIBLE else View.GONE,
            )
            val heartFor = when {
                !ownCaption -> null
                days.isNotEmpty() -> days.first().id
                else -> widgetData.getString("flower_id", "")
            }
            // On the last line, level with it: the note's, when there is
            // one, and the title's otherwise.
            if (body.isEmpty()) {
                renderHeart(context, views, R.id.widget_heart, heartFor, hearted)
            } else {
                views.setViewVisibility(R.id.widget_heart, View.GONE)
                renderHeart(context, views, R.id.widget_body_heart, heartFor, hearted)
            }

            // 🔴 **What it shows is what a tap opens.** Every tap opened the
            // conversation, so a day on the card opened the app on the
            // chat, or on Home when the app was cold, and never on the day.
            // Their days now open in the My Day viewer; a flower still goes
            // to the conversation it was sent in. See _openWidgetTarget.
            val open = if (listed || photos.isNotEmpty()) {
                openDays(context, null)
            } else {
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dayflower://flowers"),
                )
            }
            views.setOnClickPendingIntent(R.id.widget_root, open)
            // The header too, and always: over the scrolling list a tap on
            // it would otherwise land on the row beneath, and once a view
            // has a tap it keeps it through every later render, so it is
            // set every time rather than only while the list is up.
            views.setOnClickPendingIntent(R.id.widget_header, open)

            roundTheWholeCard(views)
            return listed
        }

        /**
         * Their days as a list to scroll (Settings: Scroll).
         *
         * The rows are DayListService's: the launcher asks it for each one
         * as it comes into view. A row cannot carry PendingIntents of its
         * own (the launcher ignores them inside a list), so the list has
         * one, to DayLikeReceiver, and each row fills in which day it is
         * and whether the tap was its heart.
         *
         * ⚠️ The widget id is in the adapter intent's data, not only in an
         * extra. Intents that differ only in extras are the same intent to
         * the system, so two widgets would share one list; and the same
         * intent again on the next render is what keeps the list where it
         * was scrolled to rather than starting it over.
         */
        @Suppress("DEPRECATION")
        private fun renderList(context: Context, views: RemoteViews, widgetId: Int) {
            val adapter = Intent(context, DayListService::class.java)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            adapter.data = Uri.parse(adapter.toUri(Intent.URI_INTENT_SCHEME))
            views.setRemoteAdapter(R.id.widget_list, adapter)
            views.setPendingIntentTemplate(R.id.widget_list, DayLikeReceiver.listTemplate(context))
            views.setViewVisibility(R.id.widget_list, View.VISIBLE)
        }

        /** The My Day viewer, on day [id] when there is one. */
        fun openDays(context: Context, id: String?): PendingIntent =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(
                    if (id.isNullOrBlank()) "dayflower://days" else "dayflower://days?id=" + Uri.encode(id),
                ),
            )

        /**
         * A heart for message [id]: an outline, or red once hearted, and a
         * tap that flips it (DayLikeReceiver). Invisible when there is
         * nothing to love, not gone: its box is what holds the caption's
         * last line off the bottom of the card (see widget_caption).
         */
        fun renderHeart(
            context: Context,
            views: RemoteViews,
            viewId: Int,
            id: String?,
            hearted: Set<String>,
        ) {
            if (id.isNullOrBlank()) {
                views.setViewVisibility(viewId, View.INVISIBLE)
                return
            }
            val on = hearted.contains(id)
            views.setViewVisibility(viewId, View.VISIBLE)
            views.setImageViewResource(
                viewId,
                if (on) R.drawable.ic_widget_heart_on else R.drawable.ic_widget_heart_off,
            )
            views.setContentDescription(viewId, if (on) "Loved. Tap to take it back" else "Love")
            views.setOnClickPendingIntent(viewId, DayLikeReceiver.pendingIntent(context, id))
        }

        /** A newline-separated list the Dart side wrote. */
        fun linesOf(widgetData: SharedPreferences, key: String): List<String> =
            (widgetData.getString(key, "") ?: "").split('\n').filter { it.isNotBlank() }

        /**
         * Rounds the card and everything in it, the system's way.
         *
         * WARNING: this is the ONLY thing that rounds the photo on API 31+.
         * roundCorners bakes a radius into the bitmap as well, but only
         * below 31 - doing both made the corners twice as round as the card,
         * because a radius cut into a bitmap scales when the ImageView is
         * centerCrop - so the moment the widget's real aspect differs at all
         * from the size the launcher reported, the crop trims off the very
         * corners that were just drawn and the card looks square again.
         * That is exactly what happened on the phone.
         *
         * setViewOutlinePreferredRadius clips the root and every child of
         * it, so nothing inside can have a sharp corner regardless of what
         * the bitmap looks like. API 31+ only, which is why the bitmap
         * rounding stays as the fallback rather than being replaced.
         */
        fun roundTheWholeCard(views: RemoteViews, rootId: Int = R.id.widget_root) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
            views.setViewOutlinePreferredRadius(
                rootId,
                CORNER_DP,
                TypedValue.COMPLEX_UNIT_DIP,
            )
        }

        /**
         * Matches @drawable/widget_background's corner radius.
         *
         * 20, down from 34 at the user's request: at 34 the cards read as
         * pills beside the launcher's own icons and folders.
         */
        private const val CORNER_DP = 20f

        /**
         * Cuts the photo to the widget's own shape, with rounded corners.
         *
         * WARNING: this is the only thing that rounds this widget. The card
         * behind it is a rounded shape drawable, but a full-bleed photo
         * covers it completely, so the widget rendered as a hard-cornered
         * rectangle beside the heartbeat widget's rounded one. Only Android
         * 12+ launchers clip widget corners themselves, and OEM launchers
         * often skip it; on anything else nothing else will do this.
         *
         * The bitmap is cropped to the widget's reported aspect first so the
         * ImageView's centerCrop becomes a straight scale - otherwise it
         * would trim the very corners this just drew. A launcher that
         * reports nothing usable falls back to the bitmap's own bounds,
         * which still rounds, just with a sliver possibly cropped.
         */
        fun roundCorners(context: Context, src: Bitmap, options: Bundle?): Bitmap {
            return try {
                val density = context.resources.displayMetrics.density
                // Portrait dimensions: minWidth is the narrow-orientation
                // width, maxHeight the tall-orientation height.
                val wDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
                val hDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0

                var outW = (wDp * density).toInt()
                var outH = (hDp * density).toInt()
                if (outW <= 0 || outH <= 0) {
                    outW = src.width
                    outH = src.height
                }
                // ⚠️ Bounded on BOTH axes, and that is not tidiness.
                // updateAppWidget() rejects a RemoteViews whose bitmaps
                // exceed 6 * screen width * height bytes, and it throws that
                // on this side of the binder call - inside a provider, which
                // runs in the app's process. Getting this wrong is not a
                // blank widget, it is the app closing on launch.
                //
                // TARGET_PX is what loadDayPhoto already downsamples to, so
                // this can never ask for more memory than the square version
                // did. Upscaling past the source buys no detail either.
                val limit = minOf(maxOf(src.width, src.height), TARGET_PX)
                if (maxOf(outW, outH) > limit) {
                    val scale = limit.toFloat() / maxOf(outW, outH)
                    outW = (outW * scale).toInt()
                    outH = (outH * scale).toInt()
                }
                if (outW <= 0 || outH <= 0) return src

                // Centre-crop rect on the source, matching the output aspect.
                val outAspect = outW.toFloat() / outH
                val srcAspect = src.width.toFloat() / src.height
                val cropW: Int
                val cropH: Int
                if (srcAspect > outAspect) {
                    cropH = src.height
                    cropW = (src.height * outAspect).toInt().coerceIn(1, src.width)
                } else {
                    cropW = src.width
                    cropH = (src.width / outAspect).toInt().coerceIn(1, src.height)
                }
                val left = (src.width - cropW) / 2
                val top = (src.height - cropH) / 2
                val srcRect = Rect(left, top, left + cropW, top + cropH)

                val out = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(out)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG)

                // 🔴 **Only where nothing else can round it.** The corners
                // were being cut twice - here and by the outline clip - and
                // the two do not agree, because this radius is baked into
                // the *bitmap* while the clip is applied to the *view*.
                //
                // The bitmap is smaller than the widget: capped to the
                // source's own size and to TARGET_PX. So the ImageView
                // scales it up, and the baked radius scales with it. A 20dp
                // corner cut into a 540-wide bitmap shown in a 1080-wide
                // widget lands at 40dp - twice as round as the card behind
                // it, and twice as round as the heartbeat widget beside it.
                //
                // Above API 31 the outline clip is exact and the view does
                // it right; below, this is the only thing there is.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                    val radius = CORNER_DP * density
                    // A mask rather than a clipPath: clipPath is not
                    // antialiased and leaves stepped corners.
                    paint.color = 0xFF000000.toInt()
                    canvas.drawRoundRect(
                        RectF(0f, 0f, outW.toFloat(), outH.toFloat()),
                        radius,
                        radius,
                        paint,
                    )
                    paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
                }

                canvas.drawBitmap(src, srcRect, Rect(0, 0, outW, outH), paint)
                out
            } catch (e: Throwable) {
                // Out of memory, a recycled bitmap, anything: a square photo
                // is a cosmetic problem, a blank widget is not.
                src
            }
        }

        /** How many photos the widget will cycle through. */
        private const val MAX_ROTATION = 5

        /**
         * Puts the photos on the card, animated or still.
         *
         * 🔴 **Every call through RemoteViews has to be remotable, and almost
         * none of ViewFlipper's are.** `setFlipInterval` is the only method
         * on the class annotated `@RemotableViewMethod` — `setAutoStart`,
         * `startFlipping` and `stopFlipping` are ordinary methods, and
         * putting one through RemoteViews throws an ActionException the
         * launcher reports as **"Problem loading widget"**.
         *
         * 🔴 Which means **a flipper cannot be told to hold still**, and the
         * attempt to express that structurally — a flipper with one child —
         * did not work either: `autoStart` runs it anyway, and `showNext`
         * with a single child re-shows *that* child, playing the out and in
         * animations against itself. On the phone that was the widget
         * blinking every few seconds.
         *
         * So the flipper is used only when there is genuinely something to
         * cycle. One photo, or rotation off, goes to a plain ImageView that
         * has no animation to run.
         *
         * ⚠️ Children are added rather than shown and hidden: a flipper
         * cycles every child it has, GONE included, so fixed slots would
         * flip through blank frames.
         */
        /** Returns whether the days are rotating (each with its own heart). */
        fun renderPhotos(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
            days: List<Day>,
            hearted: Set<String>,
        ): Boolean {
            val photos = days.map { it.photo }
            if (photos.isEmpty()) {
                views.setViewVisibility(R.id.widget_photo_still, View.GONE)
                views.setViewVisibility(R.id.widget_flipper, View.GONE)
                return false
            }

            val seconds = widgetData.intOf("widget_rotate_seconds")
            val rotating = seconds > 0 && photos.size > 1

            // Emptied either way. A flipper left holding last sync's bitmaps
            // is a flipper still holding that memory, and the children would
            // reappear the moment rotation came back on.
            views.removeAllViews(R.id.widget_flipper)

            if (!rotating) {
                views.setImageViewBitmap(R.id.widget_photo_still, photos.first())
                views.setViewVisibility(R.id.widget_photo_still, View.VISIBLE)
                views.setViewVisibility(R.id.widget_flipper, View.GONE)
                return false
            }

            for (day in days.take(MAX_ROTATION)) {
                val item = RemoteViews(context.packageName, R.layout.widget_photo_item)
                item.setImageViewBitmap(R.id.widget_photo, day.photo)
                // Its own words and its own heart: see widget_photo_item.
                setTextOrHide(item, R.id.widget_item_note, day.note)
                renderHeart(context, item, R.id.widget_item_heart, day.id, hearted)
                // A tap opens the viewer on the day that was showing, not
                // on their newest.
                item.setOnClickPendingIntent(R.id.widget_photo, openDays(context, day.id))
                views.addView(R.id.widget_flipper, item)
            }
            views.setInt(R.id.widget_flipper, "setFlipInterval", seconds * 1000)
            // Back on the day whose heart was just tapped, not the newest.
            val focus = widgetData.getString(DayLikeReceiver.KEY_FOCUS, "")
            val focusAt = widgetData.longOf(DayLikeReceiver.KEY_FOCUS_AT)
            if (!focus.isNullOrBlank() &&
                System.currentTimeMillis() - focusAt < DayLikeReceiver.FOCUS_MS
            ) {
                val at = days.take(MAX_ROTATION).indexOfFirst { it.id == focus }
                if (at > 0) views.setDisplayedChild(R.id.widget_flipper, at)
            }
            views.setViewVisibility(R.id.widget_flipper, View.VISIBLE)
            views.setViewVisibility(R.id.widget_photo_still, View.GONE)
            return true
        }

        /** One live day on the card: its photo, message id and words. */
        data class Day(val photo: Bitmap, val id: String?, val note: String?)

        /** One live day before its photo is decoded: where the photo is. */
        data class DayRef(val path: String, val id: String?, val note: String?)

        /**
         * The live days, newest first, each with the id its heart loves and
         * the words written on it.
         *
         * ⚠️ Kept in step by index with what Dart wrote (day_photo_paths,
         * day_photo_ids, day_photo_notes): a photo that is not there is
         * dropped with its id and note, never shifting the others onto the
         * wrong day. One that is there but will not decode is dropped the
         * same way, by whoever decodes it.
         */
        fun dayRefs(widgetData: SharedPreferences): List<DayRef> {
            // Self-expiry. The widget refreshes every 30 min, so the photos
            // leave the home screen within half an hour of their 24h mark
            // even if the app is never opened again, which is the only way
            // the "lasts a day" promise actually holds.
            val expiresAt = widgetData.longOf("day_photo_expires_at")
            if (expiresAt > 0L && System.currentTimeMillis() >= expiresAt) {
                return emptyList()
            }
            val paths = linesOf(widgetData, "day_photo_paths")
            val ids = linesOf(widgetData, "day_photo_ids")
            val notes = try {
                val json = org.json.JSONArray(widgetData.getString("day_photo_notes", "[]") ?: "[]")
                List(json.length()) { json.optString(it, "") }
            } catch (_: Throwable) {
                emptyList()
            }
            if (paths.isEmpty()) {
                // Older data, written before rotation existed.
                val path = widgetData.getString("day_photo_path", "") ?: ""
                if (path.isEmpty() || !File(path).exists()) return emptyList()
                return listOf(DayRef(path, widgetData.getString("day_photo_id", ""), null))
            }
            return paths.take(MAX_ROTATION).mapIndexedNotNull { i, path ->
                if (File(path).exists()) DayRef(path, ids.getOrNull(i), notes.getOrNull(i)) else null
            }
        }

        /**
         * Decodes the day photo Dart cached to disk, downscaled.
         *
         * RemoteViews are delivered to the launcher over IPC and a full-size
         * camera bitmap blows straight through that limit — the widget just
         * renders blank with no error anywhere. [inSampleSize] keeps the long
         * edge near [TARGET_PX].
         *
         * That target is sized for the story layout, where the photo is
         * full-bleed across a tall widget rather than a thumbnail in a row —
         * 512 was visibly soft once it had to fill the whole card. The
         * ceiling being spent against is AppWidgetService's
         * `6 * displayWidth * displayHeight` bytes, which on a 1080x2400
         * phone is roughly 15 MB; a 1024-long-edge ARGB_8888 bitmap costs
         * under 3 MB, so there is room, but this is the knob to turn back
         * down if a widget ever starts rendering blank.
         *
         * Returns null when there is no live photo, which is also what an
         * expired one looks like: Dart writes an empty path once the 24h are
         * up, so expiry needs no logic on this side.
         */
        fun setTextOrHide(views: RemoteViews, viewId: Int, text: String?) {
            if (text.isNullOrEmpty()) {
                views.setViewVisibility(viewId, View.GONE)
            } else {
                views.setViewVisibility(viewId, View.VISIBLE)
                views.setTextViewText(viewId, text)
            }
        }

        /**
         * Story header — avatar, who it is from, and the time remaining.
         *
         * The countdown is computed here rather than pushed from Dart for the
         * same reason expiry is: the widget outlives the app process, so a
         * "16h" written at sync time would still read 16h tomorrow.
         */
        fun renderStoryHeader(views: RemoteViews, widgetData: SharedPreferences) {
            // Written for a flower as well as a day photo now; empty only
            // when there is nothing from them, which is when there is
            // nobody to name.
            val owner = widgetData.getString("day_photo_owner", "") ?: ""
            if (owner.isEmpty()) {
                views.setViewVisibility(R.id.widget_header, View.GONE)
                return
            }

            views.setViewVisibility(R.id.widget_header, View.VISIBLE)
            views.setTextViewText(R.id.widget_owner, owner)
            // Their chosen flower (migration 0015). Falls back to a tulip
            // rather than an initial: every other surface draws a flower now,
            // and a lone letter here would be the odd one out.
            val flower = widgetData.getString("day_photo_owner_flower", "") ?: ""
            views.setTextViewText(
                R.id.widget_avatar,
                if (flower.isEmpty()) "🌷" else flower,
            )

            // Their actual face, when they have uploaded one. Already cut to
            // a circle by Dart — RemoteViews cannot clip a bitmap, so a
            // square photo here would sit in the round header as a square.
            val avatar = loadAvatar(widgetData)
            if (avatar != null) {
                views.setImageViewBitmap(R.id.widget_avatar_photo, avatar)
                views.setViewVisibility(R.id.widget_avatar_photo, View.VISIBLE)
                views.setViewVisibility(R.id.widget_avatar, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_avatar_photo, View.GONE)
                views.setViewVisibility(R.id.widget_avatar, View.VISIBLE)
            }
            views.setTextViewText(
                R.id.widget_left,
                timeLeftLabel(widgetData.longOf("day_photo_expires_at")),
            )
        }

        /**
         * The circular avatar PNG Dart cached, or null when there is none.
         *
         * No downscaling here: it is written at 96px and drawn at 30dp, so
         * there is nothing to save and `inSampleSize` on something this
         * small only costs sharpness.
         */
        fun loadAvatar(widgetData: SharedPreferences): Bitmap? {
            val path = widgetData.getString("day_photo_owner_avatar", "") ?: ""
            if (path.isEmpty()) return null
            val file = File(path)
            if (!file.exists()) return null
            return try {
                BitmapFactory.decodeFile(path)
            } catch (e: Exception) {
                // A half-written cache file is a missing avatar, not a
                // broken widget — the flower glyph is right there.
                null
            }
        }

        /** "16h" / "42m", and empty once there is nothing left to count. */
        fun timeLeftLabel(expiresAt: Long): String {
            if (expiresAt <= 0L) return ""
            val remaining = expiresAt - System.currentTimeMillis()
            if (remaining <= 0L) return ""
            val hours = remaining / 3_600_000L
            if (hours >= 1L) return "${hours}h"
            return "${(remaining / 60_000L).coerceAtLeast(1L)}m"
        }

        private const val TARGET_PX = 1024

        /**
         * The flower's painting, copied out of the app bundle by Dart.
         *
         * No expiry check, unlike the day photo: a flower stays on the home
         * screen until the next one replaces it. Written under its own key
         * so it never collides with a live day.
         */
        fun loadFlowerArt(widgetData: SharedPreferences): Bitmap? {
            val path = widgetData.getString("flower_art", "") ?: ""
            if (path.isEmpty()) return null
            return decodePhoto(path)
        }

        /** Decodes one cached photo, downscaled to [TARGET_PX]. */
        fun decodePhoto(path: String): Bitmap? {
            val file = File(path)
            if (!file.exists()) return null

            return try {
                val bounds = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeFile(path, bounds)
                var sample = 1
                val longEdge = maxOf(bounds.outWidth, bounds.outHeight)
                while (longEdge / sample > TARGET_PX) sample *= 2

                BitmapFactory.decodeFile(
                    path,
                    BitmapFactory.Options().apply { inSampleSize = sample },
                )
            } catch (e: Throwable) {
                // A corrupt or half-written file must not take the widget
                // down — fall back to the flower glyph.
                null
            }
        }
    }
}
