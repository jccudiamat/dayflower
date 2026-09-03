package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
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
            renderFlower(context, views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        /** Shared with DayflowerWidget so the adaptive variant renders identically. */
        fun renderFlower(
            context: Context,
            views: RemoteViews,
            widgetData: SharedPreferences,
        ) {
            // A day photo takes the slot when there is a live one; otherwise
            // the flower glyph does. Never both.
            val photo = loadDayPhoto(widgetData)
            if (photo != null) {
                views.setImageViewBitmap(R.id.widget_photo, photo)
                views.setViewVisibility(R.id.widget_photo, View.VISIBLE)
                views.setViewVisibility(R.id.widget_emoji, View.GONE)
                renderStoryHeader(views, widgetData)
            } else {
                views.setViewVisibility(R.id.widget_photo, View.GONE)
                views.setViewVisibility(R.id.widget_emoji, View.VISIBLE)
                // A name and a countdown over the fallback glyph would be
                // describing a photo that is not there.
                views.setViewVisibility(R.id.widget_header, View.GONE)
            }

            views.setTextViewText(
                R.id.widget_emoji,
                widgetData.getString("tulip_emoji", "🌷"),
            )
            views.setTextViewText(
                R.id.widget_title,
                widgetData.getString("tulip_title", "No flower yet today"),
            )
            views.setTextViewText(
                R.id.widget_body,
                widgetData.getString("tulip_body", "Tap to send yours first."),
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dayflower://flowers"),
                ),
            )

            renderReplyBar(context, views, photo != null)
        }

        /**
         * The story-style reply bar under the caption.
         *
         * Only shown alongside a live day photo: with the fallback glyph
         * there is nothing being replied *to*, and a reply bar over it would
         * be offering to answer a picture that isn't there.
         *
         * ⚠️ The two halves are deliberately different kinds of action. The
         * pill **launches the app** — a widget cannot host a text field, so
         * the honest version of "send message" is a door to the place that
         * can take one. The tulip is a **background action**, the same shape
         * as the heartbeat widget's tap: a one-tap reaction that costs an
         * app launch is not a one-tap reaction.
         */
        fun renderReplyBar(context: Context, views: RemoteViews, hasPhoto: Boolean) {
            if (!hasPhoto) {
                views.setViewVisibility(R.id.widget_reply_bar, View.GONE)
                return
            }
            views.setViewVisibility(R.id.widget_reply_bar, View.VISIBLE)

            views.setOnClickPendingIntent(
                R.id.widget_reply_pill,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dayflower://chat"),
                ),
            )
            views.setOnClickPendingIntent(
                R.id.widget_reply_tulip,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("dayflower://tulip"),
                ),
            )
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
        /**
         * Story header — avatar, whose day it is, and the time remaining.
         *
         * The countdown is computed here rather than pushed from Dart for the
         * same reason expiry is: the widget outlives the app process, so a
         * "16h" written at sync time would still read 16h tomorrow.
         */
        fun renderStoryHeader(views: RemoteViews, widgetData: SharedPreferences) {
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
