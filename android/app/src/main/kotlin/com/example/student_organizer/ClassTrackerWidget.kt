package com.example.student_organizer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import android.os.Build

class ClassTrackerWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "ClassTrackerWidget"
        private val PREFS_NAMES = arrayOf(
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

                val headline = prefs.getString("flutter.widget_headline", "System Idle") ?: "System Idle"
                val subline = prefs.getString("flutter.widget_subline", "No active class") ?: "No active class"
                val teacher = prefs.getString("flutter.current_class_teacher", "") ?: ""
                val progressPercent = prefs.getInt("flutter.progress_percentage", 0).coerceIn(0, 100)
                val timeInfo = prefs.getString("flutter.time_info", "--") ?: "--"
                val isLive = prefs.getBoolean("flutter.is_class_live", false)
                val isUrgent = prefs.getBoolean("flutter.is_urgent", false)
                val widgetDarkMode = prefs.getBoolean("flutter.widget_dark_mode", false)

                val layoutId = if (widgetDarkMode) R.layout.widget_safe_dark else R.layout.widget_safe
                val views = try {
                    RemoteViews(context.packageName, layoutId)
                } catch (e: Exception) {
                    Log.e(TAG, "Widget layout inflate failed: ${e.message}", e)
                    return
                }

                // Apply Liquid Glass effect if supported (Android 13+)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    Log.d(TAG, "Attempting to generate LiquidGlass effect for widget $appWidgetId")
                    try {
                        val bgRes = if (widgetDarkMode) R.drawable.widget_fluffy_dark_bg else R.drawable.widget_fluffy_bg
                        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                        var width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
                        var height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
                        
                        if (width <= 0) width = 160 // Fallback
                        if (height <= 0) height = 100 // Fallback

                        val displayMetrics = context.resources.displayMetrics
                        val widthPx = (width * displayMetrics.density).toInt()
                        val heightPx = (height * displayMetrics.density).toInt()

                        val glassBitmap = LiquidGlassBitmapGenerator.generateGlassBitmap(
                            context, widthPx, heightPx, bgRes, widgetDarkMode
                        )
                        if (glassBitmap != null) {
                            Log.d(TAG, "Successfully generated glass bitmap: ${glassBitmap.width}x${glassBitmap.height}")
                            views.setImageViewBitmap(R.id.widget_glass_bg, glassBitmap)
                        } else {
                            Log.w(TAG, "Generated glass bitmap is null")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "LiquidGlass effect generation failed: ${e.message}", e)
                    }
                } else {
                    Log.d(TAG, "LiquidGlass effect skipped: API level ${Build.VERSION.SDK_INT} < 33")
                }

                views.setTextViewText(R.id.widget_headline, headline)
                views.setTextViewText(R.id.widget_subline, subline)

                val headlineColor = when {
                    isLive -> 0xFF10B981.toInt()
                    isUrgent -> 0xFFF59E0B.toInt()
                    else -> if (widgetDarkMode) 0xFFE2E8F0.toInt() else 0xFF334155.toInt()
                }
                views.setTextColor(R.id.widget_headline, headlineColor)
                views.setTextColor(R.id.widget_subline, if (widgetDarkMode) 0xFFFFFFFF.toInt() else 0xFF1E293B.toInt())

                when {
                    isLive -> {
                        views.setTextViewText(R.id.widget_status_badge, "LIVE")
                        views.setTextColor(R.id.widget_status_badge, 0xFF10B981.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, android.view.View.VISIBLE)
                    }
                    isUrgent -> {
                        views.setTextViewText(R.id.widget_status_badge, "SOON")
                        views.setTextColor(R.id.widget_status_badge, 0xFFF59E0B.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, android.view.View.VISIBLE)
                    }
                    else -> {
                        views.setTextViewText(R.id.widget_status_badge, "NEXT")
                        views.setTextColor(R.id.widget_status_badge, if (widgetDarkMode) 0xFFBFDBFE.toInt() else 0xFF5B7FFF.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, android.view.View.VISIBLE)
                    }
                }

                if (teacher.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_teacher_info, "Teacher: $teacher")
                    views.setTextColor(R.id.widget_teacher_info, if (widgetDarkMode) 0xFFCBD5E1.toInt() else 0xFF64748B.toInt())
                    views.setViewVisibility(R.id.widget_teacher_info, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_teacher_info, android.view.View.GONE)
                }

                if (isLive) {
                    views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
                    views.setViewVisibility(R.id.widget_progress, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_progress, android.view.View.GONE)
                }

                val displayTime = if (timeInfo.isEmpty()) "--" else timeInfo
                views.setTextViewText(R.id.widget_time_info, displayTime)
                val timeColor = when {
                    isLive -> 0xFF10B981.toInt()
                    isUrgent -> 0xFFF59E0B.toInt()
                    else -> if (widgetDarkMode) 0xFFA5B4C5.toInt() else 0xFF64748B.toInt()
                }
                views.setTextColor(R.id.widget_time_info, timeColor)
                views.setTextColor(R.id.widget_refresh, if (widgetDarkMode) 0xFFBFDBFE.toInt() else 0xFF334155.toInt())

                val launchIntent = Intent(context, MainActivity::class.java)
                val launchPending = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, launchPending)
                views.setOnClickPendingIntent(R.id.widget_headline, launchPending)
                views.setOnClickPendingIntent(R.id.widget_subline, launchPending)
                views.setOnClickPendingIntent(R.id.widget_time_info, launchPending)

                val refreshIntent = Intent(context, providerClass).apply {
                    action = UPDATE_ACTION
                }
                val refreshPending = PendingIntent.getBroadcast(
                    context,
                    appWidgetId + 2000,
                    refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_refresh, refreshPending)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Widget update failed: ${e.message}", e)
            }
        }

        private fun updateAllInstances(
            context: Context,
            providerClass: Class<out AppWidgetProvider>,
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context.packageName, providerClass.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId, providerClass)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, ClassTrackerWidget::class.java)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        super.onReceive(context, intent)
        if (intent?.action == UPDATE_ACTION) {
            updateAllInstances(context, ClassTrackerWidget::class.java)
        }
    }
}
