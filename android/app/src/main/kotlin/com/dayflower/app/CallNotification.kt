package com.dayflower.app

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


/**
 * Re-posts the incoming call as a CallStyle notification: the caller's face
 * and name, and two round buttons in the app's own colours.
 *
 * WARNING: this REPLACES a notification Dart has already posted, using the
 * same id and channel, and that ordering is deliberate. flutter_local_
 * notifications raises the ring first and it works; this upgrades it in
 * place afterwards. If anything here throws, the plugin's notification is
 * still sitting there with its Answer and Decline actions, and the call
 * still rings. A prettier notification is not worth a missed call.
 *
 * WARNING: the plugin cannot do this itself. Its AndroidNotificationStyle is
 * bigPicture, bigText, inbox, messaging and media - CallStyle is not in it,
 * which is why this is Kotlin. See CallAlerts.styleIncoming.
 *
 * The buttons are NOT the usual green and red. setAnswerButtonColorHint and
 * setDeclineButtonColorHint take the app's own answer purple and end-call
 * pink, so the notification matches the screen it opens.
 */
object CallNotification {

    const val CHANNEL = "dayflower/native_calls"

    /** Same id Dart posts the ring under, so this replaces rather than adds. */
    private const val NOTIFICATION_ID = 4501

    const val EXTRA_ACTION = "dayflower.call.action"
    const val EXTRA_ID = "dayflower.call.id"
    const val ACTION_ANSWER = "answer"
    const val ACTION_DECLINE = "decline"

    /**
     * Why the last attempt did or did not replace the notification.
     *
     * WARNING: every failure path here is silent by design - the fallback is
     * "leave Dart's working notification alone" - which already hid a real
     * bug once, where an ARGB colour arrived as a Long and the whole feature
     * did nothing on every call while looking exactly like it had not been
     * built. This is how that gets noticed next time.
     */
    @Volatile
    var lastStatus: String = "not attempted"
        private set

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "styleIncoming" -> result.success(styleIncoming(context, call))
            "callStyleStatus" -> result.success(lastStatus)
            else -> result.notImplemented()
        }
    }

    /**
     * True when the notification was replaced. False is not an error - Dart's
     * own notification is still on screen, which is the point.
     */
    private fun styleIncoming(context: Context, call: MethodCall): Boolean {
        // WARNING: no API gate any more. This used CallStyle, which needs
        // 31 and whose button colours an OEM shade may ignore - ColorOS
        // does. RemoteViews are inflated by the system rather than
        // substituted, so the buttons are ours, and they have worked since
        // long before 31.

        val name = call.argument<String>("name")
        val callId = call.argument<String>("callId")
        val channelId = call.argument<String>("channelId")
        if (name == null || callId == null || channelId == null) {
            lastStatus = "bad args: name/callId/channelId"
            return false
        }
        val avatar = call.argument<ByteArray>("avatar")
        // WARNING: Number, not Int. An ARGB colour with full alpha is above
        // 2^31 - 0xFF906FE8 is 4,287,655,912 - so Dart sends it as a 64-bit
        // Long and argument<Int>() comes back null. Read as Int, this
        // returned false on every call and the notification was never
        // replaced: the whole feature shipped doing nothing, silently,
        // because the failure path is "leave Dart's notification alone".
        val answerColor = call.argument<Number>("answerColor")?.toInt()
        val declineColor = call.argument<Number>("declineColor")?.toInt()
        if (answerColor == null || declineColor == null) {
            lastStatus = "bad args: colours"
            return false
        }

        return try {
            // WARNING: decoded up front so the status can say whether the
            // face actually became a bitmap. "avatar=true" only ever meant
            // "bytes arrived", and a green circle with a letter in it is
            // exactly what Android draws when a Person has no icon - which
            // is indistinguishable from bytes that failed to decode.
            val bitmap = avatar?.let { decode(it) }
            val views = RemoteViews(context.packageName, R.layout.call_notification)
            views.setTextViewText(R.id.call_name, name)
            views.setTextViewText(
                R.id.call_subtitle,
                call.argument<String>("subtitle") ?: "Incoming call",
            )
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.call_avatar, circle(bitmap))
            } else {
                views.setImageViewResource(R.id.call_avatar, R.mipmap.ic_launcher)
            }
            // The colours are baked into the two pill drawables; these only
            // have to agree with them. Set anyway so a future change in Dart
            // is not silently ignored by a drawable nobody remembered.
            views.setInt(R.id.call_answer, "setBackgroundColor", answerColor)
            views.setInt(R.id.call_decline, "setBackgroundColor", declineColor)
            views.setOnClickPendingIntent(
                R.id.call_answer,
                pendingIntent(context, callId, ACTION_ANSWER),
            )
            views.setOnClickPendingIntent(
                R.id.call_decline,
                pendingIntent(context, callId, ACTION_DECLINE),
            )

            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                // WARNING: custom views instead of CallStyle. CallStyle's
                // button colours are hints and ColorOS ignores them, drawing
                // plain green text actions whatever they are set to. The
                // system inflates these views rather than substituting its
                // own, which is the only way the buttons are actually ours.
                // WARNING: bare custom views, no DecoratedCustomViewStyle.
                // The decorated style wraps our layout in the platform's own
                // chrome and falls back to the standard template if anything
                // about the custom view displeases it - which is
                // indistinguishable, from the outside, from our layout never
                // being used. Bare is the literal "draw this".
                .setCustomContentView(views)
                .setCustomBigContentView(views)
                .setCustomHeadsUpContentView(views)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                // Not swipeable. A ringing call you can flick away is a call
                // you never knew about.
                .setOngoing(true)
                .setAutoCancel(false)
                .setFullScreenIntent(
                    pendingIntent(context, callId, ACTION_ANSWER),
                    true,
                )
                .build()
                .apply { flags = flags or Notification.FLAG_INSISTENT }

            val manager = context.getSystemService(NotificationManager::class.java)
            // WARNING: the plugin's notification is cancelled by hand first.
            // Posting the same id is supposed to replace it, and that
            // assumes the plugin posts without a tag. If it does not, its
            // notification is a different one that ours never replaced -
            // which would look exactly like ours never being drawn.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                manager?.activeNotifications
                    ?.filter { it.id == NOTIFICATION_ID }
                    ?.forEach { manager.cancel(it.tag, it.id) }
            }
            NotificationManagerCompat.from(context)
                .notify(NOTIFICATION_ID, notification)
            // WARNING: posting is not the same as rendering. CallStyle needs
            // a full-screen intent or a foreground service to be shown as a
            // call, and on Android 14 the full-screen permission is not
            // granted to an app that is not a dialler unless the user turns
            // it on. Reported so that "posted but looks ordinary" is
            // distinguishable from "never posted".
            val fsi = if (Build.VERSION.SDK_INT >= 34) {
                context.getSystemService(NotificationManager::class.java)
                    ?.canUseFullScreenIntent() ?: false
            } else {
                true
            }
            val face = when {
                avatar == null -> "no avatar sent"
                bitmap == null -> "avatar sent but would not decode"
                else -> "avatar ${bitmap.width}x${bitmap.height}"
            }
            // What is actually in the shade, rather than what we asked for.
            val live = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                manager?.activeNotifications
                    ?.joinToString(",") { "${it.id}${it.tag?.let { t -> "/$t" } ?: ""}" }
                    ?: "?"
            } else {
                "?"
            }
            lastStatus = buildString {
                append(if (fsi) "posted" else "posted, no full-screen permission")
                append(", ").append(face)
                append(", custom views, shade=[").append(live).append("]")
            }
            true
        } catch (e: Throwable) {
            // Missing POST_NOTIFICATIONS, a channel that does not exist, a
            // ByteArray that is not an image, CallStyle missing from an old
            // androidx.core. Dart's notification stays.
            lastStatus = "failed: ${e.javaClass.simpleName}: ${e.message}"
            false
        }
    }

    /**
     * WARNING: distinct request codes per action, or the second
     * PendingIntent silently reuses the first one's extras and Decline
     * answers the call.
     */
    private fun pendingIntent(
        context: Context,
        callId: String,
        action: String,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction("$action:$callId")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EXTRA_ACTION, action)
            .putExtra(EXTRA_ID, callId)
        return PendingIntent.getActivity(
            context,
            if (action == ACTION_ANSWER) 1 else 2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * A round face.
     *
     * WARNING: done to the bitmap, not with a clip. RemoteViews cannot round
     * an ImageView - there is no outline provider across the process
     * boundary - so a square photo stays square however the layout is
     * written.
     */
    private fun circle(source: Bitmap): Bitmap {
        val size = minOf(source.width, source.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint().apply { isAntiAlias = true }
        val rect = Rect(0, 0, size, size)
        val radius = size / 2f
        canvas.drawCircle(radius, radius, radius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        // Centre-cropped: a portrait squashed into a square is a wide face.
        val left = (source.width - size) / 2
        val top = (source.height - size) / 2
        canvas.drawBitmap(source, Rect(left, top, left + size, top + size), rect, paint)
        return output
    }

    private fun decode(bytes: ByteArray): Bitmap? = try {
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    } catch (e: Throwable) {
        null
    }
}
