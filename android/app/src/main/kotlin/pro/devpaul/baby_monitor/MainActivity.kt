package pro.devpaul.baby_monitor

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val ENGINE_ID = "baby_monitor_main_engine"
        const val CONTROL_CHANNEL = "pro.devpaul.baby_monitor/background_camera"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Only this one promotes the service to foreground, so
                    // only this one may use startForegroundService(). It
                    // must run while the app is visible (Android 14+
                    // requirement for camera-typed foreground services).
                    "startService" -> {
                        val intent = Intent(this, CameraBackgroundService::class.java).apply {
                            action = CameraBackgroundService.ACTION_START_SERVICE
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "acquireCamera" -> {
                        startService(Intent(this, CameraBackgroundService::class.java).apply {
                            action = CameraBackgroundService.ACTION_ACQUIRE_CAMERA
                            putExtra("lensFacing", call.argument<String>("lensFacing"))
                            putExtra("width", call.argument<Int>("width") ?: 1280)
                            putExtra("height", call.argument<Int>("height") ?: 720)
                            putExtra("quality", call.argument<Int>("quality") ?: 80)
                            putExtra("targetFps", call.argument<Int>("targetFps") ?: 10)
                        })
                        result.success(null)
                    }
                    "releaseCamera" -> {
                        startService(Intent(this, CameraBackgroundService::class.java).apply {
                            action = CameraBackgroundService.ACTION_RELEASE_CAMERA
                        })
                        result.success(null)
                    }
                    "stopService" -> {
                        startService(Intent(this, CameraBackgroundService::class.java).apply {
                            action = CameraBackgroundService.ACTION_STOP_SERVICE
                        })
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
