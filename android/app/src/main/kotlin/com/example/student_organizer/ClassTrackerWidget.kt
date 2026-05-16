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
            "com.example.student_organizer",
            "HomeWidgetPreferences",
            "FlutterSharedPreferences",
        )
        private const val UPDATE_ACTION = "com.example.student_organizer.WIDGET_UPDATE"
        private const val AUTO_REFRESH_INTERVAL_MS = 12_000L
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

                val sizePx = getWidgetSizePx(context, appWidgetManager, appWidgetId)

                // Primary background: render a dynamic frame from GIF for a living background.
                val gifApplied = applyGifBackground(
                    context = context,
                    views = views,
                    widthPx = sizePx.first,
                    heightPx = sizePx.second,
                    widgetDarkMode = widgetDarkMode,
                    isLive = isLive,
                    isUrgent = isUrgent,
                    progressPercent = progressPercent,
                )

                // Apply Liquid Glass effect if supported (Android 13+)
                if (!gifApplied && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    Log.d(TAG, "Attempting to generate LiquidGlass effect for widget $appWidgetId")
                    try {
                        val bgRes = if (widgetDarkMode) R.drawable.widget_fluffy_dark_bg else R.drawable.widget_fluffy_bg
                        val glassBitmap = LiquidGlassBitmapGenerator.generateGlassBitmap(
                            context,
                            sizePx.first,
                            sizePx.second,
                            bgRes,
                            widgetDarkMode,
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
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                    isUrgent -> {
                        views.setTextViewText(R.id.widget_status_badge, "SOON")
                        views.setTextColor(R.id.widget_status_badge, 0xFFF59E0B.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                    else -> {
                        views.setTextViewText(R.id.widget_status_badge, "NEXT")
                        views.setTextColor(R.id.widget_status_badge, if (widgetDarkMode) 0xFFBFDBFE.toInt() else 0xFF5B7FFF.toInt())
                        views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    }
                }

                if (teacher.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_teacher_info, "Teacher: $teacher")
                    views.setTextColor(R.id.widget_teacher_info, if (widgetDarkMode) 0xFFCBD5E1.toInt() else 0xFF64748B.toInt())
                    views.setViewVisibility(R.id.widget_teacher_info, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_teacher_info, View.GONE)
                }

                if (isLive) {
                    views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
                    views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_progress, View.GONE)
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
