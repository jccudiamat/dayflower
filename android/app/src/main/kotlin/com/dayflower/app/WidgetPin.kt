package com.dayflower.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Asks the launcher to put one of the widgets on the home screen, the way
 * the chat's shortcut is added (ChatShortcut): its own "Add to home screen"
 * dialog, rather than steps to follow through the widget tray.
 *
 * Nothing is handed over with the request: every one of these draws from
 * what the app has already synced, as it does when added from the tray. The
 * sticky note is the exception, and has its own (StickyNoteWidget.pin).
 *
 * The Dart side is WidgetPinner (lib/features/widget/widget_pinner.dart).
 */
object WidgetPin {

    const val CHANNEL = "dayflower/widget_pin"

    /** Dart's HomeWidgetKind names. */
    private fun providerFor(kind: String?): Class<*>? = when (kind) {
        "myDay" -> TodaysTulipWidget::class.java
        "heartbeat" -> HeartbeatWidget::class.java
        "reunion" -> ReunionWidget::class.java
        else -> null
    }

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pin") {
            result.notImplemented()
            return
        }
        val provider = providerFor(call.arguments as? String)
        if (provider == null) {
            result.error("bad_args", "unknown widget ${call.arguments}", null)
            return
        }
        // Android 8, and a launcher that takes requests: without either the
        // answer is false, and Dart shows the steps through the tray.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(false)
            return
        }
        try {
            val manager = AppWidgetManager.getInstance(context)
            result.success(
                manager.isRequestPinAppWidgetSupported &&
                    // true only means the launcher was asked: the person
                    // can still say no.
                    manager.requestPinAppWidget(ComponentName(context, provider), null, null),
            )
        } catch (e: Throwable) {
            // Asked from the background, or a launcher that throws instead
            // of saying no.
            android.util.Log.e("WidgetPin", "pin failed", e)
            result.success(false)
        }
    }
}
