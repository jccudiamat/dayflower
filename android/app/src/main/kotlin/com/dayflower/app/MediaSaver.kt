package com.dayflower.app

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.ByteArrayOutputStream
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Saves an image into the phone's own gallery.
 *
 * WARNING: the app could already write a photo to disk - see _savePending in
 * share_your_day.dart - but only into its own external folder, which is a
 * place nothing else looks. A "Save" that puts a picture somewhere the
 * Gallery app will never show it is a button that lies.
 *
 * MediaStore is what actually publishes it, and on API 29+ it needs no
 * permission at all: the app owns the row it inserts. That is the whole
 * reason this is Kotlin and not a plugin - the alternative was a dependency
 * plus WRITE_EXTERNAL_STORAGE, for about thirty lines of work.
 */
object MediaSaver {

    const val CHANNEL = "dayflower/media"

    /**
     * When the last save started, on the elapsedRealtime clock. A picture we
     * put in the gallery ourselves is not a screenshot; ScreenshotWatcher
     * checks this before offering a report.
     */
    @Volatile
    var lastSavedAt = 0L

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "supported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            "encodeWebp" -> encodeWebp(call, result)
            "saveImage" -> {
                lastSavedAt = android.os.SystemClock.elapsedRealtime()
                saveImage(context, call, result)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Re-encodes a picture as lossy WebP, keeping its transparency.
     *
     * WARNING: this exists for cost. A photo on paper is composed in Dart,
     * and Dart can only write PNG: a framed day photo came out at about a
     * megabyte, four to six times an ordinary one, and day photos are kept
     * forever. JPEG would be smaller still but has no transparency, and a
     * torn edge is not a rectangle. WebP has both, and Android has encoded
     * it natively since long before this app's minSdk.
     *
     * Off the main thread: a 1280px encode is tens of milliseconds, which is
     * a dropped frame on the shutter animation if it runs inline.
     */
    private fun encodeWebp(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val quality = call.argument<Int>("quality") ?: 85
        if (bytes == null || bytes.isEmpty()) {
            result.success(null)
            return
        }
        val main = Handler(Looper.getMainLooper())
        Thread {
            val encoded = try {
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap == null) {
                    null
                } else {
                    val out = ByteArrayOutputStream()
                    val format = if (Build.VERSION.SDK_INT >= 30) {
                        Bitmap.CompressFormat.WEBP_LOSSY
                    } else {
                        @Suppress("DEPRECATION")
                        Bitmap.CompressFormat.WEBP
                    }
                    bitmap.compress(format, quality, out)
                    bitmap.recycle()
                    out.toByteArray()
                }
            } catch (e: Exception) {
                // Null tells Dart to keep the PNG: bigger, but still right.
                null
            }
            main.post { result.success(encoded) }
        }.start()
    }

    private fun saveImage(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val bytes = call.argument<ByteArray>("bytes")
        val name = call.argument<String>("name") ?: "dayflower.jpg"
        if (bytes == null || bytes.isEmpty()) {
            result.success(false)
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, name)
                    put(MediaStore.Images.Media.MIME_TYPE, mimeFor(name))
                    // WARNING: DCIM, not Pictures/Dayflower. An app album
                    // keeps saved flowers and days together, and that was
                    // the original reasoning - but it also puts them
                    // somewhere people have to go looking for. Several
                    // gallery apps show DCIM as the roll and file
                    // everything else away under Albums, so "Save" appeared
                    // to do nothing. DCIM is where a phone's own pictures
                    // live, which is where someone who just tapped Save
                    // expects to find one.
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_DCIM,
                    )
                    // WARNING: hides the row from the Gallery until the
                    // bytes are written. Without it a scan that lands
                    // mid-write shows a half-decoded image permanently.
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }

                val resolver = context.contentResolver
                val uri = resolver.insert(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    values,
                ) ?: run {
                    result.success(false)
                    return
                }

                resolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: run {
                        resolver.delete(uri, null, null)
                        result.success(false)
                        return
                    }

                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                result.success(true)
            } else {
                // Pre-29 would need WRITE_EXTERNAL_STORAGE and a media scan
                // broadcast. Refused rather than half-done: Dart shows a
                // plain "couldn't save" instead of claiming success.
                result.success(false)
            }
        } catch (e: Throwable) {
            // A full disk, a revoked volume, a name the resolver rejects.
            // Never throw across the channel - Dart only needs to know it
            // did not happen.
            result.success(false)
        }
    }

    private fun mimeFor(name: String): String =
        if (name.endsWith(".png", ignoreCase = true)) "image/png" else "image/jpeg"
}
