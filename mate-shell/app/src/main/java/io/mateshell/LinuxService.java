package io.mateshell;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.IBinder;

import androidx.core.app.NotificationCompat;

public class LinuxService extends Service {
    public static final String ACTION_START = "start";
    public static final String ACTION_STOP = "stop";

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent != null ? intent.getAction() : ACTION_START;
        try {
            Notification n = buildNotification(action.equals(ACTION_STOP) ? "Остановка Linux..." : "Linux desktop...");
            startForeground(1, n);
        } catch (SecurityException ignored) {
            // Android 13+ без разрешения на уведомления — продолжаем без foreground
        }

        if (ACTION_STOP.equals(action)) {
            TermuxHelper.stopLinuxDesktop(this);
        } else {
            TermuxHelper.startLinuxDesktop(this);
        }
        try {
            stopForeground(true);
        } catch (Exception ignored) {
        }
        stopSelf();
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private Notification buildNotification(String text) {
        String ch = "mateshell_linux";
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel(ch, "Linux", NotificationManager.IMPORTANCE_LOW));
        return new NotificationCompat.Builder(this, ch)
                .setContentTitle("MateShell")
                .setContentText(text)
                .setSmallIcon(R.drawable.ic_linux)
                .build();
    }
}
