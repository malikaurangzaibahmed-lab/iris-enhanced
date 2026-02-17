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

class ClassTrackerWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "ClassTrackerWidget"
        // Try multiple preference store names since home_widget might use different names
        private val PREFS_NAMES = arrayOf(
            "com.example.student_organizer",  // App group ID
            "HomeWidgetPreferences",          // Standard home_widget name
            "FlutterSharedPreferences",       // Flutter's native prefs
        )
        private const val UPDATE_ACTION = "com.example.student_organizer.WIDGET_UPDATE"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                Log.d(TAG, "Updating widget $appWidgetId")
                
                // Try to read from multiple possible preference stores
                var prefs: SharedPreferences? = null
                for (prefsName in PREFS_NAMES) {
                    val candidate = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    // Check if this prefs store has our data
                    if (candidate.contains("flutter.widget_headline") || 
                        candidate.contains("flutter.current_class_subject")) {
                        prefs = candidate
                        Log.d(TAG, "Found widget data in prefs: $prefsName")
                        break
                    }
                }
                
                // If no data found, use the app group ID as fallback
                if (prefs == null) {
                    Log.w(TAG, "Widget data not found in any prefs store, using default")
                    prefs = context.getSharedPreferences(PREFS_NAMES[0], Context.MODE_PRIVATE)
                }
                
                // Read temporal insight data with safe defaults
                val headline = prefs.getString("flutter.widget_headline", "System Idle") ?: "System Idle"
                val subline = prefs.getString("flutter.widget_subline", "No active class") ?: "No active class"
                val teacher = prefs.getString("flutter.current_class_teacher", "") ?: ""
                val progressPercent = prefs.getInt("flutter.progress_percentage", 0).coerceIn(0, 100)
                val timeInfo = prefs.getString("flutter.time_info", "--") ?: "--"
                val isLive = prefs.getBoolean("flutter.is_class_live", false)
                val isUrgent = prefs.getBoolean("flutter.is_urgent", false)
                val widgetDarkMode = prefs.getBoolean("flutter.widget_dark_mode", false)
                
                Log.d(TAG, "Loaded: headline=$headline, live=$isLive, urgent=$isUrgent, darkMode=$widgetDarkMode")

                val views = RemoteViews(context.packageName, R.layout.widget)
                
                // Set headline
                views.setTextViewText(R.id.widget_headline, headline)
                
                // Apply color based on state and dark mode
                val textColorDark = 0xFF6366F1.toInt()  // Indigo
                val textColorLight = 0xFF1E293B.toInt() // Dark slate (light mode)
                val headlineColor = when {
                    isLive -> 0xFF10B981.toInt()        // Green for live
                    isUrgent -> 0xFFEF4444.toInt()      // Red for urgent
                    else -> if (widgetDarkMode) textColorDark else textColorLight
                }
                views.setTextColor(R.id.widget_headline, headlineColor)
                
                // Set subline
                views.setTextViewText(R.id.widget_subline, subline)
                val sublineColor = if (widgetDarkMode) 0xFFF5F5F5.toInt() else 0xFF333333.toInt()
                views.setTextColor(R.id.widget_subline, sublineColor)
                
                // Set teacher info if available
                if (teacher.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_teacher_info, teacher)
                    val teacherColor = if (widgetDarkMode) 0xFFA0A0A0.toInt() else 0xFF666666.toInt()
                    views.setTextColor(R.id.widget_teacher_info, teacherColor)
                    views.setViewVisibility(R.id.widget_teacher_info, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_teacher_info, android.view.View.GONE)
                }
                
                // Show/hide progress bar only if live
                if (isLive) {
                    views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
                    views.setViewVisibility(R.id.widget_progress, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_progress, android.view.View.GONE)
                }
                
                // Show/hide live indicator
                if (isLive) {
                    views.setViewVisibility(R.id.widget_live_indicator, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_live_indicator, android.view.View.GONE)
                }
                
                // Set time info
                views.setTextViewText(R.id.widget_time_info, if (timeInfo.isEmpty()) "--" else timeInfo)
                val timeColor = if (widgetDarkMode) 0xFF888888.toInt() else 0xFF777777.toInt()
                views.setTextColor(R.id.widget_time_info, timeColor)

                // Launch app on click
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(context, 0, intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_headline, pendingIntent)
                views.setOnClickPendingIntent(R.id.widget_subline, pendingIntent)
                views.setOnClickPendingIntent(R.id.widget_time_info, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                Log.d(TAG, "✅ Successfully updated widget $appWidgetId")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error updating widget: ${e.message}", e)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d(TAG, "onUpdate called with ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "onReceive: ${intent?.action}")
        super.onReceive(context, intent)
        if (intent?.action == UPDATE_ACTION) {
            Log.d(TAG, "Received widget update broadcast")
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context.packageName, ClassTrackerWidget::class.java.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        Log.d(TAG, "Widget disabled")
    }
}
