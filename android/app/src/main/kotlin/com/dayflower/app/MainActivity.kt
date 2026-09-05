package com.dayflower.app

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Picture-in-picture, so a call survives leaving the app.
 *
 * WARNING: there is no Flutter API for this and no plugin here doing it.
 * PiP is an Activity capability - enterPictureInPictureMode is a method on
 * Activity, onUserLeaveHint is an Activity callback - so it has to live in
 * Kotlin. Roughly forty lines of it, which is the reason this is not a new
 * pub dependency: the last dependency added to reach a platform feature
 * (firebase_messaging) would have broken the whole Android build.
 *
 * The Dart side is lib/features/calls/data/call_pip.dart.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null

    /**
     * Whether a call is live right now.
     *
     * WARNING: onUserLeaveHint fires for *every* exit from the app, so
     * without this the launcher button would shrink Dayflower into a
     * floating window while somebody was reading the home screen. Dart owns
     * this flag because Dart is what knows a call is up.
     */
    private var callActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Saving a picture to the gallery. Its own channel because it has
        // nothing to do with calls — see MediaSaver.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MediaSaver.CHANNEL)
            .setMethodCallHandler { call, result ->
                MediaSaver.handle(applicationContext, call, result)
            }

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "supported" -> result.success(pipSupported())
                    "setCallActive" -> {
                        callActive = call.arguments as? Boolean ?: false
                        result.success(null)
                    }
                    "enter" -> result.success(enterPip())
                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * API 26+, and only where the device actually has the feature - Android
     * Go and some tablets do not, and calling in without checking throws.
     */
    private fun pipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun enterPip(): Boolean {
        if (!pipSupported()) return false
        return try {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder()
                    // Portrait, because the call screen is. A ratio that
                    // disagrees with the content gets letterboxed by the
                    // system rather than cropped.
                    .setAspectRatio(Rational(9, 16))
                    .build(),
            )
        } catch (e: Throwable) {
            // A device that claims the feature and refuses it anyway, or a
            // state where PiP is not allowed (already finishing, locked).
            // Staying full-screen is the right failure.
            false
        }
    }

    /**
     * Home or recents while a call is live.
     *
     * This is the half of the request that is not a button: "or the app is
     * put on the background". Without it, leaving the app during a call
     * leaves the call running behind an app you cannot see.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (callActive) enterPip()
    }

    /**
     * Tells Dart to draw the compact layout.
     *
     * WARNING: a PiP window is a few hundred pixels wide and takes no
     * touches. Rendering the full call screen into it gives a wall of
     * unreadable, untappable controls, so the screen swaps to video-only
     * while this is true.
     */
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }

    companion object {
        private const val CHANNEL = "dayflower/pip"
    }
}
