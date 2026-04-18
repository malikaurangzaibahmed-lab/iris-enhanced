package com.example.student_organizer

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class OmniFlowWidgetProvider : AppWidgetProvider() {
    companion object {
        const val ACTION_WIDGET_UPDATE = "com.example.student_organizer.WIDGET_UPDATE"

        private fun updateAllInstances(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context.packageName, OmniFlowWidgetProvider::class.java.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (appWidgetId in appWidgetIds) {
                ClassTrackerWidget.updateAppWidget(
                    context,
                    appWidgetManager,
                    appWidgetId,
                    OmniFlowWidgetProvider::class.java,
                )
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            ClassTrackerWidget.updateAppWidget(
                context,
                appWidgetManager,
                appWidgetId,
                OmniFlowWidgetProvider::class.java,
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        super.onReceive(context, intent)
        if (intent?.action == ACTION_WIDGET_UPDATE) {
            updateAllInstances(context)
        }
    }
}