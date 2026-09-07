package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.Context
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
                renderFlower(
                    context,
                    views,
                    widgetData,
                    appWidgetManager.getAppWidgetOptions(widgetId),
                )
                appWidgetManager.updateAppWidget(widgetId, views)
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
            views.setViewVisibility(R.id.widget_header, View.GONE)
            views.setViewVisibility(R.id.widget_reply_bar, View.GONE)
            views.setViewVisibility(R.id.widget_emoji, View.VISIBLE)
            views.setTextViewText(
                R.id.widget_emoji,
                widgetData.getString("tulip_emoji", "🌷"),
            )
            setTextOrHide(views, R.id.widget_title, widgetData.getString("tulip_title", ""))
            views.setViewVisibility(R.id.widget_body, View.GONE)
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

        /** Shared with DayflowerWidget so the adaptive variant renders identically. */
        fun renderFlower(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
            options: Bundle? = null,
        ) {
            // A day photo takes the slot when there is a live one; otherwise
            // the flower glyph does. Never both.
            val photos = loadDayPhotos(widgetData)
                .map { roundCorners(context, it, options) }
            if (photos.isNotEmpty()) {
                // Which of the two photo views is shown is renderPhotos'
                // decision — it depends on whether anything is rotating.
                renderPhotos(context, views, widgetData, photos)
                views.setViewVisibility(R.id.widget_emoji, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_photo_still, View.GONE)
                views.setViewVisibility(R.id.widget_flipper, View.GONE)
                views.setViewVisibility(R.id.widget_emoji, View.VISIBLE)
            }
            val photo = photos.firstOrNull()

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
            setTextOrHide(views, R.id.widget_body, widgetData.getString("tulip_body", ""))

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dayflower://flowers"),
                ),
            )

            roundTheWholeCard(views)
            renderReactions(context, views, photo != null)
        }

        /**
         * The five reactions, in place of the old reply bar.
         *
         * WARNING: there used to be a "Send message" pill beside a tulip.
         * The pill could not be a text field - RemoteViews has no EditText -
         * so it launched the app, which is not replying from the widget but
         * leaving it. And the tulip sent a real classic_tulip FLOWER into
         * the conversation: giving somebody a flower is a deliberate act in
         * this app, not what a tap meaning "nice" should cost.
         *
         * Each of these posts its emoji as a reply to the photo on screen,
         * in the background, without opening anything.
         *
         * Only shown alongside a live day photo: with the fallback glyph
         * there is nothing being reacted *to*.
         */
        fun renderReactions(context: Context, views: RemoteViews, hasPhoto: Boolean) {
            if (!hasPhoto) {
                views.setViewVisibility(R.id.widget_reply_bar, View.GONE)
                return
            }
            views.setViewVisibility(R.id.widget_reply_bar, View.VISIBLE)

            REACTIONS.forEach { (viewId, reactionId) ->
                views.setOnClickPendingIntent(
                    viewId,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        // The id travels, never the emoji: a URI is at the
                        // mercy of whoever percent-encodes it on the way to
                        // the isolate, and ascii cannot be mangled.
                        //
                        // Distinct data is also what keeps these five
                        // PendingIntents apart - the plugin builds them all
                        // with request code 0, and Intent.filterEquals
                        // compares data.
                        Uri.parse("dayflower://react?r=" + reactionId),
                    ),
                )
            }
        }

        /**
         * WARNING: mirrors DayReaction.values in
         * lib/features/tulip/domain/day_reactions.dart, which is the source
         * of truth for what each id means. An id sent from here that Dart
         * does not recognise is dropped there rather than posted.
         */
        private val REACTIONS = listOf(
            R.id.widget_react_heart to "heart",
            R.id.widget_react_like to "like",
            R.id.widget_react_flower to "flower",
            R.id.widget_react_sad to "sad",
            R.id.widget_react_haha to "haha",
        )

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

        /** Matches @drawable/widget_background's corner radius. */
        private const val CORNER_DP = 34f

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
                // scales it up, and the baked radius scales with it. A 34dp
                // corner cut into a 540-wide bitmap shown in a 1080-wide
                // widget lands at 68dp - twice as round as the card behind
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
        fun renderPhotos(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
            photos: List<Bitmap>,
        ) {
            if (photos.isEmpty()) {
                views.setViewVisibility(R.id.widget_photo_still, View.GONE)
                views.setViewVisibility(R.id.widget_flipper, View.GONE)
                return
            }

            val seconds = widgetData.getInt("widget_rotate_seconds", 0)
            val rotating = seconds > 0 && photos.size > 1

            // Emptied either way. A flipper left holding last sync's bitmaps
            // is a flipper still holding that memory, and the children would
            // reappear the moment rotation came back on.
            views.removeAllViews(R.id.widget_flipper)

            if (!rotating) {
                views.setImageViewBitmap(R.id.widget_photo_still, photos.first())
                views.setViewVisibility(R.id.widget_photo_still, View.VISIBLE)
                views.setViewVisibility(R.id.widget_flipper, View.GONE)
                return
            }

            for (bitmap in photos.take(MAX_ROTATION)) {
                val item = RemoteViews(context.packageName, R.layout.widget_photo_item)
                item.setImageViewBitmap(R.id.widget_photo, bitmap)
                views.addView(R.id.widget_flipper, item)
            }
            views.setInt(R.id.widget_flipper, "setFlipInterval", seconds * 1000)
            views.setViewVisibility(R.id.widget_flipper, View.VISIBLE)
            views.setViewVisibility(R.id.widget_photo_still, View.GONE)
        }

        /**
         * Every cached day photo, newest first.
         *
         * Dart writes them as a newline-separated list under one key rather
         * than five: the count changes, and five keys would need clearing
         * individually every time it shrank.
         */
        fun loadDayPhotos(widgetData: SharedPreferences): List<Bitmap> {
            val expiresAt = widgetData.getLong("day_photo_expires_at", 0L)
            if (expiresAt > 0L && System.currentTimeMillis() >= expiresAt) {
                return emptyList()
            }
            val joined = widgetData.getString("day_photo_paths", "") ?: ""
            val paths = joined.split("\n").filter { it.isNotBlank() }
            if (paths.isEmpty()) {
                // Older data, written before rotation existed.
                return listOfNotNull(loadDayPhoto(widgetData))
            }
            return paths.take(MAX_ROTATION).mapNotNull { decodePhoto(it) }
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
        private fun setTextOrHide(views: RemoteViews, viewId: Int, text: String?) {
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
                timeLeftLabel(widgetData.getLong("day_photo_expires_at", 0L)),
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

        fun loadDayPhoto(widgetData: SharedPreferences): Bitmap? {
            val path = widgetData.getString("day_photo_path", "") ?: ""
            if (path.isEmpty()) return null

            // Self-expiry. The widget refreshes every 30 min, so the photo
            // leaves the home screen within half an hour of its 24h mark
            // even if the app is never opened again — which is the only way
            // the "lasts a day" promise actually holds.
            val expiresAt = widgetData.getLong("day_photo_expires_at", 0L)
            if (expiresAt > 0L && System.currentTimeMillis() >= expiresAt) {
                return null
            }

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
