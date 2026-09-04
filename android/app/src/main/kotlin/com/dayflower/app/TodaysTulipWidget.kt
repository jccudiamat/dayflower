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
import android.os.Bundle
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
            val views = RemoteViews(context.packageName, R.layout.todays_tulip_widget)
            renderFlower(
                context,
                views,
                widgetData,
                appWidgetManager.getAppWidgetOptions(widgetId),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        /** Shared with DayflowerWidget so the adaptive variant renders identically. */
        fun renderFlower(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
            options: Bundle? = null,
        ) {
            // A day photo takes the slot when there is a live one; otherwise
            // the flower glyph does. Never both.
            val photo = loadDayPhoto(widgetData)?.let { roundCorners(context, it, options) }
            if (photo != null) {
                views.setImageViewBitmap(R.id.widget_photo, photo)
                views.setViewVisibility(R.id.widget_photo, View.VISIBLE)
                views.setViewVisibility(R.id.widget_emoji, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_photo, View.GONE)
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
            setTextOrHide(views, R.id.widget_body, widgetData.getString("tulip_body", ""))

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dayflower://flowers"),
                ),
            )

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

        /** Matches @drawable/widget_background's corner radius. */
        private const val CORNER_DP = 28f

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
                // Never upscale past the source: a widget wider than the
                // cached photo would cost memory for no extra detail, and
                // RemoteViews has a hard bitmap budget.
                if (outW > src.width) {
                    outH = outH * src.width / outW
                    outW = src.width
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
                val radius = CORNER_DP * density
                val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                // Draw the rounded shape, then paint the photo only where it
                // already is. A mask rather than a clipPath because
                // clipPath is not antialiased and leaves stepped corners.
                paint.color = 0xFF000000.toInt()
                canvas.drawRoundRect(
                    RectF(0f, 0f, outW.toFloat(), outH.toFloat()),
                    radius,
                    radius,
                    paint,
                )
                paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
                canvas.drawBitmap(src, srcRect, Rect(0, 0, outW, outH), paint)
                out
            } catch (e: Throwable) {
                // Out of memory, a recycled bitmap, anything: a square photo
                // is a cosmetic problem, a blank widget is not.
                src
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
