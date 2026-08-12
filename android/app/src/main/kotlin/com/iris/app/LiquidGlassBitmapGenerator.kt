package com.iris.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RenderNode
import android.graphics.HardwareRenderer
import android.graphics.PixelFormat
import android.graphics.SurfaceTexture
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.Surface
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.util.Log
import androidx.annotation.RequiresApi
import com.qmdeve.liquidglass.Config
import com.qmdeve.liquidglass.widget.LiquidGlassView
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
object LiquidGlassBitmapGenerator {
    private const val TAG = "GlassBitmapGen"

    fun generateGlassBitmap(
        context: Context,
        width: Int,
        height: Int,
        backgroundResId: Int,
        isDark: Boolean
    ): Bitmap? {
        // AppWidgets run in background/launcher processes where HardwareRenderer/PixelCopy 
        // are unsupported and block the main thread, causing severe widget freezes and ANRs.
        // Return null to let the widget layout fallback gracefully to the native XML shape/drawable.
        return null
    }

    private fun drawSoftwareFallback(
        context: Context,
        container: ViewGroup,
        bitmap: Bitmap,
        backgroundResId: Int,
        width: Int,
        height: Int
    ) {
        try {
            val softwareCanvas = Canvas(bitmap)
            container.draw(softwareCanvas)
        } catch (e: Exception) {
            Log.w(TAG, "Software container draw failed, drawing fallback drawable: ${e.message}")
            try {
                val drawable = context.getDrawable(backgroundResId)
                if (drawable != null) {
                    drawable.setBounds(0, 0, width, height)
                    val canvas = Canvas(bitmap)
                    drawable.draw(canvas)
                }
            } catch (ex: Exception) {
                Log.e(TAG, "Safelight fallback drawable failed: ${ex.message}", ex)
            }
        }
    }
}
