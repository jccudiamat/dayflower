package com.dayflower.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Where this phone is, once, while the app is open: for "share my exact
 * location" (lib/features/location/data/live_location.dart).
 *
 * Android's own LocationManager, not a plugin. The usual plugins pull in
 * Google's fused-location library, and the APK has little room left under
 * its ceiling (PROGRESS.md § Android builds). On Android 12+ the platform
 * has a fused provider of its own, which is what this asks first.
 *
 * ⚠️ **Foreground only, by design.** No background permission is declared,
 * nothing runs when the app is closed: a spot is taken when the person has
 * the app open and has said to share. The permission prompt is Android's
 * "while using the app".
 */
object LocationShare {

    const val CHANNEL = "dayflower/location"
    const val REQUEST_CODE = 7311

    /** Longest a single fix may take before the last known one is used. */
    private const val FIX_TIMEOUT_MS = 20_000L

    /** A last-known spot older than this is not "where they are". */
    private const val LAST_KNOWN_MAX_AGE_MS = 10 * 60_000L

    private val geocoding = Executors.newSingleThreadExecutor()

    /** "precise", "approximate" (Android 12's coarse-only grant) or "none". */
    fun permission(context: Context): String = when {
        granted(context, Manifest.permission.ACCESS_FINE_LOCATION) -> "precise"
        granted(context, Manifest.permission.ACCESS_COARSE_LOCATION) -> "approximate"
        else -> "none"
    }

    private fun granted(context: Context, permission: String) =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    val permissions = arrayOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION,
    )

    /** The app's page in system settings, for a permission refused for good. */
    fun openSettings(context: Context) {
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", context.packageName, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    /**
     * One fresh fix, answered as a map (lat, lon, accuracy, time, place,
     * precise), or null when there is none to be had: no permission,
     * location switched off, or nothing within [FIX_TIMEOUT_MS].
     */
    fun current(context: Context, result: MethodChannel.Result) {
        val perm = permission(context)
        val manager = context.getSystemService(LocationManager::class.java)
        if (perm == "none" || manager == null) {
            result.success(null)
            return
        }
        val provider = providerFor(manager, perm == "precise")
        if (provider == null) {
            result.success(mapOf("off" to true))
            return
        }
        val main = Handler(Looper.getMainLooper())
        var answered = false
        fun answer(location: Location?) {
            if (answered) return
            answered = true
            val fix = location ?: lastKnown(manager)
            if (fix == null) {
                result.success(null)
                return
            }
            // The town's name off the main thread: the geocoder blocks on
            // the network before Android 13.
            geocoding.execute {
                val place = try {
                    placeName(context, fix)
                } catch (e: Throwable) {
                    null
                }
                main.post {
                    result.success(
                        mapOf(
                            "lat" to fix.latitude,
                            "lon" to fix.longitude,
                            "accuracy" to (if (fix.hasAccuracy()) fix.accuracy.toDouble() else null),
                            "time" to fix.time,
                            "place" to place,
                            "precise" to (perm == "precise"),
                        ),
                    )
                }
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val cancel = CancellationSignal()
                main.postDelayed({
                    cancel.cancel()
                    answer(null)
                }, FIX_TIMEOUT_MS)
                manager.getCurrentLocation(provider, cancel, context.mainExecutor) { answer(it) }
            } else {
                val listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        manager.removeUpdates(this)
                        answer(location)
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onStatusChanged(p: String?, s: Int, e: android.os.Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                }
                main.postDelayed({
                    manager.removeUpdates(listener)
                    answer(null)
                }, FIX_TIMEOUT_MS)
                @Suppress("DEPRECATION")
                manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
            }
        } catch (e: SecurityException) {
            // Revoked between the check and the ask.
            answer(null)
        } catch (e: Throwable) {
            android.util.Log.e("LocationShare", "fix failed", e)
            answer(null)
        }
    }

    /**
     * The fused provider where Android has one (12+), else GPS when precise
     * location is allowed, else the network's. Null when location is off.
     */
    private fun providerFor(manager: LocationManager, precise: Boolean): String? {
        val candidates = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add(LocationManager.FUSED_PROVIDER)
            if (precise) add(LocationManager.GPS_PROVIDER)
            add(LocationManager.NETWORK_PROVIDER)
        }
        return candidates.firstOrNull {
            try {
                manager.isProviderEnabled(it)
            } catch (e: Throwable) {
                false
            }
        }
    }

    private fun lastKnown(manager: LocationManager): Location? = try {
        manager.allProviders
            .mapNotNull {
                try {
                    manager.getLastKnownLocation(it)
                } catch (e: SecurityException) {
                    null
                }
            }
            .filter { System.currentTimeMillis() - it.time < LAST_KNOWN_MAX_AGE_MS }
            .minByOrNull { if (it.hasAccuracy()) it.accuracy else Float.MAX_VALUE }
    } catch (e: Throwable) {
        null
    }

    /** "Abu Dhabi", from the phone's own geocoder; null when it has none. */
    private fun placeName(context: Context, fix: Location): String? {
        if (!Geocoder.isPresent()) return null
        val geocoder = Geocoder(context, Locale.ENGLISH)
        val address: Address? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val latch = java.util.concurrent.CountDownLatch(1)
            var found: Address? = null
            geocoder.getFromLocation(fix.latitude, fix.longitude, 1, object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) {
                    found = addresses.firstOrNull()
                    latch.countDown()
                }

                override fun onError(errorMessage: String?) {
                    latch.countDown()
                }
            })
            latch.await(8, java.util.concurrent.TimeUnit.SECONDS)
            found
        } else {
            @Suppress("DEPRECATION")
            geocoder.getFromLocation(fix.latitude, fix.longitude, 1)?.firstOrNull()
        }
        return address?.let { it.locality ?: it.subAdminArea ?: it.adminArea ?: it.countryName }
    }
}
