package com.dayflower.app

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Recording and playing a voice message.
 *
 * WARNING: this is Kotlin rather than a pub package on purpose, and the
 * reason is size. The APK sits about 76 KB under Play's 50 MB ceiling, and
 * every recorder package on pub carries its own native audio engine -
 * megabytes, for a job Android's own MediaRecorder does in a hundred lines.
 * The same reasoning as MediaSaver: a dependency plus a permission, for
 * about this much work.
 *
 * WARNING: **24 kbps mono at 16 kHz, and those numbers are a cost
 * decision.** Speech needs no more, and a recorder's usual default (music
 * quality, ~128 kbps) is five times the bytes for no audible gain on a voice
 * note. Two minutes here is about 360 KB; at the default it would be 1.8 MB,
 * which at thousands of pairs is the difference between voice notes costing
 * a few dollars a month and costing hundreds. AAC in an MP4 container
 * (`.m4a`) because every phone and browser plays it.
 */
object VoiceNotes {

    const val CHANNEL = "dayflower/voice"

    /** The ceiling the UI also enforces; the recorder stops itself here. */
    private const val MAX_MS = 120_000

    private var recorder: MediaRecorder? = null
    private var recordingPath: String? = null
    private var startedAt = 0L

    private var player: MediaPlayer? = null

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "start" -> start(context, result)
                "stop" -> stop(result)
                "cancel" -> cancel(result)
                "amplitude" -> result.success(amplitude())
                "play" -> play(call, result)
                "pause" -> {
                    player?.takeIf { it.isPlaying }?.pause()
                    result.success(null)
                }
                "resume" -> {
                    player?.start()
                    result.success(null)
                }
                "seek" -> {
                    (call.argument<Int>("ms"))?.let { player?.seekTo(it) }
                    result.success(null)
                }
                "stopPlay" -> {
                    releasePlayer()
                    result.success(null)
                }
                "position" -> result.success(position())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // A failed voice note must never take the app down with it.
            result.error("voice_failed", e.message, null)
        }
    }

    // ── Recording ───────────────────────────────────────────────────────

    private fun start(context: Context, result: MethodChannel.Result) {
        // A second start without a stop would leak the first recorder and
        // leave the microphone held.
        releaseRecorder()

        val file = File(context.cacheDir, "voice-${System.currentTimeMillis()}.m4a")
        val next = if (Build.VERSION.SDK_INT >= 31) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        next.apply {
            setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioChannels(1)
            setAudioSamplingRate(16_000)
            setAudioEncodingBitRate(24_000)
            setMaxDuration(MAX_MS)
            setOutputFile(file.absolutePath)
            prepare()
            start()
        }
        recorder = next
        recordingPath = file.absolutePath
        // SystemClock, not wall time: a clock correction mid-recording must
        // not make a voice note report a negative length.
        startedAt = SystemClock.elapsedRealtime()
        result.success(null)
    }

    private fun stop(result: MethodChannel.Result) {
        val active = recorder
        val path = recordingPath
        if (active == null || path == null) {
            result.success(null)
            return
        }
        val ms = (SystemClock.elapsedRealtime() - startedAt).toInt()
        try {
            active.stop()
        } catch (e: RuntimeException) {
            // MediaRecorder throws on stop when it captured nothing at all -
            // a tap rather than a hold. The file is unusable, so it goes.
            releaseRecorder()
            File(path).delete()
            result.success(null)
            return
        }
        releaseRecorder()
        result.success(mapOf("path" to path, "ms" to ms.coerceAtMost(MAX_MS)))
    }

    private fun cancel(result: MethodChannel.Result) {
        val path = recordingPath
        try {
            recorder?.stop()
        } catch (e: RuntimeException) {
            // Nothing captured. Releasing below is all that is left to do.
        }
        releaseRecorder()
        if (path != null) File(path).delete()
        result.success(null)
    }

    /**
     * Loudness right now, 0 to 1, for the bar that moves while you speak.
     *
     * getMaxAmplitude is a raw 16-bit peak and reads almost nothing for
     * ordinary speech on a linear scale, so this is shaped roughly the way
     * hearing is: a square root, which lifts a quiet voice into a visible
     * bar without pinning a loud one.
     */
    private fun amplitude(): Double {
        val peak = try {
            recorder?.maxAmplitude ?: 0
        } catch (e: IllegalStateException) {
            0
        }
        if (peak <= 0) return 0.0
        return Math.sqrt(peak / 32_767.0).coerceIn(0.0, 1.0)
    }

    private fun releaseRecorder() {
        try {
            recorder?.reset()
            recorder?.release()
        } catch (e: Exception) {
            // Already gone.
        }
        recorder = null
        recordingPath = null
    }

    // ── Playing ─────────────────────────────────────────────────────────

    private fun play(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null || !File(path).exists()) {
            result.success(null)
            return
        }
        releasePlayer()
        val next = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    // MUSIC, not VOICE_COMMUNICATION: a voice note is
                    // something you play, not a call, and the call routing
                    // would send it to the earpiece.
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            setDataSource(path)
            prepare()
            start()
        }
        player = next
        next.setOnCompletionListener {
            // Told rather than polled, so the bubble resets the moment it
            // ends instead of on the next tick.
            MainActivity.voiceChannel?.invokeMethod("finished", null)
        }
        result.success(next.duration)
    }

    private fun position(): Map<String, Any> {
        val active = player
        return mapOf(
            "ms" to (active?.currentPosition ?: 0),
            "playing" to (active?.isPlaying ?: false),
        )
    }

    private fun releasePlayer() {
        try {
            player?.stop()
            player?.release()
        } catch (e: Exception) {
            // Already gone.
        }
        player = null
    }

    /** From onStop: nothing should keep recording once the app is away. */
    fun releaseAll() {
        releaseRecorder()
        releasePlayer()
    }
}
