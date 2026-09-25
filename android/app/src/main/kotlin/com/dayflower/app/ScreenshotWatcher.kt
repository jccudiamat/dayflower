package com.dayflower.app

import android.app.Activity
import android.content.ContentResolver
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.MediaStore

/**
 * Tells Dart that a screenshot was just taken, while Dayflower is on screen,
 * so it can offer to send it as a bug report. See
 * lib/features/feedback/presentation/screenshot_report.dart.
 *
 * Nothing here reads the screenshot. Dart captures its own screen instead,
 * which is the same picture without asking for access to the gallery.
 *
 * Two ways to know, by Android version:
 *
 * - **14 and up:** registerScreenCaptureCallback, which is exactly this
 *   event and nothing else. Needs DETECT_SCREEN_CAPTURE, an install-time
 *   permission with no prompt.
 * - **Below 14** there is no such event. The nearest thing is a new picture
 *   arriving in MediaStore while the app is in front, which is what a
 *   screenshot is. It can also be something else saving a picture at the
 *   same moment, so the Dart side offers rather than assumes, and our own
 *   saves (MediaSaver) are skipped.
 */
class ScreenshotWatcher(
    private val activity: Activity,
    private val onScreenshot: () -> Unit,
) {
    companion object {
        const val CHANNEL = "dayflower/screenshots"

        /** One screenshot is several MediaStore changes; this is one event. */
        private const val QUIET_MS = 3000L

        /** How long after our own save a new picture is ours, not a screenshot. */
        private const val OWN_SAVE_MS = 5000L
    }

    private var captureCallback: Any? = null
    private var observer: ContentObserver? = null
    private var lastAt = 0L

    /** From onStart: only while the app can be seen. */
    fun start() {
        if (Build.VERSION.SDK_INT >= 34) {
            if (captureCallback != null) return
            val callback = Activity.ScreenCaptureCallback { report() }
            try {
                activity.registerScreenCaptureCallback(activity.mainExecutor, callback)
                captureCallback = callback
            } catch (e: SecurityException) {
                // The permission is in the manifest; a build without it simply
                // never offers.
            }
            return
        }
        if (observer != null) return
        val watching = object : ContentObserver(Handler(Looper.getMainLooper())) {
            // API 30+: only an insert is a new picture. An edit or a delete
            // in somebody's gallery is not.
            override fun onChange(selfChange: Boolean, uris: Collection<Uri>, flags: Int) {
                if (flags and ContentResolver.NOTIFY_INSERT != 0) report()
            }

            // Below 30 there is no telling an insert from an edit, and the
            // quiet window folds a screenshot's several changes into one.
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                if (Build.VERSION.SDK_INT < 30) report()
            }
        }
        try {
            activity.contentResolver.registerContentObserver(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                true,
                watching,
            )
            observer = watching
        } catch (e: SecurityException) {
            // Some OEM builds refuse; no offer is the right failure.
        }
    }

    /** From onStop. */
    fun stop() {
        if (Build.VERSION.SDK_INT >= 34) {
            val callback = captureCallback as? Activity.ScreenCaptureCallback
            if (callback != null) {
                try {
                    activity.unregisterScreenCaptureCallback(callback)
                } catch (e: Exception) {
                }
            }
            captureCallback = null
        }
        observer?.let {
            try {
                activity.contentResolver.unregisterContentObserver(it)
            } catch (e: Exception) {
            }
        }
        observer = null
    }

    private fun report() {
        val now = SystemClock.elapsedRealtime()
        if (now - MediaSaver.lastSavedAt < OWN_SAVE_MS) return
        if (now - lastAt < QUIET_MS) return
        lastAt = now
        onScreenshot()
    }
}
