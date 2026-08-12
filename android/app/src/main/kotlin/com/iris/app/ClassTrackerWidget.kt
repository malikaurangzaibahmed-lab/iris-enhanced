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

                        val teacherImageUrl = prefs.getString("flutter.teacher_image_url", "") ?: ""
                        var avatarLoaded = false

                        if (teacherImageUrl.isNotEmpty()) {
                            try {
                                if (teacherImageUrl.startsWith("assets/")) {
                                    val assetPath = teacherImageUrl.substring("assets/".length)
                                    context.assets.open(assetPath).use { inputStream ->
                                        val srcBitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
                                        if (srcBitmap != null) {
                                            views.setImageViewBitmap(R.id.widget_teacher_avatar, getCircularBitmap(srcBitmap))
                                            avatarLoaded = true
                                        }
                                    }
                                } else if (java.io.File(teacherImageUrl).exists()) {
                                    val srcBitmap = android.graphics.BitmapFactory.decodeFile(teacherImageUrl)
                                    if (srcBitmap != null) {
                                        views.setImageViewBitmap(R.id.widget_teacher_avatar, getCircularBitmap(srcBitmap))
                                        avatarLoaded = true
                                    }
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to load teacher avatar bitmap: ${e.message}")
                            }
                        }

                        if (!avatarLoaded) {
                            try {
                                val initialsBitmap = createInitialsAvatar(teacher)
                                views.setImageViewBitmap(R.id.widget_teacher_avatar, initialsBitmap)
                            } catch (e: Exception) {
                                views.setImageViewResource(R.id.widget_teacher_avatar, R.drawable.widget_ic_teacher_avatar)
                            }
                        }
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
