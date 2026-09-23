package com.dayflower.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * DEBUG BUILDS ONLY - this file lives in src/debug and is not in a release
 * APK. Rings an incoming call exactly as CallPushService does for a real
 * push, so the notification can be tested on an emulator without Firebase
 * and without ringing anybody's phone:
 *
 *   adb shell am broadcast -a com.dayflower.app.DEBUG_RING \
 *     -n com.dayflower.app/.DebugCallReceiver \
 *     --es id call-1 --es name Wifey --es mode voice
 */
class DebugCallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val data = mapOf(
            "kind" to "call",
            "messageId" to (intent.getStringExtra("id") ?: "debug-call"),
            "title" to (intent.getStringExtra("name") ?: "Wifey"),
            "callMode" to (intent.getStringExtra("mode") ?: "voice"),
        )
        val result = CallPushService.ringIfCall(context, data)
        Log.i("DayflowerCall", "debug ring: $result | ${CallNotification.lastStatus}")
    }
}
