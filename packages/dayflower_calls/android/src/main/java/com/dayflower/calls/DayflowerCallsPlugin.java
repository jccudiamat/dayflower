package com.dayflower.calls;

import android.content.Context;
import android.content.Intent;
import android.os.Build;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;

/**
 * Registered in both the main engine and Firebase's background engine.
 *
 * WARNING: in the main engine MainActivity registers the same channel name
 * afterwards and takes it over (and handles startActive/stopActive itself).
 * So this handler only ever answers in the background engine.
 *
 * 🔴 styleIncoming is gone. It rebuilt the ring as a CallStyle carrying
 * only the caller's name - no face - and Android draws that as an initial
 * letter, with ColorOS dropping the buttons. That was the "W" notification
 * every call to a closed app arrived as. The app's CallPushService now rings
 * natively before this engine starts; see CallNotification in the app.
 */
public class DayflowerCallsPlugin implements FlutterPlugin {
    private MethodChannel channel;
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "dayflower/native_calls");
        channel.setMethodCallHandler((call, result) -> {
            try {
                if (call.method.equals("startActive")) {
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
