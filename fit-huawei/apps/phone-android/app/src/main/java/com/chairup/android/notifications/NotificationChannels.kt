package com.chairup.android.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import com.chairup.android.R

object NotificationChannels {
    const val MICRO_NUDGE = "chairup_micro_nudge"

    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            MICRO_NUDGE,
            "Микро-паузы",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Напоминания встать на 2 минуты"
            enableVibration(true)
        }
        nm.createNotificationChannel(channel)
    }

    fun microNudge(context: Context, title: String, text: String) =
        NotificationCompat.Builder(context, MICRO_NUDGE)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
}
