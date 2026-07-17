import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Bridges to a native Android foreground service that keeps capturing
/// JPEG frames via Camera2 while the app is backgrounded/screen off —
/// something CameraX (used by the `camera` plugin) cannot do, since it
/// unbinds its use cases when the hosting Activity stops.
///
/// The service itself must be started while the app is still visible
/// (Android 14+ requirement for camera-typed foreground services), so
/// [startService] and camera acquisition ([acquireCamera]/[releaseCamera])
/// are separate calls — see [CameraRepositoryImpl] for how they're wired.
class NativeCameraDatasource {
  static const _controlChannel = MethodChannel(
    'pro.devpaul.baby_monitor/background_camera',
  );
  static const _framesChannel = EventChannel(
    'pro.devpaul.baby_monitor/camera_frames',
  );

  Stream<Uint8List>? _frameStream;

  Stream<Uint8List> get frameStream {
    return _frameStream ??= _framesChannel
        .receiveBroadcastStream()
        .map((event) => event as Uint8List);
  }

  /// Starts the foreground service (shows the notification). Must be
  /// called while the app is foreground/visible.
  Future<void> startService() {
    return _controlChannel.invokeMethod('startService');
  }

  /// Opens the camera via Camera2 and starts capturing. Safe to call
  /// while the app is backgrounded, as long as [startService] already ran.
  Future<void> acquireCamera({
    required CameraLensDirection lensDirection,
    required int width,
    required int height,
    required int quality,
    required int targetFps,
  }) {
    return _controlChannel.invokeMethod('acquireCamera', {
      'lensFacing': lensDirection == CameraLensDirection.front ? 'front' : 'back',
      'width': width,
      'height': height,
      'quality': quality,
      'targetFps': targetFps,
    });
  }

  /// Releases the camera device without stopping the foreground service.
  Future<void> releaseCamera() {
    return _controlChannel.invokeMethod('releaseCamera');
  }

  /// Stops the foreground service entirely (releases the camera first).
  Future<void> stopService() {
    return _controlChannel.invokeMethod('stopService');
  }
}
