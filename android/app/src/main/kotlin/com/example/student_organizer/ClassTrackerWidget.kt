package com.example.student_organizer

import android.app.PendingIntent
import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Movie
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.os.SystemClock
import android.util.DisplayMetrics
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.os.Build
import kotlin.math.sin
import kotlin.math.cos

class ClassTrackerWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "ClassTrackerWidget"
        private const val LIGHT_GIF_ASSET_PATH = "flutter_assets/assets/widget_bg_light.gif"
        private const val DARK_GIF_ASSET_PATH = "flutter_assets/assets/widget_bg_dark.gif"
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

                val subline = prefs.getString("flutter.widget_subline", "")?.takeIf { it.isNotEmpty() }
                    ?: if (rawRoom.isNotEmpty()) rawRoom else "No active class"

                val teacher = prefs.getString("flutter.current_class_teacher", "") ?: ""
                val progressPercent = prefs.getInt("flutter.progress_percentage", 0).coerceIn(0, 100)
                val timeInfo = prefs.getString("flutter.time_info", "--") ?: "--"
                val isLive = prefs.getBoolean("flutter.is_class_live", false)
                val isUrgent = prefs.getBoolean("flutter.is_urgent", false)
                val widgetDarkMode = prefs.getBoolean("flutter.widget_dark_mode", false)
                val startTime = prefs.getString("flutter.widget_start_time", "")?.takeIf { it.isNotEmpty() }
                    ?: prefs.getString("flutter.current_class_end_time", "") ?: ""

                val layoutId = if (widgetDarkMode) R.layout.widget_safe_dark else R.layout.widget_safe
                val views = try {
                    RemoteViews(context.packageName, layoutId)
                } catch (e: Exception) {
                    Log.e(TAG, "Widget layout inflate failed: ${e.message}", e)
                    return
                }

                val sizePx = getWidgetSizePx(context, appWidgetManager, appWidgetId)

                // Dynamically select role-based & academic period liquid glass background picture
                val role = prefs.getString("flutter.active_role", "student") ?: "student"
                val period = prefs.getString("active_academic_period", "classes") ?: "classes"
                
                val assetName = when {
                    period == "midterms" || period == "finals" || period == "exams" -> "widget_bg_exams.png"
                    period == "sports_week" || period == "students_week" || period == "gala" -> "widget_bg_sports.png"
                    role == "faculty" && (isLive || isUrgent) -> "widget_bg_faculty.png"
                    role == "faculty" -> "widget_bg_idle.png"
                    isLive || isUrgent -> "widget_bg_student.png"
                    else -> "widget_bg_idle.png"
                }
                
                val bgXmlRes = when {
                    period == "midterms" || period == "finals" || period == "exams" -> R.drawable.widget_bg_exams
                    period == "sports_week" || period == "students_week" || period == "gala" -> R.drawable.widget_bg_sports
                    role == "faculty" && (isLive || isUrgent) -> R.drawable.widget_bg_faculty
                    role == "faculty" -> R.drawable.widget_bg_idle
                    isLive || isUrgent -> R.drawable.widget_bg_student
                    else -> R.drawable.widget_bg_idle
                }

                val glassBitmap = loadAssetBitmap(context, assetName)
                if (glassBitmap != null) {
                    views.setImageViewBitmap(R.id.widget_glass_bg, glassBitmap)
                } else {
                    views.setImageViewResource(R.id.widget_glass_bg, bgXmlRes)
                }

                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).let { if (it <= 0) 180 else it }
                val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).let { if (it <= 0) 110 else it }

                val isShortHeight = heightDp < 90
                val isNarrowWidth = widthDp < 120
                val isUltraCompact = heightDp < 80 || widthDp < 100

                // 1. Contextual Subheader & Subject Headline
                val finalSubject = subject
                val finalStateLabel = when {
                    period == "midterms" || period == "finals" || period == "exams" -> "EXAM DATESHEET"
                    period == "sports_week" || period == "students_week" || period == "gala" -> "STUDENTS WEEK"
                    role == "faculty" -> "FACULTY SCHEDULE"
                    isLive -> "CURRENT LECTURE"
                    isUrgent -> "UPCOMING LECTURE"
                    subject.isEmpty() || subject == "All classes completed" -> "SYSTEM IDLE"
                    else -> "TIMETABLE INSIGHT"
                }
                
                if (isShortHeight || isUltraCompact) {
                    views.setInt(R.id.widget_headline, "setMaxLines", 1)
                    views.setTextViewTextSize(R.id.widget_headline, android.util.TypedValue.COMPLEX_UNIT_SP, 13.5f)
                } else {
                    views.setInt(R.id.widget_headline, "setMaxLines", 2)
                    views.setTextViewTextSize(R.id.widget_headline, android.util.TypedValue.COMPLEX_UNIT_SP, 16.5f)
                }

                if (isNarrowWidth || isUltraCompact) {
                    views.setViewVisibility(R.id.widget_state_label, View.GONE)
                } else {
                    views.setTextViewText(R.id.widget_state_label, finalStateLabel)
                    views.setViewVisibility(R.id.widget_state_label, View.VISIBLE)
                }
                views.setTextViewText(R.id.widget_headline, finalSubject)

                // 2. Color Coding State Indicator & Status Badge
                val stateColor = if (widgetDarkMode) 0xFFA5B4C5.toInt() else 0xFF475569.toInt()
                views.setTextColor(R.id.widget_state_label, stateColor)

                when {
                    period == "midterms" -> {
                        views.setTextViewText(R.id.widget_status_badge, "✍️ MIDTERM")
                        views.setTextColor(R.id.widget_status_badge, 0xFFF59E0B.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                    period == "finals" -> {
                        views.setTextViewText(R.id.widget_status_badge, "🎓 FINAL EXAM")
                        views.setTextColor(R.id.widget_status_badge, 0xFF8B5CF6.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                    period == "ramadan" -> {
                        views.setTextViewText(R.id.widget_status_badge, "🌙 RAMADAN")
                        views.setTextColor(R.id.widget_status_badge, 0xFF10B981.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                    period == "sports_week" || period == "students_week" -> {
                        views.setTextViewText(R.id.widget_status_badge, "🏆 SPORTS GALA")
                        views.setTextColor(R.id.widget_status_badge, 0xFF06B6D4.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                    isLive -> {
                        views.setTextViewText(R.id.widget_status_badge, "🔴 LIVE")
                        views.setTextColor(R.id.widget_status_badge, 0xFF10B981.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                    isUrgent -> {
                        views.setTextViewText(R.id.widget_status_badge, "⚡ SOON")
                        views.setTextColor(R.id.widget_status_badge, 0xFFF59E0B.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                    else -> {
                        views.setTextViewText(R.id.widget_status_badge, "NEXT")
                        views.setTextColor(R.id.widget_status_badge, if (widgetDarkMode) 0xFF8BB5FF.toInt() else 0xFF5B7FFF.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                }

                // 3. Intermediate Capsule (Time and Room)
                val displayRoom = when {
                    rawRoom.isEmpty() -> ""
                    rawRoom.startsWith("Room") || rawRoom.startsWith("Hall") || rawRoom.startsWith("Lab") -> rawRoom
                    period == "midterms" || period == "finals" || period == "exams" -> "Exam Hall: $rawRoom"
                    else -> "Room $rawRoom"
                }

                if (startTime.isNotEmpty() || displayRoom.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_class_details_capsule, View.VISIBLE)
                    views.setTextViewText(R.id.widget_details_start_time, if (startTime.isNotEmpty()) startTime else "--")
                    views.setViewVisibility(R.id.widget_details_divider, if (displayRoom.isNotEmpty()) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.widget_details_loc_icon, if (displayRoom.isNotEmpty()) View.VISIBLE else View.GONE)
                    views.setTextViewText(R.id.widget_details_room, displayRoom)
                    views.setViewVisibility(R.id.widget_details_room, if (displayRoom.isNotEmpty()) View.VISIBLE else View.GONE)
                } else if (subline.isNotEmpty() && subline != "No active class" && subline != "Loading schedule...") {
                    views.setViewVisibility(R.id.widget_class_details_capsule, View.VISIBLE)
                    views.setTextViewText(R.id.widget_details_start_time, subline)
                    views.setViewVisibility(R.id.widget_details_divider, View.GONE)
                    views.setViewVisibility(R.id.widget_details_loc_icon, View.GONE)
                    views.setViewVisibility(R.id.widget_details_room, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_class_details_capsule, View.GONE)
                }

                // 4. Translucent Role Subcard (Faculty = BATCH, Student = INSTRUCTOR, Exam = INVIGILATOR)
                val subcardLabel = when {
                    period == "midterms" || period == "finals" || period == "exams" -> "INVIGILATOR"
                    role == "faculty" -> "STUDENT BATCH"
                    else -> "INSTRUCTOR"
                }

                val displaySubcardText = if (role == "faculty") {
                    val batch = prefs.getString("flutter.faculty_assigned_batch", "")?.takeIf { it.isNotEmpty() }
                        ?: prefs.getString("flutter.widget_batch", "")?.takeIf { it.isNotEmpty() }
                        ?: teacher
                    if (batch.isNotEmpty()) batch else "BSCS-4A"
                } else {
                    teacher
                }

                try {
                    views.setTextViewText(R.id.widget_teacher_label, subcardLabel)
                } catch (e: Exception) {
                    Log.w(TAG, "widget_teacher_label set failed", e)
                }

                if (displaySubcardText.isNotEmpty() && !isShortHeight) {
                    views.setTextViewText(R.id.widget_teacher_name, displaySubcardText)
                    views.setViewVisibility(R.id.widget_teacher_card, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_teacher_card, View.GONE)
                }

                // 5. Progress Bar
                if (isLive && !isShortHeight) {
                    views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
                    views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_progress, View.GONE)
                }

                // 6. Bottom Countdown Text
                val displayTime = if (timeInfo.isEmpty()) "--" else timeInfo
                views.setTextViewText(R.id.widget_time_info, displayTime)
                val timeColor = when {
                    isLive -> 0xFF10B981.toInt()
                    isUrgent -> 0xFFF59E0B.toInt()
                    else -> if (widgetDarkMode) 0xFF8BB5FF.toInt() else 0xFF5B7FFF.toInt()
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

            val dm: DisplayMetrics = context.resources.displayMetrics
            val widthPx = (widthDp * dm.density).toInt().coerceAtLeast(240)
            val heightPx = (heightDp * dm.density).toInt().coerceAtLeast(140)
            return Pair(widthPx, heightPx)
        }

        private fun getWidgetSizeCategory(widthPx: Int): String = when {
            widthPx < 320 -> "SMALL"
            widthPx < 480 -> "MEDIUM"
            else -> "LARGE"
        }

        private fun getOverlayAlphaForSize(baseAlpha: Int, sizeCategory: String): Int = when (sizeCategory) {
            "SMALL" -> (baseAlpha * 1.04f).toInt().coerceIn(0, 255)
            "MEDIUM" -> baseAlpha
            "LARGE" -> (baseAlpha * 0.92f).toInt().coerceIn(0, 255)
            else -> baseAlpha
        }

        private fun applyFocalHighlight(
            canvas: Canvas,
            widthPx: Int,
            heightPx: Int,
            isDark: Boolean,
        ) {
            val focalPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    widthPx * 0.28f,
                    heightPx * 0.22f,
                    widthPx * 0.48f,
                    intArrayOf(
                        if (isDark) Color.argb(72, 120, 170, 255) else Color.argb(64, 255, 255, 255),
                        Color.TRANSPARENT,
                    ),
                    floatArrayOf(0f, 1f),
                    Shader.TileMode.CLAMP,
                )
            }
            canvas.drawRect(0f, 0f, widthPx.toFloat(), heightPx.toFloat(), focalPaint)
        }

        private fun applyMotionAccents(
            canvas: Canvas,
            widthPx: Int,
            heightPx: Int,
            isLive: Boolean,
            isUrgent: Boolean,
            isDark: Boolean,
        ) {
            if (isLive) {
                val phase = (SystemClock.elapsedRealtime() % 1600L) / 1600f
                val pulseAlpha = (70 + (24 * sin(phase * 2 * 3.14159f))).toInt().coerceIn(0, 255)
                val pulsePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.argb(pulseAlpha, 34, 197, 94)
                }
                val pulseRadius = (widthPx * (0.16f + 0.04f * sin(phase * 2 * 3.14159f))).toInt()
                canvas.drawCircle(widthPx * 0.86f, heightPx * 0.14f, pulseRadius.toFloat(), pulsePaint)
            } else if (isUrgent) {
                val phase = (SystemClock.elapsedRealtime() % 2000L) / 2000f
                val sweepX = (phase * (widthPx + 140)) - 140
                val sweepPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(
                        sweepX,
                        0f,
                        sweepX + 100,
                        heightPx.toFloat(),
                        Color.argb(0, 245, 158, 11),
                        Color.argb(40, 245, 158, 11),
                        Shader.TileMode.CLAMP,
                    )
                }
                canvas.drawRect(sweepX, 0f, sweepX + 100, heightPx.toFloat(), sweepPaint)
            } else {
                val phase = (SystemClock.elapsedRealtime() % 3200L) / 3200f
                val driftAlpha = (22 + (10 * cos(phase * 2 * 3.14159f))).toInt().coerceIn(0, 255)
                val driftPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.argb(driftAlpha, if (isDark) 116 else 220, if (isDark) 180 else 235, 255)
                }
                val driftX = widthPx * (0.54f + 0.09f * cos(phase * 2 * 3.14159f))
                canvas.drawCircle(driftX, heightPx * 0.67f, (widthPx * 0.10f), driftPaint)
            }
        }

        private fun applyGifBackground(
            context: Context,
            views: RemoteViews,
            widthPx: Int,
            heightPx: Int,
            widgetDarkMode: Boolean,
            isLive: Boolean,
            isUrgent: Boolean,
            progressPercent: Int,
        ): Boolean {
            return try {
                val gifPath = if (widgetDarkMode) DARK_GIF_ASSET_PATH else LIGHT_GIF_ASSET_PATH
                context.assets.open(gifPath).use { gifStream ->
                    val movie = Movie.decodeStream(gifStream) ?: return false
                    val duration = movie.duration().takeIf { it > 0 } ?: 1200
                    val speedMultiplier = when {
                        isLive -> 2.5f
                        isUrgent -> 2.1f
                        else -> 1.7f
                    }
                    val phaseOffset = ((progressPercent * 41L) + (if (isLive) 520L else if (isUrgent) 280L else 0L))
                    val syntheticTime = ((SystemClock.elapsedRealtime() * speedMultiplier) + phaseOffset).toLong()
                    val timeMs = (syntheticTime % duration).toInt()
                    movie.setTime(timeMs)

                    val out = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(out)

                    val movieW = movie.width().coerceAtLeast(1)
                    val movieH = movie.height().coerceAtLeast(1)
                    val scale = maxOf(widthPx.toFloat() / movieW.toFloat(), heightPx.toFloat() / movieH.toFloat())

                    canvas.save()
                    canvas.scale(scale, scale)
                    val drawX = (widthPx / scale - movieW) / 2f
                    val drawY = (heightPx / scale - movieH) / 2f
                    movie.draw(canvas, drawX, drawY)
                    canvas.restore()

                    val sizeCategory = getWidgetSizeCategory(widthPx)

                    // State-aware overlay keeps text readable and preserves IRIS visual language.
                    val baseOverlay = when {
                        widgetDarkMode && isLive -> Color.argb(86, 5, 20, 18)
                        widgetDarkMode && isUrgent -> Color.argb(92, 26, 18, 6)
                        widgetDarkMode -> Color.argb(104, 8, 16, 28)
                        isLive -> Color.argb(58, 241, 255, 251)
                        isUrgent -> Color.argb(62, 255, 249, 236)
                        else -> Color.argb(68, 244, 248, 255)
                    }
                    val adjustedOverlayAlpha = getOverlayAlphaForSize(Color.alpha(baseOverlay), sizeCategory)
                    val overlay = Color.argb(
                        adjustedOverlayAlpha,
                        Color.red(baseOverlay),
                        Color.green(baseOverlay),
                        Color.blue(baseOverlay),
                    )
                    canvas.drawColor(overlay)

                    // Adaptive scrim for high text legibility across launcher sizes and crop behavior.
                    val baseTopScrim = if (widgetDarkMode) {
                        Color.argb(114, 0, 0, 0)
                    } else {
                        Color.argb(84, 255, 255, 255)
                    }
                    val baseTransparentScrim = if (widgetDarkMode) {
                        Color.argb(6, 0, 0, 0)
                    } else {
                        Color.argb(6, 255, 255, 255)
                    }
                    val topScrimAlpha = getOverlayAlphaForSize(Color.alpha(baseTopScrim), sizeCategory)
                    val transparentScrimAlpha = getOverlayAlphaForSize(Color.alpha(baseTransparentScrim), sizeCategory)
                    
                    val topScrim = Color.argb(topScrimAlpha, Color.red(baseTopScrim), Color.green(baseTopScrim), Color.blue(baseTopScrim))
                    val transparentScrim = Color.argb(transparentScrimAlpha, Color.red(baseTransparentScrim), Color.green(baseTransparentScrim), Color.blue(baseTransparentScrim))
                    
                    val scrimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        shader = LinearGradient(
                            0f,
                            0f,
                            0f,
                            heightPx.toFloat(),
                            topScrim,
                            transparentScrim,
                            Shader.TileMode.CLAMP,
                        )
                    }
                    canvas.drawRect(0f, 0f, widthPx.toFloat(), heightPx.toFloat(), scrimPaint)

                    val bottomBandAlpha = if (!widgetDarkMode) getOverlayAlphaForSize(18, sizeCategory) else getOverlayAlphaForSize(24, sizeCategory)
                    val bottomBandPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        shader = LinearGradient(
                            0f,
                            (heightPx * 0.72f),
                            0f,
                            heightPx.toFloat(),
                            Color.TRANSPARENT,
                            if (widgetDarkMode) Color.argb(bottomBandAlpha, 0, 0, 0) else Color.argb(bottomBandAlpha, 255, 255, 255),
                            Shader.TileMode.CLAMP,
                        )
                    }
                    canvas.drawRect(0f, (heightPx * 0.72f), widthPx.toFloat(), heightPx.toFloat(), bottomBandPaint)

                    applyFocalHighlight(canvas, widthPx, heightPx, widgetDarkMode)

                    // Apply state-specific motion accents
                    applyMotionAccents(canvas, widthPx, heightPx, isLive, isUrgent, widgetDarkMode)

                    val edgePaint = Paint().apply {
                        color = if (widgetDarkMode) Color.argb(84, 7, 18, 32) else Color.argb(72, 255, 255, 255)
                    }
                    canvas.drawRect(0f, 0f, widthPx.toFloat(), 3f, edgePaint)
                    canvas.drawRect(0f, (heightPx - 3).toFloat(), widthPx.toFloat(), heightPx.toFloat(), edgePaint)

                    // Blend real LiquidGlass output over GIF so the widget keeps IRIS glass language.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val bgRes = if (widgetDarkMode) R.drawable.widget_fluffy_dark_bg else R.drawable.widget_fluffy_bg
                        val glassBitmap = LiquidGlassBitmapGenerator.generateGlassBitmap(
                            context,
                            widthPx,
                            heightPx,
                            bgRes,
                            widgetDarkMode,
                        )
                        if (glassBitmap != null) {
                            val glassPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                                alpha = if (isLive) 162 else if (isUrgent) 154 else 148
                            }
                            canvas.drawBitmap(glassBitmap, 0f, 0f, glassPaint)
                        } else {
                            canvas.drawColor(if (widgetDarkMode) Color.argb(20, 255, 255, 255) else Color.argb(24, 255, 255, 255))
                        }
                    }

                    views.setImageViewBitmap(R.id.widget_glass_bg, out)
                    true
                }
            } catch (e: Exception) {
                Log.w(TAG, "GIF background render failed: ${e.message}")
                false
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

        private fun loadAssetBitmap(context: Context, assetFileName: String): Bitmap? {
            return try {
                val assetPath = "flutter_assets/assets/$assetFileName"
                context.assets.open(assetPath).use { stream ->
                    BitmapFactory.decodeStream(stream)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load asset bitmap $assetFileName: ${e.message}")
                null
            }
        }

        private fun autoRefreshPendingIntent(
            context: Context,
            providerClass: Class<out AppWidgetProvider>,
        ): PendingIntent {
            val refreshIntent = Intent(context, providerClass).apply {
                action = UPDATE_ACTION
            }
            return PendingIntent.getBroadcast(
                context,
                AUTO_REFRESH_REQUEST_CODE,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun scheduleAutoRefresh(
            context: Context,
            providerClass: Class<out AppWidgetProvider>,
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val pendingIntent = autoRefreshPendingIntent(context, providerClass)
            val triggerAt = System.currentTimeMillis() + AUTO_REFRESH_INTERVAL_MS
            alarmManager.cancel(pendingIntent)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        }

        private fun cancelAutoRefresh(
            context: Context,
            providerClass: Class<out AppWidgetProvider>,
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val pendingIntent = autoRefreshPendingIntent(context, providerClass)
            alarmManager.cancel(pendingIntent)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, ClassTrackerWidget::class.java)
        }
        scheduleAutoRefresh(context, ClassTrackerWidget::class.java)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleAutoRefresh(context, ClassTrackerWidget::class.java)
    }

    override fun onDisabled(context: Context) {
        cancelAutoRefresh(context, ClassTrackerWidget::class.java)
        super.onDisabled(context)
    }

    override fun onReceive(context: Context, intent: Intent?) {
        super.onReceive(context, intent)
        if (intent?.action == UPDATE_ACTION) {
            updateAllInstances(context, ClassTrackerWidget::class.java)
            scheduleAutoRefresh(context, ClassTrackerWidget::class.java)
        }
    }
}
