package com.dayflower.calls;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.Person;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;
import android.service.notification.StatusBarNotification;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;

/** Registered in both the main engine and Firebase's background engine. */
public class DayflowerCallsPlugin implements FlutterPlugin {
    private MethodChannel channel;
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "dayflower/native_calls");
        channel.setMethodCallHandler((call, result) -> {
            try {
                if (call.method.equals("styleIncoming")) {
                    if (Build.VERSION.SDK_INT >= 31) {
                        NotificationManager manager = context.getSystemService(NotificationManager.class);
                        for (StatusBarNotification active : manager.getActiveNotifications()) {
                            if (active.getId() != 4501) continue;
                            Notification original = active.getNotification();
                            if (original.actions == null || original.actions.length < 2) break;
                            String name = call.argument("name");
                            Person person = new Person.Builder().setName(name == null ? "Dayflower" : name).setImportant(true).build();
                            // Reuse the tested Flutter action intents, including background decline.
                            Notification.CallStyle style = Notification.CallStyle.forIncomingCall(
                                person, original.actions[0].actionIntent, original.actions[1].actionIntent)
                                .setAnswerButtonColorHint(Color.rgb(38, 166, 91))
                                .setDeclineButtonColorHint(Color.rgb(224, 63, 69));
                            Notification updated = Notification.Builder.recoverBuilder(context, original)
                                .setActions(new Notification.Action[0]).setStyle(style)
                                .setOnlyAlertOnce(true).build();
                            updated.flags |= Notification.FLAG_INSISTENT;
                            manager.notify(4501, updated);
                            break;
                        }
                    }
                    result.success(null);
                } else if (call.method.equals("startActive")) {
                    Intent intent = new Intent(context, ActiveCallService.class);
                    intent.putExtra("video", Boolean.TRUE.equals(call.argument("video")));
                    if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent);
                    else context.startService(intent);
                    result.success(null);
                } else if (call.method.equals("stopActive")) {
                    context.stopService(new Intent(context, ActiveCallService.class));
                    result.success(null);
                } else result.notImplemented();
            } catch (Exception error) {
                result.error("native_call", error.getClass().getSimpleName(), null);
            }
        });
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
