package com.dayflower.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Their chat on the home screen, the way WhatsApp puts a chat there: an
 * icon with their face (the launcher adds Dayflower's badge to it) that
 * opens the conversation. Also in the menu that opens when the app's icon is
 * held, where it can be dragged out too.
 *
 * One shortcut, [ID]. The copy on the home screen and the one in the menu
 * are the same shortcut, so publishing it again (a new photo, a new name,
 * the other account signed in) changes every copy at once.
 *
 * The icon is drawn in Dart (lib/features/tulip/data/chat_shortcut.dart) as
 * an adaptive icon's whole layer, and the launcher masks it to its shape.
 *
 * The Dart side is ChatShortcut. Its own channel, like the others in
 * MainActivity: ShortcutManager is an Android API, and a plugin for it
 * would be APK the app has no room for.
 */
object ChatShortcut {

    const val CHANNEL = "dayflower/chat_shortcut"

    private const val ID = "chat"

    /** Where a tap lands: DayflowerApp._openWidgetTarget, like a widget's. */
    private val TARGET: Uri = Uri.parse("dayflower://chat")

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        // Pinning is Android 8. A phone older than that has no way to be
        // handed a shortcut, and the one in the icon's menu would be the
        // only half; not worth a second code path for Android 7.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(if (call.method == "pin") "unsupported" else false)
            return
        }
        val manager = context.getSystemService(ShortcutManager::class.java)
        if (manager == null) {
            result.success(if (call.method == "pin") "unsupported" else false)
            return
        }
        try {
            when (call.method) {
                "publish" -> {
                    val info = info(context, call)
                    if (info == null) {
                        result.error("bad_args", "expected a name", null)
                        return
                    }
                    manager.dynamicShortcuts = listOf(info)
                    // A copy on the home screen that is no longer in the
                    // menu (rate limits, a launcher that trims the menu) is
                    // still brought up to date.
                    manager.updateShortcuts(listOf(info))
                    result.success(true)
                }
                "pin" -> {
                    val info = info(context, call)
                    if (info == null) {
                        result.error("bad_args", "expected a name", null)
                        return
                    }
                    when {
                        !manager.isRequestPinShortcutSupported ->
                            result.success("unsupported")
                        manager.pinnedShortcuts.any { it.id == ID } -> {
                            manager.updateShortcuts(listOf(info))
                            result.success("already")
                        }
                        // The launcher's own "Add to home screen" dialog.
                        // true only means it was asked: the person can
                        // still say no.
                        manager.requestPinShortcut(info, null) ->
                            result.success("asked")
                        else -> result.success("unsupported")
                    }
                }
                "clear" -> {
                    // Signed out or unpaired: out of the icon's menu. A
                    // copy on the home screen stays (only the person can
                    // take it off) and opens the app to sign in; the next
                    // partner to be published takes it over.
                    manager.removeAllDynamicShortcuts()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            // Rate limited, or the app went to the background mid-call:
            // ShortcutManager throws rather than returning for both.
            android.util.Log.e("ChatShortcut", "${call.method} failed", e)
            result.success(if (call.method == "pin") "unsupported" else false)
        }
    }

    private fun info(context: Context, call: MethodCall): ShortcutInfo? {
        val name = call.argument<String>("name")?.takeIf { it.isNotBlank() } ?: return null
        val bytes = call.argument<ByteArray>("icon")
        val bitmap = bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
        val icon = if (bitmap != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Icon.createWithAdaptiveBitmap(bitmap)
        } else {
            Icon.createWithResource(context, R.mipmap.ic_launcher)
        }
        return ShortcutInfo.Builder(context, ID)
            .setShortLabel(name)
            .setLongLabel(name)
            .setIcon(icon)
            .setIntent(
                Intent(context, ShortcutActivity::class.java)
                    .setAction(Intent.ACTION_VIEW)
                    .setData(TARGET),
            )
            .build()
    }
}

/**
 * What a chat shortcut starts, which starts the app.
 *
 * 🔴 **Not MainActivity itself.** Android launches a shortcut with
 * FLAG_ACTIVITY_CLEAR_TASK, which would destroy the running app first, and
 * the Flutter engine with it: a chat opened from the home screen mid-call
 * would hang up the call, and every open would be a cold start. This lives
 * in a task of its own (taskAffinity ""), so that task is the one cleared,
 * and it brings the app forward the way a widget's tap does, which
 * home_widget hands to Dart.
 */
class ShortcutActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
                .setData(intent?.data ?: Uri.parse("dayflower://chat"))
                // Brought forward, not started again: onNewIntent on the
                // running one, with anything over it (a photo cropper) closed.
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
        )
        finish()
    }
}
