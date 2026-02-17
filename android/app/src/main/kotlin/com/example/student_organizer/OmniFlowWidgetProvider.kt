package com.example.student_organizer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.view.View
import android.widget.RemoteViews

class OmniFlowWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "OmniFlowWidget"
        private const val PREFS_NAME = "HomeWidgetPreferences"

        // Preference keys MUST match exactly with Dart widget_service.dart
        private const val KEY_CURRENT_CLASS_SUBJECT = "flutter.current_class_subject"
        private const val KEY_CURRENT_CLASS_ROOM = "flutter.current_class_room"
        private const val KEY_CURRENT_CLASS_TEACHER = "flutter.current_class_teacher"
        private const val KEY_CURRENT_CLASS_END_TIME = "flutter.current_class_end_time"
        private const val KEY_NEXT_CLASS_SUBJECT = "flutter.next_class_subject"
        private const val KEY_NEXT_CLASS_START_TIME = "flutter.next_class_start_time"
        private const val KEY_NEXT_CLASS_ROOM = "flutter.next_class_room"
        private const val KEY_PROGRESS_PERCENTAGE = "flutter.progress_percentage"
        private const val KEY_IS_CLASS_LIVE = "flutter.is_class_live"
        private const val KEY_TIME_INFO = "flutter.time_info"
        private const val KEY_IS_URGENT = "flutter.is_urgent"

        const val ACTION_WIDGET_UPDATE = "com.example.student_organizer.WIDGET_UPDATE"

        fun requestUpdate(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, OmniFlowWidgetProvider::class.java)
                )
                Log.d(TAG, "Found ${ids.size} widget instances to update")
                for (id in ids) {
                    updateAppWidget(context, appWidgetManager, id)
                }
            } catch (e: Exception) {
                Log.e(TAG, "🔥 Error requesting widget update: ${e.message}", e)
            }
        }

        private fun updateAppWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                Log.d(TAG, "🔧 Starting widget update for ID: $widgetId")
                val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                
                // Initialize defaults if missing
                initializeDefaultsIfNeeded(prefs)

                // Read all data with safe defaults
                val isClassLive = prefs.getBoolean(KEY_IS_CLASS_LIVE, false)
                val subject = prefs.getString(KEY_CURRENT_CLASS_SUBJECT, "System Idle") ?: "System Idle"
                val room = prefs.getString(KEY_CURRENT_CLASS_ROOM, "No active class") ?: "No active class"
                val teacher = prefs.getString(KEY_CURRENT_CLASS_TEACHER, "") ?: ""
                val endTime = prefs.getString(KEY_CURRENT_CLASS_END_TIME, "--:--") ?: "--:--"
                val progress = prefs.getInt(KEY_PROGRESS_PERCENTAGE, 0).coerceIn(0, 100)
                val timeInfo = prefs.getString(KEY_TIME_INFO, "") ?: ""
                val isUrgent = prefs.getBoolean(KEY_IS_URGENT, false)

                Log.d(TAG, "📊 Data loaded: subject='$subject', isLive=$isClassLive, progress=$progress%")

                // Create RemoteViews - catch any creation errors
                val views = try {
                    RemoteViews(context.packageName, R.layout.widget_layout)
                } catch (e: Exception) {
                    Log.e(TAG, "🔥 Failed to create RemoteViews: ${e.message}", e)
                    return
                }

                // Update views with explicit error handling for each field
                safeSetText(views, R.id.widget_subject, subject)
                
                if (timeInfo.isNotEmpty()) {
                    safeSetText(views, R.id.widget_time_info, timeInfo)
                    safeSetViewVisibility(views, R.id.widget_time_info, View.VISIBLE)
                } else {
                    safeSetViewVisibility(views, R.id.widget_time_info, View.GONE)
                }

                // widget_current removed in new 2x2 layout

                // Live/Idle specific fields
                if (isClassLive) {
                    if (endTime.isNotEmpty() && endTime != "--:--") {
                        safeSetText(views, R.id.widget_time, "Ends $endTime")
                        safeSetViewVisibility(views, R.id.widget_time, View.VISIBLE)
                    } else {
                        safeSetViewVisibility(views, R.id.widget_time, View.GONE)
                    }
                    
                    // Extract room from room string if it contains separator
                    val displayRoom = if (room.contains("·")) {
                        val parts = room.split("·")
                        if (parts.size > 1) parts[1].trim() else room
                    } else {
                        room
                    }
                    safeSetText(views, R.id.widget_room, displayRoom)
                    safeSetViewVisibility(views, R.id.widget_room, View.VISIBLE)
                } else {
                    safeSetViewVisibility(views, R.id.widget_room, View.GONE)
                    safeSetViewVisibility(views, R.id.widget_time, View.GONE)
                }

                // Teacher
                if (teacher.isNotEmpty() && teacher != "--" && teacher != "NA") {
                    safeSetText(views, R.id.widget_teacher, teacher)
                    safeSetViewVisibility(views, R.id.widget_teacher, View.VISIBLE)
                } else {
                    safeSetViewVisibility(views, R.id.widget_teacher, View.GONE)
                }

                // Status indicator dot - Color-coded by lecture type
                if (isClassLive) {
                    val dotColor = getStatusDotColor(subject)
                    safeSetStatusDot(views, dotColor)
                    safeSetViewVisibility(views, R.id.status_dot, View.VISIBLE)
                } else {
                    safeSetViewVisibility(views, R.id.status_dot, View.GONE)
                }

                // Progress bar
                safeSetProgress(views, R.id.widget_progress, 100, progress)

                // Set up click listeners
                setupClickListeners(context, views, widgetId)

                // Final update attempt
                try {
                    manager.updateAppWidget(widgetId, views)
                    Log.d(TAG, "✅ Successfully updated widget $widgetId")
                } catch (e: Exception) {
                    Log.e(TAG, "🔥 Error calling updateAppWidget: ${e.message}", e)
                }
            } catch (e: Exception) {
                Log.e(TAG, "🔥 Widget update failed: ${e.message}", e)
            }
        }

        private fun initializeDefaultsIfNeeded(prefs: SharedPreferences) {
            if (!prefs.contains(KEY_CURRENT_CLASS_SUBJECT)) {
                Log.w(TAG, "Initializing default widget preferences")
                try {
                    val editor = prefs.edit()
                    editor.putBoolean(KEY_IS_CLASS_LIVE, false)
                    editor.putString(KEY_CURRENT_CLASS_SUBJECT, "System Idle")
                    editor.putString(KEY_CURRENT_CLASS_ROOM, "No active class")
                    editor.putString(KEY_CURRENT_CLASS_TEACHER, "")
                    editor.putString(KEY_CURRENT_CLASS_END_TIME, "--:--")
                    editor.putInt(KEY_PROGRESS_PERCENTAGE, 0)
                    editor.putString(KEY_TIME_INFO, "")
                    editor.putBoolean(KEY_IS_URGENT, false)
                    editor.apply()
                    Log.d(TAG, "✅ Defaults initialized")
                } catch (e: Exception) {
                    Log.e(TAG, "Error initializing defaults: ${e.message}")
                }
            }
        }

        private fun safeSetText(views: RemoteViews, viewId: Int, text: String) {
            try {
                views.setTextViewText(viewId, text)
            } catch (e: Exception) {
                Log.w(TAG, "Could not set text for view $viewId: ${e.message}")
            }
        }

        private fun safeSetViewVisibility(views: RemoteViews, viewId: Int, visibility: Int) {
            try {
                views.setViewVisibility(viewId, visibility)
            } catch (e: Exception) {
                Log.w(TAG, "Could not set visibility for view $viewId: ${e.message}")
            }
        }

        private fun safeSetProgress(views: RemoteViews, viewId: Int, max: Int, progress: Int) {
            try {
                views.setProgressBar(viewId, max, progress, false)
            } catch (e: Exception) {
                Log.w(TAG, "Could not set progress for view $viewId: ${e.message}")
            }
        }

        private fun getStatusDotColor(subject: String): Int {
            // Color code by subject type keywords
            val subjectLower = subject.lowercase()
            return when {
                // Green for labs/practical/project
                subjectLower.contains("lab") || 
                subjectLower.contains("practical") || 
                subjectLower.contains("project") ||
                subjectLower.contains("studio") -> R.drawable.status_dot_green
                
                // Red for special/seminar/workshop/urgent
                subjectLower.contains("seminar") || 
                subjectLower.contains("workshop") || 
                subjectLower.contains("assignment") ||
                subjectLower.contains("presentation") -> R.drawable.status_dot_red
                
                // Blue for regular lectures (default)
                else -> R.drawable.status_dot_blue
            }
        }

        private fun safeSetStatusDot(views: RemoteViews, drawableId: Int) {
            try {
                views.setImageViewResource(R.id.status_dot, drawableId)
            } catch (e: Exception) {
                Log.w(TAG, "Could not set status dot: ${e.message}")
            }
        }

        private fun setupClickListeners(context: Context, views: RemoteViews, widgetId: Int) {
            try {
                // Click to open app
                val intent = Intent(context, MainActivity::class.java)
                val pending = PendingIntent.getActivity(
                    context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_subject, pending)

                // Refresh button
                val refreshIntent = Intent(context, OmniFlowWidgetProvider::class.java).apply {
                    action = ACTION_WIDGET_UPDATE
                }
                val refreshPending = PendingIntent.getBroadcast(
                    context, widgetId + 1000, refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_refresh, refreshPending)
            } catch (e: Exception) {
                Log.w(TAG, "Could not set click listeners: ${e.message}")
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d(TAG, "onUpdate called with ${appWidgetIds.size} widgets")
        for (id in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "onReceive: ${intent?.action}")
        super.onReceive(context, intent)
        if (intent?.action == ACTION_WIDGET_UPDATE) {
            requestUpdate(context)
        }
    }
}
