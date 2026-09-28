package com.dayflower.app

import android.app.Application
import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * The app's process, whatever started it: the app, a push, a widget.
 *
 * 🔴 **Here to stop every Dayflower widget blinking at every widget tap.**
 * A tap that does something without opening the app (a heartbeat, a heart)
 * goes to Dart through home_widget, which queues it with WorkManager. And
 * WorkManager switches one of its own receivers
 * (`androidx.work.impl.background.systemalarm.RescheduleReceiver`) on while
 * it has work waiting and off again when it has none. Switching a component
 * on or off is a PACKAGE_CHANGED, and on a PACKAGE_CHANGED Android resets
 * every widget the package has: it drops what each one shows, tells the
 * launcher the provider changed, and asks for them all again. So every tap
 * blanked all of them, My Day, Heartbeat, Reunion and every sticky note,
 * twice (on, then off), and each one came back a moment later.
 *
 * The fix is WorkManager's own advice: never let it run out of work. One
 * job that waits ten years and does nothing keeps the receiver on for good,
 * so nothing is ever switched and nothing is reset. It is queued with KEEP,
 * so every later start finds it there and changes nothing. The first one
 * does switch the receiver on, once, the first time this build runs.
 */
class DayflowerApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        keepWorkManagerSteady(this)
    }

    companion object {
        private const val STEADY_WORK = "widgets_steady"

        fun keepWorkManagerSteady(context: Context) {
            try {
                WorkManager.getInstance(context).enqueueUniqueWork(
                    STEADY_WORK,
                    ExistingWorkPolicy.KEEP,
                    OneTimeWorkRequestBuilder<SteadyWorker>()
                        .setInitialDelay(3650, TimeUnit.DAYS)
                        .build(),
                )
            } catch (e: Throwable) {
                // Widgets that blink are a cosmetic problem; an app that
                // will not start is not.
                android.util.Log.w("Dayflower", "could not hold WorkManager steady: $e")
            }
        }
    }
}

/** Does nothing, ten years from now. See [DayflowerApplication]. */
class SteadyWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result = Result.success()
}
