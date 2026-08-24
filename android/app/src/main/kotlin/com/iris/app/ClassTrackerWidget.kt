package com.iris.app

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
            "group.com.iris.app",
            "com.iris.app",
            "HomeWidgetPreferences",
            "FlutterSharedPreferences",
        )
        private const val UPDATE_ACTION = "com.iris.app.WIDGET_UPDATE"

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

                val widgetSubline = prefs.getString("flutter.widget_subline", "") ?: ""
                val teacher = prefs.getString("flutter.current_class_teacher", "") ?: ""
                val batch = prefs.getString("flutter.widget_batch", "") ?: ""
                val progressPercent = prefs.getInt("flutter.progress_percentage", 0).coerceIn(0, 100)
                val timeInfo = prefs.getString("flutter.time_info", "--") ?: "--"
                val isLive = prefs.getBoolean("flutter.is_class_live", false)
                val startTime = prefs.getString("flutter.widget_start_time", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.current_class_end_time", "") ?: ""

                val activeMode = prefs.getString("flutter.active_mode", "classes") ?: "classes"
                val widgetDarkMode = prefs.getBoolean("flutter.widget_dark_mode", true)

                val layoutId = if (widgetDarkMode) R.layout.widget_safe_dark else R.layout.widget_safe
                val views = RemoteViews(context.packageName, layoutId)

                val (widthDp, heightDp) = getWidgetSizeDp(context, appWidgetManager, appWidgetId)

                // Dynamic Luxury Glass Backgrounds matching Active Mode & Light/Dark Theme
                val bgRes = when {
                    activeMode == "vacation" || activeMode == "break" ->
                        if (widgetDarkMode) R.drawable.widget_bg_vacation else R.drawable.widget_bg_vacation_light
                    activeMode == "midterms" || activeMode == "finals" || activeMode == "exams" ->
                        if (widgetDarkMode) R.drawable.widget_bg_exams else R.drawable.widget_bg_exams_light
                    activeMode == "ramadan" ->
                        if (widgetDarkMode) R.drawable.widget_bg_ramadan else R.drawable.widget_bg_ramadan_light
                    activeMode == "sports_week" ->
                        R.drawable.widget_bg_sports
                    isFaculty ->
                        if (widgetDarkMode) R.drawable.widget_bg_faculty else R.drawable.widget_bg_faculty_light
                    isLive ->
                        if (widgetDarkMode) R.drawable.widget_bg_student_live_dark else R.drawable.widget_bg_student_live_light
                    widgetDarkMode ->
                        R.drawable.widget_bg_dark_v2
                    else ->
                        R.drawable.widget_bg_light_v2
                }
                views.setImageViewResource(R.id.widget_glass_bg, bgRes)

                val isCompact = heightDp < 105

                if (isCompact) {
                    views.setViewVisibility(R.id.widget_compact_container, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_full_container, View.GONE)

                    val compactTitle = if (rawRoom.isNotEmpty()) "$subject • $rawRoom" else subject
                    views.setTextViewText(R.id.widget_compact_title, compactTitle)
                    views.setTextViewText(R.id.widget_compact_time, timeInfo)

                    if (activeMode == "vacation" || activeMode == "break") {
                        views.setTextViewText(R.id.widget_compact_badge, "VACATION")
                    } else if (activeMode == "midterms" || activeMode == "finals" || activeMode == "exams") {
                        views.setTextViewText(R.id.widget_compact_badge, "EXAM")
                    } else if (activeMode == "ramadan") {
                        views.setTextViewText(R.id.widget_compact_badge, "RAMADAN")
                    } else if (activeMode == "sports_week") {
                        views.setTextViewText(R.id.widget_compact_badge, "GALA")
                    } else if (isLive) {
                        views.setTextViewText(R.id.widget_compact_badge, if (isFaculty) "TEACHING" else "LIVE")
                    } else {
                        views.setTextViewText(R.id.widget_compact_badge, if (isFaculty) "LECTURE" else "NEXT")
                    }
                } else {
                    views.setViewVisibility(R.id.widget_compact_container, View.GONE)
                    views.setViewVisibility(R.id.widget_full_container, View.VISIBLE)

                    val sublineDetails = when {
                        teacher.isNotEmpty() && rawRoom.isNotEmpty() -> "$teacher • $rawRoom"
                        rawRoom.isNotEmpty() -> rawRoom
                        teacher.isNotEmpty() -> teacher
                        else -> "Academic Block"
                    }

                    if (activeMode == "vacation" || activeMode == "break") {
                        // VACATION & SEMESTER BREAK WIDGET
                        views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_pill_badge_vacation)
                        views.setTextViewText(R.id.widget_status_badge, "🏖️ VACATION MODE")
                        views.setTextViewText(R.id.widget_state_label, "SEMESTER BREAK")
                        
                        val heroColor = if (widgetDarkMode) "#FB7185" else "#E11D48"
                        views.setTextColor(R.id.widget_time_info, android.graphics.Color.parseColor(heroColor))
                        views.setTextViewText(R.id.widget_time_info, if (timeInfo.isNotEmpty() && timeInfo != "--") timeInfo.uppercase() else "RECHARGE & UNWIND")
                        views.setTextViewText(R.id.widget_headline, if (subject.isNotEmpty() && subject != "--") subject else "Campus in Recess")
                        views.setTextViewText(R.id.widget_subline, if (widgetSubline.isNotEmpty() && widgetSubline != "--") widgetSubline else "Zero Active Classes • Enjoy Your Break")
                        views.setTextViewText(R.id.widget_action_text, "Upcoming Schedule 📅")
                        views.setViewVisibility(R.id.widget_progress, View.GONE)
                    } else if (activeMode == "midterms" || activeMode == "finals" || activeMode == "exams") {
                        // EXAM MODE WIDGET
                        val examBadge = if (isLive) "📝 LIVE EXAM" else if (timeInfo.contains("today", ignoreCase = true) || timeInfo.contains("in ", ignoreCase = true)) "📝 EXAM TODAY" else "📝 EXAM SCHEDULE"
                        views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_pill_badge_exam)
                        views.setTextViewText(R.id.widget_status_badge, examBadge)
                        views.setTextViewText(R.id.widget_state_label, "EXAMINATION")
                        
                        val heroColor = if (widgetDarkMode) "#FBBF24" else "#D97706"
                        views.setTextColor(R.id.widget_time_info, android.graphics.Color.parseColor(heroColor))
                        views.setTextViewText(R.id.widget_time_info, if (timeInfo.isNotEmpty() && timeInfo != "--") timeInfo.uppercase() else "UPCOMING")
                        views.setTextViewText(R.id.widget_headline, subject)
                        views.setTextViewText(R.id.widget_subline, if (rawRoom.isNotEmpty()) "Venue: $rawRoom" else "Examination Hall")
                        views.setTextViewText(R.id.widget_action_text, "Exam Room Locator 🏛️")
                        views.setViewVisibility(R.id.widget_progress, View.GONE)
                    } else if (activeMode == "ramadan") {
                        // RAMADAN MODE WIDGET
                        views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_pill_badge_ramadan)
                        views.setTextViewText(R.id.widget_status_badge, if (isLive) "🌙 RAMADAN • LIVE" else "🌙 RAMADAN TIMINGS")
                        views.setTextViewText(R.id.widget_state_label, "1-HR SLOTS")
                        
                        val heroColor = if (widgetDarkMode) "#34D399" else "#059669"
                        views.setTextColor(R.id.widget_time_info, android.graphics.Color.parseColor(heroColor))
                        views.setTextViewText(R.id.widget_time_info, if (timeInfo.isNotEmpty() && timeInfo != "--") timeInfo.uppercase() else "1-HR COMPRESSED")
                        views.setTextViewText(R.id.widget_headline, subject)
                        views.setTextViewText(R.id.widget_subline, sublineDetails)
                        views.setTextViewText(R.id.widget_action_text, "Ramadan Timetable View ⏱️")
                        views.setViewVisibility(R.id.widget_progress, if (isLive) View.VISIBLE else View.GONE)
                        if (isLive) views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
                    } else if (activeMode == "sports_week") {
                        // SPORTS WEEK GALA WIDGET
                        views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_pill_badge_next)
                        views.setTextViewText(R.id.widget_status_badge, "🏆 STUDENTS GALA")
                        views.setTextViewText(R.id.widget_state_label, "SPORTS WEEK")
                        
                        val heroColor = if (widgetDarkMode) "#F97316" else "#EA580C"
                        views.setTextColor(R.id.widget_time_info, android.graphics.Color.parseColor(heroColor))
                        views.setTextViewText(R.id.widget_time_info, if (timeInfo.isNotEmpty() && timeInfo != "--") timeInfo.uppercase() else "GALA ACTIVE")
                        views.setTextViewText(R.id.widget_headline, if (subject.isNotEmpty()) subject else "Campus Sports Week")
                        views.setTextViewText(R.id.widget_subline, if (widgetSubline.isNotEmpty() && widgetSubline != "--") widgetSubline else sublineDetails)
                        views.setTextViewText(R.id.widget_action_text, "Gala Schedule 🏆")
                        views.setViewVisibility(R.id.widget_progress, View.GONE)
                    } else {
                        // REGULAR CLASSES SCENARIOS
                        val isStartsSoon = !isLive && timeInfo.contains("in ", ignoreCase = true) && (timeInfo.contains("min", ignoreCase = true) || timeInfo.contains("m left", ignoreCase = true))
                        val isNextUp = !isLive && (timeInfo.contains("in ", ignoreCase = true) || timeInfo.contains("at ", ignoreCase = true))
                        val isNoClasses = subject.contains("No Classes", ignoreCase = true) || subject.contains("Free", ignoreCase = true)

                        when {
                            isLive -> {
                                val liveBadgeBg = if (isFaculty) R.drawable.widget_pill_badge_faculty else R.drawable.widget_pill_badge_live
                                views.setInt(R.id.widget_status_badge, "setBackgroundResource", liveBadgeBg)
                                views.setTextViewText(R.id.widget_status_badge, if (isFaculty) "● ACTIVE TEACHING" else "● LIVE LECTURE")
                                val heroColor = if (isFaculty) (if (widgetDarkMode) "#C084FC" else "#7C3AED") else (if (widgetDarkMode) "#38BDF8" else "#0284C7")
                                views.setTextColor(R.id.widget_time_info, android.graphics.Color.parseColor(heroColor))
                                views.setTextViewText(R.id.widget_time_info, if (timeInfo.isNotEmpty() && timeInfo != "--") timeInfo.uppercase() else "IN SESSION")
                                views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                                views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
                                views.setTextViewText(R.id.widget_action_text, if (isFaculty) "Attendance & Roll Call 📋" else "Room Route Map 📍")
                            }
                            isStartsSoon -> {
                                views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_pill_badge_live)
                                views.setTextViewText(R.id.widget_status_badge, "⏱️ STARTS SOON")
                                val heroColor = if (widgetDarkMode) "#38BDF8" else "#0284C7"
                                views.setTextColor(R.id.widget_time_info, android.graphics.Color.parseColor(heroColor))
                                views.setTextViewText(R.id.widget_time_info, timeInfo.uppercase())
                                views.setViewVisibility(R.id.widget_progress, View.GONE)
                                views.setTextViewText(R.id.widget_action_text, "Room Route Map 📍")
                            }
                            isNextUp -> {
                                views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_pill_badge_next)
                                views.setTextViewText(R.id.widget_status_badge, if (isFaculty) "NEXT LECTURE" else "📅 NEXT CLASS")
                                val heroColor = if (widgetDarkMode) "#818CF8" else "#4338CA"
                                views.setTextColor(R.id.widget_time_info, android.graphics.Color.parseColor(heroColor))
                                views.setTextViewText(R.id.widget_time_info, timeInfo.uppercase())
                                views.setViewVisibility(R.id.widget_progress, View.GONE)
                                views.setTextViewText(R.id.widget_action_text, "Room Route Map 📍")
                            }
                            isNoClasses -> {
                                views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_pill_badge_next)
                                views.setTextViewText(R.id.widget_status_badge, "🏖️ NO CLASSES")
                                val heroColor = if (widgetDarkMode) "#94A3B8" else "#64748B"
                                views.setTextColor(R.id.widget_time_info, android.graphics.Color.parseColor(heroColor))
                                views.setTextViewText(R.id.widget_time_info, "WEEKEND BREAK")
                                views.setViewVisibility(R.id.widget_progress, View.GONE)
                                views.setTextViewText(R.id.widget_action_text, "Open Timetable 📅")
                            }
                            else -> {
                                views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_pill_badge_next)
                                views.setTextViewText(R.id.widget_status_badge, "✓ ALL DONE TODAY")
                                val heroColor = if (widgetDarkMode) "#94A3B8" else "#64748B"
                                views.setTextColor(R.id.widget_time_info, android.graphics.Color.parseColor(heroColor))
                                views.setTextViewText(R.id.widget_time_info, if (timeInfo.isNotEmpty() && timeInfo != "--") timeInfo.uppercase() else "ALL LECTURES COMPLETE")
                                views.setViewVisibility(R.id.widget_progress, View.GONE)
                                views.setTextViewText(R.id.widget_action_text, "Full Timetable 📅")
                            }
                        }

                        views.setTextViewText(R.id.widget_headline, subject)
                        if (isFaculty) {
                            val facultySub = if (batch.isNotEmpty() && rawRoom.isNotEmpty()) "Batch: $batch • $rawRoom" else (if (batch.isNotEmpty()) "Batch: $batch" else sublineDetails)
                            views.setTextViewText(R.id.widget_subline, facultySub)
                        } else {
                            views.setTextViewText(R.id.widget_subline, sublineDetails)
                        }
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

        private fun getCircularBitmap(src: android.graphics.Bitmap): android.graphics.Bitmap {
            val size = Math.min(src.width, src.height)
            val output = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(output)
            val paint = android.graphics.Paint().apply {
                isAntiAlias = true
                shader = android.graphics.BitmapShader(src, android.graphics.Shader.TileMode.CLAMP, android.graphics.Shader.TileMode.CLAMP)
            }
            val r = size / 2f
            canvas.drawCircle(r, r, r, paint)
            return output
        }

        private fun createInitialsAvatar(name: String, sizePx: Int = 96): android.graphics.Bitmap {
            val bitmap = android.graphics.Bitmap.createBitmap(sizePx, sizePx, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bitmap)
            val paint = android.graphics.Paint().apply {
                isAntiAlias = true
                color = android.graphics.Color.parseColor("#4F46E5")
            }
            canvas.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f, paint)

            val cleanName = name.replace(Regex("(?i)^(dr|prof|mr|mrs|ms)\\.?\\s+"), "").trim()
            val parts = cleanName.split("\\s+".toRegex())
            val initials = when {
                parts.size >= 2 -> "${parts[0].take(1)}${parts[1].take(1)}".uppercase()
                parts.isNotEmpty() && parts[0].isNotEmpty() -> parts[0].take(2).uppercase()
                else -> "FC"
            }

            val textPaint = android.graphics.Paint().apply {
                isAntiAlias = true
                color = android.graphics.Color.WHITE
                textSize = sizePx * 0.42f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                textAlign = android.graphics.Paint.Align.CENTER
            }
            val yPos = (sizePx / 2f) - ((textPaint.descent() + textPaint.ascent()) / 2f)
            canvas.drawText(initials, sizePx / 2f, yPos, textPaint)
            return bitmap
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
