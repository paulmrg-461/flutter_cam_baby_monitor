import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests the permissions the native background camera service needs
/// (notification + battery optimization exemption) ahead of time, while
/// the app is still foreground. Best-effort: a failure here must never
/// break the core streaming flow.
class BackgroundServiceController {
  static Future<void> requestPermissions() async {
    try {
      await Permission.notification.request();
      await Permission.ignoreBatteryOptimizations.request();
    } catch (e) {
      debugPrint('BackgroundServiceController.requestPermissions failed: $e');
    }
  }
}
