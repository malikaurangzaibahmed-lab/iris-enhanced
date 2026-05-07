package com.example.student_organizer

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
        Log.d(TAG, "Generating hardware-accelerated glass bitmap: ${width}x${height}, dark=$isDark")
        if (width <= 0 || height <= 0) return null

        // Create a dummy container to host the views for rendering
        val container = FrameLayout(context)
        container.layoutParams = ViewGroup.LayoutParams(width, height)
        
        // Add background image
        val bgView = ImageView(context)
        bgView.setImageResource(backgroundResId)
        bgView.scaleType = ImageView.ScaleType.CENTER_CROP
        container.addView(bgView, FrameLayout.LayoutParams(width, height))

        // Add LiquidGlassView
        val glassView = LiquidGlassView(context)
        glassView.setCornerRadius(28f)
        glassView.setBlurRadius(16f)
        glassView.setTintAlpha(if (isDark) 0.35f else 0.45f)
        
        container.addView(glassView, FrameLayout.LayoutParams(width, height))
        glassView.bind(container)

        // Measure and layout
        container.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        )
        container.layout(0, 0, width, height)

        // Setup HardwareRenderer to capture the shader
        val renderNode = RenderNode("GlassWidgetRender")
        renderNode.setPosition(0, 0, width, height)
        
        val canvas = renderNode.beginRecording()
        container.draw(canvas)
        renderNode.endRecording()

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val surfaceTexture = SurfaceTexture(0)
        surfaceTexture.setDefaultBufferSize(width, height)
        val surface = Surface(surfaceTexture)

        val renderer = HardwareRenderer()
        renderer.setSurface(surface)
        renderer.setContentRoot(renderNode)
        
        try {
            // Trigger a hardware frame
            renderer.createRenderRequest()
                .setVsyncTime(System.nanoTime())
                .syncAndDraw()

            // Capture the surface content back to a bitmap
            val latch = CountDownLatch(1)
            var pixelCopyResult = -1
            
            PixelCopy.request(surface, bitmap, { result ->
                pixelCopyResult = result
                latch.countDown()
            }, Handler(Looper.getMainLooper()))
            
            val success = latch.await(2, TimeUnit.SECONDS)
            if (!success || pixelCopyResult != PixelCopy.SUCCESS) {
                Log.e(TAG, "PixelCopy failed: success=$success, result=$pixelCopyResult")
                // Fallback to software draw (no glass effect)
                val softwareCanvas = Canvas(bitmap)
                container.draw(softwareCanvas)
            } else {
                Log.d(TAG, "PixelCopy successful")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Hardware rendering failed: ${e.message}", e)
            val softwareCanvas = Canvas(bitmap)
            container.draw(softwareCanvas)
        } finally {
            renderer.destroy()
            surface.release()
            surfaceTexture.release()
        }
        
        return bitmap
    }
}
