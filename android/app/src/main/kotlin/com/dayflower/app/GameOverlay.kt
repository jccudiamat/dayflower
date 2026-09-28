package com.dayflower.app

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.SurfaceTexture
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.TextureView
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.utils.EglUtils
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.hypot
import org.webrtc.EglBase
import org.webrtc.EglRenderer
import org.webrtc.GlRectDrawer
import org.webrtc.VideoTrack

/**
 * Game mode: the call as a small circle floating over other apps.
 *
 * Their face in a circle, over whatever game the two of you are playing,
 * while their voice carries on. Tap it to come back to the call; drag it
 * anywhere, and it settles against the nearer side.
 *
 * WARNING: not picture-in-picture. A PiP window is a rounded rectangle whose
 * size the system chooses, and it is the size of a small video. This is a
 * window of our own, drawn over other apps, which is the only way to a small
 * circle - and why it needs "Display over other apps", granted once in
 * Settings (see [canDraw] and "requestPermission").
 *
 * WARNING: the video is drawn here, natively, not by Flutter. With the app
 * in the background Flutter draws nothing at all, so the picture comes
 * straight from the WebRTC track that flutter_webrtc is already receiving:
 * the same frames, a second sink. That is why this module compiles against
 * org.webrtc (see build.gradle.kts) and reaches into FlutterWebRTCPlugin.
 *
 * 🔴 **The main engine's plugin, never FlutterWebRTCPlugin.sharedSingleton.**
 * The first build asked the singleton for the track and the circle only ever
 * showed their face. The plugin's constructor writes that field, and every
 * Flutter engine constructs its own: the FCM background isolate's engine,
 * which starts as soon as the app does, and the home-screen widget's. The
 * last engine up wins, it has no call in it, and the track is "not found".
 * The plugin is looked up in MainActivity's own engine instead (see
 * [webrtcOf]), which is the one holding the call.
 *
 * The Dart side is lib/features/calls/data/game_mode.dart.
 */
object GameOverlay {
    const val CHANNEL = "dayflower/game_mode"
    private const val TAG = "GameOverlay"

    /** Their face, in dp. Small enough to keep out of a game's way. */
    private const val DIAMETER = 96

    /** From the screen's edge, in dp. */
    private const val MARGIN = 10

    private var root: FrameLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var ring: GradientDrawable? = null
    private var renderer: EglRenderer? = null
    private var track: VideoTrack? = null
    private var trackId: String? = null

    /** flutter_webrtc in the engine that holds the call. See [webrtcOf]. */
    private var webrtc: FlutterWebRTCPlugin? = null

    /** Why the circle is or is not showing video, for the log. */
    @Volatile
    var lastStatus: String = "not started"
        private set

    val showing: Boolean get() = root != null

    /**
     * The flutter_webrtc plugin registered with [engine], MainActivity's.
     * sharedSingleton only as a last resort: it belongs to whichever engine
     * started last (see the class comment).
     */
    private fun webrtcOf(engine: FlutterEngine): FlutterWebRTCPlugin? =
        (engine.plugins.get(FlutterWebRTCPlugin::class.java) as? FlutterWebRTCPlugin)
            ?: FlutterWebRTCPlugin.sharedSingleton

    fun handle(
        activity: MainActivity,
        engine: FlutterEngine,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        webrtcOf(engine)?.let { webrtc = it }
        when (call.method) {
            "supported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            "canDraw" -> result.success(canDraw(activity))
            "requestPermission" -> {
                try {
                    activity.startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${activity.packageName}"),
                        ),
                    )
                    result.success(true)
                } catch (e: Throwable) {
                    // A phone with no such screen (Android Go refuses
                    // overlays outright).
                    result.success(false)
                }
            }
            "start" -> {
                val shown = show(
                    activity.applicationContext,
                    call.argument<String>("trackId"),
                    call.argument<Boolean>("speaking") == true,
                )
                // Out of the way, to the launcher or the game underneath.
                // moveTaskToBack, not onUserLeaveHint: this is not the user
                // leaving, so it does not float the picture-in-picture
                // window as well.
                if (shown) activity.moveTaskToBack(true)
                result.success(shown)
            }
            "update" -> {
                update(
                    call.argument<String>("trackId"),
                    call.argument<Boolean>("speaking") == true,
                )
                result.success(null)
            }
            "stop" -> {
                hide()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun canDraw(context: Context): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            Settings.canDrawOverlays(context)

    private fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    @SuppressLint("ClickableViewAccessibility")
    private fun show(context: Context, trackId: String?, speaking: Boolean): Boolean {
        if (!canDraw(context)) return false
        if (root != null) {
            update(trackId, speaking)
            return true
        }
        val size = dp(context, DIAMETER)
        val margin = dp(context, MARGIN)
        val screen = context.resources.displayMetrics

        // 🔴 Clipped to a circle by its outline. A circular outline is a
        // round rect underneath, which is one of the shapes Android can clip
        // to - and it clips the video too, because a TextureView is drawn
        // in the view tree like any other view. A SurfaceView would not be.
        val frame = FrameLayout(context).apply {
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setOval(0, 0, view.width, view.height)
                }
            }
            clipToOutline = true
            setBackgroundColor(Color.parseColor("#1D1430"))
            contentDescription = "Back to the call"
        }

        // Their face underneath, for a voice call, for a camera that is off,
        // and for the moment before the first frame arrives.
        frame.addView(face(context), FrameLayout.LayoutParams(size, size))

        val video = TextureView(context).apply {
            // Transparent until a frame is drawn, so the face shows through.
            isOpaque = false
            surfaceTextureListener = object : TextureView.SurfaceTextureListener {
                override fun onSurfaceTextureAvailable(st: SurfaceTexture, w: Int, h: Int) {
                    renderer?.createEglSurface(st)
                }

                override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, w: Int, h: Int) {}

                override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean {
                    // Released once the renderer has let go of it, not
                    // before: EGL drawing into a released texture crashes.
                    val r = renderer
                    if (r == null) return true
                    r.releaseEglSurface { st.release() }
                    return false
                }

                override fun onSurfaceTextureUpdated(st: SurfaceTexture) {}
            }
        }
        frame.addView(video, FrameLayout.LayoutParams(size, size))

        // A rim: soft normally, the app's pink while they are talking, so
        // you can tell who is speaking without looking up from the game.
        val rim = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.TRANSPARENT)
        }
        frame.addView(
            View(context).apply { background = rim },
            FrameLayout.LayoutParams(size, size),
        )
        ring = rim

        renderer = EglRenderer("dayflower-game").apply {
            init(EglUtils.getRootEglBaseContext(), EglBase.CONFIG_RGBA, GlRectDrawer())
            // Cropped to a square, not squashed into one.
            setLayoutAspectRatio(1f)
        }

        val type =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
        val layout = WindowManager.LayoutParams(
            size,
            size,
            type,
            // Never takes the keyboard or the game's touches: only the
            // circle's own pixels are ours.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = screen.widthPixels - size - margin
            y = screen.heightPixels / 4
        }
        params = layout

        frame.setOnTouchListener(DragOrTap(context, size, margin))

        return try {
            windows(context).addView(frame, layout)
            root = frame
            update(trackId, speaking)
            true
        } catch (e: Throwable) {
            Log.w(TAG, "could not float the call: $e")
            renderer?.release()
            renderer = null
            ring = null
            params = null
            false
        }
    }

    /** Follows their camera: on, off, or a new track after a reconnect. */
    private fun update(trackId: String?, speaking: Boolean) {
        val frame = root ?: return
        ring?.setStroke(
            dp(frame.context, if (speaking) 3 else 2),
            if (speaking) Color.parseColor("#EE6FA8") else Color.argb(90, 255, 255, 255),
        )
        if (trackId == this.trackId) return
        detach()
        this.trackId = trackId
        if (trackId == null) return
        val found = try {
            webrtc?.getRemoteTrack(trackId) as? VideoTrack
        } catch (e: Throwable) {
            null
        }
        val r = renderer
        if (found == null || r == null) {
            lastStatus = "no video track $trackId (plugin ${webrtc != null}), showing their face"
            Log.w(TAG, lastStatus)
            return
        }
        try {
            found.addSink(r)
            track = found
            lastStatus = "showing video $trackId"
            Log.i(TAG, lastStatus)
        } catch (e: Throwable) {
            lastStatus = "could not attach $trackId: $e"
            Log.w(TAG, lastStatus)
        }
    }

    private fun detach() {
        val t = track
        val r = renderer
        track = null
        trackId = null
        if (t != null && r != null) {
            // A track the call has already disposed of throws here; it has
            // stopped sending frames either way.
            try {
                t.removeSink(r)
            } catch (_: Throwable) {}
        }
        // Back to their face, not their last frame frozen.
        r?.clearImage()
    }

    /** Takes the circle away. Safe to call when there is none. */
    fun hide() {
        val frame = root ?: return
        detach()
        root = null
        ring = null
        params = null
        try {
            // Immediate, so the texture is destroyed (and the renderer's
            // surface released) before the renderer itself is.
            windows(frame.context).removeViewImmediate(frame)
        } catch (e: Throwable) {
            Log.w(TAG, "could not remove the circle: $e")
        }
        renderer?.release()
        renderer = null
    }

    private fun windows(context: Context): WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    /**
     * Their photo, the one the incoming-call notification uses (see
     * CallerAvatar in Dart). A tulip on the call's plum when there is none.
     */
    private fun face(context: Context): View {
        val file = File(context.filesDir, "caller_avatar")
        val bitmap = try {
            if (file.exists() && file.length() > 0) BitmapFactory.decodeFile(file.path) else null
        } catch (_: Throwable) {
            null
        }
        if (bitmap != null) {
            return ImageView(context).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                setImageBitmap(bitmap)
            }
        }
        return TextView(context).apply {
            text = "🌷"
            textSize = 34f
            gravity = Gravity.CENTER
        }
    }

    /** Drag it anywhere; let go and it settles on the nearer side. A tap is
     *  the way back to the call. */
    private class DragOrTap(
        private val context: Context,
        private val size: Int,
        private val margin: Int,
    ) : View.OnTouchListener {
        private val slop = ViewConfiguration.get(context).scaledTouchSlop
        private var downX = 0f
        private var downY = 0f
        private var startX = 0
        private var startY = 0
        private var dragging = false

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            val layout = params ?: return false
            val screen = context.resources.displayMetrics
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startX = layout.x
                    startY = layout.y
                    dragging = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX
                    val dy = event.rawY - downY
                    if (!dragging && hypot(dx, dy) > slop) dragging = true
                    if (dragging) {
                        layout.x = (startX + dx.toInt())
                            .coerceIn(0, screen.widthPixels - size)
                        layout.y = (startY + dy.toInt())
                            .coerceIn(0, screen.heightPixels - size)
                        move(view, layout)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (dragging) settle(view, layout, screen.widthPixels) else back()
                }
            }
            return true
        }

        private fun move(view: View, layout: WindowManager.LayoutParams) {
            try {
                windows(context).updateViewLayout(view, layout)
            } catch (_: Throwable) {
                // Taken away mid-drag: the call ended.
            }
        }

        private fun settle(view: View, layout: WindowManager.LayoutParams, width: Int) {
            val left = layout.x + size / 2 < width / 2
            val target = if (left) margin else width - size - margin
            ValueAnimator.ofInt(layout.x, target).apply {
                duration = 220
                interpolator = DecelerateInterpolator()
                addUpdateListener {
                    if (root !== view) {
                        cancel()
                        return@addUpdateListener
                    }
                    layout.x = it.animatedValue as Int
                    move(view, layout)
                }
                start()
            }
        }

        /**
         * Brings the call back. The circle itself goes when the app
         * resumes (MainActivity.onResume), which covers opening the app any
         * other way too.
         *
         * WARNING: an app in the background may not normally start an
         * activity. One with "Display over other apps" may, which is the
         * permission this whole mode already needs.
         */
        private fun back() {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: return
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            try {
                context.startActivity(launch)
            } catch (e: Throwable) {
                Log.w(TAG, "could not come back to the call: $e")
            }
        }
    }
}
