package com.dayflower.app

import android.app.Notification
import android.app.NotificationChannel
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
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The incoming call: the caller's face and name, and two round buttons in
 * the app's own colours.
 *
 * 🔴 **Native first, and from the push itself.** This used to *restyle* a
 * notification Dart had already posted, over a method channel that only
 * exists while MainActivity is alive. A call almost always arrives with the
 * app closed, and then the ring came from FCM's background isolate, which has
 * no Activity and so no channel: every call arrived as the plugin's plain
 * notification - a letter "W" for a face and no buttons - and the styled one
 * only appeared once the app was opened, as a second notification. Now
 * [CallPushService] rings from here the moment the push lands, before any
 * Flutter engine exists, and the channel path is only for a call the app sees
 * first (over realtime, while open).
 *
 * WARNING: custom views, not CallStyle. CallStyle's button colours are hints
 * and ColorOS ignores them, drawing plain green text. The system inflates
 * these views rather than substituting its own, which is the only way the
 * buttons are actually ours.
 */
object CallNotification {

    const val CHANNEL = "dayflower/native_calls"

    /** Same id Dart's fallback posts under, so one always replaces the other. */
    private const val NOTIFICATION_ID = 4501

    /**
     * Created here too, not only in Dart. The push can be the first thing
     * this install ever runs after an update, and notify() on a channel that
     * does not exist posts nothing at all. Same id and settings as
     * CallAlerts._channelId, so whichever side creates it first, it is the
     * same channel.
     */
    const val CHANNEL_ID = "incoming_calls_v2"

    const val EXTRA_ACTION = "dayflower.call.action"
    const val EXTRA_ID = "dayflower.call.id"
    const val ACTION_ANSWER = "answer"
    const val ACTION_DECLINE = "decline"

    /** Opens the ring screen without deciding anything. */
    const val ACTION_OPEN = "open"

    /**
     * A ring nobody answers stops by itself. WARNING: the restyled
     * notification had no timeout at all - with the app closed nothing else
     * could take it down, and an unanswered call rang on in the shade.
     */
    private const val RING_MS = 60_000L

    /** How long a claim holds. A little past [RING_MS]. */
    private const val CLAIM_MS = 70_000L

    /**
     * Where Dart's CallAlerts keeps the same claim. Written from here so the
     * FCM background isolate - which rings through the plugin when it cannot
     * reach this - sees the call is already ringing and stays quiet.
     *
     * WARNING: shared_preferences' legacy store: this file, keys prefixed
     * "flutter.", ints as Longs. Change them together or not at all.
     */
    private const val PREFS = "FlutterSharedPreferences"
    private const val CLAIM_ID = "flutter.ringing_call_id"
    private const val CLAIM_AT = "flutter.ringing_call_at"

    /**
     * What is ringing in this process, whichever door it came through. The
     * push service and the Activity share a process, so this one field is
     * enough to stop a realtime row re-posting - and restarting the ringtone
     * of - a call the push already rang.
     */
    @Volatile
    private var ringing: Pair<String, Long>? = null

    /**
     * Why the last ring did or did not go up. Every failure here falls back
     * to something quieter, which has hidden a real bug before; this is
     * surfaced in Settings -> About so the next one is noticed.
     */
    @Volatile
    var lastStatus: String = "not attempted"
        private set

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ring" -> {
                val name = call.argument<String>("name")
                val callId = call.argument<String>("callId")
                if (name == null || callId == null) {
                    lastStatus = "bad args: name/callId"
                    result.success("failed")
                    return
                }
                result.success(
                    ring(
                        context,
                        callId = callId,
                        name = name,
                        subtitle = call.argument<String>("subtitle") ?: "Incoming call",
                        avatar = call.argument<ByteArray>("avatar"),
                        source = "app",
                    ),
                )
            }
            "stopRinging" -> {
                stop(context)
                result.success(null)
            }
            "callStyleStatus" -> result.success(lastStatus)
            else -> result.notImplemented()
        }
    }

    /**
     * Rings for [callId]. Returns "posted", "already" when this call is
     * ringing already, or "failed" - in which case Dart posts its plain
     * fallback, because a plain ring beats no ring.
     */
    fun ring(
        context: Context,
        callId: String,
        name: String,
        subtitle: String,
        avatar: ByteArray?,
        source: String,
    ): String {
        val now = System.currentTimeMillis()
        synchronized(this) {
            val held = ringing
            if (held != null && held.first == callId && now - held.second < CLAIM_MS) {
                return "already"
            }
            ringing = callId to now
        }
        writeClaim(context, callId, now)

        return try {
            ensureChannel(context)
            // The face the app saved when the partner's profile loaded - see
            // CallerAvatar in Dart. Read from disk when the caller did not
            // hand it over, which is always the case for a push: the process
            // may have been dead a second ago.
            val bytes = avatar ?: cachedAvatar(context)
            val bitmap = bytes?.let { decode(it) }
            val views = RemoteViews(context.packageName, R.layout.call_notification)
            views.setTextViewText(R.id.call_name, name)
            views.setTextViewText(R.id.call_subtitle, subtitle)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.call_avatar, circle(bitmap))
            } else {
                views.setImageViewResource(R.id.call_avatar, R.mipmap.ic_launcher)
            }
            // WARNING: no setBackgroundColor on the buttons. It replaces the
            // pill drawable with a flat fill, so they rendered as squares.
            // The colours live in call_answer_pill / call_decline_pill.
            views.setOnClickPendingIntent(
                R.id.call_answer,
                pendingIntent(context, callId, ACTION_ANSWER),
            )
            views.setOnClickPendingIntent(
                R.id.call_decline,
                pendingIntent(context, callId, ACTION_DECLINE),
            )

            val open = pendingIntent(context, callId, ACTION_OPEN)
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(name)
                .setContentText(subtitle)
                // WARNING: bare custom views, no DecoratedCustomViewStyle.
                // The decorated style falls back to the standard template if
                // anything about the view displeases it, which from outside
                // is indistinguishable from our layout never being used.
                .setCustomContentView(views)
                .setCustomBigContentView(views)
                .setCustomHeadsUpContentView(views)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                // Not swipeable: a ringing call you can flick away is a call
                // you never knew about. The timeout is what ends it instead.
                .setOngoing(true)
                .setAutoCancel(false)
                .setTimeoutAfter(RING_MS)
                // Tapping the card, not a button: the ring screen.
                .setContentIntent(open)
                // 🔴 **The ring screen, never Answer.** On a locked phone
                // Android fires the full-screen intent the moment this is
                // posted, with nobody touching anything. It pointed at Answer,
                // which would pick the call up on its own.
                .setFullScreenIntent(open, true)
                .build()
                .apply { flags = flags or Notification.FLAG_INSISTENT }

            val manager = context.getSystemService(NotificationManager::class.java)
            // Whatever is up under this id - the plugin's plain fallback, or
            // a stale ring - goes first, tag and all, so this one replaces it
            // rather than sitting beside it.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                manager?.activeNotifications
                    ?.filter { it.id == NOTIFICATION_ID }
                    ?.forEach { manager.cancel(it.tag, it.id) }
            }
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)

            val fsi = if (Build.VERSION.SDK_INT >= 34) {
                manager?.canUseFullScreenIntent() ?: false
            } else {
                true
            }
            val face = when {
                bytes == null -> "no avatar on disk"
                bitmap == null -> "avatar would not decode"
                else -> "avatar ${bitmap.width}x${bitmap.height}"
            }
            lastStatus = buildString {
                append("posted from ").append(source)
                if (!fsi) append(", no full-screen permission")
                append(", ").append(face)
            }
            "posted"
        } catch (e: Throwable) {
            // Missing POST_NOTIFICATIONS, a bad image, an OEM refusing the
            // view. The claim is released so Dart's fallback may ring.
            synchronized(this) { if (ringing?.first == callId) ringing = null }
            clearClaim(context)
            lastStatus = "failed from $source: ${e.javaClass.simpleName}: ${e.message}"
            "failed"
        }
    }

    /** Answered, declined, gave up, or ended elsewhere. */
    fun stop(context: Context) {
        synchronized(this) { ringing = null }
        clearClaim(context)
        try {
            NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        } catch (_: Throwable) {
        }
    }

    private fun writeClaim(context: Context, callId: String, at: Long) {
        try {
            // commit(), not apply(): the push service returns and the plugin
            // starts the Dart isolate straight after. It must see this.
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(CLAIM_ID, callId)
                .putLong(CLAIM_AT, at)
                .commit()
        } catch (_: Throwable) {
        }
    }

    private fun clearClaim(context: Context) {
        try {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .remove(CLAIM_ID)
                .remove(CLAIM_AT)
                .commit()
        } catch (_: Throwable) {
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Incoming calls",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Someone is calling you on Dayflower."
                enableVibration(true)
                setSound(
                    Uri.parse("content://settings/system/ringtone"),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    /** The file CallerAvatar in Dart writes: getApplicationSupportDirectory. */
    private fun cachedAvatar(context: Context): ByteArray? = try {
        val file = File(context.filesDir, "caller_avatar")
        if (file.exists() && file.length() > 0) file.readBytes() else null
    } catch (_: Throwable) {
        null
    }

    /**
     * WARNING: distinct request codes per action, or a later PendingIntent
     * silently reuses an earlier one's extras and Decline answers the call.
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
        val code = when (action) {
            ACTION_ANSWER -> 1
            ACTION_DECLINE -> 2
            else -> 3
        }
        return PendingIntent.getActivity(
            context,
            code,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * A round face. WARNING: done to the bitmap - RemoteViews cannot clip an
     * ImageView across the process boundary.
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
        val left = (source.width - size) / 2
        val top = (source.height - size) / 2
        canvas.drawBitmap(source, Rect(left, top, left + size, top + size), rect, paint)
        return output
    }

    /**
     * Downsampled on the way in: a profile photo can be several megapixels,
     * and a notification's views travel to the system process in one
     * parcel. The avatar is drawn at 48dp.
     */
    private fun decode(bytes: ByteArray): Bitmap? = try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 256) sample *= 2
        BitmapFactory.decodeByteArray(
            bytes, 0, bytes.size,
            BitmapFactory.Options().apply { inSampleSize = sample },
        )
    } catch (e: Throwable) {
        null
    }
}
