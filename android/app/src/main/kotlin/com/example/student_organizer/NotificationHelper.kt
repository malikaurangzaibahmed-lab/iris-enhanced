package com.example.student_organizer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object NotificationHelper {
    private const val CHANNEL_ID = "persistent_class_foreground"
    private const val CHANNEL_NAME = "IRIS Class Tracker"
    private const val CHANNEL_DESC = "Shows your current and upcoming classes"
    private const val NOTIFICATION_ID = 256

    fun showOrUpdate(
        context: Context,
        title: String,
        line1: String,
        line2: String,
        progress: Int,
        isLive: Boolean
    ) {
        ensureChannel(context)

        val collapsed = RemoteViews(context.packageName, R.layout.notification_progress)
        val expanded = RemoteViews(context.packageName, R.layout.notification_progress)

        collapsed.setTextViewText(R.id.notif_title, title)
        collapsed.setTextViewText(R.id.notif_line1, line1)
        collapsed.setProgressBar(R.id.notif_progress, 100, progress.coerceIn(0, 100), false)
        collapsed.setTextViewText(R.id.notif_progress_text, "${progress.coerceIn(0, 100)}%")
        collapsed.setTextViewText(R.id.notif_line2, line2)
        collapsed.setViewVisibility(
            R.id.notif_line2,
            if (line2.isNotBlank()) android.view.View.VISIBLE else android.view.View.GONE
        )

        expanded.setTextViewText(R.id.notif_title, title)
        expanded.setTextViewText(R.id.notif_line1, line1)
        expanded.setProgressBar(R.id.notif_progress, 100, progress.coerceIn(0, 100), false)
        expanded.setTextViewText(R.id.notif_progress_text, "${progress.coerceIn(0, 100)}%")
        expanded.setTextViewText(R.id.notif_line2, line2)
        expanded.setViewVisibility(
            R.id.notif_line2,
            if (line2.isNotBlank()) android.view.View.VISIBLE else android.view.View.GONE
        )

        val launchIntent: Intent? = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .setColor(Color.parseColor("#10B981"))
            .setColorized(isLive)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = manager.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = CHANNEL_DESC
                    setSound(null, null)
                    enableVibration(false)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }
}
