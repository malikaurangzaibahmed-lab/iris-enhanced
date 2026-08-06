package com.example.student_organizer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews

class PortalTasksWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "PortalTasksWidget"
        private val PREFS_NAMES = arrayOf(
            "group.com.example.student_organizer",
            "com.example.student_organizer_preferences",
            "com.example.student_organizer",
            "HomeWidgetPreferences",
            "FlutterSharedPreferences"
        )
        private const val UPDATE_ACTION = "com.example.student_organizer.PORTAL_WIDGET_UPDATE"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                var prefs: SharedPreferences? = null
                for (prefsName in PREFS_NAMES) {
                    val candidate = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    if (candidate.contains("flutter.portal_task_count") ||
                        candidate.contains("flutter.portal_tasks_json")) {
                        prefs = candidate
                        break
                    }
                }
                if (prefs == null) {
                    prefs = context.getSharedPreferences(PREFS_NAMES[0], Context.MODE_PRIVATE)
                }

                val count = prefs.getInt("flutter.portal_task_count", 0)
                val lastSync = prefs.getString("flutter.portal_last_sync", "Not Synced") ?: "Not Synced"
                val widgetDarkMode = prefs.getBoolean("flutter.widget_dark_mode", false)

                val layoutId = if (widgetDarkMode) R.layout.widget_portal_tasks_dark else R.layout.widget_portal_tasks
                val views = RemoteViews(context.packageName, layoutId)

                // Apply Liquid Glass background effect if supported (Android 13+)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    Log.d(TAG, "Generating LiquidGlass background for PortalTasksWidget $appWidgetId")
                    try {
                        val sizePx = getWidgetSizePx(context, appWidgetManager, appWidgetId)
                        val bgRes = if (widgetDarkMode) R.drawable.widget_fluffy_dark_bg else R.drawable.widget_fluffy_bg
                        val glassBitmap = LiquidGlassBitmapGenerator.generateGlassBitmap(
                            context,
                            sizePx.first,
                            sizePx.second,
                            bgRes,
                            widgetDarkMode,
                        )
                        if (glassBitmap != null) {
                            views.setImageViewBitmap(R.id.widget_glass_bg, glassBitmap)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "LiquidGlass background generation failed: ${e.message}", e)
                    }
                }

                views.setTextViewText(R.id.widget_last_sync, lastSync)

                if (count == 0) {
                    views.setViewVisibility(R.id.widget_tasks_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_empty_state, View.GONE)
                    views.setViewVisibility(R.id.widget_tasks_list, View.VISIBLE)

                    // Bind RemoteViewsService to ListView
                    val serviceIntent = Intent(context, PortalTasksWidgetService::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        // Make intent unique to force update
                        data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                    }
                    views.setRemoteAdapter(R.id.widget_tasks_list, serviceIntent)
                }

                // Click Intent to open app on clicking header title
                val launchIntent = Intent(context, MainActivity::class.java)
                val launchPending = PendingIntent.getActivity(
                    context,
                    appWidgetId + 3000,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_title, launchPending)
                views.setOnClickPendingIntent(R.id.widget_last_sync, launchPending)

                // List item pending intent template (opens app when task is clicked)
                val taskLaunchIntent = Intent(context, MainActivity::class.java)
                val taskLaunchPending = PendingIntent.getActivity(
                    context,
                    appWidgetId + 4000,
                    taskLaunchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setPendingIntentTemplate(R.id.widget_tasks_list, taskLaunchPending)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_tasks_list)
            } catch (e: Exception) {
                Log.e(TAG, "PortalTasksWidget update failed: ${e.message}", e)
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

            val dm: android.util.DisplayMetrics = context.resources.displayMetrics
            val widthPx = (widthDp * dm.density).toInt().coerceAtLeast(240)
            val heightPx = (heightDp * dm.density).toInt().coerceAtLeast(140)
            return Pair(widthPx, heightPx)
        }

        private fun updateAllInstances(
            context: Context
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context.packageName, PortalTasksWidget::class.java.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent?) {
        super.onReceive(context, intent)
        if (intent?.action == UPDATE_ACTION || intent?.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            updateAllInstances(context)
        }
    }
}
