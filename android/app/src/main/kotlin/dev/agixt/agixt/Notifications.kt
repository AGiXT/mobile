package dev.agixt.agixt

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object Notifications {
    const val NOTIFICATION_ID_BACKGROUND_SERVICE = 1

    private const val CHANNEL_ID_BACKGROUND_SERVICE = "background_service"

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID_BACKGROUND_SERVICE,
                "AGiXT Background Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Maintains glasses connection and processes commands"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun buildForegroundNotification(context: Context): Notification {
        println("creating notification for background service");
        return NotificationCompat
            .Builder(context, CHANNEL_ID_BACKGROUND_SERVICE)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("AGiXT Background Service")
            .setContentText("Maintaining glasses connection and processing commands.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }
}