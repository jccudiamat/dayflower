package com.dayflower.app

import com.dayflower.calls.ActiveCallService
import android.app.KeyguardManager
import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.PowerManager
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
    private var callChannel: MethodChannel? = null
    private var screenshotChannel: MethodChannel? = null

    /** A screenshot taken while the app is in front - see ScreenshotWatcher. */
    private val screenshots = ScreenshotWatcher(this) {
        screenshotChannel?.invokeMethod("taken", null)
    }

    /**
     * An Answer or Decline tapped while the app was dead.
     *
     * WARNING: the notification can be tapped before there is a Flutter
     * engine to tell. Without parking it, answering a call from the lock
     * screen on a cold start opened the app and did nothing.
     */
    private var pendingCallAction: Pair<String, String>? = null

    /**
     * Whether Dart has said it is listening for [pendingCallAction]s.
     *
     * 🔴 An engine existing is not Dart listening. A tap on Answer with the
     * app closed launches us, configureFlutterEngine builds the channel, and
     * the tap was sent down it at once - before main() had run far enough to
     * register a handler. Flutter drops a call nobody handles, so answering
     * from a closed app opened it and answered nothing. Held until Dart asks
     * with "callActionsReady" now.
     */
    private var dartListening = false

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

        // Sticking one reminder on the home screen. Its own channel for the
        // same reason as the others: requestPinAppWidget is a method on
        // AppWidgetManager, so it cannot be reached from Dart, and
        // home_widget can write a widget's data but cannot ask a launcher to
        // create one. See StickyNoteWidget.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STICKY_NOTE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pin" -> {
                        val note = call.arguments as? Map<String, Any?>
                        if (note == null) {
                            result.error("bad_args", "expected a note map", null)
                        } else {
                            result.success(
                                StickyNoteWidget.pin(applicationContext, note),
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Whether a person is actually here, for the chat header's "Active
        // now". Its own channel because it has nothing to do with calls --
        // see DevicePresence.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRESENCE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceAwake" -> result.success(deviceAwake())
                    else -> result.notImplemented()
                }
            }

        // The incoming call - see CallNotification. Also where Dart collects
        // an Answer or Decline tapped before it was listening.
        dartListening = false
        callChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CallNotification.CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "callActionsReady" -> {
                        dartListening = true
                        val held = pendingCallAction
                        pendingCallAction = null
                        result.success(
                            held?.let { mapOf("action" to it.first, "callId" to it.second) },
                        )
                    }
                    // 🔴 This channel shares its name with the
                    // dayflower_calls plugin's, and registering it here
                    // replaced the plugin's handler in this engine. The
                    // plugin was what started the in-call foreground service
                    // - so once this existed, startActive and stopActive fell
                    // through to notImplemented and a call in the background
                    // ran with nothing keeping its microphone alive. Handled
                    // here now, with the plugin's own service.
                    "startActive" -> {
                        val service = Intent(applicationContext, ActiveCallService::class.java)
                            .putExtra("video", call.argument<Boolean>("video") == true)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            applicationContext.startForegroundService(service)
                        } else {
                            applicationContext.startService(service)
                        }
                        result.success(null)
                    }
                    "stopActive" -> {
                        applicationContext.stopService(
                            Intent(applicationContext, ActiveCallService::class.java),
                        )
                        result.success(null)
                    }
                    else -> CallNotification.handle(applicationContext, call, result)
                }
            }
        }
        // The intent that launched us may itself be an Answer. Parked until
        // Dart says it is listening.
        readCallAction(intent)

        // One-way: a screenshot was just taken. Dart offers to report it.
        screenshotChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ScreenshotWatcher.CHANNEL)

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
                    // 5:7, matching callTileSize in call_pip.dart - the
                    // self-view, the window that floats inside the app and
                    // this one are the same object to whoever is holding
                    // the phone.
                    //
                    // WARNING: this was 9:16, a sliver down the edge of the
                    // launcher, and briefly 4:3, which was landscape and
                    // disagreed with the portrait content inside it.
                    .setAspectRatio(Rational(5, 7))
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
     * Screen on, and nothing in front of the app.
     *
     * WARNING: this Activity is showWhenLocked, so "resumed" is not the same
     * as "somebody is using it". A ringing reminder or an incoming call
     * launches it with a full-screen intent over the lock screen, on a phone
     * on a bedside table - and without this the app would beat, and tell the
     * caller their partner had just become active. Calling somebody must not
     * be what makes them look present.
     *
     * isInteractive alone is not enough: the full-screen intent turns the
     * screen on itself (turnScreenOn, above), so it would be true by the
     * time this is asked. The keyguard is the half that says nobody has
     * arrived yet.
     *
     * ! A phone with no lock screen at all has no keyguard to be showing, so
     *   an alarm can still produce one beat there. Fixing that properly
     *   means the ring screens telling Dart they are unanswered; this covers
     *   every phone that locks.
     */
    private fun deviceAwake(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        // A device that will not answer is not evidence of absence. Same
        // fail-open rule as the Dart side.
        if (power == null || keyguard == null) return true
        return power.isInteractive && !keyguard.isKeyguardLocked
    }

    /**
     * The Answer or Decline button on the call notification.
     *
     * WARNING: these arrive as Activity intents, not as notification
     * actions the Flutter plugin knows about - CallNotification builds its
     * own PendingIntents, because CallStyle's buttons are its own. Both
     * land here, and Dart does the rest so that answering from the lock
     * screen and answering from the ring screen are the same code path.
     */
    override fun onStart() {
        super.onStart()
        screenshots.start()
    }

    override fun onStop() {
        screenshots.stop()
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readCallAction(intent)
    }

    private fun readCallAction(intent: Intent?) {
        val action = intent?.getStringExtra(CallNotification.EXTRA_ACTION)
            ?: return
        val id = intent.getStringExtra(CallNotification.EXTRA_ID) ?: return
        // Cleared so a rotation or a resume does not answer the call twice.
        intent.removeExtra(CallNotification.EXTRA_ACTION)
        intent.removeExtra(CallNotification.EXTRA_ID)
        // Answered or declined: the ringtone stops now, not when Dart gets
        // round to it. On a cold start that is seconds of an insistent ring
        // after the person has already picked up. "open" decides nothing, so
        // it keeps ringing until the ring screen takes the banner down.
        if (action == CallNotification.ACTION_ANSWER ||
            action == CallNotification.ACTION_DECLINE
        ) {
            CallNotification.stop(applicationContext)
        }
        deliverCallAction(action, id)
    }

    private fun deliverCallAction(action: String, id: String) {
        val sink = callChannel
        if (sink == null || !dartListening) {
            pendingCallAction = action to id
            return
        }
        sink.invokeMethod("callAction", mapOf("action" to action, "callId" to id))
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
     * Back goes to Flutter, always. Dart decides what it means.
     *
     * WARNING: this used to read `if (callActive && enterPip()) return`
     * before calling super, with a comment claiming it was only reached
     * once Flutter had nothing left to pop. That was exactly backwards.
     * super.onBackPressed() is FlutterActivity's, and calling it is what
     * hands the press to Dart - so checking first meant Flutter never saw
     * a back press at all while a call was up. Every press went straight
     * out to a floating window over the launcher: the call screen never
     * popped, the conversation never came back, the app simply left.
     *
     * The routing lives in Dart, which is the half that knows what is on
     * screen. When Dart decides a press would leave the app while a call
     * is live, it asks for PiP itself through the "enter" method above.
     *
     * onUserLeaveHint still covers Home and recents, which never reach
     * here.
     */
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        super.onBackPressed()
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
        private const val PRESENCE_CHANNEL = "dayflower/presence"
        private const val STICKY_NOTE_CHANNEL = "dayflower/sticky_note"
    }
}
