package com.dayflower.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * One reminder, stuck on the home screen.
 *
 * Unlike every other widget in this app, this one is **per instance**: each
 * copy on a home screen holds its own note, the way a fridge holds several
 * different pieces of paper. That is the whole metaphor — a widget showing
 * "your next reminder" would be a dashboard, not a note.
 *
 * ## How a note reaches a new widget
 *
 * `requestPinAppWidget` cannot hand data to the widget it creates. So `pin()`
 * parks the note under `pending_note_*` first, and the first `onUpdate` for a
 * widget id that has no note of its own adopts it. Nothing else claims the
 * pending note, and it is cleared once adopted, so two pins in a row cannot
 * cross over.
 */
class StickyNoteWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            adoptPendingNote(context, widgetId, widgetData)
            renderSafely(context, appWidgetManager, widgetId, widgetData)
        }
    }

    /**
     * A note goes with the widget it was stuck to.
     *
     * WARNING: without this, removing one note from a home screen leaves its
     * data behind forever, and the next widget to be created with a recycled
     * id would silently inherit a stranger's reminder.
     */
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context).edit()
        appWidgetIds.forEach { id ->
            KEYS.forEach { key -> prefs.remove("note_${id}_$key") }
        }
        prefs.apply()
        super.onDeleted(context, appWidgetIds)
    }

    companion object {
        private const val TAG = "DayflowerWidget"

        private val KEYS = listOf(
            "id", "emoji", "title", "note", "at", "done", "repeats",
            "fill", "edge", "ink",
        )

        /**
         * Parks a note for the next widget to claim, then asks the launcher
         * to create one.
         *
         * Returns false when the launcher will not pin — some will not, and
         * API 25 and below has no such request at all. **True only means the
         * request was made**: the launcher shows its own confirmation and a
         * person can dismiss it, so nothing may report that a note landed.
         */
        fun pin(context: Context, note: Map<String, Any?>): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false

            val manager = AppWidgetManager.getInstance(context)
            val provider = ComponentName(context, StickyNoteWidget::class.java)
            if (!manager.isRequestPinAppWidgetSupported) return false

            val prefs = HomeWidgetPlugin.getData(context).edit()
            prefs.putString("pending_note_id", note["id"] as? String ?: "")
            prefs.putString("pending_note_emoji", note["emoji"] as? String ?: "")
            prefs.putString("pending_note_title", note["title"] as? String ?: "")
            prefs.putString("pending_note_note", note["note"] as? String ?: "")
            prefs.putLong("pending_note_at", (note["remindAt"] as? Number)?.toLong() ?: 0L)
            prefs.putBoolean("pending_note_done", note["done"] as? Boolean ?: false)
            prefs.putBoolean("pending_note_repeats", note["repeats"] as? Boolean ?: false)
            prefs.putInt("pending_note_fill", (note["fill"] as? Number)?.toInt() ?: 0xFFFCE4EF.toInt())
            prefs.putInt("pending_note_edge", (note["edge"] as? Number)?.toInt() ?: 0xFFF3CBDF.toInt())
            prefs.putInt("pending_note_ink", (note["ink"] as? Number)?.toInt() ?: 0xFF4A2338.toInt())
            // commit, not apply: the launcher may create the widget and call
            // onUpdate before an async write has landed, and the note would
            // be gone by the time anything looked for it.
            prefs.commit()

            // No preview bundle: EXTRA_APPWIDGET_PREVIEW is API 33+, and the
            // launcher's own confirmation already shows previewLayout. One
            // more branch to keep in step for a dialog that appears once.
            return manager.requestPinAppWidget(provider, null, null).also { asked ->
                if (!asked) {
                    // Nothing will adopt it, so it must not sit there waiting
                    // to ambush the next widget added from the tray.
                    HomeWidgetPlugin.getData(context).edit()
                        .remove("pending_note_id").apply()
                }
            }
        }

        /** Gives a brand-new widget the note that was parked for it. */
        fun adoptPendingNote(
            context: Context,
            widgetId: Int,
            widgetData: SharedPreferences,
        ) {
            val alreadyMine = widgetData.getString("note_${widgetId}_id", "") ?: ""
            if (alreadyMine.isNotEmpty()) return

            val pending = widgetData.getString("pending_note_id", "") ?: ""
            if (pending.isEmpty()) return

            val prefs = HomeWidgetPlugin.getData(context).edit()
            prefs.putString("note_${widgetId}_id", pending)
            prefs.putString("note_${widgetId}_emoji", widgetData.getString("pending_note_emoji", "") ?: "")
            prefs.putString("note_${widgetId}_title", widgetData.getString("pending_note_title", "") ?: "")
            prefs.putString("note_${widgetId}_note", widgetData.getString("pending_note_note", "") ?: "")
            prefs.putLong("note_${widgetId}_at", widgetData.getLong("pending_note_at", 0L))
            prefs.putBoolean("note_${widgetId}_done", widgetData.getBoolean("pending_note_done", false))
            prefs.putBoolean("note_${widgetId}_repeats", widgetData.getBoolean("pending_note_repeats", false))
            prefs.putInt("note_${widgetId}_fill", widgetData.getInt("pending_note_fill", 0xFFFCE4EF.toInt()))
            prefs.putInt("note_${widgetId}_edge", widgetData.getInt("pending_note_edge", 0xFFF3CBDF.toInt()))
            prefs.putInt("note_${widgetId}_ink", widgetData.getInt("pending_note_ink", 0xFF4A2338.toInt()))
            // Claimed. A second widget added later gets the empty state
            // rather than a copy of this note.
            prefs.remove("pending_note_id")
            prefs.commit()
        }

        /**
         * 🔴 A provider runs in the **app's own process**, so an uncaught
         * throw here is the app closing about a second after it opens — the
         * grey-screen crash that took a build to find. Same guard, same
         * reason, as ReunionWidget.renderSafely.
         */
        fun renderSafely(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            widgetData: SharedPreferences,
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.sticky_note_widget)
                renderNote(context, views, valuesFor(widgetId, widgetData))
                manager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                android.util.Log.e(TAG, "sticky note render failed", e)
                try {
                    val plain = RemoteViews(context.packageName, R.layout.sticky_note_widget)
                    renderEmpty(context, plain)
                    manager.updateAppWidget(widgetId, plain)
                } catch (inner: Throwable) {
                    android.util.Log.e(TAG, "sticky note fallback failed", inner)
                }
            }
        }

        private fun valuesFor(widgetId: Int, data: SharedPreferences) = NoteValues(
            id = data.getString("note_${widgetId}_id", "") ?: "",
            emoji = data.getString("note_${widgetId}_emoji", "") ?: "",
            title = data.getString("note_${widgetId}_title", "") ?: "",
            note = data.getString("note_${widgetId}_note", "") ?: "",
            at = data.getLong("note_${widgetId}_at", 0L),
            done = data.getBoolean("note_${widgetId}_done", false),
            repeats = data.getBoolean("note_${widgetId}_repeats", false),
            fill = data.getInt("note_${widgetId}_fill", 0xFFFCE4EF.toInt()),
            edge = data.getInt("note_${widgetId}_edge", 0xFFF3CBDF.toInt()),
            ink = data.getInt("note_${widgetId}_ink", 0xFF4A2338.toInt()),
        )

        fun renderNote(
            context: Context,
            views: RemoteViews,
            values: NoteValues,
        ) {
            if (values.id.isEmpty()) {
                renderEmpty(context, views)
                return
            }

            // The paper. setInt on setColorFilter is how a RemoteViews
            // ImageView gets tinted — there is no setBackgroundColor that
            // survives the RemoteViews allowlist.
            views.setInt(R.id.note_paper, "setColorFilter", values.fill)
            views.setInt(R.id.note_fold, "setColorFilter", values.edge)

            views.setTextViewText(R.id.note_emoji, values.emoji)
            views.setTextViewText(R.id.note_title, values.title)
            views.setTextColor(R.id.note_title, values.ink)

            if (values.note.isEmpty()) {
                views.setViewVisibility(R.id.note_body, View.GONE)
            } else {
                views.setViewVisibility(R.id.note_body, View.VISIBLE)
                views.setTextViewText(R.id.note_body, values.note)
                views.setTextColor(R.id.note_body, withAlpha(values.ink, 0.72f))
            }

            // ⚠️ Worked out here, every draw, not baked in Dart. A note can
            // sit on a home screen for days; "Tomorrow 9am" written when the
            // app last ran would still say tomorrow all week. Same reason as
            // ReunionWidget.renderCountdown.
            val overdue = values.at in 1 until System.currentTimeMillis() && !values.done
            views.setTextViewText(R.id.note_when, whenLabel(values))
            views.setTextColor(
                R.id.note_when,
                if (overdue) OVERDUE else withAlpha(values.ink, 0.78f),
            )

            views.setViewVisibility(
                R.id.note_repeat,
                if (values.repeats) View.VISIBLE else View.GONE,
            )
            views.setInt(R.id.note_repeat, "setColorFilter", withAlpha(values.ink, 0.55f))

            views.setViewVisibility(
                R.id.note_done,
                if (values.done) View.VISIBLE else View.GONE,
            )
            views.setInt(R.id.note_done, "setColorFilter", values.ink)

            views.setOnClickPendingIntent(R.id.note_root, openReminders(context))
        }

        private fun renderEmpty(context: Context, views: RemoteViews) {
            views.setInt(R.id.note_paper, "setColorFilter", 0xFFFCE4EF.toInt())
            views.setInt(R.id.note_fold, "setColorFilter", 0xFFF3CBDF.toInt())
            views.setTextViewText(R.id.note_emoji, "📌")
            views.setTextViewText(R.id.note_title, "No note yet")
            views.setTextColor(R.id.note_title, 0xFF4A2338.toInt())
            views.setViewVisibility(R.id.note_body, View.VISIBLE)
            views.setTextViewText(
                R.id.note_body,
                "Long-press a reminder in Dayflower to stick it here.",
            )
            views.setTextColor(R.id.note_body, 0xB34A2338.toInt())
            views.setTextViewText(R.id.note_when, "")
            views.setViewVisibility(R.id.note_repeat, View.GONE)
            views.setViewVisibility(R.id.note_done, View.GONE)
            views.setOnClickPendingIntent(R.id.note_root, openReminders(context))
        }

        private fun openReminders(context: Context): PendingIntent =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("dayflower://reminders"),
            )

        /** "8pm" / "Tomorrow 9am" / "Fri 12 Sep" — short enough for paper. */
        fun whenLabel(values: NoteValues): String {
            if (values.at <= 0L) return ""
            if (values.done) return "Done"

            val days = wholeDaysUntil(values.at)
            val time = TIME_FORMAT.format(Date(values.at))
                .lowercase(Locale.getDefault())
                .replace(" ", "")
            return when {
                days == 0L -> time
                days == 1L -> "Tomorrow $time"
                days == -1L -> "Yesterday $time"
                days in 2..6 -> "${DAY_FORMAT.format(Date(values.at))} $time"
                else -> DATE_FORMAT.format(Date(values.at))
            }
        }

        /**
         * ⚠️ Calendar days, not elapsed hours, and rounded rather than
         * truncated — two midnights are 23 or 25 hours apart across a
         * daylight-saving change, and integer division would drop a day once
         * a year. Same arithmetic as ReunionWidget.wholeDaysUntil.
         */
        private fun wholeDaysUntil(at: Long): Long {
            val target = startOfDay(at)
            val today = startOfDay(System.currentTimeMillis())
            return Math.round((target - today) / 86_400_000.0)
        }

        private fun startOfDay(millis: Long): Long {
            val cal = Calendar.getInstance()
            cal.timeInMillis = millis
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.timeInMillis
        }

        private fun withAlpha(color: Int, alpha: Float): Int =
            (color and 0x00FFFFFF) or ((alpha * 255).toInt() shl 24)

        private val OVERDUE = 0xFFE2447C.toInt()
        private val TIME_FORMAT = SimpleDateFormat("h:mma", Locale.getDefault())
        private val DAY_FORMAT = SimpleDateFormat("EEE", Locale.getDefault())
        private val DATE_FORMAT = SimpleDateFormat("d MMM", Locale.getDefault())

    }

    data class NoteValues(
        val id: String,
        val emoji: String,
        val title: String,
        val note: String,
        val at: Long,
        val done: Boolean,
        val repeats: Boolean,
        val fill: Int,
        val edge: Int,
        val ink: Int,
    )
}
