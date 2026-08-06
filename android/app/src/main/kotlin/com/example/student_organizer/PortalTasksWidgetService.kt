package com.example.student_organizer

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class PortalTasksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return PortalTasksRemoteViewsFactory(this.applicationContext)
    }
}

class PortalTasksRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val PREFS_NAMES = arrayOf(
        "group.com.example.student_organizer",
        "com.example.student_organizer_preferences",
        "com.example.student_organizer",
        "HomeWidgetPreferences",
        "FlutterSharedPreferences"
    )

    private data class TaskItem(
        val title: String,
        val subject: String,
        val due: String,
        val urgent: Boolean,
        val type: String,
        val isHeader: Boolean = false
    )

    private val tasksList = ArrayList<TaskItem>()
    private var widgetDarkMode = false

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        tasksList.clear()
        try {
            var prefs: SharedPreferences? = null
            var matchedFile = "None"
            for (prefsName in PREFS_NAMES) {
                val candidate = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                if (candidate.contains("flutter.portal_tasks_json")) {
                    prefs = candidate
                    matchedFile = prefsName
                    break
                }
            }
            if (prefs == null) {
                prefs = context.getSharedPreferences(PREFS_NAMES[0], Context.MODE_PRIVATE)
                matchedFile = "Fallback: " + PREFS_NAMES[0]
            }

            Log.d("PortalTasksWidget", "Using preferences file: $matchedFile")
            widgetDarkMode = prefs.getBoolean("flutter.widget_dark_mode", false)
            val jsonStr = prefs.getString("flutter.portal_tasks_json", null)
            Log.d("PortalTasksWidget", "Loaded JSON from storage: $jsonStr, Mode: Dark=$widgetDarkMode")
            
            if (jsonStr != null) {
                val rawTasks = ArrayList<TaskItem>()
                val array = JSONArray(jsonStr)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    rawTasks.add(
                        TaskItem(
                            title = obj.optString("title", "No Title"),
                            subject = obj.optString("subject", "No Subject"),
                            due = obj.optString("due", ""),
                            urgent = obj.optBoolean("urgent", false),
                            type = obj.optString("type", "ASSIGNMENT"),
                            isHeader = false
                        )
                    )
                }

                // Group tasks: Quizzes and Assignments separately to build gorgeous separators/barriers
                val quizzes = rawTasks.filter { it.type.contains("QUIZ", ignoreCase = true) }
                val assignments = rawTasks.filter { !it.type.contains("QUIZ", ignoreCase = true) }

                if (quizzes.isNotEmpty()) {
                    tasksList.add(TaskItem(title = "QUIZZES", subject = "", due = "", urgent = false, type = "QUIZ", isHeader = true))
                    tasksList.addAll(quizzes)
                }
                if (assignments.isNotEmpty()) {
                    tasksList.add(TaskItem(title = "ASSIGNMENTS", subject = "", due = "", urgent = false, type = "ASSIGNMENT", isHeader = true))
                    tasksList.addAll(assignments)
                }
            }
        } catch (e: Exception) {
            Log.e("PortalTasksWidget", "Error parsing tasks JSON: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        tasksList.clear()
    }

    override fun getCount(): Int {
        return tasksList.size
    }

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= tasksList.size) return null

        val task = tasksList[position]

        if (task.isHeader) {
            val layoutId = if (widgetDarkMode) R.layout.widget_portal_task_header_dark else R.layout.widget_portal_task_header
            val views = RemoteViews(context.packageName, layoutId)
            
            views.setTextViewText(R.id.header_title, task.title)
            
            // Dynamic premium accent bar color: Pink/Magenta for Quizzes, Cobalt Blue for Assignments
            val barColor = if (task.type.contains("QUIZ", ignoreCase = true)) {
                if (widgetDarkMode) 0xFFEC4899.toInt() else 0xFFDB2777.toInt()
            } else {
                if (widgetDarkMode) 0xFF3B82F6.toInt() else 0xFF1D4ED8.toInt()
            }
            try {
                views.setInt(R.id.header_bar, "setBackgroundColor", barColor)
            } catch (e: Exception) {
                // Fail-safe
            }
            return views
        }

        val layoutId = if (widgetDarkMode) R.layout.widget_portal_task_item_dark else R.layout.widget_portal_task_item
        val views = RemoteViews(context.packageName, layoutId)

        views.setTextViewText(R.id.task_title_text, task.title)
        views.setTextViewText(R.id.task_course_tag, task.subject)
        views.setTextViewText(R.id.task_due_time, if (task.due.isNotEmpty()) task.due else "Due Soon")
        views.setTextViewText(R.id.task_due_date, "11:59 PM")

        val isQuiz = task.type.contains("QUIZ", ignoreCase = true)
        
        // 1. Premium Pill Badge Styling
        if (isQuiz) {
            views.setTextViewText(R.id.task_type_badge, "✦ QUIZ")
        } else {
            views.setTextViewText(R.id.task_type_badge, "ASSIGNMENT")
        }

        // Click fills in pending template to open app when item is clicked
        val fillInIntent = Intent()
        views.setOnClickFillInIntent(R.id.widget_item_root, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 2 // Supports 2 layout types: 0 = Task Item, 1 = Header Barrier
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }
}
