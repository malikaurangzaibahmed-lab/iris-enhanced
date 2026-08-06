package com.example.student_organizer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews

class ClassTrackerWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "ClassTrackerWidget"
        private val PREFS_NAMES = arrayOf(
            "group.com.example.student_organizer",
            "com.example.student_organizer",
            "HomeWidgetPreferences",
            "FlutterSharedPreferences",
        )
        private const val UPDATE_ACTION = "com.example.student_organizer.WIDGET_UPDATE"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            providerClass: Class<out AppWidgetProvider> = ClassTrackerWidget::class.java,
        ) {
            try {
                var prefs: SharedPreferences? = null
                for (prefsName in PREFS_NAMES) {
                    val candidate = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    if (candidate.contains("flutter.widget_headline") ||
                        candidate.contains("flutter.current_class_subject")) {
                        prefs = candidate
                        break
                    }
                }
                if (prefs == null) {
                    prefs = context.getSharedPreferences(PREFS_NAMES[0], Context.MODE_PRIVATE)
                }

                val activeRole = prefs.getString("flutter.active_role", "") ?: ""
                val isFaculty = activeRole.equals("Faculty", ignoreCase = true) || activeRole.equals("Teacher", ignoreCase = true)

                val subject = prefs.getString("flutter.widget_subject", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.current_class_subject", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.widget_headline", if (isFaculty) "Faculty Schedule" else "System Idle")
                    ?: if (isFaculty) "Faculty Schedule" else "System Idle"

                val rawRoom = prefs.getString("flutter.widget_room", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.current_class_room", "")?.takeIf { it.isNotEmpty() }
                    ?: ""

                val teacher = prefs.getString("flutter.current_class_teacher", "") ?: ""
                val batch = prefs.getString("flutter.widget_batch", "") ?: ""
                val progressPercent = prefs.getInt("flutter.progress_percentage", 0).coerceIn(0, 100)
                val timeInfo = prefs.getString("flutter.time_info", "--") ?: "--"
                val isLive = prefs.getBoolean("flutter.is_class_live", false)
                val widgetDarkMode = prefs.getBoolean("flutter.widget_dark_mode", false)
                val startTime = prefs.getString("flutter.widget_start_time", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.current_class_end_time", "") ?: ""

                val layoutId = if (widgetDarkMode) R.layout.widget_safe_dark else R.layout.widget_safe
                val views = RemoteViews(context.packageName, layoutId)

                val (widthDp, heightDp) = getWidgetSizeDp(context, appWidgetManager, appWidgetId)

                // Set native background drawable
                val bgRes = if (widgetDarkMode) R.drawable.widget_bg_dark_v2 else R.drawable.widget_bg_light_v2
                views.setImageViewResource(R.id.widget_glass_bg, bgRes)

                val isCompact = heightDp < 105
                val showTeacherCard = heightDp >= 145

                if (isCompact) {
                    views.setViewVisibility(R.id.widget_compact_container, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_full_container, View.GONE)

                    val compactTitle = if (rawRoom.isNotEmpty()) "$subject • $rawRoom" else subject
                    views.setTextViewText(R.id.widget_compact_title, compactTitle)
                    views.setTextViewText(R.id.widget_compact_time, timeInfo)

                    if (isLive) {
                        views.setTextViewText(R.id.widget_compact_badge, if (isFaculty) "TEACHING" else "LIVE")
                    } else {
                        views.setTextViewText(R.id.widget_compact_badge, if (isFaculty) "LECTURE" else "NEXT")
                    }
                } else {
                    views.setViewVisibility(R.id.widget_compact_container, View.GONE)
                    views.setViewVisibility(R.id.widget_full_container, View.VISIBLE)

                    // Text Binds
                    views.setTextViewText(R.id.widget_headline, subject)
                    views.setTextViewText(R.id.widget_time_info, timeInfo)

                    if (isLive) {
                        views.setTextViewText(R.id.widget_status_badge, if (isFaculty) "● TEACHING NOW" else "● LIVE CLASS")
                        views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                        views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
                    } else {
                        views.setTextViewText(R.id.widget_status_badge, if (isFaculty) "NEXT LECTURE" else "NEXT CLASS")
                        views.setViewVisibility(R.id.widget_progress, View.GONE)
                    }

                    if (rawRoom.isNotEmpty()) {
                        views.setTextViewText(R.id.widget_details_room, rawRoom)
                        views.setViewVisibility(R.id.widget_class_details_capsule, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.widget_class_details_capsule, View.GONE)
                    }

                    if (startTime.isNotEmpty()) {
                        views.setTextViewText(R.id.widget_details_start_time, startTime)
                    }

                    if (isFaculty) {
                        val classInfoText = if (batch.isNotEmpty()) "Class: $batch" else "Faculty Schedule"
                        views.setTextViewText(R.id.widget_teacher_name, classInfoText)
                        views.setViewVisibility(R.id.widget_teacher_card, View.VISIBLE)
                    } else if (teacher.isNotEmpty() && showTeacherCard) {
                        views.setTextViewText(R.id.widget_teacher_name, teacher)
                        views.setViewVisibility(R.id.widget_teacher_card, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.widget_teacher_card, View.GONE)
                    }
                }

                // App Launch Intent
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId + 2000,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_glass_bg, pendingIntent)
                views.setOnClickPendingIntent(R.id.widget_headline, pendingIntent)

                // Refresh Button Intent
                val refreshIntent = Intent(context, providerClass).apply {
                    action = UPDATE_ACTION
                }
                val refreshPending = PendingIntent.getBroadcast(
                    context,
                    appWidgetId + 5000,
                    refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_refresh, refreshPending)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Widget update error: ${e.message}", e)
                try {
                    val fallbackViews = RemoteViews(context.packageName, R.layout.widget_safe)
                    fallbackViews.setTextViewText(R.id.widget_headline, "IRIS Companion")
                    fallbackViews.setTextViewText(R.id.widget_time_info, "Tap to open app")
                    val fallbackIntent = Intent(context, MainActivity::class.java)
                    val fallbackPending = PendingIntent.getActivity(
                        context,
                        appWidgetId + 2001,
                        fallbackIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    fallbackViews.setOnClickPendingIntent(R.id.widget_glass_bg, fallbackPending)
                    appWidgetManager.updateAppWidget(appWidgetId, fallbackViews)
                } catch (ex: Exception) {
                    Log.e(TAG, "Fallback widget update failed: ${ex.message}", ex)
                }
            }
        }

        private fun getWidgetSizeDp(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ): Pair<Int, Int> {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            var widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            var heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            if (widthDp <= 0) widthDp = 180
            if (heightDp <= 0) heightDp = 110
            return Pair(widthDp, heightDp)
        }

        fun updateAllInstances(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context.packageName, ClassTrackerWidget::class.java.name)
            val ids = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in ids) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == UPDATE_ACTION) {
            updateAllInstances(context)
        }
    }
}
