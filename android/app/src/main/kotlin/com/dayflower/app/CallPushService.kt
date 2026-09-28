package com.dayflower.app

import android.content.Context
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Rings for an incoming call the moment its push arrives.
 *
 * 🔴 **Before Flutter, not through it.** The plugin hands every message to a
 * background Dart isolate, which has to boot an engine first and, having no
 * Activity, cannot reach [CallNotification]. So a call to a closed app rang
 * late and plain: a letter for a face, no buttons. This runs in the app's
 * process as soon as FCM delivers, with nothing to start up, and posts the
 * real notification straight away. The Dart isolate still runs afterwards
 * and finds the call already claimed - see CallAlerts.ring.
 *
 * WARNING: a subclass of the plugin's own service, swapped in for it in the
 * manifest (tools:node="remove" on the original). The plugin's version
 * ignores onMessageReceived - its receiver does the work - and keeps
 * onNewToken, which this inherits untouched. Every non-call message passes
 * straight through to super, so nothing else changes.
 */
class CallPushService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        try {
            ringIfCall(applicationContext, remoteMessage.data, remoteMessage.sentTime)
        } catch (_: Throwable) {
            // Never let a bad payload take the service down: the Dart side
            // will still ring the plain way.
        }
        super.onMessageReceived(remoteMessage)
    }

    companion object {
        /**
         * The push's data map, as supabase/functions/push sends it: kind,
         * title (the caller's name), messageId (the call's row), callMode.
         * Mirrors PushMessage.isActionableCall in Dart.
         */
        fun ringIfCall(context: Context, data: Map<String, String>, sentAt: Long = 0): String? {
            if (data["kind"] != "call") return null
            val callId = data["messageId"]?.takeIf { it.isNotBlank() } ?: return null
            // ⚠️ FCM can deliver late, minutes late on a phone deep in Doze.
            // A push for a call that has long since rung out is not a call.
            val age = System.currentTimeMillis() - sentAt
            if (sentAt > 0 && age > CallNotification.STALE_PUSH_MS) {
                return CallNotification.refuse(context, callId, "push ${age / 1000}s late")
            }
            val name = data["title"]?.trim()?.takeIf { it.isNotEmpty() } ?: "Dayflower"
            val video = data["callMode"] == "video"
            return CallNotification.ring(
                context,
                callId = callId,
                name = name,
                // Short, beside the round buttons. Same words as CallAlerts.
                subtitle = if (video) "Video call" else "Voice call",
                avatar = null,
                source = "push",
            )
        }
    }
}
