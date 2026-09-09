package com.dayflower.calls;

import android.app.*;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;

/** Keeps an explicitly answered/dialled call eligible for background media. */
public class ActiveCallService extends Service {
    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        boolean video = intent != null && intent.getBooleanExtra("video", false);
        String channel = "active_calls_v1";
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(new NotificationChannel(channel, "Active calls", NotificationManager.IMPORTANCE_LOW));
        }
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        PendingIntent open = PendingIntent.getActivity(this, 4502, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, channel) : new Notification.Builder(this);
        Notification notification = builder.setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle("Dayflower call in progress")
            .setContentText(video ? "Video call · tap to return" : "Voice call · tap to return")
            .setContentIntent(open).setCategory(Notification.CATEGORY_CALL).setOngoing(true).build();
        if (Build.VERSION.SDK_INT >= 30) {
            int types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE;
            if (video) types |= ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA;
            startForeground(4502, notification, types);
        } else startForeground(4502, notification);
        return START_NOT_STICKY;
    }
    @Override public IBinder onBind(Intent intent) { return null; }
    @Override public void onDestroy() { stopForeground(true); super.onDestroy(); }
}
