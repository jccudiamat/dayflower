package com.dayflower.app

import android.content.ContentValues
import android.content.Context
import android.os.Build
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

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "supported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            "saveImage" -> saveImage(context, call, result)
            else -> result.notImplemented()
        }
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
                    // Its own album, so saved flowers and days sit together
                    // rather than scattered through the camera roll.
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_PICTURES + "/Dayflower",
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
