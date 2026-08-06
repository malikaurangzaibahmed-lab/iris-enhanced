package com.example.student_organizer

import android.app.PendingIntent
import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.os.SystemClock
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
        private const val AUTO_REFRESH_INTERVAL_MS = 3_000L
        private const val AUTO_REFRESH_REQUEST_CODE = 7001

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

                val subject = prefs.getString("flutter.widget_subject", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.current_class_subject", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.widget_headline", "System Idle")
                    ?: "System Idle"

                val rawRoom = prefs.getString("flutter.widget_room", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.current_class_room", "")?.takeIf { it.isNotEmpty() }
                    ?: ""

                val teacher = prefs.getString("flutter.current_class_teacher", "") ?: ""
                val progressPercent = prefs.getInt("flutter.progress_percentage", 0).coerceIn(0, 100)
                val timeInfo = prefs.getString("flutter.time_info", "--") ?: "--"
                val isLive = prefs.getBoolean("flutter.is_class_live", false)
                val widgetDarkMode = prefs.getBoolean("flutter.widget_dark_mode", false)
                val startTime = prefs.getString("flutter.widget_start_time", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.current_class_end_time", "") ?: ""

                val layoutId = if (widgetDarkMode) R.layout.widget_safe_dark else R.layout.widget_safe
                val views = RemoteViews(context.packageName, layoutId)

                val sizePx = getWidgetSizePx(context, appWidgetManager, appWidgetId)
                val heightPx = sizePx.second

                // Generate background glass bitmap matched to exact widget bounds
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    try {
                        val role = prefs.getString("flutter.active_role", "student") ?: "student"
                        val period = prefs.getString("active_academic_period", "classes") ?: "classes"
                        val assetName = when {
                            period == "midterms" || period == "finals" || period == "exams" -> "widget_bg_exams.png"
                            period == "sports" || period == "gala" -> "widget_bg_sports.png"
                            role == "faculty" -> "widget_bg_faculty.png"
                            isLive -> "widget_bg_student.png"
                            else -> "widget_bg_idle.png"
                        }
                        val glassBitmap = LiquidGlassBitmapGenerator.generateGlassBitmapFromAsset(
                            context,
                            sizePx.first,
                            sizePx.second,
                            assetName,
                            widgetDarkMode
                        )
                        if (glassBitmap != null) {
                            views.setImageViewBitmap(R.id.widget_glass_bg, glassBitmap)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Glass background failed: ${e.message}")
                    }
                }

                // Text Binds
                views.setTextViewText(R.id.widget_headline, subject)
                views.setTextViewText(R.id.widget_time_info, timeInfo)
                
                if (isLive) {
                    views.setTextViewText(R.id.widget_status_badge, "● LIVE CLASS")
                    views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                    views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
                } else {
                    views.setTextViewText(R.id.widget_status_badge, "NEXT CLASS")
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

                if (teacher.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_teacher_name, teacher)
                }

                // Responsive auto-hiding for small widget sizes (< 140px height)
                val isCompact = heightPx < 140
                if (isCompact) {
                    views.setViewVisibility(R.id.widget_state_label, View.GONE)
                    views.setViewVisibility(R.id.widget_teacher_card, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_state_label, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_teacher_card, if (teacher.isNotEmpty()) View.VISIBLE else View.GONE)
                }

                // App Launch Intent
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId + 2000,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

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
            }
        }

        private fun getWidgetSizePx(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ): Pair<Int, Int> {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            var widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            var heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            if (widthDp <= 0) widthDp = 180
            if (heightDp <= 0) heightDp = 110

            val dm = context.resources.displayMetrics
            val widthPx = (widthDp * dm.density).toInt().coerceAtLeast(200)
            val heightPx = (heightDp * dm.density).toInt().coerceAtLeast(100)
            return Pair(widthPx, heightPx)
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
